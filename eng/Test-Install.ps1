#Requires -Version 7.0
<#
.SYNOPSIS
    Installs the package on both hosts inside a clean container, timed, and records the result.

.DESCRIPTION
    SC-001 says a clean machine installs the package from the README alone in under a minute per host.
    This script makes that claim checkable rather than asserted: it builds the container defined in
    tests/install/Dockerfile (Node, git and the two hosts at pinned versions, a fresh user, nothing
    else), runs tests/install/run-install.sh inside it, and writes the outcome to tests/results/ as the
    recorded run the README points at. The same command runs on a maintainer's machine and on the
    GitHub runner; only the recording differs (CI keeps the file as a workflow artifact).

    The package is installed from GitHub, not copied into the container, so a pass means the published
    path works. A private repository needs a token: GH_TOKEN if set, otherwise `gh auth token` when the
    GitHub CLI is available. The token is passed to the container's environment and never written.

.PARAMETER Source
    GitHub repository the hosts install from. Defaults to the published repository.

.PARAMETER NoRecord
    Print the report but do not write a file under tests/results/. Used in CI.

.EXAMPLE
    pwsh -File ./eng/Test-Install.ps1
#>

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $Source = 'alonf/agentic-architecture-skills',

    [ValidateNotNullOrEmpty()]
    [string] $PackageRoot = (Split-Path -Parent $PSScriptRoot),

    [switch] $NoRecord,

    [ValidateNotNullOrEmpty()]
    [string] $ImageTag = 'agentic-architecture-skills-install-check'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# docker streams UTF-8; without this, box-drawing characters in the installers' output are mis-decoded
# on Windows and the record fills with mojibake.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. (Join-Path $PSScriptRoot 'Protect-Secret.ps1')
. (Join-Path $PSScriptRoot 'ConvertFrom-InstallResult.ps1')

$contextDir = Join-Path $PackageRoot 'tests/install'
$resultsDir = Join-Path $PackageRoot 'tests/results'

function Get-DockerPlatform {
    $platform = & docker info --format '{{.OSType}}/{{.Architecture}} engine {{.ServerVersion}}' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon is not reachable. Start Docker (Desktop) and re-run. Docker said: $platform"
    }
    "$platform"
}

function Get-PinnedVersions {
    # The Dockerfile is the single place the versions are declared; read them from it for the record.
    $pins = [ordered]@{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $contextDir 'Dockerfile')) {
        if ($line -match '^ARG\s+(\w+)=(\S+)') { $pins[$Matches[1]] = $Matches[2] }
    }
    $pins
}

function Resolve-Token {
    if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { return 'GH_TOKEN (environment)' }
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        $token = & $gh.Source auth token 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($token)) {
            $env:GH_TOKEN = $token.Trim()
            return 'gh auth token'
        }
    }
    'none (public repository assumed)'
}

$platform = Get-DockerPlatform
$pins = Get-PinnedVersions
$tokenSource = Resolve-Token
$startedAt = [DateTimeOffset]::UtcNow

Write-Output "Install verification - $Source"
Write-Output "docker: $platform | token: $tokenSource"
Write-Output ("image: {0} | claude-code {1} | copilot {2} | skills {3}" -f $pins['NODE_IMAGE'], $pins['CLAUDE_CODE_VERSION'], $pins['COPILOT_CLI_VERSION'], $pins['SKILLS_CLI_VERSION'])
Write-Output ''

$buildStart = Get-Date
& docker build --pull --quiet --tag $ImageTag $contextDir 2>&1 | ForEach-Object { "build: $_" }
if ($LASTEXITCODE -ne 0) { throw 'docker build failed; see output above.' }
$buildSeconds = [int]((Get-Date) - $buildStart).TotalSeconds
Write-Output "build: image ready in ${buildSeconds}s (build time is not part of the install measurement)"

# Every line is masked the moment it is captured, so the token value cannot reach the console, the
# RESULT parser or the record by any path. What follows only ever sees the masked log.
$log = & docker run --rm -e GH_TOKEN -e "PACKAGE_SOURCE=$Source" $ImageTag 2>&1 |
    ForEach-Object { Protect-Secret -Text "$_" -Secret ([string]$env:GH_TOKEN) }
$runExit = $LASTEXITCODE
$log | ForEach-Object { Write-Output $_ }

$results = @($log | Where-Object { $_ -like 'RESULT *' } | ForEach-Object { ConvertFrom-InstallResult -Line $_ })

if (-not $NoRecord) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
    $file = Join-Path $resultsDir ("{0}-install-linux-container.md" -f $startedAt.ToString('yyyy-MM-dd'))
    $verdict = if ($runExit -eq 0) { 'PASS' } else { "FAIL (exit $runExit)" }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Install verification - $($startedAt.ToString('yyyy-MM-dd'))")
    $lines.Add('')
    $lines.Add("**Outcome**: $verdict")
    $lines.Add("**Recorded**: $($startedAt.ToString('u'))")
    $lines.Add("**Source**: ``$Source`` (installed from GitHub, as the README documents)")
    $lines.Add("**Machine**: clean container, $platform, base image ``$($pins['NODE_IMAGE'])``, fresh non-root user")
    $lines.Add("**Hosts**: Claude Code $($pins['CLAUDE_CODE_VERSION']), GitHub Copilot CLI $($pins['COPILOT_CLI_VERSION']), skills CLI $($pins['SKILLS_CLI_VERSION'])")
    $lines.Add("**Limit**: 60 s per host (SC-001), both skills present after install")
    $lines.Add('')
    $lines.Add('| Path | Blocking | Status | Reason | Install time | Skills found |')
    $lines.Add('| ---- | -------- | ------ | ------ | ------------ | ------------ |')
    foreach ($r in $results) {
        $seconds = [math]::Round([int]$r.elapsed_ms / 1000, 1)
        $lines.Add("| $($r.path) | $($r.blocking) | $($r.status) | $($r.reason) | ${seconds} s | $($r.skills) |")
    }
    $lines.Add('')
    $lines.Add('## Log')
    $lines.Add('')
    $lines.Add('```text')
    foreach ($l in $log) {
        # Already masked at capture. Terminal control sequences and spinner frames are noise in a record.
        $clean = $l -replace "`e\[[0-9;?]*[A-Za-z]", ''
        if ($clean -match '^[◒◐◓◑]\s') { continue }
        $lines.Add($clean.TrimEnd())
    }
    $lines.Add('```')
    Set-Content -LiteralPath $file -Value (($lines -join "`n") + "`n") -Encoding UTF8 -NoNewline
    Write-Output ''
    Write-Output "recorded: $file"
}

exit $runExit
