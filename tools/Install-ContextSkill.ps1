# Run from a regular PowerShell terminal outside the restricted agent session.
# Community source: muratcankoylan/Agent-Skills-for-Context-Engineering
# Installs only context-optimization, pinned to the reviewed repository revision.
# This guidance cannot guarantee savings or control host caching/model settings.
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$skillDestination = Join-Path $projectRoot '.agents\skills'
$skillName = 'context-optimization'
$skillDirectory = Join-Path $skillDestination $skillName
$manifestPath = Join-Path $skillDirectory 'SKILL.md'
$sourceRepository = 'muratcankoylan/Agent-Skills-for-Context-Engineering'
$sourceRevision = '6dbe1a1d868eab51a3bc9011b0f55e2891513e40'

if (Test-Path -LiteralPath $skillDirectory) {
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Existing directory has no SKILL.md; it will not be overwritten: $skillDirectory"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    if ($manifest -notmatch '(?m)^name:\s*context-optimization\s*$') {
        throw "Existing skill has an unexpected name; it will not be overwritten: $manifestPath"
    }
    Write-Output "Already present; left unchanged: $skillDirectory"
    return
}

# The generic installer extracts the entire repository ZIP, including unrelated
# research files whose paths exceed Windows limits. Fetch this pinned skill's
# three files and license directly instead; downloaded Python is never executed.
if (-not $PSCmdlet.ShouldProcess($skillDirectory, "Download only context-optimization and its license from $sourceRepository at $sourceRevision")) {
    return
}

$downloadRoot = "https://raw.githubusercontent.com/$sourceRepository/$sourceRevision"
$stagingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('ctx-' + [guid]::NewGuid().ToString('N'))
$downloads = @(
    @{ Source = 'skills/context-optimization/SKILL.md'; Target = 'SKILL.md' }
    @{ Source = 'skills/context-optimization/references/optimization_techniques.md'; Target = 'references/optimization_techniques.md' }
    @{ Source = 'skills/context-optimization/scripts/compaction.py'; Target = 'scripts/compaction.py' }
    @{ Source = 'LICENSE'; Target = 'LICENSE' }
)
try {
    foreach ($download in $downloads) {
        $targetPath = Join-Path $stagingDirectory $download.Target
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($targetPath)) | Out-Null
        Invoke-WebRequest -UseBasicParsing -Uri "$downloadRoot/$($download.Source)" -OutFile $targetPath -TimeoutSec 60
        if ((Get-Item -LiteralPath $targetPath).Length -eq 0) {
            throw "Downloaded file is empty: $($download.Target)"
        }
    }
    $manifest = Get-Content -LiteralPath (Join-Path $stagingDirectory 'SKILL.md') -Raw -Encoding UTF8
    if ($manifest -notmatch '(?m)^name:\s*context-optimization\s*$') {
        throw 'Downloaded skill has an unexpected name.'
    }
    [System.IO.Directory]::CreateDirectory($skillDestination) | Out-Null
    # Directory.Move refuses an existing destination, preserving existing skills.
    $resolvedSource = [System.IO.Path]::GetFullPath($stagingDirectory)
    $resolvedDestination = [System.IO.Path]::GetFullPath($skillDirectory)
    $destinationRoot = [System.IO.Path]::GetFullPath($skillDestination).TrimEnd('\') + '\'
    if (-not $resolvedDestination.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Skill destination is outside the intended skills directory.'
    }
    [System.IO.Directory]::Move($resolvedSource, $resolvedDestination)
} catch {
    throw "Skill installation failed: $($_.Exception.Message) Downloaded files remain at $stagingDirectory; existing skills were left unchanged."
}
Write-Output "Installed: $skillDirectory"
Write-Output 'The skill will be available on your next turn in this project.'
