#Requires -Version 7.0
<#
.SYNOPSIS
    Computes the content digest of a set of skill directories, the same way tests/install/digest-skills.sh does.

.DESCRIPTION
    The install verification binds what a host installed to the tree it was supposed to install from.
    Where a host keeps a git clone of the source, the clone's HEAD is that binding; where it does not,
    this digest is. Both sides compute it the same way, so the definition here and in digest-skills.sh
    MUST change together (Test-Checks.ps1 proves they agree on the real package):

      for every regular file under each named skill directory, excluding dotfiles, take its path
      relative to the skills root (forward slashes) and the SHA-256 of its bytes with every CR removed;
      sort the paths bytewise; hash the text "<path>\n<sha256>\n" for each in that order.

    CRs are removed because a host may rewrite line endings when it copies a skill, and a line-ending
    change is not a content change for these Markdown files.

.PARAMETER SkillsRoot
    The directory that holds the skill directories (the package's skills/).

.PARAMETER Skill
    The skill directory names to include, in any order. Every one must exist.

.EXAMPLE
    . ./eng/Get-SkillsTreeDigest.ps1
    Get-SkillsTreeDigest -SkillsRoot ./skills -Skill agentic-architecture-router, maf-architecture-mapping
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SkillsTreeDigest {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $SkillsRoot,
        [Parameter(Mandatory)][string[]] $Skill
    )
    $root = (Resolve-Path -LiteralPath $SkillsRoot).Path
    foreach ($name in $Skill) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $name) -PathType Container)) {
            throw "Skill directory '$name' is not under '$root'."
        }
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashByPath = @{}
        foreach ($name in $Skill) {
            foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $root $name) -Recurse -File)) {
                if ($file.Name.StartsWith('.')) { continue }
                $relative = [System.IO.Path]::GetRelativePath($root, $file.FullName) -replace '\\', '/'
                $withoutCr = [byte[]]@([System.IO.File]::ReadAllBytes($file.FullName) | Where-Object { $_ -ne 13 })
                $hashByPath[$relative] = ($sha.ComputeHash($withoutCr) | ForEach-Object { $_.ToString('x2') }) -join ''
            }
        }
        # Bytewise ordering, as LC_ALL=C sort does, so both implementations list the files identically.
        $paths = [string[]]$hashByPath.Keys
        [Array]::Sort($paths, [System.StringComparer]::Ordinal)
        $manifest = ($paths | ForEach-Object { "$_`n$($hashByPath[$_])`n" }) -join ''
        ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($manifest)) | ForEach-Object { $_.ToString('x2') }) -join ''
    }
    finally {
        $sha.Dispose()
    }
}
