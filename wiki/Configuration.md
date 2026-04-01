<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Configuration

[[Home]] › Configuration

This page describes all available parameters, configuration profiles, and enterprise Group Policy integration for the RDP Diagnostic Tool.

---

## 🔧 Parameters Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Target` | `string` | `localhost` | Target hostname or IP |
| `-Mode` | `string` | `Full` | Diagnostic mode: `Quick`, `Full`, `Deep` |
| `-OutputFormat` | `string` | `Console` | Output: `Console`, `JSON`, `HTML`, `CSV` |
| `-ReportPath` | `string` | `$PWD` | Directory for report files |
| `-Credential` | `PSCredential` | *(current user)* | Alternate credentials for remote targets |
| `-Remediate` | `switch` | `$false` | Enable automatic remediation (use with caution) |
| `-SkipModules` | `string[]` | `@()` | Modules to skip (e.g., `GPU`, `Licensing`) |
| `-Timeout` | `int` | `30` | Per-check timeout in seconds |
| `-Verbose` | `switch` | `$false` | Enable verbose diagnostic output |

---

## 📁 Configuration Profiles

Create a JSON profile to standardize settings across your environment:

```json
{
  "ProfileName": "Enterprise-Standard",
  "DefaultMode": "Full",
  "OutputFormat": "HTML",
  "ReportPath": "\\\\fileserver\\rdp-reports\\",
  "Timeout": 45,
  "SkipModules": ["GPU"],
  "AlertThresholds": {
    "MaxSessionLatencyMs": 150,
    "MaxCPUPercent": 85,
    "MaxMemoryPercent": 90
  }
}
```

Load the profile:

```powershell
Invoke-RdpDiagnostic -Target "rdsh01" -Profile "C:\RDPTool\enterprise-standard.json"
```

---

## 🏢 GPO Deployment {#gpo-deployment}

<details>
<summary>▶ Expand: Group Policy deployment instructions</summary>

1. **Create a GPO** named `RDP-Diagnostic-Tool-Deploy` in your domain.
2. Under **Computer Configuration → Windows Settings → Scripts (Startup)**:
   ```powershell
   # startup-deploy.ps1
   $dest = "$env:ProgramFiles\RDP-Diagnostic-Tool"
   if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
   Copy-Item "\\domain.corp\SYSVOL\scripts\RDP-Tool.ps1" $dest -Force
   ```
3. Link the GPO to the **RDS Session Hosts** OU.
4. Set **Execution Policy** via GPO:
   - Path: `Computer Configuration → Administrative Templates → Windows Components → Windows PowerShell`
   - Setting: `Turn on Script Execution` → `Allow only signed scripts` or `RemoteSigned`

</details>

---

## 🔐 Credential Management

> [!WARNING]
> Never store plaintext credentials in scripts. Use Windows Credential Manager or a secrets vault.

```powershell
# Store credentials securely
$cred = Get-Credential -Message "Enter RDP Diagnostic credentials"
$cred | Export-Clixml -Path "$env:APPDATA\rdp-diag-cred.xml"

# Load stored credentials
$cred = Import-Clixml -Path "$env:APPDATA\rdp-diag-cred.xml"
Invoke-RdpDiagnostic -Target "server01" -Credential $cred
```

> [!TIP]
> In Azure AD / Entra ID environments, consider using Managed Identities for credential-free remote execution.

---

**Next:** [[Usage]] →
