<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Troubleshooting

[[Home]] › Troubleshooting

This page provides systematic root-cause analysis procedures for the most common RDP failure categories encountered in enterprise environments.

---

## 🔗 Connectivity Issues

### RDP Port Not Listening

**Symptoms:** Connection refused on port 3389; `Test-NetConnection` returns `TcpTestSucceeded: False`.

**Diagnosis:**
```powershell
# Check if port 3389 is listening
Get-NetTCPConnection -LocalPort 3389 -ErrorAction SilentlyContinue

# Verify TermService is running
Get-Service -Name TermService | Select-Object Status, StartType

# Check registry RDP enable flag
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections
# Expected: 0 (RDP enabled)
```

**Resolution:**
```powershell
# Enable RDP
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0

# Start/restart TermService
Restart-Service -Name TermService -Force

# Enable firewall rule
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

---

### Firewall Blocking RDP

**Diagnosis:**
```powershell
# Test connectivity from a remote machine
Test-NetConnection -ComputerName "server01" -Port 3389

# Check Windows Firewall rules
Get-NetFirewallRule -DisplayGroup "Remote Desktop" | Select-Object DisplayName, Enabled, Direction, Action

# Check for third-party firewall (event log)
Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=5152 or EventID=5157]]" -MaxEvents 20
```

---

## 🔐 Authentication Issues

### CredSSP Encryption Oracle Remediation Error

**Error:** `CredSSP encryption oracle remediation` — client/server CredSSP patch level mismatch.

**Root Cause:** CVE-2018-0886 patch applied on one side but not the other, causing `Encryption Oracle Remediation` policy conflict.

**Diagnosis:**
```powershell
# Check CredSSP policy on client
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters' -ErrorAction SilentlyContinue
# AllowEncryptionOracle: 0=Force Updated Clients (strict), 1=Mitigated, 2=Vulnerable
```

**Resolution:**
```powershell
# Temporary workaround (revert to Mitigated — apply patch ASAP)
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters' `
  -Name AllowEncryptionOracle -Value 2 -PropertyType DWORD -Force
# ⚠️ APPLY THE SECURITY PATCH (KB4103723 or later) IMMEDIATELY — revert policy after patching
```

> [!WARNING]
> Setting `AllowEncryptionOracle = 2` is a temporary measure only. Apply the May 2018 or later cumulative update to ALL affected systems, then reset policy to `0`.

---

### Kerberos Authentication Failures

**Symptoms:** Event ID 4625 with `Failure Reason: 0xC000006D`, or `KRB_AP_ERR_MODIFIED`.

**Diagnosis:**
```powershell
# Check SPN registration for the RDP service
SetSPN -L "server01"
# Look for: TERMSRV/server01 and TERMSRV/server01.corp.local

# Verify time sync (Kerberos requires <5 min skew)
w32tm /query /status

# Check for duplicate SPNs
SetSPN -X
```

**Resolution:**
```powershell
# Register missing SPN
SetSPN -A TERMSRV/server01.corp.local server01

# Force time sync
w32tm /resync /force
```

---

## ⚡ Performance Issues

### Network-Induced Performance Degradation

**Symptoms:** Sluggish desktop, high input latency, frequent screen freeze.

```powershell
# Measure RDP session latency
$rdpSessions = Get-WmiObject -Class Win32_PerfFormattedData_LocalSessionManager_TerminalServices
$rdpSessions | Select-Object Name, InputDelayPerSession, InputDelayPerUser |
  Where-Object { $_.InputDelayPerSession -gt 100 }

# Check packet loss
Test-NetConnection -ComputerName "server01" -Port 3389 -InformationLevel Detailed
```

**Optimization:**
```powershell
# Configure QoS DSCP marking for RDP traffic (Expedited Forwarding)
New-NetQosPolicy -Name "RDP-QoS" -AppPathNameMatchCondition "mstsc.exe" -DSCPAction 46

# Reduce color depth for low-bandwidth links
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name ColorDepth -Value 2
# 1=8bpp, 2=15bpp, 3=16bpp, 4=24bpp, 5=32bpp
```

---

### Server-Side Resource Exhaustion

```powershell
# Check session host resource utilization
Get-Counter -Counter @(
  "\Terminal Services Session(*) (*)\% Processor Time",
  "\Memory\Available MBytes",
  "\Terminal Services\Active Sessions",
  "\Terminal Services\Inactive Sessions"
) -SampleInterval 5 -MaxSamples 3

# Identify top CPU-consuming RDP sessions
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, SessionId, WorkingSet
```

---

## 📋 Clipboard Redirection Failures

**Symptoms:** Copy/paste not working between RDP session and local machine.

```powershell
# Check CLIPRDR virtual channel driver
Get-WmiObject -Class Win32_SystemDriver | Where-Object { $_.Name -eq "rdpclip" }

# Restart clipboard process in session
$sessions = query session | Where-Object { $_ -match "Active" }
# In affected session:
Get-Process rdpclip -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process rdpclip.exe

# Verify Group Policy allows clipboard
(Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services').fDisableClip
# Expected: 0 or key absent
```

---

## 📊 Quick Reference: Event IDs

| Event ID | Log | Meaning |
|----------|-----|---------|
| 4625 | Security | Logon failure (check SubStatus for reason) |
| 4778 | Security | RDP session reconnected |
| 4779 | Security | RDP session disconnected |
| 1149 | TerminalServices-RemoteConnectionManager | Successful RDP authentication |
| 1158 | TerminalServices-LocalSessionManager | Session logon succeeded |
| 40 | TerminalServices-LocalSessionManager | Session disconnect |
| 41 | TerminalServices-LocalSessionManager | Session reconnect |
| 1006 | TerminalServices-Gateway | Gateway connection |

---

**Next:** [[Advanced-Diagnostics]] →
