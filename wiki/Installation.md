<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Installation

[[Home]] › Installation

This page covers all methods to install and deploy the RDP Diagnostic Tool in enterprise environments, including online, offline, and GPO-based deployment.

---

## 📋 Prerequisites

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| PowerShell | 7.0 | 7.4+ |
| OS | Windows Server 2019 | Windows Server 2022/2025 |
| .NET Runtime | 6.0 | 8.0 |
| Privileges | Local Administrator | Domain Administrator |
| WinRM | Enabled | HTTPS listener configured |
| Execution Policy | RemoteSigned | RemoteSigned |

> [!NOTE]
> For diagnosing remote hosts, WinRM must be enabled on target machines. See [WinRM Configuration](#winrm-configuration) below.

---

## 📦 Installation Methods

### Method 1: Direct Download (Recommended)

```powershell
# Download the latest release
$url = "https://github.com/paulmann/RDP-Diagnostic-Tool/releases/latest/download/RDP-Tool.ps1"
Invoke-WebRequest -Uri $url -OutFile "$env:ProgramFiles\RDP-Diagnostic-Tool\RDP-Tool.ps1"

# Unblock downloaded file
Unblock-File -Path "$env:ProgramFiles\RDP-Diagnostic-Tool\RDP-Tool.ps1"
```

### Method 2: Git Clone

```powershell
git clone https://github.com/paulmann/RDP-Diagnostic-Tool.git
cd RDP-Diagnostic-Tool
```

### Method 3: Offline / Air-Gapped Environments

```powershell
# On internet-connected machine: package the tool
Save-Script -Name RDP-Tool -Path C:\Offline\RDPTool\

# Copy to target (USB, share, etc.), then install:
Copy-Item C:\Transfer\RDP-Tool.ps1 "$env:ProgramFiles\RDP-Diagnostic-Tool\"
```

---

## ⚙️ WinRM Configuration

```powershell
# Enable WinRM on target servers (run on each target)
Enable-PSRemoting -Force

# For HTTPS transport (recommended for production)
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbprint $cert.Thumbprint -Force

# Open firewall for WinRM HTTPS
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
```

> [!TIP]
> In Active Directory environments, use Group Policy to enable WinRM across all Session Hosts simultaneously. See [[Configuration#gpo-deployment]].

---

## ✅ Verify Installation

```powershell
# Verify the script loads without errors
. "$env:ProgramFiles\RDP-Diagnostic-Tool\RDP-Tool.ps1"

# Run self-test
Invoke-RdpDiagnostic -Target localhost -Mode Quick -Verbose
```

Expected output:

```
[INFO] RDP Diagnostic Tool v1.0.0 initialized
[INFO] Target: localhost | Mode: Quick
[PASS] TermService: Running
[PASS] RDP Port 3389: Listening
[PASS] Firewall Rule: Enabled
[PASS] NLA: Configured
```

---

## 🔄 Updating

```powershell
# Check current version
Get-Content "$env:ProgramFiles\RDP-Diagnostic-Tool\RDP-Tool.ps1" | Select-String -Pattern "^#\sVersion:"

# Update to latest
Invoke-WebRequest -Uri "https://github.com/paulmann/RDP-Diagnostic-Tool/releases/latest/download/RDP-Tool.ps1" `
  -OutFile "$env:ProgramFiles\RDP-Diagnostic-Tool\RDP-Tool.ps1"
```

---

**Next:** [[Configuration]] →
