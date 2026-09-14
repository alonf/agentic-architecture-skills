#Requires -Version 7.0
<#
.SYNOPSIS
    Parses the RESULT lines emitted by tests/install/run-install.sh and judges the set as a whole.

.DESCRIPTION
    The container script prints one line per install path in the form

        RESULT path=<p> blocking=<yes|no> status=<pass|fail> reason=<code|-> elapsed_ms=<n> skills=<k>/<n> inventory=<k>/<n> revision=<sha|unknown> digest=<sha256|unknown>

    Every value is whitespace-free by contract, so the line is a sequence of key=value tokens and nothing
    else. Anything that is not such a token is a parse error, not something to skip quietly: a record
    that dropped a field would misreport the run.

    Test-InstallResultSet judges the whole run: every expected path must appear exactly once, every
    blocking path must have passed, every blocking path must be BOUND to the expected tree, and the
    container must have exited 0. A run that produced no RESULT lines at all, or half of them, is a
    failure - the container exiting 0 is not evidence on its own.

    Binding: the hosts install from the source repository's default branch and take no ref, so what
    they installed is not necessarily what the caller checked out. A blocking path is bound when its
    installed content digest equals the expected digest AND, where the host exposed the revision it
    cloned, that revision equals the expected one. A host that exposes no revision is bound by the
    digest alone; a digest mismatch is never excused. All failure paths are proven in Test-Checks.ps1,
    because a passing run never exercises them.

.EXAMPLE
    . ./eng/ConvertFrom-InstallResult.ps1
    $results = $log | Where-Object { $_ -match '^RESULT\b' } | ForEach-Object { ConvertFrom-InstallResult -Line $_ }
    Test-InstallResultSet -Results $results -ExpectedPaths @('claude-code', 'copilot-cli') -ContainerExitCode 0 -ExpectedRevision $sha -ExpectedDigest $digest
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredResultFields = @('path', 'blocking', 'status', 'reason', 'elapsed_ms', 'skills', 'inventory', 'revision', 'digest')
$script:UnknownValue = 'unknown'

function ConvertFrom-InstallResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][string] $Line)

    if ($Line -notmatch '^RESULT\s+(\S.*)$') { throw "Not a well-formed RESULT line: '$Line'." }
    $fields = [ordered]@{}
    foreach ($token in ($Matches[1].Trim() -split '\s+')) {
        if ($token -notmatch '^([A-Za-z_]+)=(\S+)$') { throw "RESULT token is not key=value: '$token' in '$Line'." }
        if ($fields.Contains($Matches[1])) { throw "RESULT field repeated: '$($Matches[1])' in '$Line'." }
        $fields[$Matches[1]] = $Matches[2]
    }
    foreach ($required in $script:RequiredResultFields) {
        if (-not $fields.Contains($required)) { throw "RESULT line missing '$required': '$Line'." }
    }
    if ($fields['elapsed_ms'] -notmatch '^\d+$') { throw "RESULT elapsed_ms is not an integer: '$($fields['elapsed_ms'])'." }
    if ($fields['status'] -cnotin @('pass', 'fail')) { throw "RESULT status is not pass|fail: '$($fields['status'])'." }
    if ($fields['blocking'] -cnotin @('yes', 'no')) { throw "RESULT blocking is not yes|no: '$($fields['blocking'])'." }
    if ($fields['revision'] -cne $script:UnknownValue -and $fields['revision'] -notmatch '^[0-9a-f]{40}$') { throw "RESULT revision is not a commit SHA or 'unknown': '$($fields['revision'])'." }
    if ($fields['digest'] -cne $script:UnknownValue -and $fields['digest'] -notmatch '^[0-9a-f]{64}$') { throw "RESULT digest is not a SHA-256 or 'unknown': '$($fields['digest'])'." }
    [pscustomobject]$fields
}

function Get-InstallBindingReason {
    <#
      Returns the reason one result is NOT bound to the expected tree, or $null when it is. The digest
      must match whenever the skills were found; the revision must match whenever the host exposed one.
      Neither expectation may be empty: an empty expected digest would let a mismatch pass as "no
      comparison", which is the defect this function exists to prevent.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][pscustomobject] $Result,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $ExpectedRevision,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string] $ExpectedDigest
    )
    if ($Result.digest -ceq $script:UnknownValue) { return "installed content could not be digested (skills not all on disk)" }
    if ($Result.digest -cne $ExpectedDigest) { return "installed content digest $($Result.digest.Substring(0, 12)) is not the expected $($ExpectedDigest.Substring(0, 12))" }
    if ($Result.revision -ceq $script:UnknownValue) { return $null }
    if ($Result.revision -cne $ExpectedRevision) { return "installed revision $($Result.revision.Substring(0, 7)) is not the expected $($ExpectedRevision.Substring(0, 7))" }
    $null
}

function Test-InstallResultSet {
    <#
      Returns @{ Pass = bool; Reasons = string[] }. Pass requires: every expected path present exactly
      once and nothing unexpected, every blocking path 'pass', every blocking path bound to the expected
      revision/digest, container exit code 0. Non-blocking paths are judged for binding too, but only
      as recorded reasons that do not fail the run.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()][object[]] $Results = @(),
        [Parameter(Mandatory)][string[]] $ExpectedPaths,
        [Parameter(Mandatory)][int] $ContainerExitCode,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $ExpectedRevision,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string] $ExpectedDigest
    )
    $reasons = [System.Collections.Generic.List[string]]::new()
    $notes = [System.Collections.Generic.List[string]]::new()
    $seen = @($Results | ForEach-Object { $_.path })
    foreach ($expected in $ExpectedPaths) {
        $n = @($seen | Where-Object { $_ -ceq $expected }).Count
        if ($n -eq 0) { $reasons.Add("no RESULT for path '$expected'") }
        elseif ($n -gt 1) { $reasons.Add("path '$expected' reported $n times") }
    }
    foreach ($unexpected in @($seen | Where-Object { $_ -cnotin $ExpectedPaths })) {
        $reasons.Add("unexpected path '$unexpected'")
    }
    foreach ($r in @($Results | Where-Object { $_.blocking -ceq 'yes' -and $_.status -cne 'pass' })) {
        $reasons.Add("blocking path '$($r.path)' failed: $($r.reason)")
    }
    foreach ($r in $Results) {
        $unbound = Get-InstallBindingReason -Result $r -ExpectedRevision $ExpectedRevision -ExpectedDigest $ExpectedDigest
        if (-not $unbound) { continue }
        if ($r.blocking -ceq 'yes') { $reasons.Add("blocking path '$($r.path)' is not bound to the expected tree: $unbound") }
        else { $notes.Add("path '$($r.path)' (advisory) is not bound to the expected tree: $unbound") }
    }
    if ($ContainerExitCode -ne 0) { $reasons.Add("container exited $ContainerExitCode") }
    [pscustomobject]@{ Pass = ($reasons.Count -eq 0); Reasons = [string[]]$reasons; Notes = [string[]]$notes }
}
