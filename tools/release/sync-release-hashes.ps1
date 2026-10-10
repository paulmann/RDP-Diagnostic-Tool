#Requires -Version 7.6
#Requires -PSEdition Core
<#
.SYNOPSIS
    Syncs the manifest hashes with the assets that are actually published.

.DESCRIPTION
    The release ZIP is not bit-reproducible: the launcher executable is built with the
    in-box C# 5 compiler, which embeds a fresh module GUID into every build. Rebuilding
    locally therefore yields a different hash than the file sitting in the GitHub release,
    and winget/Scoop would reject the download with "hash mismatch".

    This script removes that failure mode by reading the SHA256 of the published asset
    from the GitHub releases API and writing it into the winget and Scoop manifests. Run
    it after the release exists - it is the only correct source of the hash.

.EXAMPLE
    pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\release\sync-release-hashes.ps1
#>
[CmdletBinding()]
param(
    [string]$Repo = 'paulmann/RDP-Diagnostic-Tool',
    [string]$Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

if (-not $Version) {
    $scriptText = Get-Content -LiteralPath (Join-Path $repoRoot 'RDP-Tool.ps1') -Raw
    $match = [regex]::Match($scriptText, "\`$script:ToolVersion\s*=\s*\[version\]'(\d+\.\d+\.\d+)'")
    if (-not $match.Success) { throw 'Could not read $script:ToolVersion from RDP-Tool.ps1' }
    $Version = $match.Groups[1].Value
}

$zipName = "RDP-Diagnostic-Tool-$Version.zip"
$headers = @{ 'User-Agent' = 'RDP-Diagnostic-Tool-release-tooling'; Accept = 'application/vnd.github+json' }
$token = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'User')
if (-not [string]::IsNullOrWhiteSpace($token)) { $headers['Authorization'] = "Bearer $token" }

$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$Version" -Headers $headers -TimeoutSec 60
$asset = $release.assets | Where-Object { $_.name -eq $zipName } | Select-Object -First 1
if (-not $asset) { throw "Release $Version has no asset named $zipName" }

# The API reports the publisher's digest; fall back to downloading and hashing when absent.
$sha = $null
if ($asset.PSObject.Properties.Name -contains 'digest' -and $asset.digest -match '^sha256:([0-9a-f]{64})$') {
    $sha = $Matches[1].ToUpperInvariant()
}
if (-not $sha) {
    $tempFile = Join-Path ([IO.Path]::GetTempPath()) ("{0}.{1}.zip" -f $Version, [guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempFile -TimeoutSec 300
        $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $tempFile).Hash
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}

$utf8 = [System.Text.UTF8Encoding]::new($false)

$installerPath = Join-Path $repoRoot "winget\manifests\p\Paulmann\RDPDiagnosticTool\$Version\Paulmann.RDPDiagnosticTool.installer.yaml"
if (-not (Test-Path -LiteralPath $installerPath)) { throw "Missing manifest: $installerPath" }
$installer = Get-Content -LiteralPath $installerPath -Raw
$installer = [regex]::Replace($installer, '(?m)^InstallerSha256:.*$', "InstallerSha256: $sha")
[IO.File]::WriteAllText($installerPath, $installer, $utf8)

$scoopPath = Join-Path $repoRoot 'scoop\rdp-diagnostic-tool.json'
$scoop = Get-Content -LiteralPath $scoopPath -Raw | ConvertFrom-Json -AsHashtable
$scoop['hash'] = $sha.ToLowerInvariant()
[IO.File]::WriteAllText($scoopPath, (($scoop | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n", $utf8)

"version : $Version"
"asset   : $zipName"
"sha256  : $sha"
"updated : winget installer manifest + scoop manifest"
