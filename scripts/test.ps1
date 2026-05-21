param(
    [string]$VenvPath = ".venv"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root "$VenvPath\Scripts\python.exe"
$WorkaroundPath = & (Join-Path $PSScriptRoot "ensure_python_workaround.ps1") -Root $Root

if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment not found. Run .\scripts\install_deps.ps1 first."
}

$env:PYTHONPATH = $WorkaroundPath

& $VenvPython -m pytest
