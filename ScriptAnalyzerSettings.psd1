# PSScriptAnalyzer settings for RDP-Tool.ps1
# Used locally and by the CI workflow (.github/workflows/ci.yml).
#
# Policy: enforce semantic correctness rules (default set) at Error/Warning
# severity. Formatting rules (PSPlaceCloseBrace, PSAlignAssignmentStatement,
# PSUseConsistentIndentation) are deliberately NOT enabled - the script uses
# aligned literal blocks and one-line guards for readability.
@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # The tool is an interactive console application; direct host output is
        # the intended UX (structured data goes to the JSON/HTML exporters).
        'PSAvoidUsingWriteHost'

        # Script parameters ARE consumed by the pipeline functions; the rule's
        # heuristic misses usages inside guarded scriptblocks and produces
        # false positives for script-level param() blocks.
        'PSReviewUnusedParameter'

        # Diagnostic function names intentionally use plural nouns because they
        # operate on collections (Test-RdpServices, Get-RdpSessions, ...).
        'PSUseSingularNouns'

        # New-DiagnosticResult / New-RemediationRecord / New-TestRecord only
        # append in-memory records - they do not change system state, so
        # ShouldProcess would add noise without safety.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
