#Requires -Version 7.0
<#
.SYNOPSIS
    The single definition of "this package is valid". CI invokes this and adds nothing of its own.

.DESCRIPTION
    Every mechanical check lives here rather than in the workflow, so what fails in CI fails
    identically on a maintainer's machine. A check that exists only in CI cannot be run before a push,
    which turns a two-minute fix into a push-and-wait loop.

    Statuses:
      pass    - the check ran and the package satisfies it
      fail    - the check ran and the package violates it. Blocking; the script exits 1
      warn    - non-blocking by policy (the external link check) or the tool is unavailable locally
      pending - there is nothing to assert yet, and the check says so rather than passing silently

    'pending' exists because a check with nothing to check is not a passing check. Reporting it as
    pass would be the specific defect this package is built to warn about: a validator that cannot fail.

.PARAMETER PackageRoot
    Root of the package to validate. Defaults to the parent of this script's directory.

.EXAMPLE
    pwsh -File ./eng/Test-Skills.ps1
#>

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $PackageRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Read-SkillFrontmatter.ps1')

# Contract constants. Named once here because the checks assert them and the skills must satisfy them;
# two copies of 250 would drift.
$script:MaxSkillLines = 250
$script:MaxReferenceLines = 120
$script:MaxDescriptionChars = 1024
$script:MaxNameChars = 64
$script:NamePattern = '^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$'
$script:TerminalLine = '**Architecture review required before implementation.**'
# Decision Card fixtures are marked with this literal comment so the card-shape check knows which
# golden fixtures to hold to FR-015's 12-15-line, nine-field contract; a full-analysis fixture has no
# such line count and would be a false failure under the same check.
$script:CardModeMarker = '<!-- mode: decision-card -->'
$script:RequiredCardFieldCount = 9
$script:MinCardSourceLines = 12
$script:MaxCardSourceLines = 15
$script:RequiredCardFields = @('Requirement', 'Known facts', 'Unknown / assumptions', 'Routed mechanism',
    'Agent boundary', 'Evidence classification', 'Authority chain', 'Rejected alternatives', 'Decision and trade-off')
$script:RequiredCardAlternatives = @('all-deterministic', 'bounded-AI-only', 'agent-everywhere', 'multi-agent', 'workflow-only')
$script:RequiredAuthorityStages = @('reasoning', 'authorization', 'authoritative service', 'execution', 'audit')
$script:RequiredPhrases = @(
    'should this be an agent'
    'deterministic vs agentic'
    'do we need AI'
    'single agent or multi-agent'
    'should we expose MCP'
    'agentic architecture'
    'architecture decision'
)
$script:ForbiddenFrontmatterKeys = @('allowed-tools', 'hooks', 'compatibility')
$script:RequiredDisallowedTools = @('Write', 'Edit', 'NotebookEdit')
$script:HostSpecificTerms = @('Claude Code', 'Copilot CLI', 'Cursor', 'Codex', 'VS Code')

$script:Results = [System.Collections.Generic.List[pscustomobject]]::new()

function Add-CheckResult {
    param(
        [Parameter(Mandatory)][string] $Check,
        [Parameter(Mandatory)][ValidateSet('pass', 'fail', 'warn', 'pending')][string] $Status,
        [string] $Detail = ''
    )
    $script:Results.Add([pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail })
}

function Get-SkillFiles {
    param([Parameter(Mandatory)][string] $Root)
    $skillsDir = Join-Path $Root 'skills'
    if (-not (Test-Path -LiteralPath $skillsDir -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $skillsDir -Directory | ForEach-Object {
        $candidate = Join-Path $_.FullName 'SKILL.md'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
    })
}

function Resolve-Skills {
    <#
      Parses every SKILL.md exactly once and CONTAINS any parse failure.

      A malformed SKILL.md is precisely what this runner exists to catch, so letting the parser's
      terminating error escape would trade the report for a stack trace and hide every other check.
      Each entry carries either Frontmatter or ParseError; never both, never neither.
    #>
    param([Parameter(Mandatory)][string[]] $SkillFiles)
    @($SkillFiles | ForEach-Object {
        $path = $_
        try {
            [pscustomobject]@{ Path = $path; Frontmatter = (Read-SkillFrontmatter -Path $path); ParseError = $null }
        }
        catch {
            [pscustomobject]@{ Path = $path; Frontmatter = $null; ParseError = $_.Exception.Message }
        }
    })
}

function Test-FrontmatterContract {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Skills)

    if ($Skills.Count -eq 0) {
        Add-CheckResult -Check 'frontmatter-schema' -Status 'fail' -Detail 'No SKILL.md found under skills/.'
        return
    }

    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($skill in $Skills) {
        $rel = [System.IO.Path]::GetRelativePath($PackageRoot, $skill.Path)
        if ($skill.ParseError) { $problems.Add("${rel}: frontmatter does not parse - $($skill.ParseError)"); continue }
        $fm = $skill.Frontmatter

        if ([string]::IsNullOrWhiteSpace($fm.Name)) { $problems.Add("${rel}: name missing") }
        elseif ($fm.Name -cnotmatch $script:NamePattern) { $problems.Add("${rel}: name '$($fm.Name)' fails $($script:NamePattern)") }
        elseif ($fm.Name.Length -gt $script:MaxNameChars) { $problems.Add("${rel}: name exceeds $($script:MaxNameChars) chars") }

        if ([string]::IsNullOrWhiteSpace($fm.Description)) { $problems.Add("${rel}: description missing") }
        else {
            if ($fm.Description.Length -gt $script:MaxDescriptionChars) {
                $problems.Add("${rel}: description $($fm.Description.Length) chars exceeds $($script:MaxDescriptionChars)")
            }
            if ($fm.Description.StartsWith("'") -or $fm.Description.StartsWith('"')) {
                $problems.Add("${rel}: description is quoted; Foundry requires it unquoted")
            }
            # The separator is a dash, not a colon: YAML forbids ': ' inside an unquoted plain scalar,
            # and the description must stay unquoted. See DRIFT-003.
            if ($fm.Description -notmatch '^USE FOR - .*DO NOT USE FOR - ') {
                $problems.Add("${rel}: description is not in the 'USE FOR - ... DO NOT USE FOR - ...' shape")
            }
        }

        if ($fm.License -ne 'MIT') { $problems.Add("${rel}: license must be MIT, found '$($fm.License)'") }
        foreach ($field in @('Author', 'Version', 'Homepage')) {
            if ([string]::IsNullOrWhiteSpace($fm.Metadata.$field)) { $problems.Add("${rel}: metadata.$($field.ToLower()) missing") }
        }

        if ($fm.WhenToUse.Count -lt 5 -or $fm.WhenToUse.Count -gt 10) {
            $problems.Add("${rel}: when_to_use has $($fm.WhenToUse.Count) entries; contract requires 5 to 10")
        }

        foreach ($tool in $script:RequiredDisallowedTools) {
            # Ordinal: a host matches tool names exactly, so 'write' would not restrict Write.
            if ($tool -cnotin $fm.DisallowedTools) { $problems.Add("${rel}: disallowed-tools missing '$tool'") }
        }

        foreach ($unexpected in $fm.UnknownKeys) {
            if ($unexpected -in $script:ForbiddenFrontmatterKeys) {
                $problems.Add("${rel}: '$unexpected' is forbidden by contract")
            }
            else {
                # FR-025 fixes the field set exactly and the contract schema sets
                # additionalProperties:false. An unrecognised key is a defect, not a harmless extra.
                $problems.Add("${rel}: unexpected frontmatter key '$unexpected'")
            }
        }
    }

    if ($problems.Count -eq 0) {
        Add-CheckResult -Check 'frontmatter-schema' -Status 'pass' -Detail "$($Skills.Count) skill(s) satisfy the contract"
    }
    else {
        Add-CheckResult -Check 'frontmatter-schema' -Status 'fail' -Detail ($problems -join '; ')
    }
}

function Test-RouterTriggerPhrases {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Skills)

    $router = $Skills | Where-Object { $_.Path -match 'agentic-architecture-router' } | Select-Object -First 1
    if (-not $router) {
        Add-CheckResult -Check 'router-trigger-phrases' -Status 'fail' -Detail 'Router SKILL.md not found.'
        return
    }
    if ($router.ParseError) {
        Add-CheckResult -Check 'router-trigger-phrases' -Status 'fail' -Detail 'router frontmatter does not parse'
        return
    }
    $description = $router.Frontmatter.Description
    $missing = @($script:RequiredPhrases | Where-Object { $description -notlike "*$_*" })
    if ($missing.Count -eq 0) {
        Add-CheckResult -Check 'router-trigger-phrases' -Status 'pass' -Detail "all $($script:RequiredPhrases.Count) mandated phrases present verbatim"
    }
    else {
        Add-CheckResult -Check 'router-trigger-phrases' -Status 'fail' -Detail "missing verbatim: $($missing -join ' | ')"
    }
}

function Test-LineCaps {
    param([Parameter(Mandatory)][string] $Root)

    $problems = [System.Collections.Generic.List[string]]::new()
    $counted = 0
    $skillsDir = Join-Path $Root 'skills'
    if (-not (Test-Path -LiteralPath $skillsDir -PathType Container)) {
        Add-CheckResult -Check 'line-caps' -Status 'fail' -Detail 'skills/ not found.'
        return
    }

    foreach ($file in Get-ChildItem -LiteralPath $skillsDir -Recurse -Filter '*.md' -File) {
        $counted++
        $count = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8).Count
        $rel = [System.IO.Path]::GetRelativePath($Root, $file.FullName)
        $cap = if ($file.Name -eq 'SKILL.md') { $script:MaxSkillLines } else { $script:MaxReferenceLines }
        if ($count -gt $cap) { $problems.Add("${rel}: $count lines exceeds $cap") }
    }

    if ($problems.Count -eq 0) {
        Add-CheckResult -Check 'line-caps' -Status 'pass' -Detail "$counted markdown file(s) within caps ($($script:MaxSkillLines)/$($script:MaxReferenceLines))"
    }
    else {
        Add-CheckResult -Check 'line-caps' -Status 'fail' -Detail ($problems -join '; ')
    }
}

function Test-VersionConsistency {
    param([Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Skills)

    $parsed = @($Skills | Where-Object { -not $_.ParseError })
    $versions = [System.Collections.Generic.List[string]]::new()
    foreach ($skill in $parsed) {
        $rel = [System.IO.Path]::GetRelativePath($Root, $skill.Path)
        $versions.Add("${rel}=$($skill.Frontmatter.Metadata.Version)")
    }

    $manifests = @(
        (Join-Path $Root '.claude-plugin/plugin.json')
        (Join-Path $Root '.claude-plugin/marketplace.json')
        (Join-Path $Root '.github/plugin/marketplace.json')
    )
    $present = @($manifests | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($present.Count -eq 0) {
        Add-CheckResult -Check 'version-consistency' -Status 'pending' -Detail "no manifest exists yet; skill versions are $($versions -join ', ')"
        return
    }
    if ($present.Count -ne $manifests.Count) {
        $missing = @($manifests | Where-Object { $_ -notin $present } | ForEach-Object { [System.IO.Path]::GetRelativePath($Root, $_) })
        Add-CheckResult -Check 'version-consistency' -Status 'fail' -Detail "manifest(s) missing: $($missing -join ', ')"
        return
    }

    $distinct = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($skill in $parsed) { [void]$distinct.Add($skill.Frontmatter.Metadata.Version) }
    foreach ($manifest in $present) {
        $rel = [System.IO.Path]::GetRelativePath($Root, $manifest)
        # A check must contain its own failure. An unparseable manifest is a finding for THIS check to
        # report, not an exception that aborts the runner before any accumulated result is printed -
        # which would hide every earlier failure behind one stack trace.
        try {
            $json = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Add-CheckResult -Check 'version-consistency' -Status 'fail' -Detail "${rel}: not valid JSON, so its version cannot be compared"
            return
        }
        $v = if ($json.PSObject.Properties.Name -contains 'version') { $json.version } else { $null }
        if ($null -eq $v) {
            Add-CheckResult -Check 'version-consistency' -Status 'fail' -Detail "${rel} has no version field"
            return
        }
        [void]$distinct.Add([string]$v)
    }

    if ($distinct.Count -eq 1) {
        Add-CheckResult -Check 'version-consistency' -Status 'pass' -Detail "one version across skills and manifests: $($distinct -join '')"
    }
    else {
        Add-CheckResult -Check 'version-consistency' -Status 'fail' -Detail "versions diverge: $(($distinct | Sort-Object) -join ', ')"
    }
}

function Test-ManifestShape {
    param([Parameter(Mandatory)][string] $Root)

    # Enumerated explicitly rather than discovered: every expected manifest lives under a
    # dot-directory, which Get-ChildItem treats as hidden on Linux and skips without -Force.
    # Discovery would silently report 'pending' on the very platform CI runs on.
    $manifests = @(@(
        '.claude-plugin/plugin.json'
        '.claude-plugin/marketplace.json'
        '.github/plugin/marketplace.json'
    ) | ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        ForEach-Object { Get-Item -LiteralPath $_ -Force })
    if ($manifests.Count -eq 0) {
        Add-CheckResult -Check 'manifest-shape' -Status 'pending' -Detail 'no host manifest exists yet'
        return
    }
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($manifest in $manifests) {
        $raw = Get-Content -LiteralPath $manifest.FullName -Raw -Encoding UTF8
        if (-not (Test-Json -Json $raw -ErrorAction SilentlyContinue)) {
            $problems.Add("$([System.IO.Path]::GetRelativePath($Root, $manifest.FullName)): not valid JSON")
        }
    }
    if ($problems.Count -eq 0) {
        Add-CheckResult -Check 'manifest-shape' -Status 'pass' -Detail "$($manifests.Count) manifest(s) parse"
    }
    else {
        Add-CheckResult -Check 'manifest-shape' -Status 'fail' -Detail ($problems -join '; ')
    }
}

function Test-ManifestSync {
    param([Parameter(Mandatory)][string] $Root)
    # Delegates to the generator's own -Check mode rather than reimplementing the comparison. Two
    # implementations of "are the manifests current" would eventually disagree, and the one in CI
    # would be the one nobody ran locally.
    $sync = Join-Path $PSScriptRoot 'Sync-Manifests.ps1'
    if (-not (Test-Path -LiteralPath $sync -PathType Leaf)) {
        Add-CheckResult -Check 'manifest-sync' -Status 'fail' -Detail 'Sync-Manifests.ps1 not found.'
        return
    }
    $output = & pwsh -NoProfile -File $sync -PackageRoot $Root -Check 2>&1
    if ($LASTEXITCODE -eq 0) {
        Add-CheckResult -Check 'manifest-sync' -Status 'pass' -Detail 'manifests match generated output'
    }
    else {
        Add-CheckResult -Check 'manifest-sync' -Status 'fail' -Detail (($output | Where-Object { $_ -match '^\s+- ' }) -join '; ')
    }
}

function Test-NoSymlinks {
    param([Parameter(Mandatory)][string] $Root)
    $links = @(Get-ChildItem -LiteralPath $Root -Recurse -Force |
        Where-Object { $_.LinkType })
    if ($links.Count -eq 0) {
        Add-CheckResult -Check 'no-symlinks' -Status 'pass' -Detail 'none found'
    }
    else {
        Add-CheckResult -Check 'no-symlinks' -Status 'fail' -Detail (($links | ForEach-Object { [System.IO.Path]::GetRelativePath($Root, $_.FullName) }) -join ', ')
    }
}

function Test-NoRepoLocalSkillsDir {
    param([Parameter(Mandatory)][string] $Root)
    $path = Join-Path $Root '.github/skills'
    if (Test-Path -LiteralPath $path) {
        Add-CheckResult -Check 'no-github-skills' -Status 'fail' -Detail '.github/skills/ exists; repo-local discovery is out of scope at 1.0'
    }
    else {
        Add-CheckResult -Check 'no-github-skills' -Status 'pass' -Detail 'absent, as required'
    }
}

function Test-SecretsDenylist {
    param([Parameter(Mandatory)][string] $Root)

    $skillsDir = Join-Path $Root 'skills'
    if (-not (Test-Path -LiteralPath $skillsDir -PathType Container)) {
        Add-CheckResult -Check 'secrets-denylist' -Status 'fail' -Detail 'skills/ not found.'
        return
    }
    $allowedHosts = @('github.com', 'learn.microsoft.com', 'docs.microsoft.com', 'vslive.com')
    $problems = [System.Collections.Generic.List[string]]::new()

    foreach ($file in Get-ChildItem -LiteralPath $skillsDir -Recurse -File) {
        $rel = [System.IO.Path]::GetRelativePath($Root, $file.FullName)
        $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        if ([string]::IsNullOrEmpty($text)) { continue }

        foreach ($match in [regex]::Matches($text, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')) {
            $problems.Add("${rel}: email address '$($match.Value)'")
        }
        foreach ($match in [regex]::Matches($text, 'https?://([A-Za-z0-9.-]+)')) {
            $hostName = $match.Groups[1].Value
            if ($allowedHosts -notcontains $hostName) { $problems.Add("${rel}: non-allowlisted host '$hostName'") }
        }
        foreach ($match in [regex]::Matches($text, '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b')) {
            $problems.Add("${rel}: GUID-shaped identifier '$($match.Value)'")
        }
    }

    if ($problems.Count -eq 0) {
        Add-CheckResult -Check 'secrets-denylist' -Status 'pass' -Detail 'no email, non-allowlisted host or tenant-shaped identifier'
    }
    else {
        Add-CheckResult -Check 'secrets-denylist' -Status 'fail' -Detail ($problems -join '; ')
    }
}

function Test-NoHostSpecificText {
    param([Parameter(Mandatory)][string] $Root)

    $skillsDir = Join-Path $Root 'skills'
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $skillsDir -Recurse -Filter '*.md' -File) {
        $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
        if ($lines.Count -eq 0) { continue }
        # Only a SKILL.md has frontmatter. Reference and asset Markdown does not, and parsing it would
        # raise a terminating error that -ErrorAction cannot suppress - aborting the runner before any
        # accumulated result is printed, so an earlier real failure would never be reported at all.
        $bodyStart = 0
        if ($file.Name -eq 'SKILL.md') {
            try { $bodyStart = (Read-SkillFrontmatter -Path $file.FullName).FrontmatterEnd }
            catch { continue }   # unparseable frontmatter is frontmatter-schema's finding, not this check's
        }
        if ($bodyStart -ge $lines.Count) { continue }
        $body = ($lines[$bodyStart..($lines.Count - 1)] -join "`n")
        $rel = [System.IO.Path]::GetRelativePath($Root, $file.FullName)
        foreach ($term in $script:HostSpecificTerms) {
            if ($body -like "*$term*") { $problems.Add("${rel}: host-specific term '$term' in body") }
        }
    }
    if ($problems.Count -eq 0) {
        Add-CheckResult -Check 'no-host-specific-text' -Status 'pass' -Detail 'skill bodies are host-neutral'
    }
    else {
        Add-CheckResult -Check 'no-host-specific-text' -Status 'fail' -Detail ($problems -join '; ')
    }
}

function Test-GoldenFixtureTerminalLine {
    param([Parameter(Mandatory)][string] $Root)

    $goldenDir = Join-Path $Root 'tests/golden'
    $fixtures = @()
    if (Test-Path -LiteralPath $goldenDir -PathType Container) {
        $fixtures = @(Get-ChildItem -LiteralPath $goldenDir -Filter '*.md' -File)
    }
    if ($fixtures.Count -eq 0) {
        Add-CheckResult -Check 'fixture-terminal-line' -Status 'pending' -Detail 'no golden fixture exists yet; nothing to assert'
        return
    }
    # Literal, case-sensitive comparison of the final nonempty line. -like would treat the four
    # asterisks in the required line as wildcards, so an unbolded sentence - or trailing text after it -
    # would pass a check whose entire purpose is that the line is exact.
    $problems = @($fixtures | Where-Object {
        $lines = @(Get-Content -LiteralPath $_.FullName -Encoding UTF8)
        $lastNonEmpty = ($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
        -not $lastNonEmpty -or -not $lastNonEmpty.TrimEnd().Equals($script:TerminalLine, [System.StringComparison]::Ordinal)
    } | ForEach-Object { $_.Name })
    if ($problems.Count -eq 0) {
        Add-CheckResult -Check 'fixture-terminal-line' -Status 'pass' -Detail "$($fixtures.Count) fixture(s) end with the mandated line"
    }
    else {
        Add-CheckResult -Check 'fixture-terminal-line' -Status 'fail' -Detail "missing terminal line: $($problems -join ', ')"
    }
}

function Test-GoldenFixtureCardShape {
    <#
      FR-015 / SC-005: Decision Card mode MUST produce 12-15 source lines carrying nine specified
      fields and the mandated terminal line. T303 also checks each alternative's nonempty verdict
      and each ordered authority stage within its own field. This is a fixture contract, not proof
      of semantic correctness or host behavior; those still need the recorded behavioral run.
    #>
    param([Parameter(Mandatory)][string] $Root)

    $goldenDir = Join-Path $Root 'tests/golden'
    $cardFixtures = @()
    if (Test-Path -LiteralPath $goldenDir -PathType Container) {
        $cardFixtures = @(Get-ChildItem -LiteralPath $goldenDir -Filter '*.md' -File | Where-Object {
            (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -like "*$script:CardModeMarker*"
        })
    }
    if ($cardFixtures.Count -eq 0) {
        Add-CheckResult -Check 'fixture-card-shape' -Status 'fail' -Detail 'required Decision Card fixture or its mode marker is missing'
        return
    }

    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($fixture in $cardFixtures) {
        $raw = Get-Content -LiteralPath $fixture.FullName -Raw -Encoding UTF8
        # Strip HTML comment blocks first: they carry authoring rationale, not card content, and would
        # otherwise inflate the source-line count the check is supposed to hold to 12-15.
        $stripped = $raw -replace '(?s)<!--.*?-->', ''
        # Outer padding is not card content; interior blank lines are physical source lines.
        $sourceLines = @($stripped.Trim() -split "`r?`n")
        $lineCount = $sourceLines.Count
        # A field line is "Label: value"; the mode-indicator line and the title line are excluded by
        # name/pattern so they cannot be miscounted as one of the nine specified fields.
        $fieldLines = @($sourceLines | Where-Object {
            $_ -match '^[A-Za-z][A-Za-z /\-]*:\s' -and $_ -notmatch '^Mode:\s'
        })
        $fieldCount = $fieldLines.Count
        $lastLine = $sourceLines | Select-Object -Last 1
        $endsCorrectly = $lastLine -and $lastLine.TrimEnd().Equals($script:TerminalLine, [System.StringComparison]::Ordinal)

        if ($lineCount -lt $script:MinCardSourceLines -or $lineCount -gt $script:MaxCardSourceLines) {
            $problems.Add("$($fixture.Name): $lineCount source lines, need $script:MinCardSourceLines-$script:MaxCardSourceLines")
        }
        if ($fieldCount -ne $script:RequiredCardFieldCount) {
            $problems.Add("$($fixture.Name): $fieldCount field line(s), need exactly $script:RequiredCardFieldCount")
        }
        $fields = @{}
        foreach ($fieldLine in $fieldLines) {
            $label, $value = $fieldLine -split ':\s*', 2
            if ($fields.ContainsKey($label)) { $problems.Add("$($fixture.Name): duplicate field '$label'") }
            $fields[$label] = $value
        }
        foreach ($label in $script:RequiredCardFields) {
            if (-not $fields.ContainsKey($label) -or [string]::IsNullOrWhiteSpace($fields[$label])) {
                $problems.Add("$($fixture.Name): missing or empty field '$label'")
            }
        }
        $alternatives = [string]$fields['Rejected alternatives']
        foreach ($alternative in $script:RequiredCardAlternatives) {
            $pattern = '(?i)(?:^|;\s*)' + [regex]::Escape($alternative) + ':\s*[^;\s][^;]*'
            if ($alternatives -notmatch $pattern) {
                $problems.Add("$($fixture.Name): missing verdict for '$alternative'")
            }
        }
        $authority = [string]$fields['Authority chain']
        if ($authority -match '(?i)authorization:\s*(?:policy verdict|<the stated policy[^>]*>)\s*(?:→|->|$)') {
            $problems.Add("$($fixture.Name): authorization contains literal placeholder text; state the permitting policy or unknown - governance decision required")
        }
        # A read-only card can justify non-applicability; consequential fixtures must carry the
        # full chain as labelled stages, so a stage name elsewhere cannot disguise an omission.
        if ($authority -notmatch '(?i)^no consequential action:\s*\S.+') {
            $stages = @($authority -split '\s*(?:→|->)\s*')
            if ($stages.Count -ne $script:RequiredAuthorityStages.Count) {
                $problems.Add("$($fixture.Name): authority chain needs five ordered stages")
            }
            for ($index = 0; $index -lt $script:RequiredAuthorityStages.Count; $index++) {
                $stage = $script:RequiredAuthorityStages[$index]
                $prefix = if ($index -eq 0) { '(?:deterministic control boundary:\s*)?' } else { '' }
                $pattern = '(?i)^' + $prefix + [regex]::Escape($stage) + ':\s*\S.+'
                if ($index -ge $stages.Count -or $stages[$index] -notmatch $pattern) {
                    $problems.Add("$($fixture.Name): missing or misplaced authority stage '$stage'")
                }
            }
        }
        if (-not $endsCorrectly) {
            $problems.Add("$($fixture.Name): does not end with the mandated terminal line")
        }
    }

    if ($problems.Count -eq 0) {
        Add-CheckResult -Check 'fixture-card-shape' -Status 'pass' -Detail "$($cardFixtures.Count) Decision Card fixture(s) satisfy line/field counts, five verdicts, authority chain, and terminal line"
    }
    else {
        Add-CheckResult -Check 'fixture-card-shape' -Status 'fail' -Detail ($problems -join '; ')
    }
}

function Test-MarkdownLint {
    param([Parameter(Mandatory)][string] $Root)

    $tool = Get-Command 'markdownlint' -ErrorAction SilentlyContinue
    if (-not $tool) {
        Add-CheckResult -Check 'markdown-lint' -Status 'warn' -Detail 'markdownlint not on PATH; CI installs it pinned, where this check blocks'
        return
    }
    # The package's own config is passed explicitly. markdownlint otherwise resolves config from the
    # working directory, so a run from a parent tree would lint against that tree's rules and pass or
    # fail for reasons that have nothing to do with the package.
    $config = Join-Path $Root '.markdownlint.json'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
        Add-CheckResult -Check 'markdown-lint' -Status 'fail' -Detail '.markdownlint.json missing from the package root'
        return
    }
    # Files are enumerated here and passed explicitly rather than as a glob. markdownlint's glob
    # treats a backslash as an escape, so a Windows path matched nothing and exited 0 - a check that
    # reported clean without linting a file. The count in the detail line is what makes that visible.
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.md' -File | ForEach-Object { $_.FullName })
    if ($files.Count -eq 0) {
        Add-CheckResult -Check 'markdown-lint' -Status 'fail' -Detail 'no markdown files found under the package root'
        return
    }
    $output = & $tool.Source --config $config @files 2>&1
    if ($LASTEXITCODE -eq 0) {
        Add-CheckResult -Check 'markdown-lint' -Status 'pass' -Detail "$($files.Count) file(s) clean"
    }
    else {
        Add-CheckResult -Check 'markdown-lint' -Status 'fail' -Detail (($output | Select-Object -First 5) -join '; ')
    }
}

function Test-ExternalLinks {
    param([Parameter(Mandatory)][string] $Root)
    # Non-blocking at 1.0 by decision: a flaky external link failing the build on release night is a
    # self-inflicted wound. Promoted to blocking after the sessions.
    Add-CheckResult -Check 'external-links' -Status 'warn' -Detail 'non-blocking at 1.0; not yet implemented'
}

# --- run ---------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "Package root not found: '$PackageRoot'."
}

$skillFiles = [string[]](Get-SkillFiles -Root $PackageRoot)
$skills = @(Resolve-Skills -SkillFiles $skillFiles)

Test-FrontmatterContract -Skills $skills
Test-RouterTriggerPhrases -Skills $skills
Test-LineCaps -Root $PackageRoot
Test-VersionConsistency -Root $PackageRoot -Skills $skills
Test-ManifestShape -Root $PackageRoot
Test-ManifestSync -Root $PackageRoot
Test-NoSymlinks -Root $PackageRoot
Test-NoRepoLocalSkillsDir -Root $PackageRoot
Test-SecretsDenylist -Root $PackageRoot
Test-NoHostSpecificText -Root $PackageRoot
Test-GoldenFixtureTerminalLine -Root $PackageRoot
Test-GoldenFixtureCardShape -Root $PackageRoot
Test-MarkdownLint -Root $PackageRoot
Test-ExternalLinks -Root $PackageRoot

$width = ($script:Results.Check | Measure-Object -Property Length -Maximum).Maximum
Write-Output ''
Write-Output "Package validity - $PackageRoot"
Write-Output ('-' * 72)
foreach ($result in $script:Results) {
    Write-Output ("{0,-7} {1}  {2}" -f $result.Status.ToUpper(), $result.Check.PadRight($width), $result.Detail)
}
Write-Output ('-' * 72)

$failed = @($script:Results | Where-Object { $_.Status -eq 'fail' })
$pending = @($script:Results | Where-Object { $_.Status -eq 'pending' })
$warned = @($script:Results | Where-Object { $_.Status -eq 'warn' })
Write-Output ("{0} checks: {1} pass, {2} fail, {3} pending, {4} warn" -f
    $script:Results.Count,
    @($script:Results | Where-Object { $_.Status -eq 'pass' }).Count,
    $failed.Count, $pending.Count, $warned.Count)

if ($failed.Count -gt 0) {
    Write-Output ''
    Write-Output 'BLOCKING failures:'
    foreach ($f in $failed) { Write-Output "  - $($f.Check): $($f.Detail)" }
    exit 1
}
exit 0
