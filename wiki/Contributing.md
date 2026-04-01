<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Contributing

[[Home]] › Contributing

Thank you for considering a contribution to the RDP Diagnostic Tool! This page describes the development workflow, code standards, and pull request process.

---

## 🔄 Development Workflow

1. **Fork** the repository to your GitHub account
2. **Clone** your fork locally:
   ```powershell
   git clone https://github.com/YOUR_USERNAME/RDP-Diagnostic-Tool.git
   cd RDP-Diagnostic-Tool
   ```
3. **Create a feature branch** following the naming convention:
   ```powershell
   git checkout -b feature/add-quic-diagnostics
   # or: fix/credssp-null-reference
   # or: docs/update-wpr-guide
   ```
4. **Make your changes**, following the code standards below
5. **Test** thoroughly (see [Testing Requirements](#testing-requirements))
6. **Submit a Pull Request** to `main` using the PR template

---

## ✍️ Code Standards

### PowerShell Style Guide

```powershell
#Requires -Version 7.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
  Brief description of the function.

.DESCRIPTION
  Full description. Author: Mikhail Deynekin <mid1977@gmail.com>
  https://deynekin.com

.PARAMETER Target
  Hostname or IP of the RDP server to diagnose.

.EXAMPLE
  Invoke-RdpDiagnostic -Target "rdsh01.corp.local" -Mode Full
#>
function Invoke-RdpDiagnostic {
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Target,

    [ValidateSet('Quick', 'Full', 'Deep')]
    [string]$Mode = 'Full'
  )
  # Implementation
}
```

**Key rules:**
- Use `[CmdletBinding()]` and parameter validation on all public functions
- Follow `Verb-Noun` naming (use `Get-Verb` to validate verbs)
- Include `#Requires` at the top of every script
- No positional parameters beyond `Position = 0`
- Always use `$PSCmdlet.ShouldProcess()` for state-changing operations
- Minimum PowerShell 7.0 compatibility

---

## 🧪 Testing Requirements

All PRs must include Pester 5.x tests:

```powershell
# tests/RDP-Tool.Tests.ps1
Describe "Invoke-RdpDiagnostic" {
  Context "Quick Mode" {
    It "Should return a result object with OverallStatus" {
      $result = Invoke-RdpDiagnostic -Target localhost -Mode Quick -OutputFormat JSON | ConvertFrom-Json
      $result.overallStatus | Should -BeIn @('Pass', 'Warning', 'Critical')
    }

    It "Should complete within 60 seconds" {
      $elapsed = Measure-Command { Invoke-RdpDiagnostic -Target localhost -Mode Quick }
      $elapsed.TotalSeconds | Should -BeLessOrEqual 60
    }
  }
}

# Run tests
Invoke-Pester -Path .\tests\ -Output Detailed
```

> [!NOTE]
> Tests must pass on **PowerShell 7.0, 7.2, and 7.4** on **Windows Server 2019, 2022, and 2025**.

---

## 📝 Pull Request Template

When opening a PR, fill out:

- **What does this PR do?** — clear description of the change
- **Issue reference** — `Fixes #123` or `Closes #456`
- **Test coverage** — which Pester tests cover this change?
- **Breaking changes** — list any breaking parameter or output format changes
- **Checklist:**
  - [ ] Code follows style guide
  - [ ] Pester tests included and passing
  - [ ] CHANGELOG.md updated
  - [ ] Documentation (wiki) updated if needed
  - [ ] No secrets or credentials in code

---

## 🐛 Reporting Issues

- Use [GitHub Issues](https://github.com/paulmann/RDP-Diagnostic-Tool/issues)
- For **security vulnerabilities**, see [[Security#responsible-disclosure]] — do NOT use public issues
- Include: PowerShell version, OS version, error message, steps to reproduce

---

**Next:** [[Changelog]] →
