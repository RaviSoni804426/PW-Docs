<#
    PW Docs - build, then package, in one unattended run.

    Launched by start-build.ps1 -Finish as a scheduled task. Running both
    steps inside a single task is what makes the handoff reliable: the earlier
    approach polled for make.py from a separate process, which meant the
    packaging step had no way to see make.py's exit code and died along with
    its own launcher.
#>
[CmdletBinding()]
param(
    [switch]$Clean,
    [string]$Version = '1.0.0.0'
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'finish.log'

function Say($msg) {
    Add-Content -Path $log -Value ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $msg)
}

Say "=== build starting ==="

# build.ps1 blocks until make.py finishes and exits with its code. Only -Clean
# is forwarded: -Version belongs to the packaging step, and splatting the whole
# bound-parameter set would hand build.ps1 an argument it does not declare.
if ($Clean) { & (Join-Path $root 'build.ps1') -Clean } else { & (Join-Path $root 'build.ps1') }
$code = $LASTEXITCODE

if ($code -ne 0) {
    Say "BUILD FAILED (make.py exit $code)"
    exit $code
}
Say "build finished cleanly"

$exe = Get-ChildItem (Join-Path $root 'build_tools\out') -Recurse -Filter 'PWDocs.exe' -ErrorAction SilentlyContinue |
       Select-Object -First 1
if (-not $exe) {
    Say "BUILD INCOMPLETE - no PWDocs.exe under build_tools/out"
    exit 1
}
Say "produced $($exe.FullName)"

Say "=== packaging ==="
& (Join-Path $root 'make_installer.ps1') -Version $Version *>&1 |
    ForEach-Object { Add-Content -Path $log -Value $_ }

$installer = Get-ChildItem (Join-Path $root 'installer-output') -Filter '*.exe' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($installer) {
    Say ("DONE - installer: {0} ({1:N1} MB)" -f $installer.FullName, ($installer.Length / 1MB))
} else {
    Say "PACKAGING FAILED - no installer produced"
    exit 1
}
