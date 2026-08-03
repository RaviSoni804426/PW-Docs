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

# Registered through the cmdlets rather than schtasks.exe because the defaults
# schtasks applies are wrong for a build this long, and silently so: it sets
# DisallowStartIfOnBatteries and StopIfGoingOnBatteries, so on a laptop running
# unplugged the task just sits at status "Queued" with last result 0 - it looks
# like it ran and succeeded instantly. It also caps ExecutionTimeLimit at 72h,
# which is fine, but the battery flags are not.
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $inner -WorkingDirectory $root
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::FromHours(12)) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable
# Deliberately not -RunLevel Highest: registering an elevated task needs admin,
# and the build has no need for elevation.
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Settings $settings `
    -Principal $principal | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "Build started as scheduled task '$taskName'." -ForegroundColor Green
Write-Host "It has no console and is outside this shell's job object, so neither"
Write-Host "Ctrl-C here nor this session ending will stop it."
