<#
    Copies this repo's Claude config into the current machine's ~/.claude.

    Idempotent and non-destructive: an existing file is backed up to <name>.bak-<timestamp>
    before it is replaced, and settings.json is merged key by key, never overwritten.

    Usage:  pwsh -File scripts/install.ps1 [-Activate]
#>
[CmdletBinding()]
param(
    # Also activate the output style and install the self-update SessionStart hook.
    [switch]$Activate
)

$ErrorActionPreference = 'Stop'

$repoRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoHome  = Join-Path $repoRoot 'home'
$claudeDir = Join-Path $HOME '.claude'
$stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'

function Copy-Tracked {
    param([string]$Source, [string]$Destination)

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    if (Test-Path $Destination) {
        if ((Get-FileHash $Source).Hash -eq (Get-FileHash $Destination).Hash) {
            Write-Host "  unchanged  $Destination"
            return
        }
        Copy-Item $Destination "$Destination.bak-$stamp"
        Write-Host "  backed up  $Destination.bak-$stamp"
    }

    Copy-Item $Source $Destination -Force
    Write-Host "  installed  $Destination"
}

Write-Host "Installing Claude config into $claudeDir"

Copy-Tracked -Source (Join-Path $repoHome 'CLAUDE.md') `
             -Destination (Join-Path $claudeDir 'CLAUDE.md')

Get-ChildItem (Join-Path $repoHome 'output-styles') -Filter *.md | ForEach-Object {
    Copy-Tracked -Source $_.FullName `
                 -Destination (Join-Path $claudeDir "output-styles\$($_.Name)")
}

if (-not $Activate) {
    Write-Host ""
    Write-Host "Files are installed but nothing is switched on. Re-run with -Activate to set"
    Write-Host "the output style and install the self-update hook, or do it yourself:"
    Write-Host "  /output-style  ->  pick direct-no-bs"
    Write-Host ""
    Write-Host "Done."
    return
}

$settingsPath = Join-Path $claudeDir 'settings.json'

# Merge key by key: settings.json holds machine-specific values (marketplace paths,
# enabled plugins, effort level) that must survive.
if (Test-Path $settingsPath) {
    Copy-Item $settingsPath "$settingsPath.bak-$stamp"
    Write-Host "  backed up  $settingsPath.bak-$stamp"
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
}
else {
    $settings = [pscustomobject]@{}
}

$settings | Add-Member -NotePropertyName 'outputStyle' -NotePropertyValue 'direct-no-bs' -Force
Write-Host "  set        outputStyle = direct-no-bs"

# The self-update hook. $HOME is left unexpanded on purpose: the same string has to
# resolve on every machine, which is why the clone must live at ~/claude-config.
$hookCommand = 'bash "$HOME/claude-config/scripts/self-update.sh"'

if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not $settings.hooks.PSObject.Properties['SessionStart']) {
    $settings.hooks | Add-Member -NotePropertyName 'SessionStart' -NotePropertyValue @() -Force
}

# Don't add a second copy if it is already there.
$existing = @($settings.hooks.SessionStart) | Where-Object {
    $_.hooks | Where-Object { $_.command -eq $hookCommand }
}

if ($existing) {
    Write-Host "  unchanged  self-update hook (already present)"
}
else {
    $entry = [pscustomobject]@{
        hooks = @(
            [pscustomobject]@{
                type    = 'command'
                command = $hookCommand
                async   = $true
                timeout = 30
            }
        )
    }
    $settings.hooks.SessionStart = @($settings.hooks.SessionStart) + $entry
    Write-Host "  installed  self-update hook (SessionStart)"
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $settingsPath -Encoding utf8

Write-Host ""
Write-Host "Done. Restart Claude Code to pick up the output style and the hook."
