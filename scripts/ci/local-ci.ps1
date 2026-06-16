param(
    [string]$VenvPath = ".venv",
    [switch]$DocsOnly,
    [switch]$SkipDocker
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$VenvPython = Join-Path $Root "$VenvPath\Scripts\python.exe"
$WorkflowPath = Join-Path $Root ".github\workflows\ci-cd.yml"

if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment not found. Run .\scripts\dev\install_deps.ps1 first."
}

Set-Location $Root

if ($DocsOnly) {
    Write-Host "Building documentation..."
    & (Join-Path $Root "scripts\docs\build_docs.ps1") -VenvPath $VenvPath
    return
}

Write-Host "Checking GitHub Actions YAML..."
& $VenvPython -c "import pathlib, yaml; yaml.safe_load(pathlib.Path(r'$WorkflowPath').read_text()); print('YAML OK')"

Write-Host "Running backend tests..."
& (Join-Path $Root "scripts\dev\test.ps1") -VenvPath $VenvPath

Write-Host "Building documentation..."
& (Join-Path $Root "scripts\docs\build_docs.ps1") -VenvPath $VenvPath

if ($SkipDocker) {
    Write-Host "Skipping Docker smoke test."
}
else {
    Write-Host "Running Docker smoke test..."
    & (Join-Path $Root "scripts\docker\smoke-docker.ps1") -StartDockerDesktop
}
