<!-- Last Updated: 2026-10-09 | Version: 5.0.0 -->

# Installation

[[Home]] › Installation

RDP-Tool is a **single self-contained script** - there is nothing to install, no modules, no MSI.

---

## ✅ Prerequisites

| Requirement | Notes |
|---|---|
| Windows 10 / 11 / Server 2016+ | The tool drives Windows-only APIs (registry, CIM/WMI, NetSecurity, WTS) |
| **PowerShell 7+** (`pwsh`) | Enforced via `#Requires -Version 7.0`. Install: `winget install Microsoft.PowerShell` |
| Administrator rights | Only for **changes** (`-EnableRDP`, `-SetPort`, `-AddUser`, ...). Read-only diagnostics work unelevated |
| Internet access | Only for `-CheckUpdate` / `-Update` / `-TestExternal` (or use an internal mirror via `-UpdateSource`) |

---

## 📥 Getting the Tool

### Option A - Git

```powershell
git clone https://github.com/paulmann/RDP-Diagnostic-Tool
cd RDP-Diagnostic-Tool
pwsh -NoProfile -File .\RDP-Tool.ps1 -Help
```

### Option B - Release download

Download `RDP-Tool.ps1` from the [latest release](https://github.com/paulmann/RDP-Diagnostic-Tool/releases/latest), then unblock it once:

```powershell
Unblock-File .\RDP-Tool.ps1
```

### Option C - One-liner (dot-source into a session)

```powershell
# From a trusted network location or after reviewing the file:
. .\RDP-Tool.ps1 -Help
```

### Execution policy

If your policy blocks scripts, invoking through `pwsh -File` (as shown above) is the
cleanest per-invocation bypass. Alternatives:

```powershell
Set-ExecutionPolicy -Scope Process Bypass          # current window only
# or sign the script and require signatures:
# Get-AuthenticodeSignature .\RDP-Tool.ps1
```

> [!TIP]
> For enterprise deployment, mirror `RDP-Tool.ps1` to an internal share and
> distribute via SCCM/Intune. Pin updates with `-UpdateSource <internal URL>`.

---

## 🔄 Updating

The tool updates itself from GitHub Releases (validated + backed up + atomic replace):

```powershell
.\RDP-Tool.ps1 -CheckUpdate      # 0 = up to date, 5 = update available, 6 = check failed
.\RDP-Tool.ps1 -Update           # interactive
.\RDP-Tool.ps1 -Update -Force    # unattended (backup: RDP-Tool.ps1.bak-<timestamp>)
```

Air-gapped / mirrored environments:

```powershell
.\RDP-Tool.ps1 -Update -UpdateSource https://intranet.corp/tools/RDP-Tool.ps1
.\RDP-Tool.ps1 -Update -UpdateSource contoso/RDP-Diagnostic-Tool   # fork slug
```

What `-Update` guarantees:

1. TLS-only download (GitHub API → release asset → tagged raw file → branch raw file)
2. Content validation: size floor, HTML-error-page detection, embedded version marker match, **full PowerShell syntax parse**
3. Timestamped backup next to the script (falls back to `%TEMP%` if the folder is write-protected)
4. Atomic replacement (temp file + move) - the old file is never left half-written

---

## 🗑️ Uninstalling

Delete `RDP-Tool.ps1` (and any `.bak-*` backups). The tool writes nothing to the
registry or disk except the reports/logs **you** request via `-ExportReport`,
`-ExportJson`, `-LogPath`.

---

Next: [[Usage]] for the CLI reference.
