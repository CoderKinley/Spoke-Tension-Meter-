# Run from a regular PowerShell terminal outside the restricted agent session.
# Source: https://github.com/flutter/agent-plugins
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$skillDestination = Join-Path $projectRoot '.agents\skills'
$codexDirectory = if ($env:CODEX_HOME) {
    $env:CODEX_HOME
} else {
    Join-Path $env:USERPROFILE '.codex'
}
$installerPath = Join-Path $codexDirectory 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw "Codex Skill Installer was not found at: $installerPath"
}
$pythonCommand = Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1
$skillNames = @(
    'flutter-apply-architecture-best-practices'
    'flutter-add-widget-test'
    'flutter-add-integration-test'
    'flutter-fix-layout-issues'
)
$missingPaths = @()
foreach ($skillName in $skillNames) {
    $skillDirectory = Join-Path $skillDestination $skillName
    $manifestPath = Join-Path $skillDirectory 'SKILL.md'
    if (Test-Path -LiteralPath $skillDirectory) {
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw "Existing skill directory has no SKILL.md; it will not be overwritten: $skillDirectory"
        }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
        if ($manifest -notmatch ('(?m)^name:\s*' + [regex]::Escape($skillName) + '\s*$')) {
            throw "Existing skill has an unexpected name; it will not be overwritten: $manifestPath"
        }
        Write-Output "Already present: $skillName"
    } else {
        $missingPaths += "skills/$skillName"
    }
}

if ($missingPaths.Count -gt 0) {
    $action = "Download $($missingPaths.Count) Flutter skills from flutter/agent-plugins ($Ref)"
    if (-not $PSCmdlet.ShouldProcess($skillDestination, $action)) {
        return
    }
    $installerArguments = @(
        '-B', $installerPath,
        '--repo', 'flutter/agent-plugins',
        '--ref', $Ref,
        '--dest', $skillDestination,
        '--method', 'download',
        '--path'
    ) + $missingPaths
    & $pythonCommand.Source @installerArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Skill installation failed (exit code $LASTEXITCODE). Rerunning skips completed skills."
    }
}

foreach ($skillName in $skillNames) {
    $manifestPath = Join-Path (Join-Path $skillDestination $skillName) 'SKILL.md'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Installation verification failed: $manifestPath"
    }
}
Write-Output "All four Flutter skills are installed at $skillDestination"
Write-Output 'They will be available on your next turn in this project.'
