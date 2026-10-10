# Changelog

All notable changes to this project will be documented in this file.

## [5.0.0] - 2026-10-09

> **Major refactor.** The tool was rewritten end-to-end for production use:
> a real help system, a GitHub-based self-updater, a protocol-level RDP probe,
> session management, JSON/log reporting, safe remediation with `-WhatIf`
> support, and ~20 correctness fixes over v4.2.0.

### Added
- **Comprehensive built-in help (`-Help`, `-?`, `-h`, `-ShowHelp`)** - full
  switch reference grouped by purpose, 12+ examples, exit-code table, update
  and reporting instructions. Complete comment-based help also powers
  `Get-Help .\RDP-Tool.ps1 -Full / -Examples / -Detailed`.
- **Self-update engine**
  - `-CheckUpdate` - resolves the newest version via the GitHub **Releases API**
    (falls back to a raw-file version probe when no release exists or the API
    is rate-limited); exit code **5** signals "update available" for automation.
  - `-Update` - downloads the new script over TLS, validates it (version marker,
    minimum size, HTML-error-page detection, full PowerShell **syntax parse**),
    creates a timestamped backup (`RDP-Tool.ps1.bak-<ts>`) and atomically
    replaces the running file.
  - `-UpdateSource` - mirror/fork support for air-gapped fleets (`owner/repo`
    slug or a direct HTTPS URL).
  - Machine-readable version marker (`$script:ToolVersion = [version]'x.y.z'`)
    is now part of the release contract.
- **Real RDP protocol handshake (`-TestRdpTarget <host[:port]>`)** - sends an
  unauthenticated X.224 Connection Request with an RDP Negotiation Request and
  parses the answer: distinguishes "port open" from "RDP stack responds",
  reports the negotiated security protocol (Standard RDP / TLS / CredSSP-NLA)
  and exact failure codes (`HYBRID_REQUIRED_BY_SERVER`, `SSL_CERT_NOT_ON_SERVER`,
  ...). Also runs against the local listener and cross-checks the wire result
  against the registry NLA setting.
- **Session management** - `-ShowSessions` enumerates terminal sessions
  (ID, user, state, winstation, client address, protocol) via WTS P/Invoke with
  a `qwinsta` fallback.
- **New actions**
  - `-DisableRDP` - secure disable (deny connections + firewall rules off),
    with a remote-session lockout guard.
  - `-AddUser <u1,u2>` - grant RDP logon rights (account existence validation,
    idempotent).
  - `-RestartServices` - cycle TermService/SessionEnv/UmRdpService with a
    self-disconnect guard.
  - `-SetPort` - applies a port change standalone (registry + firewall +
    listener rebind); `-ChangePort` kept as an alias.
  - `-Elevate` - relaunch the same command line elevated via UAC.
- **Reporting & observability**
  - `-ExportJson` - machine-readable report (results, remediations, summary,
    exit code) for CI/monitoring dashboards.
  - `-LogPath` - timestamped run log (complete even in `-Quiet` mode).
  - `-Quiet`, `-NoColor` (honors `NO_COLOR`), `-NoEmoji` (auto ASCII fallback
    on legacy consoles), `-NoBrowser` (do not auto-open the HTML report).
  - Redesigned HTML report: verdict banner, KPI tiles, per-check remedies,
    remediation log, connection instructions.
- **Safety & ergonomics**
  - `-WhatIf` / `-Confirm` support for every mutating operation
    (`SupportsShouldProcess` end-to-end).
  - `-Force` maps to `$ConfirmPreference = 'None'` for unattended runs.
  - Read-only diagnostics now run **unelevated** (clearly marked reduced
    coverage) instead of aborting; only actions require elevation.
  - Every diagnostic check is individually guarded - one broken subsystem
    (WMI, firewall API, event log) can no longer abort the whole run.
  - Parameter-combination validation with precise, actionable errors (exit 4).
- **New checks**: RDP TLS certificate (expiry / private key / pinned
  thumbprint), `fEnableWinStation` listener state, Group Policy overlay with
  risky-policy detection (`fDenyTSConnections`, NLA off, legacy SecurityLayer),
  Public-profile firewall gap detection, non-standard port-ownership detection,
  UDP listener state, blank-password policy, CredSSP/Credential Guard posture,
  RCM 1148/1149 + LSM 21-25 + Security 4624/4625 (LogonType 10) / 4778 / 4779
  event mining with brute-force source-IP rollup, gateway/DNS sanity,
  WMI listener cross-check, mstsc presence.
- **Engineering**: GitHub Actions CI (parse gate, PSScriptAnalyzer gate,
  Pester suite on Windows), Pester 5/6 test-suite (`tests/`), analyzer settings
  with documented exclusions, dot-source library mode (`RDPDIAG_LIB`) for tests.

### Changed
- **Running with no parameters now performs a full read-only diagnostic**
  (previously it printed help). Use `-Help` for the reference.
- `-SetPort` (alias `-ChangePort`) is no longer trapped in its own parameter
  set - it composes with `-EnableRDP`, reporting, probes, etc. (the v4
  documented example `-ChangePort 3390 -EnableRDP` previously failed to bind).
- TermService is now expected in its **default Manual (trigger-start)** state;
  "Automatic" is no longer demanded, removing a false positive on healthy
  systems. Remediation never touches RpcSs startup type.
- Network profiles are re-categorized to Private **only** with
  `-ForcePrivateNetwork` (v4 silently did this inside `-EnableRDP`).
- `fSingleSessionPerUser` and session time limits are reported informationally;
  the tool deliberately does not "fix" single-session limits (licensing).
- Firewall rule discovery matches built-in rules by language-independent
  internal names (`RemoteDesktop-*`) plus port-filter association - works on
  localized Windows (v4 relied on English display names and a non-existent
  `LocalPort` property on `Get-NetFirewallRule`).
- Local connectivity probes use a fast .NET `TcpClient` with timeouts instead
  of `Test-NetConnection` (seconds saved per probe).
- Exit codes refined & documented: `0` ready, `1` critical, `2` errors,
  `3` unsupported edition, `4` prerequisite/invalid parameters,
  `5` update available, `6` update failed, `99` script error.
- HTML report no longer auto-opens in `-Quiet` mode or with `-NoBrowser`.
- Deprecated `-ShowVerbose` kept as a compatibility shim (warns; use
  `-Verbose`).

### Fixed
- **`CoreN` (Windows Home N) was wrongly treated as RDP-capable** in the v4
  edition regex - Home N users were told their SKU "supports RDP Server".
  The edition matrix is now explicit (incl. Windows 11 SE / `CloudEdition`).
- `$Verbose` (an undefined variable) gated detail output in v4 - details never
  printed. Verbosity now flows through standard preference variables.
- `#Requires -Version 7.0` was placed *after* the `param()` block, where it is
  ignored; it is now effective at the top of the script.
- Removed `Get-WmiObject` (removed in PowerShell 7 - would crash the driver
  and service checks) - CIM only.
- Removed `Invoke-Expression` on registry "remediation strings" (arbitrary-code
  execution surface); remediations are typed function calls now.
- Pending-reboot heuristics checked `PendingFileRenameOperations`/`SetupExecute`
  as registry *keys* (they are values) - the check never fired; fixed.
- `Get-Service -DependentServices` (missing `-Name`) crashed the service
  relationships block; dependency analysis reworked.
- `Enable-WindowsOptionalFeature -FeatureName RemoteDesktop-Server` is invalid
  on client SKUs (feature does not exist) - replaced with binaries + service
  presence verification; feature path only used on Server SKUs.
- Port audit no longer reports a healthy custom port as "MISCONFIGURED"
  (expected value derived from configuration, not hard-coded 3389).
- Report/summary success-rate math, service-state comparisons
  (`Auto` vs `Automatic` WMI/Service enum mismatch), `${localIP}:port`
  interpolation, and numerous StrictMode/runtime-crash hazards.
- Script now runs under `Set-StrictMode -Version 2.0` cleanly and survives
  individual subsystem failures (guarded check pipeline).

### Removed
- Dead code: RemoteFX/`fEnableVirtualizedGraphics` "remediation" here-string
  that could corrupt the WinStation key, Windows Experience Index probe
  (WinSAT deprecated), redundant `Test-RDPCapability` DLL list items not
  present on modern SKUs, `$global:` state pollution (all state is
  script-scoped now).

### Security
- No `Invoke-Expression`, no credential handling, no telemetry.
- Update pipeline: TLS-only, version-marker + syntax-parse validation before
  replacement, automatic backup, atomic write (temp file + move).
- NLA is enforced by default during `-EnableRDP`; `-DisableNLA` requires
  explicit confirmation (or `-Force`) and is flagged as insecure everywhere.
- Block-rule handling disables (reversible) instead of deleting firewall rules.


## [4.2.0] - 2025-12-08

### Added
- **Comprehensive Diagnostic System**
  - 50+ diagnostic tests covering all RDP components
  - Registry validation (15+ settings)
  - Service configuration analysis (6 core services)
  - Firewall rule assessment and management
  - Network profile and connectivity testing
  - Security policy and audit verification
  - User permissions analysis
  - Performance and resource evaluation
  - Event log inspection and analysis

- **Automatic Remediation Engine**
  - One-click fix with `-EnableRDP` parameter
  - Registry correction and optimization
  - Service startup configuration
  - Firewall rule creation and enabling
  - Network profile adjustment
  - Dependency resolution
  - Windows feature installation
  - User permission correction
  - Custom RDP port configuration

- **Professional Reporting**
  - Color-coded console output with severity indicators
  - Structured result categorization
  - HTML report generation (`-ExportReport`)
  - Timestamped diagnostics
  - Executive summary with statistics
  - Remediation attempt logging
  - Actionable recommendations

- **Advanced Features**
  - Support for custom RDP ports (1024-65535)
  - Network Level Authentication (NLA) control
  - Private network profile enforcement
  - External connectivity testing
  - Windows edition compatibility checking
  - Virtual machine detection
  - Firewall profile analysis
  - DNS and internet connectivity testing

- **Safety & Control**
  - Diagnostic-only mode (`-DiagnoseOnly`)
  - Safe defaults (no changes without permission)
  - Comprehensive error handling
  - Rollback-friendly operations
  - Detailed logging of all changes
  - Exit codes for automation (0, 1, 2, 3, 4, 99)

### Features
- **System Prerequisites Checking**
  - Administrator privilege verification
  - PowerShell version validation (5.1+)
  - Windows edition compatibility assessment
  - Pending reboot detection
  - Windows feature availability check

- **Windows Edition Analysis**
  - Automatic RDP Server support detection
  - Windows Home edition handling
  - OEM system identification
  - System information collection

- **RDP Capability Tests**
  - Registry structure validation
  - Required DLL verification
  - Driver status monitoring
  - Virtualization environment detection
  - Windows Defender Application Guard check

- **Enhanced Registry Settings**
  - Connection state validation
  - Session configuration analysis
  - Port number verification
  - Authentication level checking
  - Encryption level validation
  - Performance timeout analysis
  - Audio and graphics settings review

- **Service Configuration**
  - TermService status monitoring
  - Session environment configuration
  - USB redirection setup
  - Video driver verification
  - Audio service validation
  - Dependency chain analysis
  - Automatic startup correction

- **Firewall Analysis**
  - Firewall service status
  - Profile configuration review
  - RDP rule detection and analysis
  - Conflicting rule identification
  - Custom rule creation
  - Rule enabling and disabling

- **Network Configuration**
  - Network adapter status
  - IP configuration validation
  - Network profile categorization
  - Connection profile analysis
  - Network discovery status
  - Isolation rule detection

- **Port & Connectivity**
  - Local port listening verification
  - Local connection testing
  - Network loopback testing
  - Port conflict detection
  - External connectivity testing
  - DNS resolution validation
  - Internet connectivity verification

- **Security & Policies**
  - Group Policy review
  - UAC status verification
  - Windows Defender monitoring
  - Credential Guard detection
  - Security auditing validation
  - Failed login attempt analysis

- **User Permissions**
  - Remote Desktop Users group membership
  - Current user RDP rights verification
  - Administrator token detection
  - Local group membership analysis

- **Performance Analysis**
  - System memory evaluation
  - CPU core and thread counting
  - Graphics adapter detection
  - Disk space monitoring
  - Windows Experience Index retrieval

- **Event Log Analysis**
  - RDP service event inspection
  - Security event log review
  - Terminal Services event analysis
  - Error and warning detection
  - Failed login tracking

### Configuration Options
- `-EnableRDP` - Enable RDP with automatic remediation
- `-DiagnoseOnly` - Diagnostic mode without changes
- `-ForcePrivateNetwork` - Convert profiles to Private
- `-ChangePort <port>` - Configure custom RDP port
- `-DisableNLA` - Disable Network Level Authentication
- `-TestExternal` - Test external connectivity
- `-SkipRebootCheck` - Skip pending reboot check
- `-ShowVerbose` - Display detailed output
- `-ExportReport <path>` - Generate HTML report
- `-Help` or `-?` - Display help message

### Exit Codes
- `0` - All tests passed, RDP ready
- `1` - Critical errors detected
- `2` - Warnings detected, RDP may have limitations
- `3` - Unsupported Windows edition
- `4` - Missing critical prerequisites
- `99` - Script execution error

### Requirements
- Windows 10/11 Pro, Enterprise, Education, or Server 2016+
- PowerShell 5.1 or higher
- Administrator privileges
- < 1 MB disk space
- < 50 MB RAM usage

### Initial Release
First stable production release with comprehensive diagnostics, automatic remediation, and professional reporting capabilities.

---

## Versioning

This project follows [Semantic Versioning](https://semver.org/).
- **MAJOR** version for incompatible changes
- **MINOR** version for backwards-compatible functionality
- **PATCH** version for backwards-compatible bug fixes

## Support

For issues, questions, or suggestions, please visit:
- **Issues**: https://github.com/paulmann/RDP-Diagnostic-Tool/issues
- **Discussions**: https://github.com/paulmann/RDP-Diagnostic-Tool/discussions
- **Author**: Mikhail Deynekin (https://deynekin.com)