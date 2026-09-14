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
    GitHub runner; only where the record goes differs (-OutputPath).

    A record is ALWAYS written unless -NoRecord is given - including when Docker is unreachable, the
    image fails to build, or the container's output cannot be parsed. A run that produced no record
    would leave the previous PASS record as the newest evidence, which is the wrong evidence.

    The outcome is PASS only when every expected install path reported exactly once, every blocking
    path passed, and the container exited 0. The container exiting 0 is not sufficient on its own.

    The package is installed from GitHub, not copied into the container, so a pass means the published
    path works. A private repository needs a token: GH_TOKEN if set, otherwise `gh auth token` when the
    GitHub CLI is available. The token is passed to the container's environment, masked out of every
    captured line the moment it is read, and never written.

    What the hosts install is bound to what the run claims to have tested. The hosts clone the source's
    default branch and take no ref, so a push between checkout and install, or a workflow_dispatch on
    another ref, would otherwise let a PASS stand for content that was never installed. Each path
    therefore reports the revision the host cloned (where it kept git metadata) and a content digest of
    the installed skills; a blocking path passes only when the digest equals the digest of the skills
    under -PackageRoot and any exposed revision equals -ExpectedRevision. The record names both.

.PARAMETER Source
    GitHub repository in owner/repo form. URLs and other hosts are rejected before credentials
    are read. Defaults to the published repository.

.PARAMETER ExpectedRevision
    The 40-hex commit the hosts are expected to have installed. CI passes the triggering commit. When
    omitted, the source's default-branch tip is resolved with `git ls-remote` before the install and
    used as the expectation; the record says which of the two it was.

.PARAMETER OutputPath
    Where the record is written. Defaults to tests/results/<yyyy-MM-dd>-install-linux-container.md
    under the package. CI passes a path outside the tree and uploads only that file.

.PARAMETER NoRecord
    Print the report but write no file.

.EXAMPLE
    pwsh -File ./eng/Test-Install.ps1

.EXAMPLE
    pwsh -File ./eng/Test-Install.ps1 -ExpectedRevision $env:GITHUB_SHA -OutputPath "$env:RUNNER_TEMP/install-verification/current-run.md"
#>

[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/(?!\.{1,2}$)[A-Za-z0-9_.-]+$')]
    [string] $Source = 'alonf/agentic-architecture-skills',

    [ValidatePattern('^(|[0-9a-f]{40})$')]
    [string] $ExpectedRevision = '',

    [ValidateNotNullOrEmpty()]
    [string] $PackageRoot = (Split-Path -Parent $PSScriptRoot),

    [string] $OutputPath = '',

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
. (Join-Path $PSScriptRoot 'Get-SkillsTreeDigest.ps1')

$contextDir = Join-Path $PackageRoot 'tests/install'
$skillsRoot = Join-Path $PackageRoot 'skills'
$startedAt = [DateTimeOffset]::UtcNow
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PackageRoot 'tests/results' ("{0}-install-linux-container.md" -f $startedAt.ToString('yyyy-MM-dd'))
}

# The paths run-install.sh reports, in order. The verdict requires each exactly once.
$script:ExpectedPaths = @('claude-code', 'copilot-cli', 'copilot-cli-direct', 'skills-cli')

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

function Resolve-ExpectedRevision {
    # Returns @{ Sha; Origin }. The caller's value wins; otherwise the default-branch tip is read from
    # the source BEFORE the install, so a push that lands during the run is caught as a mismatch rather
    # than silently becoming the expectation. Runs after Resolve-Token so a private source is readable.
    if (-not [string]::IsNullOrWhiteSpace($ExpectedRevision)) {
        return [pscustomobject]@{ Sha = $ExpectedRevision; Origin = 'given by the caller' }
    }
    $url = "https://github.com/$Source.git"
    # The token reaches git through its environment-config channel, never the command line, so it is
    # not visible in a process listing; the variables are cleared as soon as the call returns.
    $tokenConfig = @{}
    if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
        $basic = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("x-access-token:$($env:GH_TOKEN)"))
        $tokenConfig = @{ GIT_CONFIG_COUNT = '1'; GIT_CONFIG_KEY_0 = 'http.https://github.com/.extraheader'; GIT_CONFIG_VALUE_0 = "AUTHORIZATION: basic $basic" }
    }
    try {
        foreach ($k in $tokenConfig.Keys) { Set-Item -LiteralPath "Env:$k" -Value $tokenConfig[$k] }
        $tip = @(& git ls-remote $url HEAD 2>&1 | ForEach-Object { Protect-Secret -Text "$_" -Secret ([string]$env:GH_TOKEN) })
        $exit = $LASTEXITCODE
    }
    finally {
        foreach ($k in $tokenConfig.Keys) { Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue }
    }
    if ($exit -ne 0 -or "$($tip -join ' ')" -notmatch '^([0-9a-f]{40})\s') {
        throw "Could not resolve the default-branch tip of '$Source' to bind the install to; pass -ExpectedRevision. git said: $($tip -join ' ')"
    }
    [pscustomobject]@{ Sha = $Matches[1]; Origin = 'default-branch tip of the source at run start (ls-remote)' }
}

function Write-Record {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Outcome,
        [AllowEmptyCollection()][string[]] $Reasons = @(),
        [AllowEmptyCollection()][object[]] $Results = @(),
        [AllowEmptyCollection()][string[]] $Log = @(),
        [AllowEmptyCollection()][string[]] $Notes = @(),
        [string] $Platform = 'unknown',
        [System.Collections.Specialized.OrderedDictionary] $Pins = [ordered]@{},
        [string] $ExpectedSha = 'unresolved',
        [string] $ExpectedShaOrigin = 'not resolved',
        [string] $ExpectedDigestValue = 'unresolved'
    )
    $pin = { param($k) if ($Pins.Contains($k)) { $Pins[$k] } else { 'unknown' } }
    $short = { param($v, $n) if ($v -match '^[0-9a-f]{40,64}$') { $v.Substring(0, $n) } else { $v } }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Install verification - $($startedAt.ToString('yyyy-MM-dd'))")
    $lines.Add('')
    $lines.Add("**Outcome**: $Outcome")
    foreach ($r in $Reasons) { $lines.Add("**Because**: $r") }
    foreach ($n in $Notes) { $lines.Add("**Note**: $n") }
    $lines.Add("**Recorded**: $($startedAt.ToString('u'))")
    $lines.Add("**Source**: ``$Source`` (installed from GitHub, as the README documents)")
    $lines.Add("**Expected revision**: ``$ExpectedSha`` ($ExpectedShaOrigin)")
    $lines.Add("**Expected content digest**: ``$ExpectedDigestValue`` (skills/ under the tree this run was started from; see tests/install/digest-skills.sh)")
    $lines.Add("**Machine**: clean container, $Platform, base image ``$(& $pin 'NODE_IMAGE')``, fresh non-root user")
    $lines.Add("**Hosts**: Claude Code $(& $pin 'CLAUDE_CODE_VERSION'), GitHub Copilot CLI $(& $pin 'COPILOT_CLI_VERSION'), skills CLI $(& $pin 'SKILLS_CLI_VERSION')")
    $lines.Add("**Limit**: 60 s per host (SC-001); both skills on disk in the install location AND named by the host's own inventory")
    $lines.Add("**Binding**: a blocking path passes only when its installed content digest equals the expected digest and any revision the host exposed equals the expected revision")
    $lines.Add('')
    $lines.Add('| Path | Blocking | Status | Reason | Install time | Skills on disk | Host inventory | Installed revision | Installed digest |')
    $lines.Add('| ---- | -------- | ------ | ------ | ------------ | -------------- | -------------- | ------------------ | ---------------- |')
    foreach ($r in $Results) {
        $seconds = [math]::Round([int]$r.elapsed_ms / 1000, 1)
        $lines.Add("| $($r.path) | $($r.blocking) | $($r.status) | $($r.reason) | ${seconds} s | $($r.skills) | $($r.inventory) | $(& $short $r.revision 7) | $(& $short $r.digest 12) |")
    }
    if ($Results.Count -eq 0) { $lines.Add('| (no RESULT lines were produced) | | | | | | | | |') }
    $lines.Add('')
    $lines.Add('## Log')
    $lines.Add('')
    $lines.Add('```text')
    foreach ($l in $Log) {
        # Already masked at capture. Terminal control sequences and spinner frames are noise in a record.
        $clean = $l -replace "`e\[[0-9;?]*[A-Za-z]", ''
        if ($clean -match '^[◒◐◓◑]\s') { continue }
        $lines.Add($clean.TrimEnd())
    }
    if ($Log.Count -eq 0) { $lines.Add('(no output captured)') }
    $lines.Add('```')
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    Set-Content -LiteralPath $Path -Value (($lines -join "`n") + "`n") -Encoding UTF8 -NoNewline
}

$platform = 'unknown'
$pins = [ordered]@{}
$log = @()
$results = @()
$runExit = -1
$verdict = $null
$failure = $null
$expected = [pscustomobject]@{ Sha = 'unresolved'; Origin = 'not resolved' }
$expectedDigest = 'unresolved'

try {
    $platform = Get-DockerPlatform
    $pins = Get-PinnedVersions
    $tokenSource = Resolve-Token
    $expected = Resolve-ExpectedRevision
    $expectedDigest = Get-SkillsTreeDigest -SkillsRoot $skillsRoot -Skill @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object { $_.Name })

    Write-Output "Install verification - $Source"
    Write-Output "docker: $platform | token: $tokenSource"
    Write-Output ("image: {0} | claude-code {1} | copilot {2} | skills {3}" -f $pins['NODE_IMAGE'], $pins['CLAUDE_CODE_VERSION'], $pins['COPILOT_CLI_VERSION'], $pins['SKILLS_CLI_VERSION'])
    Write-Output "expected: revision $($expected.Sha.Substring(0, 7)) ($($expected.Origin)) | content digest $($expectedDigest.Substring(0, 12)) (skills/ under $PackageRoot)"
    Write-Output ''

    $buildStart = Get-Date
    & docker build --pull --quiet --tag $ImageTag $contextDir 2>&1 | ForEach-Object { "build: $_" }
    if ($LASTEXITCODE -ne 0) { throw 'docker build failed; see output above.' }
    $buildSeconds = [int]((Get-Date) - $buildStart).TotalSeconds
    Write-Output "build: image ready in ${buildSeconds}s (build time is not part of the install measurement)"

    # Every line is masked the moment it is captured, so the token value cannot reach the console, the
    # RESULT parser or the record by any path. What follows only ever sees the masked log. The expected
    # revision goes in for the container's banner only; the judgement stays here.
    $log = @(& docker run --rm -e GH_TOKEN -e "PACKAGE_SOURCE=$Source" -e "EXPECTED_REVISION=$($expected.Sha)" $ImageTag 2>&1 |
        ForEach-Object { Protect-Secret -Text "$_" -Secret ([string]$env:GH_TOKEN) })
    $runExit = $LASTEXITCODE
    $log | ForEach-Object { Write-Output $_ }

    # Any line that begins with RESULT is a result line and must parse; a malformed one is an error,
    # not something to filter past.
    $results = @($log | Where-Object { $_ -match '^RESULT\b' } | ForEach-Object { ConvertFrom-InstallResult -Line $_ })
    $verdict = Test-InstallResultSet -Results $results -ExpectedPaths $script:ExpectedPaths -ContainerExitCode $runExit -ExpectedRevision $expected.Sha -ExpectedDigest $expectedDigest
}
catch {
    $failure = $_.Exception.Message
    Write-Output "install verification: ERROR - $failure"
}

$outcome = if ($failure) { 'FAIL (run did not complete)' } elseif ($verdict.Pass) { 'PASS' } else { 'FAIL' }
$reasons = @(if ($failure) { $failure } elseif ($verdict) { $verdict.Reasons } else { @() })
$notes = @(if ($verdict) { $verdict.Notes } else { @() })
Write-Output ''
Write-Output "install verification (aggregate): $outcome$(if ($reasons.Count) { ' - ' + ($reasons -join '; ') })"
foreach ($n in $notes) { Write-Output "install verification (note): $n" }

if (-not $NoRecord) {
    Write-Record -Path $OutputPath -Outcome $outcome -Reasons $reasons -Notes $notes -Results $results -Log $log -Platform $platform -Pins $pins `
        -ExpectedSha $expected.Sha -ExpectedShaOrigin $expected.Origin -ExpectedDigestValue $expectedDigest
    Write-Output "recorded: $OutputPath"
}

exit $(if ($outcome -eq 'PASS') { 0 } else { 1 })
