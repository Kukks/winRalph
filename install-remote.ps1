<#
.SYNOPSIS
    winRalph Remote Installer - One-liner installation for Windows
.DESCRIPTION
    Downloads and installs winRalph directly from GitHub without cloning.
    Run with: iwr -useb https://raw.githubusercontent.com/Kukks/winRalph/master/install-remote.ps1 | iex
#>

$ErrorActionPreference = "Stop"
$BaseUrl = "https://raw.githubusercontent.com/Kukks/winRalph/master"

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
    Write-Host "  Windows Edition - Remote Installer" -ForegroundColor Cyan
    Write-Host ""
}

Show-Banner
Write-Host "Installing winRalph..." -ForegroundColor Green
Write-Host ""

# Create directories
Write-Host "Creating directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $HooksDir | Out-Null
New-Item -ItemType Directory -Force -Path $CommandsDir | Out-Null

# Download and install hook files
Write-Host "Downloading hook files..." -ForegroundColor Cyan
$hookFiles = @("ralph-loop.ps1", "ralph.ps1", "ralph.cmd")
foreach ($file in $hookFiles) {
    $url = "$BaseUrl/hooks/$file"
    $dst = "$HooksDir\$file"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
        Write-Host "  Downloaded $file" -ForegroundColor Green
    } catch {
        Write-Host "  Failed to download $file" -ForegroundColor Red
        exit 1
    }
}

# Download command files
Write-Host "Downloading command files..." -ForegroundColor Cyan
$cmdFiles = @("ralph.md")
foreach ($file in $cmdFiles) {
    $url = "$BaseUrl/commands/$file"
    $dst = "$CommandsDir\$file"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
        Write-Host "  Downloaded $file" -ForegroundColor Green
    } catch {
        Write-Host "  Failed to download $file" -ForegroundColor Red
        exit 1
    }
}

# Configure hooks in settings.json
Write-Host "Configuring Claude Code hooks..." -ForegroundColor Cyan
$hookConfig = @{
    type = "command"
    command = 'powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\ralph-loop.ps1"'
    statusMessage = "Ralph loop checking..."
}

if (Test-Path $SettingsFile) {
    $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

# Ensure hooks structure exists
if (-not $settings.hooks) {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{}) -Force
}
if (-not $settings.hooks.Stop) {
    $settings.hooks | Add-Member -NotePropertyName "Stop" -NotePropertyValue @() -Force
}

# Check if hook already exists
$hookExists = $false
foreach ($stopHook in $settings.hooks.Stop) {
    if ($stopHook.hooks) {
        foreach ($h in $stopHook.hooks) {
            if ($h.command -match "ralph-loop") {
                $hookExists = $true
                break
            }
        }
    }
}

if (-not $hookExists) {
    $newStopHook = [PSCustomObject]@{
        hooks = @($hookConfig)
    }
    $settings.hooks.Stop = @($settings.hooks.Stop) + $newStopHook
    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    Write-Host "  Hook configured in settings.json" -ForegroundColor Green
} else {
    Write-Host "  Hook already configured" -ForegroundColor Yellow
}

# Add to PATH
Write-Host "Adding to PATH..." -ForegroundColor Cyan
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$HooksDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$HooksDir", "User")
    Write-Host "  Added to PATH" -ForegroundColor Green
} else {
    Write-Host "  Already in PATH" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart Claude Code to load hooks"
Write-Host "  2. Restart terminal to use 'ralph' command"
Write-Host "  3. Try: ralph start `"Your task here`""
Write-Host ""
Write-Host "Update:    ralph update" -ForegroundColor Gray
Write-Host "Uninstall: iwr -useb $BaseUrl/uninstall-remote.ps1 | iex" -ForegroundColor Gray
Write-Host ""
