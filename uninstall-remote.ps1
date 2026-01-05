<#
.SYNOPSIS
    winRalph Remote Uninstaller - One-liner uninstallation for Windows
.DESCRIPTION
    Removes winRalph from your Claude Code configuration.
    Run with: iwr -useb https://raw.githubusercontent.com/Kukks/winRalph/master/uninstall-remote.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# Paths
$ClaudeDir = "$env:USERPROFILE\.claude"
$HooksDir = "$ClaudeDir\hooks"
$CommandsDir = "$ClaudeDir\commands"
$SettingsFile = "$ClaudeDir\settings.json"

function Show-Banner {
    Write-Host ""
    Write-Host "  ____       _       _     " -ForegroundColor Yellow
    Write-Host " |  _ \ __ _| |_ __ | |__  " -ForegroundColor Yellow
    Write-Host " | |_) / _`` | | '_ \| '_ \ " -ForegroundColor Yellow
    Write-Host " |  _ < (_| | | |_) | | | |" -ForegroundColor Yellow
    Write-Host " |_| \_\__,_|_| .__/|_| |_|" -ForegroundColor Yellow
    Write-Host "              |_|          " -ForegroundColor Yellow
    Write-Host "  Windows Edition - Uninstaller" -ForegroundColor Cyan
    Write-Host ""
}

Show-Banner
Write-Host "Uninstalling winRalph..." -ForegroundColor Yellow
Write-Host ""

# Remove hook files
Write-Host "Removing hook files..." -ForegroundColor Cyan
$hookFiles = @("ralph-loop.ps1", "ralph.ps1", "ralph.cmd")
foreach ($file in $hookFiles) {
    $path = "$HooksDir\$file"
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "  Removed $file" -ForegroundColor Green
    }
}

# Remove command files
Write-Host "Removing command files..." -ForegroundColor Cyan
$cmdFiles = @("ralph.md")
foreach ($file in $cmdFiles) {
    $path = "$CommandsDir\$file"
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "  Removed $file" -ForegroundColor Green
    }
}

# Remove from settings.json
Write-Host "Removing hook configuration..." -ForegroundColor Cyan
if (Test-Path $SettingsFile) {
    $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
    if ($settings.hooks -and $settings.hooks.Stop) {
        $newStopHooks = @()
        foreach ($stopHook in $settings.hooks.Stop) {
            if ($stopHook.hooks) {
                $newHooks = @()
                foreach ($h in $stopHook.hooks) {
                    if ($h.command -notmatch "ralph-loop") {
                        $newHooks += $h
                    }
                }
                if ($newHooks.Count -gt 0) {
                    $stopHook.hooks = $newHooks
                    $newStopHooks += $stopHook
                }
            }
        }
        $settings.hooks.Stop = $newStopHooks
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
        Write-Host "  Hook removed from settings.json" -ForegroundColor Green
    }
}

# Remove from PATH
Write-Host "Removing from PATH..." -ForegroundColor Cyan
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -like "*$HooksDir*") {
    $newPath = ($currentPath -split ";" | Where-Object { $_ -ne $HooksDir }) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "  Removed from PATH" -ForegroundColor Green
}

# Clear session files
Write-Host "Clearing session files..." -ForegroundColor Cyan
$sessionDir = "$env:TEMP\ralph-sessions"
if (Test-Path $sessionDir) {
    Remove-Item $sessionDir -Recurse -Force
    Write-Host "  Cleared session data" -ForegroundColor Green
}

Write-Host ""
Write-Host "Uninstall complete!" -ForegroundColor Green
Write-Host "Restart Claude Code and terminal for changes to take effect." -ForegroundColor Yellow
Write-Host ""
