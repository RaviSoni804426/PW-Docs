<#
    PW Docs - finish an interrupted v8 checkout.

        powershell -File fix-v8-sync.ps1

    v8_89.py does its fetch AND its sync inside one guard:

        if not base.is_dir("v8"):
            fetch v8
            gclient sync -r remotes/branch-heads/8.9
            gclient sync --force
            copy third_party_new/ninja -> third_party/ninja

    So the moment the v8 directory exists the whole block is skipped -
    including the sync. If a run is interrupted after `fetch` but before the
    syncs finish, every later run silently skips the remaining work and then
    dies at `gn gen` with:

        gn.py: Could not find gn executable at: v8\buildtools\win\gn.exe

    because gn is pulled down by the sync hooks that never ran. The checkout
    itself is fine, so re-fetching 2.7 GB is unnecessary - this runs just the
    steps the guard skipped.

    The alternative recovery is to delete v8_89/v8 entirely and rerun
    build.ps1, which is simpler but re-downloads the whole checkout.
#>
$ErrorActionPreference = 'Stop'

$v8Root = Join-Path $PSScriptRoot 'core\Common\3dParty\v8_89'
$depot = Join-Path $v8Root 'depot_tools'

if (-not (Test-Path (Join-Path $v8Root 'v8'))) {
    throw "No v8 checkout at $v8Root\v8 - just run build.ps1, it will fetch from scratch."
}

# Same environment v8_89.py sets up before it shells out.
$env:NoDefaultCurrentDirectoryInExePath = $null
$env:PYTHONUNBUFFERED = '1'
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
$env:GYP_MSVS_VERSION = '2019'
$env:PATH = "$depot;$env:PATH"

# A killed run leaves lock files behind; depot_tools only cleans them up on a
# clean exit, and a stale one fails with ERROR_INVALID_HANDLE next time.
Get-ChildItem $v8Root -Recurse -Force -Filter '*.locked' -ErrorAction SilentlyContinue |
    ForEach-Object {
        Write-Host "removing stale lock: $($_.Name)" -ForegroundColor Yellow
        Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
    }

Push-Location $v8Root
try {
    Write-Host "`n=== gclient sync -r remotes/branch-heads/8.9 ===" -ForegroundColor Cyan
    & "$depot\gclient.bat" sync -r remotes/branch-heads/8.9

    Write-Host "`n=== gclient sync --force ===" -ForegroundColor Cyan
    & "$depot\gclient.bat" sync --force

    # v8_89.py stashes the pre-sync third_party aside as third_party_new and
    # restores its ninja afterwards, because the synced tree does not carry a
    # usable one on Windows.
    $ninjaSrc = Join-Path $v8Root 'v8\third_party_new\ninja'
    $ninjaDst = Join-Path $v8Root 'v8\third_party\ninja'
    if ((Test-Path $ninjaSrc) -and -not (Test-Path $ninjaDst)) {
        Write-Host "`nrestoring third_party/ninja" -ForegroundColor Cyan
        Copy-Item $ninjaSrc $ninjaDst -Recurse -Force
    }
}
finally {
    Pop-Location
}

Write-Host "`n=== result ===" -ForegroundColor Cyan
foreach ($p in @('v8\buildtools\win\gn.exe', 'v8\third_party\ninja', '.gclient_entries')) {
    "{0,-6} {1}" -f (Test-Path (Join-Path $v8Root $p)), $p
}
