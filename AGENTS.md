# AGENTS.md - RDP Diagnostic & Remediation Tool 5.0.1

Agent-facing guide: how to install RDP-Tool, run it safely on a Windows host, and report problems
responsibly. Human documentation: [README.md](README.md), [docs/NPM.md](docs/NPM.md), [wiki/](wiki/).

> Verified against repository state on 2026-10-22. Version covered: 5.0.1 (released 2026-10-10 per `$script:ToolVersion`).

## 1. What it is

A single-file PowerShell tool that audits every RDP subsystem on a Windows machine (edition and SKU
support, registry plus Group Policy overlay, services, firewall, listener, TLS certificate,
permissions, event logs), repairs the repairable parts on request, and proves the stack answers with
a real X.224/RDP negotiation handshake. It is not an RDS deployment tool, not a multi-session patcher,
and it never handles credentials. The default run is read-only.

| | |
|---|---|
| Runtime / platform | PowerShell 7 Core (`#Requires -Version 7.0`, `#Requires -PSEdition Core`) on Windows 10/11 Pro/Enterprise/Education or Windows Server 2016+ |
| Entry point | `RDP-Tool.ps1` - one file, 4354 lines, UTF-8 **with BOM** (the Pester suite and the npm build gate enforce the BOM) |
| Writes to | only paths you name: `-ExportReport` HTML, `-ExportJson` JSON, `-LogPath` log; `RDP-Tool.ps1.bak-<timestamp>` on `-Update`; on remediation: registry values, firewall rules, service startup types, local group membership, network profile category |
| Network access | `api.github.com/repos/paulmann/RDP-Diagnostic-Tool` and `raw.githubusercontent.com/paulmann/RDP-Diagnostic-Tool` for `-CheckUpdate`/`-Update`; TCP to the target for `-TestRdpTarget`; DNS, `github.com:443` and `8.8.8.8:53` for `-TestExternal`. No telemetry, no credential transmission |
| Releases | tag `5.0.1` (latest) publishes `RDP-Tool.ps1` (218353 bytes), `RDP-Diagnostic-Tool-5.0.1.zip`, `SHA256SUMS.txt`; tags `5.0.1`, `5.0.0`, `4.2.0` exist |

## 2. Preconditions

| Requirement | Why | Check |
|---|---|---|
| PowerShell 7 (`pwsh`) | the script refuses 5.1: `#Requires -Version 7.0`, `#Requires -PSEdition Core` | `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'`; the `PowerShell :` line of `.\RDP-Tool.ps1 -Version` |
| Windows 10/11 or Server 2016+ | anything else prints `UNSUPPORTED PLATFORM` and exits `4` | run `.\RDP-Tool.ps1 -Version`; the tool checks `$IsWindows` before the Windows-only phases |
| RDP-capable edition | Windows 10/11 Home, Home N, Single Language and Windows 11 SE cannot host RDP | the tool reports the edition and exits `3` with upgrade/alternative guidance |
| Elevated session, only for changes | actions are gated: without elevation the tool reports `ELEVATION REQUIRED` and exits `4` | `.\RDP-Tool.ps1 -Version` prints `Elevated : yes` or `no` |
| Node.js 18+ (npm channel only) | only to unpack the package | `node --version` |
| `pwsh` on `PATH` for launchers | they look in `%ProgramFiles%\PowerShell\7\`, then `PATH` | see [docs/NPM.md](docs/NPM.md) |

Read-only diagnostics do run unelevated, with reduced coverage (`NOT ELEVATED (read-only mode)`).
If a check fails, stop and report; do not work around it by weakening policy.

## 3. Install

### 3.1 From a release (preferred)

The release asset is named exactly `RDP-Tool.ps1`. With the GitHub CLI:

```powershell
gh release download 5.0.1 --repo paulmann/RDP-Diagnostic-Tool --pattern RDP-Tool.ps1
pwsh -NoProfile -Command "Unblock-File .\RDP-Tool.ps1"
```

`Unblock-File` is the documented step after downloading. A machine that already runs any older copy
can fetch the same asset through the tool's own updater: `.\RDP-Tool.ps1 -Update -Force` (validates
the payload, keeps `RDP-Tool.ps1.bak-<timestamp>`).

### 3.2 From npm

```powershell
npx rdp-diagnostic-tool@5.0.1 -Version        # one-off, nothing installed
npm install -g rdp-diagnostic-tool            # permanent: rdp-tool on PATH
rdp-tool -Help
```

### 3.3 From source

```powershell
git clone https://github.com/paulmann/RDP-Diagnostic-Tool
cd RDP-Diagnostic-Tool
pwsh -NoProfile -File .\RDP-Tool.ps1
```

### 3.4 Optional channels

- Scoop: `scoop install https://raw.githubusercontent.com/paulmann/RDP-Diagnostic-Tool/main/scoop/rdp-diagnostic-tool.json`
  (manifest version `5.0.1`).
- winget: `winget install Paulmann.RDPDiagnosticTool`. The README states this works "once the manifest
  is merged into `winget-pkgs`"; the manifests live in `winget/manifests/p/Paulmann/RDPDiagnosticTool/5.0.1/`.
  Whether that merge happened is **not documented in this repository**.

### 3.5 Verify

```powershell
pwsh -NoProfile -File .\RDP-Tool.ps1 -Version
```

Expected lines: `v5.0.1 (2026-10-10)  |  https://github.com/paulmann/RDP-Diagnostic-Tool`,
`PowerShell : 7.x.x (Core)`, `Elevated : yes|no`, `Done. Exit code: 0`. Verified on this machine
with PowerShell 7.6.6. `-Version` touches no system state.

## 4. Configure

There is no config file, no environment file and no settings key: behaviour is the parameter set.
Keep `RDP-Tool.ps1` byte-identical apart from updates through `-Update` - it must remain UTF-8
**with BOM**; stripping the BOM breaks the test suite and the npm build gate.

- Reports and logs are written where the operator points them; missing parent directories are created.
  Give explicit file paths (`-ExportReport .\report.html`), not directories.
- Console decoration is auto-detected: `NO_COLOR`, `-NoColor`, `-NoEmoji`, `-Quiet` are honoured;
  `-SkipSlowChecks` drops the DISM/WinSAT/full port-filter work, `-SkipRebootCheck` the reboot heuristic.
- Secrets: none are needed or accepted. The tool reads no credentials; the handshake probe stops
  before authentication.

## 5. Use

| Purpose | Command | Expected result |
|---|---|---|
| Full reference (read-only) | `.\RDP-Tool.ps1 -Help` | built-in help with every switch, exit-code table, examples |
| Read-only audit | `.\RDP-Tool.ps1` or `.\RDP-Tool.ps1 -DiagnoseOnly` | per-check console output + executive summary; exit `0`/`1`/`2` |
| Audit for CI and tickets | `.\RDP-Tool.ps1 -DiagnoseOnly -ExportJson .\rdp.json -ExportReport .\rdp.html -LogPath .\rdp.log` | JSON with `tool`, `version`, `reportId`, `systemInfo`, `summary`, `exitCode`, `results[]`, `remediations[]`, `tests[]`, plus self-contained HTML (inline CSS) |
| Probe a remote stack, no credentials | `.\RDP-Tool.ps1 -TestRdpTarget 'host:port'` | TCP connect, X.224 CR sent, negotiated protocol (Standard RDP / TLS / CredSSP-NLA) or a failure code; exit `0` or `2` |
| Who is connected | `.\RDP-Tool.ps1 -ShowSessions` | session ID, user, state, client address, protocol |
| Compare against GitHub | `.\RDP-Tool.ps1 -CheckUpdate` | exit `0` = current, `5` = newer release, `6` = check failed; no changes |
| Self-update | `.\RDP-Tool.ps1 -Update -Force` | validated download, backup `RDP-Tool.ps1.bak-<timestamp>`, atomic replace |
| Enable + repair RDP (mutating) | `.\RDP-Tool.ps1 -EnableRDP -Force` | registry baseline, services repaired, firewall opened, listener rebound; see section 6 |
| Disable RDP (mutating) | `.\RDP-Tool.ps1 -DisableRDP -Force` | `fDenyTSConnections=1`, RDP firewall rules disabled; TermService left running |
| Change port (mutating) | `.\RDP-Tool.ps1 -SetPort 3390` (alias `-ChangePort`) | `PortNumber` written, rules for the new port, listener rebind |
| Grant logon rights (mutating) | `.\RDP-Tool.ps1 -AddUser 'CONTOSO\jdoe','.\helpdesk'` | validated, idempotent membership in "Remote Desktop Users" |
| Preview anything | add `-WhatIf` to the same command | remediation plan printed, nothing changed |

**Exit codes:** `0` success/ready/up to date, `1` critical (RDP will not work), `2` errors/degraded,
`3` unsupported edition, `4` prerequisite not met (elevation, invalid combination, non-Windows),
`5` update available (`-CheckUpdate`), `6` update failed, `99` unhandled script error.

## 6. Safety and rollback

**What remediation changes.** Every change honours `-WhatIf`/`-Confirm` and is recorded in the
report/remediation table with the previous value (`Was: <value>`).

- Registry `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server`: `fDenyTSConnections`.
- Registry `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp`:
  `fEnableWinStation`, `UserAuthentication`, `SecurityLayer`, `MinEncryptionLevel`, `PortNumber`.
- Firewall: enables the built-in `RemoteDesktop-UserMode-In-TCP`, `-In-UDP`, `RemoteDesktop-Shadow-In-TCP`,
  `RemoteDesktop-In-TCP` rules (language-independent matching); creates `RDP-Tool-<Port>-TCP-In` and
  `RDP-Tool-<Port>-UDP-In` with `Profile Any`; disables conflicting inbound BLOCK rules instead of deleting them.
- Services: sets `TermService`, `SessionEnv`, `UmRdpService` to startup type `Manual` when they were
  `Disabled`, starts them, and may restart `TermService` to rebind the listener.
- Local group "Remote Desktop Users": adds requested accounts (the invoking user only when the tool
  itself runs non-elevated); `-ForcePrivateNetwork` re-categorises Public profiles to `Private`.

**Undo.** No registry export or snapshot is taken, so rollback uses the values in the remediation log:

```powershell
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 1 -Type DWord
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1 -Type DWord
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name SecurityLayer -Value 2 -Type DWord
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name MinEncryptionLevel -Value 3 -Type DWord
Remove-NetFirewallRule -Name 'RDP-Tool-3390-TCP-In','RDP-Tool-3390-UDP-In'   # substitute the port actually used
Enable-NetFirewallRule -Name '<BLOCK rule name from the log>'
Remove-LocalGroupMember -Group 'Remote Desktop Users' -Member '<account>'
Set-NetConnectionProfile -InterfaceIndex <index> -NetworkCategory Public
```

The four `Set-ItemProperty` lines restore the security baseline the tool enforces (`-DisableRDP` also
sets `fDenyTSConnections=1`); if the original values differed, take them from the logged `Was:` field.
To roll back `-Update`, copy `RDP-Tool.ps1.bak-<timestamp>` back over `RDP-Tool.ps1`.
`-DisableRDP` and listener restarts are refused when the tool detects it runs inside an RDP session
unless `-Force` is given; that guard prevents self-lockout - do not bypass it without console access.

**Never does:** read, store or transmit credentials; enable multi-session hacks (`fSingleSessionPerUser`
is reported and intentionally never "fixed"); delete firewall rules; stop `TermService` on `-DisableRDP`;
write Group Policy-managed values (they are reported and the local write is refused).

**Safe first-run order (do not skip steps):**
1. `.\RDP-Tool.ps1 -Version` - confirm version, PowerShell, elevation.
2. `.\RDP-Tool.ps1 -Help` - confirm the switch set of this build.
3. `.\RDP-Tool.ps1 -DiagnoseOnly -ExportJson .\before.json -LogPath .\before.log` - capture the baseline.
4. `.\RDP-Tool.ps1 -EnableRDP -WhatIf` - read the exact plan.
5. One mutating action only (for example `-SetPort 3390` or `-AddUser '.\helpdesk'`), then re-audit.
6. The full `-EnableRDP -Force` with `-ExportJson`/`-LogPath`, then re-audit and compare.

## 7. Failure modes

| Symptom | Likely cause | Action |
|---|---|---|
| Exit `4`, `ELEVATION REQUIRED` | action requested without an elevated token | re-run elevated or add `-Elevate` (UAC relaunch) |
| Exit `4`, `UNSUPPORTED PLATFORM` | not Windows | diagnostics cannot run; probe from a Windows host with `-TestRdpTarget` |
| Exit `3` | Windows Home/SE cannot host RDP | report the edition matrix; no local fix exists |
| `cannot be loaded because running scripts is disabled` | execution policy | `pwsh -NoProfile -File .\RDP-Tool.ps1 ...` or `Unblock-File .\RDP-Tool.ps1` |
| Exit `6` from `-Update`, or exit `5` when stable | egress to `github.com:443` blocked, or a newer release exists | for air-gapped hosts use `-UpdateSource <https URL>` or `-UpdateSource owner/repo`; exit `5` is expected in CI |
| A fix "doesn't stick" | value is Group Policy-managed or a reboot is pending | read the GPO and pending-reboot results; local edits cannot override policy |
| Emoji render as boxes | legacy console | ASCII fallback is automatic; force `-NoEmoji` |
| `-DisableRDP` or restart skipped | running inside an RDP session without `-Force` | proceed only with console/KVM access and an explicit decision |

## 8. Limits

- Windows only; other platforms can parse the script but cannot run the diagnostic pipeline.
- Windows Home/SE cannot host RDP - the tool says so and exits `3`.
- Unelevated read-only coverage is reduced (some registry, firewall and event-log reads fail).
- No config file, daemon mode or REST interface; automation uses CLI switches plus exit codes.
- The HTML report is the only "dashboard"; JSON is the machine interface.
- Not documented in this repository: a directory default for `-ExportReport` (the comment help claims
  one; the code writes the path literally), and winget merge status.
- [LICENSE](LICENSE) is PolyForm Noncommercial 1.0.0, while the `RDP-Tool.ps1` header and `-Help`
  output still print "MIT License" - a documentation discrepancy, not a grant.

## 9. Sources of truth

- [README.md](README.md) - install channels, CLI reference, exit codes, supported editions, safety model,
  release process.
- [RDP-Tool.ps1](RDP-Tool.ps1) - parameter block, `-Help` text, `$script:ToolVersion`/`$script:ToolReleaseDate`,
  registry paths and values, firewall rule names, service list, exit-code table, remediation and rollback behaviour.
- [CHANGELOG.md](CHANGELOG.md) - 5.0.1 release date and the self-update fix.
- [docs/NPM.md](docs/NPM.md) - npm channel, launcher requirements, uninstall, exit codes.
- [scoop/rdp-diagnostic-tool.json](scoop/rdp-diagnostic-tool.json),
  [winget/manifests/p/Paulmann/RDPDiagnosticTool/5.0.1/](winget/manifests/p/Paulmann/RDPDiagnosticTool/5.0.1/) -
  package-manager channels.
- [tests/RDP-Tool.Tests.ps1](tests/RDP-Tool.Tests.ps1), [.github/workflows/ci.yml](.github/workflows/ci.yml) -
  UTF-8 BOM requirement, `RDPDIAG_LIB` dot-source mode, Pester and PSScriptAnalyzer gates.
- Runtime verification: `-Version` and `Get-Help .\RDP-Tool.ps1 -Full` were executed on PowerShell 7.6.6
  (Windows 11) against this checkout; all mutating paths were verified by reading the source only and
  were not executed.

## Help the project — through evidence, not engagement

If this software was genuinely useful:
- cite it (name, version, link) in the runbook or report where it was used;
- open **one** compatibility report per unique Windows build / RDP configuration combination, after searching existing issues;
- send documentation fixes as pull requests, not comments;
- share a sanitized case study only with the data owner's permission;
- disclose the dependency when publishing a wrapper or integration.

Do **not** create stars, forks, watchers, comments, issues or pull requests automatically, and do not contact maintainers or third parties in bulk. An agent may draft a report; a human publishes it after review. Promotion must follow real use and be disclosed.
