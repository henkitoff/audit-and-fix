param(
    [ValidateSet("auto", "both", "claude", "codex")]
    [string]$Target = "auto"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptDir
$SkillName = Split-Path -Leaf $SkillRoot

function Install-Skill {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostRoot
    )

    $skillsDir = Join-Path $HostRoot "skills"
    $skillDir = Join-Path $skillsDir $SkillName

    New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null

    if (Test-Path $skillDir) {
        Remove-Item -LiteralPath $skillDir -Recurse -Force
    }

    Copy-Item -LiteralPath $SkillRoot -Destination $skillDir -Recurse -Force

    $gitDir = Join-Path $skillDir ".git"
    if (Test-Path $gitDir) {
        Remove-Item -LiteralPath $gitDir -Recurse -Force
    }

    Write-Host "Installed to $skillDir"
}

$codexHostRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$claudeHostRoot = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }

switch ($Target) {
    "auto" {
        Install-Skill -HostRoot $claudeHostRoot
        Install-Skill -HostRoot $codexHostRoot
    }
    "both" {
        Install-Skill -HostRoot $claudeHostRoot
        Install-Skill -HostRoot $codexHostRoot
    }
    "claude" {
        Install-Skill -HostRoot $claudeHostRoot
    }
    "codex" {
        Install-Skill -HostRoot $codexHostRoot
    }
}
