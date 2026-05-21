param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$WorkaroundPath = Join-Path $Root ".pip-workaround"
$SiteCustomizePath = Join-Path $WorkaroundPath "sitecustomize.py"

New-Item -ItemType Directory -Force -Path $WorkaroundPath | Out-Null

$SiteCustomize = @'
import os
import tempfile
import sys
import typing
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

if sys.version_info[:3] == (3, 14, 0):
    _eval_type = typing._eval_type

    def _eval_type_compat(t, globalns, localns, type_params=None, *, recursive_guard=frozenset(), **kwargs):
        return _eval_type(
            t,
            globalns,
            localns,
            type_params=type_params,
            recursive_guard=recursive_guard,
        )

    typing._eval_type = _eval_type_compat
'@

Set-Content -Path $SiteCustomizePath -Value $SiteCustomize -Encoding utf8

return $WorkaroundPath
