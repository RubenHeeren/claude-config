<#
    Copies this repo's Claude config into the current machine's ~/.claude.

    Idempotent and non-destructive: an existing file is backed up to <name>.bak-<timestamp>
    before it is replaced, and settings.json is never overwritten wholesale.

    Usage:  pwsh -File scripts/install.ps1 [-SetOutputStyle]
#>
[CmdletBinding()]
param(
    # Also write "outputStyle": "Ruben" into ~/.claude/settings.json.
    [switch]$SetOutputStyle
)

$ErrorActionPreference = 'Stop'

$repoHome  = Join-Path $PSScriptRoot '..\home' | Resolve-Path
$claudeDir = Join-Path $HOME '.claude'
$stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'

function Copy-Tracked {
    param([string]$Source, [string]$Destination)

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    if (Test-Path $Destination) {
        # Same content already in place, nothing to do.
        if ((Get-FileHash $Source).Hash -eq (Get-FileHash $Destination).Hash) {
            Write-Host "  unchanged  $Destination"
            return
        }
        $backup = "$Destination.bak-$stamp"
        Copy-Item $Destination $backup
        Write-Host "  backed up  $backup"
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

if ($SetOutputStyle) {
    $settingsPath = Join-Path $claudeDir 'settings.json'

    # Merge the one key rather than replacing the file: settings.json holds machine-specific
    # values (marketplace paths, enabled plugins) that must survive.
    if (Test-Path $settingsPath) {
        Copy-Item $settingsPath "$settingsPath.bak-$stamp"
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    }
    else {
        $settings = [pscustomobject]@{}
    }

    $settings | Add-Member -NotePropertyName 'outputStyle' -NotePropertyValue 'Ruben' -Force
    $settings | ConvertTo-Json -Depth 20 | Set-Content $settingsPath -Encoding utf8
    Write-Host "  set        outputStyle = Ruben"
}
else {
    Write-Host ""
    Write-Host "Output style is installed but not active. Run /output-style and pick Ruben,"
    Write-Host "or re-run this script with -SetOutputStyle."
}

Write-Host ""
Write-Host "Done."
