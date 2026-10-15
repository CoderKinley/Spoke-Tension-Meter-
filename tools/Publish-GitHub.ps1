# Run in a normal PowerShell terminal with network access.
# Uses Git's configured credential helper; credentials are never saved in source.
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*$')]
    [string]$Owner = 'kinleypenjor',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$RepositoryName = 'Spoke-Tension-Meter',
    [switch]$Resume,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $projectRoot
$gitDirectory = Join-Path $projectRoot '.git'
if (!(Test-Path -LiteralPath $gitDirectory)) {
    $gitDirectory = Join-Path $projectRoot '.tooling/publish.git'
}
if (!(Test-Path -LiteralPath $gitDirectory)) { throw 'The prepared Git repository was not found.' }
$gitArguments = @("--git-dir=$gitDirectory", "--work-tree=$projectRoot")
$localCommit = & git @gitArguments rev-parse --verify refs/heads/main
if ($LASTEXITCODE -ne 0) { throw 'No prepared main branch exists.' }
$changes = & git @gitArguments status --porcelain
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the prepared repository.' }
if ($changes) { throw 'Commit the current changes before publishing.' }
$destination = "$Owner/$RepositoryName"
Write-Host "Target: https://github.com/$destination (private); commit $localCommit"
if ($CheckOnly) { return }

$headers = @{ 'User-Agent' = 'Spoke-Lab-Publisher'; 'Accept' = 'application/vnd.github+json' }
$credentialOutput = $null
$accessToken = $null
try {
    # Check connectivity before requesting any sign-in from the credential helper.
    Invoke-RestMethod -Uri 'https://api.github.com/rate_limit' -Headers $headers -TimeoutSec 15 | Out-Null
    $credentialRequest = "protocol=https`nhost=github.com`nusername=$Owner`n`n"
    $credentialOutput = $credentialRequest | & git credential fill
    if ($LASTEXITCODE -ne 0) { throw "GitHub sign-in failed. Sign into Git Credential Manager as $Owner and retry." }
    foreach ($line in $credentialOutput) {
        if ($line.StartsWith('password=')) { $accessToken = $line.Substring(9) }
    }
    if ([string]::IsNullOrWhiteSpace($accessToken)) { throw 'The configured Git credential helper returned no GitHub credential.' }
    $headers.Authorization = "Bearer $accessToken"
    $account = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -TimeoutSec 30
    if ($account.login -ine $Owner) { throw "Authenticated as $($account.login); expected $Owner. No repository was created." }
    if ($Resume) {
        $repository = Invoke-RestMethod -Uri "https://api.github.com/repos/$destination" -Headers $headers -TimeoutSec 30
    } else {
        $body = @{
            name = $RepositoryName
            description = 'Flutter acoustic spoke frequency measurement and reference tuning beta'
            private = $true
            auto_init = $false
        } | ConvertTo-Json
        $repository = Invoke-RestMethod -Method Post -Uri 'https://api.github.com/user/repos' -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 30
    }
    if ($repository.full_name -ine $destination -or !$repository.private) {
        throw 'GitHub returned an unexpected repository or visibility. No code was pushed.'
    }
    $remote = "https://github.com/$destination.git"
    $existingRemote = & git @gitArguments remote
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git remotes.' }
    if ($existingRemote -contains 'origin') {
        & git @gitArguments remote set-url origin $remote
    } else {
        & git @gitArguments remote add origin $remote
    }
    if ($LASTEXITCODE -ne 0) { throw 'Cannot set the origin remote.' }
    & git @gitArguments -c "credential.https://github.com.username=$Owner" push -u origin 'main:main'
    if ($LASTEXITCODE -ne 0) {
        throw "Repository is available at $($repository.html_url), but the push failed. Retry this script with -Resume."
    }
    $remoteHead = & git @gitArguments ls-remote origin refs/heads/main
    if ($LASTEXITCODE -ne 0 -or !($remoteHead -match "^$localCommit\s")) {
        throw 'Push returned, but remote commit verification failed.'
    }
    Write-Host "Published and verified: $($repository.html_url)"
} finally {
    $headers.Clear()
    $credentialOutput = $null
    $accessToken = $null
}
