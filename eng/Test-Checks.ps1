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
    if (-not $line) { return [pscustomobject]@{ Status = 'NOT-REPORTED'; Detail = '' } }
    $status, $rest = "$line" -split '\s+', 2
    [pscustomobject]@{ Status = $status; Detail = ($rest -replace "^$([regex]::Escape($Check))\s+", '') }
}

function Test-MaskProbe {
    # Runs planted lines through Protect-Secret and asserts three things: the secret is gone from every
    # line, every line still exists (a function returning nothing must not pass), and every line carries
    # the *** marker where the secret was. -MaskSecret:$false withholds the value so only the shape or
    # URL rule can catch it.
    param(
        [Parameter(Mandatory)][string[]] $Planted,
        [Parameter(Mandatory)][string] $Secret,
        [Parameter(Mandatory)][bool] $MaskSecret
    )
    $masked = @($Planted | ForEach-Object { if ($MaskSecret) { Protect-Secret -Text $_ -Secret $Secret } else { Protect-Secret -Text $_ } })
    $leaked = @($masked | Where-Object { $_.Contains($Secret) })
    $unmarked = @($masked | Where-Object { -not $_.Contains('***') })
    $ok = ($masked.Count -eq $Planted.Count) -and ($leaked.Count -eq 0) -and ($unmarked.Count -eq 0)
    $status = if ($leaked.Count -gt 0) { "LEAKED in $($leaked.Count) line(s)" }
              elseif ($masked.Count -ne $Planted.Count) { "output count $($masked.Count) != $($Planted.Count)" }
              elseif ($unmarked.Count -gt 0) { "$($unmarked.Count) line(s) without the *** marker" }
              else { 'masked' }
    [pscustomobject]@{ Proven = $ok; Status = $status }
}

function Edit-Skill {
    # One regex replacement in one SKILL.md of the throwaway copy. Multiline so '$' can anchor a line end.
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $Skill,
        [Parameter(Mandatory)][string] $Pattern,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Replacement
    )
    $p = Join-Path $Root "skills/$Skill/SKILL.md"
    $text = Get-Content -LiteralPath $p -Raw -Encoding UTF8
    $edited = [regex]::Replace($text, $Pattern, $Replacement, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    # -ceq: PowerShell's -eq is case-insensitive, and one fixture changes only the case of a key.
    if ($edited -ceq $text) { throw "Edit-Skill: pattern '$Pattern' matched nothing in $p; the fixture would prove nothing." }
    Set-Content -LiteralPath $p -Value $edited -Encoding UTF8 -NoNewline
}

# Each case: the check it targets, and the single defect it introduces into a throwaway copy.
# Optional 'Expect': a phrase the check's detail must contain, so the case proves the check failed for
# the named reason and not for an unrelated one.
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
    # The plain-scalar cases keep both mandated separators intact, so the ONLY thing that can fail the
    # check is the scalar rule itself - a mutation the shape check would also reject proves nothing
    # about the rule (co-review finding, round 2). Each case also names the diagnostic it expects.
    @{ Check = 'frontmatter-schema'; Defect = "': ' inside description prose, separators intact (DRIFT-003)"; Expect = 'mapping indicator'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'decisions before implementation - ' 'decisions: before implementation - '
        } }
    @{ Check = 'frontmatter-schema'; Defect = "': ' inside a when_to_use item"; Expect = 'mapping indicator'; Mutate = {
            param($root)
            Edit-Skill $root 'maf-architecture-mapping' '  - how do I host this agent\?' '  - hosting: how do I host this agent?'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "' #' inside the description - a host would truncate there"; Expect = 'YAML comment'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'decisions before implementation - ' 'decisions #before implementation - '
        } }
    @{ Check = 'frontmatter-schema'; Defect = "a metadata value that is a YAML alias (*missing)"; Expect = 'YAML indicator'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'author: Alon Fliess' 'author: *missing'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "a when_to_use item opening a flow sequence ([unterminated)"; Expect = 'YAML indicator'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' '  - should this be an agent\?' '  - [unterminated'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "'key:value' with no space after the colon"; Expect = 'mapping entry'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'license: MIT' 'license:MIT'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "'Disallowed-Tools' differing from the contract key only by case"; Expect = 'disallowed-tools missing'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'disallowed-tools:' 'Disallowed-Tools:'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "a required tool name in the wrong case (write)"; Expect = "missing 'Write'"; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' '  - Write$' '  - write'
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'a duplicated top-level key'; Expect = 'duplicate key'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'license: MIT' "license: MIT`nlicense: MIT"
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'a duplicated metadata key'; Expect = 'duplicate key'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' '  version: 1.0.0' "  version: 1.0.0`n  version: 1.0.0"
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'a comment line inside the frontmatter'; Expect = 'comments are not part'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'license: MIT' "# a note`nlicense: MIT"
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

    # Probe cases exercise a function directly rather than a package copy. The install record enters
    # public history, so the token mask must be proven, not assumed: a planted token must come out as ***.
    @{ Check = 'install-record-mask'; Defect = 'the token VALUE planted in three unrelated log lines'; Probe = {
            . (Join-Path $PSScriptRoot 'Protect-Secret.ps1')
            $token = 'not-a-github-shape-' + [guid]::NewGuid().ToString('N')
            Test-MaskProbe -Planted @(
                "Cloning into https://x-access-token:${token}@github.com/o/r.git",
                "GH_TOKEN=${token}",
                "some tool echoed ${token} in the middle of a sentence"
            ) -Secret $token -MaskSecret $true
        } }
    # Each token family is planted in ORDINARY prose, so only its own shape rule can mask it - inside a
    # URL the credential rule would mask it regardless (co-review finding, round 2). Output count and
    # the masked marker are asserted too, so a function returning nothing cannot pass.
    @{ Check = 'install-record-mask'; Defect = 'a classic ghp_ token the run was NOT told about, in plain prose'; Probe = {
            . (Join-Path $PSScriptRoot 'Protect-Secret.ps1')
            $token = 'ghp_' + ('A1b2C3d4' * 5)
            Test-MaskProbe -Planted @("value ${token} appeared", "${token}") -Secret $token -MaskSecret $false
        } }
    @{ Check = 'install-record-mask'; Defect = 'a fine-grained github_pat_ token the run was NOT told about, in plain prose'; Probe = {
            . (Join-Path $PSScriptRoot 'Protect-Secret.ps1')
            $token = 'github_pat_' + ('Zz9_' * 8)
            Test-MaskProbe -Planted @("value ${token} appeared") -Secret $token -MaskSecret $false
        } }
    # The RESULT parser's failure path is never exercised by a passing run, so it is exercised here.
    @{ Check = 'install-record-parse'; Defect = 'a FAILING result line with every field, round-tripped intact'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line 'RESULT path=copilot-cli blocking=yes status=fail reason=over-limit-61000ms-gt-60000ms elapsed_ms=61000 skills=1/2'
            $ok = ($r.status -ceq 'fail') -and ($r.reason -ceq 'over-limit-61000ms-gt-60000ms') -and ($r.elapsed_ms -ceq '61000') -and ($r.skills -ceq '1/2') -and ($r.blocking -ceq 'yes')
            [pscustomobject]@{ Proven = $ok; Status = if ($ok) { 'fields intact' } else { "fields mangled: $($r | ConvertTo-Json -Compress)" } }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a result line whose status contains a space (the round-1 shape)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            try { ConvertFrom-InstallResult -Line 'RESULT path=x blocking=yes status=fail(exit 1) elapsed_ms=5 skills=0/2' | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted a malformed line silently' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'rejected' } }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a result line missing the reason field'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            try { ConvertFrom-InstallResult -Line 'RESULT path=x blocking=yes status=pass elapsed_ms=5 skills=2/2' | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted a line missing a field' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'rejected' } }
        } }
    @{ Check = 'install-record-mask'; Defect = 'an arbitrary credential inside an x-access-token URL, no shape match'; Probe = {
            . (Join-Path $PSScriptRoot 'Protect-Secret.ps1')
            $token = 'opaque.' + [guid]::NewGuid().ToString('N')
            Test-MaskProbe -Planted @("Cloning https://x-access-token:${token}@github.com/o/r.git") -Secret $token -MaskSecret $false
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
    if ($case.ContainsKey('Probe')) {
        $outcome = & $case.Probe
        $rows.Add([pscustomobject]@{
            Check   = $case.Check
            Defect  = $case.Defect
            Status  = $outcome.Status
            Proven  = [bool]$outcome.Proven
            Skipped = $false
        })
        continue
    }
    $copy = New-PackageCopy -Source $PackageRoot
    try {
        & $case.Mutate $copy
        $result = Get-CheckStatus -Root $copy -Check $case.Check
        $proven = ($result.Status -eq 'FAIL')
        $status = $result.Status
        if ($proven -and $case.ContainsKey('Expect') -and $result.Detail -notlike "*$($case.Expect)*") {
            # It failed, but not for the reason this case exists to prove.
            $proven = $false
            $status = "FAIL for another reason: $($result.Detail)"
        }
        $rows.Add([pscustomobject]@{
            Check   = $case.Check
            Defect  = $case.Defect
            Status  = $status
            Proven  = $proven
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
    Write-Output 'These checks did not catch their own defect, so they are not implemented:'
    foreach ($u in $unproven) { Write-Output "  - $($u.Check): $($u.Defect) -> reported $($u.Status)" }
    exit 1
}
exit 0
