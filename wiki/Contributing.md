<!-- Last Updated: 2026-10-09 | Version: 5.0.0 -->

# Contributing

[[Home]] › Contributing

Thanks for considering a contribution! This project is a **single-file PowerShell
tool** (`RDP-Tool.ps1`) with a Pester test-suite, a PSScriptAnalyzer gate and
GitHub Actions CI. Everything below runs on Windows and (for the logic tests)
cross-platform.

---

## 🧰 Development Setup

```powershell
git clone https://github.com/paulmann/RDP-Diagnostic-Tool
cd RDP-Diagnostic-Tool

# Tooling (one-time)
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.0
```

### Library mode (dot-source without executing)

The script exposes a test hook: when `$env:RDPDIAG_LIB` is set, it only defines
functions and runs no actions:

```powershell
$env:RDPDIAG_LIB = '1'
. .\RDP-Tool.ps1
Initialize-ConsoleEnvironment
Get-RdpNegotiationRequestBytes            # inspect the protocol codec
Test-RdpHostEditionSupported -EditionID 'CoreN' -Caption 'Windows 11 Home N' -ProductType 1
```

---

## ✅ Validation Loop (same gates as CI)

```powershell
# 1) Syntax
$e=$null;$t=$null; [System.Management.Automation.Language.Parser]::ParseFile("$PWD\RDP-Tool.ps1",[ref]$t,[ref]$e); $e

# 2) Lint (zero Error/Warning findings required)
Invoke-ScriptAnalyzer -Path .\RDP-Tool.ps1 -Settings .\ScriptAnalyzerSettings.psd1

# 3) Tests
Invoke-Pester .\tests -Output Detailed
```

CI: [`.github/workflows/ci.yml`](https://github.com/paulmann/RDP-Diagnostic-Tool/blob/main/.github/workflows/ci.yml)
runs all three on `windows-latest` (plus a parse gate on `ubuntu-latest`) for
every push and PR.

---

## 📐 Code Conventions

- **Strict mode**: the script runs under `Set-StrictMode -Version 2.0` - never
  reference possibly-missing properties; use the helpers `Get-RegistryValue` /
  `Test-RegistryValueExists`.
- **State**: `$script:` scope only (no `$global:`). Results flow through
  `New-DiagnosticResult` / `New-RemediationRecord` / `New-TestRecord` - these
  must emit nothing to the success stream.
- **Checks**: every new check is a `Test-*`/`Get-*` function invoked through
  `Invoke-Check` so failures are isolated; add a `Category` and an actionable
  `Remedy` string to every non-OK result.
- **Mutations**: put them in the Remediation region, make them
  `SupportsShouldProcess` (`ConfirmImpact='High'` for destructive ones), GPO-aware
  (skip + explain when a policy manages the value), idempotent, and record them
  via `New-RemediationRecord`.
- **No** `Invoke-Expression`, `Get-WmiObject`, English-only firewall/group names
  (use internal rule names / well-known SIDs), or hard-coded exit paths - extend
  `$script:ExitCode`.
- **Console output** goes through `Show-Line` / `Show-Section` (Quiet/NoColor/
  NoEmoji aware). Keep lines < 100 chars.
- **Help**: any new parameter needs a `.PARAMETER` block, an entry in
  `Show-ToolHelp`, the README reference table and a test in
  `tests/RDP-Tool.Tests.ps1` (the "documents every parameter" test enforces it).

---

## 🧪 Adding Tests

`tests/RDP-Tool.Tests.ps1` groups:

| Describe | Scope | Platform |
|---|---|---|
| Script integrity | parse, BOM, `#Requires`, version marker ↔ CHANGELOG | any |
| Comment-based help | `.PARAMETER` coverage, examples, links | any |
| Parameter surface | expected switches, aliases, validation attributes | any |
| RDP negotiation protocol logic | byte-level codec fixtures | any |
| Windows edition support matrix | regression guard (e.g. `CoreN` = Home) | any |
| Update engine | marker parsing, payload validation, sources | any (+network-tagged live probe) |
| CLI behavior | child-process exit codes for `-Help`, conflicts, bind errors | any |
| PSScriptAnalyzer gate | zero findings | any (skips when module absent) |

Prefer **pure-logic tests** (fixtures/AST) over environment-dependent ones;
Windows-only behavior belongs in CI on `windows-latest`.

---

## 🚀 Release Checklist (maintainers)

1. Bump `$script:ToolVersion` (keep the literal `[version]'x.y.z'` format - the
   updater parses it remotely).
2. Sync the `.NOTES` version in the comment help and the README badge.
3. Add the `CHANGELOG.md` entry **on top** (a test compares it with the marker).
4. CI green on `main`.
5. Publish a GitHub Release with tag `x.y.z` (the updater reads `releases/latest`;
   a `v` prefix is tolerated). Optionally attach `RDP-Tool.ps1` as an asset -
   assets are preferred over tagged raw files.
6. Smoke-test the upgrade path: from the previous version run
   `.\RDP-Tool.ps1 -CheckUpdate` (expect exit `5`) then `-Update` (backup + replace).

---

## 🐞 Reporting Issues

Include:
- `.\RDP-Tool.ps1 -Version` output
- a reproduction command line
- `-ExportReport report.html` + `-LogPath run.log` files (they contain no credentials)
- OS build (`winver`) and whether Group Policies manage RDP

## 💡 Ideas / Roadmap

See [[Enhancement-Roadmap]] - high-value candidates: Authenticode-signed releases
with checksum assets, `-Targets` multi-host sweep over Remoting, RD Gateway
profile checks, QUIC transport diagnostics.

---

## Pull Request Process

1. Fork → branch `feature/<name>` or `fix/<name>`
2. Implement + tests + docs (README/wiki when user-visible)
3. Validation loop green locally; CI green on the PR
4. One review from a maintainer; squash-merge to `main`

*License: by contributing you agree your contributions are MIT-licensed.*
