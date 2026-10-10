#Requires -Version 7.6
#Requires -PSEdition Core
<#
.SYNOPSIS
    Creates the GitHub release for the current version and uploads its assets.

.DESCRIPTION
    Runs the release-asset build, extracts the matching CHANGELOG section for the
    release notes and calls `gh release create` with the three assets the project
    depends on:

      RDP-Tool.ps1                       - downloaded by -CheckUpdate / -Update (matched by name)
      RDP-Diagnostic-Tool-<ver>.zip      - consumed by the winget and Scoop manifests
      SHA256SUMS.txt                     - integrity check for both

    Requires an authenticated GitHub CLI (`gh auth login`) with write access to the
    repository. The tag is created at the current HEAD unless it already exists.

.EXAMPLE
    pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\release\publish-release.ps1
.EXAMPLE
    pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\release\publish-release.ps1 -Draft
#>
[CmdletBinding()]
param(
    [switch]$Draft,
    [switch]$Prerelease
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) not found. Install it, then run: gh auth login'
}
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated. Run: gh auth login'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

# Build (or refresh) the assets first: the manifests and the checksums must match
# exactly what is uploaded.
& (Join-Path $PSScriptRoot 'make-release-assets.ps1') | Out-Null

$scriptText = Get-Content -LiteralPath (Join-Path $repoRoot 'RDP-Tool.ps1') -Raw
$match = [regex]::Match($scriptText, "\`$script:ToolVersion\s*=\s*\[version\]'(\d+\.\d+\.\d+)'")
if (-not $match.Success) { throw 'Could not read $script:ToolVersion from RDP-Tool.ps1' }
$version = $match.Groups[1].Value

$releaseDir = Join-Path $repoRoot 'dist\release'
$assets = @(
    (Join-Path $releaseDir 'RDP-Tool.ps1')
    (Join-Path $releaseDir "RDP-Diagnostic-Tool-$version.zip")
    (Join-Path $releaseDir 'SHA256SUMS.txt')
)
foreach ($asset in $assets) {
    if (-not (Test-Path -LiteralPath $asset)) { throw "Missing release asset: $asset" }
}

# Release notes: the CHANGELOG section for this version, if present.
$notesFile = Join-Path $releaseDir 'release-notes.md'
$changelog = Get-Content -LiteralPath (Join-Path $repoRoot 'CHANGELOG.md') -Raw
$section = [regex]::Match(
    $changelog,
    "(?ms)^##\s*\[$([regex]::Escape($version))\][^\r\n]*\r?\n(.*?)(?=^##\s*\[|\z)")
$notes = if ($section.Success) {
    "RDP Diagnostic & Remediation Tool v$version`n`n" + $section.Groups[1].Value.Trim() + "`n"
} else {
    "RDP Diagnostic & Remediation Tool v$version`n"
}
[IO.File]::WriteAllText($notesFile, $notes, [System.Text.UTF8Encoding]::new($false))

# A release replaces the previous "latest", which is what the self-updater reads.
$gitArgs = @('release', 'create', $version, '--title', "RDP Diagnostic & Remediation Tool v$version", '--notes-file', $notesFile)
if ($Draft) { $gitArgs += '--draft' }
if ($Prerelease) { $gitArgs += '--prerelease' }
$gitArgs += $assets

& gh @gitArgs
if ($LASTEXITCODE -ne 0) { throw "gh release create failed with exit code $LASTEXITCODE" }

"release : $version"
"assets  : $($assets.Count)"
& gh release view $version --json tagName,isDraft,isPrerelease,assets --jq 'tag={{.tagName}} draft={{.isDraft}} prerelease={{.isPrerelease}} assets={{.assets | length}}'
