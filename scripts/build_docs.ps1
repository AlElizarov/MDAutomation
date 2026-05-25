param(
    [string]$VenvPath = ".venv",
    [string]$SiteDir = "site"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root "$VenvPath\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment not found. Run .\scripts\install_deps.ps1 first."
}

Set-Location $Root

& $VenvPython -m mkdocs build --strict --site-dir $SiteDir
