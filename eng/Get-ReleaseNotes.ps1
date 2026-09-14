#Requires -Version 7.0
<#
.SYNOPSIS
    Returns only the requested version section, failing on missing, duplicate, or empty notes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string] $Version,
    [string] $ChangelogPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'CHANGELOG.md')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$content = (Get-Content -LiteralPath $ChangelogPath -Raw) -replace "`r`n", "`n"
$heading = '(?m)^## \[' + [regex]::Escape($Version) + '\](?:[^\n]*)$'
$sections = [regex]::Matches($content, $heading)
if ($sections.Count -ne 1) { throw "Changelog must contain exactly one section for $Version" }
$start = $sections[0].Index
$bodyStart = $start + $sections[0].Length
$nextHeading = [regex]::Match($content.Substring($bodyStart), '(?m)^## ')
$end = if ($nextHeading.Success) { $bodyStart + $nextHeading.Index } else { $content.Length }
if ([string]::IsNullOrWhiteSpace($content.Substring($bodyStart, $end - $bodyStart))) {
    throw "Changelog section for $Version is empty"
}
$content.Substring($start, $end - $start).Trim()
