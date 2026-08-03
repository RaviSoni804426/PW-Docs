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
#>
[CmdletBinding()]
param(
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# See the comment block above - without this the 3dParty stage cannot run.
$env:NoDefaultCurrentDirectoryInExePath = $null

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

    Write-Host "make.py -> $log" -ForegroundColor Cyan
    & python make.py 2>&1 | Tee-Object -FilePath $log
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

Write-Host ("make.py exit code: {0}" -f $code) -ForegroundColor $(if ($code -eq 0) { 'Green' } else { 'Red' })
Write-Host "log: $log"
exit $code
