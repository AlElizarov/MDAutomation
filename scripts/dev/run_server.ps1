param(
    [string]$ComposeFile = "docker-compose.yml",
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8000,
    [int]$TimeoutSeconds = 120,
    [switch]$StartDockerDesktop,
    [switch]$NoBuild,
    [switch]$NewWindow
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ComposePath = Join-Path $Root $ComposeFile
$PreviousAppPort = $env:APP_PORT
$PreviousAppDatabaseName = $env:APP_DATABASE_NAME
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

function Wait-HealthEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        try {
            $response = Invoke-RestMethod -Uri $Url -TimeoutSec 5

            if ($response.status -eq "ok") {
                return
            }
        }
        catch {
            Start-Sleep -Seconds 3
        }
    } while ((Get-Date) -lt $deadline)

    throw "Health endpoint did not return the expected response within $TimeoutSeconds seconds: $Url"
}

function Wait-PostgresReady {
    param(
        [int]$TimeoutSeconds,
        [string]$PostgresUser
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            docker compose -f $ComposeFile exec -T db pg_isready -U $PostgresUser -d postgres > $null 2> $null
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
        "postgres",
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
        -PostgresUser $PostgresUser `
        -Sql "SELECT 1 FROM pg_database WHERE datname = '$DatabaseName';"

    if ($exists -eq "1") {
        return
    }

    Write-Host "Creating PostgreSQL database '$DatabaseName'..."
    Invoke-PostgresSql `
        -PostgresUser $PostgresUser `
        -Sql "CREATE DATABASE `"$DatabaseName`";" | Out-Null
}

if ($NewWindow) {
    $startDockerFlag = if ($StartDockerDesktop) { " -StartDockerDesktop" } else { "" }
    $noBuildFlag = if ($NoBuild) { " -NoBuild" } else { "" }
    $command = "Set-Location '$Root'; .\scripts\dev\run_server.ps1 -ComposeFile '$ComposeFile' -HostAddress '$HostAddress' -Port $Port -TimeoutSeconds $TimeoutSeconds$startDockerFlag$noBuildFlag"

    Start-Process -FilePath powershell.exe `
        -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $command) `
        -WorkingDirectory $Root `
        -WindowStyle Normal

    return
}

Set-Location $Root

if (-not (Test-CommandExists "docker")) {
    throw "Docker CLI was not found. Install Docker Desktop first."
}

if ($StartDockerDesktop) {
    $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"

    if (-not (Test-Path $dockerDesktopPath)) {
        throw "Docker Desktop executable was not found: $dockerDesktopPath"
    }

    if (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue) {
        Write-Host "Docker Desktop is already running."
    }
    else {
        Write-Host "Starting Docker Desktop..."
        Start-Process -FilePath $dockerDesktopPath | Out-Null
    }
}

try {
    $env:APP_PORT = $Port
    $env:APP_DATABASE_NAME = "mda_dev"
    $healthUrl = "http://$HostAddress`:$Port/health"
    $postgresUser = Get-PostgresSetting -Name "POSTGRES_USER" -DefaultValue "mda_user"

    Invoke-Docker @("--version")
    Invoke-Docker @("compose", "version")

    Wait-DockerReady -TimeoutSeconds $TimeoutSeconds

    Write-Host "Starting PostgreSQL service..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "db")
    Wait-PostgresReady -TimeoutSeconds $TimeoutSeconds -PostgresUser $postgresUser
    Ensure-DatabaseExists -DatabaseName $env:APP_DATABASE_NAME -PostgresUser $postgresUser

    if ($NoBuild) {
        Write-Host "Starting backend service..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "backend")
    }
    else {
        Write-Host "Building and starting backend service..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "--build", "backend")
    }

    Write-Host "Waiting for health endpoint: $healthUrl"
    Wait-HealthEndpoint -Url $healthUrl -TimeoutSeconds $TimeoutSeconds

    Write-Host "Applying database migrations..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "exec", "-T", "backend", "python", "-m", "alembic", "upgrade", "head")

    Write-Host "Backend is running at http://$HostAddress`:$Port"
    Write-Host "Swagger UI: http://$HostAddress`:$Port/docs"
    Write-Host "PostgreSQL is running in Docker Compose service: db"
    Write-Host "Backend database: $env:APP_DATABASE_NAME"
    Write-Host "Stop services with: docker compose down --remove-orphans"
}
finally {
    $env:APP_PORT = $PreviousAppPort
    $env:APP_DATABASE_NAME = $PreviousAppDatabaseName
}
