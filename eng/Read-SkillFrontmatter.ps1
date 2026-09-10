#Requires -Version 7.0
<#
.SYNOPSIS
    Reads the frontmatter block of a SKILL.md into an object.

.DESCRIPTION
    This is deliberately NOT a YAML parser. It reads the exact frontmatter shape this package
    defines and validates in CI - scalars, one nested `metadata` block, and two flat sequences -
    and it throws on anything it does not recognise rather than guessing.

    That is the whole justification for hand-writing it: a general parser would solve a problem the
    package does not have, at the cost of a module install in every CI run. A parser that silently
    accepts more than the contract allows would also let a malformed skill through the check that
    exists to catch it, so unknown keys are an error, not a shrug.

.PARAMETER Path
    Path to a SKILL.md file.

.OUTPUTS
    PSCustomObject with: Name, Description, License, Metadata (Author/Version/Homepage),
    WhenToUse (string[]), DisallowedTools (string[]), TotalLineCount, and UnknownKeys (string[]).

.EXAMPLE
    . ./eng/Read-SkillFrontmatter.ps1
    Read-SkillFrontmatter -Path ./skills/agentic-architecture-router/SKILL.md
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:KnownScalarKeys = @('name', 'description', 'license')
$script:KnownSequenceKeys = @('when_to_use', 'disallowed-tools')
$script:KnownMetadataKeys = @('author', 'version', 'homepage')

function Assert-PlainScalar {
    <#
      Every value in this frontmatter is an unquoted YAML plain scalar, and YAML does not allow a
      plain scalar to contain ': ' (or to end in ':'): the colon becomes a mapping indicator and a
      conforming parser rejects the document. Splitting on the first colon, as this parser does,
      cannot see that on its own - it accepted 'USE FOR: ...' for two commits while every real YAML
      parser refused it (DRIFT-003). So the rule is asserted here, where the value is read.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Value,
        [Parameter(Mandatory)][string] $Where
    )
    if ($Value.Contains(': ') -or $Value.EndsWith(':')) {
        throw "$Where`: value contains ': ' (or a trailing ':'), which is not valid in an unquoted YAML plain scalar."
    }
}

function Read-SkillFrontmatter {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Skill file not found: '$Path'."
    }

    $lines = [string[]](Get-Content -LiteralPath $Path -Encoding UTF8)
    if ($lines.Count -eq 0 -or $lines[0].TrimEnd() -ne '---') {
        throw "'$Path' does not open with a '---' frontmatter delimiter on line 1."
    }

    $closing = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].TrimEnd() -eq '---') { $closing = $i; break }
    }
    if ($closing -lt 0) {
        throw "'$Path' has no closing '---' frontmatter delimiter."
    }

    $scalars = @{}
    $sequences = @{}
    $metadata = @{}
    $unknownKeys = [System.Collections.Generic.List[string]]::new()
    $currentSequence = $null
    $inMetadata = $false

    for ($i = 1; $i -lt $closing; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # A sequence item or a metadata entry: exactly two spaces of indent.
        if ($line.StartsWith('  ')) {
            $indented = $line.Substring(2)

            if ($indented.StartsWith('- ')) {
                if ($null -eq $currentSequence) {
                    throw "'$Path' line $($i + 1): list item outside any sequence key."
                }
                $item = $indented.Substring(2).Trim()
                Assert-PlainScalar -Value $item -Where "'$Path' line $($i + 1)"
                $sequences[$currentSequence].Add($item)
                continue
            }

            if (-not $inMetadata) {
                throw "'$Path' line $($i + 1): indented entry outside the metadata block."
            }

            $split = $indented.IndexOf(':')
            if ($split -lt 1) {
                throw "'$Path' line $($i + 1): metadata entry is not 'key: value'."
            }
            $metaKey = $indented.Substring(0, $split).Trim()
            if ($metaKey -notin $script:KnownMetadataKeys) {
                $unknownKeys.Add("metadata.$metaKey")
            }
            $metaValue = $indented.Substring($split + 1).Trim()
            Assert-PlainScalar -Value $metaValue -Where "'$Path' line $($i + 1)"
            $metadata[$metaKey] = $metaValue
            continue
        }

        # A top-level key. Split on the FIRST colon only: the description contains several.
        $split = $line.IndexOf(':')
        if ($split -lt 1) {
            throw "'$Path' line $($i + 1): frontmatter line is not 'key: value'."
        }
        $key = $line.Substring(0, $split).Trim()
        $value = $line.Substring($split + 1).Trim()

        $currentSequence = $null
        $inMetadata = $false

        switch ($key) {
            'metadata' {
                if ($value -ne '') { throw "'$Path' line $($i + 1): 'metadata' must be a nested block, not a scalar." }
                $inMetadata = $true
            }
            { $_ -in $script:KnownSequenceKeys } {
                if ($value -ne '') { throw "'$Path' line $($i + 1): '$key' must be a list, not a scalar." }
                $sequences[$key] = [System.Collections.Generic.List[string]]::new()
                $currentSequence = $key
            }
            { $_ -in $script:KnownScalarKeys } {
                if ($value -eq '') { throw "'$Path' line $($i + 1): '$key' has no value." }
                Assert-PlainScalar -Value $value -Where "'$Path' line $($i + 1)"
                $scalars[$key] = $value
            }
            default {
                # Recorded rather than thrown: the caller decides whether an unknown key is fatal.
                # allowed-tools, hooks and compatibility are forbidden by contract and Test-Skills.ps1
                # reports them by name, which is a better error than a parse failure.
                $unknownKeys.Add($key)
                if ($value -eq '') { $sequences[$key] = [System.Collections.Generic.List[string]]::new(); $currentSequence = $key }
            }
        }
    }

    [pscustomobject]@{
        Path            = $Path
        Name            = if ($scalars.ContainsKey('name')) { $scalars['name'] } else { $null }
        Description     = if ($scalars.ContainsKey('description')) { $scalars['description'] } else { $null }
        License         = if ($scalars.ContainsKey('license')) { $scalars['license'] } else { $null }
        Metadata        = [pscustomobject]@{
            Author   = if ($metadata.ContainsKey('author')) { $metadata['author'] } else { $null }
            Version  = if ($metadata.ContainsKey('version')) { $metadata['version'] } else { $null }
            Homepage = if ($metadata.ContainsKey('homepage')) { $metadata['homepage'] } else { $null }
        }
        WhenToUse       = if ($sequences.ContainsKey('when_to_use')) { [string[]]$sequences['when_to_use'] } else { @() }
        DisallowedTools = if ($sequences.ContainsKey('disallowed-tools')) { [string[]]$sequences['disallowed-tools'] } else { @() }
        UnknownKeys     = [string[]]$unknownKeys
        TotalLineCount  = $lines.Count
        FrontmatterEnd  = $closing + 1
    }
}
