<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Security

[[Home]] › Security

This page covers enterprise RDP security hardening, Just-In-Time (JIT) access, Windows Defender Application Control (WDAC), and responsible disclosure.

> [!WARNING]
> RDP is a frequent attack vector. Exposed port 3389 without NLA, strong authentication, and network controls is a critical security risk. Apply all controls in this guide before exposing RDP to any network segment.

---

## 🔒 Baseline Hardening Checklist

- [ ] Enable **Network Level Authentication (NLA)** — pre-authenticates before session creation
- [ ] Enforce **TLS 1.2 minimum** (TLS 1.3 preferred)
- [ ] Disable **RDP Security Layer** (legacy, unencrypted)
- [ ] Enable **Account Lockout Policy** (≤5 attempts)
- [ ] Deploy **RD Gateway** to avoid exposing port 3389 directly
- [ ] Enable **MFA** via Azure AD Conditional Access or NPS extension
- [ ] Restrict RDP to **specific subnets** via Windows Firewall + NSG
- [ ] Enable **Enhanced Session Protection** (disable clipboard/drive redirection where not needed)
- [ ] Monitor Event IDs **4625, 4648, 1149** for brute-force detection

---

## ⏱️ Just-In-Time (JIT) RDP Access

JIT access grants RDP connectivity only during an approved time window, then automatically revokes it.

```powershell
# JIT Access implementation via PowerShell + Azure
function Enable-JITRDPAccess {
  param(
    [string]$VMName,
    [string]$ResourceGroup,
    [int]$MaxDurationHours = 4,
    [string]$RequesterIP = "[REDACTED]"
  )

  $justification = Read-Host "Enter business justification"

  # Request JIT access via Microsoft Defender for Cloud
  $jitPolicy = @{
    virtualMachines = @(@{
      id = (Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup).Id
      ports = @(@{
        number = 3389
        protocol = "TCP"
        allowedSourceAddressPrefix = $RequesterIP
        maxRequestAccessDuration = "PT${MaxDurationHours}H"
      })
    })
  }

  Start-AzJitNetworkAccessPolicy -ResourceGroupName $ResourceGroup `
    -Location (Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup).Location `
    -Name "default" -VirtualMachine $jitPolicy.virtualMachines

  Write-Host "[JIT] RDP access granted for $MaxDurationHours hours. Justification logged."
}
```

> [!TIP]
> Integrate JIT requests with your ITSM (ServiceNow, Jira) for automatic approval workflow and audit trail generation.

---

## 🛡️ Windows Defender Application Control (WDAC)

WDAC restricts which executables can interact with RDP components.

```powershell
# Generate a base WDAC policy allowing signed Microsoft binaries
New-CIPolicy -Level Publisher -FilePath C:\Policies\RDP-WDAC-Base.xml `
  -UserPEs -Fallback Hash

# Add RDP tool to allowed list
Add-SignerRule -FilePath C:\Policies\RDP-WDAC-Base.xml `
  -CertificatePath C:\Certs\CodeSign.cer `
  -Kernel -User -Update

# Convert to binary and deploy
ConvertFrom-CIPolicy -XmlFilePath C:\Policies\RDP-WDAC-Base.xml `
  -BinaryFilePath C:\Windows\System32\CodeIntegrity\SIPolicy.p7b
```

---

## 🔑 NLA and CredSSP Configuration

```powershell
# Enforce NLA via registry
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
  -Name UserAuthentication -Value 1

# Verify CredSSP is fully patched
$cspVer = (Get-Item "$env:SystemRoot\System32\credssp.dll").VersionInfo.ProductVersion
Write-Host "CredSSP Version: $cspVer"
# Must be >= patched version per CVE-2018-0886

# Force TLS 1.2+ only
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
  -Name MinEncryptionLevel -Value 3
# 3 = High (RC4-128 min), 4 = FIPS Compliant
```

---

## 📢 Responsible Disclosure

For security vulnerabilities in this tool, please follow the guidelines in [`SECURITY.md`](../SECURITY.md).

- **Do NOT** open public GitHub issues for security vulnerabilities
- **Email:** [mid1977@gmail.com](mailto:mid1977@gmail.com) with subject `[SECURITY] RDP-Diagnostic-Tool`
- Expected response time: **48 hours**
- CVE coordination available upon request

---

**Next:** [[Performance]] →
