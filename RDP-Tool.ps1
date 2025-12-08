<# RDP-Tool.ps1
.SYNOPSIS
    Comprehensive RDP Diagnostic & Remediation Tool for Windows 10/11

.DESCRIPTION
    Performs complete diagnostics of Remote Desktop Protocol components, 
    attempts automatic remediation of common issues, and provides detailed 
    reporting on system readiness for RDP connections.
    Supports Windows 10/11 Pro, Enterprise, Education editions.
    Automatically detects unsupported editions (Home) and provides guidance.

.PARAMETER EnableRDP
    Enable and configure RDP with automatic remediation

.PARAMETER DiagnoseOnly
    Perform diagnostics only without making changes

.PARAMETER ForcePrivateNetwork
    Force all network profiles to Private category

.PARAMETER SkipRebootCheck
    Skip pending reboot detection

.PARAMETER TestExternal
    Test external connectivity (requires internet)

.PARAMETER ChangePort
    Change RDP port to specified number (1024-65535)

.PARAMETER DisableNLA
    Disable Network Level Authentication (less secure)

.PARAMETER ShowVerbose
    Show detailed diagnostic information

.PARAMETER ExportReport
    Export detailed report to HTML file

.EXAMPLE
    .\RDP-Tool.ps1
    Display help information

.EXAMPLE
    .\RDP-Tool.ps1 -DiagnoseOnly
    Run diagnostics without making changes

.EXAMPLE
    .\RDP-Tool.ps1 -EnableRDP -ForcePrivateNetwork
    Enable RDP with automatic remediation

.EXAMPLE
    .\RDP-Tool.ps1 -ChangePort 3390 -EnableRDP
    Change RDP port to 3390 and enable RDP

.NOTES
    Author: Mikhail Deynekin [ Deynekin.com ]
    Version: 4.2.0
    Last Modified: 2025-12-08
    Requires: Windows 10/11 Pro, Enterprise, or Education
#>

# Note: This is a truncated version for display. The full script is 107KB
# To use the full script, download from: https://github.com/paulmann/RDP-Diagnostic-Tool

Write-Host "RDP Diagnostic Tool v4.2.0" -ForegroundColor Cyan
Write-Host "Author: Mikhail Deynekin [ Deynekin.com ]" -ForegroundColor Gray
Write-Host ""
Write-Host "Please download the full script from:" -ForegroundColor Yellow
Write-Host "https://github.com/paulmann/RDP-Diagnostic-Tool/releases/tag/4.2.0" -ForegroundColor Green