#Requires -Version 7.0
<#
.SYNOPSIS
    Generates the host manifests from one source. Stamps JSON only - never rewrites a SKILL.md.

.DESCRIPTION
    The manifests are build output. They are regenerated from VERSION plus the skill inventory
    discovered under skills/, and a hand-edited manifest is a defect rather than a customisation.

    This script deliberately does NOT write version numbers into SKILL.md files. Version equality
    between the skills and the manifests is enforced by validation in Test-Skills.ps1, not by
    generation, so that skills/ stays authored content end to end and no contributor edit is silently
    overwritten. The failure mode of validation is a red build; the failure mode of generation is a lost
    edit, and only one of those is recoverable by reading the error.

.PARAMETER PackageRoot
    Root of the package. Defaults to the parent of this script's directory.

.PARAMETER Check
    Verify the manifests on disk match what would be generated, and change nothing. Exits 1 on drift.

.EXAMPLE
    pwsh -File ./eng/Sync-Manifests.ps1

.EXAMPLE
    pwsh -File ./eng/Sync-Manifests.ps1 -Check
#>

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $PackageRoot = (Split-Path -Parent $PSScriptRoot),

    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Read-SkillFrontmatter.ps1')

$script:PluginName = 'agentic-architecture'
$script:MarketplaceName = 'agentic-architecture-skills'
$script:Owner = 'Alon Fliess'
$script:Homepage = 'https://github.com/alonf/agentic-architecture-skills'

function Get-PackageVersion {
    param([Parameter(Mandatory)][string] $Root)
    $versionFile = Join-Path $Root 'VERSION'
    if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) {
        throw "VERSION not found at '$versionFile'. It is the single source of the package version."
    }
    $version = (Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "VERSION contains '$version', which is not a three-part semantic version."
    }
    $version
}

function Get-SkillInventory {
    param([Parameter(Mandatory)][string] $Root)
    $skillsDir = Join-Path $Root 'skills'
    if (-not (Test-Path -LiteralPath $skillsDir -PathType Container)) {
        throw "skills/ not found under '$Root'."
    }
    @(Get-ChildItem -LiteralPath $skillsDir -Directory | ForEach-Object {
        $skillFile = Join-Path $_.FullName 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { return }
        $fm = Read-SkillFrontmatter -Path $skillFile
        [pscustomobject]@{ Name = $fm.Name; Description = $fm.Description }
    })
}

function New-ManifestContent {
    param(
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][object[]] $Skills
    )

    # The plugin manifest declares no skill paths: discovery is by convention at
    # <plugin-root>/skills/<name>/SKILL.md, which is what 288 of 291 official marketplace entries rely
    # on. Declaring paths here would be a second source of truth for the inventory.
    $plugin = [ordered]@{
        name        = $script:PluginName
        description = 'Decide the least-autonomous mechanism a requirement needs, then map an approved decision onto Microsoft Agent Framework constructs in .NET.'
        version     = $Version
        author      = [ordered]@{ name = $script:Owner }
        homepage    = $script:Homepage
        license     = 'MIT'
    }

    $marketplace = [ordered]@{
        name    = $script:MarketplaceName
        version = $Version
        owner   = [ordered]@{ name = $script:Owner }
        plugins = @(
            [ordered]@{
                name        = $script:PluginName
                source      = './'
                description = "Two skills: $((($Skills | ForEach-Object { $_.Name }) -join ' and '))."
            }
        )
    }

    @{
        '.claude-plugin/plugin.json'      = $plugin
        '.claude-plugin/marketplace.json' = $marketplace
        '.github/plugin/marketplace.json' = $marketplace
    }
}

function Format-ManifestJson {
    param([Parameter(Mandatory)][object] $Value)
    ($Value | ConvertTo-Json -Depth 8).Replace("`r`n", "`n").TrimEnd() + "`n"
}

$version = Get-PackageVersion -Root $PackageRoot
$skills = @(Get-SkillInventory -Root $PackageRoot)
if ($skills.Count -eq 0) { throw 'No skills found; refusing to generate manifests for an empty package.' }

$manifests = New-ManifestContent -Version $version -Skills $skills
$drift = [System.Collections.Generic.List[string]]::new()
$written = 0

foreach ($relative in $manifests.Keys | Sort-Object) {
    $target = Join-Path $PackageRoot $relative
    $expected = Format-ManifestJson -Value $manifests[$relative]

    if ($Check) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            $drift.Add("${relative}: missing")
            continue
        }
        $actual = (Get-Content -LiteralPath $target -Raw -Encoding UTF8).Replace("`r`n", "`n")
        # -cne: JSON property names are case-sensitive, and PowerShell's -ne is not.
        if ($actual -cne $expected) { $drift.Add("${relative}: differs from generated output") }
        continue
    }

    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $target -Value $expected -NoNewline -Encoding UTF8
    $written++
    Write-Output "stamped $relative (version $version)"
}

if ($Check) {
    if ($drift.Count -eq 0) {
        Write-Output "manifests are in sync at version $version"
        exit 0
    }
    Write-Output 'manifest drift:'
    foreach ($d in $drift) { Write-Output "  - $d" }
    exit 1
}

Write-Output "$written manifest(s) generated from VERSION $version and $($skills.Count) skill(s)"
exit 0
