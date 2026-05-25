param(
    [string]$ComposeFile = "docker-compose.yml",
    [string]$HealthUrl = "http://127.0.0.1:8000/health",
    [int]$TimeoutSeconds = 120,
    [switch]$StartDockerDesktop,
    [switch]$KeepRunning,
    [switch]$SkipPersistenceCheck
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ComposePath = Join-Path $Root $ComposeFile

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
        docker info > $null 2> $null
        return $LASTEXITCODE -eq 0
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

function Invoke-NativeCommandOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }

    return ($output -join [Environment]::NewLine).Trim()
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

    return Invoke-NativeCommandOutput -FilePath "docker" -Arguments $Arguments
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

        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)

    throw "Docker did not become ready within $TimeoutSeconds seconds."
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

function Invoke-PostgresSql {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    return Invoke-DockerOutput @(
        "compose",
        "exec",
        "-T",
        "db",
        "psql",
        "-v",
        "ON_ERROR_STOP=1",
        "-U",
        $PostgresUser,
        "-d",
        $PostgresDb,
        "-t",
        "-A",
        "-c",
        $Sql
    )
}

function Assert-PersistenceRecordExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RecordId
    )

    $result = Invoke-PostgresSql -Sql "SELECT count(*) FROM leads WHERE id = '$RecordId';"

    if ($result -ne "1") {
        throw "Expected lead persistence smoke record '$RecordId' to exist, but query returned '$result'."
    }
}

function Assert-PostgresTableExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName
    )

    $result = Invoke-PostgresSql -Sql "SELECT to_regclass('public.$TableName');"

    if ($result -ne $TableName) {
        throw "Expected PostgreSQL table '$TableName' to exist, but query returned '$result'."
    }
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

Invoke-Docker @("--version")
Invoke-Docker @("compose", "version")

Wait-DockerReady -TimeoutSeconds $TimeoutSeconds

$PostgresDb = Get-PostgresSetting -Name "POSTGRES_DB" -DefaultValue "mda"
$PostgresUser = Get-PostgresSetting -Name "POSTGRES_USER" -DefaultValue "mda_user"
$smokePassed = $false

try {
    Write-Host "Cleaning up existing Docker Compose services..."
    Invoke-Docker @("compose", "down", "--remove-orphans")

    Write-Host "Building Docker image..."
    Invoke-Docker @("compose", "build")

    Write-Host "Starting Docker Compose services..."
    Invoke-Docker @("compose", "up", "-d")

    Write-Host "Waiting for health endpoint: $HealthUrl"
    Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds

    Write-Host "Applying database migrations..."
    Invoke-Docker @("compose", "exec", "-T", "backend", "python", "-m", "alembic", "upgrade", "head")
    Assert-PostgresTableExists -TableName "leads"

    if ($SkipPersistenceCheck) {
        Write-Host "Skipping PostgreSQL persistence check."
    }
    else {
        $recordId = [System.Guid]::NewGuid().ToString("N")

        Write-Host "Creating lead persistence smoke record..."
        Invoke-PostgresSql -Sql "INSERT INTO leads (id, name, phone, preferred_contact_channel, status) VALUES ('$recordId', 'Smoke Test Lead', '+10000000000', 'telegram', 'new');"
        Assert-PersistenceRecordExists -RecordId $recordId

        Write-Host "Restarting PostgreSQL service and verifying persisted data..."
        Invoke-Docker @("compose", "restart", "db")
        Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds
        Assert-PersistenceRecordExists -RecordId $recordId

        Write-Host "Recreating Docker Compose environment and verifying persisted data..."
        Invoke-Docker @("compose", "down", "--remove-orphans")
        Invoke-Docker @("compose", "up", "-d")
        Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds
        Assert-PersistenceRecordExists -RecordId $recordId

        Write-Host "Recreating backend container and verifying persisted data..."
        Invoke-Docker @("compose", "up", "-d", "--force-recreate", "backend")
        Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds
        Assert-PersistenceRecordExists -RecordId $recordId
    }

    $smokePassed = $true
    Write-Host "Docker smoke test passed."
}
catch {
    Write-Host "Docker smoke test failed. Docker Compose status:"
    & docker compose ps

    Write-Host "Backend logs:"
    & docker compose logs backend --tail 100

    throw
}
finally {
    if ($KeepRunning -and $smokePassed) {
        Write-Host "Keeping Docker Compose services running."
    }
    else {
        Write-Host "Stopping Docker Compose services..."
        Invoke-Docker @("compose", "down", "--remove-orphans")
    }
}
