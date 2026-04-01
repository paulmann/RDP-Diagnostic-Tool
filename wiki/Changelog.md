<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Changelog

[[Home]] › Changelog

All notable changes to the RDP Diagnostic Tool are documented here following [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) conventions and [Semantic Versioning](https://semver.org/).

---

## [1.0.0] — 2026-04-01

### 🎉 Initial Release

#### Added
- `Invoke-RdpDiagnostic` core function with `Quick`, `Full`, and `Deep` modes
- **Network layer checks:** port 3389 listener, firewall rules, TCP/UDP transport validation
- **Authentication checks:** NLA enforcement, CredSSP patch level (CVE-2018-0886), TLS version
- **Session checks:** active/inactive session count, session isolation, WinStation status
- **Kernel driver checks:** `termdd.sys`, `tdtcp.sys`, `tdudp.sys` version and signing validation
- **GPU/RemoteFX checks:** VRAM utilization, GPU-P partition status
- **Output formats:** Console (colorized), JSON, HTML, CSV
- **Report generator:** timestamped HTML reports with pass/warn/fail categorization
- Comprehensive enterprise documentation wiki
- Pester 5.x test suite

#### Architecture
- PowerShell 7.0+ native (no Windows PowerShell 5.1 dependency)
- CIM/WMI abstraction layer for cross-version compatibility
- Modular design: diagnostic checks are independently loadable
- Read-only by default; `-Remediate` flag required for any changes

---

## [Unreleased] — Future Roadmap

### Planned for v1.1.0
- [ ] ServiceNow ITSM webhook integration
- [ ] Azure Monitor / Log Analytics export
- [ ] QUIC transport diagnostics (Windows Server 2025)
- [ ] Automated Pester CI via GitHub Actions

### Planned for v1.2.0
- [ ] ML anomaly detection module (Isolation Forest)
- [ ] Power BI streaming dataset connector
- [ ] Multi-host farm health summary dashboard

### Planned for v2.0.0
- [ ] Cross-platform Linux/macOS diagnostic client (xrdp targets)
- [ ] REST API mode for ITSM/automation integration
- [ ] Container-based deployment (Docker)

---

*Maintained by [Mikhail Deynekin](https://deynekin.com) · [mid1977@gmail.com](mailto:mid1977@gmail.com)*
