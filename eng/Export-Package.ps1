#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory = $true)]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-NoReparsePointAncestor {
    # Lexical overlap checks cannot detect two names for the same physical directory. Refuse
    # aliases on either path, including existing ancestors of a destination not created yet.
    param([Parameter(Mandatory)][string] $Path)

    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Export paths must not traverse a junction or symbolic link: $current"
            }
        }
        $current = Split-Path -Path $current -Parent
    }
}

Assert-NoReparsePointAncestor -Path $SourcePath
Assert-NoReparsePointAncestor -Path $ExportPath
$source = [IO.Path]::TrimEndingDirectorySeparator((Resolve-Path -LiteralPath $SourcePath).Path)
$destination = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($ExportPath))
Assert-NoReparsePointAncestor -Path $source

$allowed = @(
    '.claude-plugin',
    '.github',
    'eng',
    'skills',
    'tests',
    '.gitattributes',
    '.gitignore',
    '.markdownlint.json',
    'CHANGELOG.md',
    'LICENSE',
    'README.md',
    'VERSION'
)

$sourceSep = "$source$([IO.Path]::DirectorySeparatorChar)"
$destSep = "$destination$([IO.Path]::DirectorySeparatorChar)"
$isSelfOrDescendant = $destination -eq $source -or $destination.StartsWith($sourceSep, [StringComparison]::OrdinalIgnoreCase)
$isAncestor = $source.StartsWith($destSep, [StringComparison]::OrdinalIgnoreCase)
$isRoot = [IO.Path]::GetPathRoot($destination) -eq $destination
if ($isSelfOrDescendant -or $isAncestor -or $isRoot) {
    throw "ExportPath must not be the package source, an ancestor or descendant of it, or a filesystem root."
}

# An existing destination is only replaced if a prior export marked it as export-owned; anything
# else (an unrelated directory reused by mistake) is refused rather than silently deleted.
$ownershipMarker = Join-Path $destination '.export-owned'
if (Test-Path -LiteralPath $destination) {
    # A distribution checkout may retain the ownership marker from an earlier export. Never erase
    # its history, remotes, or worktree link; export to a separate staging directory instead.
    if (Test-Path -LiteralPath (Join-Path $destination '.git')) {
        throw "ExportPath is a Git checkout; export to a separate staging directory: $destination"
    }
    if (-not (Test-Path -LiteralPath $ownershipMarker)) {
        throw "ExportPath already exists and is not a directory this script created ('.export-owned' marker missing): $destination"
    }
    Remove-Item -LiteralPath $destination -Recurse -Force
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
New-Item -ItemType File -Path $ownershipMarker -Force | Out-Null

foreach ($entry in $allowed) {
    $from = Join-Path $source $entry
    if (-not (Test-Path -LiteralPath $from)) {
        throw "Required package entry is missing: $entry"
    }
    Copy-Item -LiteralPath $from -Destination (Join-Path $destination $entry) -Recurse -Force
}

function Get-Manifest([string]$root) {
    # -Force is required: hidden payload files/directories (.claude-plugin, .github, dotfiles under
    # them) must not silently drop out of the parity check just because they are dotfiles.
    @(Get-ChildItem -LiteralPath $root -File -Recurse -Force | Where-Object {
        $_.FullName -notmatch '[\\/]\.git([\\/]|$)'
    } | ForEach-Object {
        [PSCustomObject]@{
            Path = $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
            Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    } | Where-Object { $_.Path -ne '.export-owned' } | Sort-Object Path)
}

$sourceManifest = Get-Manifest $source
$exportManifest = Get-Manifest $destination
$sourceJson = $sourceManifest | ConvertTo-Json -Compress
$exportJson = $exportManifest | ConvertTo-Json -Compress
if ($sourceJson -cne $exportJson) {
    $missing = Compare-Object $sourceManifest.Path $exportManifest.Path | Where-Object SideIndicator -eq '<='
    $extra = Compare-Object $sourceManifest.Path $exportManifest.Path | Where-Object SideIndicator -eq '=>'
    throw "Export parity failed. Missing: $($missing.InputObject -join ', '); extra: $($extra.InputObject -join ', ')"
}

Write-Output "PASS export-parity files=$($exportManifest.Count) path=$destination"
