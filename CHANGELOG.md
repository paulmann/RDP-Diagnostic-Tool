# Changelog

All notable changes to this project will be documented in this file.

## [4.2.0] - 2025-12-08

### Added
- **Comprehensive Diagnostic System**
  - 50+ diagnostic tests covering all RDP components
  - Registry validation (15+ settings)
  - Service configuration analysis (6 core services)
  - Firewall rule assessment and management
  - Network profile and connectivity testing
  - Security policy and audit verification
  - User permissions analysis
  - Performance and resource evaluation
  - Event log inspection and analysis

- **Automatic Remediation Engine**
  - One-click fix with `-EnableRDP` parameter
  - Registry correction and optimization
  - Service startup configuration
  - Firewall rule creation and enabling
  - Network profile adjustment
  - Dependency resolution
  - Windows feature installation
  - User permission correction
  - Custom RDP port configuration

- **Professional Reporting**
  - Color-coded console output with severity indicators
  - Structured result categorization
  - HTML report generation (`-ExportReport`)
  - Timestamped diagnostics
  - Executive summary with statistics
  - Remediation attempt logging
  - Actionable recommendations

- **Advanced Features**
  - Support for custom RDP ports (1024-65535)
  - Network Level Authentication (NLA) control
  - Private network profile enforcement
  - External connectivity testing
  - Windows edition compatibility checking
  - Virtual machine detection
  - Firewall profile analysis
  - DNS and internet connectivity testing

- **Safety & Control**
  - Diagnostic-only mode (`-DiagnoseOnly`)
  - Safe defaults (no changes without permission)
  - Comprehensive error handling
  - Rollback-friendly operations
  - Detailed logging of all changes
  - Exit codes for automation (0, 1, 2, 3, 4, 99)

### Features
- **System Prerequisites Checking**
  - Administrator privilege verification
  - PowerShell version validation (5.1+)
  - Windows edition compatibility assessment
  - Pending reboot detection
  - Windows feature availability check

- **Windows Edition Analysis**
  - Automatic RDP Server support detection
  - Windows Home edition handling
  - OEM system identification
  - System information collection

- **RDP Capability Tests**
  - Registry structure validation
  - Required DLL verification
  - Driver status monitoring
  - Virtualization environment detection
  - Windows Defender Application Guard check

- **Enhanced Registry Settings**
  - Connection state validation
  - Session configuration analysis
  - Port number verification
  - Authentication level checking
  - Encryption level validation
  - Performance timeout analysis
  - Audio and graphics settings review

- **Service Configuration**
  - TermService status monitoring
  - Session environment configuration
  - USB redirection setup
  - Video driver verification
  - Audio service validation
  - Dependency chain analysis
  - Automatic startup correction

- **Firewall Analysis**
  - Firewall service status
  - Profile configuration review
  - RDP rule detection and analysis
  - Conflicting rule identification
  - Custom rule creation
  - Rule enabling and disabling

- **Network Configuration**
  - Network adapter status
  - IP configuration validation
  - Network profile categorization
  - Connection profile analysis
  - Network discovery status
  - Isolation rule detection

- **Port & Connectivity**
  - Local port listening verification
  - Local connection testing
  - Network loopback testing
  - Port conflict detection
  - External connectivity testing
  - DNS resolution validation
  - Internet connectivity verification

- **Security & Policies**
  - Group Policy review
  - UAC status verification
  - Windows Defender monitoring
  - Credential Guard detection
  - Security auditing validation
  - Failed login attempt analysis

- **User Permissions**
  - Remote Desktop Users group membership
  - Current user RDP rights verification
  - Administrator token detection
  - Local group membership analysis

- **Performance Analysis**
  - System memory evaluation
  - CPU core and thread counting
  - Graphics adapter detection
  - Disk space monitoring
  - Windows Experience Index retrieval

- **Event Log Analysis**
  - RDP service event inspection
  - Security event log review
  - Terminal Services event analysis
  - Error and warning detection
  - Failed login tracking

### Configuration Options
- `-EnableRDP` - Enable RDP with automatic remediation
- `-DiagnoseOnly` - Diagnostic mode without changes
- `-ForcePrivateNetwork` - Convert profiles to Private
- `-ChangePort <port>` - Configure custom RDP port
- `-DisableNLA` - Disable Network Level Authentication
- `-TestExternal` - Test external connectivity
- `-SkipRebootCheck` - Skip pending reboot check
- `-ShowVerbose` - Display detailed output
- `-ExportReport <path>` - Generate HTML report
- `-Help` or `-?` - Display help message

### Exit Codes
- `0` - All tests passed, RDP ready
- `1` - Critical errors detected
- `2` - Warnings detected, RDP may have limitations
- `3` - Unsupported Windows edition
- `4` - Missing critical prerequisites
- `99` - Script execution error

### Requirements
- Windows 10/11 Pro, Enterprise, Education, or Server 2016+
- PowerShell 5.1 or higher
- Administrator privileges
- < 1 MB disk space
- < 50 MB RAM usage

### Initial Release
First stable production release with comprehensive diagnostics, automatic remediation, and professional reporting capabilities.

---

## Versioning

This project follows [Semantic Versioning](https://semver.org/).
- **MAJOR** version for incompatible changes
- **MINOR** version for backwards-compatible functionality
- **PATCH** version for backwards-compatible bug fixes

## Support

For issues, questions, or suggestions, please visit:
- **Issues**: https://github.com/paulmann/RDP-Diagnostic-Tool/issues
- **Discussions**: https://github.com/paulmann/RDP-Diagnostic-Tool/discussions
- **Author**: Mikhail Deynekin (https://deynekin.com)