#Requires -Version 7.0
<#
.SYNOPSIS
    Removes a secret from text before the text is shown or recorded.

.DESCRIPTION
    Test-Install.ps1 passes a GitHub token into the container so the hosts can clone a private
    repository, and everything the container prints becomes the recorded run under tests/results/,
    which enters public history. A record that is clean only because no tool happened to print the
    token is clean by luck. This function makes it clean by construction: every occurrence of the
    token's VALUE is replaced, wherever it appears and in whatever sentence, and so is anything shaped
    like a GitHub token or an x-access-token URL credential, in case a different secret reaches the
    log than the one this run was given.

    Test-Checks.ps1 proves it: a planted token must come out as ***.

.EXAMPLE
    . ./eng/Protect-Secret.ps1
    Protect-Secret -Text $line -Secret $env:GH_TOKEN
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Protect-Secret {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Text,
        [AllowEmptyString()][string] $Secret = ''
    )
    $out = $Text
    if (-not [string]::IsNullOrEmpty($Secret)) {
        $out = $out.Replace($Secret, '***')
    }
    # GitHub token shapes: classic (ghp_, gho_, ghu_, ghs_, ghr_) and fine-grained (github_pat_).
    $out = $out -replace 'gh[pousr]_[A-Za-z0-9]{16,}', '***'
    $out = $out -replace 'github_pat_[A-Za-z0-9_]{16,}', '***'
    # A credential embedded in a clone URL, whatever its shape.
    $out = $out -replace 'x-access-token:[^@\s]+@', 'x-access-token:***@'
    $out
}
