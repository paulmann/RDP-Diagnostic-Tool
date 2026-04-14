<#
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
.PARAMETER Verbose
    Show detailed diagnostic information
.PARAMETER ExportReport
    Export detailed report to HTML file
.EXAMPLE
    .\RDP-Diagnostic.ps1
    Display help information
.EXAMPLE
    .\RDP-Diagnostic.ps1 -DiagnoseOnly
    Run diagnostics without making changes
.EXAMPLE
    .\RDP-Diagnostic.ps1 -EnableRDP -ForcePrivateNetwork
    Enable RDP with automatic remediation
.EXAMPLE
    .\RDP-Diagnostic.ps1 -ChangePort 3390 -EnableRDP
    Change RDP port to 3390 and enable RDP
.NOTES
    Author: Mikhail Deynekin [ Deynekin.com ]
    Version: 4.2.0
    Last Modified: 2025-12-08
    Requires: Windows 10/11 Pro, Enterprise, or Education
#>

#region Parameters and Help
# ============================================================================
# Parameters and Help System
# ============================================================================
[CmdletBinding(DefaultParameterSetName = 'Diagnostic')]
param(
    [Parameter(ParameterSetName = 'Enable', Mandatory = $false)]
    [switch]$EnableRDP,
    
    [Parameter(ParameterSetName = 'Diagnostic', Mandatory = $false)]
    [switch]$DiagnoseOnly,
    
    [Parameter(ParameterSetName = 'Enable', Mandatory = $false)]
    [switch]$ForcePrivateNetwork,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipRebootCheck,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestExternal,
    
    [Parameter(ParameterSetName = 'ChangePort', Mandatory = $false)]
    [ValidateRange(1024, 65535)]
    [int]$ChangePort,
    
    [Parameter(ParameterSetName = 'Enable', Mandatory = $false)]
    [switch]$DisableNLA,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowVerbose,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportReport,
    
   [Parameter(Mandatory = $false)]
   [alias("?")]
   [switch]$Help
)

#Requires -Version 7.0
#Requires -PSEdition Core

# Show help if no parameters or help requested
if ($Help -or ($PSBoundParameters.Count -eq 0)) {
    @"

********************************************************************************
RDP DIAGNOSTIC & REMEDIATION TOOL v4.2.0
Comprehensive Remote Desktop diagnostics for Windows 10/11
********************************************************************************

USAGE:
  .\RDP-Diagnostic.ps1 [OPTIONS]

DESCRIPTION:
  This tool performs complete diagnostics of RDP components, attempts
  automatic remediation of common issues, and provides detailed
  reporting on system readiness for Remote Desktop connections.

REQUIREMENTS:
  - Windows 10/11 Pro, Enterprise, or Education edition
  - Administrative privileges
  - PowerShell 5.1 or higher

OPTIONS:
  -EnableRDP           Enable and configure RDP with auto-remediation
  -DiagnoseOnly        Perform diagnostics without making changes
  -ForcePrivateNetwork Force network profiles to Private category
  -SkipRebootCheck     Skip pending reboot detection
  -TestExternal        Test external connectivity (requires internet)
  -ChangePort <port>   Change RDP port (1024-65535)
  -DisableNLA          Disable Network Level Authentication
  -Verbose             Show detailed diagnostic information
  -ExportReport <path> Export HTML report to specified path
  -Help, -?, /?        Display this help message

EXAMPLES:
  .\RDP-Diagnostic.ps1 -DiagnoseOnly
  .\RDP-Diagnostic.ps1 -EnableRDP -ForcePrivateNetwork
  .\RDP-Diagnostic.ps1 -ChangePort 3390 -EnableRDP
  .\RDP-Diagnostic.ps1 -TestExternal -Verbose

SUPPORTED EDITIONS:
  - Windows 10/11 Professional
  - Windows 10/11 Enterprise
  - Windows 10/11 Education
  - Windows 10/11 Pro for Workstations
  - Windows Server 2016/2019/2022
  - Windows 10/11 Home (RDP Server NOT supported)

EXIT CODES:
  0 - All tests passed, system ready for RDP
  1 - Critical errors detected
  2 - Warnings detected, RDP may work with limitations
  3 - Unsupported Windows edition (Home)
  4 - Missing prerequisites
  99 - Script execution error

********************************************************************************
"@
    exit 0
}

# Set verbosity
if ($ShowVerbose) {
    $VerbosePreference = "Continue"
    $DebugPreference = "Continue"
}
#endregion

#region Initialization and Configuration
# ============================================================================
# Initialization and Configuration
# ============================================================================
$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"

# Global tracking variables
$global:DiagnosticResults = [System.Collections.ArrayList]@()
$global:RemediationAttempts = [System.Collections.ArrayList]@()
$global:TestResults = [System.Collections.ArrayList]@()
$global:CriticalErrors = 0
$global:Warnings = 0
$global:SystemInfo = @{}
$global:RDPPort = 3389  # Default port

# Override port if specified
if ($ChangePort) {
    $global:RDPPort = $ChangePort
    Write-Verbose "Using custom RDP port: $($global:RDPPort)"
}

# Color definitions
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"
$ColorVerbose = "Gray"
$ColorDebug = "DarkGray"
$ColorHeader = "Magenta"

# Timestamp for reports
$global:ScriptStartTime = Get-Date
$global:ReportID = [Guid]::NewGuid().ToString().Substring(0, 8).ToUpper()

# Function to add diagnostic results
function Add-DiagnosticResult {
    param(
        [string]$Component,
        [string]$Status,
        [string]$Details,
        [string]$Remedy,
        [string]$Category = "General",
        [bool]$IsCritical = $false,
        [int]$Severity = 1  # 1=Info, 2=Warning, 3=Error, 4=Critical
    )
    
    $result = [PSCustomObject]@{
        Component = $Component
        Status = $Status
        Details = $Details
        Remedy = $Remedy
        Category = $Category
        Severity = $Severity
        IsCritical = $IsCritical
        Timestamp = Get-Date -Format "HH:mm:ss.fff"
    }
    
    $null = $global:DiagnosticResults.Add($result)
    
    # Color based on severity
    $color = switch ($Severity) {
        1 { $ColorSuccess }
        2 { $ColorWarning }
        3 { $ColorError }
        4 { $ColorError }
        default { "White" }
    }
    
    $prefix = switch ($Severity) {
        1 { "[OK]" }
        2 { "[WARN]" }
        3 { "[ERROR]" }
        4 { "[CRITICAL]" }
        default { "[INFO]" }
    }
    
    Write-Host "$prefix $Component : $Status" -ForegroundColor $color
    if ($Details -and $Verbose) {
        Write-Host "        Details: $Details" -ForegroundColor $ColorVerbose
    }
    
    if ($IsCritical) {
        $global:CriticalErrors++
    } elseif ($Severity -ge 2) {
        $global:Warnings++
    }
}

# Function to record remediation attempts
function Add-RemediationAttempt {
    param(
        [string]$Action,
        [string]$Result,
        [string]$Notes,
        [bool]$Success = $false
    )
    
    $attempt = [PSCustomObject]@{
        Action = $Action
        Result = $Result
        Notes = $Notes
        Success = $Success
        Timestamp = Get-Date -Format "HH:mm:ss"
    }
    
    $null = $global:RemediationAttempts.Add($attempt)
    
    $color = if ($Success) { $ColorSuccess } else { $ColorError }
    Write-Verbose "[REMEDIATION] $Action - $Result ($(if($Success){'SUCCESS'}else{'FAILED'}))"
    if ($Notes) {
        Write-Debug "        Notes: $Notes"
    }
}

# Function to add test result
function Add-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message,
        [object]$Data = $null
    )
    
    $test = [PSCustomObject]@{
        TestName = $TestName
        Passed = $Passed
        Message = $Message
        Data = $Data
        Timestamp = Get-Date
    }
    
    $null = $global:TestResults.Add($test)
    
    $color = if ($Passed) { $ColorSuccess } else { $ColorError }
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    Write-Verbose "[TEST] $TestName : $status - $Message"
}

# Function to display section headers
function Write-SectionHeader {
    param(
        [string]$Title, 
        [string]$Subtitle = "",
        [string]$Emoji = "📊"
    )
    
    Write-Host "`n" + ("═" * 80) -ForegroundColor $ColorHeader
    Write-Host "$Emoji $Title" -ForegroundColor $ColorHeader
    if ($Subtitle) {                           
        Write-Host "  $Subtitle" -ForegroundColor $ColorVerbose
    }
    Write-Host ("═" * 80) -ForegroundColor $ColorHeader
}
#endregion

#region Prerequisite Checks
# ============================================================================
# Prerequisite Checks
# ============================================================================
function Test-Prerequisites {
    Write-SectionHeader -Title "PREREQUISITE CHECKS" -Emoji "🔍"
    
    # 1. Administrative privileges
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Add-DiagnosticResult -Component "Administrative Privileges" `
                -Status "REQUIRED" `
                -Details "Script must run as Administrator" `
                -Remedy "Run PowerShell as Administrator" `
                -Category "Prerequisites" `
                -Severity 4 `
                -IsCritical $true
            return $false
        }
        Add-DiagnosticResult -Component "Administrative Privileges" `
            -Status "OK" `
            -Details "Running with elevated permissions" `
            -Category "Prerequisites" `
            -Severity 1
    } catch {
        Add-DiagnosticResult -Component "Administrative Privileges" `
            -Status "CHECK FAILED" `
            -Details "Unable to verify permissions: $_" `
            -Remedy "Run PowerShell as Administrator" `
            -Category "Prerequisites" `
            -Severity 4 `
            -IsCritical $true
        return $false
    }
    
    # 2. PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Add-DiagnosticResult -Component "PowerShell Version" `
            -Status "OK" `
            -Details "Version $($psVersion.ToString())" `
            -Category "Prerequisites" `
            -Severity 1
    } else {
        Add-DiagnosticResult -Component "PowerShell Version" `
            -Status "UNSUPPORTED" `
            -Details "Version $($psVersion.ToString()) detected. PowerShell 5.1+ required." `
            -Remedy "Upgrade to Windows 10/11 or install PowerShell 7+" `
            -Category "Prerequisites" `
            -Severity 3
    }
    
    # 3. Windows version and edition
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $global:SystemInfo.OSCaption = $osInfo.Caption
        $global:SystemInfo.OSVersion = $osInfo.Version
        $global:SystemInfo.BuildNumber = $osInfo.BuildNumber
        $global:SystemInfo.OSArchitecture = $osInfo.OSArchitecture
        
        # Get edition from registry
        $editionReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
        $global:SystemInfo.EditionID = $editionReg.EditionID
        $global:SystemInfo.ProductName = $editionReg.ProductName
        $global:SystemInfo.InstallationType = $editionReg.InstallationType
        
        # Determine if RDP Server is supported
        $rdpSupported = $false
        $rdpSupportReason = ""
        
        # Check edition
        if ($global:SystemInfo.EditionID -match "Professional|Enterprise|Education|CoreN|CloudN") {
            $rdpSupported = $true
            $rdpSupportReason = "$($global:SystemInfo.EditionID) edition supports RDP Server"
        } elseif ($global:SystemInfo.EditionID -match "Home") {
            $rdpSupported = $false
            $rdpSupportReason = "Windows Home edition does not support RDP Server (incoming connections)"
        } elseif ($osInfo.Caption -match "Server") {
            $rdpSupported = $true
            $rdpSupportReason = "Windows Server edition detected"
        } else {
            # Check via product type (1=Workstation, 2=Domain Controller, 3=Server)
            $productType = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
            if ($productType -eq 1) {
                # Workstation - check if Pro/Enterprise via SKU
                $osSKU = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU
                $proSKUs = @(48, 49, 101, 103, 7, 8, 10, 11, 12, 14, 15, 16, 18, 19, 20, 21, 24, 26, 27, 28, 35, 37, 38, 39, 40, 42, 43, 44, 46, 50, 68, 71, 72, 74, 76, 79, 84, 87, 92, 95, 98, 100, 104, 123, 125, 175)
                if ($osSKU -in $proSKUs) {
                    $rdpSupported = $true
                    $rdpSupportReason = "Professional/Enterprise SKU detected"
                } else {
                    $rdpSupported = $false
                    $rdpSupportReason = "Workstation SKU does not support RDP Server"
                }
            } else {
                $rdpSupported = $true
                $rdpSupportReason = "Server/DC product type detected"
            }
        }
        
        $global:SystemInfo.RDPSupported = $rdpSupported
        $global:SystemInfo.RDPSupportReason = $rdpSupportReason
        
        Add-DiagnosticResult -Component "Operating System" `
            -Status "DETECTED" `
            -Details "$($global:SystemInfo.OSCaption) (Build: $($global:SystemInfo.BuildNumber), Edition: $($global:SystemInfo.EditionID))" `
            -Category "Prerequisites" `
            -Severity 1
        
        if (-not $rdpSupported) {
            Add-DiagnosticResult -Component "RDP Server Support" `
                -Status "NOT AVAILABLE" `
                -Details $rdpSupportReason `
                -Remedy "Upgrade to Windows Pro, Enterprise, or Education edition. Home edition can only make outgoing RDP connections." `
                -Category "Prerequisites" `
                -Severity 4 `
                -IsCritical $true
            return $false
        } else {
            Add-DiagnosticResult -Component "RDP Server Support" `
                -Status "SUPPORTED" `
                -Details $rdpSupportReason `
                -Category "Prerequisites" `
                -Severity 1
        }
        
    } catch {
        Add-DiagnosticResult -Component "Operating System Detection" `
            -Status "FAILED" `
            -Details "Unable to detect Windows version: $_" `
            -Remedy "Check system integrity and WMI service" `
            -Category "Prerequisites" `
            -Severity 3 `
            -IsCritical $true
        return $false
    }
    
    # 4. Pending reboot check
    if (-not $SkipRebootCheck) {
        $pendingReboot = $false
        $rebootReasons = @()
        
        # Common reboot pending indicators
        $indicators = @(
            @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"; Reason = "Component Based Servicing"},
            @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"; Reason = "Windows Update"},
            @{Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"; Reason = "Pending File Rename"},
            @{Path = "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts"; Reason = "Server Manager"},
            @{Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SetupExecute"; Reason = "Setup Execute"}
        )
        
        foreach ($indicator in $indicators) {
            if (Test-Path $indicator.Path) {
                $pendingReboot = $true
                $rebootReasons += $indicator.Reason
            }
        }
        
        # Check via DISM
        try {
            $dismInfo = DISM /Online /Get-Packages 2>&1 | Where-Object { $_ -match "Pending online image change" }
            if ($dismInfo) {
                $pendingReboot = $true
                $rebootReasons += "DISM Package Changes"
            }
        } catch { }
        
        if ($pendingReboot) {
            Add-DiagnosticResult -Component "System State" `
                -Status "REBOOT REQUIRED" `
                -Details "Pending reboot detected: $($rebootReasons -join ', ')" `
                -Remedy "Restart computer before configuring RDP" `
                -Category "Prerequisites" `
                -Severity 3
        } else {
            Add-DiagnosticResult -Component "System State" `
                -Status "OK" `
                -Details "No pending reboot detected" `
                -Category "Prerequisites" `
                -Severity 1
        }
    }
    
    # 5. Check for required Windows features
    try {
        $rdpFeature = Get-WindowsOptionalFeature -Online -FeatureName "RemoteDesktop-Server" -ErrorAction SilentlyContinue
        if ($rdpFeature -and $rdpFeature.State -eq "Enabled") {
            Add-DiagnosticResult -Component "RDP Windows Feature" `
                -Status "ENABLED" `
                -Details "Remote Desktop Services feature is installed" `
                -Category "Prerequisites" `
                -Severity 1
        } else {
            Add-DiagnosticResult -Component "RDP Windows Feature" `
                -Status "DISABLED/MISSING" `
                -Details "Remote Desktop Services feature may not be fully installed" `
                -Remedy "Enable via: Enable-WindowsOptionalFeature -Online -FeatureName RemoteDesktop-Server" `
                -Category "Prerequisites" `
                -Severity 2
        }
    } catch {
        Write-Debug "WindowsOptionalFeature check failed: $_"
    }
    
    return $true
}
#endregion

#region Windows Edition Detection
# ============================================================================
# Windows Edition Detection and RDP Support Analysis
# ============================================================================
function Get-WindowsEditionDetails {
    Write-SectionHeader -Title "WINDOWS EDITION ANALYSIS" -Emoji "🏷️"
    
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $global:SystemInfo.Manufacturer = $computerSystem.Manufacturer
        $global:SystemInfo.Model = $computerSystem.Model
        
        # Get detailed OS info
        $osDetails = Get-CimInstance -ClassName Win32_OperatingSystem
        $global:SystemInfo.InstallDate = $osDetails.InstallDate
        $global:SystemInfo.LastBootUpTime = $osDetails.LastBootUpTime
        $global:SystemInfo.SerialNumber = $osDetails.SerialNumber
        
        # Get product key info (partial)
        try {
            $digitalProductId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DigitalProductId -ErrorAction SilentlyContinue).DigitalProductId
            if ($digitalProductId) {
                $global:SystemInfo.ProductId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductId -ErrorAction SilentlyContinue).ProductId
            }
        } catch { }
        
        # Display edition information
        Write-Host "`n📋 System Information:" -ForegroundColor $ColorInfo
        Write-Host "  Operating System  : $($global:SystemInfo.OSCaption)" -ForegroundColor White
        Write-Host "  Edition           : $($global:SystemInfo.EditionID)" -ForegroundColor White
        Write-Host "  Build Number      : $($global:SystemInfo.BuildNumber)" -ForegroundColor White
        Write-Host "  Architecture      : $($global:SystemInfo.OSArchitecture)" -ForegroundColor White
        Write-Host "  Product Name      : $($global:SystemInfo.ProductName)" -ForegroundColor White
        Write-Host "  RDP Support       : $(if($global:SystemInfo.RDPSupported){'✅ SUPPORTED'}else{'❌ NOT SUPPORTED'})" -ForegroundColor $(if($global:SystemInfo.RDPSupported){$ColorSuccess}else{$ColorError})
        Write-Host "  Support Reason    : $($global:SystemInfo.RDPSupportReason)" -ForegroundColor $ColorVerbose
        
        if ($global:SystemInfo.Manufacturer) {
            Write-Host "  Manufacturer      : $($global:SystemInfo.Manufacturer)" -ForegroundColor White
        }
        if ($global:SystemInfo.Model) {
            Write-Host "  Model             : $($global:SystemInfo.Model)" -ForegroundColor White
        }
        
        # Check for known OEM limitations
        if ($global:SystemInfo.Manufacturer -match "Dell|HP|Lenovo|Acer|ASUS") {
            Write-Host "`n⚠️  OEM System Detected:" -ForegroundColor $ColorWarning
            Write-Host "  Some OEM systems may have custom RDP restrictions or firewall settings." -ForegroundColor $ColorVerbose
        }
        
        return $true
    } catch {
        Add-DiagnosticResult -Component "Edition Detection" `
            -Status "FAILED" `
            -Details "Unable to retrieve detailed edition information: $_" `
            -Category "SystemInfo" `
            -Severity 2
        return $false
    }
}
#endregion

#region RDP Capability Tests
# ============================================================================
# RDP Capability Tests
# ============================================================================
function Test-RDPCapability {
    Write-SectionHeader -Title "RDP CAPABILITY TESTS" -Emoji "🧪"
    
    # 1. Check if RDP registry structure exists
    $rdpRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    if (Test-Path $rdpRegPath) {
        Add-TestResult -TestName "RDP Registry Structure" -Passed $true -Message "RDP registry configuration exists"
    } else {
        Add-TestResult -TestName "RDP Registry Structure" -Passed $false -Message "RDP registry configuration missing"
        Add-DiagnosticResult -Component "RDP Registry" `
            -Status "MISSING" `
            -Details "Terminal Server registry path not found" `
            -Remedy "RDP feature may not be installed. Try: Enable-WindowsOptionalFeature -Online -FeatureName RemoteDesktop-Server" `
            -Category "Capability" `
            -Severity 3
    }
    
    # 2. Check required DLLs
    $requiredDlls = @(
        "C:\Windows\System32\termsrv.dll",
        "C:\Windows\System32\rdpudd.dll",
        "C:\Windows\System32\rdpcore.dll",
        "C:\Windows\System32\rdpbase.dll"
    )
    
    $missingDlls = @()
    foreach ($dll in $requiredDlls) {
        if (-not (Test-Path $dll)) {
            $missingDlls += (Split-Path $dll -Leaf)
        }
    }
    
    if ($missingDlls.Count -eq 0) {
        Add-TestResult -TestName "Required DLLs" -Passed $true -Message "All required RDP DLLs found"
    } else {
        Add-TestResult -TestName "Required DLLs" -Passed $false -Message "Missing DLLs: $($missingDlls -join ', ')"
        Add-DiagnosticResult -Component "RDP Components" `
            -Status "INCOMPLETE" `
            -Details "Missing critical DLLs: $($missingDlls -join ', ')" `
            -Remedy "Run System File Checker: sfc /scannow`nOr repair Windows installation" `
            -Category "Capability" `
            -Severity 3
    }
    
    # 3. Check driver status
    try {
        $rdpDrivers = Get-WmiObject Win32_SystemDriver | Where-Object { $_.Name -match "rdp" }
        $runningDrivers = $rdpDrivers | Where-Object { $_.State -eq "Running" }
        
        if ($rdpDrivers.Count -gt 0) {
            Add-TestResult -TestName "RDP Drivers" -Passed $true -Message "$($runningDrivers.Count)/$($rdpDrivers.Count) RDP drivers running"
            Write-Verbose "RDP Drivers found: $($rdpDrivers.Name -join ', ')"
        } else {
            Add-TestResult -TestName "RDP Drivers" -Passed $false -Message "No RDP drivers found"
        }
    } catch {
        Add-TestResult -TestName "RDP Drivers" -Passed $false -Message "Driver check failed: $_"
    }
    
    # 4. Check for virtualization (RDP on VMs may have different requirements)
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        if ($computerSystem.Model -match "Virtual|VMware|VirtualBox|KVM|QEMU|Hyper-V") {
            Add-TestResult -TestName "Virtualization Environment" -Passed $true -Message "Running in virtual machine"
            Write-Host "  ℹ️  Virtual Machine detected: $($computerSystem.Model)" -ForegroundColor $ColorInfo
            Write-Host "  Note: Some VM platforms require additional configuration for RDP." -ForegroundColor $ColorVerbose
        }
    } catch { }
    
    # 5. Check Windows Defender Application Guard (blocks RDP in some cases)
    try {
        $wdagStatus = Get-WindowsOptionalFeature -Online -FeatureName "Windows-Defender-ApplicationGuard" -ErrorAction SilentlyContinue
        if ($wdagStatus -and $wdagStatus.State -eq "Enabled") {
            Add-TestResult -TestName "Windows Defender Application Guard" -Passed $false -Message "WDAG is enabled and may interfere with RDP"
            Write-Host "  ⚠️  Windows Defender Application Guard is enabled" -ForegroundColor $ColorWarning
            Write-Host "  This feature can block RDP connections in some configurations." -ForegroundColor $ColorVerbose
        }
    } catch { }
}
#endregion

#region Enhanced Diagnostic Functions
# ============================================================================
# Enhanced Diagnostic Functions
# ============================================================================

function Test-EnhancedRegistrySettings {
    Write-SectionHeader -Title "ENHANCED REGISTRY ANALYSIS" -Emoji "🔧"
    
    $registryTests = @(
        # Core RDP settings
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
            Name = "fDenyTSConnections"
            ExpectedValue = 0
            Description = "RDP Connections Allowed"
            Category = "Core"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0 -Force"
        },
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
            Name = "fSingleSessionPerUser"
            ExpectedValue = 0
            Description = "Multiple Sessions Per User"
            Category = "Session"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fSingleSessionPerUser' -Value 0 -Force"
        },
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "PortNumber"
            ExpectedValue = $global:RDPPort
            Description = "RDP Port Number"
            Category = "Network"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'PortNumber' -Value $($global:RDPPort) -Force"
        },
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "UserAuthentication"
            ExpectedValue = $(if($DisableNLA){0}else{1})
            Description = "Network Level Authentication"
            Category = "Security"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication' -Value $(if($DisableNLA){0}else{1}) -Force"
        },
        
        # Performance settings
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "MaxConnectionTime"
            ExpectedValue = 0
            Description = "Max Connection Time (0=unlimited)"
            Category = "Performance"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MaxConnectionTime' -Value 0 -Force"
        },
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "MaxDisconnectionTime"
            ExpectedValue = 0
            Description = "Max Disconnection Time"
            Category = "Performance"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MaxDisconnectionTime' -Value 0 -Force"
        },
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "MaxIdleTime"
            ExpectedValue = 0
            Description = "Max Idle Time"
            Category = "Performance"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MaxIdleTime' -Value 0 -Force"
        },
        
        # Security settings
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "SecurityLayer"
            ExpectedValue = 2
            Description = "RDP Security Layer (2=Negotiate)"
            Category = "Security"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'SecurityLayer' -Value 2 -Force"
        },
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "MinEncryptionLevel"
            ExpectedValue = 3
            Description = "Minimum Encryption Level"
            Category = "Security"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MinEncryptionLevel' -Value 3 -Force"
        },
        
        # Audio/Video settings
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "fDisableAudioCapture"
            ExpectedValue = 1
            Description = "Disable Audio Capture"
            Category = "Multimedia"
            Remediation = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'fDisableAudioCapture' -Value 1 -Force"
        },
        @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
            Name = "fEnableVirtualizedGraphics"
            ExpectedValue = 1
            Description = "Virtualized Graphics"
            Category = "Graphics"
            Optional = $true  # Mark as optional since it might not exist on all systems
            Remediation = @"
# Create the value if it doesn't exist
if (-not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp')) {
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Force
}
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'fEnableVirtualizedGraphics' -Value 1 -PropertyType DWord -Force
"@
        }
    )
    
    foreach ($test in $registryTests) {
        try {
            $actualValue = Get-ItemProperty -Path $test.Path -Name $test.Name -ErrorAction Stop | 
                Select-Object -ExpandProperty $test.Name
            
            $status = if ($actualValue -eq $test.ExpectedValue) {
                "OK"
            } else {
                "MISCONFIGURED"
            }
            
            $severity = if ($status -eq "OK") { 1 } else { 
                if ($test.Category -eq "Core") { 3 } else { 2 } 
            }
            
            $details = "Current: $actualValue (Expected: $($test.ExpectedValue))"
            
            Add-DiagnosticResult -Component $test.Description `
                -Status $status `
                -Details $details `
                -Category $test.Category `
                -Severity $severity `
                -Remedy $test.Remediation
            
            # Auto-remediate if in remediation mode
            if ($EnableRDP -and $status -eq "MISCONFIGURED") {
                try {
                    Invoke-Expression $test.Remediation
                    Add-RemediationAttempt -Action "Corrected registry: $($test.Description)" `
                        -Result "SUCCESS" `
                        -Notes "Changed from $actualValue to $($test.ExpectedValue)" `
                        -Success $true
                } catch {
                    Add-RemediationAttempt -Action "Corrected registry: $($test.Description)" `
                        -Result "FAILED" `
                        -Notes "Error: $_" `
                        -Success $false
                }
            }
        } catch [System.Management.Automation.ItemNotFoundException] {
            if ($test.Optional) {
                Add-DiagnosticResult -Component $test.Description `
                    -Status "NOT CONFIGURED" `
                    -Details "Registry value does not exist (optional setting)" `
                    -Category $test.Category `
                    -Severity 1 `  # Lower severity for optional settings
                    -Remedy $test.Remediation
            } else {
                Add-DiagnosticResult -Component $test.Description `
                    -Status "NOT FOUND" `
                    -Details "Registry value or path does not exist" `
                    -Category $test.Category `
                    -Severity 2 `
                    -Remedy $test.Remediation
            }
        } catch {
            Add-DiagnosticResult -Component $test.Description `
                -Status "ERROR" `
                -Details "Unable to read registry: $_" `
                -Category $test.Category `
                -Severity 2 `
                -Remedy $test.Remediation
        }
    }
}

function Test-EnhancedServiceConfiguration {
    Write-SectionHeader -Title "ENHANCED SERVICE ANALYSIS" -Emoji "⚙️"
    
    $requiredServices = @(
        @{
            Name = "TermService"
            DisplayName = "Remote Desktop Services"
            RequiredStartup = "Automatic"
            Description = "Core RDP Service"
            Category = "Core"
            Dependencies = @("RPCSS", "TermDD")
            Critical = $true
        },
        @{
            Name = "SessionEnv"
            DisplayName = "Remote Desktop Configuration"
            RequiredStartup = "Manual"
            Description = "RDP Session Management"
            Category = "Management"
            Dependencies = @("RPCSS", "TermService")
            Critical = $false
        },
        @{
            Name = "UmRdpService"
            DisplayName = "Remote Desktop Services UserMode Port Redirector"
            RequiredStartup = "Manual"
            Description = "USB Redirection Service"
            Category = "Peripheral"
            Dependencies = @("TermService")
            Critical = $false
        },
        @{
            Name = "RdpVideoMiniport"
            DisplayName = "Remote Desktop Video Miniport Driver"
            RequiredStartup = "Manual"
            Description = "Video Driver Service"
            Category = "Graphics"
            Dependencies = @()
            Critical = $false
        },
        @{
            Name = "AudioEndpointBuilder"
            DisplayName = "Windows Audio Endpoint Builder"
            RequiredStartup = "Auto"
            Description = "Audio Support"
            Category = "Multimedia"
            Dependencies = @()
            Critical = $false
        },
        @{
            Name = "Audiosrv"
            DisplayName = "Windows Audio"
            RequiredStartup = "Auto"
            Description = "Windows Audio Service"
            Category = "Multimedia"
            Dependencies = @("AudioEndpointBuilder")
            Critical = $false
        }
    )
    
    foreach ($service in $requiredServices) {
        try {
            # Attempt to get service information
            $svc = Get-Service -Name $service.Name -ErrorAction Stop
            $svcCim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction SilentlyContinue
            
            if (-not $svcCim) {
                # Fallback to WMI if CIM fails
                $svcCim = Get-WmiObject -Class Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction SilentlyContinue
            }
            
            $startupType = if ($svcCim) { $svcCim.StartMode } else { "Unknown" }
            $state = $svc.Status
            
            # Check dependencies
            $missingDeps = @()
            $depDetails = @()
            foreach ($dep in $service.Dependencies) {
                try {
                    $depService = Get-Service -Name $dep -ErrorAction Stop
                    if ($depService.Status -ne "Running") {
                        $missingDeps += $dep
                        $depDetails += "$dep (State: $($depService.Status))"
                    } else {
                        $depDetails += "$dep (Running)"
                    }
                } catch {
                    $missingDeps += $dep
                    $depDetails += "$dep (Not Found)"
                }
            }
            
            $statusDetails = @(
                "State: $state",
                "Startup: $startupType (Required: $($service.RequiredStartup))"
            )
            
            if ($service.Dependencies.Count -gt 0) {
                $statusDetails += "Dependencies: $($depDetails -join ', ')"
            }
            
            # Determine service status
            if ($state -eq "Running" -and ($startupType -eq $service.RequiredStartup -or $startupType -eq "Auto" -and $service.RequiredStartup -eq "Automatic")) {
                $status = "OPERATIONAL"
                $severity = 1
            } elseif ($state -eq "Stopped" -and $startupType -eq "Disabled") {
                $status = "DISABLED"
                $severity = if ($service.Critical) { 3 } else { 2 }
            } elseif ($missingDeps.Count -gt 0) {
                $status = "DEPENDENCY ISSUES"
                $severity = if ($service.Critical) { 3 } else { 2 }
            } else {
                $status = "NEEDS ATTENTION"
                $severity = if ($service.Critical) { 2 } else { 1 }
            }
            
            $remedy = @"
# Set startup type
Set-Service -Name '$($service.Name)' -StartupType $($service.RequiredStartup) -ErrorAction SilentlyContinue

# Start service if needed
if ((Get-Service -Name '$($service.Name)').Status -ne 'Running') {
    Start-Service -Name '$($service.Name)' -ErrorAction SilentlyContinue
}
"@
            
            Add-DiagnosticResult -Component $service.Description `
                -Status $status `
                -Details ($statusDetails -join "; ") `
                -Category $service.Category `
                -Severity $severity `
                -Remedy $remedy
            
            # Auto-remediate if needed and enabled
            if ($EnableRDP -and $status -ne "OPERATIONAL") {
                try {
                    # Set startup type if different
                    if ($startupType -ne $service.RequiredStartup -and $startupType -ne "Unknown") {
                        Set-Service -Name $service.Name -StartupType $service.RequiredStartup -ErrorAction Stop
                        Add-RemediationAttempt -Action "Set startup type for $($service.DisplayName)" `
                            -Result "SUCCESS" `
                            -Notes "Changed from $startupType to $($service.RequiredStartup)" `
                            -Success $true
                    }
                    
                    # Start service if stopped but not disabled
                    if ($state -ne "Running" -and $startupType -ne "Disabled" -and $startupType -ne "Unknown") {
                        Start-Service -Name $service.Name -ErrorAction Stop
                        Add-RemediationAttempt -Action "Start service $($service.DisplayName)" `
                            -Result "SUCCESS" `
                            -Notes "Service started successfully" `
                            -Success $true
                    }
                    
                    # Handle dependencies
                    foreach ($dep in $missingDeps) {
                        try {
                            $depService = Get-Service -Name $dep -ErrorAction SilentlyContinue
                            if ($depService) {
                                if ($depService.StartType -eq "Disabled") {
                                    Set-Service -Name $dep -StartupType "Manual" -ErrorAction SilentlyContinue
                                }
                                Start-Service -Name $dep -ErrorAction SilentlyContinue
                                Add-RemediationAttempt -Action "Start dependency $dep for $($service.DisplayName)" `
                                    -Result "SUCCESS" `
                                    -Notes "Dependency service started" `
                                    -Success $true
                            }
                        } catch {
                            Add-RemediationAttempt -Action "Start dependency $dep for $($service.DisplayName)" `
                                -Result "FAILED" `
                                -Notes "Error: $_" `
                                -Success $false
                        }
                    }
                } catch {
                    Add-RemediationAttempt -Action "Configure service $($service.DisplayName)" `
                        -Result "FAILED" `
                        -Notes "Error: $_" `
                        -Success $false
                }
            }
            
        } catch {
            # Check if service doesn't exist
            if ($_.Exception.Message -match "Cannot find any service" -or 
                $_.Exception.Message -match "was not found" -or
                $_.Exception.Message -match "does not exist") {
                
                $severity = if ($service.Critical) { 3 } else { 2 }
                $remedy = "Install required Windows features: `n"
                $remedy += if ($service.Name -eq "TermService") {
                    "Enable-WindowsOptionalFeature -Online -FeatureName RemoteDesktop-Server -All"
                } else {
                    "The service '$($service.Name)' may need to be installed via Windows Features or reinstallation of RDP components"
                }
                
                Add-DiagnosticResult -Component $service.Description `
                    -Status "NOT INSTALLED" `
                    -Details "Service '$($service.DisplayName)' is not installed on this system" `
                    -Category $service.Category `
                    -Severity $severity `
                    -Remedy $remedy
                
                # Attempt to install if in remediation mode and it's the core RDP service
                if ($EnableRDP -and $service.Name -eq "TermService") {
                    try {
                        Write-Host "  Installing RDP Windows feature..." -ForegroundColor $ColorInfo
                        Enable-WindowsOptionalFeature -Online -FeatureName "RemoteDesktop-Server" -All -NoRestart -ErrorAction Stop
                        Add-RemediationAttempt -Action "Install RDP Windows feature" `
                            -Result "SUCCESS" `
                            -Notes "RemoteDesktop-Server feature installed" `
                            -Success $true
                    } catch {
                        Add-RemediationAttempt -Action "Install RDP Windows feature" `
                            -Result "FAILED" `
                            -Notes "Error: $_" `
                            -Success $false
                    }
                }
                
            } else {
                # Other errors
                Add-DiagnosticResult -Component $service.Description `
                    -Status "ERROR" `
                    -Details "Unable to query service: $($_.Exception.Message)" `
                    -Category $service.Category `
                    -Severity 2 `
                    -Remedy "Check Service Control Manager access and permissions"
            }
        }
    }
    
    # Additional check: Verify service relationships
    Write-Host "`n🔗 Service Relationships:" -ForegroundColor $ColorInfo
    
    # Check if TermService is properly configured
    $termService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
    if ($termService) {
        if ($termService.Status -ne "Running") {
            Write-Host "  ⚠️  TermService is not running. Attempting to start..." -ForegroundColor $ColorWarning
            if ($EnableRDP) {
                try {
                    Start-Service -Name "TermService" -ErrorAction Stop
                    Write-Host "  ✅ TermService started successfully" -ForegroundColor $ColorSuccess
                } catch {
                    Write-Host "  ❌ Failed to start TermService: $_" -ForegroundColor $ColorError
                }
            }
        }
        
        # Check dependent services
        $dependentServices = Get-Service -DependentServices | Where-Object { $_.RequiredServices.Name -contains "TermService" }
        if ($dependentServices) {
            Write-Host "  Services dependent on TermService:" -ForegroundColor White
            foreach ($depSvc in $dependentServices) {
                Write-Host "    • $($depSvc.DisplayName): $($depSvc.Status)" -ForegroundColor $ColorVerbose
            }
        }
    }
    
    # Final service status summary
    $runningServices = 0
    $stoppedServices = 0
    $missingServices = 0
    
    foreach ($service in $requiredServices) {
        $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -eq "Running") {
                $runningServices++
            } else {
                $stoppedServices++
            }
        } else {
            $missingServices++
        }
    }
    
    Write-Host "`n📊 Service Status Summary:" -ForegroundColor $ColorInfo
    Write-Host "  Running: $runningServices" -ForegroundColor $(if($runningServices -ge 3){$ColorSuccess}else{$ColorWarning})
    Write-Host "  Stopped: $stoppedServices" -ForegroundColor $(if($stoppedServices -eq 0){$ColorSuccess}else{$ColorWarning})
    Write-Host "  Missing: $missingServices" -ForegroundColor $(if($missingServices -eq 0){$ColorSuccess}else{$ColorError})
    
    if ($runningServices -eq $requiredServices.Count) {
        Write-Host "  ✅ All RDP services are operational" -ForegroundColor $ColorSuccess
    } elseif ($missingServices -gt 0) {
        Write-Host "  ⚠️  Some RDP services are missing" -ForegroundColor $ColorWarning
    } elseif ($stoppedServices -gt 0) {
        Write-Host "  ⚠️  Some RDP services are not running" -ForegroundColor $ColorWarning
    }
}

function Test-EnhancedFirewallConfiguration {
    Write-SectionHeader -Title "ENHANCED FIREWALL ANALYSIS" -Emoji "🔥"
    
    # Check firewall service
    $firewallService = Get-Service -Name "MpsSvc" -ErrorAction SilentlyContinue
    if ($firewallService -and $firewallService.Status -eq "Running") {
        Add-DiagnosticResult -Component "Windows Defender Firewall Service" `
            -Status "RUNNING" `
            -Details "Firewall service is active" `
            -Category "Firewall" `
            -Severity 1
    } else {
        Add-DiagnosticResult -Component "Windows Defender Firewall Service" `
            -Status "STOPPED/DISABLED" `
            -Details "Firewall service may be disabled" `
            -Category "Firewall" `
            -Severity 2
    }
    
    # Check all firewall profiles
    $profiles = @("Domain", "Private", "Public")
    foreach ($profile in $profiles) {
        $fwProfile = Get-NetFirewallProfile -Name $profile -ErrorAction SilentlyContinue
        if ($fwProfile) {
            $status = if ($fwProfile.Enabled) { "ENABLED" } else { "DISABLED" }
            $severity = if ($fwProfile.Enabled) { 1 } else { 2 }
            
            Add-DiagnosticResult -Component "Firewall Profile: $profile" `
                -Status $status `
                -Details "DefaultInboundAction: $($fwProfile.DefaultInboundAction), DefaultOutboundAction: $($fwProfile.DefaultOutboundAction)" `
                -Category "Firewall" `
                -Severity $severity
        }
    }
    
    # Analyze RDP-specific firewall rules
    $rdpRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.DisplayName -match "Remote Desktop" -or 
            $_.DisplayGroup -match "Remote Desktop" -or
            ($_.LocalPort -contains $global:RDPPort -or $_.LocalPort -contains "3389")
        }
    
    if ($rdpRules) {
        $enabledRules = $rdpRules | Where-Object { $_.Enabled -eq $true }
        $disabledRules = $rdpRules | Where-Object { $_.Enabled -eq $false }
        
        Add-DiagnosticResult -Component "RDP Firewall Rules" `
            -Status "FOUND" `
            -Details "Total: $($rdpRules.Count), Enabled: $($enabledRules.Count), Disabled: $($disabledRules.Count)" `
            -Category "Firewall" `
            -Severity 1
        
        # Show rule details in verbose mode
        if ($Verbose) {
            Write-Verbose "`nDetailed RDP Firewall Rules:"
            foreach ($rule in $enabledRules | Select-Object -First 5) {
                Write-Verbose "  ✓ $($rule.DisplayName) - $($rule.Direction) - $($rule.Action)"
            }
            if ($disabledRules.Count -gt 0) {
                Write-Verbose "`nDisabled RDP Firewall Rules:"
                foreach ($rule in $disabledRules | Select-Object -First 3) {
                    Write-Verbose "  ✗ $($rule.DisplayName) - $($rule.Direction) - $($rule.Action)"
                }
            }
        }
        
        # Enable disabled rules if in remediation mode
        if ($EnableRDP -and $disabledRules.Count -gt 0) {
            foreach ($rule in $disabledRules) {
                try {
                    Enable-NetFirewallRule -Name $rule.Name -ErrorAction Stop
                    Add-RemediationAttempt -Action "Enable firewall rule: $($rule.DisplayName)" `
                        -Result "SUCCESS" `
                        -Notes "Rule enabled" `
                        -Success $true
                } catch {
                    Add-RemediationAttempt -Action "Enable firewall rule: $($rule.DisplayName)" `
                        -Result "FAILED" `
                        -Notes "Error: $_" `
                        -Success $false
                }
            }
        }
    } else {
        Add-DiagnosticResult -Component "RDP Firewall Rules" `
            -Status "NOT FOUND" `
            -Details "No specific RDP firewall rules detected" `
            -Category "Firewall" `
            -Severity 2
        
        # Create rules if in remediation mode
        if ($EnableRDP) {
            try {
                # Create inbound TCP rule
                New-NetFirewallRule -DisplayName "RDP-TCP-In-Custom" `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort $global:RDPPort `
                    -Action Allow `
                    -Profile Any `
                    -Enabled True `
                    -ErrorAction Stop
                
                # Create inbound UDP rule (for improved performance)
                New-NetFirewallRule -DisplayName "RDP-UDP-In-Custom" `
                    -Direction Inbound `
                    -Protocol UDP `
                    -LocalPort $global:RDPPort `
                    -Action Allow `
                    -Profile Any `
                    -Enabled True `
                    -ErrorAction Stop
                
                Add-RemediationAttempt -Action "Create custom RDP firewall rules" `
                    -Result "SUCCESS" `
                    -Notes "Created TCP and UDP rules for port $($global:RDPPort)" `
                    -Success $true
            } catch {
                Add-RemediationAttempt -Action "Create custom RDP firewall rules" `
                    -Result "FAILED" `
                    -Notes "Error: $_" `
                    -Success $false
            }
        }
    }
    
    # Check for conflicting/blocking rules
    $blockingRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.Action -eq "Block" -and 
            $_.Direction -eq "Inbound" -and
            ($_.LocalPort -contains $global:RDPPort -or $_.LocalPort -contains "3389")
        }
    
    if ($blockingRules.Count -gt 0) {
        Add-DiagnosticResult -Component "Conflicting Firewall Rules" `
            -Status "BLOCKING RULES FOUND" `
            -Details "$($blockingRules.Count) rule(s) blocking port $($global:RDPPort)" `
            -Category "Firewall" `
            -Severity 3
        
        if ($EnableRDP) {
            foreach ($rule in $blockingRules) {
                try {
                    Remove-NetFirewallRule -Name $rule.Name -Confirm:$false -ErrorAction Stop
                    Add-RemediationAttempt -Action "Remove blocking firewall rule: $($rule.DisplayName)" `
                        -Result "SUCCESS" `
                        -Notes "Blocking rule removed" `
                        -Success $true
                } catch {
                    try {
                        Disable-NetFirewallRule -Name $rule.Name -ErrorAction Stop
                        Add-RemediationAttempt -Action "Disable blocking firewall rule: $($rule.DisplayName)" `
                            -Result "SUCCESS" `
                            -Notes "Blocking rule disabled" `
                            -Success $true
                    } catch {
                        Add-RemediationAttempt -Action "Handle blocking firewall rule: $($rule.DisplayName)" `
                            -Result "FAILED" `
                            -Notes "Could not remove or disable" `
                            -Success $false
                    }
                }
            }
        }
    }
}

function Test-EnhancedNetworkConfiguration {
    Write-SectionHeader -Title "ENHANCED NETWORK ANALYSIS" -Emoji "🌐"
    
    # Get network adapters
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    
    if ($adapters.Count -eq 0) {
        Add-DiagnosticResult -Component "Network Adapters" `
            -Status "NO ACTIVE ADAPTERS" `
            -Details "No active physical network adapters found" `
            -Category "Network" `
            -Severity 3
        return
    }
    
    Write-Host "`nActive Network Adapters:" -ForegroundColor $ColorInfo
    foreach ($adapter in $adapters) {
        Write-Host "  $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor White
        Write-Host "    Status: $($adapter.Status), Speed: $($adapter.LinkSpeed)" -ForegroundColor $ColorVerbose
        
        # Get IP configuration
        $ipConfig = Get-NetIPConfiguration -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
        if ($ipConfig) {
            foreach ($address in $ipConfig.IPv4Address) {
                Write-Host "    IPv4: $($address.IPAddress)/$($address.PrefixLength)" -ForegroundColor $ColorVerbose
            }
        }
    }
    
    # Check network profiles
    $connections = Get-NetConnectionProfile
    
    if ($connections.Count -eq 0) {
        Add-DiagnosticResult -Component "Network Connections" `
            -Status "NO PROFILES" `
            -Details "No network connection profiles found" `
            -Category "Network" `
            -Severity 2
        return
    }
    
    foreach ($conn in $connections) {
        $status = if ($conn.NetworkCategory -eq "Private") {
            "OK"
        } elseif ($conn.NetworkCategory -eq "Public") {
            "PUBLIC"
        } else {
            "DOMAIN"
        }
        
        $severity = if ($conn.NetworkCategory -eq "Private") { 1 } else { 2 }
        
        Add-DiagnosticResult -Component "Network Profile ($($conn.InterfaceAlias))" `
            -Status $status `
            -Details "Category: $($conn.NetworkCategory), Name: $($conn.Name)" `
            -Category "Network" `
            -Severity $severity
        
        # Auto-remediate if forced
        if (($ForcePrivateNetwork -or $EnableRDP) -and $conn.NetworkCategory -ne "Private") {
            try {
                Set-NetConnectionProfile -InterfaceAlias $conn.InterfaceAlias -NetworkCategory Private -ErrorAction Stop
                Add-RemediationAttempt -Action "Set network profile to Private" `
                    -Result "SUCCESS" `
                    -Notes "Interface: $($conn.InterfaceAlias)" `
                    -Success $true
            } catch {
                Add-RemediationAttempt -Action "Set network profile to Private" `
                    -Result "FAILED" `
                    -Notes "Interface: $($conn.InterfaceAlias), Error: $_" `
                    -Success $false
            }
        }
    }
    
    # Check Network Discovery
    $discoveryRules = Get-NetFirewallRule -DisplayGroup "Network Discovery*" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Enabled -eq $true }
    
    if ($discoveryRules.Count -gt 0) {
        Add-DiagnosticResult -Component "Network Discovery" `
            -Status "ENABLED" `
            -Details "$($discoveryRules.Count) rules enabled" `
            -Category "Network" `
            -Severity 1
    } else {
        Add-DiagnosticResult -Component "Network Discovery" `
            -Status "DISABLED" `
            -Details "Network discovery may be disabled" `
            -Category "Network" `
            -Severity 2
    }
    
    # Check for network isolation features
    try {
        $networkIsolation = Get-NetIsolationRule -ErrorAction SilentlyContinue
        if ($networkIsolation) {
            Add-DiagnosticResult -Component "Network Isolation Rules" `
                -Status "CONFIGURED" `
                -Details "$($networkIsolation.Count) isolation rule(s) configured" `
                -Category "Network" `
                -Severity 2
        }
    } catch { }
}

function Test-EnhancedPortAndConnectivity {
    Write-SectionHeader -Title "ENHANCED PORT & CONNECTIVITY ANALYSIS" -Emoji "🔌"
    
    # 1. Check if port is listening locally
    $listening = $null
    try {
        $listening = Get-NetTCPConnection -LocalPort $global:RDPPort -ErrorAction SilentlyContinue | 
            Where-Object { $_.State -eq "Listen" }
        
        if ($listening) {
            $processId = $listening[0].OwningProcess
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            
            Add-DiagnosticResult -Component "Port $($global:RDPPort) Listening" `
                -Status "ACTIVE" `
                -Details "Process: $(if($process){$process.ProcessName}else{'Unknown'}) (PID: $processId)" `
                -Category "Connectivity" `
                -Severity 1
            
            Add-TestResult -TestName "Port Listening Test" -Passed $true -Message "Port $($global:RDPPort) is listening"
        } else {
            Add-DiagnosticResult -Component "Port $($global:RDPPort) Listening" `
                -Status "NOT LISTENING" `
                -Details "No process listening on port $($global:RDPPort)" `
                -Category "Connectivity" `
                -Severity 3
            
            Add-TestResult -TestName "Port Listening Test" -Passed $false -Message "Port $($global:RDPPort) is not listening"
        }
    } catch {
        Add-DiagnosticResult -Component "Port Listening Check" `
            -Status "ERROR" `
            -Details "Failed to check port status: $_" `
            -Category "Connectivity" `
            -Severity 2
    }
    
    # 2. Test local connection
    Write-Host "`nTesting local connectivity..." -ForegroundColor $ColorInfo
    try {
        $testResult = Test-NetConnection -ComputerName "localhost" -Port $global:RDPPort -WarningAction SilentlyContinue -ErrorAction Stop
        
        if ($testResult.TcpTestSucceeded) {
            Add-DiagnosticResult -Component "Local RDP Connectivity" `
                -Status "SUCCESS" `
                -Details "Successfully connected to localhost:$($global:RDPPort)" `
                -Category "Connectivity" `
                -Severity 1
            
            Add-TestResult -TestName "Local Connectivity Test" -Passed $true -Message "Connected to localhost:$($global:RDPPort)"
        } else {
            Add-DiagnosticResult -Component "Local RDP Connectivity" `
                -Status "FAILED" `
                -Details "Cannot connect to RDP locally on port $($global:RDPPort)" `
                -Category "Connectivity" `
                -Severity 3
            
            Add-TestResult -TestName "Local Connectivity Test" -Passed $false -Message "Failed to connect to localhost:$($global:RDPPort)"
        }
    } catch {
        Add-DiagnosticResult -Component "Local RDP Connectivity" `
            -Status "TEST ERROR" `
            -Details "Connection test failed: $_" `
            -Category "Connectivity" `
            -Severity 2
    }
    
    # 3. Test network loopback - ВАЖНОЕ ИСПРАВЛЕНИЕ: используем правильный синтаксис с ${} для разделения переменных
    try {
        $localIP = Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp | 
            Select-Object -First 1 -ExpandProperty IPAddress
        
        if ($localIP) {
            Write-Host "Testing network loopback ($localIP)..." -ForegroundColor $ColorInfo
            $loopbackTest = Test-NetConnection -ComputerName $localIP -Port $global:RDPPort -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            
            if ($loopbackTest.TcpTestSucceeded) {
                Add-DiagnosticResult -Component "Network Loopback Test" `
                    -Status "SUCCESS" `
                    -Details ("Connected to ${localIP}:$($global:RDPPort)") `
                    -Category "Connectivity" `
                    -Severity 1
            } else {
                Add-DiagnosticResult -Component "Network Loopback Test" `
                    -Status "FAILED" `
                    -Details ("Cannot connect to ${localIP}:$($global:RDPPort)") `
                    -Category "Connectivity" `
                    -Severity 2
            }
        }
    } catch { }
    
    # 4. Check for port conflicts
    Write-Host "`nChecking for port conflicts..." -ForegroundColor $ColorInfo
    $conflictingProcesses = @()
    try {
        $tcpConnections = Get-NetTCPConnection -LocalPort $global:RDPPort -ErrorAction SilentlyContinue
        foreach ($conn in $tcpConnections) {
            if ($conn.State -ne "Listen") {
                try {
                    $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                    if ($process) {
                        $conflictingProcesses += "$($process.ProcessName) (PID: $($conn.OwningProcess), State: $($conn.State))"
                    } else {
                        $conflictingProcesses += "Unknown Process (PID: $($conn.OwningProcess), State: $($conn.State))"
                    }
                } catch {
                    $conflictingProcesses += "PID: $($conn.OwningProcess), State: $($conn.State)"
                }
            }
        }
    } catch { }
    
    if ($conflictingProcesses.Count -gt 0) {
        Add-DiagnosticResult -Component "Port Conflict Detection" `
            -Status "CONFLICTS FOUND" `
            -Details "Port $($global:RDPPort) in use by: $($conflictingProcesses -join '; ')" `
            -Category "Connectivity" `
            -Severity 3
        
        if ($EnableRDP) {
            Write-Host "  ⚠️  Port conflicts detected. Consider changing RDP port with -ChangePort parameter." -ForegroundColor $ColorWarning
        }
    }
    
    # 5. Test external connectivity if requested
    if ($TestExternal) {
        Write-SectionHeader -Title "EXTERNAL CONNECTIVITY TESTS" -Emoji "🌍"
        
        try {
            # Test internet connectivity
            $internetTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            
if ($internetTest.TcpTestSucceeded) {
    Add-DiagnosticResult -Component "Internet Connectivity" `
        -Status "AVAILABLE" `
        -Details "Internet connection is working" `
        -Category "External" `
        -Severity 1
    
    # Test common RDP-related domains
    $testDomains = @("microsoft.com", "windowsupdate.com", "live.com")
    foreach ($domain in $testDomains) {
        try {
            $dnsTest = Resolve-DnsName -Name $domain -ErrorAction SilentlyContinue
            if ($dnsTest) {
                Write-Host "  ✓ DNS resolution for ${domain}: SUCCESS" -ForegroundColor $ColorSuccess
            }
        } catch {
            Write-Host "  ✗ DNS resolution for ${domain}: FAILED" -ForegroundColor $ColorWarning
        }
    }
} else {
                Add-DiagnosticResult -Component "Internet Connectivity" `
                    -Status "UNAVAILABLE" `
                    -Details "No internet connection detected" `
                    -Category "External" `
                    -Severity 2
            }
        } catch {
            Add-DiagnosticResult -Component "External Connectivity Tests" `
                -Status "ERROR" `
                -Details "External tests failed: $_" `
                -Category "External" `
                -Severity 2
        }
    }
}

function Test-EnhancedSecurityAndPolicies {
    Write-SectionHeader -Title "SECURITY & POLICY ANALYSIS" -Emoji "🔒"
    
    # 1. Check Group Policy settings
    Write-Host "`nChecking Group Policy settings..." -ForegroundColor $ColorInfo
    
    $gpoPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
    )
    
    $gpoFound = $false
    foreach ($path in $gpoPaths) {
        if (Test-Path $path) {
            $gpoFound = $true
            $policyCount = (Get-ChildItem -Path $path -ErrorAction SilentlyContinue).Count
            
            Add-DiagnosticResult -Component "Group Policy Configuration" `
                -Status "CONFIGURED" `
                -Details "Path: $path, Policies: $policyCount" `
                -Category "Security" `
                -Severity 2
            
            if ($Verbose -and $policyCount -gt 0) {
                Write-Verbose "  Policies in ${path}:"
                try {
                    $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
                    $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | 
                        ForEach-Object {
                            Write-Verbose "    $($_.Name) = $($_.Value)"
                        }
                } catch { }
            }
        }
    }
    
    if (-not $gpoFound) {
        Add-DiagnosticResult -Component "Group Policy Configuration" `
            -Status "NOT CONFIGURED" `
            -Details "No specific RDP GPO settings detected" `
            -Category "Security" `
            -Severity 1
    }
    
    # 2. Check UAC (User Account Control) settings
    try {
        $uacEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
        if ($uacEnabled -eq 1) {
            Add-DiagnosticResult -Component "User Account Control (UAC)" `
                -Status "ENABLED" `
                -Details "UAC is active (recommended for security)" `
                -Category "Security" `
                -Severity 1
        } else {
            Add-DiagnosticResult -Component "User Account Control (UAC)" `
                -Status "DISABLED" `
                -Details "UAC is disabled (security risk)" `
                -Category "Security" `
                -Severity 2
        }
    } catch { }
    
    # 3. Check Windows Defender status
    try {
        $defenderService = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
        if ($defenderService -and $defenderService.Status -eq "Running") {
            Add-DiagnosticResult -Component "Windows Defender" `
                -Status "ACTIVE" `
                -Details "Real-time protection is enabled" `
                -Category "Security" `
                -Severity 1
        }
    } catch { }
    
    # 4. Check Credential Guard
    try {
        $credGuard = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
        if ($credGuard -and $credGuard.VirtualizationBasedSecurityStatus -eq 1) {
            Add-DiagnosticResult -Component "Credential Guard" `
                -Status "ENABLED" `
                -Details "Virtualization-based security is active" `
                -Category "Security" `
                -Severity 2
        }
    } catch { }
    
    # 5. Check for security event logging
    try {
        $auditPolicy = auditpol /get /category:* 2>&1 | Select-String "Logon/Logoff"
        if ($auditPolicy) {
            Add-DiagnosticResult -Component "Security Auditing" `
                -Status "CONFIGURED" `
                -Details "Logon auditing is enabled" `
                -Category "Security" `
                -Severity 1
        }
    } catch { }
}

function Test-EnhancedUserPermissions {
    Write-SectionHeader -Title "USER PERMISSIONS ANALYSIS" -Emoji "👥"
    
    # Current user info
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $global:SystemInfo.CurrentUser = $currentUser.Name
    $global:SystemInfo.UserSID = $currentUser.User.Value
    
    Write-Host "Current User: $($currentUser.Name)" -ForegroundColor White
    Write-Host "User SID: $($currentUser.User.Value)" -ForegroundColor $ColorVerbose
    
    # 1. Check Remote Desktop Users group
    try {
        $rdUsersGroup = [ADSI]"WinNT://$env:COMPUTERNAME/Remote Desktop Users"
        $members = @()
        
        $rdUsersGroup.psbase.Invoke("Members") | ForEach-Object {
            $member = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
            $members += $member
        }
        
        $global:SystemInfo.RemoteDesktopUsers = $members
        
        if ($members.Count -gt 0) {
            Add-DiagnosticResult -Component "Remote Desktop Users Group" `
                -Status "CONFIGURED" `
                -Details "$($members.Count) user(s) in group: $($members -join ', ')" `
                -Category "Permissions" `
                -Severity 1
        } else {
            Add-DiagnosticResult -Component "Remote Desktop Users Group" `
                -Status "EMPTY" `
                -Details "No users in Remote Desktop Users group" `
                -Category "Permissions" `
                -Severity 2
        }
    } catch {
        Add-DiagnosticResult -Component "Remote Desktop Users Group" `
            -Status "ERROR" `
            -Details "Cannot query group membership: $_" `
            -Category "Permissions" `
            -Severity 2
    }
    
    # 2. Check if current user has RDP rights
    $isInGroup = $false
    try {
        $groupMembers = Get-LocalGroupMember -Group "Remote Desktop Users" -ErrorAction Stop
        $isInGroup = ($groupMembers | Where-Object { $_.Name -eq $currentUser.Name }).Count -gt 0
        
        if ($isInGroup) {
            Add-DiagnosticResult -Component "Current User RDP Rights" `
                -Status "GRANTED" `
                -Details "User has RDP permission" `
                -Category "Permissions" `
                -Severity 1
        } else {
            Add-DiagnosticResult -Component "Current User RDP Rights" `
                -Status "NOT GRANTED" `
                -Details "User is not in Remote Desktop Users group" `
                -Remedy "Add user to group: Add-LocalGroupMember -Group 'Remote Desktop Users' -Member '$($currentUser.Name)'" `
                -Category "Permissions" `
                -Severity 2
            
            # Auto-add if in remediation mode
            if ($EnableRDP) {
                try {
                    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $currentUser.Name -ErrorAction Stop
                    Add-RemediationAttempt -Action "Add current user to Remote Desktop Users group" `
                        -Result "SUCCESS" `
                        -Notes "User $($currentUser.Name) added to group" `
                        -Success $true
                } catch {
                    Add-RemediationAttempt -Action "Add current user to Remote Desktop Users group" `
                        -Result "FAILED" `
                        -Notes "Error: $_" `
                        -Success $false
                }
            }
        }
    } catch {
        Add-DiagnosticResult -Component "Current User RDP Rights" `
            -Status "UNKNOWN" `
            -Details "Cannot verify permissions: $_" `
            -Category "Permissions" `
            -Severity 2
    }
    
    # 3. Check for other relevant groups
    $relevantGroups = @("Administrators", "Remote Management Users", "Power Users")
    foreach ($group in $relevantGroups) {
        try {
            $groupMembers = Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue
            if ($groupMembers) {
                $isMember = ($groupMembers | Where-Object { $_.Name -eq $currentUser.Name }).Count -gt 0
                if ($isMember) {
                    Write-Verbose "User is member of $group group"
                }
            }
        } catch { }
    }
    
    # 4. Check User Account Control token
    try {
        $token = [System.Security.Principal.WindowsIdentity]::GetCurrent().Token
        $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        
        if ($principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Verbose "User has administrative token"
        }
    } catch { }
}

function Test-EnhancedPerformanceAndFeatures {
    Write-SectionHeader -Title "PERFORMANCE & FEATURE ANALYSIS" -Emoji "🚀"
    
    # 1. Check system resources
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $totalMemory = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeMemory = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        
        Add-DiagnosticResult -Component "System Memory" `
            -Status "ANALYZED" `
            -Details "Total: ${totalMemory}GB, Free: ${freeMemory}GB" `
            -Category "Performance" `
            -Severity 1
    } catch { }
    
    # 2. Check CPU information
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        $cpuCores = $cpu.NumberOfCores
        $cpuThreads = $cpu.NumberOfLogicalProcessors
        
        Add-DiagnosticResult -Component "CPU Configuration" `
            -Status "ANALYZED" `
            -Details "Cores: $cpuCores, Threads: $cpuThreads, Name: $($cpu.Name)" `
            -Category "Performance" `
            -Severity 1
    } catch { }
    
    # 3. Check graphics capabilities (important for RDP)
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController
        $gpuCount = $gpus.Count
        
        if ($gpuCount -gt 0) {
            $primaryGPU = $gpus[0]
            Add-DiagnosticResult -Component "Graphics Adapter" `
                -Status "DETECTED" `
                -Details "$($primaryGPU.Name) ($([math]::Round($primaryGPU.AdapterRAM / 1MB))MB)" `
                -Category "Performance" `
                -Severity 1
            
            if ($Verbose -and $gpuCount -gt 1) {
                Write-Verbose "Additional GPUs detected:"
                for ($i = 1; $i -lt $gpuCount; $i++) {
                    Write-Verbose "  - $($gpus[$i].Name)"
                }
            }
        } else {
            Add-DiagnosticResult -Component "Graphics Adapter" `
                -Status "NOT DETECTED" `
                -Details "No dedicated GPU found" `
                -Category "Performance" `
                -Severity 2
        }
    } catch { }
    
    # 4. Check disk performance
    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
        if ($disk) {
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
            
            Add-DiagnosticResult -Component "Disk Space (C:)" `
                -Status "ANALYZED" `
                -Details "Free: ${freeSpaceGB}GB / Total: ${totalSpaceGB}GB" `
                -Category "Performance" `
                -Severity 1
        }
    } catch { }
    
    # 5. Check Windows Experience Index (if available)
    try {
        $perfCounter = Get-CimInstance -ClassName Win32_WinSAT -ErrorAction SilentlyContinue
        if ($perfCounter) {
            Add-DiagnosticResult -Component "Windows Experience Index" `
                -Status "AVAILABLE" `
                -Details "Score: $($perfCounter.WinSPRLevel)" `
                -Category "Performance" `
                -Severity 1
        }
    } catch { }
}
#endregion

#region Event Log Analysis
# ============================================================================
# Event Log Analysis
# ============================================================================
function Get-EventLogAnalysis {
    Write-SectionHeader -Title "EVENT LOG ANALYSIS" -Emoji "📋"
    
    Write-Host "`nChecking RDP-related event logs..." -ForegroundColor $ColorInfo
    
    $logSources = @(
        @{Log = "System"; Source = "TermService"; Description = "RDP Service Events"},
        @{Log = "Security"; Source = "Microsoft-Windows-Security-Auditing"; Description = "Logon/Logoff Events"},
        @{Log = "Application"; Source = "Microsoft-Windows-TerminalServices*"; Description = "Terminal Services Application Events"},
        @{Log = "Microsoft-Windows-TerminalServices*"; Source = "*"; Description = "Terminal Services Operational"}
    )
    
    $eventSummary = @()
    
    foreach ($logSource in $logSources) {
        try {
            $events = Get-WinEvent -LogName $logSource.Log -ErrorAction SilentlyContinue | 
                Where-Object { $_.ProviderName -like $logSource.Source } |
                Select-Object -First 5
            
            if ($events) {
                $eventCount = $events.Count
                $latestTime = $events[0].TimeCreated
                
                Write-Host "  ✓ $($logSource.Description): $eventCount recent events" -ForegroundColor $ColorSuccess
                if ($Verbose) {
                    foreach ($event in $events | Select-Object -First 3) {
                        Write-Verbose "    [$($event.TimeCreated)] $($event.LevelDisplayName): $($event.Message.Substring(0, [math]::Min(100, $event.Message.Length)))..."
                    }
                }
                
                $eventSummary += [PSCustomObject]@{
                    Source = $logSource.Description
                    Count = $eventCount
                    Latest = $latestTime
                }
            }
        } catch {
            # Log not available
        }
    }
    
    # Check for specific error events
    try {
        $rdpErrors = Get-WinEvent -LogName "System" -FilterXPath "*[System[Provider[@Name='TermService'] and (Level=2 or Level=3)]]" -ErrorAction SilentlyContinue |
            Select-Object -First 3
        
        if ($rdpErrors) {
            Add-DiagnosticResult -Component "RDP Error Events" `
                -Status "FOUND" `
                -Details "$($rdpErrors.Count) recent error/warning events" `
                -Category "EventLogs" `
                -Severity 2
            
            if ($Verbose) {
                Write-Verbose "Recent RDP Errors:"
                foreach ($error in $rdpErrors) {
                    Write-Verbose "  [$($error.TimeCreated)] ID $($error.Id): $($error.Message.Substring(0, [math]::Min(80, $error.Message.Length)))..."
                }
            }
        }
    } catch { }
    
    # Check failed login attempts
    try {
        $failedLogins = Get-WinEvent -LogName "Security" -FilterXPath "*[System[EventID=4625]]" -MaxEvents 5 -ErrorAction SilentlyContinue
        
        if ($failedLogins) {
            Add-DiagnosticResult -Component "Failed Login Attempts" `
                -Status "DETECTED" `
                -Details "$($failedLogins.Count) recent failed login attempts" `
                -Category "EventLogs" `
                -Severity 2
        }
    } catch { }
    
    return $eventSummary
}
#endregion

#region Advanced Diagnostics
# ============================================================================
# Advanced Diagnostics
# ============================================================================
function Test-AdvancedRDPSettings {
    Write-SectionHeader -Title "ADVANCED RDP SETTINGS" -Emoji "⚡"
    
    # 1. Check RDP Client settings
    try {
        $clientSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Terminal Server Client" -ErrorAction SilentlyContinue
        if ($clientSettings) {
            Write-Host "RDP Client settings found in user registry" -ForegroundColor $ColorInfo
        }
    } catch { }
    
    # 2. Check for RDP session settings
    $sessionSettings = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
    )
    
    foreach ($path in $sessionSettings) {
        if (Test-Path $path) {
            try {
                $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                Write-Verbose "Found $($keys.Count) settings in $path"
            } catch { }
        }
    }
    
    # 3. Check for RDP over UDP settings (for better performance)
    try {
        $udpEnabled = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-UDP" -ErrorAction SilentlyContinue
        if ($udpEnabled) {
            Add-DiagnosticResult -Component "RDP over UDP" `
                -Status "ENABLED" `
                -Details "UDP transport available for improved performance" `
                -Category "Advanced" `
                -Severity 1
        }
    } catch { }
    
    # 4. Check for RemoteFX settings (older but still relevant)
    try {
        $remotefx = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fEnableRemoteFX" -ErrorAction SilentlyContinue
        if ($remotefx -and $remotefx.fEnableRemoteFX -eq 1) {
            Add-DiagnosticResult -Component "RemoteFX" `
                -Status "ENABLED" `
                -Details "RemoteFX graphics acceleration is enabled" `
                -Category "Advanced" `
                -Severity 1
        }
    } catch { }
    
    # 5. Check for PowerShell Remoting compatibility
    try {
        $psRemoting = Get-PSSessionConfiguration -Name Microsoft.PowerShell -ErrorAction SilentlyContinue
        if ($psRemoting) {
            Add-DiagnosticResult -Component "PowerShell Remoting" `
                -Status "ENABLED" `
                -Details "PowerShell Remoting is configured (complementary to RDP)" `
                -Category "Advanced" `
                -Severity 1
        }
    } catch { }
}
#endregion

#region Reporting and Export
# ============================================================================
# Reporting and Export Functions
# ============================================================================
function Export-DiagnosticReport {
    param(
        [string]$FilePath
    )
    
    if (-not $FilePath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $FilePath = "RDP-Diagnostic-Report-$timestamp.html"
    }
    
    Write-SectionHeader -Title "EXPORTING DIAGNOSTIC REPORT" -Emoji "📄"
    
    try {
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>RDP Diagnostic Report - $env:COMPUTERNAME</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { background: #e8f4f8; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
        .section { margin-bottom: 25px; }
        .section-title { background: #4a5568; color: white; padding: 10px 15px; border-radius: 5px; margin-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #2d3748; color: white; padding: 10px; text-align: left; }
        td { padding: 8px 10px; border-bottom: 1px solid #e2e8f0; }
        .status-ok { background-color: #c6f6d5; color: #22543d; }
        .status-warning { background-color: #feebc8; color: #744210; }
        .status-error { background-color: #fed7d7; color: #742a2a; }
        .status-critical { background-color: #fed7d7; color: #742a2a; font-weight: bold; }
        .badge { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 12px; margin-right: 5px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e2e8f0; color: #718096; font-size: 12px; }
        .progress-bar { height: 20px; background: #e2e8f0; border-radius: 10px; overflow: hidden; margin: 10px 0; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #48bb78, #38a169); }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ RDP Diagnostic Report</h1>
            <p>Computer: $env:COMPUTERNAME | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            <p>Report ID: $global:ReportID | Script Version: 4.2.0</p>
        </div>
"@

        # System Information
        $html += @"
        <div class="section">
            <div class="section-title">System Information</div>
            <table>
                <tr><th>Property</th><th>Value</th></tr>
                <tr><td>Operating System</td><td>$($global:SystemInfo.OSCaption)</td></tr>
                <tr><td>Edition</td><td>$($global:SystemInfo.EditionID)</td></tr>
                <tr><td>Build Number</td><td>$($global:SystemInfo.BuildNumber)</td></tr>
                <tr><td>Architecture</td><td>$($global:SystemInfo.OSArchitecture)</td></tr>
                <tr><td>RDP Support</td><td><span class="badge $(if($global:SystemInfo.RDPSupported){'status-ok'}else{'status-error'} )">$(if($global:SystemInfo.RDPSupported){'SUPPORTED'}else{'NOT SUPPORTED'})</span> $($global:SystemInfo.RDPSupportReason)</td></tr>
            </table>
        </div>
"@

        # Summary Statistics
        $totalTests = $global:DiagnosticResults.Count
        $passedTests = $global:DiagnosticResults | Where-Object { $_.Severity -eq 1 } | Measure-Object | Select-Object -ExpandProperty Count
        $warningTests = $global:DiagnosticResults | Where-Object { $_.Severity -eq 2 } | Measure-Object | Select-Object -ExpandProperty Count
        $errorTests = $global:DiagnosticResults | Where-Object { $_.Severity -eq 3 } | Measure-Object | Select-Object -ExpandProperty Count
        $criticalTests = $global:DiagnosticResults | Where-Object { $_.IsCritical } | Measure-Object | Select-Object -ExpandProperty Count
        
        $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
        
        $html += @"
        <div class="summary">
            <h3>📊 Diagnostic Summary</h3>
            <p>Total Tests: $totalTests | Passed: $passedTests | Warnings: $warningTests | Errors: $errorTests | Critical: $criticalTests</p>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${successRate}%"></div>
            </div>
            <p>Success Rate: ${successRate}%</p>
            <p>Script Execution Time: $((Get-Date) - $global:ScriptStartTime)</p>
        </div>
"@

        # Detailed Results by Category
        $categories = $global:DiagnosticResults | Group-Object Category | Sort-Object Name
        
        foreach ($category in $categories) {
            $html += @"
            <div class="section">
                <div class="section-title">$($category.Name.ToUpper()) ($($category.Count) tests)</div>
                <table>
                    <tr>
                        <th>Component</th>
                        <th>Status</th>
                        <th>Details</th>
                        <th>Timestamp</th>
                    </tr>
"@
            
            foreach ($result in $category.Group | Sort-Object Severity -Descending) {
                $statusClass = switch ($result.Severity) {
                    1 { "status-ok" }
                    2 { "status-warning" }
                    3 { "status-error" }
                    4 { "status-critical" }
                    default { "" }
                }
                
                $html += @"
                    <tr>
                        <td>$($result.Component)</td>
                        <td><span class="badge $statusClass">$($result.Status)</span></td>
                        <td>$([System.Net.WebUtility]::HtmlEncode($result.Details))</td>
                        <td>$($result.Timestamp)</td>
                    </tr>
"@
            }
            
            $html += "</table></div>"
        }
        
        # Remediation Attempts
        if ($global:RemediationAttempts.Count -gt 0) {
            $html += @"
            <div class="section">
                <div class="section-title">Remediation Attempts ($($global:RemediationAttempts.Count))</div>
                <table>
                    <tr>
                        <th>Action</th>
                        <th>Result</th>
                        <th>Notes</th>
                        <th>Time</th>
                    </tr>
"@
            
            foreach ($attempt in $global:RemediationAttempts) {
                $resultClass = if ($attempt.Success) { "status-ok" } else { "status-error" }
                $html += @"
                    <tr>
                        <td>$([System.Net.WebUtility]::HtmlEncode($attempt.Action))</td>
                        <td><span class="badge $resultClass">$($attempt.Result)</span></td>
                        <td>$([System.Net.WebUtility]::HtmlEncode($attempt.Notes))</td>
                        <td>$($attempt.Timestamp)</td>
                    </tr>
"@
            }
            
            $html += "</table></div>"
        }
        
        # Recommendations
        $html += @"
        <div class="section">
            <div class="section-title">Recommendations</div>
"@
        
        if ($criticalTests -gt 0) {
            $html += "<p style='color: #c53030;'><strong>❌ CRITICAL ISSUES DETECTED:</strong> RDP will not work until these are resolved.</p>"
            $html += "<ul>"
            $global:DiagnosticResults | Where-Object { $_.IsCritical } | ForEach-Object {
                $html += "<li><strong>$($_.Component):</strong> $([System.Net.WebUtility]::HtmlEncode($_.Details))</li>"
            }
            $html += "</ul>"
        }
        
        if ($errorTests -gt 0) {
            $html += "<p style='color: #c05621;'><strong>⚠️ ERRORS DETECTED:</strong> RDP may not work correctly.</p>"
        }
        
        if ($warningTests -gt 0) {
            $html += "<p style='color: #d69e2e;'><strong>⚠️ WARNINGS:</strong> Consider addressing for optimal performance.</p>"
        }
        
        if ($criticalTests -eq 0 -and $errorTests -eq 0) {
            $html += "<p style='color: #38a169;'><strong>✅ SYSTEM READY FOR RDP:</strong> All critical tests passed.</p>"
        }
        
        $html += "</div>"
        
        # Footer
        $html += @"
        <div class="footer">
            <p>Report generated by RDP Diagnostic Tool v4.2.0</p>
            <p>Note: This report contains diagnostic information only. Always verify configurations in production environments.</p>
            <p>Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Duration: $((Get-Date) - $global:ScriptStartTime)</p>
        </div>
    </div>
</body>
</html>
"@
        
        $html | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Host "✅ Report exported to: $FilePath" -ForegroundColor $ColorSuccess
        
        # Try to open the report
        if (Test-Path $FilePath) {
            try {
                Start-Process $FilePath
            } catch { }
        }
        
    } catch {
        Write-Host "❌ Failed to export report: $_" -ForegroundColor $ColorError
    }
}

function Show-ComprehensiveSummary {
    Write-SectionHeader -Title "COMPREHENSIVE SUMMARY REPORT" -Emoji "📈"
    
    # Calculate statistics
    $totalDiagnostics = $global:DiagnosticResults.Count
    $passedDiagnostics = $global:DiagnosticResults | Where-Object { $_.Severity -eq 1 } | Measure-Object | Select-Object -ExpandProperty Count
    $warningDiagnostics = $global:DiagnosticResults | Where-Object { $_.Severity -eq 2 } | Measure-Object | Select-Object -ExpandProperty Count
    $errorDiagnostics = $global:DiagnosticResults | Where-Object { $_.Severity -eq 3 } | Measure-Object | Select-Object -ExpandProperty Count
    $criticalDiagnostics = $global:DiagnosticResults | Where-Object { $_.IsCritical } | Measure-Object | Select-Object -ExpandProperty Count
    
    $totalTests = $global:TestResults.Count
    $passedTests = $global:TestResults | Where-Object { $_.Passed -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
    $failedTests = $totalTests - $passedTests
    
    $remediationAttempts = $global:RemediationAttempts.Count
    $successfulRemediations = $global:RemediationAttempts | Where-Object { $_.Success -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
    
    # Display summary
    Write-Host "`n📊 EXECUTIVE SUMMARY" -ForegroundColor $ColorHeader
    Write-Host ("─" * 60) -ForegroundColor $ColorHeader
    
    Write-Host "System Information:" -ForegroundColor $ColorInfo
    Write-Host "  OS: $($global:SystemInfo.OSCaption)" -ForegroundColor White
    Write-Host "  Edition: $($global:SystemInfo.EditionID)" -ForegroundColor White
    Write-Host "  RDP Support: $(if($global:SystemInfo.RDPSupported){'✅ SUPPORTED'}else{'❌ NOT SUPPORTED'})" -ForegroundColor $(if($global:SystemInfo.RDPSupported){$ColorSuccess}else{$ColorError})
    
    Write-Host "`nDiagnostic Results:" -ForegroundColor $ColorInfo
    Write-Host "  Total Diagnostics: $totalDiagnostics" -ForegroundColor White
    Write-Host "  Passed: $passedDiagnostics" -ForegroundColor $ColorSuccess
    Write-Host "  Warnings: $warningDiagnostics" -ForegroundColor $ColorWarning
    Write-Host "  Errors: $errorDiagnostics" -ForegroundColor $ColorError
    Write-Host "  Critical: $criticalDiagnostics" -ForegroundColor $(if($criticalDiagnostics -gt 0){$ColorError}else{"White"})
    
    Write-Host "`nTest Results:" -ForegroundColor $ColorInfo
    Write-Host "  Total Tests: $totalTests" -ForegroundColor White
    Write-Host "  Passed: $passedTests" -ForegroundColor $ColorSuccess
    Write-Host "  Failed: $failedTests" -ForegroundColor $(if($failedTests -gt 0){$ColorError}else{"White"})
    
    if ($remediationAttempts -gt 0) {
        Write-Host "`nRemediation Results:" -ForegroundColor $ColorInfo
        Write-Host "  Attempts: $remediationAttempts" -ForegroundColor White
        Write-Host "  Successful: $successfulRemediations" -ForegroundColor $ColorSuccess
        Write-Host "  Failed: $($remediationAttempts - $successfulRemediations)" -ForegroundColor $(if(($remediationAttempts - $successfulRemediations) -gt 0){$ColorError}else{"White"})
    }
    
    Write-Host "`n⏱️  Performance Metrics:" -ForegroundColor $ColorInfo
    $duration = (Get-Date) - $global:ScriptStartTime
    Write-Host "  Script Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host "  Diagnostics per Second: $([math]::Round($totalDiagnostics / $duration.TotalSeconds, 2))" -ForegroundColor White
    
    # Show system status
    Write-Host "`n🏷️  SYSTEM STATUS:" -ForegroundColor $ColorInfo
    
    if ($criticalDiagnostics -gt 0) {
        Write-Host "  ❌ CRITICAL - RDP NOT FUNCTIONAL" -ForegroundColor $ColorError
        Write-Host "    Critical issues must be resolved before RDP will work." -ForegroundColor $ColorError
    } elseif ($errorDiagnostics -gt 0) {
        Write-Host "  ⚠️  DEGRADED - RDP MAY NOT WORK" -ForegroundColor $ColorWarning
        Write-Host "    Errors detected. RDP functionality may be limited." -ForegroundColor $ColorWarning
    } elseif ($warningDiagnostics -gt 0) {
        Write-Host "  ⚠️  FUNCTIONAL WITH WARNINGS" -ForegroundColor $ColorWarning
        Write-Host "    RDP should work, but warnings should be reviewed." -ForegroundColor $ColorWarning
    } else {
        Write-Host "  ✅ OPTIMAL - RDP FULLY FUNCTIONAL" -ForegroundColor $ColorSuccess
        Write-Host "    All diagnostics passed. RDP should work correctly." -ForegroundColor $ColorSuccess
    }
    
    # Top issues
    $topIssues = $global:DiagnosticResults | 
        Where-Object { $_.Severity -ge 2 } | 
        Sort-Object Severity -Descending | 
        Select-Object -First 5
    
    if ($topIssues) {
        Write-Host "`n🔍 TOP ISSUES TO ADDRESS:" -ForegroundColor $ColorInfo
        foreach ($issue in $topIssues) {
            $color = switch ($issue.Severity) {
                4 { $ColorError }
                3 { $ColorError }
                2 { $ColorWarning }
                default { "White" }
            }
            Write-Host "  • $($issue.Component): $($issue.Status)" -ForegroundColor $color
            if ($issue.Details) {
                Write-Host "    Details: $($issue.Details)" -ForegroundColor $ColorVerbose
            }
        }
    }
    
    # Connection information
    Write-Host "`n🔗 RDP CONNECTION INFORMATION:" -ForegroundColor $ColorInfo
    Write-Host "  Computer Name: $env:COMPUTERNAME" -ForegroundColor White
    
    try {
        $ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | 
            Where-Object { $_.PrefixOrigin -ne "WellKnown" } | 
            Select-Object -ExpandProperty IPAddress
        
        if ($ipAddresses) {
            Write-Host "  IP Addresses:" -ForegroundColor White
            foreach ($ip in $ipAddresses) {
                Write-Host "    • $ip" -ForegroundColor $ColorVerbose
            }
        }
    } catch { }
    
    Write-Host "  RDP Port: $($global:RDPPort)" -ForegroundColor White
    Write-Host "  Authentication: $(if($DisableNLA){'Password only (NLA disabled)'}else{'Network Level Authentication (recommended)'})" -ForegroundColor White
    
    # Final recommendations
    Write-Host "`n💡 RECOMMENDATIONS:" -ForegroundColor $ColorInfo
    
    if ($criticalDiagnostics -gt 0) {
        Write-Host "  1. Resolve critical issues first" -ForegroundColor $ColorError
        Write-Host "  2. Re-run diagnostics after fixes" -ForegroundColor White
    } elseif ($errorDiagnostics -gt 0) {
        Write-Host "  1. Address error conditions" -ForegroundColor $ColorWarning
        Write-Host "  2. Consider running with -EnableRDP for auto-remediation" -ForegroundColor White
    } elseif ($warningDiagnostics -gt 0) {
        Write-Host "  1. Review warnings for potential improvements" -ForegroundColor $ColorWarning
        Write-Host "  2. Run with -Verbose for more details" -ForegroundColor White
    } else {
        Write-Host "  1. System is ready for RDP connections" -ForegroundColor $ColorSuccess
        Write-Host "  2. Test connection from another computer" -ForegroundColor White
    }
    
    Write-Host "  3. Consider security best practices (strong passwords, firewall)" -ForegroundColor White
    Write-Host "  4. Regular monitoring via Event Viewer" -ForegroundColor White
    
    # Export report if requested
    if ($ExportReport) {
        Export-DiagnosticReport -FilePath $ExportReport
    }
    
    # Return appropriate exit code
    if ($criticalDiagnostics -gt 0) {
        return 1
    } elseif ($errorDiagnostics -gt 0) {
        return 2
    } elseif ($global:SystemInfo.RDPSupported -eq $false) {
        return 3
    } else {
        return 0
    }
}
#endregion

#region Main Execution
# ============================================================================
# Main Execution
# ============================================================================
function Main {
    try {
        # Display startup banner
        Write-SectionHeader -Title "RDP DIAGNOSTIC TOOL v4.2.0" -Subtitle "Comprehensive Remote Desktop Analysis for Windows 10/11" -Emoji "🚀"
        
        Write-Host "Mode: $(if($EnableRDP){'Diagnostic + Remediation'}elseif($DiagnoseOnly){'Diagnostic Only'}else{'Interactive'})" -ForegroundColor $ColorInfo
        Write-Host "Target Port: $($global:RDPPort)" -ForegroundColor $ColorInfo
        if ($DisableNLA) {
            Write-Host "Security: NLA Disabled (less secure)" -ForegroundColor $ColorWarning
        }
        
        # Check prerequisites
        if (-not (Test-Prerequisites)) {
            Write-Host "`n❌ Prerequisite checks failed. Exiting." -ForegroundColor $ColorError
            return 3
        }
        
        # Check if RDP is supported
        if (-not $global:SystemInfo.RDPSupported) {
            Write-SectionHeader -Title "RDP SERVER NOT SUPPORTED" -Emoji "❌"
            
            Write-Host "`nYour Windows edition ($($global:SystemInfo.EditionID)) does not support RDP Server." -ForegroundColor $ColorError
            Write-Host "`nWHAT THIS MEANS:" -ForegroundColor $ColorInfo
            Write-Host "• You CANNOT accept incoming RDP connections on this computer" -ForegroundColor White
            Write-Host "• You CAN still USE RDP Client to connect TO other computers" -ForegroundColor White
            Write-Host "• RDP Server is a feature limited to Pro, Enterprise, and Education editions" -ForegroundColor White
            
            Write-Host "`nRECOMMENDED ACTIONS:" -ForegroundColor $ColorInfo
            Write-Host "1. Upgrade to Windows 10/11 Pro ($99-199 via Microsoft Store)" -ForegroundColor White
            Write-Host "2. Use alternative remote access solutions:" -ForegroundColor White
            Write-Host "   • TeamViewer, AnyDesk, Chrome Remote Desktop (free for personal use)" -ForegroundColor $ColorVerbose
            Write-Host "   • Windows Quick Assist (built into Windows 10/11)" -ForegroundColor $ColorVerbose
            Write-Host "   • Parsec (good for gaming/media)" -ForegroundColor $ColorVerbose
            
            Write-Host "`nUPGRADE OPTIONS:" -ForegroundColor $ColorInfo
            Write-Host "• Microsoft Store: Search for 'Windows 10 Pro Upgrade' or 'Windows 11 Pro'" -ForegroundColor White
            Write-Host "• Retail: Purchase Pro license from authorized retailer" -ForegroundColor White
            Write-Host "• Volume Licensing: For businesses with multiple computers" -ForegroundColor White
            
            Write-Host "`nNote: Windows Home edition intentionally lacks RDP Server for security reasons." -ForegroundColor $ColorWarning
            return 3
        }
        
        # Run diagnostic modules
        Get-WindowsEditionDetails
        Test-RDPCapability
        Test-EnhancedRegistrySettings
        Test-EnhancedServiceConfiguration
        Test-EnhancedFirewallConfiguration
        Test-EnhancedNetworkConfiguration
        Test-EnhancedPortAndConnectivity
        Test-EnhancedSecurityAndPolicies
        Test-EnhancedUserPermissions
        Test-EnhancedPerformanceAndFeatures
        
        # Advanced diagnostics
        Get-EventLogAnalysis
        Test-AdvancedRDPSettings
        
        # Show comprehensive summary and get exit code
        $exitCode = Show-ComprehensiveSummary
        
        # Final message
        Write-Host "`n" + ("═" * 80) -ForegroundColor $ColorHeader
        Write-Host "✅ DIAGNOSTICS COMPLETE" -ForegroundColor $ColorSuccess
        
        if ($EnableRDP -and $exitCode -eq 0) {
            Write-Host "RDP has been configured and should be ready for connections." -ForegroundColor $ColorSuccess
            Write-Host "You may need to restart the computer for all changes to take effect." -ForegroundColor $ColorInfo
        } elseif ($DiagnoseOnly) {
            Write-Host "Diagnostics completed. No changes were made to the system." -ForegroundColor $ColorInfo
            Write-Host "Use -EnableRDP parameter to apply recommended fixes." -ForegroundColor $ColorInfo
        }
        
        return $exitCode
        
    } catch {
        Write-Host "`n" + ("!" * 80) -ForegroundColor $ColorError
        Write-Host "SCRIPT EXECUTION ERROR" -ForegroundColor $ColorError
        Write-Host ("!" * 80) -ForegroundColor $ColorError
        
        Write-Host "Error occurred at: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor $ColorError
        Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor $ColorError
        
        if ($Verbose) {
            Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor $ColorVerbose
        }
        
        return 99
    }
}

# Execute main function
$exitCode = Main

# Cleanup and exit
Write-Host "`nScript completed with exit code: $exitCode" -ForegroundColor $(if($exitCode -eq 0){$ColorSuccess}else{$ColorError})
exit $exitCode
#endregion
