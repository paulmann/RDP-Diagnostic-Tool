# RDP Diagnostic & Remediation Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://docs.microsoft.com/en-us/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/en-us/windows/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-4.2.0-success.svg)](https://github.com/paulmann/RDP-Diagnostic-Tool/releases/tag/4.2.0)

**A comprehensive PowerShell-based diagnostic and remediation tool for Remote Desktop Protocol (RDP) connectivity on Windows 10/11 systems.** This tool performs extensive system analysis, identifies configuration issues, and provides automated remediation capabilities with detailed HTML reporting.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Command Examples](#command-examples)
- [Supported Windows Editions](#supported-windows-editions)
- [Architecture & Design](#architecture--design)
- [Diagnostics Coverage](#diagnostics-coverage)
- [Remediation Capabilities](#remediation-capabilities)
- [Exit Codes](#exit-codes)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Support](#support)

## 🎯 Overview

Remote Desktop Protocol (RDP) is a critical component of modern Windows administration and remote work infrastructure. However, RDP configuration issues remain a common source of support tickets and connectivity problems. This tool addresses this challenge by providing:

### The Problem It Solves

1. **Complex Diagnostics** - RDP failures can stem from dozens of different sources: misconfigured registry settings, disabled services, firewall rules, network profiles, permissions, Windows edition limitations, and more
2. **Time-Consuming Troubleshooting** - Manual investigation requires knowledge of numerous registry keys, services, firewall rules, and system configurations
3. **Error Recovery** - When RDP breaks, system administrators need a way to systematically identify and remediate the issue
4. **Compliance Verification** - Organizations need to ensure systems are properly configured for remote access security

### The Solution

The **RDP Diagnostic & Remediation Tool** provides:

- **Comprehensive System Analysis** - Checks 50+ different RDP-related configurations across registry, services, firewall, network, permissions, and system resources
- **Automated Problem Detection** - Identifies misconfigurations with detailed severity levels (info, warning, error, critical)
- **One-Click Remediation** - Automatically fixes common RDP issues with the `-EnableRDP` parameter
- **Detailed Reporting** - Generates color-coded terminal output and optional HTML reports
- **Safe Testing** - Diagnostic-only mode (`-DiagnoseOnly`) lets you assess issues without making changes
- **Production-Ready** - Designed for enterprise environments with proper error handling and logging

## ✨ Features

### Core Diagnostic Capabilities

| Feature | Description |
|---------|-------------|
| **Prerequisite Validation** | Checks administrative privileges, PowerShell version, Windows edition compatibility |
| **Registry Analysis** | Validates 15+ critical RDP registry settings (connection state, port, authentication, security) |
| **Service Configuration** | Audits 6+ RDP-related Windows services and their dependencies |
| **Firewall Assessment** | Analyzes Windows Defender Firewall rules, profiles, and port accessibility |
| **Network Configuration** | Evaluates network adapters, profiles (Private/Public/Domain), and connectivity |
| **Port & Connectivity Testing** | Tests local port listening, network loopback, and external connectivity |
| **Security Policy Review** | Checks Group Policy, UAC, Windows Defender, Credential Guard status |
| **User Permissions Analysis** | Verifies Remote Desktop Users group membership and RDP rights |
| **Performance Evaluation** | Reports on system resources (CPU, memory, graphics, disk) |
| **Event Log Inspection** | Analyzes RDP-related events and security logs for errors/warnings |

### Remediation Features

- **Service Auto-Start** - Configures TermService and dependencies with correct startup types
- **Registry Correction** - Applies recommended settings for RDP functionality and security
- **Firewall Rule Management** - Creates and enables necessary inbound RDP rules
- **Network Profile Adjustment** - Converts Public profiles to Private (with `-ForcePrivateNetwork`)
- **Dependency Resolution** - Automatically starts dependent services
- **Windows Feature Installation** - Can enable RemoteDesktop-Server feature if missing
- **Permission Correction** - Adds users to Remote Desktop Users group
- **Port Configuration** - Changes RDP port to non-standard values with `-ChangePort`

### Reporting Capabilities

- **Color-Coded Console Output** - Real-time results with visual severity indicators
- **Structured Categorization** - Results grouped by component category (Core, Network, Security, etc.)
- **HTML Export** - Professional reports saved to file with `-ExportReport`
- **Timestamped Logging** - All diagnostic checks include precise timestamps
- **Summary Statistics** - Executive overview with pass/fail/warning counts
- **Detailed Remediation Log** - Complete history of attempted fixes and results
- **Recommendations Section** - Actionable next steps based on findings

## 🔧 System Requirements

### Minimum Requirements

| Requirement | Specification |
|-------------|---|
| **Operating System** | Windows 10/11 Pro, Enterprise, Education, or Server 2016+ |
| **PowerShell** | 5.1 or higher (built into Windows 10/11) |
| **Administrator Rights** | Required to read configuration and apply remediation |
| **Disk Space** | Minimal (< 1 MB for script and reports) |
| **RAM** | Minimal (diagnostic process uses < 50 MB) |

### Supported Editions

✅ **Fully Supported:**
- Windows 10/11 Professional
- Windows 10/11 Enterprise
- Windows 10/11 Education
- Windows 10/11 Pro for Workstations
- Windows Server 2016/2019/2022

❌ **Not Supported (No RDP Server):**
- Windows 10/11 Home Edition*
- Windows 10/11 S Mode

> *Windows Home can use RDP Client to connect to other computers, but cannot accept incoming RDP connections (server functionality).

### Supported Configurations

| Aspect | Support |
|--------|---------|
| **Language** | English (script output, diagnostics) |
| **Network** | Works in domain, workgroup, isolated networks |
| **Virtualization** | Full support for VMs (Hyper-V, VMware, VirtualBox, etc.) |
| **Graphics** | Works with dedicated GPUs, integrated graphics, and virtual adapters |
| **Firewalls** | Compatible with Windows Defender Firewall and 3rd-party firewalls |

## 📥 Installation

### Method 1: Download from GitHub (Recommended)

```powershell
# Navigate to desired directory
cd $HOME\Desktop

# Download the latest script
Invoke-WebRequest -Uri "https://github.com/paulmann/RDP-Diagnostic-Tool/raw/refs/heads/main/RDP-Tool.ps1" `
    -OutFile "RDP-Tool.ps1"

# Verify download
Get-Item RDP-Tool.ps1
```

### Method 2: Clone Repository

```powershell
# Clone the entire repository
git clone https://github.com/paulmann/RDP-Diagnostic-Tool.git
cd RDP-Diagnostic-Tool
```

### Method 3: Manual Download

1. Navigate to [GitHub Repository](https://github.com/paulmann/RDP-Diagnostic-Tool)
2. Click **Code** → **Download ZIP**
3. Extract to desired location
4. Right-click `RDP-Tool.ps1` → **Properties** → check **Unblock** checkbox → **OK**

### Execution Policy Configuration

If you encounter execution policy restrictions:

```powershell
# Option 1: Run single script bypassing policy
powershell -ExecutionPolicy Bypass -File RDP-Tool.ps1 -DiagnoseOnly

# Option 2: Temporarily change execution policy (current session only)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
.\RDP-Tool.ps1 -EnableRDP
```

## 🚀 Usage

### Basic Syntax

```powershell
.\RDP-Tool.ps1 [OPTIONS]
```

### Display Help

```powershell
# Show help message
.\RDP-Tool.ps1 -Help

# Or use aliases
.\RDP-Tool.ps1 -?
.\RDP-Tool.ps1 /?
```

## 📚 Command Examples

### Example 1: Diagnostic Mode (No Changes)

Run complete diagnostics without modifying system configuration:

```powershell
.\RDP-Tool.ps1 -DiagnoseOnly

# With verbose output for detailed information
.\RDP-Tool.ps1 -DiagnoseOnly -ShowVerbose
```

---

### Example 2: Enable RDP with Automatic Remediation

Configure RDP with automatic fixing of common issues:

```powershell
.\RDP-Tool.ps1 -EnableRDP

# With private network enforcement
.\RDP-Tool.ps1 -EnableRDP -ForcePrivateNetwork
```

---

### Example 3: Change RDP Port

Configure RDP on non-standard port for security:

```powershell
# Use port 3390 instead of default 3389
.\RDP-Tool.ps1 -ChangePort 3390 -EnableRDP

# Diagnose configuration on custom port
.\RDP-Tool.ps1 -ChangePort 3390 -DiagnoseOnly
```

---

### Example 4: Export Diagnostic Report

Generate HTML report for documentation:

```powershell
.\RDP-Tool.ps1 -DiagnoseOnly -ExportReport "C:\Reports\RDP-Report.html"

# With detailed analysis
.\RDP-Tool.ps1 -DiagnoseOnly -ShowVerbose -ExportReport ".\RDP-Report-$(Get-Date -f yyyy-MM-dd).html"
```

---

### Example 5: Comprehensive Analysis with External Testing

Run full diagnostics including external connectivity:

```powershell
.\RDP-Tool.ps1 -DiagnoseOnly -ShowVerbose -TestExternal

# Full remediation with testing
.\RDP-Tool.ps1 -EnableRDP -TestExternal -ExportReport ".\Full-Analysis.html"
```

---

### Example 6: Troubleshoot RDP Issues

Step-by-step troubleshooting approach:

```powershell
# Step 1: Diagnose without changes
.\RDP-Tool.ps1 -DiagnoseOnly -ShowVerbose

# Step 2: Review critical issues
# (Check output for [CRITICAL] and [ERROR] items)

# Step 3: Apply fixes
.\RDP-Tool.ps1 -EnableRDP

# Step 4: Verify remediation
.\RDP-Tool.ps1 -DiagnoseOnly

# Step 5: Export final report
.\RDP-Tool.ps1 -DiagnoseOnly -ExportReport ".\RDP-Final-Status.html"

# Step 6: Restart if needed
Restart-Computer -Confirm
```

---

### Example 7: Private Network Enforcement

Configure RDP with Private network profile requirement:

```powershell
# Force all network connections to Private profile
.\RDP-Tool.ps1 -EnableRDP -ForcePrivateNetwork
```

---

### Example 8: Disable NLA (For Compatibility)

Connect from older RDP clients that don't support NLA:

```powershell
# Disable Network Level Authentication (less secure)
.\RDP-Tool.ps1 -EnableRDP -DisableNLA
```

⚠️ **Security Warning:** Only disable NLA for legacy client compatibility.

---

### Example 9: Real-World Scenario - System Recovery

After unexpected RDP failure:

```powershell
# Step 1: Analyze current state
.\RDP-Tool.ps1 -DiagnoseOnly -ShowVerbose -ExportReport "Before.html"

# Step 2: Attempt automatic recovery
.\RDP-Tool.ps1 -EnableRDP -ForcePrivateNetwork

# Step 3: Verify restoration
.\RDP-Tool.ps1 -DiagnoseOnly -TestExternal -ExportReport "After.html"

# Step 4: Reboot
Restart-Computer -Force
```

## 🏷️ Supported Windows Editions

### Professional Editions (✅ Full RDP Server Support)

| Edition | RDP Support | Details |
|---------|:-----------:|---------|
| **Windows 11 Pro** | ✅ Yes | Recommended for modern deployments |
| **Windows 10 Pro** | ✅ Yes | Stable and widely used |
| **Windows 11 Enterprise** | ✅ Yes | Full featured, LTSC option available |
| **Windows 10 Enterprise** | ✅ Yes | LTSC version for long-term support |
| **Windows Server 2016/2019/2022** | ✅ Yes | Server edition, fully supported |

### Consumer Editions (❌ No RDP Server Support)

| Edition | RDP Server | RDP Client | Details |
|---------|:----------:|:----------:|---------|
| **Windows 11 Home** | ❌ No | ✅ Yes | Cannot accept connections, can initiate them |
| **Windows 10 Home** | ❌ No | ✅ Yes | Cannot accept connections, can initiate them |

## 🏗️ Architecture & Design

### Script Organization

The tool is organized into logical regions for maintainability:

```
1. Parameters & Help        - Command-line interface definition
2. Initialization           - Global variables, color definitions, functions
3. Prerequisite Checks      - Admin rights, PowerShell version, OS compatibility
4. Windows Edition Analysis - Edition detection and RDP support verification
5. RDP Capability Tests     - DLL checks, driver validation
6. Enhanced Diagnostics     - Registry, services, firewall, network analysis
7. Security & Policies      - Group Policy, UAC, Defender, Credential Guard
8. User Permissions         - Remote Desktop Users group, RDP rights
9. Performance Analysis     - System resources, CPU, memory, graphics, disk
10. Event Log Analysis      - RDP event examination
11. Reporting              - Summary generation and HTML export
12. Main Execution         - Orchestration of all diagnostic flows
```

### Design Principles

- **Modular Functions** - Each diagnostic area is independently testable
- **Error Handling** - Comprehensive try-catch blocks prevent cascading failures
- **Structured Output** - Diagnostic results stored in PowerShell objects for analysis
- **Color Coding** - Severity levels visually indicated (Green=OK, Yellow=Warning, Red=Error)
- **Safe Defaults** - Diagnostic mode by default, remediation opt-in
- **Comprehensive Logging** - All actions timestamped and recorded
- **User-Centric** - Clear guidance on issues and how to fix them

## 🔍 Diagnostics Coverage

### Registry Validation (15+ Settings)

The tool validates critical RDP registry configuration:

```powershell
HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\
├─ fDenyTSConnections        (0 = RDP enabled)
├─ fSingleSessionPerUser     (0 = Multiple connections)
└─ WinStations\RDP-Tcp\
   ├─ PortNumber             (Default: 3389)
   ├─ UserAuthentication     (1 = NLA enabled)
   ├─ SecurityLayer          (2 = Negotiate security)
   ├─ MinEncryptionLevel     (3 = High encryption)
   ├─ MaxConnectionTime      (0 = Unlimited)
   ├─ MaxIdleTime            (0 = Unlimited)
   └─ fDisableAudioCapture   (1 = Disable audio)
```

### Service Analysis (6 Services)

Critical RDP services and their dependencies:

1. **TermService** (Remote Desktop Services) - Core RDP service
2. **SessionEnv** (Remote Desktop Configuration) - Session management
3. **UmRdpService** (RDP UserMode Port Redirector) - USB redirection
4. **RdpVideoMiniport** (Video Miniport Driver) - Video streaming
5. **AudioEndpointBuilder** (Windows Audio Endpoint) - Audio support
6. **Audiosrv** (Windows Audio) - Audio service

### Firewall Rules Analysis

- Inbound RDP rules (TCP/UDP on configured port)
- Blocked port detection
- Profile-specific rules (Domain/Private/Public)
- Network Discovery rules
- Conflicting rules identification

### Network Configuration Checks

- Physical adapter status
- IP address configuration (IPv4/IPv6)
- Network profiles (Private/Public/Domain)
- Default gateway
- DNS resolution
- Network isolation rules

### Security Verification

- Group Policy RDP settings
- User Account Control status
- Windows Defender real-time protection
- Credential Guard activation
- Security event log auditing
- User permissions and group membership

## 🔧 Remediation Capabilities

### Automatic Fixes Applied with `-EnableRDP`

| Component | Action | Details |
|-----------|--------|---------|
| **Registry** | Correct misconfigured values | Apply recommended RDP settings |
| **Services** | Enable and start required services | TermService + dependencies |
| **Firewall** | Create inbound rules | TCP/UDP on configured port |
| **Network** | Change to Private profile | If using -ForcePrivateNetwork |
| **Permissions** | Add users to RDP group | If current user not authorized |
| **Features** | Enable RDP Windows feature | If not installed |
| **Dependencies** | Start service dependencies | Auto-resolve broken dependency chains |
| **Port** | Configure custom RDP port | If using -ChangePort |

## 📊 Exit Codes

The script returns specific exit codes for automation and scripting:

```powershell
$exitCode = & .\RDP-Tool.ps1 -DiagnoseOnly

switch ($exitCode) {
    0 { Write-Host "RDP fully functional" }
    1 { Write-Host "Critical errors prevent RDP" }
    2 { Write-Host "RDP may work with limitations" }
    3 { Write-Host "Windows edition doesn't support RDP Server" }
    4 { Write-Host "Missing critical prerequisites" }
    99 { Write-Host "Script execution error" }
}
```

| Code | Meaning | Action |
|------|---------|--------|
| **0** | ✅ All tests passed | RDP ready for use |
| **1** | ❌ Critical errors | Fix issues before using RDP |
| **2** | ⚠️ Warnings detected | RDP may work with limitations |
| **3** | ❌ Unsupported edition | Upgrade to Pro/Enterprise edition |
| **4** | ❌ Missing prerequisites | Install required components |
| **99** | ❌ Script error | Check prerequisites and retry |

## 🆘 Troubleshooting

### Issue: "Access Denied" / "Not Administrator"

```powershell
# Problem: Script requires administrative privileges
# Solution: Run PowerShell as Administrator

# Right-click PowerShell → Run as Administrator
# Then execute the script:
.\RDP-Tool.ps1 -EnableRDP
```

---

### Issue: "Execution Policy Prevents Script"

```powershell
# Problem: PowerShell execution policy blocks script
# Solution 1: Bypass for single execution
powershell -ExecutionPolicy Bypass -File RDP-Tool.ps1 -DiagnoseOnly

# Solution 2: Change policy (temporary)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
.\RDP-Tool.ps1 -EnableRDP

# Solution 3: Unblock downloaded file
Unblock-File -Path .\RDP-Tool.ps1
.\RDP-Tool.ps1 -DiagnoseOnly
```

---

### Issue: "Windows Edition Not Supported"

```powershell
# Problem: Running on Windows Home edition
# Why: Windows Home doesn't include RDP Server capability

# Solutions:
#   1. Upgrade to Windows Pro ($99-199)
#   2. Use alternative: TeamViewer, AnyDesk, Chrome Remote Desktop
#   3. Use Windows Quick Assist (built-in)

# Check your edition:
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Caption
```

---

### Issue: "Cannot Connect from Remote Client"

```powershell
# Network connectivity tests:
.\RDP-Tool.ps1 -TestExternal

# Verify firewall rules:
Get-NetFirewallRule -DisplayName "*Remote Desktop*"

# Test port listening:
Test-NetConnection -ComputerName localhost -Port 3389 -Verbose

# Check network profile:
Get-NetConnectionProfile

# Verify from remote:
Test-NetConnection -ComputerName <hostname/IP> -Port 3389 -Verbose
```

---

### Issue: "Performance Is Slow"

```powershell
# Analyze performance:
.\RDP-Tool.ps1 -DiagnoseOnly | Select-String -Pattern "Memory|CPU|Graphics|Disk"

# Check Event Logs for errors:
Get-WinEvent -LogName System -FilterXPath "*[System[Provider[@Name='TermService']]]" -MaxEvents 10
```

## 🔨 Advanced Configuration

### Custom Port Configuration

```powershell
# Change RDP to port 3390
.\RDP-Tool.ps1 -ChangePort 3390 -EnableRDP

# Connect using custom port:
mstsc /v:servername:3390
```

### Network Level Authentication (NLA)

```powershell
# Disable NLA (for legacy clients)
.\RDP-Tool.ps1 -EnableRDP -DisableNLA

# Re-enable NLA (recommended)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
    -Name UserAuthentication -Value 1 -Force
```

### Force Private Network Profile

```powershell
# Enforce Private network profile for enhanced security
.\RDP-Tool.ps1 -EnableRDP -ForcePrivateNetwork

# View network profiles:
Get-NetConnectionProfile
```

## 📞 Support

### Documentation

- **GitHub Issues** - [Report bugs and request features](https://github.com/paulmann/RDP-Diagnostic-Tool/issues)
- **Discussions** - [Ask questions and share knowledge](https://github.com/paulmann/RDP-Diagnostic-Tool/discussions)

### Author

**Mikhail Deynekin**
- Website: [deynekin.com](https://deynekin.com)
- Email: [mid1977@gmail.com](mailto:mid1977@gmail.com)
- GitHub: [@paulmann](https://github.com/paulmann)

### License

This project is licensed under the MIT License. See the LICENSE file for full details.

---

**Version:** 4.2.0  
**Last Updated:** December 8, 2025  
**Status:** Production Ready