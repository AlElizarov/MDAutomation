param(
    [string]$VenvPath = ".venv",
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8000,
    [switch]$Reload,
    [switch]$NewWindow
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root "$VenvPath\Scripts\python.exe"
$WorkaroundPath = & (Join-Path $PSScriptRoot "ensure_python_workaround.ps1") -Root $Root

if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment not found. Run .\scripts\install_deps.ps1 first."
}

$arguments = @(
    "-m",
    "uvicorn",
    "mda_automation.main:app",
    "--app-dir",
    "src",
    "--host",
    $HostAddress,
    "--port",
    $Port
)

if ($Reload) {
    $arguments += "--reload"
}

if ($NewWindow) {
    $reloadFlag = if ($Reload) { " -Reload" } else { "" }
    $command = "Set-Location '$Root'; .\scripts\run_server.ps1 -HostAddress '$HostAddress' -Port $Port$reloadFlag"

    Start-Process -FilePath powershell.exe `
        -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $command) `
        -WorkingDirectory $Root `
        -WindowStyle Normal

    return
}

Set-Location $Root

$env:PYTHONPATH = $WorkaroundPath

Write-Host "FastAPI server starting at http://$HostAddress`:$Port"
Write-Host "Swagger UI: http://$HostAddress`:$Port/docs"
Write-Host "Press Ctrl+C to stop."

& $VenvPython @arguments
