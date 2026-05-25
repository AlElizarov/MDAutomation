param(
    [string]$VenvPath = ".venv",
    [string]$Revision = "head"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root "$VenvPath\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment not found. Run .\scripts\install_deps.ps1 first."
}

if ([string]::IsNullOrWhiteSpace($env:DATABASE_URL)) {
    throw "DATABASE_URL environment variable is required to run migrations locally."
}

Set-Location $Root

& $VenvPython -m alembic upgrade $Revision
