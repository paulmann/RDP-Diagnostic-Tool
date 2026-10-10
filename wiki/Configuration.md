<!-- Last Updated: 2026-10-09 | Version: 5.0.0 -->

# Configuration

[[Home]] › Configuration

Every behavior of `RDP-Tool.ps1` is controlled through switches - there is no
config file to drift. This page is the switch-by-switch reference; the same
content is available in-tool via `-Help` and `Get-Help .\RDP-Tool.ps1 -Full`.

---

## 🧩 Parameter Matrix

| Switch | Type | Elevation | Changes system | Notes |
|---|---|---|---|---|
| *(none)* | - | no | no | Full read-only diagnostic |
| `-DiagnoseOnly` | switch | no | no | Explicit read-only; `-SetPort`/`-DisableNLA` only shift the audit baseline |
| `-EnableRDP` | switch | **yes** | **yes** | Full enable + repair pipeline |
| `-DisableRDP` | switch | **yes** | **yes** | Deny connections + firewall off; remote-session guard |
| `-SetPort <n>` | int 1024-65535 | **yes** | **yes** | Alias `-ChangePort`; composes with `-EnableRDP` |
| `-DisableNLA` | switch | **yes** | **yes** | Insecure; confirmation required unless `-Force` |
| `-AddUser <list>` | string[] | **yes** | **yes** | Validates accounts; idempotent; SID-based group lookup (localized-safe) |
| `-RestartServices` | switch | **yes** | **yes** | Self-disconnect guard (needs `-Force` inside RDP) |
| `-ForcePrivateNetwork` | switch | **yes** | **yes** | Public → Private re-categorization |
| `-TestRdpTarget <h[:p]>` | string | no | no | X.224/RDP negotiation probe; IPv4/IPv6/hostname |
| `-ShowSessions` | switch | no | no | WTS API + qwinsta fallback |
| `-TestExternal` | switch | no | no | DNS + egress checks |
| `-SkipRebootCheck` | switch | no | no | |
| `-SkipSlowChecks` | switch | no | no | Skips DISM + full port-filter enumeration |
| `-ExportReport <path>` | string | no | file | Self-contained HTML |
| `-ExportJson <path>` | string | no | file | Machine-readable report |
| `-LogPath <path>` | string | no | file | Appended, complete even in `-Quiet` |
| `-NoBrowser` | switch | no | no | Don't auto-open HTML |
| `-Quiet` | switch | no | no | Summary + problems only |
| `-NoColor` / `-NoEmoji` | switch | no | no | `NO_COLOR` env honored; ASCII fallback auto-detected |
| `-CheckUpdate` | switch | no | no | Exit `5` when newer release exists |
| `-Update` | switch | write access to script | script file | Validated + backed-up + atomic |
| `-UpdateSource <src>` | string | no | no | `owner/repo` slug or HTTPS URL |
| `-Elevate` | switch | - | no | Relaunch elevated with same args (UAC) |
| `-Force` | switch | no | no | Maps to `$ConfirmPreference='None'` |
| `-ShowVerbose` | switch | no | no | **Deprecated** - use `-Verbose` |
| `-Version` | switch | no | no | |
| `-Help` / `-?` / `-h` | switch | no | no | Comprehensive built-in reference |
| `-WhatIf` / `-Confirm` | common | no | no | Honored by every mutating action |

Invalid combinations (e.g. `-EnableRDP -DisableRDP`, actions + `-DiagnoseOnly`)
are rejected with precise messages and exit code `4`.

---

## 🛡️ What `-EnableRDP` Actually Does

Ordered, idempotent, `-WhatIf`-aware; every step is recorded in the report:

1. **Registry baseline** - `fDenyTSConnections=0`, `fEnableWinStation=1`,
   NLA per policy (`UserAuthentication=1` unless `-DisableNLA`), `SecurityLayer=2`,
   `MinEncryptionLevel=3`, optional `PortNumber` from `-SetPort`.
   *GPO-managed values are detected and skipped with policy-path guidance.*
2. **Services** - TermService/SessionEnv/UmRdpService: un-disable (→ Manual,
   the Windows default trigger-start state), start, verify dependencies. RpcSs is
   reported, never reconfigured.
3. **Firewall** - enable built-in `RemoteDesktop-*` rules (language-independent
   matching), ensure tool-managed TCP+UDP allow rules for the effective port,
   optionally disable conflicting BLOCK rules (reversible).
4. **Permissions** - add the invoking non-admin user and any `-AddUser` accounts
   to *Remote Desktop Users* (well-known SID `S-1-5-32-555`, localized-safe).
5. **Listener rebind** - restart TermService only when something actually changed
   and never inside your own remote session without `-Force`.

---

## 🤖 Automation Recipes

### CI gate (fail build on broken RDP config)

```yaml
- name: RDP audit
  shell: pwsh
  run: |
    .\RDP-Tool.ps1 -DiagnoseOnly -Quiet -ExportJson rdp.json -NoBrowser
    if ($LASTEXITCODE -in 1,2) { throw "RDP misconfigured (exit $LASTEXITCODE)" }
```

### Fleet deployment (Intune/SCCM)

```powershell
pwsh -NoProfile -File C:\Tools\RDP-Tool.ps1 -EnableRDP -SetPort 3390 -Force -Quiet `
     -ExportJson C:\Temp\rdp-$env:COMPUTERNAME.json -LogPath C:\Temp\rdp-$env:COMPUTERNAME.log
exit $LASTEXITCODE     # the management system records per-host results
```

### Nightly drift detection

```powershell
.\RDP-Tool.ps1 -DiagnoseOnly -Quiet -ExportJson \\nas\rdp\$(Get-Date -f yyyyMMdd)-$env:COMPUTERNAME.json
# diff summary.exitCode / results[] between days
```

---

## 📦 JSON Report Schema (stable)

```jsonc
{
  "tool": "...", "version": "5.0.0", "reportId": "A1B2C3D4",
  "generatedUtc": "2026-10-09T12:00:00.000Z", "durationSec": 41.2,
  "computer": "WS-01",
  "systemInfo": { "Caption": "...", "EditionID": "...", "Build": "...", "RDPSupported": true, "...": "..." },
  "parameters": ["DiagnoseOnly", "ExportJson"],
  "summary": { "Total": 57, "Info": 49, "Warning": 6, "Error": 2, "Critical": 0, "TestsTotal": 3, "TestsPassed": 2,
               "Remediations": 0, "RemediationsOk": 0, "RemediationsFailed": 0 },
  "exitCode": 2,
  "results": [ { "component": "...", "status": "...", "details": "...", "remedy": "...",
                 "category": "Firewall", "severity": "ERROR", "severityLevel": 3, "time": "12:00:01.123" } ],
  "remediations": [ { "Action": "...", "Success": true, "Skipped": false, "Notes": "...", "Time": "..." } ],
  "tests": [ { "Name": "...", "Passed": true, "Message": "...", "Data": null, "Time": "..." } ]
}
```

---

## 🎨 Output Customization

- `-NoEmoji` (or non-UTF8 console → automatic): `[OK]/[WARN]/[FAIL]` ASCII markers
- `-NoColor` (or `NO_COLOR=1` env): plain text, pipe/redirect friendly
- `-Quiet`: summary + problems only - logs and reports stay complete

See also [[Usage]] and [[Security]].
