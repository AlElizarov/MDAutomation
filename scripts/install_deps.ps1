param(
    [string]$Python = "python",
    [string]$VenvPath = ".venv",
    [string]$Requirements = "requirements.txt"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvFullPath = Join-Path $Root $VenvPath
$TmpPath = Join-Path $Root ".pip-tmp"
$DownloadPath = Join-Path $Root ".pip-download"
$WorkaroundPath = Join-Path $Root ".pip-workaround"
$SiteCustomizePath = Join-Path $WorkaroundPath "sitecustomize.py"
$RequirementsPath = Join-Path $Root $Requirements
$PySocksWheelPath = Join-Path $DownloadPath "PySocks-1.7.1-py3-none-any.whl"

if (-not (Test-Path $RequirementsPath)) {
    throw "Requirements file not found: $RequirementsPath"
}

New-Item -ItemType Directory -Force -Path $TmpPath, $DownloadPath, $WorkaroundPath | Out-Null

$SiteCustomize = @'
import os
import tempfile
import uuid


def _mkdtemp(suffix=None, prefix=None, dir=None):
    suffix = "" if suffix is None else suffix
    prefix = "tmp" if prefix is None else prefix
    base_dir = tempfile.gettempdir() if dir is None else dir

    for _ in range(100):
        path = os.path.abspath(os.path.join(base_dir, f"{prefix}{uuid.uuid4().hex}{suffix}"))
        try:
            os.mkdir(path)
        except FileExistsError:
            continue
        return path

    raise FileExistsError("could not create a unique temporary directory")


tempfile.mkdtemp = _mkdtemp
'@

Set-Content -Path $SiteCustomizePath -Value $SiteCustomize -Encoding utf8

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
