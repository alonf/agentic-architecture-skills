#Requires -Version 7.0
<#
.SYNOPSIS
    Parses one RESULT line emitted by tests/install/run-install.sh.

.DESCRIPTION
    The container script prints one line per install path in the form

        RESULT path=<p> blocking=<yes|no> status=<pass|fail> reason=<code|-> elapsed_ms=<n> skills=<k>/<n>

    Every value is whitespace-free by contract, so the line is a sequence of key=value tokens and nothing
    else. Anything that is not such a token is a parse error, not something to skip quietly: a record
    that dropped a field would misreport the run. The failure path is proven in Test-Checks.ps1 with a
    failing RESULT line, because a passing run never exercises it.

.EXAMPLE
    . ./eng/ConvertFrom-InstallResult.ps1
    ConvertFrom-InstallResult -Line 'RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=1904 skills=2/2'
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredResultFields = @('path', 'blocking', 'status', 'reason', 'elapsed_ms', 'skills')

function ConvertFrom-InstallResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][string] $Line)

    if ($Line -notmatch '^RESULT\s+(.*)$') { throw "Not a RESULT line: '$Line'." }
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
    [pscustomobject]$fields
}
