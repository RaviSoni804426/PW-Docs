<#
    PW Docs - start the build so it survives the shell that launched it.

        powershell -File start-build.ps1

    Why this is not just "run build.ps1":

    The build takes hours. A process started normally - including via
    Start-Process -NoNewWindow - stays inside the launching shell's process
    tree and job object, so when that shell goes away (terminal closed, agent
    session torn down, SSH dropped) Windows kills the whole tree with it. That
    happened once mid-way through the v8 stage: the git clone was killed, then
    gclient sat stalled for five minutes before v8_89.py died on
    os.chdir("v8") because the checkout it expected was never finished.

    Creating the process through WMI instead parents it to WmiPrvSE rather
    than to us, so it is outside our job object and outlives the session.

    Progress:  Get-Content .\logs\build-<stamp>.log -Wait -Tail 20
    Stop:      Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
                 Where-Object CommandLine -like '*make.py*' |
                 ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
#>
[CmdletBinding()]
param(
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}\build.ps1"' -f $root
if ($Clean) { $cmd += ' -Clean' }

$result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine      = $cmd
    CurrentDirectory = $root
}

if ($result.ReturnValue -ne 0) {
    throw "Win32_Process.Create failed with code $($result.ReturnValue)"
}

Write-Host "Build started detached, pid $($result.ProcessId)" -ForegroundColor Green
Write-Host "It is parented to WmiPrvSE and will keep running after this shell exits."
