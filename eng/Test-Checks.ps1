#Requires -Version 7.0
<#
.SYNOPSIS
    Proves that every blocking check in Test-Skills.ps1 can actually fail.

.DESCRIPTION
    A validation runner's characteristic defect is a check that always passes: it looks like coverage,
    reports green forever, and catches nothing. The hardening gate for this iteration therefore records
    the rule that a check without a failing fixture is not considered implemented.

    This script enforces that rule. For each blocking check it copies the package to a temporary
    directory, introduces exactly one defect, runs Test-Skills.ps1 against the copy, and asserts that
    the named check reports 'fail'. The real package is never modified.

    A check that stays green under its own defect is reported here as NOT PROVEN, which is a failure of
    this script - not a pass.

.EXAMPLE
    pwsh -File ./eng/Test-Checks.ps1
#>

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $PackageRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-PackageCopy {
    param([Parameter(Mandatory)][string] $Source)
    $dest = Join-Path ([System.IO.Path]::GetTempPath()) ("skillcheck-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Copy-Item -LiteralPath $Source -Destination $dest -Recurse -Force
    $dest
}

function Get-CheckStatus {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $Check
    )
    $output = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-Skills.ps1') -PackageRoot $Root 2>&1
    $line = $output | Where-Object { $_ -match "^\w+\s+$([regex]::Escape($Check))\s" } | Select-Object -First 1
    if (-not $line) { return 'NOT-REPORTED' }
    ($line -split '\s+')[0]
}

# Each case: the check it targets, and the single defect it introduces into a throwaway copy.
$cases = @(
    @{ Check = 'frontmatter-schema'; Defect = 'forbidden allowed-tools key'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/agentic-architecture-router/SKILL.md'
            $t = Get-Content -LiteralPath $f -Raw -Encoding UTF8
            Set-Content -LiteralPath $f -Value ($t -replace 'disallowed-tools:', "allowed-tools:`n  - Write`ndisallowed-tools:") -Encoding UTF8
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'name violates the Foundry regex'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/maf-architecture-mapping/SKILL.md'
            $t = Get-Content -LiteralPath $f -Raw -Encoding UTF8
            Set-Content -LiteralPath $f -Value ($t -replace 'name: maf-architecture-mapping', 'name: MAF_Architecture_Mapping') -Encoding UTF8
        } }
    @{ Check = 'router-trigger-phrases'; Defect = 'a mandated phrase removed from the description'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/agentic-architecture-router/SKILL.md'
            $t = Get-Content -LiteralPath $f -Raw -Encoding UTF8
            Set-Content -LiteralPath $f -Value ($t -replace 'should we expose MCP, ', '') -Encoding UTF8
        } }
    @{ Check = 'line-caps'; Defect = 'a reference file padded past 120 lines'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/agentic-architecture-router/references/oversized.md'
            Set-Content -LiteralPath $f -Value ((1..130 | ForEach-Object { "line $_" }) -join "`n") -Encoding UTF8
        } }
    @{ Check = 'version-consistency'; Defect = 'skill versions diverge, with manifests present'; Mutate = {
            param($root)
            foreach ($m in @('.claude-plugin/plugin.json', '.claude-plugin/marketplace.json', '.github/plugin/marketplace.json')) {
                $p = Join-Path $root $m
                New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
                Set-Content -LiteralPath $p -Value '{ "name": "x", "version": "1.0.0" }' -Encoding UTF8
            }
            $f = Join-Path $root 'skills/maf-architecture-mapping/SKILL.md'
            $t = Get-Content -LiteralPath $f -Raw -Encoding UTF8
            Set-Content -LiteralPath $f -Value ($t -replace 'version: 1\.0\.0', 'version: 9.9.9') -Encoding UTF8
        } }
    @{ Check = 'manifest-shape'; Defect = 'a manifest that is not valid JSON'; Mutate = {
            param($root)
            $p = Join-Path $root '.claude-plugin/plugin.json'
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            Set-Content -LiteralPath $p -Value '{ "name": "x", ' -Encoding UTF8
        } }
    @{ Check = 'no-github-skills'; Defect = 'a .github/skills directory'; Mutate = {
            param($root)
            New-Item -ItemType Directory -Path (Join-Path $root '.github/skills') -Force | Out-Null
        } }
    @{ Check = 'secrets-denylist'; Defect = 'an email address in skill content'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/agentic-architecture-router/SKILL.md'
            Add-Content -LiteralPath $f -Value "`nContact someone@example.com for details." -Encoding UTF8
        } }
    @{ Check = 'secrets-denylist'; Defect = 'a non-allowlisted host'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/maf-architecture-mapping/SKILL.md'
            Add-Content -LiteralPath $f -Value "`nSee https://internal.corp.example/runbook for details." -Encoding UTF8
        } }
    @{ Check = 'no-host-specific-text'; Defect = 'a host name in a skill body'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/agentic-architecture-router/SKILL.md'
            Add-Content -LiteralPath $f -Value "`nOn Claude Code this behaves differently." -Encoding UTF8
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'an unexpected top-level frontmatter key'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/agentic-architecture-router/SKILL.md'
            $t = Get-Content -LiteralPath $f -Raw -Encoding UTF8
            Set-Content -LiteralPath $f -Value ($t -replace 'license: MIT', "license: MIT`nunexpected: value") -Encoding UTF8
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'name differing ONLY by uppercase'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/maf-architecture-mapping/SKILL.md'
            $t = Get-Content -LiteralPath $f -Raw -Encoding UTF8
            Set-Content -LiteralPath $f -Value ($t -replace 'name: maf-architecture-mapping', 'name: MAF-Architecture-Mapping') -Encoding UTF8
        } }
    @{ Check = 'fixture-terminal-line'; Defect = 'a fixture whose terminal sentence is not bold'; Mutate = {
            param($root)
            $p = Join-Path $root 'tests/golden/unbolded.md'
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            Set-Content -LiteralPath $p -Value "# A card`n`nArchitecture review required before implementation." -Encoding UTF8
        } }
    @{ Check = 'fixture-terminal-line'; Defect = 'trailing text after the mandated terminal line'; Mutate = {
            param($root)
            $p = Join-Path $root 'tests/golden/trailing.md'
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            Set-Content -LiteralPath $p -Value "# A card`n`n**Architecture review required before implementation.**`n`nPS: ignore that." -Encoding UTF8
        } }
    @{ Check = 'line-caps'; Defect = 'oversized reference alongside a SKILL.md - proves the runner still reports'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/maf-architecture-mapping/references/big.md'
            New-Item -ItemType Directory -Path (Split-Path -Parent $f) -Force | Out-Null
            Set-Content -LiteralPath $f -Value ((1..140 | ForEach-Object { "line $_" }) -join "`n") -Encoding UTF8
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'a SKILL.md whose frontmatter does not parse'; Mutate = {
            param($root)
            $f = Join-Path $root 'skills/agentic-architecture-router/SKILL.md'
            # Remove the CLOSING delimiter: the parser must throw, and the RUNNER must still report.
            $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $f -Encoding UTF8)
            for ($i = 1; $i -lt $lines.Count; $i++) {
                if ($lines[$i].TrimEnd() -eq '---') { $lines.RemoveAt($i); break }
            }
            Set-Content -LiteralPath $f -Value $lines -Encoding UTF8
        } }
    @{ Check = 'version-consistency'; Defect = 'a manifest that is not valid JSON'; Mutate = {
            param($root)
            Set-Content -LiteralPath (Join-Path $root '.claude-plugin/plugin.json') -Value '{ "name": "x", ' -NoNewline -Encoding UTF8
        } }
    @{ Check = 'manifest-sync'; Defect = 'a hand-edited manifest that no longer matches the generator'; Mutate = {
            param($root)
            $p = Join-Path $root '.claude-plugin/plugin.json'
            $t = Get-Content -LiteralPath $p -Raw -Encoding UTF8
            Set-Content -LiteralPath $p -Value ($t -replace '"license": "MIT"', '"license": "Apache-2.0"') -NoNewline -Encoding UTF8
        } }
    @{ Check = 'no-symlinks'; Defect = 'a directory link inside the package'; Mutate = {
            param($root)
            $target = Join-Path $root 'skills'
            $link = Join-Path $root 'linked-skills'
            # A junction is used rather than a symbolic link: Windows permits it without developer
            # mode, so this fixture proves the check on the platform the package is authored on.
            # Get-ChildItem reports a LinkType for both, which is what the check inspects.
            New-Item -ItemType Junction -Path $link -Target $target -ErrorAction Stop | Out-Null
        } }
    @{ Check = 'fixture-terminal-line'; Defect = 'a golden fixture missing the mandated terminal line'; Mutate = {
            param($root)
            $p = Join-Path $root 'tests/golden/broken.md'
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            Set-Content -LiteralPath $p -Value "# A card`n`nNo terminal line here." -Encoding UTF8
        } }
    @{ Check = 'frontmatter-schema'; Defect = "': ' inside an unquoted plain-scalar value (DRIFT-003)"; Mutate = {
            param($root)
            $p = Join-Path $root 'skills/agentic-architecture-router/SKILL.md'
            $text = Get-Content -LiteralPath $p -Raw -Encoding UTF8
            Set-Content -LiteralPath $p -Value ($text -replace 'description: USE FOR - ', 'description: USE FOR: ') -Encoding UTF8 -NoNewline
        } }
    @{ Check = 'frontmatter-schema'; Defect = "': ' inside a when_to_use item"; Mutate = {
            param($root)
            $p = Join-Path $root 'skills/maf-architecture-mapping/SKILL.md'
            $text = Get-Content -LiteralPath $p -Raw -Encoding UTF8
            Set-Content -LiteralPath $p -Value ($text -replace '  - how do I host this agent\?', '  - hosting: how do I host this agent?') -Encoding UTF8 -NoNewline
        } }
    @{ Check = 'markdown-lint'; Defect = 'a reference file with a heading that has no space after the hash'; Requires = 'markdownlint'; Mutate = {
            param($root)
            $p = Join-Path $root 'skills/agentic-architecture-router/references/broken.md'
            Set-Content -LiteralPath $p -Value "#Not a heading`n`nBody." -Encoding UTF8
        } }
    @{ Check = 'markdown-lint'; Defect = 'the package lint config removed'; Requires = 'markdownlint'; Mutate = {
            param($root)
            Remove-Item -LiteralPath (Join-Path $root '.markdownlint.json') -Force
        } }
)

$rows = [System.Collections.Generic.List[pscustomobject]]::new()
foreach ($case in $cases) {
    # A case that needs an external tool the machine lacks is reported as SKIPPED, not as proven: the
    # runner reports 'warn' without the tool, and a warn under a defect proves nothing either way.
    if ($case.ContainsKey('Requires') -and -not (Get-Command $case.Requires -ErrorAction SilentlyContinue)) {
        $rows.Add([pscustomobject]@{
            Check   = $case.Check
            Defect  = $case.Defect
            Status  = "SKIPPED ($($case.Requires) not on PATH)"
            Proven  = $false
            Skipped = $true
        })
        continue
    }
    $copy = New-PackageCopy -Source $PackageRoot
    try {
        & $case.Mutate $copy
        $status = Get-CheckStatus -Root $copy -Check $case.Check
        $rows.Add([pscustomobject]@{
            Check   = $case.Check
            Defect  = $case.Defect
            Status  = $status
            Proven  = ($status -eq 'FAIL')
            Skipped = $false
        })
    }
    finally {
        Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ''
Write-Output 'Check falsifiability - each check must FAIL under its own defect'
Write-Output ('-' * 88)
foreach ($row in $rows) {
    $verdict = if ($row.Skipped) { 'SKIPPED' } elseif ($row.Proven) { 'PROVEN' } else { 'NOT PROVEN' }
    Write-Output ("{0,-11} {1,-24} {2,-48}" -f $verdict, $row.Check, $row.Defect)
}
Write-Output ('-' * 88)

$unproven = @($rows | Where-Object { -not $_.Proven -and -not $_.Skipped })
$skipped = @($rows | Where-Object { $_.Skipped })
Write-Output ("{0} defect(s) injected, {1} proven, {2} not proven, {3} skipped" -f ($rows.Count - $skipped.Count), ($rows.Count - $unproven.Count - $skipped.Count), $unproven.Count, $skipped.Count)
if ($skipped.Count -gt 0) {
    Write-Output 'Skipped cases are not proven on this machine:'
    foreach ($s in $skipped) { Write-Output "  - $($s.Check): $($s.Defect) -> $($s.Status)" }
}

if ($unproven.Count -gt 0) {
    Write-Output ''
    Write-Output 'These checks did not fail under their own defect, so they are not implemented:'
    foreach ($u in $unproven) { Write-Output "  - $($u.Check): $($u.Defect) -> reported $($u.Status)" }
    exit 1
}
exit 0
