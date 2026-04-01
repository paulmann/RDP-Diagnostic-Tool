<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Usage

[[Home]] › Usage

This page documents diagnostic modes, practical usage examples, and output format options for the RDP Diagnostic Tool.

---

## 🎯 Diagnostic Modes

| Mode | Duration | Checks Performed | Use Case |
|------|----------|------------------|----------|
| `Quick` | ~30 sec | Service state, port, firewall, NLA | Fast health check, monitoring integration |
| `Full` | ~2-5 min | All Quick checks + auth, sessions, drivers, GPU | Standard operational diagnostics |
| `Deep` | ~10-20 min | All Full checks + WPR traces, packet analysis, memory | Root cause analysis, escalation |

---

## 💻 Common Examples

### Basic Health Check

```powershell
# Check local machine
Invoke-RdpDiagnostic -Target localhost -Mode Quick

# Check a remote server
Invoke-RdpDiagnostic -Target "rdsh01.corp.local" -Mode Full -Verbose
```

### Bulk Diagnostics Across a Farm

```powershell
$servers = @("rdsh01", "rdsh02", "rdsh03", "rdsh04")
$results = $servers | ForEach-Object -Parallel {
    Invoke-RdpDiagnostic -Target $_ -Mode Quick -OutputFormat JSON
} -ThrottleLimit 4

# Export combined results
$results | ConvertTo-Json -Depth 5 | Out-File "C:\Reports\farm-health-$(Get-Date -f yyyyMMdd).json"
```

### Generate HTML Report

```powershell
Invoke-RdpDiagnostic -Target "rdsh01" -Mode Full -OutputFormat HTML -ReportPath "C:\RDPReports\"
# Opens: C:\RDPReports\rdsh01-diagnostic-20260401.html
```

### Remediation Mode

```powershell
# Automatically fix common issues (requires elevation + change approval)
Invoke-RdpDiagnostic -Target "server01" -Mode Full -Remediate -Verbose
```

> [!WARNING]
> The `-Remediate` flag will make configuration changes. Always test in a non-production environment first and obtain change management approval.

---

## 📊 Output Formats

### Console Output

```
╔══════════════════════════════════════════════════════════╗
║     RDP Diagnostic Tool v1.0.0 | Target: rdsh01         ║
╚══════════════════════════════════════════════════════════╝
[✅ PASS] TermService:           Running (PID: 1204)
[✅ PASS] RDP Port 3389:         Listening
[✅ PASS] Firewall RDP Rule:     Enabled
[✅ PASS] NLA Enforced:          Yes
[✅ PASS] TLS Version:           1.3
[⚠️ WARN] Active Sessions:       47/50 (94% capacity)
[✅ PASS] CredSSP:               Patched (CVE-2018-0886)
[✅ PASS] termdd.sys:            Version 10.0.20348.1 (OK)
[❌ FAIL] GPU RemoteFX:         VRAM exhausted (98% used)
```

### JSON Output (SIEM/ITSM Integration)

```json
{
  "target": "rdsh01.corp.local",
  "timestamp": "2026-04-01T13:44:00Z",
  "overallStatus": "Warning",
  "checks": [
    { "name": "TermService", "status": "Pass", "detail": "Running PID 1204" },
    { "name": "GPU_VRAM", "status": "Fail", "detail": "VRAM 98% utilized" }
  ]
}
```

---

## 🔄 Scheduled Monitoring

```powershell
# Create a scheduled task for daily diagnostics
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
  -Argument "-NonInteractive -File 'C:\RDP-Diagnostic-Tool\RDP-Tool.ps1' -Target localhost -Mode Full -OutputFormat HTML -ReportPath C:\RDPReports\"
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00AM"
Register-ScheduledTask -TaskName "RDP-Daily-Diagnostic" -Action $action -Trigger $trigger -RunLevel Highest
```

---

**Next:** [[Architecture]] →
