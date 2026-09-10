#Requires -Version 7.0
<#
.SYNOPSIS
    Parses the RESULT lines emitted by tests/install/run-install.sh and judges the set as a whole.

.DESCRIPTION
    The container script prints one line per install path in the form

        RESULT path=<p> blocking=<yes|no> status=<pass|fail> reason=<code|-> elapsed_ms=<n> skills=<k>/<n> inventory=<k>/<n>

    Every value is whitespace-free by contract, so the line is a sequence of key=value tokens and nothing
    else. Anything that is not such a token is a parse error, not something to skip quietly: a record
    that dropped a field would misreport the run.

    Test-InstallResultSet judges the whole run: every expected path must appear exactly once, every
    blocking path must have passed, and the container must have exited 0. A run that produced no RESULT
    lines at all, or half of them, is a failure - the container exiting 0 is not evidence on its own.
    Both failure paths are proven in Test-Checks.ps1, because a passing run never exercises them.

.EXAMPLE
    . ./eng/ConvertFrom-InstallResult.ps1
    $results = $log | Where-Object { $_ -match '^RESULT\b' } | ForEach-Object { ConvertFrom-InstallResult -Line $_ }
    Test-InstallResultSet -Results $results -ExpectedPaths @('claude-code', 'copilot-cli') -ContainerExitCode 0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredResultFields = @('path', 'blocking', 'status', 'reason', 'elapsed_ms', 'skills', 'inventory')

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
    [pscustomobject]$fields
}

function Test-InstallResultSet {
    <#
      Returns @{ Pass = bool; Reasons = string[] }. Pass requires: every expected path present exactly
      once and nothing unexpected, every blocking path 'pass', container exit code 0.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()][object[]] $Results = @(),
        [Parameter(Mandatory)][string[]] $ExpectedPaths,
        [Parameter(Mandatory)][int] $ContainerExitCode
    )
    $reasons = [System.Collections.Generic.List[string]]::new()
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
    if ($ContainerExitCode -ne 0) { $reasons.Add("container exited $ContainerExitCode") }
    [pscustomobject]@{ Pass = ($reasons.Count -eq 0); Reasons = [string[]]$reasons }
}
