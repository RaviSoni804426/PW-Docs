<#
    PW Docs - build the Windows installer.

    Run after build.ps1 has completed successfully:

        powershell -File make_installer.ps1 -Version 1.0.0.0

    This drives the upstream packaging scripts rather than the CI pipeline in
    build_tools/scripts/package_desktop.py. That pipeline hardcodes its naming
    through package_branding.py and also wants S3 credentials, an AdvancedInstaller
    licence and a signing certificate, none of which apply here.

    Two steps:

      desktop-apps/package/make.ps1       stages build output into package/build/x64,
                                          splitting the help tree out of the app tree
      desktop-apps/package/make_inno.ps1  fetches the VC redist, writes package.config,
                                          and runs ISCC over common.iss

    make.ps1 derives its source path as
    build_tools/out/<platform>/<CompanyName>/<ProductName>, which follows the
    upstream branding names, not ours. Since we build without --branding-name,
    the output lands under "onlyoffice". So SourceDir is detected and passed
    explicitly, leaving CompanyName/ProductName free to carry the PW Docs
    naming that ends up in the installer filename.
#>
[CmdletBinding()]
param(
    [System.Version]$Version = "1.0.0.0",
    [string]$Arch = "x64",
    [string]$SourceDir
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$pkg = Join-Path $root 'desktop-apps\package'

$CompanyName = 'PW'
$ProductName = 'Docs'

if (-not $SourceDir) {
    $outRoot = Join-Path $root 'build_tools\out'
    if (-not (Test-Path $outRoot)) {
        throw "No build output at $outRoot - run build.ps1 first."
    }
    # The app tree is the directory containing the built executable.
    $exe = Get-ChildItem $outRoot -Recurse -Filter 'PWDocs.exe' -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if (-not $exe) {
        $exe = Get-ChildItem $outRoot -Recurse -Filter 'DesktopEditors.exe' -ErrorAction SilentlyContinue |
               Select-Object -First 1
    }
    if (-not $exe) {
        throw "Could not find PWDocs.exe (or DesktopEditors.exe) under $outRoot - the build did not finish."
    }
    $SourceDir = $exe.DirectoryName
}
Write-Host "SourceDir : $SourceDir" -ForegroundColor Cyan
Write-Host "Version   : $Version" -ForegroundColor Cyan

Push-Location $pkg
try {
    Write-Host "`n=== stage build output ===" -ForegroundColor Cyan
    & (Join-Path $pkg 'make.ps1') `
        -Version $Version -Arch $Arch `
        -CompanyName $CompanyName -ProductName $ProductName `
        -SourceDir $SourceDir
    if ($LASTEXITCODE) { throw "make.ps1 failed ($LASTEXITCODE)" }

    Write-Host "`n=== build Inno Setup package ===" -ForegroundColor Cyan
    & (Join-Path $pkg 'make_inno.ps1') `
        -Version $Version -Arch $Arch `
        -CompanyName $CompanyName -ProductName $ProductName
    if ($LASTEXITCODE) { throw "make_inno.ps1 failed ($LASTEXITCODE)" }
}
finally {
    Pop-Location
}

$installer = Get-ChildItem (Join-Path $pkg 'inno') -Filter '*.exe' |
             Where-Object { $_.Name -notlike 'vc_redist*' } |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($installer) {
    $outDir = Join-Path $root 'installer-output'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Copy-Item $installer.FullName $outDir -Force
    Write-Host ("`nInstaller: {0}  ({1:N1} MB)" -f `
        (Join-Path $outDir $installer.Name), ($installer.Length / 1MB)) -ForegroundColor Green
} else {
    throw "ISCC reported success but no installer .exe was produced."
}
