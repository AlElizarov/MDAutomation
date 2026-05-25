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

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ComposePath = Join-Path $Root $ComposeFile
$PreviousAppPort = $env:APP_PORT
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

if ($NewWindow) {
    $startDockerFlag = if ($StartDockerDesktop) { " -StartDockerDesktop" } else { "" }
    $noBuildFlag = if ($NoBuild) { " -NoBuild" } else { "" }
    $command = "Set-Location '$Root'; .\scripts\run_server.ps1 -ComposeFile '$ComposeFile' -HostAddress '$HostAddress' -Port $Port -TimeoutSeconds $TimeoutSeconds$startDockerFlag$noBuildFlag"

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
    $healthUrl = "http://$HostAddress`:$Port/health"

    Invoke-Docker @("--version")
    Invoke-Docker @("compose", "version")

    Wait-DockerReady -TimeoutSeconds $TimeoutSeconds

    if ($NoBuild) {
        Write-Host "Starting Docker Compose services..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d")
    }
    else {
        Write-Host "Building and starting Docker Compose services..."
        Invoke-Docker @("compose", "-f", $ComposeFile, "up", "-d", "--build")
    }

    Write-Host "Waiting for health endpoint: $healthUrl"
    Wait-HealthEndpoint -Url $healthUrl -TimeoutSeconds $TimeoutSeconds

    Write-Host "Applying database migrations..."
    Invoke-Docker @("compose", "-f", $ComposeFile, "exec", "-T", "backend", "python", "-m", "alembic", "upgrade", "head")

    Write-Host "Backend is running at http://$HostAddress`:$Port"
    Write-Host "Swagger UI: http://$HostAddress`:$Port/docs"
    Write-Host "PostgreSQL is running in Docker Compose service: db"
    Write-Host "Stop services with: docker compose down --remove-orphans"
}
finally {
    $env:APP_PORT = $PreviousAppPort
}
