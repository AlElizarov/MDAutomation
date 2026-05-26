param(
    [string]$VenvPath = ".venv"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$VenvPython = Join-Path $Root "$VenvPath\Scripts\python.exe"
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "MDAutomation-python-$([System.Guid]::NewGuid().ToString('N'))"
$PreviousPythonPath = $env:PYTHONPATH

if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment not found. Run .\scripts\dev\install_deps.ps1 first."
}

try {
    $WorkaroundPath = & (Join-Path $Root "scripts\internal\ensure_python_workaround.ps1") -Root $TempRoot
    $env:PYTHONPATH = $WorkaroundPath

    & $VenvPython -m pytest
}
finally {
    $env:PYTHONPATH = $PreviousPythonPath

    if (Test-Path $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
