<!-- Last Updated: 2026-10-09 | Version: 5.0.0 -->

# Usage

[[Home]] › Usage

This page documents the **actual v5.0.0 CLI** of `RDP-Tool.ps1`: modes, actions, probes, reporting and exit codes.

---

## 🎯 Operating Modes

| Invocation | Duration | Changes? | Use Case |
|---|---|---|---|
| `.\RDP-Tool.ps1` | ~20-60 sec | No | Full read-only audit (default) |
| `.\RDP-Tool.ps1 -DiagnoseOnly` | ~20-60 sec | No | Same, explicit intent for scripts/policies |
| `.\RDP-Tool.ps1 -EnableRDP` | ~30-90 sec | **Yes** | Enable + auto-repair (elevation required) |
| `.\RDP-Tool.ps1 -DisableRDP` | seconds | **Yes** | Emergency lock-down |
| `.\RDP-Tool.ps1 -TestRdpTarget <host[:port]>` | seconds | No | Remote/local protocol probe |
| `.\RDP-Tool.ps1 -ShowSessions` | seconds | No | Live session list |
| `.\RDP-Tool.ps1 -CheckUpdate` / `-Update` | seconds | file only | Version management |

Add `-SkipSlowChecks` to skip the DISM scan and full firewall port-filter enumeration on slow machines.

---

## 💻 Common Examples

### Basic health check

```powershell
.\RDP-Tool.ps1                       # local, read-only, colored summary + exit code
.\RDP-Tool.ps1 -Quiet                # summary and problems only
.\RDP-Tool.ps1 -Verbose              # per-check details
```

### Enable & repair (unattended)

```powershell
.\RDP-Tool.ps1 -EnableRDP -Force
.\RDP-Tool.ps1 -EnableRDP -SetPort 3390 -AddUser 'CONTOSO\jdoe','.\helpdesk' -Force
.\RDP-Tool.ps1 -EnableRDP -WhatIf    # preview the plan, change nothing
```

### Remote diagnostics without touching the target

```powershell
.\RDP-Tool.ps1 -TestRdpTarget "rdsh01.corp.local"          # default port 3389
.\RDP-Tool.ps1 -TestRdpTarget "10.0.0.5:3390"              # custom port
.\RDP-Tool.ps1 -TestRdpTarget "[2001:db8::10]:3389"        # IPv6 literal
```

The probe performs the same X.224/RDP negotiation `mstsc.exe` does before
authentication - **no credentials involved** - and reports:

- whether the endpoint is really RDP (vs. another TCP service on the port)
- the negotiated protocol: Standard RDP / TLS / **CredSSP (NLA)**
- exact failure codes (`HYBRID_REQUIRED_BY_SERVER`, `SSL_CERT_NOT_ON_SERVER`, ...)

### Farm sweep (parallel, JSON per host)

```powershell
$servers = @("rdsh01", "rdsh02", "rdsh03", "rdsh04")
$results = $servers | ForEach-Object -Parallel {
    $out = "C:\Temp\rdp-$_.json"
    & pwsh -NoProfile -File C:\Tools\RDP-Tool.ps1 -TestRdpTarget "$_:3389" -ExportJson $out -Quiet -NoBrowser
    [pscustomobject]@{ Server = $_; ExitCode = $LASTEXITCODE; Json = $out }
} -ThrottleLimit 4
$results | Format-Table
```

> Tip: for full audits run the tool **on** each host (via Remoting/SCCM/Intune);
> `-TestRdpTarget` is the zero-footprint remote option.

### Reports

```powershell
.\RDP-Tool.ps1 -ExportReport .\rdp.html -NoBrowser   # styled HTML (ticket attachment)
.\RDP-Tool.ps1 -ExportJson .\rdp.json                # CI/SIEM-consumable
.\RDP-Tool.ps1 -LogPath C:\Temp\rdp-run.log          # appended run log
```

### Sessions

```powershell
.\RDP-Tool.ps1 -ShowSessions
# SessionId User              State        WinStation ClientAddress Protocol
# --------- ----              -----        ---------- ------------- --------
#         0 -                 Listen       Services   -             Console
#         2 CONTOSO\jdoe      Active       RDP-Tcp#0  10.0.0.31     RDP
```

### Version management

```powershell
.\RDP-Tool.ps1 -CheckUpdate          # exit 5 = newer version published
.\RDP-Tool.ps1 -Update               # validated download + backup + atomic replace
.\RDP-Tool.ps1 -Update -UpdateSource https://intranet/tools/RDP-Tool.ps1
.\RDP-Tool.ps1 -Version
```

---

## 🔢 Exit Codes

| Code | Meaning | Typical automation reaction |
|---|---|---|
| `0` | Ready / success / up to date | continue |
| `1` | Critical issues - RDP broken | page on-call |
| `2` | Errors - RDP degraded | open ticket |
| `3` | Unsupported edition (Home/SE) | skip host |
| `4` | Prerequisite (elevation, bad parameter combo, non-Windows) | fix invocation |
| `5` | Update available (`-CheckUpdate`) | schedule `-Update` |
| `6` | Update failed | alert maintainer |
| `99` | Unhandled script error | file a bug with `-ExportReport` + `-LogPath` |

---

## ⌨️ Keyboard-Friendly Help

```powershell
.\RDP-Tool.ps1 -Help       # comprehensive built-in reference
.\RDP-Tool.ps1 -?          # same
Get-Help .\RDP-Tool.ps1 -Full       # PowerShell help system (all .PARAMETER entries)
Get-Help .\RDP-Tool.ps1 -Examples   # just the examples
```

See [[Configuration]] for switch-by-switch detail and [[Troubleshooting]] for failures.
