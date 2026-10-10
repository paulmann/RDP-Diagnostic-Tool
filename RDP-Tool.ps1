<#
.SYNOPSIS
    Comprehensive RDP Diagnostic & Remediation Tool for Windows 10/11 and Windows Server.

.DESCRIPTION
    RDP-Tool performs a complete health check of every Remote Desktop Protocol (RDP)
    component on a Windows machine - OS edition and SKU support, registry configuration
    (local and Group Policy), listener state, services and dependencies, Windows Defender
    Firewall rules, network profiles, listener port, TLS certificate, user permissions,
    security posture, system resources and RDP-related event logs - and can automatically
    remediate most common misconfigurations.

    The tool can also:
      * Perform a real RDP protocol handshake (X.224 / RDP Negotiation) against the local
        listener or any remote host to verify the RDP stack actually answers and to detect
        whether TLS / CredSSP (NLA) is required - without authenticating.
      * List live RDP sessions (WTS API, with qwinsta fallback).
      * Enable / disable the RDP server, change the listener port, manage NLA, add users to
        the "Remote Desktop Users" group, restart the RDP service stack.
      * Export machine-readable JSON and styled HTML reports, write a log file.
      * Check GitHub for a newer version and self-update (-CheckUpdate / -Update).

    Running the tool without parameters executes a full read-only diagnostic pass.
    No changes are made to the system unless an explicit action switch (-EnableRDP,
    -DisableRDP, -SetPort, -AddUser, -RestartServices, -ForcePrivateNetwork, -DisableNLA)
    is supplied. All mutating actions support -WhatIf / -Confirm and require elevation.

    Read-only diagnostics work WITHOUT administrator rights (with reduced coverage);
    any remediation REQUIRES an elevated session (or use -Elevate to auto-relaunch).

.PARAMETER DiagnoseOnly
    Run the full diagnostic pipeline and make no changes (default behavior).

.PARAMETER EnableRDP
    Enable the RDP server and automatically remediate common issues:
    allows remote connections (fDenyTSConnections=0), enables the listener
    (fEnableWinStation=1), configures NLA, starts and repairs TermService and
    dependencies, enables/creates Windows Defender Firewall rules for the RDP
    port, and adds the invoking non-admin user to "Remote Desktop Users" when needed.
    Combine with -SetPort, -AddUser, -DisableNLA, -ForcePrivateNetwork as required.

.PARAMETER DisableRDP
    Securely disable the RDP server: sets fDenyTSConnections=1 and disables
    RDP firewall rules. Warns when executed from inside a remote session.

.PARAMETER SetPort
    Change the RDP listener port (1024-65535). Updates the WinStations\RDP-Tcp
    PortNumber value, creates firewall rules for the new port and restarts the
    listener when safe. Alias: -ChangePort (kept for backward compatibility).
    Used alone it is an action (applies the change, requires elevation);
    combined with -DiagnoseOnly it only audits the current configuration
    against this port.

.PARAMETER DisableNLA
    Disable Network Level Authentication (UserAuthentication=0). STRONGLY
    DISCOURAGED: NLA protects against unauthenticated RDP exploits and
    brute-force session allocation. Requires confirmation (or -Force).

.PARAMETER AddUser
    One or more accounts to add to the local "Remote Desktop Users" group
    (e.g. 'jdoe', '.\jdoe', 'CONTOSO\jdoe'). Implies a remediation action.

.PARAMETER RestartServices
    Restart the RDP service stack (TermService, SessionEnv, UmRdpService).
    WARNING: if you are connected through RDP this terminates active sessions.
    Requires confirmation (or -Force).

.PARAMETER ForcePrivateNetwork
    Set every non-domain network connection profile to the Private category
    (Windows Firewall applies Private-profile rules to RDP by default).

.PARAMETER TestRdpTarget
    Perform a real RDP protocol handshake against 'host' or 'host:port'
    (default port 3389) and report whether the RDP stack answers, which
    security protocol it negotiates (Standard RDP / TLS / CredSSP-NLA) and
    detailed failure codes. Works against localhost and remote systems and
    does not require credentials.

.PARAMETER TestExternal
    Test outbound connectivity and DNS resolution required for RDP tooling
    and updates (github.com:443, DNS, 8.8.8.8:53).

.PARAMETER ShowSessions
    Enumerate RDP/terminal sessions on this machine (ID, user, state,
    client address, protocol) via the WTS API with a qwinsta fallback.

.PARAMETER SkipRebootCheck
    Skip pending-reboot detection (registry heuristics + optional DISM).

.PARAMETER SkipSlowChecks
    Skip time-consuming checks (DISM package scan, WinSAT, full firewall
    port-filter enumeration). Useful on slow machines or in CI.

.PARAMETER ExportReport
    Export a styled, self-contained HTML report to the specified path
    (default: .\RDP-Diagnostic-Report-<timestamp>.html when given a directory).

.PARAMETER ExportJson
    Export a machine-readable JSON report (results, remediations, system
    info, summary, exit code) to the specified path. Ideal for CI/monitoring.

.PARAMETER LogPath
    Write a timestamped plain-text log of every check, result and change
    to the specified file (appended).

.PARAMETER NoBrowser
    Do not auto-open the exported HTML report in a browser.

.PARAMETER Quiet
    Print only the executive summary and errors (no per-check output).

.PARAMETER NoColor
    Disable colored console output (also honors the NO_COLOR environment variable).

.PARAMETER NoEmoji
    Disable Unicode emoji/decoration and use plain ASCII markers ([OK], [WARN], ...).
    Auto-enabled when the console output encoding is not UTF-8.

.PARAMETER CheckUpdate
    Check GitHub for a newer release of this tool and report the result.
    Exit code 5 means "update available". Makes no changes.

.PARAMETER Update
    Download the latest release from GitHub (or -UpdateSource), validate it,
    back up the current script and replace it in place.

.PARAMETER UpdateSource
    Optional custom update source for air-gapped/mirror scenarios: either an
    'owner/repo' GitHub slug (default: paulmann/RDP-Diagnostic-Tool) or a
    direct HTTPS URL to a copy of RDP-Tool.ps1.

.PARAMETER Elevate
    Re-launch this script elevated (UAC prompt) with the same arguments and exit.

.PARAMETER Force
    Skip interactive confirmations for high-impact actions (NLA disable,
    service restart, self-update, RDP disable from a remote session).

.PARAMETER ShowVerbose
    DEPRECATED (kept for backward compatibility). Use the standard -Verbose
    common parameter instead.

.PARAMETER Version
    Display tool version, runtime and repository information, then exit.

.PARAMETER Help
    Display comprehensive built-in help (all switches, examples, exit codes,
    update instructions). Aliases: -?, -h. Full comment-based help is also
    available via: Get-Help .\RDP-Tool.ps1 -Full

.EXAMPLE
    .\RDP-Tool.ps1
    Full read-only diagnostic pass with console summary and exit code.

.EXAMPLE
    .\RDP-Tool.ps1 -EnableRDP -Force
    Enable and repair RDP end-to-end without interactive prompts (elevated).

.EXAMPLE
    .\RDP-Tool.ps1 -EnableRDP -SetPort 3390 -AddUser 'CONTOSO\jdoe','.\helpdesk'
    Enable RDP on custom port 3390, open the firewall for it and grant two
    accounts remote logon rights.

.EXAMPLE
    .\RDP-Tool.ps1 -DiagnoseOnly -ExportReport .\report.html -ExportJson .\report.json -LogPath .\rdp.log
    Read-only audit producing HTML + JSON reports and a log file.

.EXAMPLE
    .\RDP-Tool.ps1 -TestRdpTarget 'srv01.contoso.com:3390'
    Remote RDP handshake probe: verifies the RDP stack answers and shows the
    negotiated security protocol (TLS/CredSSP) without logging on.

.EXAMPLE
    .\RDP-Tool.ps1 -ShowSessions
    List live terminal sessions (who is connected, from where, session state).

.EXAMPLE
    .\RDP-Tool.ps1 -CheckUpdate
    Ask GitHub whether a newer version exists (exit code 5 = update available).

.EXAMPLE
    .\RDP-Tool.ps1 -Update -Force
    Self-update from the latest GitHub release, backing up the current script.

.EXAMPLE
    .\RDP-Tool.ps1 -DisableRDP -Force
    Immediately disable inbound RDP and close firewall rules.

.EXAMPLE
    .\RDP-Tool.ps1 -EnableRDP -WhatIf
    Show exactly what the remediation engine would change, touching nothing.

.EXAMPLE
    .\RDP-Tool.ps1 -Help
    Comprehensive built-in help; also try: Get-Help .\RDP-Tool.ps1 -Full

.OUTPUTS
    None. Diagnostics are written to the console and (optionally) to HTML/JSON/log files.
    The process exit code conveys the overall result (see NOTES and the README).

.NOTES
    Tool:        RDP Diagnostic & Remediation Tool (RDP-Tool.ps1)
    Author:      Mikhail Deynekin [ Deynekin.com ]
    Version:     5.0.1 (2026-10-10)
    Requires:    Windows 10/11 or Windows Server 2016+; PowerShell 7+;
                 administrator rights for any change (read-only mode works unelevated).
    Repository:  https://github.com/paulmann/RDP-Diagnostic-Tool

    EXIT CODES
      0  Success - system ready (or action completed / up to date)
      1  Critical issues detected - RDP will NOT work until resolved
      2  Errors/warnings detected - RDP may be degraded or limited
      3  Unsupported Windows edition (Home / SE cannot host RDP)
      4  Prerequisite not met (elevation required, invalid parameter combination)
      5  Update available (returned by -CheckUpdate only)
      6  Update failed
      99 Unhandled script error

    SECURITY
      * The tool never reads, stores or transmits credentials.
      * The RDP handshake probe sends an unauthenticated X.224 negotiation
        request only - equivalent to opening mstsc and closing it.
      * Updates are downloaded from GitHub over TLS and validated (version
        marker + sanity checks) before the current script is replaced; the
        previous file is kept as a timestamped .bak next to it.

.LINK
    https://github.com/paulmann/RDP-Diagnostic-Tool

.LINK
    https://github.com/paulmann/RDP-Diagnostic-Tool/wiki
#>

# ============================================================================
#  RDP Diagnostic & Remediation Tool - v5.0.1
#  (c) Mikhail Deynekin [ Deynekin.com ] - MIT License
# ============================================================================

#Requires -Version 7.0
#Requires -PSEdition Core

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    # ---------------- Diagnostic modes ----------------
    [switch] $DiagnoseOnly,

    [switch] $EnableRDP,

    [switch] $DisableRDP,

    # ---------------- Configuration actions ----------------
    [Alias('ChangePort')]
    [ValidateRange(1024, 65535)]
    [int] $SetPort = 0,

    [switch] $DisableNLA,

    [ValidateNotNullOrEmpty()]
    [string[]] $AddUser = @(),

    [switch] $RestartServices,

    [switch] $ForcePrivateNetwork,

    # ---------------- Probes ----------------
    [ValidateNotNullOrEmpty()]
    [string] $TestRdpTarget = '',

    [switch] $TestExternal,

    [switch] $ShowSessions,

    # ---------------- Check tuning ----------------
    [switch] $SkipRebootCheck,

    [switch] $SkipSlowChecks,

    # ---------------- Reporting ----------------
    [string] $ExportReport = '',

    [string] $ExportJson = '',

    [string] $LogPath = '',

    [switch] $NoBrowser,

    [switch] $Quiet,

    [switch] $NoColor,

    [switch] $NoEmoji,

    # ---------------- Update ----------------
    [switch] $CheckUpdate,

    [switch] $Update,

    [string] $UpdateSource = '',

    # ---------------- Misc ----------------
    [switch] $Elevate,

    [switch] $Force,

    [switch] $ShowVerbose,

    [switch] $Version,

    [Alias('?', 'h', 'ShowHelp')]
    [switch] $Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

if ($ShowVerbose) {
    # Deprecated switch kept for backward compatibility with v4.x invocations.
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'
    Write-Warning "-ShowVerbose is deprecated and will be removed in a future release; use the standard -Verbose parameter instead."
}

if ($Force) {
    # Suppress ShouldProcess prompts for high-impact remediation/update actions.
    $ConfirmPreference = 'None'
}

#region Tool Metadata (single source of truth)
# ============================================================================
# Tool metadata - keep in sync with CHANGELOG.md and the GitHub release tag.
# The updater parses $script:ToolVersion from the remote script, so DO NOT
# change the literal format of the assignment below.
# ============================================================================
$script:ToolName = 'RDP Diagnostic & Remediation Tool'
$script:ToolVersion = [version]'5.0.1'
$script:ToolReleaseDate = '2026-10-10'
$script:ToolFileName = 'RDP-Tool.ps1'
$script:ToolAuthor = 'Mikhail Deynekin [ Deynekin.com ]'
$script:ToolRepo = 'paulmann/RDP-Diagnostic-Tool'
$script:ToolRepoUrl = 'https://github.com/paulmann/RDP-Diagnostic-Tool'
$script:ToolRawBase = 'https://raw.githubusercontent.com/paulmann/RDP-Diagnostic-Tool'
$script:ToolApiBase = 'https://api.github.com/repos/paulmann/RDP-Diagnostic-Tool'

# Exit codes (documented in help, README and CHANGELOG).
$script:ExitCode = @{
    Success          = 0
    Critical         = 1
    Errors           = 2
    UnsupportedOs    = 3
    Prerequisite     = 4
    UpdateAvailable  = 5
    UpdateFailed     = 6
    ScriptError      = 99
}

# Severity levels for diagnostic results.
$script:Severity = @{
    Info     = 1
    Warning  = 2
    Error    = 3
    Critical = 4
}
#endregion

#region Console & Logging Infrastructure
# ============================================================================
# Console rendering (color/emoji/width aware) and file logging.
# ============================================================================
$script:StartTime = [datetime]::Now
$script:ReportId = [guid]::NewGuid().ToString('N').Substring(0, 8).ToUpperInvariant()
$script:LogFile = $null
$script:IsWindowsOs = $IsWindows   # script #Requires PowerShell 7, where $IsWindows always exists
$script:IsAdmin = $false
$script:IsRemoteSession = $false
$script:ConsoleWidth = 100
$script:UseColor = $true
$script:UseEmoji = $true
# Capture the script-level bound parameters once (functions have their own $PSBoundParameters).
$script:BoundArguments = @($PSBoundParameters.GetEnumerator() | ForEach-Object { '-{0} {1}' -f $_.Key, $_.Value })
# ASCII-safe defaults; Initialize-ConsoleEnvironment replaces these when it runs.
$script:Colors = @{}
$script:Icons = @{
    Ok = '[OK]'; Warn = '[!]'; Err = '[X]'; Crit = '[!!]'; Info = '[i]'; Section = '>'
    Rocket = '>'; Lock = '[sec]'; Plug = '[net]'; Globe = '[ext]'; Gear = '[cfg]'; Users = '[usr]'
    Report = '[rpt]'; Summary = '[sum]'; Clock = '[t]'; Tag = '[os]'; Flask = '[test]'; Key = '[key]'
    Link = '[url]'; Bulb = '[tip]'; Arrow = '->'; Bullet = '*'; Rule = '='; Dash = '-'
}

function Initialize-ConsoleEnvironment {
    <#
    .SYNOPSIS
        Detects console capabilities (width, color, UTF-8 emoji support) and
        initializes the icon/color tables used by all output helpers.
    #>
    [CmdletBinding()]
    param()

    # --- Console width -----------------------------------------------------
    try {
        $rawUi = $Host.UI.RawUI
        $width = $rawUi.WindowSize.Width
        if ($width -ge 60 -and $width -le 300) { $script:ConsoleWidth = $width }
        elseif ($width -gt 300) { $script:ConsoleWidth = 160 }
    } catch {
        $script:ConsoleWidth = 100
    }

    # --- Color support ------------------------------------------------------
    $script:UseColor = -not ($NoColor.IsPresent -or $env:NO_COLOR)

    # --- Emoji support ------------------------------------------------------
    $encodingIsUtf8 = $false
    try {
        $encodingIsUtf8 = [Console]::OutputEncoding.WebName -match '^utf-?8$'
    } catch {
        $encodingIsUtf8 = $false
    }
    $script:UseEmoji = -not $NoEmoji -and $encodingIsUtf8

    $script:Colors = @{
        Success = 'Green'
        Warning = 'Yellow'
        Error   = 'Red'
        Info    = 'Cyan'
        Header  = 'Magenta'
        Verbose = 'Gray'
        Debug   = 'DarkGray'
        Neutral = 'White'
        Accent  = 'Blue'
    }

    if ($script:UseEmoji) {
        $script:Icons = @{
            Ok        = [char]::ConvertFromUtf32(0x2705)   # white heavy check mark
            Warn      = [char]::ConvertFromUtf32(0x26A0)   # warning sign
            Err       = [char]::ConvertFromUtf32(0x274C)   # cross mark
            Crit      = [char]::ConvertFromUtf32(0x1F525)  # fire
            Info      = [char]::ConvertFromUtf32(0x2139)   # information source
            Section   = [char]::ConvertFromUtf32(0x1F4CA)  # bar chart
            Rocket    = [char]::ConvertFromUtf32(0x1F680)  # rocket
            Lock      = [char]::ConvertFromUtf32(0x1F512)  # lock
            Plug      = [char]::ConvertFromUtf32(0x1F50C)  # electric plug
            Globe     = [char]::ConvertFromUtf32(0x1F310)  # globe
            Gear      = [char]::ConvertFromUtf32(0x2699)   # gear
            Users     = [char]::ConvertFromUtf32(0x1F465)  # busts in silhouette
            Report    = [char]::ConvertFromUtf32(0x1F4C4)  # page facing up
            Summary   = [char]::ConvertFromUtf32(0x1F4C8)  # chart upwards trend
            Clock     = [char]::ConvertFromUtf32(0x23F1)   # stopwatch
            Tag       = [char]::ConvertFromUtf32(0x1F3F7)  # label tag
            Flask     = [char]::ConvertFromUtf32(0x1F9EA)  # test tube
            Key       = [char]::ConvertFromUtf32(0x1F511)  # key
            Link      = [char]::ConvertFromUtf32(0x1F517)  # link
            Bulb      = [char]::ConvertFromUtf32(0x1F4A1)  # light bulb
            Arrow     = [char]::ConvertFromUtf32(0x2192)   # rightwards arrow
            Bullet    = [char]::ConvertFromUtf32(0x2022)   # bullet
            Rule      = [string][char]0x2550               # double horizontal line
            Dash      = [string][char]0x2500               # light horizontal line
        }
    } else {
        $script:Icons = @{
            Ok = '[OK]'; Warn = '[!]'; Err = '[X]'; Crit = '[!!]'
            Info = '[i]'; Section = '>'; Rocket = '>'; Lock = '[sec]'; Plug = '[net]'
            Globe = '[ext]'; Gear = '[cfg]'; Users = '[usr]'; Report = '[rpt]'; Summary = '[sum]'
            Clock = '[t]'; Tag = '[os]'; Flask = '[test]'; Key = '[key]'; Link = '[url]'
            Bulb = '[tip]'; Arrow = '->'; Bullet = '*'; Rule = '='; Dash = '-'
        }
    }
}

function Show-Line {
    <#
    .SYNOPSIS
        Writes a line to the console (unless -Quiet suppresses informational
        output) and appends a plain-text version to the log file when enabled.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string] $Text = '',
        [string] $Color = 'Neutral',
        [switch] $Force,          # print even in Quiet mode
        [switch] $NoLog,
        [string] $LogLevel = 'INFO'
    )
    process {
        # Log FIRST: the log file must be complete even when -Quiet hides console output.
        if ($script:LogFile -and -not $NoLog) {
            Add-LogEntry -Message $Text -Level $LogLevel
        }
        if ((-not $Force) -and $script:QuietMode) { return }
        if ($script:UseColor -and $script:Colors.ContainsKey($Color)) {
            Write-Host $Text -ForegroundColor $script:Colors[$Color]
        } else {
            Write-Host $Text
        }
    }
}

function Add-LogEntry {
    <#
    .SYNOPSIS
        Appends a timestamped entry to the log file (no console output).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'ACTION', 'DEBUG')]
        [string] $Level = 'INFO'
    )
    if (-not $script:LogFile) { return }
    try {
        $line = '{0:yyyy-MM-dd HH:mm:ss.fff} [{1,-5}] {2}' -f [datetime]::Now, $Level, $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {
        # Logging must never break the tool.
        $script:LogFile = $null
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Resolves -LogPath, creates the target directory and writes the log header.
    #>
    [CmdletBinding()]
    param()
    if ([string]::IsNullOrWhiteSpace($LogPath)) { return }
    try {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath)
        $dir = Split-Path -Path $resolved -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            $null = New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop
        }
        $script:LogFile = $resolved
        Add-Content -LiteralPath $script:LogFile -Encoding utf8 -Value '' -ErrorAction SilentlyContinue
        Add-LogEntry -Level 'INFO' -Message ('=' * 78)
        Add-LogEntry -Level 'INFO' -Message ("{0} v{1} - ReportID {2} - started {3:yyyy-MM-dd HH:mm:ss}" -f $script:ToolName, $script:ToolVersion, $script:ReportId, $script:StartTime)
        Add-LogEntry -Level 'INFO' -Message ("Script: {0} {1}" -f $PSCommandPath, ($script:BoundArguments -join ' '))
    } catch {
        Write-Warning "Unable to initialize log file '$LogPath': $($_.Exception.Message)"
        $script:LogFile = $null
    }
}

function Show-Section {
    <#
    .SYNOPSIS
        Renders a section header bar with an icon, title and optional subtitle.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Title,
        [string] $Subtitle = '',
        [string] $Icon = 'Section'
    )
    $rule = [string]$script:Icons['Rule'] * $script:ConsoleWidth
    $iconChar = if ($script:Icons.ContainsKey($Icon)) { $script:Icons[$Icon] } else { '>' }
    Show-Line -Text '' -Force:$false -NoLog
    Show-Line -Text $rule -Color 'Header' -NoLog
    Show-Line -Text "$iconChar $Title" -Color 'Header'
    if ($Subtitle) { Show-Line -Text "  $Subtitle" -Color 'Verbose' -NoLog }
    Show-Line -Text $rule -Color 'Header' -NoLog
}

function Show-KeyValuePair {
    <#
    .SYNOPSIS
        Prints an aligned 'Key : value' line.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Key,
        [AllowEmptyString()][string] $Value = '',
        [string] $Color = 'Neutral',
        [int] $Width = 22
    )
    Show-Line -Text ("  {0,-$Width}: {1}" -f $Key, $Value) -Color $Color
}
#endregion

#region Result State
# ============================================================================
# Diagnostic result state: every check appends structured records that feed
# the console summary, HTML/JSON reports and the exit-code computation.
# ============================================================================
$script:DiagnosticResults = [System.Collections.Generic.List[object]]::new()
$script:RemediationLog = [System.Collections.Generic.List[object]]::new()
$script:TestResults = [System.Collections.Generic.List[object]]::new()
$script:SystemInfo = [ordered]@{}
$script:EffectiveRdpPort = 3389
$script:QuietMode = [bool]$Quiet

function Get-SeverityName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $Severity)
    switch ($Severity) {
        $script:Severity.Info     { 'OK' }
        $script:Severity.Warning  { 'WARNING' }
        $script:Severity.Error    { 'ERROR' }
        $script:Severity.Critical { 'CRITICAL' }
        default                    { 'INFO' }
    }
}

function New-DiagnosticResult {
    <#
    .SYNOPSIS
        Records one diagnostic result, renders it on the console (severity
        colored) and writes it to the log file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Component,
        [Parameter(Mandatory)][string] $Status,
        [string] $Details = '',
        [string] $Remedy = '',
        [string] $Category = 'General',
        [ValidateSet(1, 2, 3, 4)]
        [int] $Severity = 1
    )

    $record = [pscustomobject]@{
        Component = $Component
        Status    = $Status
        Details   = $Details
        Remedy    = $Remedy
        Category  = $Category
        Severity  = $Severity
        Time      = [datetime]::Now.ToString('HH:mm:ss.fff')
    }
    $script:DiagnosticResults.Add($record)

    $color = switch ($Severity) {
        $script:Severity.Info     { 'Success' }
        $script:Severity.Warning  { 'Warning' }
        $script:Severity.Error    { 'Error' }
        $script:Severity.Critical { 'Error' }
        default                    { 'Neutral' }
    }
    $iconKey = switch ($Severity) {
        $script:Severity.Info     { 'Ok' }
        $script:Severity.Warning  { 'Warn' }
        $script:Severity.Error    { 'Err' }
        $script:Severity.Critical { 'Crit' }
        default                    { 'Info' }
    }
    $tag = switch ($Severity) {
        $script:Severity.Info     { '[ OK ]' }
        $script:Severity.Warning  { '[WARN]' }
        $script:Severity.Error    { '[FAIL]' }
        $script:Severity.Critical { '[CRIT]' }
        default                    { '[INFO]' }
    }
    $isProblem = $Severity -ge $script:Severity.Warning

    Show-Line -Text ("{0} {1} {2}: {3}" -f $script:Icons[$iconKey], $tag, $Component, $Status) -Color $color -Force:$isProblem
    if ($Details) {
        Show-Line -Text ("        Details: {0}" -f $Details) -Color 'Verbose' -Force:$false
        Write-Verbose "[$Component] $Details"
    }
    if ($Remedy) {
        Show-Line -Text ("        Remedy : {0}" -f ($Remedy -split "`r?`n" | Select-Object -First 1)) -Color 'Verbose'
        Write-Verbose "[$Component] Full remedy:`n$Remedy"
    }
    Add-LogEntry -Level ($(if ($isProblem) { 'WARN' } else { 'INFO' })) -Message ("[{0}] {1} = {2} | {3}" -f (Get-SeverityName -Severity $Severity), $Component, $Status, $Details)
}

function New-RemediationRecord {
    <#
    .SYNOPSIS
        Records the outcome of one remediation action.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Action,
        [Parameter(Mandatory)][bool] $Success,
        [string] $Notes = '',
        [switch] $Skipped
    )
    $record = [pscustomobject]@{
        Action  = $Action
        Success = [bool]$Success
        Skipped = [bool]$Skipped.IsPresent
        Notes   = $Notes
        Time    = [datetime]::Now.ToString('HH:mm:ss')
    }
    $script:RemediationLog.Add($record)

    $status = if ($Skipped) { 'SKIPPED' } elseif ($Success) { 'SUCCESS' } else { 'FAILED' }
    $color = if ($Skipped) { 'Warning' } elseif ($Success) { 'Success' } else { 'Error' }
    $icon = if ($Skipped) { 'Warn' } elseif ($Success) { 'Ok' } else { 'Err' }
    Show-Line -Text ("{0} [FIX ] {1} - {2}" -f $script:Icons[$icon], $Action, $status) -Color $color -Force
    if ($Notes) { Show-Line -Text ("        Notes: {0}" -f $Notes) -Color 'Verbose' -Force }
    Add-LogEntry -Level 'ACTION' -Message ("REMEDIATION {0}: {1} | {2}" -f $status, $Action, $Notes)
}

function New-TestRecord {
    <#
    .SYNOPSIS
        Records a pass/fail probe result (TCP connect, handshake, etc.).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][bool] $Passed,
        [string] $Message = '',
        $Data = $null
    )
    $record = [pscustomobject]@{
        Name    = $Name
        Passed  = [bool]$Passed
        Message = $Message
        Data    = $Data
        Time    = [datetime]::Now.ToString('HH:mm:ss.fff')
    }
    $script:TestResults.Add($record)
    Write-Verbose ("[TEST] {0}: {1} - {2}" -f $Name, $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Message)
}

function Invoke-Check {
    <#
    .SYNOPSIS
        Executes one diagnostic check inside a guarded scope so that a single
        failing subsystem (WMI, firewall API, event log, ...) can never abort
        the whole pipeline. Failures are recorded as warnings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][scriptblock] $ScriptBlock
    )
    try {
        & $ScriptBlock
    } catch {
        New-DiagnosticResult -Component $Name -Status 'CHECK ERROR' `
            -Details ("Unexpected error inside check: {0}" -f $_.Exception.Message) `
            -Remedy 'Re-run with -Verbose; if reproducible, attach an -ExportReport file to a GitHub issue.' `
            -Category 'Internal' -Severity $script:Severity.Warning
        Write-Verbose ("Check '{0}' failed at {1}:{2}`n{3}" -f $Name, $_.InvocationInfo.ScriptName, $_.InvocationInfo.ScriptLineNumber, $_.ScriptStackTrace)
        Add-LogEntry -Level 'ERROR' -Message ("Check '$Name' threw: $($_.Exception.Message)")
    }
}

function Get-RegistryValue {
    <#
    .SYNOPSIS
        Strict-mode-safe registry value reader. Returns $null when the key or
        value does not exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Name
    )
    try {
        return Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
    } catch {
        return $null
    }
}

function Test-RegistryValueExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Name
    )
    if (-not (Test-Path -Path $Path)) { return $false }
    $key = Get-Item -Path $Path -ErrorAction SilentlyContinue
    if ($null -eq $key) { return $false }
    return $key.GetValueNames() -contains $Name
}
#endregion

#region Parameter Validation
# ============================================================================
# Parameter combination validation (friendly errors + exit code 4 instead of
# broken ParameterSet acrobatics).
# ============================================================================
function Test-ParameterCombination {
    <#
    .SYNOPSIS
        Validates mutually exclusive and dependent parameter combinations.
        Returns $true when the combination is valid; otherwise prints the
        reason and returns $false.
    #>
    [CmdletBinding()]
    param()

    $errors = [System.Collections.Generic.List[string]]::new()

    $modes = @(
        if ($DiagnoseOnly) { '-DiagnoseOnly' }
        if ($EnableRDP)    { '-EnableRDP' }
        if ($DisableRDP)   { '-DisableRDP' }
        if ($Update)       { '-Update' }
        if ($CheckUpdate)  { '-CheckUpdate' }
    )
    if ($modes.Count -gt 1) {
        $errors.Add("Mutually exclusive modes specified: $($modes -join ', '). Pick exactly one.")
    }

    if ($AddUser.Count -gt 0 -and $DisableRDP) {
        $errors.Add('-AddUser cannot be combined with -DisableRDP (granting access while disabling the server is contradictory).')
    }
    if ($RestartServices -and $DisableRDP) {
        $errors.Add('-RestartServices cannot be combined with -DisableRDP.')
    }
    if ($DiagnoseOnly) {
        $conflicting = @(
            if ($EnableRDP)           { '-EnableRDP' }
            if ($DisableRDP)          { '-DisableRDP' }
            if ($AddUser.Count -gt 0) { '-AddUser' }
            if ($RestartServices)     { '-RestartServices' }
            if ($ForcePrivateNetwork) { '-ForcePrivateNetwork' }
        )
        if ($conflicting.Count -gt 0) {
            $errors.Add("-DiagnoseOnly makes no changes; remove conflicting action(s): $($conflicting -join ', '). (-SetPort/-DisableNLA are allowed: they only change the audit baseline.)")
        }
    }
    if (($SetPort -gt 0) -and $DisableRDP) {
        $errors.Add('-SetPort cannot be combined with -DisableRDP.')
    }
    # Note: -DisableNLA is valid both with -EnableRDP (apply during enable) and with
    # -DiagnoseOnly (expected NLA value flips to 0 for auditing NLA-disabled servers).
    if ($Elevate -and ($CheckUpdate -or $Update)) {
        $errors.Add('-Elevate cannot be combined with -CheckUpdate/-Update (updates do not need elevation unless the script lives in a protected directory).')
    }

    if ($errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Error -Message $e -ErrorAction Continue }
        Show-Line -Text '' -Force
        Show-Line -Text 'Invalid parameter combination. Run with -Help for the full option reference.' -Color 'Error' -Force
        return $false
    }
    return $true
}

function Get-RequestedActionList {
    <#
    .SYNOPSIS
        Returns the list of mutating actions requested on the command line.
    #>
    [CmdletBinding()]
    param()
    $actions = [System.Collections.Generic.List[string]]::new()
    if ($EnableRDP)            { $actions.Add('EnableRDP') }
    if ($DisableRDP)           { $actions.Add('DisableRDP') }
    if ($SetPort -gt 0 -and -not $DiagnoseOnly) { $actions.Add('SetPort') }
    if ($DisableNLA -and -not $DiagnoseOnly -and -not $EnableRDP) { $actions.Add('DisableNLA') }
    if ($AddUser.Count -gt 0 -and -not $DiagnoseOnly) { $actions.Add('AddUser') }
    if ($RestartServices)      { $actions.Add('RestartServices') }
    if ($ForcePrivateNetwork)  { $actions.Add('ForcePrivateNetwork') }
    return $actions
}

function Test-RunningElevated {
    <#
    .SYNOPSIS
        Returns $true when the current process has an elevated (Administrator) token.
    #>
    [CmdletBinding()]
    param()
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Test-InRemoteSession {
    <#
    .SYNOPSIS
        Best-effort detection whether the tool runs inside an RDP session
        (used to warn before service restarts / disabling RDP).
        SESSIONNAME is 'Console' for physical sessions and 'RDP-Tcp#N' inside
        remote sessions; ICA- prefixes cover Citrix.
    #>
    [CmdletBinding()]
    param()
    try {
        if ($env:SESSIONNAME -and $env:SESSIONNAME -match '^(RDP|ICA|rdp|ica)') { return $true }
    } catch {
        Write-Verbose "Remote-session detection inconclusive: $($_.Exception.Message)"
    }
    return $false
}
#endregion

#region Help & Version Display
# ============================================================================
# Built-in comprehensive help (-Help) and version info (-Version).
# ============================================================================
function Show-ToolBanner {
    [CmdletBinding()]
    param()
    $rule = [string]$script:Icons['Rule'] * $script:ConsoleWidth
    Show-Line -Text $rule -Color 'Header' -NoLog -Force
    Show-Line -Text ("{0}  {1}" -f $script:Icons['Rocket'], $script:ToolName.ToUpperInvariant()) -Color 'Header' -Force
    Show-Line -Text ("v{0} ({1})  |  {2}  |  ReportID: {3}" -f $script:ToolVersion, $script:ToolReleaseDate, $script:ToolRepoUrl, $script:ReportId) -Color 'Verbose' -Force
    Show-Line -Text $rule -Color 'Header' -NoLog -Force
}

function Show-ToolHelp {
    <#
    .SYNOPSIS
        Comprehensive built-in help: mode reference, every switch grouped by
        purpose, examples, exit codes, update and reporting instructions.
    #>
    [CmdletBinding()]
    param()

    $rule = [string]$script:Icons['Rule'] * $script:ConsoleWidth
    $dash = [string]$script:Icons['Dash'] * ($script:ConsoleWidth - 4)

    Show-ToolBanner
    Show-Line -Text '' -Force
    Show-Line -Text 'USAGE' -Color 'Info' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 [<mode>] [<actions>] [<probes>] [<reporting>] [<update>] [<misc>]' -Force
    Show-Line -Text '' -Force
    Show-Line -Text 'WHAT IT DOES' -Color 'Info' -Force
    Show-Line -Text '  Runs 50+ checks across OS edition, registry (local + GPO), services,' -Force
    Show-Line -Text '  firewall, network, listener port, TLS certificate, permissions, security' -Force
    Show-Line -Text '  posture, resources and RDP event logs; optionally repairs the found' -Force
    Show-Line -Text '  issues and exports HTML/JSON reports. Without parameters the tool is' -Force
    Show-Line -Text '  strictly read-only. All changes require elevation and honor -WhatIf.' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'MODES (pick at most one)' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  -DiagnoseOnly            Full read-only audit (default when no action given)' -Force
    Show-Line -Text '  -EnableRDP               Enable RDP + auto-remediate everything it can fix' -Force
    Show-Line -Text '  -DisableRDP              Securely disable RDP (deny connections + firewall)' -Force
    Show-Line -Text '  -CheckUpdate             Query GitHub for a newer version (exit 5 = newer exists)' -Force
    Show-Line -Text '  -Update                  Download + validate + back up + self-replace' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'CONFIGURATION ACTIONS (require elevation; imply remediation)' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  -SetPort <1024-65535>    Change listener port (alias: -ChangePort)' -Force
    Show-Line -Text '  -DisableNLA              Turn Network Level Authentication OFF (insecure!)' -Force
    Show-Line -Text '  -AddUser <u1,u2,...>     Add accounts to "Remote Desktop Users" group' -Force
    Show-Line -Text '  -RestartServices         Restart TermService/SessionEnv/UmRdpService' -Force
    Show-Line -Text '  -ForcePrivateNetwork     Set all non-domain network profiles to Private' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'PROBES & INSPECTION' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  -TestRdpTarget <host[:port]>  Real X.224/RDP negotiation handshake against' -Force
    Show-Line -Text '                           local or REMOTE host; shows TLS/CredSSP(NLA)' -Force
    Show-Line -Text '                           requirement without authenticating' -Force
    Show-Line -Text '  -ShowSessions            List live terminal sessions (WTS API + fallback)' -Force
    Show-Line -Text '  -TestExternal            Outbound DNS/TCP checks (github.com:443, 8.8.8.8:53)' -Force
    Show-Line -Text '  -SkipRebootCheck         Skip pending-reboot detection' -Force
    Show-Line -Text '  -SkipSlowChecks          Skip DISM scan & other slow probes' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'REPORTING' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  -ExportReport <file.html>  Self-contained styled HTML report' -Force
    Show-Line -Text '  -ExportJson <file.json>    Machine-readable report for CI/monitoring' -Force
    Show-Line -Text '  -LogPath <file.log>        Timestamped run log (appended)' -Force
    Show-Line -Text '  -NoBrowser                 Do not auto-open the HTML report' -Force
    Show-Line -Text '  -Quiet                     Summary + problems only' -Force
    Show-Line -Text '  -NoColor / -NoEmoji        Plain output (NO_COLOR env also honored;' -Force
    Show-Line -Text '                             ASCII fallback auto-enabled on legacy consoles)' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'MISC' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  -Elevate                 Relaunch elevated with the same arguments (UAC)' -Force
    Show-Line -Text '  -Force                   Skip confirmations for high-impact actions' -Force
    Show-Line -Text '  -UpdateSource <src>      "owner/repo" slug or direct HTTPS URL to RDP-Tool.ps1' -Force
    Show-Line -Text '  -Version                 Print version/runtime info and exit' -Force
    Show-Line -Text '  -Verbose                 Detailed per-check output (replaces old -ShowVerbose)' -Force
    Show-Line -Text '  -WhatIf / -Confirm       Preview / gate every system change' -Force
    Show-Line -Text '  -Help, -?, -h            This help. Full help: Get-Help .\RDP-Tool.ps1 -Full' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'EXAMPLES' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  .\RDP-Tool.ps1                                        # full read-only audit' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -EnableRDP -Force                      # enable + repair, no prompts' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -EnableRDP -SetPort 3390               # enable on port 3390' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -AddUser "CONTOSO\jdoe",".\helpdesk"   # grant RDP logon rights' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -TestRdpTarget "10.0.0.5:3390"         # probe remote RDP stack' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -ShowSessions                          # who is connected now' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -DiagnoseOnly -ExportReport report.html -ExportJson report.json' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -EnableRDP -WhatIf                     # dry run: show intended fixes' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -CheckUpdate                           # is a new version out?' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -Update -Force                         # self-update (backup kept)' -Color 'Verbose' -Force
    Show-Line -Text '  .\RDP-Tool.ps1 -DisableRDP -Force                     # lock the machine down' -Color 'Verbose' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'EXIT CODES' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  0  Success / system ready / up to date       4  Prerequisite failed (elevation,' -Force
    Show-Line -Text '  1  Critical issues - RDP will not work          invalid parameter combination)' -Force
    Show-Line -Text '  2  Errors or warnings - RDP degraded         5  Update available (-CheckUpdate)' -Force
    Show-Line -Text '  3  Unsupported edition (Windows Home/SE)     6  Update failed' -Force
    Show-Line -Text '                                             99 Unhandled script error' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'AUTO-UPDATE' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text "  Source of truth: latest GitHub release of $($script:ToolRepo)." -Force
    Show-Line -Text '  -CheckUpdate compares your version with the remote one (no changes).' -Force
    Show-Line -Text '  -Update downloads the new script over TLS, validates it (version marker,' -Force
    Show-Line -Text '  minimum size, PowerShell syntax parse), stores a timestamped backup' -Force
    Show-Line -Text '  (RDP-Tool.ps1.bak-<ts>) next to the current file and replaces it.' -Force
    Show-Line -Text '  Air-gapped networks: mirror the file and point -UpdateSource at the URL,' -Force
    Show-Line -Text '  or use -UpdateSource "owner/repo" for a fork.' -Force
    Show-Line -Text '' -Force

    Show-Line -Text 'NOTES' -Color 'Info' -Force
    Show-Line -Text $dash -Color 'Verbose' -NoLog -Force
    Show-Line -Text '  * Read-only diagnostics run unelevated (reduced coverage, clearly marked).' -Force
    Show-Line -Text '  * Windows Home/SE cannot host the RDP server (Microsoft licensing); the tool' -Force
    Show-Line -Text '    detects this and exits with code 3 plus upgrade/alternative guidance.' -Force
    Show-Line -Text '  * The tool never touches credentials and never enables multi-session hacks' -Force
    Show-Line -Text '    (fSingleSessionPerUser is reported but intentionally not "fixed").' -Force
    Show-Line -Text ("  * Author: {0}  |  License: MIT" -f $script:ToolAuthor) -Force
    Show-Line -Text '' -Force
    Show-Line -Text $rule -Color 'Header' -NoLog -Force
}

function Show-ToolVersionInfo {
    <#
    .SYNOPSIS
        Prints compact version/runtime information (-Version).
    #>
    [CmdletBinding()]
    param()
    Show-ToolBanner
    Show-Line -Text '' -Force
    Show-KeyValuePair -Key 'Tool' -Value ("{0} v{1}" -f $script:ToolName, $script:ToolVersion) -Color 'Info'
    Show-KeyValuePair -Key 'Released' -Value $script:ToolReleaseDate
    Show-KeyValuePair -Key 'Author' -Value $script:ToolAuthor
    Show-KeyValuePair -Key 'Repository' -Value $script:ToolRepoUrl
    Show-KeyValuePair -Key 'Script path' -Value $(if ($PSCommandPath) { $PSCommandPath } else { '<unknown>' })
    Show-KeyValuePair -Key 'PowerShell' -Value ("{0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
    Show-KeyValuePair -Key 'OS' -Value $(if ($script:IsWindowsOs) { [System.Environment]::OSVersion.VersionString } else { 'Non-Windows (unsupported)' })
    Show-KeyValuePair -Key 'Elevated' -Value $(if ($script:IsAdmin) { 'yes' } else { 'no' })
    Show-Line -Text '' -Force
    Show-Line -Text '  Run -CheckUpdate to see if a newer version is available.' -Color 'Verbose' -Force
}
#endregion

#region Update Engine
# ============================================================================
# GitHub-backed self-update: releases API first, raw-file probe as fallback.
# ============================================================================
$script:VersionMarkerRegex = "\`$script:ToolVersion\s*=\s*\[version\]'(?<v>\d+\.\d+\.\d+(?:\.\d+)?)(?:-(?<pre>[0-9A-Za-z\.\-]+))?'"

function Get-RemoteToolVersion {
    <#
    .SYNOPSIS
        Resolves the newest published version of the tool.
        Strategy: GitHub releases/latest API -> if that fails (no releases,
        rate limit, offline), download the raw script from the default branch
        and parse its embedded version marker.
    .OUTPUTS
        [pscustomobject] Version, Tag, Source ('release'|'raw'|'direct-url'),
        DownloadUrl, Notes - or $null when nothing could be resolved.
    #>
    [CmdletBinding()]
    param(
        [string] $Source = ''
    )

    $headers = @{
        'User-Agent'         = ('{0}/{1} (PowerShell {2}; Windows)' -f $script:ToolFileName, $script:ToolVersion, $PSVersionTable.PSVersion)
        'Accept'             = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    # --- Direct URL override ------------------------------------------------
    if ($Source -and $Source -match '^https?://') {
        return [pscustomobject]@{
            Version     = $null          # unknown until we fetch the file
            Tag         = $null
            Source      = 'direct-url'
            DownloadUrl = $Source
            Notes       = 'Custom -UpdateSource URL'
        }
    }

    $repo = if ($Source -and $Source -match '^[\w\.\-]+/[\w\.\-]+$') { $Source } else { $script:ToolRepo }
    $apiBase = "https://api.github.com/repos/$repo"
    $rawBase = "https://raw.githubusercontent.com/$repo"

    # --- 1) Releases API ------------------------------------------------------
    try {
        Write-Verbose "Querying latest release: $apiBase/releases/latest"
        $release = Invoke-RestMethod -Uri "$apiBase/releases/latest" -Headers $headers -TimeoutSec 20 -ErrorAction Stop
        if ($release -and $release.tag_name) {
            $tag = $release.tag_name -replace '^v', ''
            $ver = $null
            if ([version]::TryParse($tag, [ref]$ver)) {
                # Prefer an explicit script asset; fall back to the tagged raw file.
                $asset = $release.assets | Where-Object { $_.name -eq $script:ToolFileName } | Select-Object -First 1
                $downloadUrl = if ($asset) { $asset.browser_download_url } else { "$rawBase/$($release.tag_name)/$($script:ToolFileName)" }
                return [pscustomobject]@{
                    Version     = $ver
                    Tag         = $release.tag_name
                    Source      = 'release'
                    DownloadUrl = $downloadUrl
                    Notes       = ("Release '{0}' published {1}" -f $release.name, $release.published_at)
                }
            }
            Write-Verbose "Release tag '$tag' is not a parsable version; falling back to raw probe."
        }
    } catch {
        $reason = $_.Exception.Message
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 403) {
            $reason = 'GitHub API rate limit or auth required (HTTP 403)'
        } elseif ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            $reason = 'no published releases (HTTP 404)'
        }
        Write-Verbose "Releases API unavailable ($reason); falling back to raw file probe."
    }

    # --- 2) Raw file probe on default branch ----------------------------------
    $rawUrl = "$rawBase/main/$($script:ToolFileName)"
    return [pscustomobject]@{
        Version     = $null
        Tag         = $null
        Source      = 'raw'
        DownloadUrl = $rawUrl
        Notes       = 'Version will be parsed from the remote script marker'
    }
}

function ConvertTo-ScriptText {
    <#
    .SYNOPSIS
        Normalizes downloaded payloads to a script string.
    .DESCRIPTION
        GitHub serves release assets as application/octet-stream, so in PowerShell 7
        Invoke-WebRequest returns .Content as [byte[]] instead of [string]. Passing that
        byte array to the [string] parameters of the version parser and the validator
        raises a binding error, which aborted -Update with an unhandled script error.
        This converts either shape to text, decodes it as UTF-8 and strips a leading
        byte-order mark (the file is written back with a BOM, so keeping the decoded
        U+FEFF would produce a double mark).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Content
    )

    if ($Content -is [byte[]]) {
        $bytes = $Content
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $bytes = if ($bytes.Length -gt 3) { $bytes[3..($bytes.Length - 1)] } else { @() }
        }
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    } else {
        $text = [string]$Content
    }

    return $text.TrimStart([char]0xFEFF)
}

function Get-VersionFromScriptContent {
    <#
    .SYNOPSIS
        Parses the embedded $script:ToolVersion marker out of downloaded
        script content. Returns [version] or $null.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return $null }
    $m = [regex]::Match($Content, $script:VersionMarkerRegex)
    if ($m.Success) {
        $ver = $null
        if ([version]::TryParse($m.Groups['v'].Value, [ref]$ver)) { return $ver }
    }
    return $null
}

function Invoke-UpdateCheck {
    <#
    .SYNOPSIS
        -CheckUpdate implementation. Compares local vs remote version.
    .OUTPUTS
        Exit code: 0 = up to date or indeterminate, 5 = update available, 6 = check failed.
    #>
    [CmdletBinding()]
    param()

    Show-Section -Title 'UPDATE CHECK' -Icon 'Globe'
    Show-Line -Text ("  Local version : v{0}" -f $script:ToolVersion) -Color 'Info' -Force

    $remote = $null
    try {
        $remote = Get-RemoteToolVersion -Source $UpdateSource
    } catch {
        New-DiagnosticResult -Component 'Update Check' -Status 'FAILED' `
            -Details $_.Exception.Message -Category 'Update' -Severity $script:Severity.Warning
        return $script:ExitCode.UpdateFailed
    }

    if ($null -eq $remote) {
        New-DiagnosticResult -Component 'Update Check' -Status 'NO SOURCE' `
            -Details 'Could not determine an update source.' -Category 'Update' -Severity $script:Severity.Warning
        return $script:ExitCode.UpdateFailed
    }

    $remoteVersion = $remote.Version
    $content = $null

    if ($null -eq $remoteVersion) {
        # Fetch the file to read its version marker.
        try {
            Write-Verbose "Downloading remote script for version probe: $($remote.DownloadUrl)"
            $probeResponse = Invoke-WebRequest -Uri $remote.DownloadUrl -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
            $content = ConvertTo-ScriptText -Content $probeResponse.Content
            $remoteVersion = Get-VersionFromScriptContent -Content $content
        } catch {
            New-DiagnosticResult -Component 'Update Check' -Status 'UNREACHABLE' `
                -Details ("Cannot reach update source: {0}" -f $_.Exception.Message) `
                -Remedy 'Check internet/proxy settings or use -UpdateSource with an internal mirror.' `
                -Category 'Update' -Severity $script:Severity.Warning
            return $script:ExitCode.UpdateFailed
        }
    }

    if ($null -eq $remoteVersion) {
        New-DiagnosticResult -Component 'Update Check' -Status 'UNKNOWN VERSION' `
            -Details 'Remote script does not contain a parsable version marker.' `
            -Category 'Update' -Severity $script:Severity.Warning
        return $script:ExitCode.UpdateFailed
    }

    Show-Line -Text ("  Remote version: v{0}  ({1}: {2})" -f $remoteVersion, $remote.Source, $remote.DownloadUrl) -Color 'Info' -Force

    if ($remoteVersion -gt $script:ToolVersion) {
        New-DiagnosticResult -Component 'Update Check' -Status 'UPDATE AVAILABLE' `
            -Details ("v{0} -> v{1}. {2}" -f $script:ToolVersion, $remoteVersion, $remote.Notes) `
            -Remedy 'Run:  .\RDP-Tool.ps1 -Update   (add -Force to skip confirmation; a timestamped backup is created automatically)' `
            -Category 'Update' -Severity $script:Severity.Warning
        return $script:ExitCode.UpdateAvailable
    }
    elseif ($remoteVersion -eq $script:ToolVersion) {
        New-DiagnosticResult -Component 'Update Check' -Status 'UP TO DATE' `
            -Details ("You are running the latest published version (v{0})." -f $script:ToolVersion) `
            -Category 'Update' -Severity $script:Severity.Info
        return $script:ExitCode.Success
    }
    else {
        New-DiagnosticResult -Component 'Update Check' -Status 'AHEAD OF RELEASE' `
            -Details ("Local v{0} is newer than remote v{1} (dev build or mirrored source)." -f $script:ToolVersion, $remoteVersion) `
            -Category 'Update' -Severity $script:Severity.Info
        return $script:ExitCode.Success
    }
}

function Test-DownloadedScriptIsValid {
    <#
    .SYNOPSIS
        Sanity + syntax validation of a downloaded script before it replaces
        the running tool. Guards against truncated/HTML-error pages and
        syntactically broken downloads.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Content,
        [version] $ExpectedVersion = $null
    )
    if ([string]::IsNullOrWhiteSpace($Content)) { return 'Downloaded content is empty.' }
    if ($Content.Length -lt 20000) { return "Downloaded content too small ($($Content.Length) bytes) - likely an error page." }
    # Only inspect the head: a valid script legitimately embeds HTML report templates later on.
    $head = $Content.Substring(0, [Math]::Min(500, $Content.Length))
    if ($head -match '<\s*(!DOCTYPE|html|HTML)') { return 'Downloaded content looks like an HTML error page, not a PowerShell script.' }

    $parsedVersion = Get-VersionFromScriptContent -Content $Content
    if ($null -eq $parsedVersion) { return 'Version marker ($script:ToolVersion) not found in the downloaded script.' }
    if ($ExpectedVersion -and $parsedVersion -ne $ExpectedVersion) {
        return "Version mismatch: expected $ExpectedVersion, download contains $parsedVersion."
    }

    $tokens = $null; $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        return "PowerShell syntax errors in download ($($parseErrors.Count)); first: $($parseErrors[0].Message)"
    }
    return $null   # valid
}

function Invoke-ToolSelfUpdate {
    <#
    .SYNOPSIS
        -Update implementation: download, validate, back up and replace the
        currently running script file.
    .OUTPUTS
        Exit code: 0 = updated / already latest, 6 = update failed.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()

    Show-Section -Title 'SELF-UPDATE' -Icon 'Globe'

    if (-not $script:IsWindowsOs) {
        New-DiagnosticResult -Component 'Self-Update' -Status 'UNSUPPORTED PLATFORM' `
            -Details 'Self-update is only supported on Windows.' -Category 'Update' -Severity $script:Severity.Error
        return $script:ExitCode.UpdateFailed
    }
    if (-not $PSCommandPath -or -not (Test-Path -LiteralPath $PSCommandPath)) {
        New-DiagnosticResult -Component 'Self-Update' -Status 'NO SCRIPT PATH' `
            -Details 'Cannot determine the on-disk location of the running script (dot-sourced or in-memory invocation).' `
            -Remedy 'Save the script to a .ps1 file and run it from disk.' -Category 'Update' -Severity $script:Severity.Error
        return $script:ExitCode.UpdateFailed
    }

    $remote = Get-RemoteToolVersion -Source $UpdateSource
    if ($null -eq $remote) {
        New-DiagnosticResult -Component 'Self-Update' -Status 'NO SOURCE' -Details 'Update source could not be resolved.' -Category 'Update' -Severity $script:Severity.Error
        return $script:ExitCode.UpdateFailed
    }

    Write-Verbose "Update source: $($remote.Source) -> $($remote.DownloadUrl)"
    Show-Line -Text ("  Source : {0}" -f $remote.DownloadUrl) -Color 'Verbose' -Force

    # --- Download -----------------------------------------------------------
    $content = $null
    try {
        $response = Invoke-WebRequest -Uri $remote.DownloadUrl -TimeoutSec 60 -UseBasicParsing -ErrorAction Stop
        $content = ConvertTo-ScriptText -Content $response.Content
    } catch {
        New-DiagnosticResult -Component 'Self-Update' -Status 'DOWNLOAD FAILED' `
            -Details $_.Exception.Message `
            -Remedy 'Check connectivity/proxy; or download manually from the repository Releases page.' `
            -Category 'Update' -Severity $script:Severity.Error
        return $script:ExitCode.UpdateFailed
    }

    # --- Validate ------------------------------------------------------------
    $remoteVersion = $remote.Version
    if ($null -eq $remoteVersion) { $remoteVersion = Get-VersionFromScriptContent -Content $content }
    $validationError = Test-DownloadedScriptIsValid -Content $content -ExpectedVersion $remoteVersion
    if ($validationError) {
        New-DiagnosticResult -Component 'Self-Update' -Status 'VALIDATION FAILED' `
            -Details $validationError -Category 'Update' -Severity $script:Severity.Error
        return $script:ExitCode.UpdateFailed
    }

    if ($null -ne $remoteVersion -and $remoteVersion -le $script:ToolVersion) {
        New-DiagnosticResult -Component 'Self-Update' -Status 'ALREADY UP TO DATE' `
            -Details ("Local v{0} >= remote v{1}. Nothing to do." -f $script:ToolVersion, $remoteVersion) `
            -Category 'Update' -Severity $script:Severity.Info
        return $script:ExitCode.Success
    }

    # --- Confirm ---------------------------------------------------------------
    $target = $PSCommandPath
    $backupPath = '{0}.bak-{1:yyyyMMdd-HHmmss}' -f $target, [datetime]::Now
    if (-not $PSCmdlet.ShouldProcess($target, "Replace with v$remoteVersion (backup: $(Split-Path $backupPath -Leaf))")) {
        New-RemediationRecord -Action "Self-update to v$remoteVersion" -Success $true -Skipped -Notes 'Skipped by user (-WhatIf/-Confirm)'
        return $script:ExitCode.Success
    }

    # --- Backup ----------------------------------------------------------------
    try {
        Copy-Item -LiteralPath $target -Destination $backupPath -Force -ErrorAction Stop
        Show-Line -Text ("  Backup : {0}" -f $backupPath) -Color 'Verbose' -Force
    } catch {
        # Fall back to TEMP when the script directory is write-protected for backups.
        try {
            $backupPath = Join-Path ([System.IO.Path]::GetTempPath()) (Split-Path $backupPath -Leaf)
            Copy-Item -LiteralPath $target -Destination $backupPath -Force -ErrorAction Stop
            Show-Line -Text ("  Backup : {0} (script dir not writable)" -f $backupPath) -Color 'Warning' -Force
        } catch {
            New-DiagnosticResult -Component 'Self-Update' -Status 'BACKUP FAILED' `
                -Details $_.Exception.Message -Category 'Update' -Severity $script:Severity.Error
            return $script:ExitCode.UpdateFailed
        }
    }

    # --- Atomic replace ----------------------------------------------------------
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("{0}.{1}.tmp" -f $script:ToolFileName, [guid]::NewGuid().ToString('N'))
    try {
        [System.IO.File]::WriteAllText($tempPath, $content, [System.Text.UTF8Encoding]::new($true))
        Move-Item -LiteralPath $tempPath -Destination $target -Force -ErrorAction Stop
    } catch {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        New-DiagnosticResult -Component 'Self-Update' -Status 'REPLACE FAILED' `
            -Details ("{0}. The original file was restored/left untouched; backup at {1}" -f $_.Exception.Message, $backupPath) `
            -Remedy 'If the script lives in Program Files or another protected path, re-run elevated (pwsh -Verb RunAs) or copy the tool to a writable folder.' `
            -Category 'Update' -Severity $script:Severity.Error
        return $script:ExitCode.UpdateFailed
    }

    New-DiagnosticResult -Component 'Self-Update' -Status 'UPDATED' `
        -Details ("v{0} -> v{1}. Backup kept at: {2}" -f $script:ToolVersion, $remoteVersion, $backupPath) `
        -Category 'Update' -Severity $script:Severity.Info
    Show-Line -Text '' -Force
    Show-Line -Text ("  {0} Successfully updated to v{1}. Re-run the tool to use the new version:" -f $script:Icons['Ok'], $remoteVersion) -Color 'Success' -Force
    Show-Line -Text ("      pwsh -NoProfile -File `"{0}`" -Help" -f $target) -Color 'Verbose' -Force
    return $script:ExitCode.Success
}

function Invoke-ElevatedRelaunch {
    <#
    .SYNOPSIS
        -Elevate implementation: re-launches the script elevated with the
        identical argument list (best-effort quoting) and exits.
    #>
    [CmdletBinding()]
    param()
    if ($script:IsAdmin) {
        Show-Line -Text 'Already running elevated; continuing normally.' -Color 'Warning' -Force
        return $false
    }
    if (-not $PSCommandPath) {
        Write-Error '-Elevate requires the script to be run from a file path.'
        return $true
    }

    # Rebuild the argument list from bound parameters.
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.Append("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Key -eq 'Elevate') { continue }
        $value = $kv.Value
        if ($value -is [switch]) {
            if ($value.IsPresent) { $null = $sb.Append(" -$($kv.Key)") }
        } elseif ($value -is [array]) {
            $null = $sb.Append(" -$($kv.Key) $(($value | ForEach-Object { "'$_'" }) -join ',')")
        } else {
            $null = $sb.Append(" -$($kv.Key) `"$value`"")
        }
    }

    $exe = (Get-Process -Id $PID).Path
    if (-not $exe) { $exe = 'pwsh.exe' }
    Show-Line -Text 'Requesting elevation (UAC prompt)...' -Color 'Info' -Force
    Write-Verbose "Relaunch: $exe $sb"
    try {
        Start-Process -FilePath $exe -ArgumentList $sb.ToString() -Verb RunAs -ErrorAction Stop
    } catch {
        Write-Error "Elevation failed or was declined: $($_.Exception.Message)"
        return $true
    }
    return $true
}
#endregion

#region Well-Known Paths & Inventory
# ============================================================================
# Well-known registry paths and system inventory.
# ============================================================================
$script:RegTerminalServer = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$script:RegWinStation = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
$script:RegGpoTerminalServices = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
$script:RegGpoSystem = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$script:SidRemoteDesktopUsers = 'S-1-5-32-555'
$script:SidAdministrators = 'S-1-5-32-544'

function Get-RdpListenerPort {
    <#
    .SYNOPSIS
        Returns the effective RDP listener port: -SetPort when given,
        otherwise the configured registry value, otherwise 3389.
    #>
    [CmdletBinding()]
    param()
    if ($SetPort -gt 0) { return $SetPort }
    $configured = Get-RegistryValue -Path $script:RegWinStation -Name 'PortNumber'
    if ($null -ne $configured -and $configured -ge 1 -and $configured -le 65535) { return [int]$configured }
    return 3389
}

function Test-RdpHostEditionSupported {
    <#
    .SYNOPSIS
        Determines whether this Windows edition can HOST an RDP server.
        Returns @{ Supported = [bool]; Reason = [string] }.
        Correctly rejects ALL Home variants (Core, CoreN, CoreSingleLanguage,
        CoreCountrySpecific) and Windows SE / S-mode SKUs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $EditionID,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Caption,
        [Parameter(Mandatory)][int] $ProductType
    )

    # Servers and domain controllers always support the RDP host role.
    if ($ProductType -ne 1) {
        return @{ Supported = $true; Reason = 'Windows Server / Domain Controller product type supports RDP hosting' }
    }

    $supportedEditions = @(
        'Professional', 'ProfessionalN',
        'ProfessionalEducation', 'ProfessionalEducationN',
        'ProfessionalWorkstation', 'ProfessionalWorkstationN',
        'Enterprise', 'EnterpriseN', 'EnterpriseS', 'EnterpriseSN',
        'EnterpriseG', 'EnterpriseGN',
        'Education', 'EducationN',
        'IoTEnterprise', 'IoTEnterpriseS', 'IoTEnterpriseSK',
        'ServerRdsh'   # Windows Enterprise multi-session (AVD)
    )
    $unsupportedEditions = @(
        'Core', 'CoreN', 'CoreSingleLanguage', 'CoreCountrySpecific',
        'Cloud', 'CloudN', 'CloudE', 'CloudEdition', 'CloudEditionN',
        'Starter', 'HomeBasic', 'HomePremium', 'HomeServer'
    )

    if ($EditionID -and ($supportedEditions -contains $EditionID)) {
        return @{ Supported = $true; Reason = "Edition '$EditionID' supports the RDP server role" }
    }
    if ($EditionID -and ($unsupportedEditions -contains $EditionID)) {
        return @{ Supported = $false; Reason = "Edition '$EditionID' (Windows Home/SE family) cannot accept incoming RDP connections - Microsoft licensing restriction" }
    }
    if ($Caption -match '\bHome\b|Windows 11 SE|Single Language') {
        return @{ Supported = $false; Reason = "Caption '$Caption' indicates a Home/SE edition without RDP server support" }
    }
    if ($Caption -match 'Pro|Enterprise|Education|Server') {
        return @{ Supported = $true; Reason = "Caption '$Caption' matches an RDP-capable edition family" }
    }
    return @{ Supported = $false; Reason = "Unrecognized edition '$EditionID' / '$Caption'; assuming no RDP host support (report to GitHub if this is wrong)" }
}

function Get-SystemInventory {
    <#
    .SYNOPSIS
        Collects OS/hardware/network inventory into $script:SystemInfo and
        renders the system information block.
    #>
    [CmdletBinding()]
    param()

    $script:SystemInfo = [ordered]@{
        ComputerName    = $env:COMPUTERNAME
        Caption         = ''; EditionID = ''; Build = ''; Architecture = ''
        ProductType     = 1; InstallDate = $null; LastBoot = $null
        Manufacturer    = ''; Model = ''
        RDPSupported    = $false; RdpSupportReason = ''
        CurrentUser     = ''; CurrentUserSid = ''
        IsRemoteSession = $false; IsVirtualMachine = $false
        IPv4Addresses   = @(); Domain = ''
    }

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $script:SystemInfo.Caption = $os.Caption
        $script:SystemInfo.Architecture = $os.OSArchitecture
        $script:SystemInfo.ProductType = [int]$os.ProductType
        $script:SystemInfo.InstallDate = $os.InstallDate
        $script:SystemInfo.LastBoot = $os.LastBootUpTime

        $ubr = Get-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'UBR'
        $script:SystemInfo.Build = ('{0}.{1}' -f $os.BuildNumber, $(if ($null -ne $ubr) { $ubr } else { '0' }))
        $script:SystemInfo.EditionID = [string](Get-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID')

        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs) {
            $script:SystemInfo.Manufacturer = $cs.Manufacturer
            $script:SystemInfo.Model = $cs.Model
            $script:SystemInfo.Domain = if ($cs.PartOfDomain) { $cs.Domain } else { "(workgroup: $($cs.Workgroup))" }
            $script:SystemInfo.IsVirtualMachine = [bool]($cs.Model -match 'Virtual|VMware|VirtualBox|KVM|QEMU|Hyper-V|Parallels|Xen')
        }

        $support = Test-RdpHostEditionSupported -EditionID $script:SystemInfo.EditionID -Caption $script:SystemInfo.Caption -ProductType $script:SystemInfo.ProductType
        $script:SystemInfo.RDPSupported = $support.Supported
        $script:SystemInfo.RdpSupportReason = $support.Reason
    } catch {
        New-DiagnosticResult -Component 'System Inventory' -Status 'FAILED' `
            -Details ("WMI/CIM query failed: {0}" -f $_.Exception.Message) `
            -Remedy 'Ensure the Winmgmt service is running (Start-Service Winmgmt) and retry.' `
            -Category 'Prerequisites' -Severity $script:Severity.Error
    }

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $script:SystemInfo.CurrentUser = $identity.Name
        $script:SystemInfo.CurrentUserSid = $identity.User.Value
        $script:SystemInfo.IsRemoteSession = $script:IsRemoteSession
    } catch {
        Write-Verbose "User identity probe failed: $($_.Exception.Message)"
    }

    try {
        $script:SystemInfo.IPv4Addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
            Select-Object -ExpandProperty IPAddress)
    } catch {
        Write-Verbose "IPv4 enumeration failed: $($_.Exception.Message)"
    }

    Show-KeyValuePair -Key 'Computer' -Value ("{0} {1}" -f $script:SystemInfo.ComputerName, $script:SystemInfo.Domain) -Color 'Info'
    Show-KeyValuePair -Key 'Operating System' -Value $script:SystemInfo.Caption
    Show-KeyValuePair -Key 'Edition / Build' -Value ("{0} / {1} ({2})" -f $script:SystemInfo.EditionID, $script:SystemInfo.Build, $script:SystemInfo.Architecture)
    Show-KeyValuePair -Key 'Hardware' -Value ("{0} {1}{2}" -f $script:SystemInfo.Manufacturer, $script:SystemInfo.Model, $(if ($script:SystemInfo.IsVirtualMachine) { ' [VM]' } else { '' }))
    Show-KeyValuePair -Key 'Last boot' -Value $(if ($script:SystemInfo.LastBoot) { '{0:yyyy-MM-dd HH:mm:ss}' -f $script:SystemInfo.LastBoot } else { 'unknown' })
    Show-KeyValuePair -Key 'Current user' -Value ("{0} (elevated: {1}, remote session: {2})" -f $script:SystemInfo.CurrentUser, $script:IsAdmin, $script:IsRemoteSession)
    $supportColor = if ($script:SystemInfo.RDPSupported) { 'Success' } else { 'Error' }
    Show-KeyValuePair -Key 'RDP host support' -Value ("{0} {1}" -f $(if ($script:SystemInfo.RDPSupported) { $script:Icons['Ok'] } else { $script:Icons['Err'] }), $script:SystemInfo.RdpSupportReason) -Color $supportColor
    if ($script:SystemInfo.IPv4Addresses.Count -gt 0) {
        Show-KeyValuePair -Key 'IPv4 addresses' -Value ($script:SystemInfo.IPv4Addresses -join ', ')
    }
}
#endregion

#region Check: Prerequisites
# ============================================================================
# Prerequisite checks: elevation, OS support, pending reboot, RDP binaries.
# ============================================================================
function Test-AdminPrivileges {
    [CmdletBinding()]
    param()
    if ($script:IsAdmin) {
        New-DiagnosticResult -Component 'Administrative privileges' -Status 'ELEVATED' `
            -Details 'Running with an administrator token; all checks and repairs available.' `
            -Category 'Prerequisites' -Severity $script:Severity.Info
    } else {
        $requestedActions = @(Get-RequestedActionList)
        if ($requestedActions.Count -gt 0 -or $Update) {
            $relaunchArgs = ($requestedActions | ForEach-Object { "-$_" }) -join ' '
            New-DiagnosticResult -Component 'Administrative privileges' -Status 'ELEVATION REQUIRED' `
                -Details ("Actions [{0}] modify the system and require an elevated session." -f ($requestedActions -join ', ')) `
                -Remedy ("Re-run elevated, e.g.:  Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile -File `"{0}`" {1}'   (or simply add -Elevate to auto-relaunch)" -f $PSCommandPath, $relaunchArgs) `
                -Category 'Prerequisites' -Severity $script:Severity.Critical
            return $false
        }
        New-DiagnosticResult -Component 'Administrative privileges' -Status 'NOT ELEVATED (read-only mode)' `
            -Details 'Diagnostics continue with reduced coverage (some registry keys, firewall internals and event logs may be unreadable). Remediation requires elevation.' `
            -Remedy 'For the full audit + repair experience run:  .\RDP-Tool.ps1 -Elevate -EnableRDP' `
            -Category 'Prerequisites' -Severity $script:Severity.Warning
    }
    return $true
}

function Test-PendingRebootState {
    [CmdletBinding()]
    param()
    if ($SkipRebootCheck) {
        Write-Verbose 'Pending reboot check skipped (-SkipRebootCheck).'
        return
    }

    $reasons = [System.Collections.Generic.List[string]]::new()

    # Key-presence indicators.
    $keyIndicators = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'; Reason = 'Component-Based Servicing' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress'; Reason = 'CBS reboot in progress' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; Reason = 'Windows Update' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting'; Reason = 'Windows Update post-reboot reporting' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts'; Reason = 'Server Manager' }
    )
    foreach ($ind in $keyIndicators) {
        if (Test-Path -Path $ind.Path) { $reasons.Add($ind.Reason) }
    }

    # Non-empty value indicators (fixed: v4 checked these as registry KEYS, so they never matched).
    $valueIndicators = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Name = 'PendingFileRenameOperations'; Reason = 'Pending file rename operations' },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Name = 'SetupExecute'; Reason = 'SetupExecute pending' }
    )
    foreach ($ind in $valueIndicators) {
        $value = Get-RegistryValue -Path $ind.Path -Name $ind.Name
        if ($null -ne $value -and ("$value").Trim() -ne '' -and ("$value") -ne '0') { $reasons.Add($ind.Reason) }
    }

    # Optional (slow) DISM scan - read-only probe.
    if (-not $SkipSlowChecks -and $script:IsAdmin) {
        try {
            Write-Verbose 'Running DISM pending-change probe (skip with -SkipSlowChecks)...'
            $dismInfo = & dism.exe /Online /Get-Packages 2>&1 | Where-Object { $_ -match 'Install Pending|Pending online image change' }
            if ($dismInfo) { $reasons.Add('DISM package changes pending') }
        } catch {
            Write-Verbose "DISM probe skipped: $($_.Exception.Message)"
        }
    }

    if ($reasons.Count -gt 0) {
        New-DiagnosticResult -Component 'Pending reboot' -Status 'REBOOT REQUIRED' `
            -Details ("Indicators: {0}" -f (($reasons | Select-Object -Unique) -join '; ')) `
            -Remedy 'Restart the machine, then re-run the tool. Configuration changes (port, services, features) may not fully apply until reboot.' `
            -Category 'Prerequisites' -Severity $script:Severity.Warning
    } else {
        New-DiagnosticResult -Component 'Pending reboot' -Status 'NONE DETECTED' `
            -Details 'No pending-reboot indicators found.' -Category 'Prerequisites' -Severity $script:Severity.Info
    }
}

function Test-RdpBinaries {
    [CmdletBinding()]
    param()
    $sys32 = [Environment]::GetFolderPath('System')
    $required = @('termsrv.dll', 'rdpcorets.dll', 'rdpudd.dll', 'rdpbase.dll', 'rdpinput.exe')
    $optional = @('rdpclip.exe', 'rdpshell.exe', 'rdinit.exe')
    $missing = [System.Collections.Generic.List[string]]::new()
    $present = [System.Collections.Generic.List[string]]::new()

    foreach ($f in $required) {
        $path = Join-Path $sys32 $f
        if (Test-Path -LiteralPath $path) { $present.Add($f) } else { $missing.Add($f) }
    }
    foreach ($f in $optional) {
        $path = Join-Path $sys32 $f
        if (-not (Test-Path -LiteralPath $path)) { Write-Verbose "Optional RDP component not found: $f" }
    }

    $termsrvPath = Join-Path $sys32 'termsrv.dll'
    $termsrvVersion = if (Test-Path -LiteralPath $termsrvPath) { (Get-Item -LiteralPath $termsrvPath).VersionInfo.FileVersion } else { 'n/a' }
    $mstscPath = Join-Path $sys32 'mstsc.exe'
    $mstscPresent = Test-Path -LiteralPath $mstscPath

    if ($missing.Count -eq 0) {
        New-DiagnosticResult -Component 'RDP binaries' -Status 'COMPLETE' `
            -Details ("termsrv.dll v{0}; {1}/{2} required components present; RDP client (mstsc.exe): {3}" -f $termsrvVersion, $present.Count, $required.Count, $(if ($mstscPresent) { 'yes' } else { 'MISSING' })) `
            -Category 'Capability' -Severity $script:Severity.Info
    } else {
        New-DiagnosticResult -Component 'RDP binaries' -Status 'INCOMPLETE' `
            -Details ("Missing: {0}" -f ($missing -join ', ')) `
            -Remedy "Run 'sfc /scannow' then 'DISM /Online /Cleanup-Image /RestoreHealth' as Administrator; a repair upgrade fixes persistent cases." `
            -Category 'Capability' -Severity $script:Severity.Error
    }
}

function Test-RdpWindowsFeature {
    <#
    .SYNOPSIS
        Client SKUs do not expose a 'RemoteDesktop-Server' optional feature
        (v4 used Enable-WindowsOptionalFeature for it, which fails on
        Win10/11). Verify the feature only on Server SKUs; on clients,
        capability is proven by binaries + service presence instead.
    #>
    [CmdletBinding()]
    param()
    if ($script:SystemInfo.ProductType -eq 1) {
        Write-Verbose 'Client SKU: RDP server is built into the OS; no optional feature to check.'
        return
    }
    try {
        $rdpFeature = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue |
                      Where-Object { $_.FeatureName -match 'RemoteDesktop|Terminal' }
        if ($rdpFeature) {
            $disabled = @($rdpFeature | Where-Object { $_.State -ne 'Enabled' })
            if ($disabled.Count -eq 0) {
                New-DiagnosticResult -Component 'RDP server feature' -Status 'ENABLED' `
                    -Details ("Server feature state OK ({0} related feature(s) enabled)" -f @($rdpFeature).Count) `
                    -Category 'Capability' -Severity $script:Severity.Info
            } else {
                New-DiagnosticResult -Component 'RDP server feature' -Status 'PARTIALLY DISABLED' `
                    -Details ("Disabled: {0}" -f (($disabled | Select-Object -ExpandProperty FeatureName) -join ', ')) `
                    -Remedy 'Install-WindowsFeature RDS-RD-Server (Server Core/GUI) or enable via Server Manager.' `
                    -Category 'Capability' -Severity $script:Severity.Warning
            }
        } else {
            Write-Verbose 'No RDP-related optional features reported; skipping.'
        }
    } catch {
        Write-Verbose "Optional feature check unavailable: $($_.Exception.Message)"
    }
}
#endregion

#region Check: Registry Configuration (+ GPO overlay)
# ============================================================================
# Data-driven registry audit. Each entry has a uniform shape (StrictMode-safe).
# GPO-managed values are detected and reported instead of being "repaired"
# locally (local changes are overridden by policy and would mislead the user).
# ============================================================================
function Get-RdpRegistryChecks {
    [CmdletBinding()]
    param()
    $expectedNla = if ($DisableNLA) { 0 } else { 1 }
    $expectedPort = Get-RdpListenerPort

    @(
        [pscustomobject]@{ Path = $script:RegTerminalServer; Name = 'fDenyTSConnections'; Desc = 'RDP connections allowed (fDenyTSConnections)'; Cat = 'Core'
            Expected = @($(if ($DisableRDP) { 1 } else { 0 })); Default = 1; Sev = $script:Severity.Error; InfoOnly = $false
            Hint = $(if ($DisableRDP) { 'Requested state: RDP disabled (fDenyTSConnections=1).' } else { 'Enable RDP:  .\RDP-Tool.ps1 -EnableRDP   (sets fDenyTSConnections=0, starts services, opens firewall)' }) }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'fEnableWinStation'; Desc = 'RDP listener enabled (fEnableWinStation)'; Cat = 'Core'
            Expected = @(1); Default = 1; Sev = $script:Severity.Error; InfoOnly = $false
            Hint = 'Run with -EnableRDP to re-enable the RDP-Tcp listener.' }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'PortNumber'; Desc = "Listener port (PortNumber; requested: $(if ($SetPort -gt 0) { $SetPort } else { 'default' }))"; Cat = 'Network'
            Expected = @($expectedPort); Default = 3389; Sev = $script:Severity.Error; InfoOnly = $false
            Hint = "Apply with:  .\RDP-Tool.ps1 -SetPort $expectedPort -EnableRDP" }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'UserAuthentication'; Desc = 'Network Level Authentication (UserAuthentication)'; Cat = 'Security'
            Expected = @($expectedNla); Default = 1; Sev = $script:Severity.Warning; InfoOnly = $false
            Hint = 'Recommended: NLA enabled (=1). Apply:  .\RDP-Tool.ps1 -EnableRDP   (or -DisableNLA to force 0 - insecure!)' }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'SecurityLayer'; Desc = 'Security layer (2=Negotiate)'; Cat = 'Security'
            Expected = @(2); Default = 2; Sev = $script:Severity.Warning; InfoOnly = $false
            Hint = 'Set SecurityLayer=2 (Negotiate) - required for TLS/CredSSP selection.' }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'MinEncryptionLevel'; Desc = 'Minimum encryption level (3=High, 4=FIPS)'; Cat = 'Security'
            Expected = @(3, 4); Default = 3; Sev = $script:Severity.Warning; InfoOnly = $false
            Hint = 'Set MinEncryptionLevel=3 (High). Levels 1/2 use legacy RC4 and are vulnerable.' }
        [pscustomobject]@{ Path = $script:RegTerminalServer; Name = 'fSingleSessionPerUser'; Desc = 'Single session per user (fSingleSessionPerUser)'; Cat = 'Session'
            Expected = $null; Default = 1; Sev = $script:Severity.Info; InfoOnly = $true
            Hint = 'Client Windows allows ONE concurrent session per user by design (licensing). Reported for information only - the tool deliberately does not patch this.' }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'SelectTransport'; Desc = 'Transport selection (0=TCP+UDP, 1=TCP only, 2=UDP only)'; Cat = 'Network'
            Expected = $null; Default = 0; Sev = $script:Severity.Info; InfoOnly = $true
            Hint = 'UDP improves latency on good links; set 1 (TCP only) to force TCP through UDP-hostile networks.' }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'MaxIdleTime'; Desc = 'Max idle time, ms (0=never)'; Cat = 'Session'
            Expected = $null; Default = 0; Sev = $script:Severity.Info; InfoOnly = $true
            Hint = 'Idle-limit policy; 0 means sessions are kept forever (fine for workstations).' }
        [pscustomobject]@{ Path = $script:RegWinStation; Name = 'MaxDisconnectionTime'; Desc = 'Max disconnection time, ms (0=never)'; Cat = 'Session'
            Expected = $null; Default = 0; Sev = $script:Severity.Info; InfoOnly = $true
            Hint = 'How long a disconnected session is preserved before logoff.' }
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'LimitBlankPasswordUse'; Desc = 'Blank-password accounts blocked from network/RDP logon'; Cat = 'Security'
            Expected = @(1); Default = 1; Sev = $script:Severity.Warning; InfoOnly = $false
            Hint = 'Accounts with empty passwords CANNOT use RDP while LimitBlankPasswordUse=1 (secure default). Set a password for the account instead of weakening this policy.' }
    )
}

function Test-RdpRegistrySettings {
    [CmdletBinding()]
    param()
    Show-Section -Title 'REGISTRY CONFIGURATION' -Subtitle 'Local WinStations/Terminal Server values with Group Policy overlay detection' -Icon 'Gear'

    foreach ($check in Get-RdpRegistryChecks) {
        $localValue = Get-RegistryValue -Path $check.Path -Name $check.Name
        $gpoValue = Get-RegistryValue -Path $script:RegGpoTerminalServices -Name $check.Name

        # GPO also manages some values under different names - handle the NLA policy alias.
        if ($null -eq $gpoValue -and $check.Name -eq 'UserAuthentication') {
            $gpoValue = Get-RegistryValue -Path $script:RegGpoTerminalServices -Name 'UserAuthentication'
        }

        $effective = if ($null -ne $gpoValue) { $gpoValue } elseif ($null -ne $localValue) { $localValue } else { $check.Default }

        if ($null -ne $gpoValue) {
            $matchesPolicyExpectation = ($null -eq $check.Expected) -or ($gpoValue -in $check.Expected)
            $sev = if ($matchesPolicyExpectation) { $script:Severity.Info } else { $script:Severity.Warning }
            New-DiagnosticResult -Component $check.Desc -Status 'MANAGED BY GROUP POLICY' `
                -Details ("Policy value: {0} | Local value: {1}. GPO wins - local changes will NOT take effect." -f $gpoValue, $(if ($null -ne $localValue) { $localValue } else { '<not set>' })) `
                -Remedy ("Adjust the policy (gpedit.msc / domain GPO: Computer Configuration -> Administrative Templates -> Windows Components -> Remote Desktop Services), then run 'gpupdate /force'. Hint: {0}" -f $check.Hint) `
                -Category $check.Cat -Severity $sev
            continue
        }

        if ($check.InfoOnly -or $null -eq $check.Expected) {
            New-DiagnosticResult -Component $check.Desc -Status $(if ($null -ne $localValue) { "VALUE = $effective" } else { "DEFAULT = $effective" }) `
                -Details $check.Hint -Category $check.Cat -Severity $script:Severity.Info
            continue
        }

        if ($effective -in $check.Expected) {
            $origin = if ($null -ne $localValue) { 'configured' } else { 'default' }
            New-DiagnosticResult -Component $check.Desc -Status "OK ($origin value: $effective)" `
                -Category $check.Cat -Severity $script:Severity.Info
        } else {
            New-DiagnosticResult -Component $check.Desc -Status 'MISCONFIGURED' `
                -Details ("Current: {0} | Expected: {1}" -f $effective, ($check.Expected -join ' or ')) `
                -Remedy $check.Hint -Category $check.Cat -Severity $check.Sev
        }
    }
}

function Test-RdpGroupPolicyOverview {
    [CmdletBinding()]
    param()
    Show-Section -Title 'GROUP POLICY OVERVIEW' -Subtitle 'RDP-relevant policies applied to this machine' -Icon 'Lock'

    $gpoLocations = @(
        @{ Path = $script:RegGpoTerminalServices; Label = 'Terminal Services policies' },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client'; Label = 'RDP client policies' },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'; Label = 'Credential delegation policies' }
    )

    $anyFound = $false
    foreach ($loc in $gpoLocations) {
        if (-not (Test-Path -Path $loc.Path)) { continue }
        $values = @{}
        try {
            $props = Get-ItemProperty -Path $loc.Path -ErrorAction SilentlyContinue
            if ($props) {
                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$') { $values[$p.Name] = $p.Value }
                }
            }
        } catch {
            Write-Verbose "Policy enumeration failed for $($loc.Path): $($_.Exception.Message)"
        }
        if ($values.Count -eq 0) { continue }

        $anyFound = $true
        New-DiagnosticResult -Component $loc.Label -Status "$($values.Count) VALUE(S) SET" `
            -Details (($values.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join '; ') `
            -Remedy 'Policies override local settings. Review in gpedit.msc under Remote Desktop Services / Remote Desktop Connection Client.' `
            -Category 'Security' -Severity $script:Severity.Info

        # Flag risky policy combinations explicitly.
        if ($values.ContainsKey('fDenyTSConnections') -and "$($values['fDenyTSConnections'])" -eq '1') {
            New-DiagnosticResult -Component 'Policy: Allow remote connections' -Status 'DENIED BY GPO' `
                -Details 'Group Policy explicitly disables inbound RDP (fDenyTSConnections=1). No local fix can override this.' `
                -Remedy 'Change "Allow users to connect remotely using RDP" to Enabled in the applied GPO, then gpupdate /force.' `
                -Category 'Security' -Severity $script:Severity.Error
        }
        if ($values.ContainsKey('UserAuthentication') -and "$($values['UserAuthentication'])" -eq '0') {
            New-DiagnosticResult -Component 'Policy: NLA requirement' -Status 'NLA DISABLED BY GPO' `
                -Details 'Group Policy turns off the NLA requirement for remote connections.' `
                -Remedy 'Enable "Require user authentication for remote connections by using NLA" in the applied GPO.' `
                -Category 'Security' -Severity $script:Severity.Warning
        }
        if ($values.ContainsKey('SecurityLayer') -and "$($values['SecurityLayer'])" -eq '0') {
            New-DiagnosticResult -Component 'Policy: Security layer' -Status 'LEGACY RDP SECURITY BY GPO' `
                -Details 'SecurityLayer=0 forces legacy RDP native encryption (no TLS).' `
                -Remedy 'Set the policy to Negotiate (2) or SSL/TLS (1).' `
                -Category 'Security' -Severity $script:Severity.Warning
        }
    }

    # RDP client-side credential delegation (CredSSP) - relevant for outbound RDP + NLA.
    $credDeleg = Get-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation' -Name 'AllowDefaultCredentials'
    if ($null -ne $credDeleg) {
        New-DiagnosticResult -Component 'Policy: CredSSP delegation' -Status "AllowDefaultCredentials=$credDeleg" `
            -Details 'Controls whether the RDP client may delegate default credentials (CredSSP).' `
            -Category 'Security' -Severity $script:Severity.Info
    }

    if (-not $anyFound) {
        New-DiagnosticResult -Component 'Group Policy' -Status 'NO RDP POLICIES APPLIED' `
            -Details 'Local configuration is authoritative (no HKLM policy overrides detected).' `
            -Category 'Security' -Severity $script:Severity.Info
    }
}
#endregion

#region Check: Services
# ============================================================================
# RDP service stack with dependency awareness. TermService is Manual with a
# service trigger by design on Win10/11 - v4 wrongly required "Automatic".
# ============================================================================
function Get-RdpServiceDefinitions {
    [CmdletBinding()]
    param()
    @(
        [pscustomobject]@{ Name = 'TermService'; Role = 'Remote Desktop Services (RDP listener host)'; Critical = $true; Deps = @('RpcSs', 'RpcEptMapper') }
        [pscustomobject]@{ Name = 'UmRdpService'; Role = 'RDP UserMode Port Redirector (USB/COM/LPT redirection)'; Critical = $false; Deps = @('TermService') }
        [pscustomobject]@{ Name = 'SessionEnv'; Role = 'Remote Desktop Configuration (session management)'; Critical = $false; Deps = @('RpcSs') }
        [pscustomobject]@{ Name = 'RpcSs'; Role = 'RPC (foundation dependency)'; Critical = $true; Deps = @('RpcEptMapper') }
        [pscustomobject]@{ Name = 'RpcEptMapper'; Role = 'RPC Endpoint Mapper'; Critical = $true; Deps = @() }
        [pscustomobject]@{ Name = 'Audiosrv'; Role = 'Windows Audio (audio redirection)'; Critical = $false; Deps = @('AudioEndpointBuilder') }
        [pscustomobject]@{ Name = 'AudioEndpointBuilder'; Role = 'Audio Endpoint Builder'; Critical = $false; Deps = @() }
    )
}

function Test-RdpServices {
    [CmdletBinding()]
    param()
    Show-Section -Title 'SERVICE STACK' -Subtitle 'TermService and dependencies (trigger-start aware)' -Icon 'Gear'

    $rdpEnabled = (Get-RegistryValue -Path $script:RegTerminalServer -Name 'fDenyTSConnections') -eq 0
    $serviceSnapshot = @{}

    foreach ($def in Get-RdpServiceDefinitions) {
        $svc = Get-Service -Name $def.Name -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            $sev = if ($def.Critical) { $script:Severity.Error } else { $script:Severity.Warning }
            New-DiagnosticResult -Component "Service $($def.Name)" -Status 'NOT INSTALLED' `
                -Details "$($def.Role) is missing from this system." `
                -Remedy $(if ($def.Name -eq 'TermService') { 'Repair Windows: DISM /Online /Cleanup-Image /RestoreHealth  then  sfc /scannow' } else { 'Reinstall/repair Windows components; optional on client SKUs.' }) `
                -Category 'Services' -Severity $sev
            $serviceSnapshot[$def.Name] = $null
            continue
        }
        $serviceSnapshot[$def.Name] = $svc

        $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($def.Name)'" -ErrorAction SilentlyContinue
        $startMode = if ($cim) { $cim.StartMode } else { 'Unknown' }
        $isDisabled = $svc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled
        $isRunning = $svc.Status -eq 'Running'

        # Dependency health
        $brokenDeps = @()
        foreach ($dep in $def.Deps) {
            $depSvc = Get-Service -Name $dep -ErrorAction SilentlyContinue
            if ($null -eq $depSvc -or $depSvc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) { $brokenDeps += $dep }
        }

        $detail = "State: $($svc.Status) | StartType: $($svc.StartType) (SCM StartMode: $startMode)"
        if ($brokenDeps.Count -gt 0) { $detail += " | Broken dependencies: $($brokenDeps -join ', ')" }

        if ($isDisabled) {
            $sev = if ($def.Critical) { $script:Severity.Error } else { $script:Severity.Warning }
            New-DiagnosticResult -Component "Service $($def.Name)" -Status 'DISABLED' -Details $detail `
                -Remedy "Set-Service -Name '$($def.Name)' -StartupType Manual; Start-Service -Name '$($def.Name)'   (or run with -EnableRDP)" `
                -Category 'Services' -Severity $sev
        }
        elseif ($brokenDeps.Count -gt 0) {
            New-DiagnosticResult -Component "Service $($def.Name)" -Status 'DEPENDENCY ISSUE' -Details $detail `
                -Remedy "Repair dependency service(s): $($brokenDeps -join ', ') (or run with -EnableRDP)." `
                -Category 'Services' -Severity $script:Severity.Error
        }
        elseif ($def.Name -eq 'TermService') {
            if ($isRunning) {
                New-DiagnosticResult -Component "Service $($def.Name)" -Status 'RUNNING' -Details "$detail | Listener host active." -Category 'Services' -Severity $script:Severity.Info
            } elseif ($rdpEnabled) {
                New-DiagnosticResult -Component "Service $($def.Name)" -Status 'NOT RUNNING (RDP ENABLED)' -Details "$detail | RDP is enabled but the listener host is stopped - connections will fail." `
                    -Remedy 'Start-Service TermService   (or run with -EnableRDP / -RestartServices)' `
                    -Category 'Services' -Severity $script:Severity.Error
            } else {
                New-DiagnosticResult -Component "Service $($def.Name)" -Status 'STOPPED (RDP DISABLED - normal)' -Details "$detail | Manual trigger-start service; starts automatically when RDP is enabled." -Category 'Services' -Severity $script:Severity.Info
            }
        }
        else {
            $status = if ($isRunning) { 'RUNNING' } else { 'STOPPED (on-demand - normal)' }
            $sev = $script:Severity.Info
            New-DiagnosticResult -Component "Service $($def.Name)" -Status $status -Details $detail -Category 'Services' -Severity $sev
        }
    }

    # Cross-check with the Terminal Services WMI namespace when available.
    try {
        $tsSetting = Get-CimInstance -Namespace 'root\cimv2\terminalservices' -ClassName Win32_TerminalServiceSetting -ErrorAction Stop
        New-DiagnosticResult -Component 'WMI listener setting' -Status "AllowTSConnections=$($tsSetting.AllowTSConnections)" `
            -Details ("0=deny, 1=allow connections, 2=allow + no re-announce. RequireEncryption={0}" -f $tsSetting.RequireEncryption) `
            -Category 'Services' -Severity $script:Severity.Info
        Write-Verbose "Win32_TerminalServiceSetting: AllowTSConnections=$($tsSetting.AllowTSConnections)"
    } catch {
        Write-Verbose "Terminal Services WMI namespace unavailable: $($_.Exception.Message)"
    }

    return $serviceSnapshot
}
#endregion

#region Check: Firewall
# ============================================================================
# Windows Defender Firewall: profiles, RDP rule sets (language-independent
# matching by rule Name + port filter), blocking rules. v4 matched rules by a
# LocalPort property that Get-NetFirewallRule does not expose - fixed via
# Get-NetFirewallPortFilter association.
# ============================================================================
$script:WellKnownRdpRuleNames = @(
    'RemoteDesktop-UserMode-In-TCP',
    'RemoteDesktop-UserMode-In-UDP',
    'RemoteDesktop-Shadow-In-TCP',
    'RemoteDesktop-In-TCP'
)

function Get-RdpFirewallRules {
    <#
    .SYNOPSIS
        Collects firewall rules relevant to RDP: well-known built-in rules
        (by language-independent Name), rules in the localized "Remote
        Desktop" display group, and custom rules matching the RDP port via
        port-filter association.
    .OUTPUTS
        @{ All = rules; Enabled = rules; Disabled = rules; Blocking = rules; PublicProfileGap = bool }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $Port)

    $result = @{ All = @(); Enabled = @(); Disabled = @(); Blocking = @(); PublicProfileGap = $false }

    $allRules = @(Get-NetFirewallRule -ErrorAction SilentlyContinue)
    if ($allRules.Count -eq 0) {
        Write-Verbose 'Get-NetFirewallRule returned nothing (firewall API unavailable?)'
        return $result
    }

    # 1) Well-known RDP rules by internal Name (language independent).
    $rdpRules = @($allRules | Where-Object { $script:WellKnownRdpRuleNames -contains $_.Name })

    # 2) Anything else in the same (localized) display group as the known TCP rule.
    $knownTcpRule = $rdpRules | Where-Object { $_.Name -eq 'RemoteDesktop-UserMode-In-TCP' } | Select-Object -First 1
    if ($knownTcpRule -and $knownTcpRule.DisplayGroup) {
        $rdpRules += @($allRules | Where-Object { $_.DisplayGroup -eq $knownTcpRule.DisplayGroup })
    }

    # 3) Custom rules matching the RDP port (skipped with -SkipSlowChecks).
    if (-not $SkipSlowChecks) {
        try {
            $portFilters = @(Get-NetFirewallPortFilter -ErrorAction Stop | Where-Object { $_.LocalPort -contains "$Port" })
            if ($portFilters.Count -gt 0) {
                $portRules = @($portFilters | Get-NetFirewallRule -ErrorAction SilentlyContinue)
                $rdpRules += $portRules
            }
        } catch {
            Write-Verbose "Port-filter enumeration failed: $($_.Exception.Message)"
        }
    }

    $rdpRules = @($rdpRules | Sort-Object -Property Name -Unique)
    $inbound = @($rdpRules | Where-Object { $_.Direction -eq 'Inbound' })

    $result.All = $inbound
    $result.Enabled = @($inbound | Where-Object { $_.Enabled -eq $true -and $_.Action -eq 'Allow' })
    $result.Disabled = @($inbound | Where-Object { $_.Enabled -ne $true })
    $result.Blocking = @($inbound | Where-Object { $_.Action -eq 'Block' })

    # Public-profile gap: enabled allow-rules exist but none covers the Public profile.
    if ($result.Enabled.Count -gt 0) {
        $coversPublic = $false
        foreach ($r in $result.Enabled) {
            if ("$($r.Profile)" -match 'Any|Public') { $coversPublic = $true; break }
        }
        $publicProfiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq 'Public' })
        $result.PublicProfileGap = (-not $coversPublic) -and ($publicProfiles.Count -gt 0)
    }

    return $result
}

function Test-FirewallConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $Port)
    Show-Section -Title 'WINDOWS FIREWALL' -Subtitle "Profiles and RDP rules for port $Port" -Icon 'Lock'

    # Firewall service
    $mps = Get-Service -Name 'MpsSvc' -ErrorAction SilentlyContinue
    if ($mps -and $mps.Status -eq 'Running') {
        New-DiagnosticResult -Component 'Firewall service (MpsSvc)' -Status 'RUNNING' -Category 'Firewall' -Severity $script:Severity.Info
    } elseif ($mps) {
        New-DiagnosticResult -Component 'Firewall service (MpsSvc)' -Status 'NOT RUNNING' `
            -Details 'Windows Defender Firewall service is stopped. Third-party AV may have replaced it - verify there IS an active firewall.' `
            -Remedy 'Start-Service MpsSvc (if no third-party firewall manages the system).' `
            -Category 'Firewall' -Severity $script:Severity.Warning
    } else {
        New-DiagnosticResult -Component 'Firewall service (MpsSvc)' -Status 'NOT FOUND' `
            -Details 'MpsSvc service is missing.' -Category 'Firewall' -Severity $script:Severity.Warning
    }

    # Profiles
    try {
        foreach ($profileName in @('Domain', 'Private', 'Public')) {
            $p = Get-NetFirewallProfile -Name $profileName -ErrorAction Stop
            $enabledText = if ($p.Enabled) { 'ENABLED' } else { 'DISABLED' }
            $sev = if ($p.Enabled) { $script:Severity.Info } else { $script:Severity.Warning }
            New-DiagnosticResult -Component "Firewall profile '$profileName'" -Status $enabledText `
                -Details ("Default inbound: {0} | outbound: {1}" -f $p.DefaultInboundAction, $p.DefaultOutboundAction) `
                -Category 'Firewall' -Severity $sev
        }
    } catch {
        New-DiagnosticResult -Component 'Firewall profiles' -Status 'QUERY FAILED' -Details $_.Exception.Message `
            -Category 'Firewall' -Severity $script:Severity.Warning
    }

    # RDP rules
    $fw = Get-RdpFirewallRules -Port $Port
    if ($fw.All.Count -eq 0) {
        New-DiagnosticResult -Component 'RDP firewall rules' -Status 'NONE FOUND' `
            -Details "No inbound rules for RDP (built-in 'Remote Desktop' group or port $Port)." `
            -Remedy "Run with -EnableRDP to create/enable rules, or: Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'" `
            -Category 'Firewall' -Severity $script:Severity.Error
    } else {
        $summary = ("Total inbound RDP rules: {0} | enabled+allow: {1} | disabled: {2}" -f $fw.All.Count, $fw.Enabled.Count, $fw.Disabled.Count)
        if ($fw.Enabled.Count -gt 0) {
            New-DiagnosticResult -Component 'RDP firewall rules' -Status 'ALLOW RULES ACTIVE' -Details $summary `
                -Category 'Firewall' -Severity $script:Severity.Info
            Write-Verbose ("Enabled rules: {0}" -f (($fw.Enabled | Select-Object -First 8 | ForEach-Object { "$($_.DisplayName) [$($_.Name)] profile=$($_.Profile)" }) -join "`n  "))
        } else {
            New-DiagnosticResult -Component 'RDP firewall rules' -Status 'ALL DISABLED' -Details $summary `
                -Remedy "Enable-NetFirewallRule -Name '$($script:WellKnownRdpRuleNames -join "','")'   (or run with -EnableRDP)" `
                -Category 'Firewall' -Severity $script:Severity.Error
        }
        if ($fw.Disabled.Count -gt 0) {
            New-DiagnosticResult -Component 'RDP firewall rules (disabled set)' -Status "$($fw.Disabled.Count) DISABLED" `
                -Details (($fw.Disabled | Select-Object -First 6 | ForEach-Object { $_.DisplayName }) -join '; ') `
                -Remedy 'Run with -EnableRDP to enable them.' -Category 'Firewall' -Severity $script:Severity.Warning
        }
        if ($fw.PublicProfileGap) {
            New-DiagnosticResult -Component 'Public network exposure' -Status 'RULES DO NOT COVER PUBLIC PROFILE' `
                -Details 'The active network is categorized Public, but the enabled RDP rules only apply to Private/Domain profiles - inbound RDP will be blocked.' `
                -Remedy 'Run with -ForcePrivateNetwork (home/office LAN) or extend the rules: Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Profile Any' `
                -Category 'Firewall' -Severity $script:Severity.Error
        }
    }

    if ($fw.Blocking.Count -gt 0) {
        New-DiagnosticResult -Component 'Conflicting BLOCK rules' -Status "$($fw.Blocking.Count) FOUND" `
            -Details (($fw.Blocking | Select-Object -First 6 | ForEach-Object { "$($_.DisplayName) [$($_.Name)]" }) -join '; ') `
            -Remedy 'Block rules take precedence over allow rules. Remove/disable them for the RDP port (run with -EnableRDP to disable automatically).' `
            -Category 'Firewall' -Severity $script:Severity.Error
    }
    return $fw
}
#endregion

#region Check: Network
# ============================================================================
function Test-NetworkConfiguration {
    [CmdletBinding()]
    param()
    Show-Section -Title 'NETWORK CONFIGURATION' -Icon 'Globe'

    $adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    if ($adapters.Count -eq 0) {
        New-DiagnosticResult -Component 'Network adapters' -Status 'NONE UP' `
            -Details 'No connected network adapters found - RDP cannot be reached.' `
            -Category 'Network' -Severity $script:Severity.Error
        return
    }
    foreach ($a in $adapters) {
        New-DiagnosticResult -Component "Adapter '$($a.Name)'" -Status "UP ($($a.LinkSpeed))" `
            -Details $a.InterfaceDescription -Category 'Network' -Severity $script:Severity.Info
    }

    $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
    if ($profiles.Count -eq 0) {
        New-DiagnosticResult -Component 'Network profiles' -Status 'NONE FOUND' `
            -Details 'No connection profiles (normal only on Server Core without NLA stack).' `
            -Category 'Network' -Severity $script:Severity.Warning
        return
    }
    foreach ($cp in $profiles) {
        $sev = switch ($cp.NetworkCategory) {
            'DomainAuthenticated' { $script:Severity.Info }
            'Private'             { $script:Severity.Info }
            'Public'              { $script:Severity.Warning }
            default               { $script:Severity.Warning }
        }
        $hint = if ($cp.NetworkCategory -eq 'Public') {
            ' Public networks block RDP by default - use -ForcePrivateNetwork on a trusted LAN.'
        } else { '' }
        New-DiagnosticResult -Component "Profile '$($cp.InterfaceAlias)'" -Status $cp.NetworkCategory `
            -Details ("Network: {0}. IPv4 connectivity: {1}.{2}" -f $cp.Name, $cp.IPv4Connectivity, $hint) `
            -Category 'Network' -Severity $sev
    }

    # DNS + gateway sanity on the first connected profile
    try {
        $firstUp = $adapters | Select-Object -First 1
        $ipCfg = Get-NetIPConfiguration -InterfaceIndex $firstUp.ifIndex -ErrorAction Stop
        $gwEntry = $ipCfg.IPv4DefaultGateway | Select-Object -First 1
        $gw = if ($gwEntry) { $gwEntry.NextHop } else { $null }
        $dnsEntry = $ipCfg.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -First 1
        $dns = if ($dnsEntry) { $dnsEntry.ServerAddresses } else { $null }
        New-DiagnosticResult -Component 'Default gateway / DNS' -Status $(if ($gw) { "GW: $gw" } else { 'NO GATEWAY' }) `
            -Details ("DNS: {0}" -f $(if ($dns) { $dns -join ', ' } else { 'none configured' })) `
            -Remedy $(if (-not $gw) { 'A missing default gateway blocks RDP from other subnets.' } else { '' }) `
            -Category 'Network' -Severity $(if ($gw) { $script:Severity.Info } else { $script:Severity.Warning })
    } catch {
        Write-Verbose "Gateway/DNS probe failed: $($_.Exception.Message)"
    }
}
#endregion

#region Check: Listener, Ports & Local Connectivity
# ============================================================================
function Test-TcpPort {
    <#
    .SYNOPSIS
        Fast .NET TCP connect probe (replaces slow Test-NetConnection).
    .OUTPUTS
        [bool] connected
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $TargetHost,
        [Parameter(Mandatory)][int] $Port,
        [int] $TimeoutMs = 3000
    )
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $iar = $client.BeginConnect($TargetHost, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($iar)
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Test-ListenerAndPorts {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $Port)
    Show-Section -Title 'LISTENER & PORTS' -Subtitle "TCP/UDP state on port $Port" -Icon 'Plug'

    $rdpEnabled = (Get-RegistryValue -Path $script:RegTerminalServer -Name 'fDenyTSConnections') -eq 0
    $rdpShouldBeEnabled = -not $DisableRDP

    # TCP listener
    $tcpListen = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($tcpListen.Count -gt 0) {
        $ownerPid = $tcpListen[0].OwningProcess
        $owner = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
        $ownerName = if ($owner) { $owner.ProcessName } else { 'unknown' }
        $addresses = ($tcpListen | Select-Object -ExpandProperty LocalAddress -Unique) -join ', '
        New-DiagnosticResult -Component "TCP listener :$Port" -Status 'LISTENING' `
            -Details ("Owner: {0} (PID {1}) on [{2}]" -f $ownerName, $ownerPid, $addresses) `
            -Category 'Connectivity' -Severity $script:Severity.Info
        New-TestRecord -Name "TCP listener $Port" -Passed $true -Message "$ownerName listening on port $Port" | Out-Null
    } else {
        $unexpectedDown = $rdpEnabled -and $rdpShouldBeEnabled
        $sev = if ($unexpectedDown) { $script:Severity.Error } else { $script:Severity.Info }
        $status = if ($unexpectedDown) { 'NOT LISTENING (RDP ENABLED!)' } else { 'NOT LISTENING (RDP disabled - expected)' }
        New-DiagnosticResult -Component "TCP listener :$Port" -Status $status `
            -Details $(if ($unexpectedDown) { 'RDP is enabled in the registry but nothing accepts connections - service/listener problem.' } else { 'RDP is disabled by configuration; no listener is expected.' }) `
            -Remedy $(if ($unexpectedDown) { 'Restart the stack:  .\RDP-Tool.ps1 -RestartServices -Force   (or -EnableRDP for full repair)' } else { 'Run with -EnableRDP to bring the listener up.' }) `
            -Category 'Connectivity' -Severity $sev
        New-TestRecord -Name "TCP listener $Port" -Passed (-not $unexpectedDown) -Message 'No listener' | Out-Null
    }

    # UDP listener (RDP transport for better UX)
    $udpListen = @(Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($udpListen.Count -gt 0) {
        New-DiagnosticResult -Component "UDP listener :$Port" -Status 'LISTENING' `
            -Details 'RDP-over-UDP endpoint active (improves latency on good links).' -Category 'Connectivity' -Severity $script:Severity.Info
    } else {
        New-DiagnosticResult -Component "UDP listener :$Port" -Status 'NOT LISTENING' `
            -Details 'UDP transport inactive (TCP still works; SelectTransport=1 or missing UDP firewall rule are common causes).' -Category 'Connectivity' -Severity $script:Severity.Info
    }

    # Foreign process squatting on the port
    $foreign = @()
    foreach ($conn in $tcpListen) {
        $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -notin @('svchost', 'System', 'TermService')) {
            $foreign += ("{0} (PID {1})" -f $proc.ProcessName, $conn.OwningProcess)
        }
    }
    if ($foreign.Count -gt 0) {
        New-DiagnosticResult -Component 'Port ownership' -Status 'NON-STANDARD OWNER' `
            -Details ("Port {0} is served by: {1}. RDP normally runs inside svchost (TermService)." -f $Port, (($foreign | Select-Object -Unique) -join '; ')) `
            -Remedy 'Another application may have claimed the port. Stop it or move RDP: -SetPort <other-port>.' `
            -Category 'Connectivity' -Severity $script:Severity.Warning
    }

    # Loopback TCP connect (only meaningful when something listens)
    if ($tcpListen.Count -gt 0) {
        $connected = Test-TcpPort -TargetHost '127.0.0.1' -Port $Port -TimeoutMs 3000
        New-DiagnosticResult -Component "Loopback connect 127.0.0.1:$Port" -Status $(if ($connected) { 'CONNECTED' } else { 'FAILED' }) `
            -Details $(if ($connected) { 'TCP stack accepts connections locally.' } else { 'Listener present but TCP connect failed - check WFP filters / AV.' }) `
            -Category 'Connectivity' -Severity $(if ($connected) { $script:Severity.Info } else { $script:Severity.Error })
        New-TestRecord -Name "Loopback TCP $Port" -Passed $connected -Message '' | Out-Null
    }
}
#endregion

#region RDP Protocol Handshake (X.224 / RDP Negotiation)
# ============================================================================
# Real protocol-level probe: sends an unauthenticated X.224 Connection Request
# with an RDP Negotiation Request and parses the server answer. This proves
# the RDP stack (not just "some TCP server") is answering, and reveals the
# required security protocol (Standard / TLS / CredSSP-NLA) and precise
# failure codes. Equivalent to opening mstsc and closing it before logon.
# ============================================================================
function Get-RdpNegotiationRequestBytes {
    <#
    .SYNOPSIS
        Builds a TPKT + X.224 Connection Request containing an RDP Negotiation
        Request (requestedProtocols = TLS | CredSSP), with optional mstshash cookie.
    #>
    [CmdletBinding()]
    param([string] $Cookie = '')

    $data = [System.Collections.Generic.List[byte]]::new()
    if ($Cookie) {
        $cookieBytes = [System.Text.Encoding]::ASCII.GetBytes("Cookie: mstshash=$Cookie`r`n")
        $data.AddRange([byte[]]$cookieBytes)
    }
    # RDP_NEG_REQ: type=1, flags=0, length=8 (LE16), requestedProtocols=3 (LE32: TLS|CredSSP)
    $data.AddRange([byte[]]@(0x01, 0x00, 0x08, 0x00))
    $data.AddRange([byte[]]@(0x03, 0x00, 0x00, 0x00))

    $packet = [System.Collections.Generic.List[byte]]::new()
    $li = [byte](6 + $data.Count)          # X.224 LI: code(1)+dst(2)+src(2)+class(1)+data
    $total = 4 + 1 + $li                    # TPKT header(4) + LI byte(1) + LI content
    $packet.AddRange([byte[]]@(0x03, 0x00, [byte](($total -shr 8) -band 0xFF), [byte]($total -band 0xFF)))
    $packet.Add($li)
    $packet.AddRange([byte[]]@(0xE0, 0x00, 0x00, 0x00, 0x00, 0x00))
    $packet.AddRange($data)
    return , $packet.ToArray()
}

function ConvertFrom-RdpNegotiationResponse {
    <#
    .SYNOPSIS
        Parses an X.224 Connection Confirm packet.
    .OUTPUTS
        [pscustomobject] Type ('Response'|'Failure'|'None'), SelectedProtocol,
        FailureCode, FailureName, Detail.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][byte[]] $Packet)

    $out = [pscustomobject]@{ Type = 'None'; SelectedProtocol = -1; FailureCode = -1; FailureName = ''; Detail = '' }
    if ($Packet.Length -lt 11 -or $Packet[0] -ne 0x03) { $out.Detail = 'Not a TPKT packet'; return $out }
    if ($Packet[5] -ne 0xD0) { $out.Detail = ('Unexpected X.224 code 0x{0:X2} (expected 0xD0 CC)' -f $Packet[5]); return $out }

    $dataOffset = 4 + 1 + 6   # TPKT(4) + LI(1) + CC fixed fields(6)
    if ($Packet.Length -le $dataOffset) {
        $out.Type = 'Response'
        $out.SelectedProtocol = 0
        $out.Detail = 'Plain X.224 CC without negotiation response - server speaks Standard RDP security (no TLS/NLA)'
        return $out
    }

    $negType = $Packet[$dataOffset]
    if ($Packet.Length -lt ($dataOffset + 8)) { $out.Detail = 'Truncated negotiation payload'; return $out }
    $payload = [BitConverter]::ToUInt32($Packet, $dataOffset + 4)

    switch ($negType) {
        0x02 {
            $out.Type = 'Response'
            $out.SelectedProtocol = [int]$payload
            $out.Detail = switch ($payload) {
                0 { 'PROTOCOL_RDP - Standard RDP security (legacy, no TLS)' }
                1 { 'PROTOCOL_SSL - TLS encryption' }
                2 { 'PROTOCOL_HYBRID - CredSSP / Network Level Authentication (NLA)' }
                3 { 'PROTOCOL_HYBRID_EX - CredSSP with Echo extension' }
                default { "Unknown selectedProtocol 0x{0:X}" -f $payload }
            }
        }
        0x03 {
            $out.Type = 'Failure'
            $out.FailureCode = [int]$payload
            $out.FailureName = switch ($payload) {
                1 { 'SSL_REQUIRED_BY_SERVER' }
                2 { 'SSL_NOT_ALLOWED_BY_SERVER' }
                3 { 'SSL_CERT_NOT_ON_SERVER' }
                4 { 'INCONSISTENT_FLAGS' }
                5 { 'HYBRID_REQUIRED_BY_SERVER (NLA enforced)' }
                6 { 'SSL_WITH_USER_AUTH_REQUIRED_BY_SERVER' }
                default { "UNKNOWN_FAILURE_0x{0:X}" -f $payload }
            }
            $out.Detail = "Server rejected the negotiation: $($out.FailureName)"
        }
        default {
            $out.Detail = ('Unexpected negotiation type 0x{0:X2}' -f $negType)
        }
    }
    return $out
}

function Invoke-RdpHandshake {
    <#
    .SYNOPSIS
        Performs a full TCP + X.224 negotiation handshake against an RDP endpoint.
    .OUTPUTS
        [pscustomobject] Connected, HandshakeOk, Type, SelectedProtocol,
        FailureName, Detail, ElapsedMs, RequiresNla (nullable bool).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $TargetHost,
        [int] $Port = 3389,
        [int] $TimeoutSec = 8
    )

    $result = [pscustomobject]@{
        Connected = $false; HandshakeOk = $false; Type = 'None'; SelectedProtocol = -1
        FailureCode = -1; FailureName = ''; Detail = ''; ElapsedMs = 0; RequiresNla = $null
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $iar = $client.BeginConnect($TargetHost, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSec))) {
            $result.Detail = "TCP connect to ${TargetHost}:${Port} timed out after ${TimeoutSec}s"
            return $result
        }
        $client.EndConnect($iar)
        $result.Connected = $true

        $stream = $client.GetStream()
        $stream.ReadTimeout = $TimeoutSec * 1000
        $stream.WriteTimeout = $TimeoutSec * 1000

        $request = Get-RdpNegotiationRequestBytes -Cookie 'rdpdiag'
        $stream.Write($request, 0, $request.Length)
        $stream.Flush()

        # Read TPKT header (4 bytes), then the declared payload length.
        $header = New-Object byte[] 4
        $read = 0
        while ($read -lt 4) {
            $n = $stream.Read($header, $read, 4 - $read)
            if ($n -le 0) { throw 'Connection closed before TPKT header was received' }
            $read += $n
        }
        if ($header[0] -ne 0x03) { throw ('Non-TPKT response (first byte 0x{0:X2}) - service on this port is probably NOT RDP' -f $header[0]) }
        $length = ($header[2] -shl 8) -bor $header[3]
        if ($length -lt 4 -or $length -gt 65535) { throw "Implausible TPKT length $length" }

        $body = New-Object byte[] ($length - 4)
        $read = 0
        while ($read -lt $body.Length) {
            $n = $stream.Read($body, $read, $body.Length - $read)
            if ($n -le 0) { throw 'Connection closed mid-packet' }
            $read += $n
        }
        $packet = New-Object byte[] $length
        [Array]::Copy($header, 0, $packet, 0, 4)
        [Array]::Copy($body, 0, $packet, 4, $body.Length)

        $parsed = ConvertFrom-RdpNegotiationResponse -Packet $packet
        $result.Type = $parsed.Type
        $result.SelectedProtocol = $parsed.SelectedProtocol
        $result.FailureCode = $parsed.FailureCode
        $result.FailureName = $parsed.FailureName
        $result.Detail = $parsed.Detail
        $result.HandshakeOk = ($parsed.Type -eq 'Response') -or ($parsed.Type -eq 'Failure')
        if ($parsed.Type -eq 'Response') {
            $result.RequiresNla = ($parsed.SelectedProtocol -in @(2, 3))
        } elseif ($parsed.Type -eq 'Failure' -and $parsed.FailureCode -in @(5, 6)) {
            $result.RequiresNla = $true
        } elseif ($parsed.Type -eq 'Failure' -and $parsed.FailureCode -eq 1) {
            $result.RequiresNla = $false   # TLS required, but not CredSSP/NLA
        }
    } catch {
        $result.Detail = $_.Exception.Message
    } finally {
        $sw.Stop()
        $result.ElapsedMs = $sw.ElapsedMilliseconds
        $client.Dispose()
    }
    return $result
}

function Show-HandshakeResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Label,
        [Parameter(Mandatory)] $Handshake
    )
    if (-not $Handshake.Connected) {
        New-DiagnosticResult -Component "RDP handshake $Label" -Status 'TCP CONNECT FAILED' `
            -Details $Handshake.Detail `
            -Remedy 'Verify the host/port, firewall (local + perimeter), and that the listener is up. Test the port path with Test-NetConnection.' `
            -Category 'Connectivity' -Severity $script:Severity.Error
        New-TestRecord -Name "RDP handshake $Label" -Passed $false -Message $Handshake.Detail -Data $Handshake | Out-Null
        return $false
    }
    if (-not $Handshake.HandshakeOk) {
        New-DiagnosticResult -Component "RDP handshake $Label" -Status 'NOT AN RDP ENDPOINT' `
            -Details ("TCP connected but negotiation failed: {0} ({1} ms)" -f $Handshake.Detail, $Handshake.ElapsedMs) `
            -Remedy 'Something else may own this port, or the RDP stack is broken (restart TermService / repair Windows).' `
            -Category 'Connectivity' -Severity $script:Severity.Error
        New-TestRecord -Name "RDP handshake $Label" -Passed $false -Message $Handshake.Detail -Data $Handshake | Out-Null
        return $false
    }

    $protocolText = switch ($Handshake.Type) {
        'Response' { "negotiated: $($Handshake.Detail)" }
        'Failure'  { "rejected: $($Handshake.FailureName)" }
        default    { $Handshake.Detail }
    }
    $nlaText = switch ($Handshake.RequiresNla) {
        $true  { 'NLA/CredSSP: REQUIRED by server' }
        $false { 'NLA/CredSSP: not required (Standard/TLS)' }
        default { 'NLA/CredSSP: n/a' }
    }
    New-DiagnosticResult -Component "RDP handshake $Label" -Status 'RDP STACK ANSWERS' `
        -Details ("{0} | {1} | {2} ms" -f $protocolText, $nlaText, $Handshake.ElapsedMs) `
        -Category 'Connectivity' -Severity $script:Severity.Info
    New-TestRecord -Name "RDP handshake $Label" -Passed $true -Message $protocolText -Data $Handshake | Out-Null
    return $true
}

function Test-LocalRdpHandshake {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $Port)
    $tcpListen = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($tcpListen.Count -eq 0) {
        Write-Verbose "Skipping local handshake: nothing listening on port $Port."
        return
    }
    $hs = Invoke-RdpHandshake -TargetHost '127.0.0.1' -Port $Port -TimeoutSec 8
    $null = Show-HandshakeResult -Label "127.0.0.1:$Port (local)" -Handshake $hs

    # Cross-check handshake outcome vs registry NLA setting.
    if ($hs.HandshakeOk -and $null -ne $hs.RequiresNla) {
        $regNla = Get-RegistryValue -Path $script:RegWinStation -Name 'UserAuthentication'
        if ($null -ne $regNla -and $hs.RequiresNla -and $regNla -eq 0) {
            New-DiagnosticResult -Component 'NLA consistency (registry vs wire)' -Status 'MISMATCH' `
                -Details 'Registry says NLA disabled (UserAuthentication=0) but the stack still demands CredSSP - a GPO or WinStation override is active.' `
                -Remedy 'Check Group Policy "Require user authentication ... using NLA" and WinStation security settings.' `
                -Category 'Security' -Severity $script:Severity.Warning
        }
    }
}

function Test-RemoteRdpTarget {
    <#
    .SYNOPSIS
        -TestRdpTarget probe: parses 'host[:port]' and runs the handshake.
    .OUTPUTS
        $true when the remote RDP stack answered.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Target)

    $hostPart = $Target
    $port = 3389
    if ($Target -match '^(?<h>\[[^\]]+\]|[^:]+)(:(?<p>\d+))?$') {
        $hostPart = $Matches['h'] -replace '^\[|\]$', ''
        if ($Matches['p']) { $port = [int]$Matches['p'] }
    }

    Show-Section -Title "REMOTE RDP PROBE: ${hostPart}:${port}" -Icon 'Flask'
    $hs = Invoke-RdpHandshake -TargetHost $hostPart -Port $port -TimeoutSec 10
    $ok = Show-HandshakeResult -Label "${hostPart}:${port} (remote)" -Handshake $hs

    if ($ok) {
        Show-Line -Text '' 
        Show-Line -Text "  Connect with:  mstsc /v:${hostPart}:$port" -Color 'Info' -Force
        if ($hs.RequiresNla -eq $true) {
            Show-Line -Text '  Server enforces NLA (CredSSP). Clients older than Windows 7 SP1 / without CredSSP updates will fail.' -Color 'Verbose' -Force
        }
    }
    return $ok
}
#endregion

#region Check: RDP TLS Certificate
# ============================================================================
function Test-RdpCertificate {
    [CmdletBinding()]
    param()
    Show-Section -Title 'RDP CERTIFICATE' -Subtitle 'TLS certificate used by the listener' -Icon 'Key'

    $configuredThumbprint = Get-RegistryValue -Path $script:RegWinStation -Name 'SSLCertificateSHA1Hash'
    $cert = $null
    $origin = 'auto-generated'

    if ($configuredThumbprint) {
        $tp = ([string]$configuredThumbprint) -replace '[^0-9A-Fa-f]', ''
        try {
            $cert = Get-Item -Path "Cert:\LocalMachine\My\$tp" -ErrorAction SilentlyContinue
            if (-not $cert) { $cert = Get-ChildItem -Path 'Cert:\LocalMachine\My' -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $tp } | Select-Object -First 1 }
            $origin = 'explicitly configured (SSLCertificateSHA1Hash)'
        } catch { Write-Verbose "My-store lookup failed: $($_.Exception.Message)" }
        if (-not $cert) {
            New-DiagnosticResult -Component 'Configured TLS certificate' -Status 'NOT FOUND IN STORE' `
                -Details ("Registry pins thumbprint {0} but no such certificate exists in LocalMachine\My. The listener falls back to a self-signed certificate or fails TLS." -f $tp) `
                -Remedy 'Import the certificate into LocalMachine\My (with private key) or remove the SSLCertificateSHA1Hash value to fall back to auto-generation.' `
                -Category 'Security' -Severity $script:Severity.Error
            return
        }
    } else {
        try {
            $cert = Get-ChildItem -Path 'Cert:\LocalMachine\Remote Desktop' -ErrorAction Stop |
                    Sort-Object NotAfter -Descending | Select-Object -First 1
        } catch {
            Write-Verbose "'Remote Desktop' certificate store not accessible: $($_.Exception.Message)"
        }
    }

    if (-not $cert) {
        New-DiagnosticResult -Component 'RDP self-signed certificate' -Status 'NOT PRESENT' `
            -Details "No certificate in 'LocalMachine\Remote Desktop'. Windows regenerates one automatically when the listener starts; clients will see an unknown-publisher warning." `
            -Category 'Security' -Severity $script:Severity.Info
        return
    }

    $daysLeft = [math]::Floor(($cert.NotAfter - [datetime]::Now).TotalDays)
    $details = ("Subject: {0} | Thumbprint: {1} | Valid: {2:yyyy-MM-dd} .. {3:yyyy-MM-dd} ({4} days left) | Private key: {5} | Source: {6}" -f `
        $cert.Subject, $cert.Thumbprint, $cert.NotBefore, $cert.NotAfter, $daysLeft, $(if ($cert.HasPrivateKey) { 'yes' } else { 'NO' }), $origin)

    if (-not $cert.HasPrivateKey) {
        New-DiagnosticResult -Component 'RDP TLS certificate' -Status 'NO PRIVATE KEY' -Details $details `
            -Remedy 'The listener cannot use a certificate without a private key. Re-import with the key or delete the pinning registry value.' `
            -Category 'Security' -Severity $script:Severity.Error
    } elseif ($cert.NotAfter -lt [datetime]::Now) {
        New-DiagnosticResult -Component 'RDP TLS certificate' -Status 'EXPIRED' -Details $details `
            -Remedy 'Replace the expired certificate (renew GPO/MDM-deployed cert or delete the auto-generated one to force regeneration).' `
            -Category 'Security' -Severity $script:Severity.Error
    } elseif ($daysLeft -lt 30) {
        New-DiagnosticResult -Component 'RDP TLS certificate' -Status 'EXPIRES SOON' -Details $details `
            -Remedy 'Plan certificate renewal within the next 30 days.' `
            -Category 'Security' -Severity $script:Severity.Warning
    } else {
        New-DiagnosticResult -Component 'RDP TLS certificate' -Status 'VALID' -Details $details `
            -Category 'Security' -Severity $script:Severity.Info
    }
}
#endregion

#region Check: User Permissions
# ============================================================================
function Get-LocalGroupBySid {
    <#
    .SYNOPSIS
        Resolves a local group by its well-known SID - immune to OS display
        language (v4 used the English name 'Remote Desktop Users', which fails
        on localized Windows installations).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Sid)
    try {
        return Get-LocalGroup | Where-Object { $_.SID.Value -eq $Sid } | Select-Object -First 1
    } catch {
        Write-Verbose "Get-LocalGroup enumeration failed: $($_.Exception.Message)"
        return $null
    }
}

function Test-UserPermissions {
    [CmdletBinding()]
    param()
    Show-Section -Title 'USER PERMISSIONS' -Icon 'Users'

    $currentUser = $script:SystemInfo.CurrentUser
    $currentUserSid = $script:SystemInfo.CurrentUserSid
    Show-Line -Text ("  Current user: {0} (SID {1})" -f $currentUser, $currentUserSid) -Color 'Info'

    $rdGroup = Get-LocalGroupBySid -Sid $script:SidRemoteDesktopUsers
    if (-not $rdGroup) {
        New-DiagnosticResult -Component 'Remote Desktop Users group' -Status 'NOT FOUND' `
            -Details "No local group with SID $($script:SidRemoteDesktopUsers) exists (domain controllers do not have local groups)." `
            -Remedy 'On domain controllers, grant "Allow log on through Remote Desktop Services" via GPO instead.' `
            -Category 'Permissions' -Severity $script:Severity.Warning
        return
    }

    $members = @()
    try {
        $members = @(Get-LocalGroupMember -Group $rdGroup.Name -ErrorAction Stop)
    } catch {
        New-DiagnosticResult -Component 'Remote Desktop Users group' -Status 'QUERY FAILED' `
            -Details $_.Exception.Message `
            -Remedy 'Ensure the LocalAccounts provider works (Microsoft.PowerShell.LocalAccounts) and retry elevated.' `
            -Category 'Permissions' -Severity $script:Severity.Warning
        return
    }

    if ($members.Count -gt 0) {
        $memberNames = ($members | ForEach-Object { $_.Name }) -join ', '
        New-DiagnosticResult -Component "Group '$($rdGroup.Name)'" -Status "$($members.Count) MEMBER(S)" `
            -Details $memberNames -Category 'Permissions' -Severity $script:Severity.Info
    } else {
        New-DiagnosticResult -Component "Group '$($rdGroup.Name)'" -Status 'EMPTY' `
            -Details 'No members. Only local Administrators can connect via RDP (administrators have implicit rights).' `
            -Remedy 'Grant access:  .\RDP-Tool.ps1 -AddUser "DOMAIN\user"' `
            -Category 'Permissions' -Severity $script:Severity.Warning
    }

    # Current user rights: admin OR member of RD Users
    $isAdminUser = $false
    try {
        $adminGroup = Get-LocalGroupBySid -Sid $script:SidAdministrators
        if ($adminGroup) {
            $admins = @(Get-LocalGroupMember -Group $adminGroup.Name -ErrorAction SilentlyContinue)
            $isAdminUser = @($admins | Where-Object { $_.SID -and $_.SID.Value -eq $currentUserSid }).Count -gt 0
        }
    } catch { Write-Verbose "Admin group check failed: $($_.Exception.Message)" }

    $isMember = @($members | Where-Object { $_.SID -and $_.SID.Value -eq $currentUserSid }).Count -gt 0

    if ($isAdminUser -or $isMember) {
        $via = if ($isAdminUser) { 'Administrators (implicit right)' } else { "member of '$($rdGroup.Name)'" }
        New-DiagnosticResult -Component 'Current user RDP right' -Status 'GRANTED' `
            -Details "Granted via: $via" -Category 'Permissions' -Severity $script:Severity.Info
    } else {
        New-DiagnosticResult -Component 'Current user RDP right' -Status 'NOT GRANTED' `
            -Details ("'{0}' is neither a local administrator nor a member of '{1}' - interactive RDP logon will be denied." -f $currentUser, $rdGroup.Name) `
            -Remedy "Run:  .\RDP-Tool.ps1 -AddUser '$currentUser'" `
            -Category 'Permissions' -Severity $script:Severity.Warning
    }

    # Denied logon right (SeDenyRemoteInteractiveLogonRight) via effective user rights is
    # expensive to enumerate (secedit export); surface the policy path instead.
    $denyPolicy = Get-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LimitBlankPasswordUse'
    if ($null -ne $denyPolicy -and "$denyPolicy" -eq '1') {
        Write-Verbose 'LimitBlankPasswordUse=1 (default): accounts with blank passwords cannot use RDP.'
    }
}
#endregion

#region Check: Security Posture
# ============================================================================
function Test-SecurityPosture {
    [CmdletBinding()]
    param()
    Show-Section -Title 'SECURITY POSTURE' -Icon 'Lock'

    # UAC
    $enableLua = Get-RegistryValue -Path $script:RegGpoSystem -Name 'EnableLUA'
    if ($null -ne $enableLua) {
        $uacOn = "$enableLua" -eq '1'
        New-DiagnosticResult -Component 'User Account Control' -Status $(if ($uacOn) { 'ENABLED' } else { 'DISABLED' }) `
            -Details $(if ($uacOn) { 'EnableLUA=1 (recommended).' } else { 'EnableLUA=0 - the machine is more exposed to malware; some RDP features (e.g. Credential Guard) require UAC.' }) `
            -Category 'Security' -Severity $(if ($uacOn) { $script:Severity.Info } else { $script:Severity.Warning })
    }

    # Defender service (third-party AV may have disabled it - informational)
    $defender = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if ($defender) {
        New-DiagnosticResult -Component 'Microsoft Defender AV' -Status $defender.Status `
            -Details $(if ($defender.Status -eq 'Running') { 'Real-time protection service running.' } else { 'Not running - verify a third-party AV is active instead.' }) `
            -Category 'Security' -Severity $(if ($defender.Status -eq 'Running') { $script:Severity.Info } else { $script:Severity.Warning })
    }

    # Credential Guard / VBS (can interact with CredSSP/NLA behavior)
    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        $running = @($dg.SecurityServicesRunning)
        $cgOn = $running -contains 1
        $hvbciOn = ($dg.VirtualizationBasedSecurityStatus -eq 2) -or ($running.Count -gt 0)
        New-DiagnosticResult -Component 'Credential Guard / VBS' -Status $(if ($cgOn) { 'CREDENTIAL GUARD RUNNING' } elseif ($hvbciOn) { 'VBS ACTIVE' } else { 'NOT ACTIVE' }) `
            -Details ("SecurityServicesRunning: [{0}]. CredSSP/NLA works with Credential Guard on patched systems; very old clients may hit KDC-proxy style issues." -f ($running -join ', ')) `
            -Category 'Security' -Severity $script:Severity.Info
    } catch {
        Write-Verbose "DeviceGuard namespace unavailable: $($_.Exception.Message)"
    }

    # NLA posture summary (single consolidated statement)
    $nla = Get-RegistryValue -Path $script:RegWinStation -Name 'UserAuthentication'
    $gpoNla = Get-RegistryValue -Path $script:RegGpoTerminalServices -Name 'UserAuthentication'
    $effectiveNla = if ($null -ne $gpoNla) { $gpoNla } elseif ($null -ne $nla) { $nla } else { 1 }
    if ("$effectiveNla" -eq '1') {
        New-DiagnosticResult -Component 'NLA posture' -Status 'ENFORCED (recommended)' `
            -Details 'Connections must authenticate via CredSSP before a session is allocated - mitigates RDP worming and resource-exhaustion attacks.' `
            -Category 'Security' -Severity $script:Severity.Info
    } else {
        New-DiagnosticResult -Component 'NLA posture' -Status 'NOT ENFORCED' `
            -Details 'Server accepts pre-authentication sessions (UserAuthentication=0). Exposed to unauthenticated attacks and session exhaustion.' `
            -Remedy 'Enable NLA:  .\RDP-Tool.ps1 -EnableRDP   (sets UserAuthentication=1 unless -DisableNLA was passed)' `
            -Category 'Security' -Severity $script:Severity.Warning
    }

    # Audit policy sanity: presence of logon events in the Security log
    try {
        $null = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4624; StartTime = [datetime]::Now.AddDays(-1) } -MaxEvents 1 -ErrorAction Stop
        New-DiagnosticResult -Component 'Logon auditing' -Status 'ACTIVE' `
            -Details 'Security log records logon events (4624) - RDP forensics possible.' `
            -Category 'Security' -Severity $script:Severity.Info
    } catch {
        New-DiagnosticResult -Component 'Logon auditing' -Status 'NO RECENT LOGON EVENTS' `
            -Details 'No 4624 events in the last 24h - logon auditing may be disabled, making RDP incident analysis impossible.' `
            -Remedy 'auditpol /set /subcategory:"Logon" /success:enable /failure:enable' `
            -Category 'Security' -Severity $script:Severity.Warning
    }
}
#endregion

#region Check: Resources
# ============================================================================
function Test-ResourceReadiness {
    [CmdletBinding()]
    param()
    Show-Section -Title 'RESOURCES' -Icon 'Summary'

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $sev = if ($freeGB -lt 1) { $script:Severity.Warning } else { $script:Severity.Info }
        New-DiagnosticResult -Component 'Memory' -Status ("{0} GB free / {1} GB total" -f $freeGB, $totalGB) `
            -Details $(if ($freeGB -lt 1) { 'Less than 1 GB free - RDP sessions (especially with graphics) may be slow or fail.' } else { 'Sufficient free memory for RDP sessions.' }) `
            -Category 'Performance' -Severity $sev
    } catch { Write-Verbose "Memory probe failed: $($_.Exception.Message)" }

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        New-DiagnosticResult -Component 'CPU' -Status ("{0} core(s) / {1} thread(s), load {2}%" -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors, $cpu.LoadPercentage) `
            -Details $cpu.Name.Trim() -Category 'Performance' -Severity $script:Severity.Info
    } catch { Write-Verbose "CPU probe failed: $($_.Exception.Message)" }

    try {
        $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        if ($drive) {
            $freeGB = [math]::Round($drive.FreeSpace / 1GB, 1)
            $totalGB = [math]::Round($drive.Size / 1GB, 1)
            $sev = if ($freeGB -lt 5) { $script:Severity.Warning } else { $script:Severity.Info }
            New-DiagnosticResult -Component 'System drive C:' -Status ("{0} GB free / {1} GB" -f $freeGB, $totalGB) `
                -Details $(if ($freeGB -lt 5) { 'Low disk space degrades profiles, paging and RDP session stability.' } else { 'Sufficient free space.' }) `
                -Category 'Performance' -Severity $sev
        }
    } catch { Write-Verbose "Disk probe failed: $($_.Exception.Message)" }

    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop)
        if ($gpus.Count -gt 0) {
            $names = ($gpus | ForEach-Object { $_.Name }) -join '; '
            New-DiagnosticResult -Component 'Graphics' -Status "$($gpus.Count) ADAPTER(S)" -Details $names `
                -Category 'Performance' -Severity $script:Severity.Info
        }
    } catch { Write-Verbose "GPU probe failed: $($_.Exception.Message)" }
}
#endregion

#region Check: Event Log Insights
# ============================================================================
function Get-RdpEventInsights {
    <#
    .SYNOPSIS
        Mines RDP-relevant event logs from the last N days: TermService
        errors, RemoteConnectionManager auth events (1148/1149),
        LocalSessionManager session events (21-25) and Security logon
        events (4624/4625 type 10, 4778/4779).
    #>
    [CmdletBinding()]
    param([int] $Days = 7)

    Show-Section -Title "EVENT LOG INSIGHTS (LAST $Days DAYS)" -Icon 'Report'
    $since = [datetime]::Now.AddDays(-$Days)

    # 1) TermService errors/warnings in System log
    try {
        $termErrors = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-TerminalServices-LocalSessionManager', 'TermService', 'Microsoft-Windows-TerminalServices-PnPDevices'; Level = 1, 2, 3; StartTime = $since } -MaxEvents 200 -ErrorAction Stop)
    } catch { $termErrors = @() }
    if ($termErrors.Count -gt 0) {
        $latest = $termErrors | Select-Object -First 3
        $detail = ($latest | ForEach-Object { '[{0:MM-dd HH:mm}] ID {1}: {2}' -f $_.TimeCreated, $_.Id, (($_.Message -split "`r?`n" | Select-Object -First 1)) }) -join ' | '
        New-DiagnosticResult -Component 'RDP service errors (System log)' -Status "$($termErrors.Count) EVENT(S)" `
            -Details ($detail.Substring(0, [math]::Min(500, $detail.Length))) `
            -Remedy 'Inspect in Event Viewer: Windows Logs -> System, source TermService / LocalSessionManager.' `
            -Category 'EventLogs' -Severity $script:Severity.Warning
    } else {
        New-DiagnosticResult -Component 'RDP service errors (System log)' -Status 'NONE' -Category 'EventLogs' -Severity $script:Severity.Info
    }

    # 2) RemoteConnectionManager: 1149 (auth success), 1148 (auth failure)
    foreach ($idSpec in @(@{ Id = 1149; Label = 'RDP authentication successes (RCM 1149)'; Sev = $script:Severity.Info },
                          @{ Id = 1148; Label = 'RDP authentication failures (RCM 1148)'; Sev = $script:Severity.Warning })) {
        try {
            $evts = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational'; Id = $idSpec.Id; StartTime = $since } -MaxEvents 500 -ErrorAction Stop)
            $sev = $idSpec.Sev
            if ($evts.Count -eq 0 -and $idSpec.Id -eq 1148) { $sev = $script:Severity.Info }
            $detail = ''
            if ($evts.Count -gt 0) {
                $first = $evts | Select-Object -First 1
                $detail = ('Most recent: [{0:yyyy-MM-dd HH:mm}] {1}' -f $first.TimeCreated, (($first.Message -split "`r?`n" | Select-Object -First 1)))
            }
            New-DiagnosticResult -Component $idSpec.Label -Status "$($evts.Count) EVENT(S)" -Details $detail `
                -Category 'EventLogs' -Severity $sev
        } catch {
            Write-Verbose "RCM log unavailable (ID $($idSpec.Id)): $($_.Exception.Message)"
        }
    }

    # 3) LocalSessionManager operational: 21 logon, 23 logoff, 24 disconnect, 25 reconnect
    try {
        $lsm = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; Id = 21, 22, 23, 24, 25; StartTime = $since } -MaxEvents 500 -ErrorAction Stop)
        if ($lsm.Count -gt 0) {
            $grouped = $lsm | Group-Object Id | ForEach-Object { "ID $($_.Name): $($_.Count)" }
            New-DiagnosticResult -Component 'Session lifecycle events (LSM)' -Status "$($lsm.Count) EVENT(S)" `
                -Details ($grouped -join '; ') -Category 'EventLogs' -Severity $script:Severity.Info
        }
    } catch { Write-Verbose "LSM log unavailable: $($_.Exception.Message)" }

    # 4) Security log: interactive-remote logons (4624 type 10), failures (4625 type 10), reconnect 4778, disconnect 4779
    try {
        $ok4624 = @(Get-WinEvent -FilterXPath "*[System[EventID=4624 and TimeCreated[timediff(@SystemTime) <= $($Days * 86400000)]] and EventData[Data[@Name='LogonType']='10']]" -LogName 'Security' -MaxEvents 200 -ErrorAction Stop)
        New-DiagnosticResult -Component 'Remote interactive logons (4624/10)' -Status "$($ok4624.Count) SUCCESS(ES)" `
            -Details $(if ($ok4624.Count -gt 0) { 'Successful RDP logons recorded in the Security log.' } else { 'No successful RDP logons in the window.' }) `
            -Category 'EventLogs' -Severity $script:Severity.Info
    } catch { Write-Verbose "Security 4624/10 query failed: $($_.Exception.Message)" }

    try {
        $bad4625 = @(Get-WinEvent -FilterXPath "*[System[EventID=4625 and TimeCreated[timediff(@SystemTime) <= $($Days * 86400000)]] and EventData[Data[@Name='LogonType']='10']]" -LogName 'Security' -MaxEvents 300 -ErrorAction Stop)
        if ($bad4625.Count -gt 0) {
            $byIp = @{}
            foreach ($e in ($bad4625 | Select-Object -First 100)) {
                try {
                    $xml = [xml]$e.ToXml()
                    $ipNode = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -First 1
                    $ip = if ($ipNode) { $ipNode.'#text' } else { '?' }
                    if ($byIp.ContainsKey($ip)) { $byIp[$ip]++ } else { $byIp[$ip] = 1 }
                } catch {
                    Write-Verbose "IpAddress extraction failed for event $($e.Id): $($_.Exception.Message)"
                }
            }
            $top = ($byIp.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Key) ($($_.Value)x)" }) -join ', '
            $sev = if ($bad4625.Count -ge 20) { $script:Severity.Error } else { $script:Severity.Warning }
            New-DiagnosticResult -Component 'Failed RDP logons (4625/10)' -Status "$($bad4625.Count) ATTEMPT(S)" `
                -Details ("Top source IPs: {0}{1}" -f $top, $(if ($bad4625.Count -ge 20) { ' - possible brute-force activity!' } else { '' })) `
                -Remedy 'Consider NLA (blocks pre-auth attacks), firewall scoping to known subnets, account lockout policy, or an RD Gateway for internet-facing hosts.' `
                -Category 'EventLogs' -Severity $sev
        } else {
            New-DiagnosticResult -Component 'Failed RDP logons (4625/10)' -Status 'NONE' -Category 'EventLogs' -Severity $script:Severity.Info
        }
    } catch { Write-Verbose "Security 4625/10 query failed: $($_.Exception.Message)" }

    try {
        $reconnects = @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4778, 4779; StartTime = $since } -MaxEvents 200 -ErrorAction Stop)
        if ($reconnects.Count -gt 0) {
            New-DiagnosticResult -Component 'Session reconnect/disconnect (4778/4779)' -Status "$($reconnects.Count) EVENT(S)" `
                -Category 'EventLogs' -Severity $script:Severity.Info
        }
    } catch { Write-Verbose "Security 4778/4779 query failed: $($_.Exception.Message)" }
}
#endregion

#region Session Enumeration (WTS API)
# ============================================================================
$script:WtsTypeDef = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class RdpWtsNative
{
    public static readonly IntPtr WTS_CURRENT_SERVER_HANDLE = IntPtr.Zero;

    [StructLayout(LayoutKind.Sequential)]
    public struct WTS_SESSION_INFO
    {
        public int SessionID;
        [MarshalAs(UnmanagedType.LPTStr)] public string pWinStationName;
        public int State;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WTS_CLIENT_ADDRESS
    {
        public int AddressFamily;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 20)] public byte[] Address;
    }

    public enum WTSInfoClass : int
    {
        WTSApplicationName = 1,
        WTSWorkingDirectory = 2,
        WTSOEMId = 3,
        WTSSessionId = 4,
        WTSUserName = 5,
        WTSWinStationName = 6,
        WTSDomainName = 7,
        WTSConnectState = 8,
        WTSClientBuildNumber = 9,
        WTSClientName = 10,
        WTSClientDirectory = 11,
        WTSClientProductId = 12,
        WTSClientHardwareId = 13,
        WTSClientAddress = 14,
        WTSClientDisplay = 15,
        WTSClientProtocolType = 16
    }

    public static string[] StateNames = new string[]
    { "Active", "Connected", "ConnectQuery", "Shadow", "Disconnected", "Idle", "Listen", "Reset", "Down", "Init" };

    [DllImport("wtsapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool WTSEnumerateSessions(IntPtr hServer, int Reserved, int Version, out IntPtr ppSessionInfo, out int pCount);

    [DllImport("wtsapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool WTSQuerySessionInformation(IntPtr hServer, int sessionId, WTSInfoClass wtsInfoClass, out IntPtr ppBuffer, out int pBytesReturned);

    [DllImport("wtsapi32.dll")]
    public static extern void WTSFreeMemory(IntPtr pMemory);

    private static string QueryString(int sessionId, WTSInfoClass infoClass)
    {
        IntPtr buffer = IntPtr.Zero;
        int bytes = 0;
        try
        {
            if (WTSQuerySessionInformation(WTS_CURRENT_SERVER_HANDLE, sessionId, infoClass, out buffer, out bytes) && buffer != IntPtr.Zero)
            {
                return Marshal.PtrToStringUni(buffer) ?? string.Empty;
            }
        }
        catch { }
        finally { if (buffer != IntPtr.Zero) WTSFreeMemory(buffer); }
        return string.Empty;
    }

    private static string QueryClientAddress(int sessionId)
    {
        IntPtr buffer = IntPtr.Zero;
        int bytes = 0;
        try
        {
            if (WTSQuerySessionInformation(WTS_CURRENT_SERVER_HANDLE, sessionId, WTSInfoClass.WTSClientAddress, out buffer, out bytes) && buffer != IntPtr.Zero)
            {
                WTS_CLIENT_ADDRESS addr = Marshal.PtrToStructure<WTS_CLIENT_ADDRESS>(buffer);
                if (addr.AddressFamily == 2)   // AF_INET
                {
                    // IPv4 stored big-endian starting at offset 2
                    return string.Format("{0}.{1}.{2}.{3}", addr.Address[2], addr.Address[3], addr.Address[4], addr.Address[5]);
                }
                if (addr.AddressFamily == 23)  // AF_INET6
                {
                    byte[] v6 = new byte[16];
                    Array.Copy(addr.Address, 2, v6, 0, 16);
                    return new System.Net.IPAddress(v6).ToString();
                }
            }
        }
        catch { }
        finally { if (buffer != IntPtr.Zero) WTSFreeMemory(buffer); }
        return string.Empty;
    }

    private static string QueryProtocol(int sessionId)
    {
        IntPtr buffer = IntPtr.Zero;
        int bytes = 0;
        try
        {
            if (WTSQuerySessionInformation(WTS_CURRENT_SERVER_HANDLE, sessionId, WTSInfoClass.WTSClientProtocolType, out buffer, out bytes) && buffer != IntPtr.Zero)
            {
                short proto = Marshal.ReadInt16(buffer);
                if (proto == 0) return "Console";
                if (proto == 1) return "Legacy (ICA)";
                if (proto == 2) return "RDP";
                return "Unknown(" + proto + ")";
            }
        }
        catch { }
        finally { if (buffer != IntPtr.Zero) WTSFreeMemory(buffer); }
        return string.Empty;
    }

    public static List<object> GetSessions()
    {
        var list = new List<object>();
        IntPtr pInfo = IntPtr.Zero;
        int count = 0;
        if (!WTSEnumerateSessions(WTS_CURRENT_SERVER_HANDLE, 0, 1, out pInfo, out count))
        {
            throw new InvalidOperationException("WTSEnumerateSessions failed, Win32 error " + Marshal.GetLastWin32Error());
        }
        try
        {
            int stride = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
            for (int i = 0; i < count; i++)
            {
                IntPtr cur = IntPtr.Add(pInfo, i * stride);
                WTS_SESSION_INFO info = Marshal.PtrToStructure<WTS_SESSION_INFO>(cur);
                string state = (info.State >= 0 && info.State < StateNames.Length) ? StateNames[info.State] : "Unknown";
                string user = QueryString(info.SessionID, WTSInfoClass.WTSUserName);
                string domain = QueryString(info.SessionID, WTSInfoClass.WTSDomainName);
                string account = string.IsNullOrEmpty(user) ? string.Empty : (string.IsNullOrEmpty(domain) ? user : domain + "\\" + user);
                var row = new PSObjectShim
                {
                    SessionId = info.SessionID,
                    User = account,
                    State = state,
                    WinStation = info.pWinStationName ?? string.Empty,
                    ClientAddress = QueryClientAddress(info.SessionID),
                    Protocol = QueryProtocol(info.SessionID)
                };
                list.Add(row);
            }
        }
        finally { WTSFreeMemory(pInfo); }
        return list;
    }

    public class PSObjectShim
    {
        public int SessionId;
        public string User;
        public string State;
        public string WinStation;
        public string ClientAddress;
        public string Protocol;
    }
}
'@

function Get-RdpSessions {
    <#
    .SYNOPSIS
        Enumerates terminal sessions: WTS P/Invoke first, qwinsta fallback.
    .OUTPUTS
        Objects with SessionId, User, State, WinStation, ClientAddress, Protocol.
    #>
    [CmdletBinding()]
    param()

    # --- Primary: WTS API ----------------------------------------------------
    try {
        if (-not ('RdpWtsNative' -as [type])) {
            Add-Type -TypeDefinition $script:WtsTypeDef -Language CSharp -ErrorAction Stop
        }
        $rows = [RdpWtsNative]::GetSessions()
        return @($rows | ForEach-Object {
                [pscustomobject]@{
                    SessionId     = $_.SessionId
                    User          = if ($_.User) { $_.User } else { '-' }
                    State         = $_.State
                    WinStation    = if ($_.WinStation) { $_.WinStation } else { '-' }
                    ClientAddress = if ($_.ClientAddress) { $_.ClientAddress } else { '-' }
                    Protocol      = if ($_.Protocol) { $_.Protocol } else { '-' }
                }
            })
    } catch {
        Write-Verbose "WTS API enumeration failed ($($_.Exception.Message)); falling back to qwinsta."
    }

    # --- Fallback: qwinsta ---------------------------------------------------
    try {
        $output = & qwinsta.exe 2>$null
        $sessions = @()
        foreach ($line in ($output | Select-Object -Skip 1)) {
            $isCurrent = $line -match '^\s*>'
            $parts = (($line -replace '^\s*>', '').Trim()) -split '\s+' | Where-Object { $_ }
            if ($parts.Count -lt 3) { continue }
            # qwinsta columns: [SESSIONNAME] [USERNAME] ID STATE ; USERNAME may be absent
            $idIdx = -1
            for ($i = 1; $i -lt $parts.Count; $i++) {
                if ($parts[$i] -match '^[0-9]+$') { $idIdx = $i; break }
            }
            if ($idIdx -lt 1 -or ($idIdx + 1) -ge $parts.Count) { continue }
            $station = $parts[0]
            $user = if ($idIdx -ge 2) { $parts[1] } else { '-' }
            $sessions += [pscustomobject]@{
                SessionId     = [int]$parts[$idIdx]
                User          = $user
                State         = $parts[$idIdx + 1]
                WinStation    = $station
                ClientAddress = if ($isCurrent) { '(this session)' } else { '-' }
                Protocol      = '-'
            }
        }
        return $sessions
    } catch {
        Write-Verbose "qwinsta fallback failed: $($_.Exception.Message)"
        return @()
    }
}

function Show-RdpSessions {
    [CmdletBinding()]
    param()
    Show-Section -Title 'TERMINAL SESSIONS' -Icon 'Users'
    $sessions = @(Get-RdpSessions)
    if ($sessions.Count -eq 0) {
        Show-Line -Text '  No sessions could be enumerated (WTS API and qwinsta both unavailable).' -Color 'Warning' -Force
        New-DiagnosticResult -Component 'Session enumeration' -Status 'UNAVAILABLE' -Category 'Sessions' -Severity $script:Severity.Warning
        return
    }
    $table = $sessions | Sort-Object SessionId | Format-Table -Property SessionId, User, State, WinStation, ClientAddress, Protocol -AutoSize | Out-String
    Show-Line -Text $table -Force
    $activeCount = @($sessions | Where-Object { $_.State -eq 'Active' }).Count
    $discCount = @($sessions | Where-Object { $_.State -eq 'Disconnected' }).Count
    New-DiagnosticResult -Component 'Session summary' -Status "$($sessions.Count) SESSION(S)" `
        -Details ("Active: {0} | Disconnected: {1}" -f $activeCount, $discCount) `
        -Category 'Sessions' -Severity $script:Severity.Info
}
#endregion

#region Check: External Connectivity
# ============================================================================
function Test-ExternalConnectivity {
    [CmdletBinding()]
    param()
    Show-Section -Title 'EXTERNAL CONNECTIVITY' -Icon 'Globe'

    # DNS
    foreach ($domain in @('github.com', 'microsoft.com')) {
        try {
            $resolved = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop | Select-Object -First 1
            New-DiagnosticResult -Component "DNS: $domain" -Status 'RESOLVES' `
                -Details ("-> {0}" -f $resolved.IPAddress) -Category 'External' -Severity $script:Severity.Info
        } catch {
            New-DiagnosticResult -Component "DNS: $domain" -Status 'FAILED' `
                -Details $_.Exception.Message -Category 'External' -Severity $script:Severity.Warning
        }
    }

    # TCP probes
    foreach ($probe in @(@{ Host = 'github.com'; Port = 443; Why = 'required for -CheckUpdate/-Update' },
                         @{ Host = '8.8.8.8'; Port = 53; Why = 'generic egress' })) {
        $ok = Test-TcpPort -TargetHost $probe.Host -Port $probe.Port -TimeoutMs 5000
        New-DiagnosticResult -Component ("TCP {0}:{1}" -f $probe.Host, $probe.Port) -Status $(if ($ok) { 'REACHABLE' } else { 'UNREACHABLE' }) `
            -Details $probe.Why -Category 'External' -Severity $(if ($ok) { $script:Severity.Info } else { $script:Severity.Warning })
    }

    # TLS sanity (GitHub API requires TLS 1.2+)
    try {
        $tlsOk = [bool]([System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]::Tls12) -or $PSVersionTable.PSVersion.Major -ge 7
        New-DiagnosticResult -Component 'TLS 1.2+ support' -Status $(if ($tlsOk) { 'AVAILABLE' } else { 'NOT NEGOTIATED BY DEFAULT' }) `
            -Details 'PowerShell 7 enables TLS 1.2+ by default (needed by the GitHub API).' `
            -Category 'External' -Severity $(if ($tlsOk) { $script:Severity.Info } else { $script:Severity.Warning })
    } catch {
        Write-Verbose "TLS capability probe failed: $($_.Exception.Message)"
    }
}
#endregion

#region Remediation Engine
# ============================================================================
# Every mutating helper: GPO-aware, ShouldProcess-aware (-WhatIf/-Confirm),
# idempotent, and recorded via New-RemediationRecord for the reports.
# ============================================================================
$script:RegistryChanged = $false   # set when any RDP registry value is actually rewritten

function Set-RdpRegistryDword {
    <#
    .SYNOPSIS
        Writes a DWORD under the RDP configuration hive unless Group Policy
        manages the value. Records the attempt and is -WhatIf/-Confirm aware.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][int] $Value,
        [string] $Reason = ''
    )

    $action = "Set registry $Name = $Value"

    $gpo = Get-RegistryValue -Path $script:RegGpoTerminalServices -Name $Name
    if ($null -ne $gpo) {
        New-RemediationRecord -Action $action -Success $false `
            -Notes "BLOCKED by Group Policy (policy value: $gpo). Change the GPO and run 'gpupdate /force'."
        return $false
    }

    $current = Get-RegistryValue -Path $Path -Name $Name
    if ($null -ne $current -and [int]$current -eq $Value) {
        New-RemediationRecord -Action $action -Success $true -Skipped -Notes 'Already at desired value.'
        return $true
    }

    $target = "$Path -> $Name"
    $describe = "change $(if ($null -ne $current) { $current } else { '<unset>' }) to $Value$(if ($Reason) { " ($Reason)" })"
    if (-not $PSCmdlet.ShouldProcess($target, $describe)) {
        New-RemediationRecord -Action $action -Success $true -Skipped -Notes 'Skipped (-WhatIf / declined confirmation).'
        return $false
    }

    try {
        if (-not (Test-Path -Path $Path)) {
            $null = New-Item -Path $Path -Force -ErrorAction Stop
        }
        $null = New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop
        $script:RegistryChanged = $true
        New-RemediationRecord -Action $action -Success $true `
            -Notes ("Was: {0}{1}" -f $(if ($null -ne $current) { $current } else { '<unset>' }), $(if ($Reason) { " | $Reason" } else { '' }))
        return $true
    } catch {
        New-RemediationRecord -Action $action -Success $false -Notes $_.Exception.Message
        return $false
    }
}

function Repair-RdpService {
    <#
    .SYNOPSIS
        Ensures a service is not Disabled and (optionally) running.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string] $Name,
        [ValidateSet('Automatic', 'Manual')]
        [string] $DesiredStartup = 'Manual',
        [bool] $Start = $true
    )

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $svc) {
        New-RemediationRecord -Action "Repair service $Name" -Success $false -Notes 'Service not installed.'
        return $false
    }

    $changed = $false
    if ($svc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) {
        if ($PSCmdlet.ShouldProcess($Name, "Set startup type Disabled -> $DesiredStartup")) {
            try {
                Set-Service -Name $Name -StartupType $DesiredStartup -ErrorAction Stop
                New-RemediationRecord -Action "Service $Name startup -> $DesiredStartup" -Success $true -Notes 'Was Disabled.'
                $changed = $true
            } catch {
                New-RemediationRecord -Action "Service $Name startup -> $DesiredStartup" -Success $false -Notes $_.Exception.Message
                return $false
            }
        } else {
            New-RemediationRecord -Action "Service $Name startup" -Success $true -Skipped -Notes 'Declined/-WhatIf.'
        }
    }

    if ($Start) {
        $svc.Refresh()
        if ($svc.Status -ne 'Running') {
            if ($PSCmdlet.ShouldProcess($Name, 'Start service')) {
                try {
                    Start-Service -Name $Name -ErrorAction Stop
                    $svc.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
                    New-RemediationRecord -Action "Start service $Name" -Success $true
                    $changed = $true
                } catch {
                    New-RemediationRecord -Action "Start service $Name" -Success $false -Notes $_.Exception.Message
                    return $false
                }
            } else {
                New-RemediationRecord -Action "Start service $Name" -Success $true -Skipped -Notes 'Declined/-WhatIf.'
            }
        }
    }
    if (-not $changed) {
        New-RemediationRecord -Action "Repair service $Name" -Success $true -Skipped -Notes 'Already healthy (startup OK, running).'
    }
    return $true
}

function Repair-RdpFirewallRules {
    <#
    .SYNOPSIS
        Enables the built-in Remote Desktop rule set, ensures allow rules for
        the effective port (tool-managed, idempotent) and optionally disables
        conflicting block rules.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][int] $Port,
        [switch] $HandleBlockingRules
    )

    # 1) Built-in rule set
    try {
        $known = @(Get-NetFirewallRule -Name $script:WellKnownRdpRuleNames -ErrorAction SilentlyContinue)
        $disabledKnown = @($known | Where-Object { $_.Enabled -ne $true })
        if ($disabledKnown.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess(($disabledKnown.DisplayName -join '; '), 'Enable built-in Remote Desktop firewall rules')) {
                try {
                    $disabledKnown | Enable-NetFirewallRule -ErrorAction Stop
                    New-RemediationRecord -Action 'Enable built-in RDP firewall rules' -Success $true `
                        -Notes ($disabledKnown.Name -join ', ')
                } catch {
                    New-RemediationRecord -Action 'Enable built-in RDP firewall rules' -Success $false -Notes $_.Exception.Message
                }
            }
        } else {
            New-RemediationRecord -Action 'Enable built-in RDP firewall rules' -Success $true -Skipped -Notes 'Already enabled or not present on this SKU.'
        }
    } catch {
        New-RemediationRecord -Action 'Enable built-in RDP firewall rules' -Success $false -Notes $_.Exception.Message
    }

    # 2) Tool-managed rules for the effective port (idempotent)
    foreach ($proto in @('TCP', 'UDP')) {
        $ruleName = "RDP-Tool-$Port-$proto-In"
        $displayName = "Remote Desktop ($proto $Port) - managed by RDP-Tool"
        try {
            $existing = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
            if ($existing) {
                if ($existing.Enabled -ne $true) {
                    if ($PSCmdlet.ShouldProcess($displayName, 'Enable existing tool-managed rule')) {
                        Enable-NetFirewallRule -Name $ruleName -ErrorAction Stop
                        New-RemediationRecord -Action "Enable $proto/$Port rule" -Success $true -Notes $ruleName
                    }
                } else {
                    New-RemediationRecord -Action "Ensure $proto/$Port rule" -Success $true -Skipped -Notes "$ruleName already active."
                }
                continue
            }
            # Any pre-existing allow rule already covering the port makes a new rule redundant.
            $portFilters = @(Get-NetFirewallPortFilter -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -contains "$Port" -and $_.Protocol -eq $proto })
            $covered = $false
            if ($portFilters.Count -gt 0) {
                $covering = @($portFilters | Get-NetFirewallRule -ErrorAction SilentlyContinue |
                              Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' -and $_.Enabled -eq $true })
                $covered = $covering.Count -gt 0
            }
            if ($covered) {
                New-RemediationRecord -Action "Ensure $proto/$Port rule" -Success $true -Skipped -Notes 'An enabled allow rule for this port already exists.'
                continue
            }
            if ($PSCmdlet.ShouldProcess($displayName, "Create inbound allow rule for $proto port $Port (Profile: Any)")) {
                $null = New-NetFirewallRule -Name $ruleName -DisplayName $displayName `
                    -Direction Inbound -Protocol $proto -LocalPort $Port -Action Allow `
                    -Profile Any -Enabled True -ErrorAction Stop
                New-RemediationRecord -Action "Create $proto/$Port allow rule" -Success $true `
                    -Notes 'Profile=Any (covers Public networks too - scope it down if the host is internet-facing).'
            }
        } catch {
            New-RemediationRecord -Action "Ensure $proto/$Port rule" -Success $false -Notes $_.Exception.Message
        }
    }

    # 3) Conflicting block rules
    if ($HandleBlockingRules) {
        try {
            $blocking = @(Get-NetFirewallPortFilter -ErrorAction SilentlyContinue |
                          Where-Object { $_.LocalPort -contains "$Port" } |
                          Get-NetFirewallRule -ErrorAction SilentlyContinue |
                          Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Block' -and $_.Enabled -eq $true })
            foreach ($rule in $blocking) {
                if ($PSCmdlet.ShouldProcess($rule.DisplayName, 'Disable conflicting BLOCK rule')) {
                    try {
                        Disable-NetFirewallRule -Name $rule.Name -ErrorAction Stop
                        New-RemediationRecord -Action "Disable block rule '$($rule.DisplayName)'" -Success $true -Notes 'Block rules override allow rules; disabled instead of deleted (reversible).'
                    } catch {
                        New-RemediationRecord -Action "Disable block rule '$($rule.DisplayName)'" -Success $false -Notes $_.Exception.Message
                    }
                }
            }
            if ($blocking.Count -eq 0) {
                New-RemediationRecord -Action 'Handle conflicting block rules' -Success $true -Skipped -Notes 'None found.'
            }
        } catch {
            New-RemediationRecord -Action 'Handle conflicting block rules' -Success $false -Notes $_.Exception.Message
        }
    }
}

function Restart-RdpListener {
    <#
    .SYNOPSIS
        Restarts TermService so WinStation changes (port, NLA) rebind.
        Refuses inside an active remote session unless -Force is used.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([string] $Reason = '')

    if ($script:IsRemoteSession -and -not $Force) {
        New-RemediationRecord -Action 'Restart RDP listener' -Success $true -Skipped `
            -Notes 'Running inside a remote session - restart skipped to avoid cutting your connection. Re-run with -Force or restart TermService manually during a maintenance window.'
        return $false
    }
    if (-not $PSCmdlet.ShouldProcess('TermService', "Restart service$(if ($Reason) { " ($Reason)" })")) {
        New-RemediationRecord -Action 'Restart RDP listener' -Success $true -Skipped -Notes 'Declined/-WhatIf.'
        return $false
    }
    try {
        $svc = Get-Service -Name TermService -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            Restart-Service -Name TermService -Force -ErrorAction Stop
        } else {
            Start-Service -Name TermService -ErrorAction Stop
        }
        New-RemediationRecord -Action 'Restart RDP listener' -Success $true -Notes "TermService restarted$(if ($Reason) { " ($Reason)" })."
        return $true
    } catch {
        New-RemediationRecord -Action 'Restart RDP listener' -Success $false -Notes $_.Exception.Message
        return $false
    }
}

function Invoke-RdpEnable {
    <#
    .SYNOPSIS
        Full 'enable + repair' pipeline for the RDP server.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Show-Section -Title 'REMEDIATION: ENABLE RDP' -Subtitle 'Registry, services, firewall, permissions' -Icon 'Gear'

    # Core switches
    $null = Set-RdpRegistryDword -Path $script:RegTerminalServer -Name 'fDenyTSConnections' -Value 0 -Reason 'allow incoming RDP connections'
    $null = Set-RdpRegistryDword -Path $script:RegWinStation -Name 'fEnableWinStation' -Value 1 -Reason 'enable the RDP-Tcp listener'

    # Security baseline
    if ($DisableNLA) {
        if ($PSCmdlet.ShouldProcess('NLA', 'DISABLE Network Level Authentication (less secure)')) {
            $null = Set-RdpRegistryDword -Path $script:RegWinStation -Name 'UserAuthentication' -Value 0 -Reason 'NLA disabled per -DisableNLA (insecure - re-enable as soon as possible)'
        } else {
            New-RemediationRecord -Action 'Disable NLA' -Success $true -Skipped -Notes 'Declined/-WhatIf.'
        }
    } else {
        $null = Set-RdpRegistryDword -Path $script:RegWinStation -Name 'UserAuthentication' -Value 1 -Reason 'enforce NLA (CredSSP) - recommended'
        $null = Set-RdpRegistryDword -Path $script:RegWinStation -Name 'SecurityLayer' -Value 2 -Reason 'negotiated security layer'
        $null = Set-RdpRegistryDword -Path $script:RegWinStation -Name 'MinEncryptionLevel' -Value 3 -Reason 'High encryption minimum'
    }

    # Port (when requested together with -EnableRDP)
    if ($SetPort -gt 0) {
        Invoke-RdpPortChange -Port $SetPort -SkipListenerRestart
    }

    # Services
    $null = Repair-RdpService -Name 'TermService' -DesiredStartup 'Manual' -Start $true
    $null = Repair-RdpService -Name 'SessionEnv' -DesiredStartup 'Manual' -Start $true
    $null = Repair-RdpService -Name 'UmRdpService' -DesiredStartup 'Manual' -Start $true
    $rpc = Get-Service -Name RpcSs -ErrorAction SilentlyContinue
    if ($rpc -and $rpc.Status -ne 'Running') {
        New-RemediationRecord -Action 'Check RpcSs' -Success $false -Notes 'RPC service is not running - fundamental system problem; TermService cannot work. Investigate before retrying.'
    }

    # Firewall
    Repair-RdpFirewallRules -Port (Get-RdpListenerPort) -HandleBlockingRules

    # Current user rights (non-admin invoker would otherwise be unable to log on)
    try {
        $rdGroup = Get-LocalGroupBySid -Sid $script:SidRemoteDesktopUsers
        if ($rdGroup -and -not $script:IsAdmin) {
            $members = @(Get-LocalGroupMember -Group $rdGroup.Name -ErrorAction SilentlyContinue)
            $alreadyMember = @($members | Where-Object { $_.SID -and $_.SID.Value -eq $script:SystemInfo.CurrentUserSid }).Count -gt 0
            if (-not $alreadyMember) {
                Add-RdpGroupMembers -Users @($script:SystemInfo.CurrentUser)
            }
        }
    } catch {
        Write-Verbose "Current-user group check failed: $($_.Exception.Message)"
    }

    # Rebind the listener only when something actually changed (avoid needless service churn)
    if ($script:RegistryChanged -or $SetPort -gt 0) {
        $null = Restart-RdpListener -Reason 'apply WinStation configuration'
    } else {
        New-RemediationRecord -Action 'Restart RDP listener' -Success $true -Skipped -Notes 'No configuration changes were necessary; listener left running.'
    }
}

function Invoke-RdpPortChange {
    <#
    .SYNOPSIS
        Applies a new listener port: registry + firewall + listener restart.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][int] $Port,
        [switch] $SkipListenerRestart
    )
    Show-Section -Title "REMEDIATION: SET RDP PORT -> $Port" -Icon 'Plug'

    $ok = Set-RdpRegistryDword -Path $script:RegWinStation -Name 'PortNumber' -Value $Port -Reason "listener port change requested (-SetPort $Port)"
    Repair-RdpFirewallRules -Port $Port

    if ($ok -and -not $SkipListenerRestart) {
        $null = Restart-RdpListener -Reason 'rebind listener to the new port'
    }
    Show-Line -Text ("  Remember to connect with:  mstsc /v:<host>:{0}" -f $Port) -Color 'Info' -Force
}

function Invoke-ApplyNlaSetting {
    <#
    .SYNOPSIS
        Standalone -DisableNLA (without -EnableRDP): flips UserAuthentication.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Show-Section -Title 'REMEDIATION: NLA SETTING' -Icon 'Lock'
    $nlaValue = if ($DisableNLA) { 0 } else { 1 }
    if ($DisableNLA) {
        Show-Line -Text '  WARNING: disabling NLA exposes the host to unauthenticated attacks. Continue only for legacy-client compatibility.' -Color 'Warning' -Force
    }
    $null = Set-RdpRegistryDword -Path $script:RegWinStation -Name 'UserAuthentication' -Value $nlaValue -Reason $(if ($DisableNLA) { '-DisableNLA requested' } else { 'restore recommended NLA enforcement' })
    $null = Restart-RdpListener -Reason 'apply NLA change'
}

function Invoke-RdpDisable {
    <#
    .SYNOPSIS
        Securely disables inbound RDP.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Show-Section -Title 'REMEDIATION: DISABLE RDP' -Icon 'Lock'

    if ($script:IsRemoteSession -and -not $Force) {
        Show-Line -Text '  You appear to be INSIDE a remote session. Disabling RDP will not disconnect you immediately,' -Color 'Warning' -Force
        Show-Line -Text '  but you will not be able to reconnect. Re-run with -Force to proceed anyway.' -Color 'Warning' -Force
        New-RemediationRecord -Action 'Disable RDP' -Success $true -Skipped -Notes 'Running in a remote session without -Force.'
        return
    }

    $null = Set-RdpRegistryDword -Path $script:RegTerminalServer -Name 'fDenyTSConnections' -Value 1 -Reason 'deny incoming RDP connections (-DisableRDP)'

    try {
        $port = Get-RdpListenerPort
        $rulesToDisable = @(Get-NetFirewallRule -Name $script:WellKnownRdpRuleNames -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true })
        $toolRules = @(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'RDP-Tool-*' -and $_.Enabled -eq $true })
        $all = @($rulesToDisable + $toolRules)
        if ($all.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess(($all.DisplayName -join '; '), 'Disable RDP firewall rules')) {
                $all | Disable-NetFirewallRule -ErrorAction Stop
                New-RemediationRecord -Action 'Disable RDP firewall rules' -Success $true -Notes ($all.Name -join ', ')
            }
        } else {
            New-RemediationRecord -Action 'Disable RDP firewall rules' -Success $true -Skipped -Notes 'No enabled RDP rules found.'
        }
        Write-Verbose "Listener on port $port will stop accepting connections after TermService rebinds."
    } catch {
        New-RemediationRecord -Action 'Disable RDP firewall rules' -Success $false -Notes $_.Exception.Message
    }

    Show-Line -Text '  TermService is intentionally left running (stopping it could break console/management tooling).' -Color 'Verbose' -Force
}

function Add-RdpGroupMembers {
    <#
    .SYNOPSIS
        Validates and adds user accounts to the local Remote Desktop Users group.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)][string[]] $Users)

    $rdGroup = Get-LocalGroupBySid -Sid $script:SidRemoteDesktopUsers
    if (-not $rdGroup) {
        New-RemediationRecord -Action 'Add user(s) to Remote Desktop Users' -Success $false -Notes 'Local group not found (domain controller?).'
        return
    }

    $existing = @()
    try { $existing = @(Get-LocalGroupMember -Group $rdGroup.Name -ErrorAction SilentlyContinue) }
    catch { Write-Verbose "Existing membership enumeration failed: $($_.Exception.Message)" }

    foreach ($user in $Users) {
        # Membership check by name (covers 'HOST\user' and plain 'user' forms)
        $already = @($existing | Where-Object { $_.Name -eq $user -or $_.Name -like "*\$user" }).Count -gt 0
        if ($already) {
            New-RemediationRecord -Action "Add '$user' to '$($rdGroup.Name)'" -Success $true -Skipped -Notes 'Already a member.'
            continue
        }

        # Existence validation: local account or resolvable security principal
        $resolvable = $true
        try {
            $nt = [System.Security.Principal.NTAccount]::new($user)
            $null = $nt.Translate([System.Security.Principal.SecurityIdentifier])
        } catch {
            $localUser = Get-LocalUser -Name ($user -replace '^.*\\', '') -ErrorAction SilentlyContinue
            $resolvable = [bool]$localUser
        }
        if (-not $resolvable) {
            New-RemediationRecord -Action "Add '$user' to '$($rdGroup.Name)'" -Success $false -Notes 'Account does not exist / cannot be resolved.'
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($rdGroup.Name, "Add member '$user'")) {
            New-RemediationRecord -Action "Add '$user' to '$($rdGroup.Name)'" -Success $true -Skipped -Notes 'Declined/-WhatIf.'
            continue
        }
        try {
            Add-LocalGroupMember -Group $rdGroup.Name -Member $user -ErrorAction Stop
            New-RemediationRecord -Action "Add '$user' to '$($rdGroup.Name)'" -Success $true
        } catch {
            New-RemediationRecord -Action "Add '$user' to '$($rdGroup.Name)'" -Success $false -Notes $_.Exception.Message
        }
    }
}

function Invoke-RdpServiceRestart {
    <#
    .SYNOPSIS
        -RestartServices implementation with remote-session guard.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Show-Section -Title 'REMEDIATION: RESTART RDP SERVICE STACK' -Icon 'Gear'

    if ($script:IsRemoteSession -and -not $Force) {
        New-RemediationRecord -Action 'Restart RDP service stack' -Success $true -Skipped `
            -Notes 'Running inside a remote session - this would disconnect you. Re-run with -Force to proceed.'
        return
    }
    if (-not $PSCmdlet.ShouldProcess('TermService stack', 'Restart SessionEnv, UmRdpService, TermService')) {
        New-RemediationRecord -Action 'Restart RDP service stack' -Success $true -Skipped -Notes 'Declined/-WhatIf.'
        return
    }
    foreach ($name in @('UmRdpService', 'SessionEnv')) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            try { Stop-Service -Name $name -Force -ErrorAction Stop } catch { Write-Verbose "Stop $name failed: $($_.Exception.Message)" }
        }
    }
    try {
        Restart-Service -Name TermService -Force -ErrorAction Stop
        New-RemediationRecord -Action 'Restart RDP service stack' -Success $true -Notes 'TermService restarted; helpers cycled.'
    } catch {
        New-RemediationRecord -Action 'Restart RDP service stack' -Success $false -Notes $_.Exception.Message
    }
    foreach ($name in @('SessionEnv', 'UmRdpService')) {
        try { Start-Service -Name $name -ErrorAction SilentlyContinue }
        catch { Write-Verbose "Best-effort start of $name failed: $($_.Exception.Message)" }
    }
}

function Invoke-ForcePrivateNetworkAction {
    <#
    .SYNOPSIS
        -ForcePrivateNetwork implementation: re-categorize non-domain profiles.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Show-Section -Title 'REMEDIATION: NETWORK PROFILE -> PRIVATE' -Icon 'Globe'

    $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq 'Public' })
    if ($profiles.Count -eq 0) {
        New-RemediationRecord -Action 'Set profiles to Private' -Success $true -Skipped -Notes 'No Public profiles found.'
        return
    }
    foreach ($p in $profiles) {
        if (-not $PSCmdlet.ShouldProcess("Interface '$($p.InterfaceAlias)' (network: $($p.Name))", 'Set NetworkCategory Public -> Private')) {
            New-RemediationRecord -Action "Set '$($p.InterfaceAlias)' to Private" -Success $true -Skipped -Notes 'Declined/-WhatIf.'
            continue
        }
        try {
            Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
            New-RemediationRecord -Action "Set '$($p.InterfaceAlias)' to Private" -Success $true
        } catch {
            New-RemediationRecord -Action "Set '$($p.InterfaceAlias)' to Private" -Success $false -Notes $_.Exception.Message
        }
    }
}
#endregion

#region Reporting: JSON / HTML / Summary
# ============================================================================
function Get-SummaryStatistics {
    [CmdletBinding()]
    param()
    $stats = [ordered]@{
        Total        = $script:DiagnosticResults.Count
        Info         = @($script:DiagnosticResults | Where-Object { $_.Severity -eq $script:Severity.Info }).Count
        Warning      = @($script:DiagnosticResults | Where-Object { $_.Severity -eq $script:Severity.Warning }).Count
        Error        = @($script:DiagnosticResults | Where-Object { $_.Severity -eq $script:Severity.Error }).Count
        Critical     = @($script:DiagnosticResults | Where-Object { $_.Severity -eq $script:Severity.Critical }).Count
        TestsTotal   = $script:TestResults.Count
        TestsPassed  = @($script:TestResults | Where-Object { $_.Passed }).Count
        Remediations = $script:RemediationLog.Count
        RemediationsOk = @($script:RemediationLog | Where-Object { $_.Success -and -not $_.Skipped }).Count
        RemediationsFailed = @($script:RemediationLog | Where-Object { -not $_.Success }).Count
    }
    return $stats
}

function Get-FinalExitCode {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Stats)
    if (-not $script:SystemInfo.RDPSupported) { return $script:ExitCode.UnsupportedOs }
    if ($Stats.Critical -gt 0) { return $script:ExitCode.Critical }
    if ($Stats.Error -gt 0) { return $script:ExitCode.Errors }
    return $script:ExitCode.Success
}

function Export-JsonReport {
    <#
    .SYNOPSIS
        Writes the full machine-readable report (-ExportJson).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    try {
        $stats = Get-SummaryStatistics
        $report = [ordered]@{
            tool          = $script:ToolName
            version       = $script:ToolVersion.ToString()
            reportId      = $script:ReportId
            generatedUtc  = [datetime]::UtcNow.ToString('o')
            durationSec   = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 2)
            computer      = $script:SystemInfo.ComputerName
            systemInfo    = $script:SystemInfo
            parameters    = ($PSBoundParameters.Keys | Sort-Object)
            summary       = $stats
            exitCode      = (Get-FinalExitCode -Stats $stats)
            results       = @($script:DiagnosticResults | ForEach-Object {
                    [ordered]@{
                        component = $_.Component; status = $_.Status; details = $_.Details
                        remedy = $_.Remedy; category = $_.Category
                        severity = (Get-SeverityName -Severity $_.Severity); severityLevel = $_.Severity
                        time = $_.Time
                    }
                })
            remediations  = @($script:RemediationLog)
            tests         = @($script:TestResults)
        }
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $dir = Split-Path -Path $resolved -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -Path $dir -ItemType Directory -Force }
        $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resolved -Encoding utf8
        New-DiagnosticResult -Component 'JSON report' -Status 'EXPORTED' -Details $resolved -Category 'Reporting' -Severity $script:Severity.Info
        return $resolved
    } catch {
        New-DiagnosticResult -Component 'JSON report' -Status 'EXPORT FAILED' -Details $_.Exception.Message -Category 'Reporting' -Severity $script:Severity.Warning
        return $null
    }
}

function ConvertTo-HtmlSafe {
    [CmdletBinding()]
    param([AllowNull()][AllowEmptyString()][string] $Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Export-HtmlReport {
    <#
    .SYNOPSIS
        Writes the styled, self-contained HTML report (-ExportReport).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    Show-Section -Title 'EXPORT HTML REPORT' -Icon 'Report'
    $sb = [System.Text.StringBuilder]::new()
    $stats = Get-SummaryStatistics
    $exitCode = Get-FinalExitCode -Stats $stats
    $successRate = if ($stats.Total -gt 0) { [math]::Round((($stats.Info) / $stats.Total) * 100, 1) } else { 0 }
    $duration = (Get-Date) - $script:StartTime

    $css = @'
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; color:#1a202c; }
.container { max-width: 1200px; margin: 0 auto; background: white; padding: 24px; border-radius: 10px; box-shadow: 0 2px 12px rgba(0,0,0,.12); }
.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 22px; border-radius: 10px; margin-bottom: 20px; }
.header h1 { margin: 0 0 6px 0; font-size: 26px; }
.header p { margin: 2px 0; opacity: .92; }
.summary { background: #edf2f7; padding: 16px; border-radius: 8px; margin-bottom: 22px; }
.kpis { display: flex; flex-wrap: wrap; gap: 10px; margin: 10px 0; }
.kpi { flex: 1 1 120px; background: white; border-radius: 8px; padding: 10px 14px; border-left: 5px solid #a0aec0; }
.kpi b { font-size: 22px; display: block; }
.kpi.ok { border-left-color: #38a169; } .kpi.warn { border-left-color: #d69e2e; }
.kpi.err { border-left-color: #e53e3e; } .kpi.crit { border-left-color: #9b2c2c; }
.progress-bar { height: 18px; background: #e2e8f0; border-radius: 9px; overflow: hidden; margin: 10px 0; }
.progress-fill { height: 100%; background: linear-gradient(90deg, #48bb78, #38a169); }
.section { margin-bottom: 26px; }
.section-title { background: #2d3748; color: white; padding: 10px 15px; border-radius: 6px; margin-bottom: 10px; font-weight: 600; }
table { width: 100%; border-collapse: collapse; font-size: 14px; }
th { background: #4a5568; color: white; padding: 9px 10px; text-align: left; }
td { padding: 8px 10px; border-bottom: 1px solid #e2e8f0; vertical-align: top; }
tr:nth-child(even) td { background: #f7fafc; }
.badge { display: inline-block; padding: 3px 9px; border-radius: 12px; font-size: 12px; font-weight: 600; white-space: nowrap; }
.status-ok { background-color: #c6f6d5; color: #22543d; }
.status-warning { background-color: #feebc8; color: #744210; }
.status-error { background-color: #fed7d7; color: #742a2a; }
.status-critical { background-color: #feb2b2; color: #742a2a; font-weight: bold; }
.remedy { color: #2b6cb0; font-size: 12.5px; }
code, .mono { font-family: Consolas, 'Courier New', monospace; font-size: 12.5px; background:#edf2f7; padding:1px 5px; border-radius:4px; }
.footer { margin-top: 30px; padding-top: 16px; border-top: 1px solid #e2e8f0; color: #718096; font-size: 12px; }
.verdict { font-size: 17px; font-weight: 700; padding: 10px 14px; border-radius: 8px; margin: 8px 0; }
.verdict.ok { background:#f0fff4; color:#22543d; border:1px solid #9ae6b4; }
.verdict.warn { background:#fffff0; color:#744210; border:1px solid #f6e05e; }
.verdict.err { background:#fff5f5; color:#742a2a; border:1px solid #feb2b2; }
'@

    $null = $sb.AppendLine('<!DOCTYPE html>')
    $null = $sb.AppendLine('<html lang="en"><head><meta charset="utf-8">')
    $null = $sb.AppendLine("<title>RDP Diagnostic Report - $(ConvertTo-HtmlSafe $script:SystemInfo.ComputerName)</title>")
    $null = $sb.AppendLine("<style>$css</style></head><body><div class=`"container`">")

    # Header
    $null = $sb.AppendLine("<div class=`"header`"><h1>RDP Diagnostic Report</h1>")
    $null = $sb.AppendLine("<p>Computer: <b>$(ConvertTo-HtmlSafe $script:SystemInfo.ComputerName)</b> | Generated: $([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) | Report ID: $($script:ReportId)</p>")
    $null = $sb.AppendLine("<p>Tool: $(ConvertTo-HtmlSafe $script:ToolName) v$($script:ToolVersion) | PowerShell $($PSVersionTable.PSVersion) | Duration: $($duration.ToString('hh\:mm\:ss'))</p>")
    $null = $sb.AppendLine("<p>Parameters: <span class=`"mono`">$(ConvertTo-HtmlSafe (($PSBoundParameters.Keys | Sort-Object) -join ' -'))</span></p></div>")

    # Verdict
    $verdictClass = if ($stats.Critical -gt 0) { 'err' } elseif ($stats.Error -gt 0) { 'err' } elseif ($stats.Warning -gt 0) { 'warn' } else { 'ok' }
    $verdictText = if (-not $script:SystemInfo.RDPSupported) { 'UNSUPPORTED WINDOWS EDITION - RDP server cannot be hosted' }
                   elseif ($stats.Critical -gt 0) { 'CRITICAL - RDP will NOT work until the issues below are resolved' }
                   elseif ($stats.Error -gt 0) { 'DEGRADED - RDP may not work reliably' }
                   elseif ($stats.Warning -gt 0) { 'FUNCTIONAL WITH WARNINGS - review recommended' }
                   else { 'READY - all critical RDP checks passed' }
    $null = $sb.AppendLine("<div class=`"verdict $verdictClass`">$(ConvertTo-HtmlSafe $verdictText)</div>")

    # Summary KPIs
    $null = $sb.AppendLine('<div class="summary"><h3 style="margin-top:0">Diagnostic Summary</h3><div class="kpis">')
    $null = $sb.AppendLine("<div class=`"kpi`"><b>$($stats.Total)</b>checks</div>")
    $null = $sb.AppendLine("<div class=`"kpi ok`"><b>$($stats.Info)</b>passed</div>")
    $null = $sb.AppendLine("<div class=`"kpi warn`"><b>$($stats.Warning)</b>warnings</div>")
    $null = $sb.AppendLine("<div class=`"kpi err`"><b>$($stats.Error)</b>errors</div>")
    $null = $sb.AppendLine("<div class=`"kpi crit`"><b>$($stats.Critical)</b>critical</div>")
    $null = $sb.AppendLine("<div class=`"kpi`"><b>$($stats.RemediationsOk)/$($stats.Remediations)</b>fixes applied</div>")
    $null = $sb.AppendLine('</div>')
    $null = $sb.AppendLine("<div class=`"progress-bar`"><div class=`"progress-fill`" style=`"width: $successRate%`"></div></div>")
    $null = $sb.AppendLine("<p>Pass rate: $successRate% | Exit code: $exitCode</p></div>")

    # System info
    $null = $sb.AppendLine('<div class="section"><div class="section-title">System Information</div><table><tr><th>Property</th><th>Value</th></tr>')
    $sysRows = [ordered]@{
        'Operating System' = $script:SystemInfo.Caption
        'Edition'          = $script:SystemInfo.EditionID
        'Build'            = $script:SystemInfo.Build
        'Architecture'     = $script:SystemInfo.Architecture
        'Hardware'         = "$($script:SystemInfo.Manufacturer) $($script:SystemInfo.Model)"
        'Domain/Workgroup' = $script:SystemInfo.Domain
        'RDP host support' = "$(if ($script:SystemInfo.RDPSupported) { 'SUPPORTED' } else { 'NOT SUPPORTED' }) - $($script:SystemInfo.RdpSupportReason)"
        'IPv4 addresses'   = ($script:SystemInfo.IPv4Addresses -join ', ')
        'RDP port (effective)' = [string](Get-RdpListenerPort)
    }
    foreach ($kv in $sysRows.GetEnumerator()) {
        $null = $sb.AppendLine("<tr><td>$(ConvertTo-HtmlSafe $kv.Key)</td><td>$(ConvertTo-HtmlSafe ([string]$kv.Value))</td></tr>")
    }
    $null = $sb.AppendLine('</table></div>')

    # Results by category
    $categories = $script:DiagnosticResults | Group-Object -Property Category | Sort-Object -Property Name
    foreach ($cat in $categories) {
        $null = $sb.AppendLine("<div class=`"section`"><div class=`"section-title`">$(ConvertTo-HtmlSafe $cat.Name.ToUpperInvariant()) ($($cat.Count) checks)</div>")
        $null = $sb.AppendLine('<table><tr><th style="width:24%">Component</th><th style="width:16%">Status</th><th>Details</th><th>Remedy</th><th style="width:9%">Time</th></tr>')
        foreach ($r in ($cat.Group | Sort-Object -Property Severity -Descending)) {
            $cls = switch ($r.Severity) {
                $script:Severity.Info     { 'status-ok' }
                $script:Severity.Warning  { 'status-warning' }
                $script:Severity.Error    { 'status-error' }
                $script:Severity.Critical { 'status-critical' }
                default { '' }
            }
            $sevName = Get-SeverityName -Severity $r.Severity
            $null = $sb.AppendLine("<tr><td>$(ConvertTo-HtmlSafe $r.Component)</td><td><span class=`"badge $cls`">$(ConvertTo-HtmlSafe $r.Status)</span><br><small>$sevName</small></td><td>$(ConvertTo-HtmlSafe $r.Details)</td><td class=`"remedy`">$(ConvertTo-HtmlSafe $r.Remedy)</td><td class=`"mono`">$($r.Time)</td></tr>")
        }
        $null = $sb.AppendLine('</table></div>')
    }

    # Remediations
    if ($script:RemediationLog.Count -gt 0) {
        $null = $sb.AppendLine("<div class=`"section`"><div class=`"section-title`">Remediation Actions ($($script:RemediationLog.Count))</div>")
        $null = $sb.AppendLine('<table><tr><th>Action</th><th style="width:12%">Result</th><th>Notes</th><th style="width:9%">Time</th></tr>')
        foreach ($m in $script:RemediationLog) {
            $resText = if ($m.Skipped) { 'SKIPPED' } elseif ($m.Success) { 'SUCCESS' } else { 'FAILED' }
            $resCls = if ($m.Skipped) { 'status-warning' } elseif ($m.Success) { 'status-ok' } else { 'status-error' }
            $null = $sb.AppendLine("<tr><td>$(ConvertTo-HtmlSafe $m.Action)</td><td><span class=`"badge $resCls`">$resText</span></td><td>$(ConvertTo-HtmlSafe $m.Notes)</td><td class=`"mono`">$($m.Time)</td></tr>")
        }
        $null = $sb.AppendLine('</table></div>')
    }

    # Connection info
    $port = Get-RdpListenerPort
    $connectHost = if ($script:SystemInfo.IPv4Addresses.Count -gt 0) { $script:SystemInfo.IPv4Addresses[0] } else { $script:SystemInfo.ComputerName }
    $mstsc = if ($port -eq 3389) { "mstsc /v:$connectHost" } else { "mstsc /v:${connectHost}:$port" }
    $null = $sb.AppendLine('<div class="section"><div class="section-title">How to connect</div>')
    $null = $sb.AppendLine("<p>From another machine: <code>$(ConvertTo-HtmlSafe $mstsc)</code> (NLA: $(if ($DisableNLA) { 'disabled by request' } else { 'recommended/enforced' }))</p></div>")

    # Footer
    $null = $sb.AppendLine("<div class=`"footer`"><p>Generated by $(ConvertTo-HtmlSafe $script:ToolName) v$($script:ToolVersion) - $(ConvertTo-HtmlSafe $script:ToolRepoUrl)</p>")
    $null = $sb.AppendLine('<p>This report contains diagnostic information only. Verify configurations before applying changes in production.</p></div>')
    $null = $sb.AppendLine('</div></body></html>')

    try {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $dir = Split-Path -Path $resolved -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -Path $dir -ItemType Directory -Force }
        [System.IO.File]::WriteAllText($resolved, $sb.ToString(), [System.Text.UTF8Encoding]::new($true))
        New-DiagnosticResult -Component 'HTML report' -Status 'EXPORTED' -Details $resolved -Category 'Reporting' -Severity $script:Severity.Info
        Show-Line -Text ("  {0} Report written: {1}" -f $script:Icons['Ok'], $resolved) -Color 'Success' -Force

        if (-not $NoBrowser -and -not $Quiet) {
            try { Start-Process -FilePath $resolved -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not auto-open report: $($_.Exception.Message)" }
        }
        return $resolved
    } catch {
        New-DiagnosticResult -Component 'HTML report' -Status 'EXPORT FAILED' -Details $_.Exception.Message -Category 'Reporting' -Severity $script:Severity.Warning
        return $null
    }
}

function Show-UnsupportedEditionGuidance {
    [CmdletBinding()]
    param()
    Show-Section -Title 'RDP SERVER NOT SUPPORTED ON THIS EDITION' -Icon 'Err'
    Show-Line -Text ("  Edition: {0} - {1}" -f $script:SystemInfo.EditionID, $script:SystemInfo.RdpSupportReason) -Color 'Error' -Force
    Show-Line -Text '' -Force
    Show-Line -Text '  WHAT THIS MEANS' -Color 'Info' -Force
    Show-Line -Text '   - This PC CANNOT accept incoming RDP connections (Microsoft licensing limit).' -Force
    Show-Line -Text '   - It CAN still act as an RDP CLIENT: mstsc to Pro/Enterprise/Server machines works.' -Force
    Show-Line -Text '   - This tool can still probe REMOTE RDP hosts:  .\RDP-Tool.ps1 -TestRdpTarget "host:port"' -Force
    Show-Line -Text '' -Force
    Show-Line -Text '  YOUR OPTIONS' -Color 'Info' -Force
    Show-Line -Text '   1. Upgrade to Windows 10/11 Pro (Microsoft Store / retail / volume licensing).' -Force
    Show-Line -Text '   2. Free built-in alternative: Quick Assist (Windows key -> type "Quick Assist").' -Force
    Show-Line -Text '   3. Third-party remote access: Windows App, TeamViewer, AnyDesk, RustDesk, Parsec.' -Force
    Show-Line -Text '' -Force
    Show-Line -Text '  NOTE: Third-party "RDP unlockers" for Home editions violate the Windows EULA,' -Color 'Warning' -Force
    Show-Line -Text '        break with every cumulative update and are a security risk. Not recommended.' -Color 'Warning' -Force
}

function Show-ExecutiveSummary {
    <#
    .SYNOPSIS
        Final console summary: statistics, verdict, top issues with remedies,
        connection information and next steps. Returns the process exit code.
    #>
    [CmdletBinding()]
    param()

    Show-Section -Title 'EXECUTIVE SUMMARY' -Icon 'Summary'
    $stats = Get-SummaryStatistics
    $exitCode = Get-FinalExitCode -Stats $stats
    $duration = (Get-Date) - $script:StartTime

    Show-Line -Text ("  Checks run      : {0}   (OK: {1} | WARN: {2} | ERR: {3} | CRIT: {4})" -f $stats.Total, $stats.Info, $stats.Warning, $stats.Error, $stats.Critical) -Force
    Show-Line -Text ("  Probes passed   : {0}/{1}" -f $stats.TestsPassed, $stats.TestsTotal) -Force
    if ($stats.Remediations -gt 0) {
        Show-Line -Text ("  Fixes applied   : {0} ok, {1} failed, {2} total logged" -f $stats.RemediationsOk, $stats.RemediationsFailed, $stats.Remediations) -Force
    }
    Show-Line -Text ("  Duration        : {0:hh\:mm\:ss}" -f $duration) -Force
    Show-Line -Text '' -Force

    # Verdict
    if (-not $script:SystemInfo.RDPSupported) {
        Show-Line -Text ("  {0} UNSUPPORTED EDITION - this machine cannot host RDP (exit 3)" -f $script:Icons['Err']) -Color 'Error' -Force
    } elseif ($stats.Critical -gt 0) {
        Show-Line -Text ("  {0} CRITICAL - RDP will NOT work until resolved (exit 1)" -f $script:Icons['Crit']) -Color 'Error' -Force
    } elseif ($stats.Error -gt 0) {
        Show-Line -Text ("  {0} DEGRADED - RDP may not work reliably (exit 2)" -f $script:Icons['Err']) -Color 'Error' -Force
    } elseif ($stats.Warning -gt 0) {
        Show-Line -Text ("  {0} FUNCTIONAL WITH WARNINGS - review the items below (exit 0)" -f $script:Icons['Warn']) -Color 'Warning' -Force
    } else {
        Show-Line -Text ("  {0} READY - all critical RDP checks passed (exit 0)" -f $script:Icons['Ok']) -Color 'Success' -Force
    }

    # Top issues with remedies
    $issues = @($script:DiagnosticResults | Where-Object { $_.Severity -ge $script:Severity.Warning } | Sort-Object -Property Severity -Descending | Select-Object -First 6)
    if ($issues.Count -gt 0) {
        Show-Line -Text '' -Force
        Show-Line -Text '  TOP ISSUES:' -Color 'Info' -Force
        foreach ($i in $issues) {
            $color = switch ($i.Severity) {
                $script:Severity.Critical { 'Error' }
                $script:Severity.Error    { 'Error' }
                default                   { 'Warning' }
            }
            Show-Line -Text ("   {0} {1}: {2}" -f $script:Icons['Bullet'], $i.Component, $i.Status) -Color $color -Force
            if ($i.Details) { Show-Line -Text ("      {0}" -f $i.Details) -Color 'Verbose' -Force }
            if ($i.Remedy)  { Show-Line -Text ("      Fix: {0}" -f (($i.Remedy -split "`r?`n")[0])) -Color 'Info' -Force }
        }
    }

    # Connection info
    if ($script:SystemInfo.RDPSupported) {
        Show-Line -Text '' -Force
        Show-Line -Text '  CONNECT TO THIS MACHINE:' -Color 'Info' -Force
        $port = Get-RdpListenerPort
        $connectHost = if ($script:SystemInfo.IPv4Addresses.Count -gt 0) { $script:SystemInfo.IPv4Addresses[0] } else { $script:SystemInfo.ComputerName }
        $mstsc = if ($port -eq 3389) { "mstsc /v:$connectHost" } else { "mstsc /v:${connectHost}:$port" }
        Show-Line -Text ("   {0} {1}" -f $script:Icons['Arrow'], $mstsc) -Color 'Success' -Force
        Show-Line -Text ("      (hostname: {0} | port: {1} | NLA: {2})" -f $script:SystemInfo.ComputerName, $port, $(if ($DisableNLA) { 'disabled by request' } else { 'enforced' })) -Color 'Verbose' -Force
    }

    # Next steps
    Show-Line -Text '' -Force
    Show-Line -Text '  NEXT STEPS:' -Color 'Info' -Force
    if ($stats.Critical -gt 0 -or $stats.Error -gt 0) {
        Show-Line -Text '   1. Apply the fixes above (or re-run with -EnableRDP -Force for full auto-repair).' -Force
        Show-Line -Text '   2. Re-run the tool to verify; use -ExportJson for change tracking.' -Force
    } elseif ($stats.Warning -gt 0) {
        Show-Line -Text '   1. Review warnings; most are hardening opportunities, not outages.' -Force
        Show-Line -Text '   2. Verify connectivity from another machine with the mstsc command above.' -Force
    } else {
        Show-Line -Text '   1. Verify from another machine: the mstsc command above.' -Force
        Show-Line -Text '   2. Keep the host patched; re-run periodically or from CI with -ExportJson.' -Force
    }
    Show-Line -Text '   * Security baseline: NLA on, strong passwords, firewall scoped to known subnets,' -Color 'Verbose' -Force
    Show-Line -Text '     never expose 3389 directly to the internet (use RD Gateway / VPN / Windows App).' -Color 'Verbose' -Force

    return $exitCode
}
#endregion

#region Diagnostic Pipeline
# ============================================================================
# Ordered execution of all checks. Two phases: prerequisites (with early-exit
# semantics) and the full diagnostic sweep. Every check is individually
# guarded so one broken subsystem cannot abort the run.
# ============================================================================
function Invoke-PrerequisitePhase {
    <#
    .SYNOPSIS
        Elevation, inventory, edition support, pending reboot, binaries.
    .OUTPUTS
        'Continue' | 'ElevationRequired' | 'UnsupportedEdition'
    #>
    [CmdletBinding()]
    param()

    Show-Section -Title 'PREREQUISITES' -Icon 'Flask'
    if (-not (Test-AdminPrivileges)) { return 'ElevationRequired' }

    Show-Section -Title 'SYSTEM INVENTORY' -Icon 'Tag'
    Invoke-Check -Name 'System Inventory' -ScriptBlock { Get-SystemInventory }

    if (-not $script:SystemInfo.RDPSupported) { return 'UnsupportedEdition' }

    Invoke-Check -Name 'Pending Reboot' -ScriptBlock { Test-PendingRebootState }
    Invoke-Check -Name 'RDP Binaries' -ScriptBlock { Test-RdpBinaries }
    Invoke-Check -Name 'Windows Feature State' -ScriptBlock { Test-RdpWindowsFeature }
    return 'Continue'
}

function Invoke-DiagnosticPhase {
    <#
    .SYNOPSIS
        The full diagnostic sweep over configuration, connectivity, security,
        performance and logs.
    #>
    [CmdletBinding()]
    param()

    $port = Get-RdpListenerPort
    $script:EffectiveRdpPort = $port

    Invoke-Check -Name 'Registry Configuration' -ScriptBlock { Test-RdpRegistrySettings }
    Invoke-Check -Name 'Group Policy Overview' -ScriptBlock { Test-RdpGroupPolicyOverview }
    Invoke-Check -Name 'Service Stack' -ScriptBlock { $null = Test-RdpServices }
    Invoke-Check -Name 'Firewall Configuration' -ScriptBlock { $null = Test-FirewallConfiguration -Port $port }
    Invoke-Check -Name 'Network Configuration' -ScriptBlock { Test-NetworkConfiguration }
    Invoke-Check -Name 'Listener & Ports' -ScriptBlock { Test-ListenerAndPorts -Port $port }
    Invoke-Check -Name 'Local RDP Handshake' -ScriptBlock { Test-LocalRdpHandshake -Port $port }
    Invoke-Check -Name 'TLS Certificate' -ScriptBlock { Test-RdpCertificate }
    Invoke-Check -Name 'User Permissions' -ScriptBlock { Test-UserPermissions }
    Invoke-Check -Name 'Security Posture' -ScriptBlock { Test-SecurityPosture }
    Invoke-Check -Name 'Resource Readiness' -ScriptBlock { Test-ResourceReadiness }
    Invoke-Check -Name 'Event Log Insights' -ScriptBlock { Get-RdpEventInsights }

    if ($TestExternal) {
        Invoke-Check -Name 'External Connectivity' -ScriptBlock { Test-ExternalConnectivity }
    }
    if ($TestRdpTarget) {
        Invoke-Check -Name 'Remote RDP Probe' -ScriptBlock { $null = Test-RemoteRdpTarget -Target $TestRdpTarget }
    }
    if ($ShowSessions) {
        Invoke-Check -Name 'Terminal Sessions' -ScriptBlock { Show-RdpSessions }
    }
}

function Invoke-RemediationPhase {
    <#
    .SYNOPSIS
        Executes the requested mutating actions in a safe order.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]] $Actions)

    Show-Section -Title 'REMEDIATION PLAN' -Subtitle ($Actions -join ' + ') -Icon 'Gear'
    if ($WhatIfPreference) {
        Show-Line -Text '  -WhatIf is active: every change below is simulated, nothing will be modified.' -Color 'Warning' -Force
    }

    if ($DisableRDP) {
        Invoke-RdpDisable
    } elseif ($EnableRDP) {
        Invoke-RdpEnable
    } else {
        if ($SetPort -gt 0) { Invoke-RdpPortChange -Port $SetPort }
        if ($DisableNLA)    { Invoke-ApplyNlaSetting }
    }

    if ($AddUser.Count -gt 0 -and -not $DisableRDP) {
        Add-RdpGroupMembers -Users $AddUser
    }
    if ($ForcePrivateNetwork) {
        Invoke-ForcePrivateNetworkAction
    }
    if ($RestartServices) {
        Invoke-RdpServiceRestart
    }
}

function Invoke-ReportPhase {
    <#
    .SYNOPSIS
        Exports JSON/HTML reports when requested.
    #>
    [CmdletBinding()]
    param()
    if ($ExportJson)   { $null = Export-JsonReport -Path $ExportJson }
    if ($ExportReport) { $null = Export-HtmlReport -Path $ExportReport }
}
#endregion

#region Main
# ============================================================================
function Invoke-Main {
    [CmdletBinding()]
    param()

    $exitCode = $script:ExitCode.Success
    try {
        Initialize-ConsoleEnvironment

        # ---- Fast paths that need no Windows APIs (work on any platform) ----
        if ($Help) { Show-ToolHelp; return $script:ExitCode.Success }
        if ($Version) { Show-ToolVersionInfo; return $script:ExitCode.Success }

        Initialize-Logging

        if (-not (Test-ParameterCombination)) { return $script:ExitCode.Prerequisite }

        # Update engine talks plain HTTPS - usable even before the OS guard.
        if ($CheckUpdate) { return (Invoke-UpdateCheck) }
        if ($Update)      { return (Invoke-ToolSelfUpdate) }

        # Platform guard (everything below drives Windows-only APIs).
        if (-not $script:IsWindowsOs) {
            Show-Line -Text '' -Force
            Show-Line -Text '  UNSUPPORTED PLATFORM' -Color 'Error' -Force
            Show-Line -Text '  RDP-Tool requires Windows 10/11 or Windows Server: it drives the RDP stack,' -Force
            Show-Line -Text '  registry, CIM/WMI and NetSecurity cmdlets, which exist only on Windows.' -Force
            Show-Line -Text ("  (PowerShell {0}, platform '{1}' detected.)" -f $PSVersionTable.PSVersion, $PSVersionTable.Platform) -Color 'Verbose' -Force
            return $script:ExitCode.Prerequisite
        }

        $script:IsAdmin = Test-RunningElevated
        $script:IsRemoteSession = Test-InRemoteSession

        if ($Elevate) {
            if (Invoke-ElevatedRelaunch) { return $script:ExitCode.Success }
        }

        # ---- Normal run ------------------------------------------------------
        Show-ToolBanner
        $actions = @(Get-RequestedActionList)
        $modeText = if ($actions.Count -gt 0) { "REMEDIATION ($($actions -join ' + '))" }
                    elseif ($DiagnoseOnly)   { 'DIAGNOSTIC ONLY (read-only)' }
                    else                     { 'FULL DIAGNOSTIC (read-only by default)' }
        Show-Line -Text ("  Mode: {0} | WhatIf: {1} | Quiet: {2}" -f $modeText, $WhatIfPreference, $script:QuietMode) -Color 'Info' -Force

        # ---- Quick path: session listing only --------------------------------
        if ($ShowSessions -and $actions.Count -eq 0 -and -not $TestRdpTarget -and -not $TestExternal -and -not $DiagnoseOnly) {
            Show-RdpSessions
            Invoke-ReportPhase
            return $script:ExitCode.Success
        }

        # ---- Quick path: remote RDP probe only -------------------------------
        if ($TestRdpTarget -and $actions.Count -eq 0 -and -not $DiagnoseOnly -and -not $ShowSessions -and -not $TestExternal) {
            $probeOk = Test-RemoteRdpTarget -Target $TestRdpTarget
            Invoke-ReportPhase
            if ($probeOk) { return $script:ExitCode.Success } else { return $script:ExitCode.Errors }
        }

        # ---- Phase 0: prerequisites -------------------------------------------
        $prereq = Invoke-PrerequisitePhase
        switch ($prereq) {
            'ElevationRequired' {
                Invoke-ReportPhase
                return $script:ExitCode.Prerequisite
            }
            'UnsupportedEdition' {
                Show-UnsupportedEditionGuidance
                Invoke-ReportPhase
                return $script:ExitCode.UnsupportedOs
            }
        }

        # ---- Phase 1: remediation (before diagnostics so results reflect changes)
        if ($actions.Count -gt 0) {
            Invoke-RemediationPhase -Actions $actions
        }

        # ---- Phase 2: full diagnostic sweep ------------------------------------
        Invoke-DiagnosticPhase

        # ---- Phase 3: reports + summary -----------------------------------------
        Invoke-ReportPhase
        $exitCode = Show-ExecutiveSummary
        return $exitCode
    } catch {
        $rule = '!' * 78
        Show-Line -Text '' -Force
        Show-Line -Text $rule -Color 'Error' -Force
        Show-Line -Text 'UNHANDLED SCRIPT ERROR' -Color 'Error' -Force
        Show-Line -Text $rule -Color 'Error' -Force
        Show-Line -Text ("  Where  : {0}:{1}" -f $_.InvocationInfo.ScriptName, $_.InvocationInfo.ScriptLineNumber) -Color 'Error' -Force
        Show-Line -Text ("  What   : {0}" -f $_.Exception.Message) -Color 'Error' -Force
        Show-Line -Text ("  Line   : {0}" -f $_.InvocationInfo.Line.Trim()) -Color 'Verbose' -Force
        if ($VerbosePreference -eq 'Continue') {
            Show-Line -Text ("  Stack  :`n{0}" -f $_.ScriptStackTrace) -Color 'Verbose' -Force
        }
        Show-Line -Text '' -Force
        Show-Line -Text '  Re-run with -Verbose for details; attach an -ExportReport file when filing a bug:' -Color 'Verbose' -Force
        Show-Line -Text ("  {0}" -f "$($script:ToolRepoUrl)/issues") -Color 'Info' -Force
        Add-LogEntry -Level 'ERROR' -Message ("Unhandled error: $($_.Exception.Message) at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)`n$($_.ScriptStackTrace)")
        return $script:ExitCode.ScriptError
    }
}

# ---------------------------------------------------------------------------
# Entry point. Dot-source guard: when $env:RDPDIAG_LIB is set the script only
# defines functions (used by the Pester test-suite) and performs no actions.
# ---------------------------------------------------------------------------
if (-not $env:RDPDIAG_LIB) {
    $script:FinalExitCode = Invoke-Main
    Add-LogEntry -Level 'INFO' -Message ("Completed with exit code {0} after {1:hh\:mm\:ss}" -f $script:FinalExitCode, ([datetime]::Now - $script:StartTime))
    Show-Line -Text '' -Force
    Show-Line -Text ("{0} Done. Exit code: {1}" -f $(if ($script:FinalExitCode -eq 0) { $script:Icons['Ok'] } else { $script:Icons['Warn'] }), $script:FinalExitCode) -Color $(if ($script:FinalExitCode -eq 0) { 'Success' } else { 'Warning' }) -Force
    exit $script:FinalExitCode
}
#endregion
