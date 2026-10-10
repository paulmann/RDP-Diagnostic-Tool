<!-- Last Updated: 2026-10-10 | Version: 5.0.1 -->

# Changelog

[[Home]] › Changelog

The **authoritative changelog** lives in the repository: [CHANGELOG.md](https://github.com/paulmann/RDP-Diagnostic-Tool/blob/main/CHANGELOG.md).
This page is a short orientation summary.

---

## [5.0.1] — 2026-10-10 · Self-update fix

- **`-Update` aborted with exit code 99.** GitHub serves release assets as
  `application/octet-stream`, so PowerShell 7's `Invoke-WebRequest` returns `.Content`
  as a byte array; the validator expected a string and the update stopped mid-flight.
  Payloads are now normalized (UTF-8 decode, single BOM on write), the same helper
  covers the raw-file version probe, and a regression test pins the byte-array path.

## [5.0.0] — 2026-10-09 · Major production refactor

### Added
- **Comprehensive help** (`-Help` / `-?` / `-h`) + full comment-based help for `Get-Help -Full`
- **Self-update engine**: `-CheckUpdate` (exit `5` = update available), `-Update` (validated download → timestamped backup → atomic replace), `-UpdateSource` for mirrors/forks
- **RDP protocol handshake probe** (`-TestRdpTarget host[:port]`): unauthenticated X.224/RDP negotiation against local or remote endpoints; reports Standard/TLS/CredSSP(NLA) and exact failure codes
- **Session listing** (`-ShowSessions`): WTS P/Invoke with qwinsta fallback
- **New actions**: `-DisableRDP`, `-AddUser`, `-RestartServices`, `-Elevate`, standalone `-SetPort`
- **Reporting**: `-ExportJson`, `-LogPath`, `-Quiet`, `-NoBrowser`, `-NoColor`, `-NoEmoji` (auto ASCII fallback), redesigned HTML report
- **Safety**: `-WhatIf`/`-Confirm` on every mutation, GPO-overlay detection, remote-session guards, per-check failure isolation (`Invoke-Check`), parameter-combination validation
- **New checks**: TLS certificate audit, `fEnableWinStation`, Public-profile firewall gap, port squatting, UDP listener, brute-force source-IP rollup (4625/10), RCM 1148/1149, LSM 21-25, gateway/DNS sanity
- **Engineering**: GitHub Actions CI, PSScriptAnalyzer gate, Pester 5/6 suite, `RDPDIAG_LIB` dot-source mode

### Changed
- No-parameter run now performs a **full read-only diagnostic** (help moved to `-Help`)
- `-SetPort`/`-ChangePort` composes with all other switches (v4's parameter-set split made the documented `-ChangePort 3390 -EnableRDP` example fail)
- TermService expected in its default **Manual (trigger-start)** state - no more false positives
- Network re-categorization only via explicit `-ForcePrivateNetwork` (was silently bundled into `-EnableRDP`)
- Localized-Windows-safe firewall matching (internal rule names + port filters, not English display names) and SID-based group lookup
- Fast .NET `TcpClient` probes instead of `Test-NetConnection`
- Exit codes refined: `0/1/2/3/4/5/6/99` (see [[Usage]])

### Fixed (highlights)
- `CoreN` (Home N) misdetected as RDP-capable; explicit edition matrix incl. Windows 11 SE
- `Get-WmiObject` (dead in PS7), `Invoke-Expression` remediations (code-exec surface), `$Verbose` gating bug, ineffective `#Requires` placement
- Pending-reboot value-vs-key check bug; `Get-Service -DependentServices` crash; invalid `RemoteDesktop-Server` optional-feature calls on client SKUs
- Port audit false "MISCONFIGURED" on healthy custom ports; numerous StrictMode hazards

### Removed
- RemoteFX/`fEnableVirtualizedGraphics` remediation (dangerous here-string), WinSAT probe, `$global:` state pollution

### Security
- No credentials touched, no telemetry, TLS-only updates with syntax-parse validation, reversible firewall changes, NLA enforced by default

---

## [4.2.0] — 2025-12-08

- First public release: 50+ diagnostic checks, `-EnableRDP` remediation, HTML export, exit codes `0/1/2/3/4/99`.
- Full notes: [CHANGELOG.md](https://github.com/paulmann/RDP-Diagnostic-Tool/blob/main/CHANGELOG.md)

---

## Roadmap (candidates)

- [ ] RD Gateway / Windows App (AVD) connectivity profile
- [ ] Optional Authenticode signing of releases + checksum assets consumed by `-Update`
- [ ] Multi-host sweep mode (`-Targets hosts.txt`) over PowerShell Remoting
- [ ] QUIC transport diagnostics (Windows Server 2025 / Win11 24H2+)
- [ ] ServiceNow / Log Analytics exporters on top of `-ExportJson`

---

*Maintained by [Mikhail Deynekin](https://deynekin.com) · [mid1977@gmail.com](mailto:mid1977@gmail.com)*
