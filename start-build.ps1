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

# Run as a scheduled task. Task Scheduler owns the process, so it is in no job
# object of ours and receives none of our console signals.
#
# Three simpler launchers were tried first and each died to something
# different:
#
#   Start-Process -NoNewWindow  stayed in the launching shell's job object;
#                               the shell going away killed it.
#   Win32_Process.Create        escaped the job object but shared our console,
#                               so Ctrl-C reached it.
#   WMI + cmd /c start          got its own console and still died with
#                               make.py exit 0x40010004 (DBG_CONTROL_C) -
#                               session teardown signals the whole process
#                               group, not just the console.
#
# An earlier attempt at this same approach failed for an unrelated reason:
# build.ps1 then launched make.py via Start-Process -NoNewWindow, which does
# not work when the parent has no console at all - make.py reached `gn gen`
# and vanished silently. build.ps1 now redirects through `cmd /c` instead, so
# that obstacle is gone.
#
# Registered through the cmdlets rather than schtasks.exe: schtasks defaults
# to DisallowStartIfOnBatteries, and on a laptop running unplugged the task
# then sits at "Queued" with last result 0 - indistinguishable from a task
# that ran and succeeded instantly.
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $inner -WorkingDirectory $root
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::FromHours(12)) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable
# Not -RunLevel Highest: registering an elevated task needs admin rights the
# build does not require.
$principal = New-ScheduledTaskPrincipal `
    -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Settings $settings `
    -Principal $principal | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "Build started as scheduled task '$taskName'." -ForegroundColor Green
Write-Host "Task Scheduler owns it, so neither this session ending nor a Ctrl-C"
Write-Host "delivered to our process group can reach it."
