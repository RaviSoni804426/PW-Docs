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

# Visual Studio 2019, which the Qt msvc2019_64 kit requires. This install is
# not in the default location, and that matters twice over:
#
#   - build_tools needs the vcvarsall directory, passed as --vs-path below.
#   - v8's build/vs_toolchain.py does its own detection and looks only at
#     %ProgramFiles(x86)%\Microsoft Visual Studio\<year>\<edition> plus the
#     vs<year>_install variable. With neither matching it fails 'gn gen' with
#     "No supported Visual Studio can be found", even though build_tools found
#     the compiler perfectly well. The 2022 Build Tools that *are* in the
#     default location do not help: v8 8.9 accepts only 2017 and 2019.
$VsRoot = 'C:\BuildTools2019'
$env:vs2019_install = $VsRoot

# v8's _CopyDebugger() hard-fails 'gn gen' if these two API-set stubs are
# missing from the SDK's Debuggers directory. They ship with the Windows SDK
# "Debugging Tools for Windows" feature, which is only partially installed here
# - dbghelp.dll and dbgcore.dll are present, the api-ms-win-* stubs are not.
#
# They are runtime companions for dbghelp.dll, needed when a binary in the
# output directory symbolizes its own stacks. We build v8 as a static
# monolithic library to link into core; nothing is ever run out of that
# directory, so their absence cannot affect the product. Marking them optional
# is the same kind of local build-environment patch v8_89.py already applies to
# this file. Idempotent, and re-applied here because a gclient sync restores
# the pristine copy.
$vsToolchain = Join-Path $root 'core\Common\3dParty\v8_89\v8\build\vs_toolchain.py'
if (Test-Path $vsToolchain) {
    $tc = Get-Content $vsToolchain -Raw
    $needle = "debug_files.extend([('api-ms-win-downlevel-kernel32-l2-1-0.dll', False),`n                        ('api-ms-win-eventing-provider-l1-1-0.dll', False)])"
    if ($tc.Contains("('api-ms-win-downlevel-kernel32-l2-1-0.dll', False)")) {
        $tc = $tc.Replace("('api-ms-win-downlevel-kernel32-l2-1-0.dll', False)",
                          "('api-ms-win-downlevel-kernel32-l2-1-0.dll', True)")
        $tc = $tc.Replace("('api-ms-win-eventing-provider-l1-1-0.dll', False)",
                          "('api-ms-win-eventing-provider-l1-1-0.dll', True)")
        Set-Content $vsToolchain $tc -NoNewline
        Write-Host "patched vs_toolchain.py: debugger API-set stubs made optional" -ForegroundColor Yellow
    }
}

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
        '--vs-path', (Join-Path $VsRoot 'VC\Auxiliary\Build')
    )
    Write-Host "configure: $($configureArgs -join ' ')" -ForegroundColor Cyan
    & python @configureArgs

    $errLog = [IO.Path]::ChangeExtension($log, '.err.log')
    Write-Host "make.py -> $log" -ForegroundColor Cyan
    # Note: this inherits whatever job object build.ps1 itself belongs to.
    # To survive the launching shell, start build.ps1 through start-build.ps1
    # rather than running it directly - see the comment there.
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
