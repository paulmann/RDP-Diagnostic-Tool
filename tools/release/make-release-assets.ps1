#Requires -Version 7.6
#Requires -PSEdition Core
<#
.SYNOPSIS
    Builds the GitHub release assets for RDP-Diagnostic-Tool.

.DESCRIPTION
    Produces, in dist/release:
      RDP-Tool.ps1                       - the asset the self-updater looks for by name
      RDP-Diagnostic-Tool-<ver>.zip      - portable bundle (script + cmd shim + docs)
      SHA256SUMS.txt                     - hashes of both assets

    The ZIP is what winget and manual installs consume; the loose script is what
    -CheckUpdate / -Update download.

.EXAMPLE
    pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\release\make-release-assets.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir = (Join-Path $PSScriptRoot '..\..\dist\release')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scriptPath = Join-Path $repoRoot 'RDP-Tool.ps1'

# Version is read from the shipped script so the assets can never disagree with it.
$scriptText = Get-Content -LiteralPath $scriptPath -Raw
$match = [regex]::Match($scriptText, "\`$script:ToolVersion\s*=\s*\[version\]'(\d+\.\d+\.\d+)'")
if (-not $match.Success) {
    throw "Could not read \$script:ToolVersion from $scriptPath"
}
$version = $match.Groups[1].Value

$OutDir = [IO.Path]::GetFullPath($OutDir)
if (Test-Path -LiteralPath $OutDir) {
    Remove-Item -LiteralPath $OutDir -Recurse -Force
}
$stage = Join-Path $OutDir 'stage'
$null = New-Item -ItemType Directory -Path $stage -Force

# The BOM in RDP-Tool.ps1 is load-bearing for Windows PowerShell 5.1 and Notepad:
# copy bytes, never re-encode.
Copy-Item -LiteralPath $scriptPath -Destination (Join-Path $stage 'RDP-Tool.ps1')
Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination $stage
Copy-Item -LiteralPath (Join-Path $repoRoot 'README.md') -Destination $stage

# Portable command shim. CRLF is mandatory here: cmd.exe does not run LF-only batch files.
$shim = @(
    '@echo off'
    'setlocal'
    'set "PWSH=pwsh"'
    'if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"'
    '"%PWSH%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0RDP-Tool.ps1" %*'
    'exit /b %ERRORLEVEL%'
) -join "`r`n"
[IO.File]::WriteAllText((Join-Path $stage 'rdp-tool.cmd'), $shim + "`r`n", [System.Text.UTF8Encoding]::new($false))

# Launcher executable. winget refuses script files (a .cmd cannot be a portable
# NestedInstallerFile), and an .exe also runs from any console without Node or a
# PowerShell execution-policy decision. Built with the in-box C# compiler.
$csc = @(
    (Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) {
    throw 'No in-box C# compiler (csc.exe) found; cannot build the launcher executable.'
}

$exePath = Join-Path $stage 'rdp-tool.exe'
$cscOut = & $csc /nologo /optimize+ /target:exe "/out:$exePath" (Join-Path $PSScriptRoot 'launcher\rdp-tool.cs') 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
    throw "Launcher compilation failed:`n$($cscOut -join "`n")"
}

$zipName = "RDP-Diagnostic-Tool-$version.zip"
$zipPath = Join-Path $OutDir $zipName
$exePathInStage = Join-Path $stage 'rdp-tool.exe'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stage -Recurse -Force

Copy-Item -LiteralPath $scriptPath -Destination (Join-Path $OutDir 'RDP-Tool.ps1')

$lines = @(
    "$((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $OutDir 'RDP-Tool.ps1')).Hash.ToLower())  RDP-Tool.ps1"
    "$((Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLower())  $zipName"
)
[IO.File]::WriteAllText((Join-Path $OutDir 'SHA256SUMS.txt'), ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))

"version  : $version"
"zip      : $zipPath"
"launcher : $exePathInStage (inside the ZIP)"
"SHA256   : $($lines[1].Split(' ')[0])"
