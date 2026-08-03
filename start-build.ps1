<#
    PW Docs - start the build so nothing that happens to this shell can kill it.

        powershell -File start-build.ps1            # build only
        powershell -File start-build.ps1 -Finish    # build, then package

    Two separate things can kill a long build, and they need different fixes:

    1. Process-tree teardown. A process started normally - including via
       Start-Process -NoNewWindow - stays inside the launching shell's job
       object, so Windows kills it when that shell goes away. This ended one
       run mid-way through the v8 fetch.

    2. Console signals. Creating the process through WMI escapes the job
       object but leaves it attached to the same console, so a Ctrl-C
       delivered there still reaches it. This ended a later run 50% of the way
       through the v8 compile - the log simply ends in "^C".

    Registering a scheduled task solves both: Task Scheduler owns the process,
    it has no console, and it is in no job object of ours.

    Progress:  Get-Content .\logs\build-<stamp>.log -Wait -Tail 20
    Status:    schtasks /query /tn PWDocsBuild
    Stop:      schtasks /end /tn PWDocsBuild
#>
[CmdletBinding()]
param(
    [switch]$Clean,
    # Also run make_installer.ps1 once the build succeeds.
    [switch]$Finish
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$taskName = 'PWDocsBuild'

$script = if ($Finish) { 'build-and-package.ps1' } else { 'build.ps1' }
$inner = '-NoProfile -ExecutionPolicy Bypass -File "{0}\{1}"' -f $root, $script
if ($Clean) { $inner += ' -Clean' }

# Two mechanisms, because the two failure modes need different escapes:
#
#   Win32_Process.Create  parents the process to WmiPrvSE, putting it outside
#                         this shell's job object.
#   cmd /c start          gives it a brand new console, so a Ctrl-C delivered
#                         to ours never reaches it.
#
# Task Scheduler would also cover both, and was tried: schtasks.exe silently
# refuses to start on battery power (DisallowStartIfOnBatteries), and while
# the ScheduledTasks cmdlets fix that, the task's nested
# powershell -> powershell -> python chain did not survive having no console
# at all - make.py got as far as `gn gen` and disappeared with nothing on
# either stream. This is simpler and is the arrangement that has actually run
# this build for hours.
$cmd = 'cmd.exe /c start "PWDocsBuild" /min cmd.exe /c "powershell.exe {0}"' -f $inner

$result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine      = $cmd
    CurrentDirectory = $root
}
if ($result.ReturnValue -ne 0) {
    throw "Win32_Process.Create failed with code $($result.ReturnValue)"
}

Write-Host "Build started (launcher pid $($result.ProcessId))." -ForegroundColor Green
Write-Host "It runs in its own console outside this shell's job object, so"
Write-Host "neither Ctrl-C here nor this session ending will stop it."
