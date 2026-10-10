# =============================================================================
#  Pester tests for RDP-Tool.ps1
#  Cross-platform: logic/AST tests run anywhere PowerShell 7 runs.
#  Functional CLI tests spawn the script in a child process (still safe:
#  only -Help/-Version/invalid-combination paths, which never touch the system).
#  Run:  Invoke-Pester ./tests
# =============================================================================
#Requires -Version 7.0

BeforeAll {
    $script:ToolPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'RDP-Tool.ps1')).Path
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ToolContent = Get-Content -Raw -LiteralPath $script:ToolPath

    $script:ParseErrors = $null
    $script:ParseTokens = $null
    $script:ToolAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:ToolPath, [ref]$script:ParseTokens, [ref]$script:ParseErrors)

    # Library mode: dot-source WITHOUT executing the main entry point.
    $env:RDPDIAG_LIB = '1'
    . $script:ToolPath
    Initialize-ConsoleEnvironment
    $script:IsAdmin = $false
}

Describe 'Script integrity' {
    It 'Parses without syntax errors' {
        $script:ParseErrors.Count | Should -Be 0
    }

    It 'Is saved as UTF-8 with BOM (Windows PowerShell/Notepad safe)' {
        $bytes = [System.IO.File]::ReadAllBytes($script:ToolPath)
        $bytes.Length | Should -BeGreaterThan 3
        $bytes[0] | Should -Be 0xEF
        $bytes[1] | Should -Be 0xBB
        $bytes[2] | Should -Be 0xBF
    }

    It 'Declares #Requires -Version 7.0' {
        $script:ToolContent | Should -Match '#Requires\s+-Version\s+7'
        $script:ToolContent | Should -Match '#Requires\s+-PSEdition\s+Core'
    }

    It 'Has a machine-readable version marker' {
        $v = Get-VersionFromScriptContent -Content $script:ToolContent
        $v | Should -Not -BeNullOrEmpty
        $v | Should -Be $script:ToolVersion
    }

    It 'Version marker matches the top CHANGELOG entry' -Skip:(-not (Test-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'CHANGELOG.md'))) {
        $changelogPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'CHANGELOG.md'
        $changelog = Get-Content -Raw $changelogPath
        $m = [regex]::Match($changelog, '##\s*\[(?<v>\d+\.\d+\.\d+)')
        $m.Success | Should -BeTrue
        [version]$m.Groups['v'].Value | Should -Be $script:ToolVersion
    }

    It 'Does not use deprecated/banned constructs' {
        $script:ToolContent | Should -Not -Match 'Get-WmiObject'
        $script:ToolContent | Should -Not -Match 'Invoke-Expression'
        $script:ToolContent | Should -Not -Match 'Enable-WindowsOptionalFeature\s+-Online\s+-FeatureName\s+["'']?RemoteDesktop-Server'
    }
}

Describe 'Comment-based help' {
    BeforeAll {
        $script:HelpAst = $script:ToolAst.GetHelpContent()
        $script:ParamNames = @($script:ToolAst.ParamBlock.Parameters |
            ForEach-Object { $_.Name.VariablePath.UserPath })
    }

    It 'Has SYNOPSIS and DESCRIPTION' {
        $help = Get-Help $script:ToolPath
        ($help.Synopsis | Out-String).Trim() | Should -Not -Be ''
        ($help.Description | Out-String) | Should -Match 'diagnostic'
    }

    It 'Documents every parameter' {
        $documented = @($script:HelpAst.Parameters.Keys)
        foreach ($p in $script:ParamNames) {
            $documented -contains $p | Should -BeTrue -Because "parameter '$p' must have a .PARAMETER entry"
        }
    }

    It 'Has at least 10 examples' {
        @($script:HelpAst.Examples).Count | Should -BeGreaterOrEqual 10
    }

    It 'Has at least one .LINK' {
        @($script:HelpAst.Links).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Parameter surface' {
    It 'Exposes the documented v5 parameter set' {
        $expected = @(
            'DiagnoseOnly', 'EnableRDP', 'DisableRDP', 'SetPort', 'DisableNLA', 'AddUser',
            'RestartServices', 'ForcePrivateNetwork', 'TestRdpTarget', 'TestExternal',
            'ShowSessions', 'SkipRebootCheck', 'SkipSlowChecks', 'ExportReport', 'ExportJson',
            'LogPath', 'NoBrowser', 'Quiet', 'NoColor', 'NoEmoji', 'CheckUpdate', 'Update',
            'UpdateSource', 'Elevate', 'Force', 'ShowVerbose', 'Version', 'Help'
        )
        $paramBlock = $script:ToolAst.ParamBlock
        $actual = @($paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        foreach ($e in $expected) {
            $actual -contains $e | Should -BeTrue -Because "-$e must exist"
        }
    }

    It 'Keeps the v4 -ChangePort alias on -SetPort with range validation' {
        $setPort = $script:ToolAst.ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -eq 'SetPort' }
        $setPort | Should -Not -BeNullOrEmpty
        ($setPort.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] -and $_.TypeName.Name -eq 'Alias' }).
            PositionalArguments.Value | Should -Contain 'ChangePort'
        $range = $setPort.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateRange' }
        $range | Should -Not -BeNullOrEmpty
    }

    It 'Supports ShouldProcess (-WhatIf/-Confirm)' {
        $cb = @($script:ToolAst.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' })
        $cb.Count | Should -BeGreaterThan 0
        # Bare flags parse into NamedArguments with an implicit $true value.
        $cb[0].NamedArguments.ArgumentName | Should -Contain 'SupportsShouldProcess'
    }

    It 'Exposes -Help under ?, h and ShowHelp aliases' {
        $helpParam = $script:ToolAst.ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -eq 'Help' }
        $aliases = ($helpParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Alias' }).PositionalArguments.Value
        $aliases | Should -Contain '?'
        $aliases | Should -Contain 'h'
        $aliases | Should -Contain 'ShowHelp'
    }
}

Describe 'RDP negotiation protocol logic' {
    It 'Builds a standards-compliant X.224 CR + RDP_NEG_REQ (19 bytes, TLS+CredSSP)' {
        $req = Get-RdpNegotiationRequestBytes
        $req.Length | Should -Be 19
        $req[0] | Should -Be 3                      # TPKT version
        ($req[2] -shl 8) -bor $req[3] | Should -Be 19  # TPKT big-endian length
        $req[4] | Should -Be 14                      # X.224 LI
        $req[5] | Should -Be 0xE0                    # Connection Request
        $req[11] | Should -Be 0x01                   # TYPE_RDP_NEG_REQ
        $req[12] | Should -Be 0x00                   # flags
        [BitConverter]::ToUInt16($req, 13) | Should -Be 8    # length (LE16)
        [BitConverter]::ToUInt32($req, 15) | Should -Be 3    # requestedProtocols: TLS | CredSSP
    }

    It 'Embeds the mstshash cookie before the negotiation request' {
        $req = Get-RdpNegotiationRequestBytes -Cookie 'testuser'
        $text = [System.Text.Encoding]::ASCII.GetString($req)
        $text | Should -Match 'Cookie: mstshash=testuser'
        $req[0] | Should -Be 3
        ($req[2] -shl 8) -bor $req[3] | Should -Be $req.Length
    }

    It 'Parses a CredSSP (NLA) negotiation response' {
        $cc = [byte[]](0x03, 0x00, 0x00, 0x13, 0x0E, 0xD0, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x02, 0x00, 0x08, 0x00, 0x02, 0x00, 0x00, 0x00)
        $p = ConvertFrom-RdpNegotiationResponse -Packet $cc
        $p.Type | Should -Be 'Response'
        $p.SelectedProtocol | Should -Be 2
    }

    It 'Parses a TLS negotiation response' {
        $cc = [byte[]](0x03, 0x00, 0x00, 0x13, 0x0E, 0xD0, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x02, 0x00, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00)
        $p = ConvertFrom-RdpNegotiationResponse -Packet $cc
        $p.Type | Should -Be 'Response'
        $p.SelectedProtocol | Should -Be 1
    }

    It 'Parses HYBRID_REQUIRED_BY_SERVER failure (NLA enforced)' {
        $cc = [byte[]](0x03, 0x00, 0x00, 0x13, 0x0E, 0xD0, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x03, 0x00, 0x08, 0x00, 0x05, 0x00, 0x00, 0x00)
        $p = ConvertFrom-RdpNegotiationResponse -Packet $cc
        $p.Type | Should -Be 'Failure'
        $p.FailureCode | Should -Be 5
        $p.FailureName | Should -BeLike 'HYBRID_REQUIRED*'
    }

    It 'Treats a bare X.224 CC (no negotiation) as Standard RDP security' {
        $cc = [byte[]](0x03, 0x00, 0x00, 0x0B, 0x06, 0xD0, 0x00, 0x00, 0x00, 0x00, 0x00)
        $p = ConvertFrom-RdpNegotiationResponse -Packet $cc
        $p.Type | Should -Be 'Response'
        $p.SelectedProtocol | Should -Be 0
    }

    It 'Rejects non-TPKT garbage (e.g. an HTTP response)' {
        $junk = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 404 Not Found`r`n`r`n")
        $p = ConvertFrom-RdpNegotiationResponse -Packet $junk
        $p.Type | Should -Be 'None'
    }
}

Describe 'Windows edition support matrix' {
    It 'Accepts RDP-capable client editions' {
        foreach ($e in @('Professional', 'ProfessionalN', 'ProfessionalWorkstation',
                'Enterprise', 'EnterpriseN', 'EnterpriseS', 'EnterpriseSN',
                'Education', 'EducationN', 'IoTEnterprise', 'ServerRdsh')) {
            $r = Test-RdpHostEditionSupported -EditionID $e -Caption "Windows ($e)" -ProductType 1
            $r.Supported | Should -BeTrue -Because "$e must support the RDP host role"
        }
    }

    It 'Rejects ALL Home/SE variants - including CoreN (v4 regression)' {
        foreach ($e in @('Core', 'CoreN', 'CoreSingleLanguage', 'CoreCountrySpecific',
                'Cloud', 'CloudE', 'CloudEdition', 'CloudEditionN')) {
            $r = Test-RdpHostEditionSupported -EditionID $e -Caption "Windows ($e)" -ProductType 1
            $r.Supported | Should -BeFalse -Because "$e must NOT be treated as RDP-capable"
        }
    }

    It 'Accepts servers and domain controllers regardless of edition string' {
        foreach ($pt in @(2, 3)) {
            $r = Test-RdpHostEditionSupported -EditionID 'ServerStandard' -Caption 'Windows Server 2022' -ProductType $pt
            $r.Supported | Should -BeTrue
        }
    }

    It 'Falls back to the caption when EditionID is empty' {
        (Test-RdpHostEditionSupported -EditionID '' -Caption 'Windows 11 Pro' -ProductType 1).Supported | Should -BeTrue
        (Test-RdpHostEditionSupported -EditionID '' -Caption 'Windows 11 Home' -ProductType 1).Supported | Should -BeFalse
    }
}

Describe 'Update engine' {
    It 'Parses the embedded version marker from real script content' {
        Get-VersionFromScriptContent -Content $script:ToolContent | Should -Be ([version]'5.0.1')
    }

    It 'Returns $null for content without a marker' {
        Get-VersionFromScriptContent -Content 'Write-Host "hello"' | Should -BeNullOrEmpty
    }

    It 'Accepts the current script as a valid download' {
        Test-DownloadedScriptIsValid -Content $script:ToolContent | Should -BeNullOrEmpty
        Test-DownloadedScriptIsValid -Content $script:ToolContent -ExpectedVersion $script:ToolVersion | Should -BeNullOrEmpty
    }

    It 'Handles the byte[] payload GitHub serves for release assets' {
        # Regression: release assets come back as application/octet-stream, so
        # Invoke-WebRequest yields .Content as [byte[]]. Passing it straight to the
        # [string] parameters failed with "Cannot convert value to type System.String"
        # and aborted -Update with exit code 99.
        $bytes = [System.IO.File]::ReadAllBytes($script:ToolPath)
        $normalized = ConvertTo-ScriptText -Content $bytes
        $normalized | Should -BeOfType [string]
        ($normalized -split "`n")[0] | Should -Not -BeLike "*$([char]0xFEFF)*"
        Get-VersionFromScriptContent -Content $normalized | Should -Be ([version]'5.0.1')
        Test-DownloadedScriptIsValid -Content $normalized -ExpectedVersion $script:ToolVersion | Should -BeNullOrEmpty

        $withoutBom = [byte[]]($bytes[3..($bytes.Length - 1)])
        Get-VersionFromScriptContent -Content (ConvertTo-ScriptText -Content $withoutBom) | Should -Be ([version]'5.0.1')
    }

    It 'Rejects empty, tiny and HTML payloads' {
        Test-DownloadedScriptIsValid -Content '' | Should -Not -BeNullOrEmpty
        Test-DownloadedScriptIsValid -Content 'x' | Should -Not -BeNullOrEmpty
        Test-DownloadedScriptIsValid -Content ('<!DOCTYPE html><html><body>404</body></html>' + (' ' * 30000)) | Should -Not -BeNullOrEmpty
    }

    It 'Rejects a version mismatch between release metadata and payload' {
        Test-DownloadedScriptIsValid -Content $script:ToolContent -ExpectedVersion ([version]'99.0.0') | Should -Not -BeNullOrEmpty
    }

    It 'Resolves a direct HTTPS -UpdateSource without network calls' {
        $r = Get-RemoteToolVersion -Source 'https://mirror.internal/tools/RDP-Tool.ps1'
        $r.Source | Should -Be 'direct-url'
        $r.DownloadUrl | Should -Be 'https://mirror.internal/tools/RDP-Tool.ps1'
    }

    It 'Resolves the live GitHub release (network)' -Tag 'Network' {
        $r = Get-RemoteToolVersion
        $r | Should -Not -BeNullOrEmpty
        $r.DownloadUrl | Should -Match '^https://'
        if ($r.Source -eq 'release') { $r.Version | Should -Not -BeNullOrEmpty }
    }
}

Describe 'CLI behavior (child process)' {
    BeforeAll {
        $script:pwsh = (Get-Process -Id $PID).Path
        function script:Invoke-ToolCli {
            param([string[]] $Arguments)
            # The child process must NOT inherit library mode - it has to run the real entry point.
            $saved = $env:RDPDIAG_LIB
            $env:RDPDIAG_LIB = $null
            try {
                $out = & $script:pwsh -NoProfile -ExecutionPolicy Bypass -File $script:ToolPath @Arguments *>&1 | Out-String
                return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
            } finally {
                $env:RDPDIAG_LIB = $saved
            }
        }
    }

    It '-Help prints the full reference and exits 0' {
        $r = Invoke-ToolCli @('-Help', '-NoEmoji', '-NoColor')
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match 'USAGE'
        $r.Output | Should -Match 'EXIT CODES'
        $r.Output | Should -Match '-TestRdpTarget'
    }

    It '-Version prints version info and exits 0' {
        $r = Invoke-ToolCli @('-Version', '-NoEmoji', '-NoColor')
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match 'Repository'
        $r.Output | Should -Match ([regex]::Escape($script:ToolVersion.ToString()))
    }

    It 'Rejects mutually exclusive modes with exit code 4' {
        $r = Invoke-ToolCli @('-EnableRDP', '-DisableRDP', '-NoEmoji')
        $r.ExitCode | Should -Be 4
        $r.Output | Should -Match 'Mutually exclusive'
    }

    It 'Rejects -DiagnoseOnly combined with mutating actions (exit 4)' {
        $r = Invoke-ToolCli @('-DiagnoseOnly', '-ForcePrivateNetwork', '-NoEmoji')
        $r.ExitCode | Should -Be 4
    }

    It 'Rejects out-of-range -SetPort at bind time (non-zero exit)' {
        $r = Invoke-ToolCli @('-SetPort', '80', '-NoEmoji')
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'SetPort'
    }

    It 'Exits 4 on unsupported platforms (non-Windows guard)' -Skip:($IsWindows) {
        $r = Invoke-ToolCli @('-NoEmoji')
        $r.ExitCode | Should -Be 4
        $r.Output | Should -Match 'UNSUPPORTED PLATFORM'
    }
}

Describe 'PSScriptAnalyzer gate' {
    It 'Reports zero Error/Warning findings with the project settings' -Skip:(-not (Get-Module PSScriptAnalyzer -ListAvailable)) {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        $settings = Join-Path $script:RepoRoot 'ScriptAnalyzerSettings.psd1'
        $findings = @(Invoke-ScriptAnalyzer -Path $script:ToolPath -Settings $settings)
        $findings | ForEach-Object { Write-Host ("  L{0} [{1}] {2}: {3}" -f $_.Line, $_.Severity, $_.RuleName, $_.Message) }
        $findings.Count | Should -Be 0
    }
}
