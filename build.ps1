<#
    PW Docs - desktop build driver.

    Usage:  powershell -File build.ps1 [-Clean]

    Why this script exists rather than calling make.py directly:

    ONLYOFFICE's build_tools invokes several third-party build steps by bare
    filename from the working directory - boost's `bootstrap.bat` and `b2.exe`,
    among others - via subprocess with shell=True (scripts/base.py, `cmd()`).
    That relies on cmd.exe resolving executables from the current directory.

    When the environment defines NoDefaultCurrentDirectoryInExePath=1 (a
    common Windows hardening setting, and the default in some CI and sandboxed
    shells) cmd.exe stops searching the current directory, and every one of
    those calls dies with:

        'bootstrap.bat' is not recognized as an internal or external command

    even though the file is sitting right there. Clearing the variable for the
    build process - and therefore for everything it spawns - restores the
    lookup the upstream scripts assume.

    A note on how make.py is launched:

    The build runs for hours. Piping it through Tee-Object ties its lifetime
    to the launching console - when that console goes away the pipe breaks,
    the log stops growing, and make.py is left running blind with its output
    going nowhere. So make.py is started detached with its stdout and stderr
    redirected straight to files by the OS. The log keeps filling regardless
    of what happens to whatever started the build, and progress can be
    followed with:

        Get-Content .\logs\build-<stamp>.log -Wait -Tail 20
#>
[CmdletBinding()]
param(
    [switch]$Clean,
    # Return once make.py has been started instead of waiting for it to finish.
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# See the comment block above - without this the 3dParty stage cannot run.
$env:NoDefaultCurrentDirectoryInExePath = $null

# Redirected stdout is a pipe rather than a console, so Python block-buffers it
# and the log sits empty for a long time. Unbuffer it so progress is visible
# while the build runs, and so a crash does not take the tail of the log with it.
$env:PYTHONUNBUFFERED = '1'

$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir ("build-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

Push-Location (Join-Path $root 'build_tools')
try {
    $configureArgs = @(
        'configure.py'
        '--module', 'desktop'
        '--platform', 'win_64'
        '--update', '0'            # never re-clone: it would discard the PW Docs changes
        '--clean', $(if ($Clean) { '1' } else { '0' })
        '--qt-dir', 'C:\Qt\5.15.2'
        '--vs-version', '2019'     # matches the Qt msvc2019_64 kit
        '--vs-path', 'C:\BuildTools2019\VC\Auxiliary\Build'
    )
    Write-Host "configure: $($configureArgs -join ' ')" -ForegroundColor Cyan
    & python @configureArgs

    $errLog = [IO.Path]::ChangeExtension($log, '.err.log')
    Write-Host "make.py -> $log" -ForegroundColor Cyan
    $proc = Start-Process -FilePath 'python' -ArgumentList 'make.py' `
        -RedirectStandardOutput $log -RedirectStandardError $errLog `
        -NoNewWindow -PassThru
    Write-Host ("make.py pid: {0}" -f $proc.Id) -ForegroundColor Cyan
}
finally {
    Pop-Location
}

if ($NoWait) {
    Write-Host "started detached; follow with: Get-Content `"$log`" -Wait -Tail 20"
    exit 0
}

$proc.WaitForExit()
$code = $proc.ExitCode
Write-Host ("make.py exit code: {0}" -f $code) -ForegroundColor $(if ($code -eq 0) { 'Green' } else { 'Red' })
Write-Host "log: $log"
exit $code
