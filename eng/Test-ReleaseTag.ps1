#Requires -Version 7.0
<#
.SYNOPSIS
    Requires a release tag whose peeled commit is HEAD and whose version matches VERSION.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Tag,
    [string] $PackageRoot = (Split-Path -Parent $PSScriptRoot)
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Tag -cnotmatch '^v(?<version>\d+\.\d+\.\d+)$') { throw 'Release ref must be vMAJOR.MINOR.PATCH' }
$version = $Matches.version
if ((Get-Content -LiteralPath (Join-Path $PackageRoot 'VERSION') -Raw).Trim() -cne $version) {
    throw "Tag $Tag does not match VERSION"
}
$tagCommit = & git -C $PackageRoot rev-parse --verify --quiet "refs/tags/$Tag^{commit}"
if ($LASTEXITCODE -ne 0) { throw "Release tag refs/tags/$Tag does not exist or does not point to a commit" }
$headCommit = & git -C $PackageRoot rev-parse --verify HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve release checkout HEAD' }
if ($tagCommit -cne $headCommit) { throw "Release tag refs/tags/$Tag does not resolve to HEAD" }
$version
