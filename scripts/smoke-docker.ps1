param(
    [string]$ComposeFile = "docker-compose.yml",
    [string]$HealthUrl = "http://127.0.0.1:8000/health",
    [int]$TimeoutSeconds = 120,
    [switch]$StartDockerDesktop,
    [switch]$KeepRunning
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

function Invoke-Docker {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Invoke-NativeCommand -FilePath "docker" -Arguments $Arguments
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
