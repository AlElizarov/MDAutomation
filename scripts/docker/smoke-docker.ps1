param(
    [string]$ComposeFile = "docker-compose.yml",
    [string]$HealthUrl = "http://127.0.0.1:8000/health",
    [int]$TimeoutSeconds = 120,
    [switch]$StartDockerDesktop,
    [switch]$KeepRunning,
    [switch]$SkipPersistenceCheck
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ComposePath = Join-Path $Root $ComposeFile
$PreviousAppDatabaseName = $env:APP_DATABASE_NAME

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

function Invoke-CreateLeadApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HealthUrl
    )

    $leadsUrl = $HealthUrl -replace "/health$", "/leads"
    $body = @{
        name = "Smoke Test Lead"
        phone = "+10000000000"
        preferred_contact_channel = "telegram"
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri $leadsUrl `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec 10
    }
    catch {
        throw "Lead creation API smoke request failed: $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace($response.lead_id)) {
        throw "Lead creation API response did not include lead_id."
    }

    if ($response.status -ne "created") {
        throw "Lead creation API response returned unexpected status: $($response.status)"
    }

    return $response.lead_id
}

function Invoke-PostgresSql {
    param(
        [string]$DatabaseName = $PostgresDb,

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
        $DatabaseName,
        "-t",
        "-A",
        "-c",
        $Sql
    )
}

function Assert-ValidDatabaseName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName
    )

    if ($DatabaseName -notmatch "^[A-Za-z0-9_]+$") {
        throw "Database name contains unsupported characters: $DatabaseName"
    }
}

function New-TestDatabase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName
    )

    Assert-ValidDatabaseName -DatabaseName $DatabaseName

    Write-Host "Creating smoke test database '$DatabaseName'..."
    Invoke-PostgresSql -DatabaseName "postgres" -Sql "CREATE DATABASE `"$DatabaseName`";" | Out-Null
}

function Remove-TestDatabase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName
    )

    Assert-ValidDatabaseName -DatabaseName $DatabaseName

    Write-Host "Dropping smoke test database '$DatabaseName'..."
    Invoke-PostgresSql `
        -DatabaseName "postgres" `
        -Sql "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DatabaseName' AND pid <> pg_backend_pid();" | Out-Null
    Invoke-PostgresSql -DatabaseName "postgres" -Sql "DROP DATABASE IF EXISTS `"$DatabaseName`";" | Out-Null
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

$PostgresDb = "mda_test"
$PostgresUser = Get-PostgresSetting -Name "POSTGRES_USER" -DefaultValue "mda_user"
$smokePassed = $false

try {
    $env:APP_DATABASE_NAME = $PostgresDb

    Write-Host "Cleaning up existing Docker Compose services..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "down", "--remove-orphans")

    Write-Host "Building Docker image..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "build")

    Write-Host "Starting PostgreSQL service..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "db")
    Wait-PostgresReady -TimeoutSeconds $TimeoutSeconds -PostgresUser $PostgresUser
    Remove-TestDatabase -DatabaseName $PostgresDb
    New-TestDatabase -DatabaseName $PostgresDb

    Write-Host "Starting backend service with database '$PostgresDb'..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "backend")

    Write-Host "Waiting for health endpoint: $HealthUrl"
    Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds

    Write-Host "Applying database migrations..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "exec", "-T", "backend", "python", "-m", "alembic", "upgrade", "head")
    Assert-PostgresTableExists -TableName "leads"

    if ($SkipPersistenceCheck) {
        Write-Host "Skipping PostgreSQL persistence check."
    }
    else {
        Write-Host "Creating lead through POST /leads..."
        $recordId = Invoke-CreateLeadApi -HealthUrl $HealthUrl
        Assert-PersistenceRecordExists -RecordId $recordId

        Write-Host "Restarting PostgreSQL service and verifying persisted data..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "restart", "db")
        Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds
        Assert-PersistenceRecordExists -RecordId $recordId

        Write-Host "Recreating Docker Compose environment and verifying persisted data..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "down", "--remove-orphans")
        Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d")
        Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds
        Assert-PersistenceRecordExists -RecordId $recordId

        Write-Host "Recreating backend container and verifying persisted data..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "--force-recreate", "backend")
        Wait-HealthEndpoint -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds
        Assert-PersistenceRecordExists -RecordId $recordId
    }

    $smokePassed = $true
    Write-Host "Docker smoke test passed."
}
catch {
    Write-Host "Docker smoke test failed. Docker Compose status:"
    & docker compose -f $ComposeFile ps

    Write-Host "Backend logs:"
    & docker compose -f $ComposeFile logs backend --tail 100

    throw
}
finally {
    Write-Host "Cleaning up smoke test database..."

    try {
        Invoke-Docker @("compose", "-f", $ComposeFile, "stop", "backend")
        Wait-PostgresReady -TimeoutSeconds $TimeoutSeconds -PostgresUser $PostgresUser
        Remove-TestDatabase -DatabaseName $PostgresDb
    }
    catch {
        Write-Host "Smoke test database cleanup failed: $($_.Exception.Message)"
    }

    if ($KeepRunning -and $smokePassed) {
        Write-Host "Keeping PostgreSQL service running after cleaning test database."
    }
    else {
        Write-Host "Stopping Docker Compose services..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "down", "--remove-orphans")
    }

    $env:APP_DATABASE_NAME = $PreviousAppDatabaseName
}
