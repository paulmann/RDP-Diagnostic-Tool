# RDP Diagnostic & Remediation Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell&logoColor=white)](https://docs.microsoft.com/en-us/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11%20%7C%20Server-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/en-us/windows/)
[![CI](https://github.com/paulmann/RDP-Diagnostic-Tool/actions/workflows/ci.yml/badge.svg)](https://github.com/paulmann/RDP-Diagnostic-Tool/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-5.0.0-success.svg)](https://github.com/paulmann/RDP-Diagnostic-Tool/releases/latest)

**A comprehensive PowerShell-based diagnostic and remediation tool for Remote Desktop Protocol (RDP) connectivity on Windows 10/11 and Windows Server.** One script, zero dependencies: it audits every RDP-related subsystem, repairs what it finds, proves the RDP stack actually answers with a real protocol handshake, and exports HTML/JSON reports for humans and automation alike.

## 📋 Table of Contents

- [What's new in v5](#whats-new-in-v5)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Features](#features)
- [Command-Line Reference](#command-line-reference)
- [Command Examples](#command-examples)
- [The RDP Protocol Handshake Probe](#the-rdp-protocol-handshake-probe)
- [Auto-Update](#auto-update)
- [Reporting & Automation](#reporting--automation)
- [Exit Codes](#exit-codes)
- [Supported Windows Editions](#supported-windows-editions)
- [Architecture & Design](#architecture--design)
- [Safety Model](#safety-model)
- [Development & CI](#development--ci)
- [Releasing (Maintainers)](#releasing-maintainers)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## What's new in v5

v5.0.0 is a full production refactor of v4.2.0. Highlights (see [CHANGELOG.md](CHANGELOG.md) for the complete list):

| Area | v5.0.0 |
|---|---|
| **Help** | Comprehensive built-in `-Help` + full comment-based help (`Get-Help -Full`) |
| **Updates** | `-CheckUpdate` / `-Update` / `-UpdateSource` - GitHub-release-backed self-update with validation & backups |
| **Diagnostics** | Real X.224/RDP negotiation handshake (`-TestRdpTarget`), TLS certificate audit, GPO overlay detection, session lifecycle & brute-force event mining, Public-profile firewall gap detection |
| **Actions** | `-DisableRDP`, `-AddUser`, `-RestartServices`, `-Elevate`, standalone `-SetPort`, `-WhatIf`/`-Confirm` everywhere |
| **Sessions** | `-ShowSessions` via WTS API (qwinsta fallback) |
| **Reporting** | `-ExportJson`, `-LogPath`, `-Quiet`, `-NoColor`, `-NoEmoji`, `-NoBrowser`, redesigned HTML report |
| **Correctness** | ~20 bug fixes: Home N (`CoreN`) edition misdetection, `Get-WmiObject` on PS7, `Invoke-Expression` remediations, broken firewall port matching, `$Verbose` gating bug, TermService "Automatic" false positive, ineffective `#Requires`, and more |
| **Engineering** | GitHub Actions CI, PSScriptAnalyzer gate, Pester test-suite, strict mode, guarded check pipeline (one broken subsystem can't abort the run) |

## Quick Start

```powershell
# 1) Get the tool (any method)
git clone https://github.com/paulmann/RDP-Diagnostic-Tool
#    or download RDP-Tool.ps1 from the latest Release

# 2) Audit this machine (read-only, works unelevated)
pwsh -NoProfile -File .\RDP-Tool.ps1

# 3) Enable + repair RDP end-to-end (elevated, no prompts)
pwsh -NoProfile -File .\RDP-Tool.ps1 -EnableRDP -Force

# 4) Prove RDP answers on a remote host without credentials
pwsh -NoProfile -File .\RDP-Tool.ps1 -TestRdpTarget "srv01.contoso.com:3390"

# 5) Full reference
pwsh -NoProfile -File .\RDP-Tool.ps1 -Help
```

> If script execution is restricted, launch through `pwsh -File ...` as shown above (bypasses ExecutionPolicy for that invocation) or use `Unblock-File .\RDP-Tool.ps1` after downloading.

## Installation

Any one channel is enough - every channel ships the **same** `RDP-Tool.ps1`.

| Channel | Command | Requires |
|---|---|---|
| **npm** (one-off) | `npx rdp-diagnostic-tool@5.0.0 -Version` | Node.js 18+ |
| **npm** (permanent) | `npm i -g rdp-diagnostic-tool`, then `rdp-tool` | Node.js 18+ |
| **Direct download** | `RDP-Tool.ps1` from the [latest release](https://github.com/paulmann/RDP-Diagnostic-Tool/releases/latest), then `Unblock-File .\RDP-Tool.ps1` | PowerShell 7 only |
| **Git clone** | `git clone https://github.com/paulmann/RDP-Diagnostic-Tool` | git |
| **winget** | `winget install Paulmann.RDPDiagnosticTool` (once the manifest is merged into `winget-pkgs`) | winget |
| **Scoop** | `scoop install https://raw.githubusercontent.com/paulmann/RDP-Diagnostic-Tool/main/scoop/rdp-diagnostic-tool.json` | Scoop |

PowerShell 7 (`pwsh`) is required on every channel; install it with `winget install Microsoft.PowerShell`. Through npm and the package managers the command is on `PATH` as `rdp-tool`:

```powershell
rdp-tool                                  # full read-only audit
rdp-tool -TestRdpTarget "srv01:3389"       # prove the listener really speaks RDP
rdp-tool -EnableRDP -Force                # elevated repair
```

Self-update (`-CheckUpdate` / `-Update`) behaves identically on all channels: the script refreshes itself in place from GitHub Releases. npm-specific details: [docs/NPM.md](docs/NPM.md).

## Features

### Diagnostics (50+ checks, individually guarded)

| Area | What is checked |
|---|---|
| **Prerequisites** | Elevation, PowerShell 7, OS/edition/SKU RDP-host support (explicit matrix incl. Home N & Windows SE), pending reboot (registry + optional DISM), RDP binaries (`termsrv.dll` version & friends), Server-SKU feature state |
| **Registry** | `fDenyTSConnections`, `fEnableWinStation`, `PortNumber`, `UserAuthentication` (NLA), `SecurityLayer`, `MinEncryptionLevel`, transport selection, session limits, blank-password policy - each with **Group Policy overlay detection** (policy-managed values are reported, never "repaired" locally) |
| **Group Policy** | Terminal Services / RDP client / CredentialsDelegation policy dump with risky-policy flags (RDP denied by GPO, NLA off by GPO, legacy SecurityLayer) |
| **Services** | TermService (trigger-start aware), UmRdpService, SessionEnv, RpcSs/RpcEptMapper, audio stack for redirection; dependency health; WMI listener cross-check |
| **Firewall** | MpsSvc, profile states, built-in RDP rule sets matched **language-independently**, custom port rules via port-filter association, BLOCK-rule conflicts, **Public-profile coverage gap** |
| **Network** | Adapters, IPv4/IPv6, profile categories, gateway/DNS sanity |
| **Listener & ports** | TCP/UDP listeners, owning process, non-standard port-ownership (squatting), fast loopback TCP probe |
| **Protocol** | Unauthenticated **X.224/RDP negotiation handshake** against local and remote endpoints; detects non-RDP services on the port; reports TLS/CredSSP requirement; cross-checks wire vs registry NLA |
| **Certificates** | Auto-generated & pinned (`SSLCertificateSHA1Hash`) certificates: expiry, private key, store lookup |
| **Permissions** | "Remote Desktop Users" via **well-known SID** (works on localized Windows), current-user rights, member listing |
| **Security posture** | NLA, UAC, Defender, Credential Guard/VBS, logon auditing presence |
| **Events** | TermService errors, RCM 1148/1149 auth events, LSM session lifecycle 21-25, Security 4624/4625 (LogonType 10) with **brute-force source-IP rollup**, 4778/4779 reconnects |
| **Resources** | RAM/CPU/disk thresholds, GPU inventory |
| **External** (`-TestExternal`) | DNS, github.com:443 (updates), generic egress, TLS 1.2+ |

### Remediation (explicit, safe, reversible)

- `-EnableRDP` - one-shot enable & repair: registry baseline (incl. NLA enforcement, SecurityLayer=Negotiate, High encryption), trigger-aware service repair, firewall enable/create, current-user rights, listener rebind
- `-DisableRDP` - secure disable with remote-session lockout guard
- `-SetPort <n>` - listener port change incl. firewall rules and safe listener restart
- `-AddUser <u1,u2>` - validated, idempotent group membership grants
- `-RestartServices` - service-stack cycle with self-disconnect protection
- `-ForcePrivateNetwork` - opt-in network re-categorization
- Everything honors `-WhatIf` / `-Confirm`; `-Force` for unattended runs; GPO-managed settings are detected and skipped with precise guidance; firewall block rules are **disabled, not deleted** (reversible)

### Reporting

- Color-coded console output with emoji **and** automatic ASCII fallback (`-NoEmoji`, `NO_COLOR`, `-Quiet`)
- **HTML** report: verdict banner, KPI tiles, per-check remedies, remediation log, connection instructions (`-ExportReport`)
- **JSON** report for CI/monitoring (`-ExportJson`)
- Plain-text run log, complete even in quiet mode (`-LogPath`)

## Command-Line Reference

```
.\RDP-Tool.ps1 [<mode>] [<actions>] [<probes>] [<reporting>] [<update>] [<misc>]
```

### Modes (pick at most one)

| Switch | Description |
|---|---|
| *(none)* | Full read-only diagnostic pass (default) |
| `-DiagnoseOnly` | Explicit read-only audit; makes no changes even if combined with baseline flags like `-SetPort`/`-DisableNLA` (they only change what is audited against) |
| `-EnableRDP` | Enable RDP + auto-remediate everything repairable |
| `-DisableRDP` | Securely disable inbound RDP (registry + firewall) |
| `-CheckUpdate` | Compare local version with the latest GitHub release (exit `5` = update available) |
| `-Update` | Validate + back up + self-replace with the latest release |

### Configuration actions (require elevation)

| Switch | Description |
|---|---|
| `-SetPort <1024-65535>` | Change the listener port (alias: `-ChangePort`); composes with `-EnableRDP` |
| `-DisableNLA` | Turn Network Level Authentication **off** (insecure - confirmation required) |
| `-AddUser <u1,u2,...>` | Add accounts to "Remote Desktop Users" (local or `DOMAIN\user`) |
| `-RestartServices` | Restart TermService/SessionEnv/UmRdpService (disconnect guard) |
| `-ForcePrivateNetwork` | Re-categorize Public profiles to Private |

### Probes & inspection

| Switch | Description |
|---|---|
| `-TestRdpTarget <host[:port]>` | Real RDP negotiation handshake against a local/remote endpoint (no credentials) |
| `-ShowSessions` | List live terminal sessions (WTS API, qwinsta fallback) |
| `-TestExternal` | Outbound DNS/TCP connectivity checks |
| `-SkipRebootCheck` | Skip pending-reboot detection |
| `-SkipSlowChecks` | Skip DISM scan and full port-filter enumeration |

### Reporting

| Switch | Description |
|---|---|
| `-ExportReport <file.html>` | Styled self-contained HTML report |
| `-ExportJson <file.json>` | Machine-readable report |
| `-LogPath <file.log>` | Timestamped run log (appended) |
| `-NoBrowser` | Don't auto-open the HTML report |
| `-Quiet` | Summary + problems only |
| `-NoColor` / `-NoEmoji` | Plain output (also auto-detected; `NO_COLOR` honored) |

### Update & misc

| Switch | Description |
|---|---|
| `-UpdateSource <src>` | `owner/repo` slug or direct HTTPS URL (mirrors/forks/air-gapped) |
| `-Elevate` | Relaunch elevated with identical arguments (UAC) |
| `-Force` | Skip interactive confirmations |
| `-Version` | Version/runtime info |
| `-Verbose` | Detailed per-check output (`-ShowVerbose` still works, deprecated) |
| `-WhatIf` / `-Confirm` | Preview / gate every system change |
| `-Help`, `-?`, `-h` | Comprehensive built-in help |

## Command Examples

```powershell
# Daily-driver audit with all reports for a support ticket
.\RDP-Tool.ps1 -ExportReport .\rdp-report.html -ExportJson .\rdp-report.json -LogPath .\rdp.log

# Unattended fleet repair (SCCM/Intune/RMM): enable RDP, custom port, grant helpdesk
.\RDP-Tool.ps1 -EnableRDP -SetPort 3390 -AddUser 'CONTOSO\rdp-helpdesk' -Force -Quiet -ExportJson C:\Temp\rdp.json

# Dry run: show exactly what would be changed, touch nothing
.\RDP-Tool.ps1 -EnableRDP -WhatIf

# Probe a remote host: is that port REALLY RDP, and does it demand NLA?
.\RDP-Tool.ps1 -TestRdpTarget 10.0.0.5:3390

# Who is connected right now?
.\RDP-Tool.ps1 -ShowSessions

# Incident response: lock the machine down immediately
.\RDP-Tool.ps1 -DisableRDP -Force

# CI: fail the pipeline when RDP is broken or a newer tool version exists
.\RDP-Tool.ps1 -DiagnoseOnly -ExportJson report.json     # exit 1/2 = broken
.\RDP-Tool.ps1 -CheckUpdate                              # exit 5 = update available

# Keep the tool current
.\RDP-Tool.ps1 -Update -Force
```

## The RDP Protocol Handshake Probe

Most tools stop at "port 3389 is open". RDP-Tool goes one layer deeper and speaks
just enough of the protocol to prove the **RDP stack itself** is answering:

```
Client ──► TPKT + X.224 Connection Request + RDP Negotiation Request (TLS|CredSSP)
Server ──► X.224 Connection Confirm + Negotiation Response
             ├─ selectedProtocol: Standard RDP | TLS | CredSSP (NLA)
             └─ or failure code: SSL_REQUIRED_BY_SERVER, HYBRID_REQUIRED_BY_SERVER, ...
```

This is the same negotiation `mstsc.exe` performs before authentication - **no
credentials are sent or needed**. The probe:

- distinguishes "some TCP service owns the port" from "RDP answers"
- reports whether NLA/CredSSP is enforced on the wire (and flags mismatches with the registry/GPO configuration)
- surfaces exact protocol failure codes that explain classic errors like *"CredSSP encryption oracle remediation"* or *"The local security settings don't allow..."*
- works against `localhost` (after the listener check) and any remote `host[:port]`

## Auto-Update

The tool carries a machine-readable version marker and knows its own repository:

```powershell
.\RDP-Tool.ps1 -CheckUpdate     # exit 0 = up to date, 5 = update available, 6 = check failed
.\RDP-Tool.ps1 -Update          # interactive; add -Force for unattended
```

How `-Update` works:

1. Resolve the newest version: **GitHub Releases API** (`releases/latest`) → if the asset `RDP-Tool.ps1` exists, it is used; otherwise the tagged raw file; if the API is unavailable/rate-limited → raw-file probe of the default branch with version-marker parsing.
2. Download over TLS and **validate**: non-empty, minimum size, not an HTML error page, version marker present and matching the release, **full PowerShell syntax parse** of the payload.
3. Back up the current script next to it (`RDP-Tool.ps1.bak-<timestamp>`; falls back to `%TEMP%`).
4. Replace atomically (temp file + move). Re-run the tool to use the new version.

Enterprise mirrors/air-gapped networks:

```powershell
.\RDP-Tool.ps1 -Update -UpdateSource https://intranet/tools/RDP-Tool.ps1   # direct file
.\RDP-Tool.ps1 -Update -UpdateSource contoso/RDP-Diagnostic-Tool           # fork slug
```

## Reporting & Automation

- **JSON** (`-ExportJson`) - stable schema: `tool`, `version`, `reportId`, `systemInfo`, `summary` (counts + exit code), `results[]` (component/status/details/remedy/severity/category), `remediations[]`, `tests[]`. Pipe into `ConvertFrom-Json`, ship to SIEM/dashboards, diff between runs.
- **HTML** (`-ExportReport`) - self-contained (inline CSS), safe to attach to tickets; HTML-encodes all dynamic data.
- **Log** (`-LogPath`) - appended, timestamped, includes every check and change even under `-Quiet`.
- **Exit codes** - designed for schedulers/CI (table below).

Example (fail a build on any RDP error):

```powershell
pwsh -NoProfile -File .\RDP-Tool.ps1 -DiagnoseOnly -Quiet -ExportJson rdp.json
if ($LASTEXITCODE -ge 1 -and $LASTEXITCODE -le 2) { throw "RDP misconfigured (exit $LASTEXITCODE)" }
```

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success - system ready / action completed / up to date |
| `1` | **Critical** issues - RDP will not work until resolved |
| `2` | Errors detected - RDP degraded or limited |
| `3` | Unsupported Windows edition (Home / SE cannot host RDP) |
| `4` | Prerequisite not met (elevation required, invalid parameter combination, non-Windows platform) |
| `5` | Update available (`-CheckUpdate` only) |
| `6` | Update failed |
| `99` | Unhandled script error |

## Supported Windows Editions

| Edition | RDP **host** | Notes |
|---|---|---|
| Windows 10/11 Pro, Pro for Workstations, Pro Education | ✅ | |
| Windows 10/11 Enterprise (incl. LTSC), Education | ✅ | |
| Windows IoT Enterprise / Enterprise multi-session (ServerRdsh) | ✅ | |
| Windows Server 2016 / 2019 / 2022 / 2025 | ✅ | Admin sessions; RDS role for published desktops |
| Windows 10/11 **Home / Home N / Single Language** | ❌ | Client connections only; tool exits `3` with guidance |
| Windows 11 **SE** (`CloudEdition`) | ❌ | |

> The v4 edition regex misidentified **Home N (`CoreN`)** as RDP-capable. v5 uses an explicit, tested edition matrix (see `tests/`).

## Architecture & Design

```
RDP-Tool.ps1 (single file, ~4300 lines, UTF-8 BOM, PowerShell 7+)
│
├─ Metadata           single version marker (release & update contract)
├─ Console/Logging    color+emoji auto-detection, ASCII fallback, file logger
├─ State              script-scoped result/remediation/test stores (no $global:)
├─ Validation         parameter-combination matrix with actionable errors
├─ Help/Version       built-in reference + comment-based help for Get-Help
├─ Update engine      releases API → raw probe fallback, validate → backup → atomic swap
├─ Checks (Test-*)    each wrapped in Invoke-Check (isolated failures)
│   └─ registry(+GPO) · services · firewall · network · listener · handshake ·
│      certificate · permissions · security · resources · event logs
├─ Session engine     WTS P/Invoke (Unicode-correct) + qwinsta fallback
├─ Remediation        ShouldProcess-aware, GPO-aware, idempotent, recorded
├─ Reporting          HTML / JSON / console summary / exit-code mapping
└─ Main               phase pipeline: prereqs → remediate → verify → report
```

Design rules the codebase follows:

1. **Never abort early** - every check is guarded; a dead WMI or firewall API degrades the report, it doesn't kill it.
2. **Never guess** - localized systems are handled via well-known SIDs and language-independent firewall rule names; GPO-managed values are detected instead of being silently overwritten.
3. **Never surprise** - no changes without explicit action switches; `-WhatIf` end-to-end; dangerous actions (NLA off, service restart in a live session, disabling RDP remotely) require confirmation or `-Force`.
4. **Be testable** - pure logic (protocol codecs, edition matrix, validators) is unit-tested; `RDPDIAG_LIB=1` enables dot-sourcing without side effects.

## Safety Model

- Read-only by default; elevation only required for actions (diagnostics run unelevated with reduced coverage).
- `-WhatIf` shows the full remediation plan without touching the system.
- GPO-locked settings are reported with exact policy paths instead of futile local edits.
- Remote-session guards prevent self-lockout on `-DisableRDP` / `-RestartServices` / port changes.
- The tool never reads, stores, or transmits credentials; the handshake probe stops before authentication.
- Updates: TLS only, content validation incl. syntax parse, timestamped backup, atomic replace.

## Development & CI

```powershell
# Lint
Invoke-ScriptAnalyzer -Path .\RDP-Tool.ps1 -Settings .\ScriptAnalyzerSettings.psd1

# Test (Pester 5+)
Invoke-Pester .\tests -Output Detailed
```

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs on every push/PR:
syntax parse gate (Windows + Ubuntu), PSScriptAnalyzer gate (zero Error/Warning with project settings), and the Pester suite on `windows-latest` (integrity, help coverage, parameter surface, protocol codec, edition matrix, update validation, CLI behavior incl. exit codes).

## Releasing (Maintainers)

1. Bump `$script:ToolVersion` **and** the `.NOTES` version in the comment help **and** add the `CHANGELOG.md` entry (the test-suite enforces marker ↔ changelog consistency).
2. Merge to `main`; CI must be green.
3. Create a GitHub **Release** with tag `X.Y.Z` (the updater parses the tag; a `v` prefix is tolerated). Optionally attach `RDP-Tool.ps1` as a release asset - the updater prefers assets and falls back to the tagged raw file.
4. Verify: `.\RDP-Tool.ps1 -CheckUpdate` from an older copy must report "update available" (exit 5).

## Troubleshooting

| Symptom | Fix |
|---|---|
| *"cannot be loaded because running scripts is disabled"* | Run via `pwsh -NoProfile -File .\RDP-Tool.ps1 ...` or `Unblock-File .\RDP-Tool.ps1` |
| Tool says *ELEVATION REQUIRED* (exit 4) | Re-run with `-Elevate`, or start PowerShell as Administrator |
| Emoji render as boxes | Legacy console: the tool auto-falls back to ASCII; force with `-NoEmoji`; or use Windows Terminal |
| `-CheckUpdate` fails behind a proxy | Configure `pwsh` proxy settings or use `-UpdateSource <internal mirror URL>` |
| Home edition (exit 3) | RDP hosting is a Microsoft licensing restriction; see in-tool guidance for alternatives |
| Changes don't take effect | Check for GPO-managed values (the report flags them) and pending reboots |

More: [wiki/Troubleshooting](https://github.com/paulmann/RDP-Diagnostic-Tool/wiki/Troubleshooting)

## Support

- 📖 Wiki: <https://github.com/paulmann/RDP-Diagnostic-Tool/wiki>
- 🐞 Issues: <https://github.com/paulmann/RDP-Diagnostic-Tool/issues> - attach an `-ExportReport` HTML and the `-LogPath` log
- 📜 [Changelog](CHANGELOG.md) · [License (MIT)](LICENSE)
- ✍️ Author: Mikhail Deynekin [ Deynekin.com ]
