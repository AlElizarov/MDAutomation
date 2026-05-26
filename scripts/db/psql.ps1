param(
    [string]$ComposeFile = "docker-compose.yml",
    [int]$TimeoutSeconds = 120,
    [Alias("Test")]
    [switch]$TestDatabase
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ComposePath = Join-Path $Root $ComposeFile
$LastDockerInfoError = ""

if (-not (Test-Path $ComposePath)) {
    throw "Compose file not found: $ComposePath"
}

function Test-CommandExists {
    param([string]$Name)

    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-DockerReady {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = docker info 2>&1
        $exitCode = $LASTEXITCODE
        $script:LastDockerInfoError = ($output -join [Environment]::NewLine).Trim()

        return $exitCode -eq 0
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $FilePath @Arguments
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')"
    }
}

function Invoke-Docker {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Invoke-NativeCommand -FilePath "docker" -Arguments $Arguments
}

function Invoke-DockerOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = docker @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: docker $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }

    return ($output -join [Environment]::NewLine).Trim()
}

function Get-DotEnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $envPath = Join-Path $Root ".env"

    if (-not (Test-Path $envPath)) {
        return $null
    }

    foreach ($line in Get-Content $envPath) {
        if ($line -match "^\s*$Name\s*=\s*(.*)\s*$") {
            return $Matches[1].Trim('"').Trim("'")
        }
    }

    return $null
}

function Get-PostgresSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$DefaultValue
    )

    $environmentValue = [Environment]::GetEnvironmentVariable($Name)

    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        return $environmentValue
    }

    $dotEnvValue = Get-DotEnvValue -Name $Name

    if (-not [string]::IsNullOrWhiteSpace($dotEnvValue)) {
        return $dotEnvValue
    }

    return $DefaultValue
}

function Start-DockerDesktopIfNeeded {
    if (Test-DockerReady) {
        return
    }

    $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"

    if (-not (Test-Path $dockerDesktopPath)) {
        throw "Docker Desktop executable was not found: $dockerDesktopPath"
    }

    if (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue) {
        Write-Host "Docker Desktop is already running."
    }
    else {
        Write-Host "Starting Docker Desktop..."
        Start-Process -FilePath $dockerDesktopPath -WindowStyle Hidden | Out-Null
    }
}

function Wait-DockerReady {
    param([int]$TimeoutSeconds)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        if (Test-DockerReady) {
            return
        }

        if ($script:LastDockerInfoError -match "Access is denied|elevated privileges") {
            throw "Docker is running, but the current process cannot access the Docker daemon. Run this script from a PowerShell session with Docker access."
        }

        Write-Host "Waiting for Docker to become ready..."
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)

    throw "Docker did not become ready within $TimeoutSeconds seconds. Last docker info error: $script:LastDockerInfoError"
}

function Wait-PostgresReady {
    param(
        [int]$TimeoutSeconds,
        [string]$PostgresUser,
        [string]$PostgresDb
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            docker compose -f $ComposeFile exec -T db pg_isready -U $PostgresUser -d $PostgresDb > $null 2> $null
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        if ($exitCode -eq 0) {
            return
        }

        Write-Host "Waiting for PostgreSQL to become ready..."
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)

    throw "PostgreSQL did not become ready within $TimeoutSeconds seconds."
}

function Invoke-PostgresSql {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,

        [Parameter(Mandatory = $true)]
        [string]$PostgresUser,

        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    return Invoke-DockerOutput @(
        "compose",
        "-f",
        $ComposeFile,
        "exec",
        "-T",
        "db",
        "psql",
        "-v",
        "ON_ERROR_STOP=1",
        "-U",
        $PostgresUser,
        "-d",
        $DatabaseName,
        "-t",
        "-A",
        "-c",
        $Sql
    )
}

function Ensure-DatabaseExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,

        [Parameter(Mandatory = $true)]
        [string]$PostgresUser
    )

    if ($DatabaseName -notmatch "^[A-Za-z0-9_]+$") {
        throw "Database name contains unsupported characters: $DatabaseName"
    }

    $exists = Invoke-PostgresSql `
        -DatabaseName "postgres" `
        -PostgresUser $PostgresUser `
        -Sql "SELECT 1 FROM pg_database WHERE datname = '$DatabaseName';"

    if ($exists -eq "1") {
        return
    }

    Write-Host "Creating PostgreSQL database '$DatabaseName'..."
    Invoke-PostgresSql `
        -DatabaseName "postgres" `
        -PostgresUser $PostgresUser `
        -Sql "CREATE DATABASE `"$DatabaseName`";" | Out-Null
}

Set-Location $Root

if (-not (Test-CommandExists "docker")) {
    throw "Docker CLI was not found. Install Docker Desktop first."
}

Start-DockerDesktopIfNeeded
Wait-DockerReady -TimeoutSeconds $TimeoutSeconds

$PostgresUser = Get-PostgresSetting -Name "POSTGRES_USER" -DefaultValue "mda_user"
$TargetDatabase = if ($TestDatabase) { "mda_test" } else { "mda_dev" }

Write-Host "Starting PostgreSQL service..."
Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "db")

Wait-PostgresReady -TimeoutSeconds $TimeoutSeconds -PostgresUser $PostgresUser -PostgresDb "postgres"
Ensure-DatabaseExists -DatabaseName $TargetDatabase -PostgresUser $PostgresUser

Write-Host "Opening psql for database '$TargetDatabase' as user '$PostgresUser'."
Write-Host "Exit psql with: \q"

& docker compose -f $ComposeFile exec db psql -U $PostgresUser -d $TargetDatabase
