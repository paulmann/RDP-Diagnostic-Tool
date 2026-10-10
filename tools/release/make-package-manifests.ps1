#Requires -Version 7.6
#Requires -PSEdition Core
<#
.SYNOPSIS
    Generates the winget manifests and the Scoop manifest for the current version.

.DESCRIPTION
    Reads the version from RDP-Tool.ps1 and the SHA256 of the release ZIP produced by
    make-release-assets.ps1, then writes:

      winget/manifests/p/Paulmann/RDPDiagnosticTool/<ver>/Paulmann.RDPDiagnosticTool.installer.yaml
      winget/manifests/p/Paulmann/RDPDiagnosticTool/<ver>/Paulmann.RDPDiagnosticTool.locale.en-US.yaml
      winget/manifests/p/Paulmann/RDPDiagnosticTool/<ver>/Paulmann.RDPDiagnosticTool.yaml
      scoop/rdp-diagnostic-tool.json

    Generating rather than hand-editing keeps the version and hash in one place:
    the release ZIP is the single source of truth for both.

.EXAMPLE
    pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\release\make-package-manifests.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scriptPath = Join-Path $repoRoot 'RDP-Tool.ps1'

$scriptText = Get-Content -LiteralPath $scriptPath -Raw
$match = [regex]::Match($scriptText, "\`$script:ToolVersion\s*=\s*\[version\]'(\d+\.\d+\.\d+)'")
if (-not $match.Success) { throw "Could not read \$script:ToolVersion from $scriptPath" }
$version = $match.Groups[1].Value

$zipName = "RDP-Diagnostic-Tool-$version.zip"
$zipPath = Join-Path $repoRoot "dist\release\$zipName"
if (-not (Test-Path -LiteralPath $zipPath)) {
    throw "Release ZIP not found: $zipPath - run make-release-assets.ps1 first."
}
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToUpperInvariant()

$releaseUrl = "https://github.com/paulmann/RDP-Diagnostic-Tool/releases/download/$version/$zipName"
$sumsUrl = "https://github.com/paulmann/RDP-Diagnostic-Tool/releases/download/$version/SHA256SUMS.txt"
$utf8 = [System.Text.UTF8Encoding]::new($false)

$manifestVersion = '1.6.0'
$pkgId = 'Paulmann.RDPDiagnosticTool'

# ---------------------------------------------------------------- winget
$wingetDir = Join-Path $repoRoot "winget\manifests\p\Paulmann\RDPDiagnosticTool\$version"
$null = New-Item -ItemType Directory -Path $wingetDir -Force

$installer = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.$manifestVersion.schema.json
PackageIdentifier: $pkgId
PackageVersion: $version
Platform:
  - Windows.Desktop
MinimumOSVersion: 10.0.17763.0
InstallerType: zip
NestedInstallerType: portable
NestedInstallerFiles:
  - RelativeFilePath: rdp-tool.exe
    PortableCommandAlias: rdp-tool
InstallModes:
  - interactive
  - silent
  - silentWithProgress
UpgradeBehavior: install
Commands:
  - rdp-tool
Installers:
  - Architecture: x64
    InstallerUrl: $releaseUrl
    InstallerSha256: $sha
ManifestType: installer
ManifestVersion: $manifestVersion
"@
[IO.File]::WriteAllText((Join-Path $wingetDir "$pkgId.installer.yaml"), $installer, $utf8)

$locale = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.defaultLocale.$manifestVersion.schema.json
PackageIdentifier: $pkgId
PackageVersion: $version
PackageLocale: en-US
Publisher: Mikhail Deynekin
PublisherUrl: https://github.com/paulmann
PublisherSupportUrl: https://github.com/paulmann/RDP-Diagnostic-Tool/issues
Author: Mikhail Deynekin
PackageName: RDP Diagnostic & Remediation Tool
PackageUrl: https://github.com/paulmann/RDP-Diagnostic-Tool
License: MIT
LicenseUrl: https://github.com/paulmann/RDP-Diagnostic-Tool/blob/main/LICENSE
Copyright: Copyright (c) 2025-2026 Mikhail Deynekin
ShortDescription: Diagnose, repair and verify Remote Desktop (RDP) on Windows, without an interpreter.
Description: >-
  RDP Diagnostic & Remediation Tool inspects every RDP component on a Windows machine -
  OS edition support, registry and Group Policy configuration, listener state, services,
  firewall rules, network profiles, TLS certificate, user rights, sessions and
  RDP-related event logs - and repairs common misconfigurations safely behind
  -WhatIf/-Confirm. It also performs a real X.224/RDP negotiation handshake against any
  host to prove the listener answers and to detect whether TLS or CredSSP (NLA) is
  required, and exports JSON and HTML reports. Requires PowerShell 7 (pwsh), which winget
  reports as a dependency-free prerequisite - install it with
  'winget install Microsoft.PowerShell'.
Moniker: rdp-tool
Tags:
  - rdp
  - remote-desktop
  - windows-server
  - diagnostics
  - troubleshooting
  - sysadmin
  - powershell
ReleaseNotesUrl: https://github.com/paulmann/RDP-Diagnostic-Tool/blob/main/CHANGELOG.md
ManifestType: defaultLocale
ManifestVersion: $manifestVersion
"@
[IO.File]::WriteAllText((Join-Path $wingetDir "$pkgId.locale.en-US.yaml"), $locale, $utf8)

$versionManifest = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.$manifestVersion.schema.json
PackageIdentifier: $pkgId
PackageVersion: $version
DefaultLocale: en-US
ManifestType: version
ManifestVersion: $manifestVersion
"@
[IO.File]::WriteAllText((Join-Path $wingetDir "$pkgId.yaml"), $versionManifest, $utf8)

# ---------------------------------------------------------------- scoop
$scoopDir = Join-Path $repoRoot 'scoop'
$null = New-Item -ItemType Directory -Path $scoopDir -Force

$scoop = [ordered]@{
    version      = $version
    description  = 'Diagnose, repair and verify Remote Desktop (RDP) on Windows (requires PowerShell 7)'
    homepage     = 'https://github.com/paulmann/RDP-Diagnostic-Tool'
    license      = 'MIT'
    url          = $releaseUrl
    hash         = $sha.ToLowerInvariant()
    bin          = @(, @('rdp-tool.exe', 'rdp-tool'))
    checkver     = @{ github = 'https://github.com/paulmann/RDP-Diagnostic-Tool' }
    autoupdate   = @{
        url  = "https://github.com/paulmann/RDP-Diagnostic-Tool/releases/download/`$version/RDP-Diagnostic-Tool-`$version.zip"
        hash = @{ url = $sumsUrl }
    }
}
[IO.File]::WriteAllText(
    (Join-Path $scoopDir 'rdp-diagnostic-tool.json'),
    (($scoop | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n",
    $utf8
)

"version  : $version"
"sha256   : $sha"
"winget   : $wingetDir"
"scoop    : $(Join-Path $scoopDir 'rdp-diagnostic-tool.json')"
