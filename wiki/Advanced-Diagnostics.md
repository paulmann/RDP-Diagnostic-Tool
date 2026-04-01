<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Advanced Diagnostics

[[Home]] › Advanced Diagnostics

This page covers expert-level diagnostic techniques using Windows Performance Recorder (WPR), WinDbg kernel debugging, Wireshark packet analysis, and memory dump analysis for RDP session host crashes.

---

## 🔬 Windows Performance Recorder (WPR)

WPR captures ETW (Event Tracing for Windows) traces for deep RDP performance analysis.

```powershell
# Start RDP-focused WPR trace
wpr.exe -start CPU -start DiskIO -start Network -start "Microsoft-Windows-TerminalServices-*" -filemode

# Reproduce the issue, then stop capture
wpr.exe -stop C:\Traces\rdp-trace-$(Get-Date -f yyyyMMdd-HHmm).etl

# Open in Windows Performance Analyzer
wpa.exe C:\Traces\rdp-trace-*.etl
```

**Key WPA analysis areas for RDP:**
- `CPU Usage (Sampled)` — identify CPU hotspots in `termsrv.dll`, `rdpwsx.dll`, `dwm.exe`
- `GPU Usage` — RemoteFX frame encoding time
- `Network I/O` — RDP PDU transmission latency per virtual channel
- `Disk I/O` — User Profile Disk (UPD) mount/access latency

---

## 🐛 Kernel Debugging: termdd.sys Crashes

<details>
<summary>▶ Expand: Full WinDbg kernel debugging procedure</summary>

### Prerequisites

```powershell
# Enable kernel debugging on target (requires reboot)
bcdedit /debug on
bcdedit /dbgsettings NET HOSTIP:[DEBUGGER_IP] PORT:50000 KEY:[AUTO_GENERATED_KEY]

# Configure complete memory dump
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name CrashDumpEnabled -Value 1
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name AlwaysKeepMemoryDump -Value 1
```

### WinDbg Analysis Commands

```
# Load dump file
.opendump C:\Windows\MEMORY.DMP

# Set symbol path
.sympath srv*C:\Symbols*https://msdl.microsoft.com/download/symbols
.reload /f

# Analyze crash
!analyze -v

# Inspect termdd.sys-specific structures
lkd> dt termdd!_ICA_STACK
lkd> dt termdd!_TD_ENDPOINT

# View RDP stack call at time of crash
lkd> kb 50
lkd> !stacks 2 termdd

# Check for memory corruption
lkd> !pool [address] 2
lkd> !verifier
```

### Common termdd.sys Bug Check Codes

| Bug Check | Code | Likely Cause |
|-----------|------|--------------|
| `DRIVER_IRQL_NOT_LESS_OR_EQUAL` | 0xD1 | Null pointer dereference in termdd |
| `SYSTEM_SERVICE_EXCEPTION` | 0x3B | Exception in terminal driver context |
| `PAGE_FAULT_IN_NONPAGED_AREA` | 0x50 | Freed memory access in ICA stack |

</details>

---

## 🌐 Wireshark: RDP Packet Analysis

```powershell
# Capture RDP traffic (requires WinPcap/Npcap on capture machine)
# Wireshark display filter for RDP:
# rdp || tpkt || x224 || cotp
```

**Useful Wireshark filters:**

| Filter | Purpose |
|--------|---------|
| `tcp.port == 3389` | All RDP TCP traffic |
| `rdp` | Decoded RDP PDUs |
| `rdp.encryptedClientRandom` | NLA/TLS handshake |
| `tcp.analysis.retransmission` | Packet loss indicators |
| `frame.time_delta > 0.5` | Latency spikes > 500ms |

**Key PDUs to examine:**
- `Demand Active PDU` — Server capability advertisement
- `Confirm Active PDU` — Client capability negotiation result
- `Synchronize PDU` — Session sync signal
- `Input PDU` — Keyboard/mouse events
- `Update PDU` — Screen update batches

> [!TIP]
> Export captured `.pcapng` to a dedicated analysis workstation. Avoid decrypting TLS-encapsulated RDP in production — use a test environment with server private key export enabled.

---

## 💾 Memory Dump Analysis for Session Host Crashes

```powershell
# Check for recent crash dumps
Get-ChildItem C:\Windows\Minidump -Filter "*.dmp" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
Get-Item C:\Windows\MEMORY.DMP | Select-Object LastWriteTime, Length

# Automated dump analysis with WinDbg CLI
& "${env:ProgramFiles(x86)}\Windows Kits\10\Debuggers\x64\cdb.exe" `
  -z C:\Windows\MEMORY.DMP `
  -c "!analyze -v; q" `
  -logo C:\Reports\dump-analysis.log

# Parse output for key indicators
Select-String -Path C:\Reports\dump-analysis.log -Pattern "FAILURE_BUCKET_ID|BugCheck|STACK_COMMAND"
```

---

**Next:** [[Security]] →
