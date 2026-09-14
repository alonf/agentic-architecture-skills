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
            # Windows junctions need no developer mode; other hosts require a symbolic link.
            $linkKind = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
            $created = New-Item -ItemType $linkKind -Path $link -Target $target -ErrorAction Stop
            if (-not $created.LinkType) { throw 'The no-symlinks fixture did not create a filesystem link.' }
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
    # Non-string spellings: a YAML consumer receives null/boolean/number where the contract says string.
    @{ Check = 'frontmatter-schema'; Defect = "a when_to_use item that is 'null'"; Expect = 'null, boolean or number'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' '  - should this be an agent\?' '  - null'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "a when_to_use item that is 'true'"; Expect = 'null, boolean or number'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' '  - should this be an agent\?' '  - true'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "author: null"; Expect = 'null, boolean or number'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' 'author: Alon Fliess' 'author: null'
        } }
    @{ Check = 'frontmatter-schema'; Defect = "a version that YAML reads as a float (1.0)"; Expect = 'null, boolean or number'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' '  version: 1\.0\.0' '  version: 1.0'
        } }
    @{ Check = 'frontmatter-schema'; Defect = 'an empty when_to_use item'; Expect = 'value is empty'; Mutate = {
            param($root)
            Edit-Skill $root 'agentic-architecture-router' '  - should this be an agent\?' '  - '
        } }
    # Manifest sync must be case-sensitive: JSON keys are.
    @{ Check = 'manifest-sync'; Defect = 'a manifest key changed only in case ("name" -> "Name")'; Expect = 'differs from generated'; Mutate = {
            param($root)
            $p = Join-Path $root '.claude-plugin/marketplace.json'
            $t = Get-Content -LiteralPath $p -Raw -Encoding UTF8
            $edited = $t -creplace '"name": "agentic-architecture-skills"', '"Name": "agentic-architecture-skills"'
            if ($edited -ceq $t) { throw 'fixture matched nothing' }
            Set-Content -LiteralPath $p -Value $edited -Encoding UTF8 -NoNewline
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
    # Every well-formed line below carries the two binding fields; 'a'*40 / 'b'*64 are the expectations
    # the verdict probes bind to, and 'c'*40 / 'd'*64 are something else of the right shape.
    @{ Check = 'install-record-parse'; Defect = 'a FAILING result line with every field, round-tripped intact'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=copilot-cli blocking=yes status=fail reason=over-limit-61000ms-gt-60000ms elapsed_ms=61000 skills=1/2 inventory=0/2 revision=$('a' * 40) digest=$('b' * 64)"
            $ok = ($r.status -ceq 'fail') -and ($r.reason -ceq 'over-limit-61000ms-gt-60000ms') -and ($r.elapsed_ms -ceq '61000') -and ($r.skills -ceq '1/2') -and ($r.inventory -ceq '0/2') -and ($r.blocking -ceq 'yes') -and ($r.revision -ceq ('a' * 40)) -and ($r.digest -ceq ('b' * 64))
            [pscustomobject]@{ Proven = $ok; Status = if ($ok) { 'fields intact' } else { "fields mangled: $($r | ConvertTo-Json -Compress)" } }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a tab-separated result line parses like a space-separated one'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT`tpath=claude-code`tblocking=yes`tstatus=pass`treason=-`telapsed_ms=5`tskills=2/2`tinventory=2/2`trevision=unknown`tdigest=$('b' * 64)"
            [pscustomobject]@{ Proven = ($r.path -ceq 'claude-code' -and $r.inventory -ceq '2/2' -and $r.revision -ceq 'unknown'); Status = 'parsed' }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a result line whose status contains a space (the round-1 shape)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            try { ConvertFrom-InstallResult -Line "RESULT path=x blocking=yes status=fail(exit 1) reason=- elapsed_ms=5 skills=0/2 inventory=0/2 revision=unknown digest=unknown" | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted a malformed line silently' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'rejected' } }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a result line missing the inventory field'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            try { ConvertFrom-InstallResult -Line "RESULT path=x blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 revision=unknown digest=$('b' * 64)" | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted a line missing a field' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'rejected' } }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a result line missing the revision and digest fields (the pre-binding shape)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            try { ConvertFrom-InstallResult -Line 'RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2' | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted an unbound line' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'rejected' } }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a revision that is neither a 40-hex SHA nor unknown'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            try { ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=main digest=$('b' * 64)" | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted a branch name as a revision' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'rejected' } }
        } }
    @{ Check = 'install-record-parse'; Defect = 'a bare RESULT line with no fields'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            try { ConvertFrom-InstallResult -Line 'RESULT' | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted a bare line' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'rejected' } }
        } }
    # Aggregation: the container exiting 0 is not evidence; the expected set must be complete.
    @{ Check = 'install-record-verdict'; Defect = 'no RESULT lines at all, container exit 0'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $v = Test-InstallResultSet -Results @() -ExpectedPaths @('claude-code', 'copilot-cli') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass -and $v.Reasons.Count -eq 2); Status = if ($v.Pass) { 'PASSED an empty run' } else { 'rejected' } }
        } }
    @{ Check = 'install-record-verdict'; Defect = 'one expected path missing, the others passing'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $ok = ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=$('a' * 40) digest=$('b' * 64)"
            $v = Test-InstallResultSet -Results @($ok) -ExpectedPaths @('claude-code', 'copilot-cli') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass); Status = if ($v.Pass) { 'PASSED with a path missing' } else { 'rejected' } }
        } }
    @{ Check = 'install-record-verdict'; Defect = 'a path reported twice'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $ok = ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=$('a' * 40) digest=$('b' * 64)"
            $v = Test-InstallResultSet -Results @($ok, $ok) -ExpectedPaths @('claude-code') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass); Status = if ($v.Pass) { 'PASSED a duplicate' } else { 'rejected' } }
        } }
    @{ Check = 'install-record-verdict'; Defect = 'a blocking path failed while the container exited 0'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $bad = ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=fail reason=inventory-lists-0-of-2 elapsed_ms=5 skills=2/2 inventory=0/2 revision=$('a' * 40) digest=$('b' * 64)"
            $v = Test-InstallResultSet -Results @($bad) -ExpectedPaths @('claude-code') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass); Status = if ($v.Pass) { 'PASSED a failed blocking path' } else { 'rejected' } }
        } }
    # Binding: a passing install of the WRONG content must not pass. This is the defect the revision
    # binding exists for - the hosts clone the default branch, and a push between checkout and install
    # would otherwise be reported as verified.
    @{ Check = 'install-record-binding'; Defect = 'a blocking path whose installed revision is not the expected one (a push landed mid-run)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=$('c' * 40) digest=$('b' * 64)"
            $v = Test-InstallResultSet -Results @($r) -ExpectedPaths @('claude-code') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass -and ($v.Reasons -join ' ') -match 'installed revision'); Status = if ($v.Pass) { 'PASSED an install of another revision' } else { 'rejected' } }
        } }
    @{ Check = 'install-record-binding'; Defect = 'a blocking path whose revision matches but whose installed content differs'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=$('a' * 40) digest=$('d' * 64)"
            $v = Test-InstallResultSet -Results @($r) -ExpectedPaths @('claude-code') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass -and ($v.Reasons -join ' ') -match 'content digest'); Status = if ($v.Pass) { 'PASSED altered content' } else { 'rejected' } }
        } }
    @{ Check = 'install-record-binding'; Defect = 'a blocking path with no exposed revision and a digest that does not match'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=copilot-cli blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=unknown digest=$('d' * 64)"
            $v = Test-InstallResultSet -Results @($r) -ExpectedPaths @('copilot-cli') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass); Status = if ($v.Pass) { 'PASSED unbound content' } else { 'rejected' } }
        } }
    @{ Check = 'install-record-binding'; Defect = 'a blocking path with no exposed revision and no digest (skills not on disk)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=copilot-cli blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=unknown digest=unknown"
            $v = Test-InstallResultSet -Results @($r) -ExpectedPaths @('copilot-cli') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = (-not $v.Pass); Status = if ($v.Pass) { 'PASSED with nothing to bind to' } else { 'rejected' } }
        } }
    @{ Check = 'install-record-binding'; Defect = 'a blocking path with no exposed revision but a matching digest (control: bound by content, must PASS)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=copilot-cli blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=unknown digest=$('b' * 64)"
            $v = Test-InstallResultSet -Results @($r) -ExpectedPaths @('copilot-cli') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = $v.Pass; Status = if ($v.Pass) { 'passes' } else { "rejected a digest-bound path: $($v.Reasons -join '; ')" } }
        } }
    @{ Check = 'install-record-binding'; Defect = 'an ADVISORY path installed from another revision (must be a note, not a failure)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=skills-cli blocking=no status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=$('c' * 40) digest=$('d' * 64)"
            $v = Test-InstallResultSet -Results @($r) -ExpectedPaths @('skills-cli') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = ($v.Pass -and $v.Notes.Count -eq 1); Status = if ($v.Pass -and $v.Notes.Count -eq 1) { 'noted, not failed' } elseif ($v.Pass) { 'passed silently without a note' } else { 'failed the run on an advisory path' } }
        } }
    @{ Check = 'install-record-binding'; Defect = 'an expected digest left empty (must be refused, not treated as no comparison)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $r = ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=$('a' * 40) digest=$('b' * 64)"
            try { Test-InstallResultSet -Results @($r) -ExpectedPaths @('claude-code') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest '' | Out-Null; [pscustomobject]@{ Proven = $false; Status = 'accepted an empty expectation' } }
            catch { [pscustomobject]@{ Proven = $true; Status = 'refused' } }
        } }
    # The two digest implementations must agree, or a correct install fails on a definition mismatch.
    @{ Check = 'install-record-digest'; Defect = 'bash and PowerShell digests of the real skills tree differ'; Requires = 'bash'; Probe = {
            . (Join-Path $PSScriptRoot 'Get-SkillsTreeDigest.ps1')
            $skillsRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills'
            $names = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object { $_.Name })
            $fromPwsh = Get-SkillsTreeDigest -SkillsRoot $skillsRoot -Skill $names
            $fromBash = (& bash (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests/install/digest-skills.sh') $skillsRoot @names 2>&1 | Select-Object -Last 1).Trim()
            [pscustomobject]@{ Proven = ($fromPwsh -ceq $fromBash); Status = if ($fromPwsh -ceq $fromBash) { "agree ($($fromPwsh.Substring(0, 12)))" } else { "differ: pwsh $fromPwsh, bash $fromBash" } }
        } }
    @{ Check = 'install-record-digest'; Defect = 'a one-byte change in a skill file leaves the digest unchanged'; Probe = {
            . (Join-Path $PSScriptRoot 'Get-SkillsTreeDigest.ps1')
            $copy = New-PackageCopy -Source (Split-Path -Parent $PSScriptRoot)
            try {
                $skillsRoot = Join-Path $copy 'skills'
                $names = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object { $_.Name })
                $before = Get-SkillsTreeDigest -SkillsRoot $skillsRoot -Skill $names
                [System.IO.File]::AppendAllText((Join-Path $skillsRoot $names[0] 'SKILL.md'), 'x')
                $after = Get-SkillsTreeDigest -SkillsRoot $skillsRoot -Skill $names
                [pscustomobject]@{ Proven = ($before -cne $after); Status = if ($before -cne $after) { 'changed' } else { 'unchanged after a content edit' } }
            }
            finally { Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction SilentlyContinue }
        } }
    @{ Check = 'install-record-digest'; Defect = 'CRLF line endings in the installed copy change the digest (a host rewriting line endings would fail a correct install)'; Probe = {
            . (Join-Path $PSScriptRoot 'Get-SkillsTreeDigest.ps1')
            $copy = New-PackageCopy -Source (Split-Path -Parent $PSScriptRoot)
            try {
                $skillsRoot = Join-Path $copy 'skills'
                $names = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object { $_.Name })
                $before = Get-SkillsTreeDigest -SkillsRoot $skillsRoot -Skill $names
                foreach ($f in Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Filter *.md) {
                    $text = [System.IO.File]::ReadAllText($f.FullName) -replace "`r`n", "`n" -replace "`n", "`r`n"
                    [System.IO.File]::WriteAllText($f.FullName, $text)
                }
                $after = Get-SkillsTreeDigest -SkillsRoot $skillsRoot -Skill $names
                [pscustomobject]@{ Proven = ($before -ceq $after); Status = if ($before -ceq $after) { 'line-ending invariant' } else { 'changed on a line-ending rewrite' } }
            }
            finally { Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction SilentlyContinue }
        } }
    @{ Check = 'install-record-verdict'; Defect = 'a complete passing set (control: must PASS)'; Probe = {
            . (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')
            $a = ConvertFrom-InstallResult -Line "RESULT path=claude-code blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=$('a' * 40) digest=$('b' * 64)"
            $b = ConvertFrom-InstallResult -Line "RESULT path=copilot-cli blocking=yes status=pass reason=- elapsed_ms=5 skills=2/2 inventory=2/2 revision=unknown digest=$('b' * 64)"
            $v = Test-InstallResultSet -Results @($a, $b) -ExpectedPaths @('claude-code', 'copilot-cli') -ContainerExitCode 0 -ExpectedRevision ('a' * 40) -ExpectedDigest ('b' * 64)
            [pscustomobject]@{ Proven = $v.Pass; Status = if ($v.Pass) { 'passes' } else { "rejected a good set: $($v.Reasons -join '; ')" } }
        } }
    @{ Check = 'install-record-mask'; Defect = 'an arbitrary credential inside an x-access-token URL, no shape match'; Probe = {
            . (Join-Path $PSScriptRoot 'Protect-Secret.ps1')
            $token = 'opaque.' + [guid]::NewGuid().ToString('N')
            Test-MaskProbe -Planted @("Cloning https://x-access-token:${token}@github.com/o/r.git") -Secret $token -MaskSecret $false
        } }
)

$cases += @{ Check = 'release-contracts'; Defect = 'tag identity and isolated changelog sections'; Probe = {
    $output = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-ReleaseContracts.ps1') 2>&1
    [pscustomobject]@{ Proven = ($LASTEXITCODE -eq 0); Status = ($output -join '; ') }
} }

# Keep the line and field counts valid while removing semantic slots: a failure must name the
# omitted verdict/stage, not an unrelated shape error. Capture loop values for each deferred mutation.
foreach ($alternative in @('all-deterministic', 'bounded-AI-only', 'agent-everywhere', 'multi-agent', 'workflow-only')) {
    $cases += @{ Check = 'fixture-card-shape'; Defect = "omitted $alternative verdict"; Expect = "missing verdict for '$alternative'"; Mutate = {
        param($root)
        $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
        $text = Get-Content -LiteralPath $path -Raw
        $pattern = [regex]::Escape($alternative) + ':[^;\r\n]+;?\s*'
        $edited = [regex]::Replace($text, $pattern, '', 'IgnoreCase')
        if ($edited -ceq $text) { throw "No $alternative verdict found for mutation" }
        Set-Content -LiteralPath $path -Value $edited -NoNewline
    }.GetNewClosure() }
}
foreach ($stage in @('reasoning', 'authorization', 'authoritative service', 'execution', 'audit')) {
    $cases += @{ Check = 'fixture-card-shape'; Defect = "omitted $stage authority stage"; Expect = "authority stage '$stage'"; Mutate = {
        param($root)
        $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
        $text = Get-Content -LiteralPath $path -Raw
        # Rename just the stage slot, preserving all arrows and the stage's explanation. A matching
        # word inside that explanation or another field must not satisfy the missing stage.
        $pattern = '(?i)(?<=[:→]\s)' + [regex]::Escape($stage) + ':'
        $edited = [regex]::Replace($text, $pattern, 'omitted:')
        if ($edited -ceq $text) { throw "No $stage stage found for mutation" }
        Set-Content -LiteralPath $path -Value $edited -NoNewline
    }.GetNewClosure() }
}
foreach ($placeholder in @('policy verdict', "<the stated policy that permits it, or exactly 'unknown - governance decision required'>")) {
    $cases += @{ Check = 'fixture-card-shape'; Defect = "literal authorization placeholder: $placeholder"; Expect = 'authorization contains literal placeholder text'; Mutate = {
        param($root)
        $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
        $text = Get-Content -LiteralPath $path -Raw
        $edited = [regex]::Replace($text, '(?i)authorization:[^→\r\n]+(?=→)', "authorization: $placeholder ")
        if ($edited -ceq $text) { throw 'Authorization placeholder mutation changed nothing' }
        Set-Content -LiteralPath $path -Value $edited -NoNewline
    }.GetNewClosure() }
}
$cases += @{ Check = 'fixture-card-shape'; Defect = 'empty bounded-AI-only verdict'; Expect = "missing verdict for 'bounded-AI-only'"; Mutate = {
    param($root)
    $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
    $text = Get-Content -LiteralPath $path -Raw
    $text -replace 'bounded-AI-only:[^;]+;', 'bounded-AI-only: ;' | Set-Content -LiteralPath $path -NoNewline
} }
$cases += @{ Check = 'fixture-card-shape'; Defect = 'execution before authorization'; Expect = "authority stage 'authorization'"; Mutate = {
    param($root)
    $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
    $text = Get-Content -LiteralPath $path -Raw
    $text.Replace('→ authorization:', '→ execution:').Replace('→ execution: send', '→ authorization: send') | Set-Content -LiteralPath $path -NoNewline
} }
$cases += @{ Check = 'fixture-card-shape'; Defect = 'duplicate field concealing missing evidence field'; Expect = "missing or empty field 'Evidence classification'"; Mutate = {
    param($root)
    $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
    (Get-Content -LiteralPath $path -Raw).Replace('Evidence classification:', 'Known facts:') | Set-Content -LiteralPath $path -NoNewline
} }

$cases += @{ Check = 'fixture-card-shape'; Defect = 'required Decision Card fixture removed'; Expect = 'required Decision Card fixture'; Mutate = {
    param($root)
    Remove-Item -LiteralPath (Join-Path $root 'tests/golden/decision-card-generic-requirement.md')
} }
$cases += @{ Check = 'fixture-card-shape'; Defect = 'required Decision Card mode marker removed'; Expect = 'required Decision Card fixture'; Mutate = {
    param($root)
    $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
    (Get-Content -LiteralPath $path -Raw).Replace('<!-- mode: decision-card -->', '') | Set-Content -LiteralPath $path -NoNewline
} }
$cases += @{ Check = 'fixture-card-shape'; Defect = 'interior blank lines exceed physical source budget'; Expect = '16 source lines'; Mutate = {
    param($root)
    $path = Join-Path $root 'tests/golden/decision-card-generic-requirement.md'
    $lines = @(Get-Content -LiteralPath $path | Where-Object { $_ -match '\S' })
    $text = ($lines -join "`n").Replace('# Decision Card', "# Decision Card`n`n`n`n")
    Set-Content -LiteralPath $path -Value $text -NoNewline
} }
foreach ($physicalCount in @(12, 15)) {
    $cases += @{ Check = 'fixture-card-shape-boundary'; Defect = "valid $physicalCount physical lines with outer padding"; Probe = {
        $copy = New-PackageCopy -Source $PackageRoot
        try {
            $path = Join-Path $copy 'tests/golden/decision-card-generic-requirement.md'
            $lines = @(Get-Content -LiteralPath $path | Where-Object { $_ -match '\S' })
            $text = ($lines -join "`n").Replace('# Decision Card', '# Decision Card' + ("`n" * ($physicalCount - 12)))
            Set-Content -LiteralPath $path -Value ("`n`n" + $text + "`n`n") -NoNewline
            $result = Get-CheckStatus -Root $copy -Check 'fixture-card-shape'
            [pscustomobject]@{ Proven = ($result.Status -eq 'PASS'); Status = $result.Status }
        }
        finally { Remove-Item -LiteralPath $copy -Recurse -Force }
    }.GetNewClosure() }
}
foreach ($invalidSource in @('https://example.invalid/repo.git', 'https://github.com/owner/repo.git',
    'owner/repo/extra', 'owner/..', 'owner/repo?redirect=example.invalid')) {
    $cases += @{ Check = 'install-source-boundary'; Defect = "unsupported source $invalidSource"; Probe = {
        $output = @(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-Install.ps1') -Source $invalidSource -NoRecord 2>&1)
        $exitCode = $LASTEXITCODE
        $rejectedAtBinding = $exitCode -ne 0 -and ($output -join ' ') -match 'Cannot validate argument on parameter .Source.'
        [pscustomobject]@{ Proven = $rejectedAtBinding; Status = if ($rejectedAtBinding) { 'rejected before execution' } else { 'source was not rejected at parameter binding' } }
    }.GetNewClosure() }
}
foreach ($gitKind in @('Directory', 'File')) {
    $cases += @{ Check = 'export-checkout-preservation'; Defect = "export-owned destination with a .git $gitKind"; Probe = {
        $copy = New-PackageCopy -Source $PackageRoot
        try {
            New-Item -ItemType File -Path (Join-Path $copy '.export-owned') | Out-Null
            $gitPath = Join-Path $copy '.git'
            New-Item -ItemType $gitKind -Path $gitPath | Out-Null
            $sentinel = if ($gitKind -eq 'Directory') { Join-Path $gitPath 'unpublished-history' } else { $gitPath }
            Set-Content -LiteralPath $sentinel -Value 'preserve this checkout metadata'
            $output = @(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Export-Package.ps1') -SourcePath $PackageRoot -ExportPath $copy 2>&1)
            $exitCode = $LASTEXITCODE
            $preserved = (Test-Path -LiteralPath $sentinel) -and (Get-Content -LiteralPath $sentinel -Raw).Trim() -eq 'preserve this checkout metadata'
            $proven = $exitCode -ne 0 -and ($output -join ' ') -match 'ExportPath is a Git checkout' -and $preserved
            [pscustomobject]@{ Proven = $proven; Status = if ($proven) { 'refused; metadata intact' } else { 'checkout was not safely refused' } }
        }
        finally { Remove-Item -LiteralPath $copy -Recurse -Force }
    }.GetNewClosure() }
}

foreach ($aliasCase in @('destination-ancestor', 'destination-self', 'source-ancestor', 'new-destination')) {
    $cases += @{ Check = 'export-alias-preservation'; Defect = $aliasCase; Probe = {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $scratch = Join-Path $tempRoot ('exportalias-' + [guid]::NewGuid().ToString('N'))
        $alias = Join-Path $scratch 'alias'
        New-Item -ItemType Directory -Path (Join-Path $scratch 'physical') -Force | Out-Null
        $source = Join-Path $scratch 'physical/pkg'
        Copy-Item -LiteralPath $PackageRoot -Destination $source -Recurse -Force
        try {
            New-Item -ItemType File -Path (Join-Path $source '.export-owned') | Out-Null
            $sentinel = Join-Path $source 'README.md'
            $before = (Get-FileHash -LiteralPath $sentinel).Hash
            $target = if ($aliasCase -eq 'destination-self') { $source } else { Split-Path -Parent $source }
            $linkKind = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
            New-Item -ItemType $linkKind -Path $alias -Target $target | Out-Null
            $exportSource = $source
            $exportDestination = Join-Path $alias 'pkg'
            switch ($aliasCase) {
                'destination-self' { $exportDestination = $alias }
                'source-ancestor' { $exportSource = Join-Path $alias 'pkg'; $exportDestination = $source }
                'new-destination' { $exportDestination = Join-Path $alias 'new/pkg' }
            }
            $output = @(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Export-Package.ps1') -SourcePath $exportSource -ExportPath $exportDestination 2>&1)
            $exitCode = $LASTEXITCODE
            $preserved = (Test-Path -LiteralPath $sentinel) -and (Get-FileHash -LiteralPath $sentinel).Hash -eq $before
            $noNewTree = -not (Test-Path -LiteralPath (Join-Path $scratch 'physical/new'))
            $proven = $exitCode -ne 0 -and ($output -join ' ') -match 'must not traverse a junction or symbolic link' -and $preserved -and $noNewTree
            [pscustomobject]@{ Proven = $proven; Status = if ($proven) { 'refused; source intact; no destination created' } else { 'alias was not safely refused' } }
        }
        finally {
            # Remove the link itself before recursive cleanup, never traverse it during deletion.
            if (Test-Path -LiteralPath $alias) { Remove-Item -LiteralPath $alias -Force }
            $resolvedScratch = [IO.Path]::GetFullPath($scratch)
            if (-not $resolvedScratch.StartsWith($tempRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Refusing cleanup outside the temporary test directory.'
            }
            Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
        }
    }.GetNewClosure() }
}

$cases += @{ Check = 'export-path-boundaries'; Defect = 'overlapping paths with trailing separators'; Probe = {
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('exportbounds-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $scratch | Out-Null
    $source = Join-Path $scratch 'pkg'
    Copy-Item -LiteralPath $PackageRoot -Destination $source -Recurse -Force
    try {
        New-Item -ItemType File -Path (Join-Path $scratch '.export-owned') | Out-Null
        New-Item -ItemType File -Path (Join-Path $source '.export-owned') | Out-Null
        $sentinel = Join-Path $source 'README.md'
        $before = (Get-FileHash -LiteralPath $sentinel).Hash
        $proven = $true
        foreach ($destination in @($source, $scratch, (Join-Path $source 'nested'))) {
            $output = @(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Export-Package.ps1') -SourcePath $source -ExportPath ($destination + [IO.Path]::DirectorySeparatorChar) 2>&1)
            $proven = $proven -and $LASTEXITCODE -ne 0 -and ($output -join ' ') -match 'must not be the package source'
            $proven = $proven -and (Test-Path -LiteralPath $sentinel) -and (Get-FileHash -LiteralPath $sentinel).Hash -eq $before
        }
        [pscustomobject]@{ Proven = $proven; Status = if ($proven) { 'self, ancestor, and descendant refused; source intact' } else { 'overlap was not safely refused' } }
    }
    finally { Remove-Item -LiteralPath $scratch -Recurse -Force }
} }
$cases += @{ Check = 'export-repeat-parity'; Defect = 'direct staging path exported twice'; Probe = {
    $destination = Join-Path ([IO.Path]::GetTempPath()) ('exportrepeat-' + [guid]::NewGuid().ToString('N'))
    try {
        $proven = $true
        foreach ($attempt in 1..2) {
            $output = @(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Export-Package.ps1') -SourcePath $PackageRoot -ExportPath $destination 2>&1)
            $proven = $proven -and $LASTEXITCODE -eq 0 -and ($output -join ' ') -match 'PASS export-parity'
        }
        [pscustomobject]@{ Proven = $proven; Status = if ($proven) { 'both exports pass byte parity' } else { 'ordinary export failed' } }
    }
    finally { if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force } }
} }

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
