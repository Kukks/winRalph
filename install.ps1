<#
.SYNOPSIS
    winRalph Installer - Windows-native autonomous loop for Claude Code
.DESCRIPTION
    Installs winRalph hooks and commands to your Claude Code configuration.
.EXAMPLE
    .\install.ps1
    .\install.ps1 -SkipPath
    .\install.ps1 -Uninstall
#>

param(
    [switch]$SkipPath,      # Don't add to PATH
    [switch]$Uninstall,     # Remove winRalph
    [switch]$Force          # Overwrite existing files
)

$ErrorActionPreference = "Stop"

# Paths
$ClaudeDir = "$env:USERPROFILE\.claude"
$HooksDir = "$ClaudeDir\hooks"
$CommandsDir = "$ClaudeDir\commands"
$SettingsFile = "$ClaudeDir\settings.json"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Banner {
    Write-Host ""
    Write-Host "  ____       _       _     " -ForegroundColor Yellow
    Write-Host " |  _ \ __ _| |_ __ | |__  " -ForegroundColor Yellow
    Write-Host " | |_) / _`` | | '_ \| '_ \ " -ForegroundColor Yellow
    Write-Host " |  _ < (_| | | |_) | | | |" -ForegroundColor Yellow
    Write-Host " |_| \_\__,_|_| .__/|_| |_|" -ForegroundColor Yellow
    Write-Host "              |_|          " -ForegroundColor Yellow
    Write-Host "  Windows Edition - Installer" -ForegroundColor Cyan
    Write-Host ""
}

function Install-WinRalph {
    Show-Banner
    Write-Host "Installing winRalph..." -ForegroundColor Green
    Write-Host ""

    # Create directories
    Write-Host "Creating directories..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $HooksDir | Out-Null
    New-Item -ItemType Directory -Force -Path $CommandsDir | Out-Null

    # Copy hook files
    Write-Host "Copying hook files..." -ForegroundColor Cyan
    $hookFiles = @("ralph-loop.ps1", "ralph.ps1", "ralph.cmd")
    foreach ($file in $hookFiles) {
        $src = Join-Path $ScriptDir "hooks\$file"
        $dst = Join-Path $HooksDir $file
        if (Test-Path $src) {
            if ((Test-Path $dst) -and -not $Force) {
                Write-Host "  $file already exists (use -Force to overwrite)" -ForegroundColor Yellow
            } else {
                Copy-Item $src $dst -Force
                Write-Host "  Copied $file" -ForegroundColor Green
            }
        } else {
            Write-Host "  Warning: $file not found in source" -ForegroundColor Yellow
        }
    }

    # Copy command files
    Write-Host "Copying command files..." -ForegroundColor Cyan
    $cmdFiles = @("ralph.md")
    foreach ($file in $cmdFiles) {
        $src = Join-Path $ScriptDir "commands\$file"
        $dst = Join-Path $CommandsDir $file
        if (Test-Path $src) {
            if ((Test-Path $dst) -and -not $Force) {
                Write-Host "  $file already exists (use -Force to overwrite)" -ForegroundColor Yellow
            } else {
                Copy-Item $src $dst -Force
                Write-Host "  Copied $file" -ForegroundColor Green
            }
        } else {
            Write-Host "  Warning: $file not found in source" -ForegroundColor Yellow
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
        $settings = @{}
    }

    # Ensure hooks structure exists
    if (-not $settings.hooks) {
        $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{} -Force
    }
    if (-not $settings.hooks.Stop) {
        $settings.hooks | Add-Member -NotePropertyName "Stop" -NotePropertyValue @() -Force
    }

    # Check if hook already exists
    $hookExists = $false
    foreach ($stopHook in $settings.hooks.Stop) {
        foreach ($h in $stopHook.hooks) {
            if ($h.command -match "ralph-loop") {
                $hookExists = $true
                break
            }
        }
    }

    if (-not $hookExists) {
        $newStopHook = @{
            hooks = @($hookConfig)
        }
        $settings.hooks.Stop += $newStopHook
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
        Write-Host "  Hook configured in settings.json" -ForegroundColor Green
    } else {
        Write-Host "  Hook already configured" -ForegroundColor Yellow
    }

    # Add to PATH
    if (-not $SkipPath) {
        Write-Host "Adding to PATH..." -ForegroundColor Cyan
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$HooksDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$HooksDir", "User")
            Write-Host "  Added $HooksDir to PATH" -ForegroundColor Green
            Write-Host "  (Restart terminal to use 'ralph' command)" -ForegroundColor Yellow
        } else {
            Write-Host "  Already in PATH" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Restart Claude Code to load hooks"
    Write-Host "  2. Restart terminal to use 'ralph' command"
    Write-Host "  3. Try: ralph start `"Your task here`""
    Write-Host ""
}

function Uninstall-WinRalph {
    Show-Banner
    Write-Host "Uninstalling winRalph..." -ForegroundColor Yellow
    Write-Host ""

    # Remove hook files
    Write-Host "Removing hook files..." -ForegroundColor Cyan
    $hookFiles = @("ralph-loop.ps1", "ralph.ps1", "ralph.cmd")
    foreach ($file in $hookFiles) {
        $path = Join-Path $HooksDir $file
        if (Test-Path $path) {
            Remove-Item $path -Force
            Write-Host "  Removed $file" -ForegroundColor Green
        }
    }

    # Remove command files
    Write-Host "Removing command files..." -ForegroundColor Cyan
    $cmdFiles = @("ralph.md")
    foreach ($file in $cmdFiles) {
        $path = Join-Path $CommandsDir $file
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
}

# Main
if ($Uninstall) {
    Uninstall-WinRalph
} else {
    Install-WinRalph
}
