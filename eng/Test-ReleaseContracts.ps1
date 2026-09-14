#Requires -Version 7.0
<#
.SYNOPSIS
    Exercises release tag and changelog contracts in a disposable local repository; never publishes.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$releaseScratch = Join-Path ([IO.Path]::GetTempPath()) ('release-contract-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $releaseScratch
function Invoke-TestGit {
    param([string[]] $GitArguments)
    & git -C $releaseScratch @GitArguments 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Git fixture setup failed: $GitArguments" }
}
function Assert-Rejected {
    param([string] $Name, [scriptblock] $Action, [string] $Reason)
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    if (-not $caught -or $caught -notlike "*$Reason*") { throw "$Name did not reject for '$Reason': $caught" }
    Write-Output "PASS $Name"
}
try {
    Invoke-TestGit @('init', '--quiet')
    Invoke-TestGit @('config', 'user.email', 'fixture@example.invalid')
    Invoke-TestGit @('config', 'user.name', 'Release fixture')
    Set-Content -LiteralPath (Join-Path $releaseScratch 'VERSION') -Value '1.1.0'
    Invoke-TestGit @('add', 'VERSION')
    Invoke-TestGit @('-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'initial')
    Invoke-TestGit @('branch', 'v1.1.0')
    Assert-Rejected 'version-shaped branch is not a tag' {
        & "$PSScriptRoot/Test-ReleaseTag.ps1" -Tag 'v1.1.0' -PackageRoot $releaseScratch
    } 'does not exist'
    Invoke-TestGit @('-c', 'tag.gpgsign=false', 'tag', 'v1.1.0')
    $version = & "$PSScriptRoot/Test-ReleaseTag.ps1" -Tag 'v1.1.0' -PackageRoot $releaseScratch
    if ($version -cne '1.1.0') { throw 'Lightweight tag returned wrong version' }
    Write-Output 'PASS lightweight tag with same-named branch'
    Invoke-TestGit @('tag', '-d', 'v1.1.0')
    Invoke-TestGit @('-c', 'tag.gpgsign=false', 'tag', '-a', 'v1.1.0', '-m', 'annotated')
    $version = & "$PSScriptRoot/Test-ReleaseTag.ps1" -Tag 'v1.1.0' -PackageRoot $releaseScratch
    if ($version -cne '1.1.0') { throw 'Annotated tag returned wrong version' }
    Write-Output 'PASS annotated tag peeled to HEAD'
    Assert-Rejected 'invalid ref text' {
        & "$PSScriptRoot/Test-ReleaseTag.ps1" -Tag 'refs/heads/v1.1.0' -PackageRoot $releaseScratch
    } 'vMAJOR.MINOR.PATCH'
    Assert-Rejected 'version mismatch' {
        & "$PSScriptRoot/Test-ReleaseTag.ps1" -Tag 'v1.0.0' -PackageRoot $releaseScratch
    } 'does not match VERSION'
    Invoke-TestGit @('-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '--quiet', '-m', 'later')
    Assert-Rejected 'tag points to a different commit' {
        & "$PSScriptRoot/Test-ReleaseTag.ps1" -Tag 'v1.1.0' -PackageRoot $releaseScratch
    } 'does not resolve to HEAD'

    $changelog = Join-Path $releaseScratch 'CHANGELOG.md'
    $notes = "# Changelog`n`n## [1.1.0] - 2026-09-14`n`n### Fixed`n`n- Only the new release.`n`n## [1.0.0] - 2026-09-12`n`n- Only the old release.`n"
    foreach ($newline in @("`n", "`r`n")) {
        Set-Content -LiteralPath $changelog -Value $notes.Replace("`n", $newline) -NoNewline
        $body = & "$PSScriptRoot/Get-ReleaseNotes.ps1" -Version '1.1.0' -ChangelogPath $changelog
        if (-not $body.Contains('Only the new release.') -or $body.Contains('1.0.0') -or $body.Contains('Only the old release.')) {
            throw '1.1.0 release body is missing or contains the old section'
        }
        Write-Output "PASS 1.1.0 section isolation with newline length $($newline.Length)"
    }
    $body = & "$PSScriptRoot/Get-ReleaseNotes.ps1" -Version '1.0.0' -ChangelogPath $changelog
    if (-not $body.Contains('Only the old release.') -or $body.Contains('1.1.0')) { throw 'Final section extraction failed' }
    Write-Output 'PASS final changelog section'
    Assert-Rejected 'missing version section' {
        & "$PSScriptRoot/Get-ReleaseNotes.ps1" -Version '1.2.0' -ChangelogPath $changelog
    } 'exactly one section'
    Add-Content -LiteralPath $changelog -Value "`n## [1.1.0] - duplicate`n- Duplicate."
    Assert-Rejected 'duplicate version section' {
        & "$PSScriptRoot/Get-ReleaseNotes.ps1" -Version '1.1.0' -ChangelogPath $changelog
    } 'exactly one section'
    Set-Content -LiteralPath $changelog -Value "## [1.1.0]`n`n## [1.0.0]`n- Old."
    Assert-Rejected 'empty version section' {
        & "$PSScriptRoot/Get-ReleaseNotes.ps1" -Version '1.1.0' -ChangelogPath $changelog
    } 'is empty'
}
finally {
    $resolvedScratch = [IO.Path]::GetFullPath($releaseScratch)
    $tempPrefix = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath([IO.Path]::GetTempPath())) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedScratch.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Scratch cleanup escaped temp' }
    Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
}
