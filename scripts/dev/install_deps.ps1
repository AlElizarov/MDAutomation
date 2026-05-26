param(
    [string]$Python = "python",
    [string]$VenvPath = ".venv",
    [string]$Requirements = "requirements.txt"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$VenvFullPath = Join-Path $Root $VenvPath
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "MDAutomation-pip-$([System.Guid]::NewGuid().ToString('N'))"
$TmpPath = Join-Path $TempRoot "tmp"
$DownloadPath = Join-Path $TempRoot "download"
$RequirementsPath = Join-Path $Root $Requirements
$PySocksWheelPath = Join-Path $DownloadPath "PySocks-1.7.1-py3-none-any.whl"
$PreviousPythonPath = $env:PYTHONPATH
$PreviousTemp = $env:TEMP
$PreviousTmp = $env:TMP

if (-not (Test-Path $RequirementsPath)) {
    throw "Requirements file not found: $RequirementsPath"
}

try {
    New-Item -ItemType Directory -Force -Path $TmpPath, $DownloadPath | Out-Null
    $WorkaroundPath = & (Join-Path $Root "scripts\internal\ensure_python_workaround.ps1") -Root $TempRoot

    $env:PYTHONPATH = $WorkaroundPath
    $env:TEMP = $TmpPath
    $env:TMP = $TmpPath

    if (-not (Test-Path (Join-Path $VenvFullPath "Scripts\python.exe"))) {
        & $Python -m venv $VenvFullPath
    }

    $VenvPython = Join-Path $VenvFullPath "Scripts\python.exe"

    try {
        & $VenvPython -m pip --version | Out-Null
    }
    catch {
        & $VenvPython -m ensurepip --upgrade --default-pip
    }

    try {
        & $VenvPython -c "import socks" | Out-Null
    }
    catch {
        if (-not (Test-Path $PySocksWheelPath)) {
            & $Python -c "import pathlib, urllib.request; url='https://files.pythonhosted.org/packages/8d/59/b4572118e098ac8e46e399a1dd0f2d85403ce8bbaad9ec79373ed6badaf9/PySocks-1.7.1-py3-none-any.whl'; path=pathlib.Path(r'$PySocksWheelPath'); path.parent.mkdir(parents=True, exist_ok=True); opener=urllib.request.build_opener(urllib.request.ProxyHandler({})); path.write_bytes(opener.open(url, timeout=60).read())"
        }

        & $VenvPython -m pip install --no-index --no-deps $PySocksWheelPath
    }

    & $VenvPython -m pip install -r $RequirementsPath
}
finally {
    $env:PYTHONPATH = $PreviousPythonPath
    $env:TEMP = $PreviousTemp
    $env:TMP = $PreviousTmp

    if (Test-Path $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
