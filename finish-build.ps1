<#
    PW Docs - wait for the running build, then package it.

        powershell -File finish-build.ps1

    Attaches to the make.py started by start-build.ps1, waits for it to exit,
    and on success runs make_installer.ps1 so the whole thing completes without
    supervision. Writes logs/finish.log throughout.

    Launch this detached the same way as the build itself (see
    start-build.ps1), or it dies with the shell that started it.
#>
[CmdletBinding()]
param(
    [string]$Version = '1.0.0.0'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'finish.log'

function Say($msg) {
    $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $msg
    Write-Host $line
    Add-Content -Path $log -Value $line
}

Say "waiting for make.py"

$proc = Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
        Where-Object { $_.CommandLine -like '*make.py*' } |
        Select-Object -First 1

if (-not $proc) {
    Say "no make.py running - nothing to wait for"
    exit 1
}

Say "attached to make.py pid $($proc.ProcessId)"

# Poll rather than Wait-Process: the process is not our child, and its handle
# is not ours to wait on.
while (Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 30
}

Say "make.py exited"

# The build log is the source of truth for success - make.py's exit code is
# not observable from here.
$buildLog = Get-ChildItem $logDir -Filter 'build-*.log' |
            Where-Object { $_.Name -notmatch '\.err\.' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
$errLog = $buildLog.FullName -replace '\.log$', '.err.log'

if ((Test-Path $errLog) -and (Get-Item $errLog).Length -gt 0) {
    Say "BUILD FAILED - stderr in $errLog"
    Say (Get-Content $errLog -Tail 6 | Out-String)
    exit 1
}

$exe = Get-ChildItem (Join-Path $root 'build_tools\out') -Recurse -Filter 'PWDocs.exe' -ErrorAction SilentlyContinue |
       Select-Object -First 1
if (-not $exe) {
    $exe = Get-ChildItem (Join-Path $root 'build_tools\out') -Recurse -Filter 'DesktopEditors.exe' -ErrorAction SilentlyContinue |
           Select-Object -First 1
}
if (-not $exe) {
    Say "BUILD INCOMPLETE - no editor executable under build_tools/out"
    exit 1
}

Say "build produced $($exe.FullName)"
Say "running make_installer.ps1"

& (Join-Path $root 'make_installer.ps1') -Version $Version *>&1 |
    ForEach-Object { Add-Content -Path $log -Value $_; Write-Host $_ }

$installer = Get-ChildItem (Join-Path $root 'installer-output') -Filter '*.exe' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($installer) {
    Say ("DONE - installer: {0} ({1:N1} MB)" -f $installer.FullName, ($installer.Length / 1MB))
} else {
    Say "installer step finished but produced no .exe"
    exit 1
}
