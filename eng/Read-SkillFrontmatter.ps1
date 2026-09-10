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

# Characters that, at the start of a plain scalar, make YAML read something other than a string:
# a sequence or mapping indicator, a comment, an anchor/alias, a tag, a block scalar header, a quote,
# a directive or a reserved indicator. A value starting with one of these is outside this contract.
$script:PlainScalarForbiddenStart = [char[]]'-?:,[]{}#&*!|>''"%@`'

function Assert-PlainScalar {
    <#
      Every value in this frontmatter is an unquoted YAML plain scalar. This function defines the
      subset the contract supports and rejects anything a conforming YAML parser would read differently
      from "the rest of the line is the string":

        - ': ' or ':<tab>' inside the value, or a trailing ':'  - a mapping indicator (DRIFT-003)
        - ' #' inside the value                                  - starts a comment; a host would see
                                                                   the description truncated there
        - a first character from PlainScalarForbiddenStart       - alias, anchor, flow collection, tag,
                                                                   block scalar, quote, comment...
        - a tab anywhere                                         - never legal in this frontmatter

      Splitting on the first colon, as this parser does, cannot see any of these on its own - it
      accepted 'USE FOR: ...' for two commits while every real YAML parser refused it. So the subset is
      asserted here, where the value is read. Comments are not part of the contract at all, so a legal
      YAML comment containing ': ' is rejected deliberately rather than parsed.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Value,
        [Parameter(Mandatory)][string] $Where
    )
    if ($Value.Length -eq 0) { return }
    if ($Value.Contains(': ') -or $Value.Contains(":`t") -or $Value.EndsWith(':')) {
        throw "$Where`: value contains ': ' (or a trailing ':'), which is a mapping indicator, not part of an unquoted YAML plain scalar."
    }
    if ($Value.Contains(' #')) {
        throw "$Where`: value contains ' #', which starts a YAML comment; a host would read the value truncated there."
    }
    if ($Value.Contains("`t")) {
        throw "$Where`: value contains a tab, which is not allowed in this frontmatter."
    }
    if ($Value[0] -in $script:PlainScalarForbiddenStart) {
        throw "$Where`: value starts with '$($Value[0])', a YAML indicator; only unquoted plain scalars are allowed."
    }
}

function Split-MappingLine {
    <#
      Splits 'key: value' or 'key:' (a block key) exactly as YAML does for this contract: the key is
      everything before the first ':' that is followed by a space or the end of the line. 'key:value'
      with no space is not a mapping entry in YAML and is rejected rather than guessed at.
    #>
    param(
        [Parameter(Mandatory)][string] $Line,
        [Parameter(Mandatory)][string] $Where
    )
    if ($Line -notmatch '^([^:\s][^:]*?)\s*:(?:\s+(.*))?$') {
        throw "$Where`: not a 'key: value' mapping entry (a colon must be followed by a space or end the line)."
    }
    [pscustomobject]@{ Key = $Matches[1]; Value = if ($Matches.ContainsKey(2)) { $Matches[2].Trim() } else { '' } }
}

function Add-UniqueKey {
    <#
      YAML forbids duplicate keys in a mapping; a parser that silently keeps the last one lets a
      duplicated 'disallowed-tools' hide a restriction that was removed. Keys are compared ordinally,
      because 'Disallowed-Tools' is a different key from 'disallowed-tools' to every host.
    #>
    param(
        # Not Mandatory: PowerShell refuses an empty collection for a mandatory parameter, and the set
        # is empty until the first key.
        [AllowEmptyCollection()][System.Collections.Generic.HashSet[string]] $Seen,
        [Parameter(Mandatory)][string] $Key,
        [Parameter(Mandatory)][string] $Where
    )
    if (-not $Seen.Add($Key)) { throw "$Where`: duplicate key '$Key'." }
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

    # Ordinal everywhere: 'Name' and 'name' are different keys to every host, so they are here too.
    $ordinal = [System.StringComparer]::Ordinal
    $scalars = [System.Collections.Generic.Dictionary[string, string]]::new($ordinal)
    $sequences = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new($ordinal)
    $metadata = [System.Collections.Generic.Dictionary[string, string]]::new($ordinal)
    $topLevelSeen = [System.Collections.Generic.HashSet[string]]::new($ordinal)
    $metadataSeen = [System.Collections.Generic.HashSet[string]]::new($ordinal)
    $unknownKeys = [System.Collections.Generic.List[string]]::new()
    $currentSequence = $null
    $inMetadata = $false

    for ($i = 1; $i -lt $closing; $i++) {
        $line = $lines[$i]
        $where = "'$Path' line $($i + 1)"
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.TrimStart().StartsWith('#')) {
            throw "$where`: comments are not part of this frontmatter contract."
        }

        # A sequence item or a metadata entry: exactly two spaces of indent.
        if ($line.StartsWith('  ')) {
            $indented = $line.Substring(2)
            if ($indented.StartsWith(' ')) {
                throw "$where`: indentation must be exactly two spaces for nested entries."
            }

            if ($indented.StartsWith('- ')) {
                if ($null -eq $currentSequence) {
                    throw "$where`: list item outside any sequence key."
                }
                $item = $indented.Substring(2).Trim()
                Assert-PlainScalar -Value $item -Where $where
                $sequences[$currentSequence].Add($item)
                continue
            }

            if (-not $inMetadata) {
                throw "$where`: indented entry outside the metadata block."
            }

            $entry = Split-MappingLine -Line $indented -Where $where
            Add-UniqueKey -Seen $metadataSeen -Key $entry.Key -Where $where
            if ($entry.Key -cnotin $script:KnownMetadataKeys) {
                $unknownKeys.Add("metadata.$($entry.Key)")
            }
            Assert-PlainScalar -Value $entry.Value -Where $where
            $metadata[$entry.Key] = $entry.Value
            continue
        }

        if ($line.StartsWith(' ')) {
            throw "$where`: indentation must be exactly two spaces for nested entries."
        }

        # A top-level key. The value may itself contain colons (the description does); only the
        # first ': ' is the separator.
        $entry = Split-MappingLine -Line $line -Where $where
        $key = $entry.Key
        $value = $entry.Value
        Add-UniqueKey -Seen $topLevelSeen -Key $key -Where $where

        $currentSequence = $null
        $inMetadata = $false

        # -ceq / -cin: the contract's keys are lowercase and a host reads them ordinally.
        if ($key -ceq 'metadata') {
            if ($value -ne '') { throw "$where`: 'metadata' must be a nested block, not a scalar." }
            $inMetadata = $true
        }
        elseif ($key -cin $script:KnownSequenceKeys) {
            if ($value -ne '') { throw "$where`: '$key' must be a list, not a scalar." }
            $sequences[$key] = [System.Collections.Generic.List[string]]::new()
            $currentSequence = $key
        }
        elseif ($key -cin $script:KnownScalarKeys) {
            if ($value -eq '') { throw "$where`: '$key' has no value." }
            Assert-PlainScalar -Value $value -Where $where
            $scalars[$key] = $value
        }
        else {
            # Recorded rather than thrown: the caller decides whether an unknown key is fatal.
            # allowed-tools, hooks and compatibility are forbidden by contract and Test-Skills.ps1
            # reports them by name, which is a better error than a parse failure. A key that differs
            # from a contract key only by case lands here too, and is reported as unexpected.
            $unknownKeys.Add($key)
            if ($value -eq '') { $sequences[$key] = [System.Collections.Generic.List[string]]::new(); $currentSequence = $key }
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
