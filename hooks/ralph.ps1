<#
.SYNOPSIS
    Ralph - Windows CLI for controlling the Ralph autonomous loop
.DESCRIPTION
    Start, stop, and monitor Ralph loop for Claude Code on Windows.
    Supports concurrent sessions - each directory gets its own loop.
.EXAMPLE
    ralph start "Build a todo app with React"
    ralph start "Fix all TypeScript errors" -MaxIterations 10
    ralph status
    ralph stop
    ralph log
    ralph list    # Show all active sessions
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "status", "log", "clear", "list", "update", "uninstall", "version", "help")]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$Prompt,

    [Parameter()]
    [int]$MaxIterations = 20,

    [Parameter()]
    [string]$CompletionPhrases = "TASK_COMPLETE,ALL_DONE,MISSION_ACCOMPLISHED",

    [Parameter()]
    [string]$Session  # Optional explicit session name
)

$Version = "1.0.0"

# Session management
function Get-SessionId {
    if ($Session) {
        return $Session
    }
    if ($env:RALPH_SESSION_ID) {
        return $env:RALPH_SESSION_ID
    }
    # Use current directory hash as default session ID
    $cwd = (Get-Location).Path
    $hash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.MD5]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($cwd)
        )
    ).Replace("-", "").Substring(0, 8).ToLower()
    return $hash
}

$SessionId = Get-SessionId
$StateDir = "$env:TEMP\ralph-sessions"
$StateFile = "$StateDir\ralph-state-$SessionId.json"
$LogFile = "$StateDir\ralph-log-$SessionId.txt"

# Ensure state directory exists
if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
}

function Get-RalphState {
    if (Test-Path $StateFile) {
        try {
            return Get-Content $StateFile -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Get-AllSessions {
    $sessions = @()
    if (Test-Path $StateDir) {
        Get-ChildItem "$StateDir\ralph-state-*.json" | ForEach-Object {
            $sid = $_.Name -replace "ralph-state-", "" -replace ".json", ""
            try {
                $state = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $sessions += [PSCustomObject]@{
                    SessionId = $sid
                    Active = $state.active
                    Iterations = $state.iterations
                    MaxIterations = $state.maxIterations
                    Prompt = if ($state.prompt.Length -gt 40) { $state.prompt.Substring(0, 40) + "..." } else { $state.prompt }
                    Directory = $state.cwd
                    StartTime = $state.startTime
                }
            } catch {}
        }
    }
    return $sessions
}

function Show-Banner {
    Write-Host ""
    Write-Host "  ____       _       _     " -ForegroundColor Yellow
    Write-Host " |  _ \ __ _| |_ __ | |__  " -ForegroundColor Yellow
    Write-Host " | |_) / _`` | | '_ \| '_ \ " -ForegroundColor Yellow
    Write-Host " |  _ < (_| | | |_) | | | |" -ForegroundColor Yellow
    Write-Host " |_| \_\__,_|_| .__/|_| |_|" -ForegroundColor Yellow
    Write-Host "              |_|          " -ForegroundColor Yellow
    Write-Host "  Windows Edition (Concurrent)" -ForegroundColor Cyan
    Write-Host ""
}

switch ($Command) {
    "start" {
        if (-not $Prompt) {
            Write-Host "Error: Prompt required. Usage: ralph start `"Your task here`"" -ForegroundColor Red
            exit 1
        }

        Show-Banner

        $cwd = (Get-Location).Path
        $state = @{
            active = $true
            iterations = 0
            maxIterations = $MaxIterations
            prompt = $Prompt
            startTime = (Get-Date).ToString("o")
            completionPhrases = $CompletionPhrases
            cwd = $cwd
            sessionId = $SessionId
        }

        $state | ConvertTo-Json | Set-Content $StateFile -Force

        # Clear previous log
        if (Test-Path $LogFile) { Clear-Content $LogFile }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] [$SessionId] Ralph loop started" | Add-Content $LogFile
        "[$timestamp] [$SessionId] Directory: $cwd" | Add-Content $LogFile
        "[$timestamp] [$SessionId] Prompt: $Prompt" | Add-Content $LogFile
        "[$timestamp] [$SessionId] Max iterations: $MaxIterations" | Add-Content $LogFile

        Write-Host "Ralph loop STARTED" -ForegroundColor Green
        Write-Host ""
        Write-Host "Session:" -ForegroundColor Cyan
        Write-Host "  ID: $SessionId"
        Write-Host "  Directory: $cwd"
        Write-Host ""
        Write-Host "Configuration:" -ForegroundColor Cyan
        Write-Host "  Max iterations: $MaxIterations"
        Write-Host "  Completion phrases: $CompletionPhrases"
        Write-Host ""
        Write-Host "Prompt:" -ForegroundColor Cyan
        Write-Host "  $Prompt"
        Write-Host ""
        Write-Host "Now run Claude Code with your prompt:" -ForegroundColor Yellow
        Write-Host "  claude `"$Prompt`"" -ForegroundColor White
        Write-Host ""
        Write-Host "Claude will say 'TASK_COMPLETE' when done, or stop after $MaxIterations iterations."
        Write-Host "Use 'ralph status' to check progress, 'ralph stop' to abort."
        Write-Host ""
        Write-Host "Other sessions won't interfere - each directory has its own loop." -ForegroundColor Gray
    }

    "stop" {
        $state = Get-RalphState
        if ($state -and $state.active) {
            $state.active = $false
            $state | ConvertTo-Json | Set-Content $StateFile -Force

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            "[$timestamp] [$SessionId] Ralph loop manually stopped after $($state.iterations) iterations" | Add-Content $LogFile

            Write-Host "Ralph loop STOPPED" -ForegroundColor Yellow
            Write-Host "Session: $SessionId"
            Write-Host "Completed $($state.iterations) iterations"
        } else {
            Write-Host "No active ralph loop in this directory" -ForegroundColor Gray
            Write-Host "Session ID: $SessionId"
            Write-Host ""
            Write-Host "Use 'ralph list' to see all sessions"
        }
    }

    "status" {
        Show-Banner

        $state = Get-RalphState
        Write-Host "Session: $SessionId" -ForegroundColor Cyan
        Write-Host "Directory: $(Get-Location)"
        Write-Host ""

        if ($state) {
            if ($state.active) {
                Write-Host "Status: ACTIVE" -ForegroundColor Green
            } else {
                Write-Host "Status: INACTIVE" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Iterations: $($state.iterations) / $($state.maxIterations)"

            if ($state.startTime) {
                try {
                    $start = [DateTime]::Parse($state.startTime)
                    $duration = (Get-Date) - $start
                    Write-Host "Duration: $($duration.ToString('hh\:mm\:ss'))"
                } catch {}
            }

            if ($state.prompt) {
                Write-Host ""
                Write-Host "Prompt:" -ForegroundColor Cyan
                Write-Host "  $($state.prompt)"
            }
        } else {
            Write-Host "Status: NOT INITIALIZED" -ForegroundColor Gray
            Write-Host "Run 'ralph start `"Your task`"' to begin"
        }
    }

    "list" {
        Show-Banner

        $sessions = Get-AllSessions
        if ($sessions.Count -eq 0) {
            Write-Host "No ralph sessions found" -ForegroundColor Gray
        } else {
            Write-Host "All Ralph Sessions:" -ForegroundColor Cyan
            Write-Host ""

            $sessions | ForEach-Object {
                $statusColor = if ($_.Active) { "Green" } else { "Gray" }
                $statusText = if ($_.Active) { "ACTIVE" } else { "inactive" }
                $marker = if ($_.SessionId -eq $SessionId) { " <-- current" } else { "" }

                Write-Host "[$($_.SessionId)]$marker" -ForegroundColor Yellow
                Write-Host "  Status: " -NoNewline; Write-Host $statusText -ForegroundColor $statusColor
                Write-Host "  Iterations: $($_.Iterations)/$($_.MaxIterations)"
                Write-Host "  Prompt: $($_.Prompt)"
                if ($_.Directory) {
                    Write-Host "  Directory: $($_.Directory)" -ForegroundColor Gray
                }
                Write-Host ""
            }
        }
    }

    "log" {
        if (Test-Path $LogFile) {
            Write-Host "=== Ralph Log [$SessionId] ===" -ForegroundColor Cyan
            Get-Content $LogFile | ForEach-Object {
                if ($_ -match "error|failed|stopped") {
                    Write-Host $_ -ForegroundColor Red
                } elseif ($_ -match "complete|success") {
                    Write-Host $_ -ForegroundColor Green
                } else {
                    Write-Host $_
                }
            }
        } else {
            Write-Host "No log file found for session $SessionId" -ForegroundColor Gray
        }
    }

    "clear" {
        if (Test-Path $StateFile) { Remove-Item $StateFile -Force }
        if (Test-Path $LogFile) { Remove-Item $LogFile -Force }
        Write-Host "Ralph state and logs cleared for session $SessionId" -ForegroundColor Green
    }

    "update" {
        Show-Banner

        $BaseUrl = "https://raw.githubusercontent.com/Kukks/winRalph/master"
        $HooksDir = "$env:USERPROFILE\.claude\hooks"
        $CommandsDir = "$env:USERPROFILE\.claude\commands"

        # Fetch manifest for version and file list
        Write-Host "Checking for updates..." -ForegroundColor Cyan
        try {
            $manifestData = Invoke-WebRequest -Uri "$BaseUrl/manifest.json" -UseBasicParsing
            $manifest = $manifestData.Content | ConvertFrom-Json
            $latestVersion = $manifest.version
        } catch {
            Write-Host "  Failed to fetch manifest, falling back to version check" -ForegroundColor Yellow
            try {
                $latestScript = Invoke-WebRequest -Uri "$BaseUrl/hooks/ralph.ps1" -UseBasicParsing
                if ($latestScript.Content -match '\$Version\s*=\s*"([^"]+)"') {
                    $latestVersion = $matches[1]
                } else {
                    $latestVersion = "unknown"
                }
            } catch {
                $latestVersion = "unknown"
            }
            $manifest = $null
        }

        Write-Host "  Current version: $Version" -ForegroundColor White
        Write-Host "  Latest version:  $latestVersion" -ForegroundColor White
        Write-Host ""

        if ($Version -eq $latestVersion) {
            Write-Host "Already up to date!" -ForegroundColor Green
            return
        }

        Write-Host "Updating winRalph..." -ForegroundColor Cyan
        Write-Host ""

        # Get file lists from manifest or use defaults
        if ($manifest -and $manifest.files) {
            $hookFiles = $manifest.files.hooks
            $cmdFiles = $manifest.files.commands
        } else {
            $hookFiles = @("ralph-loop.ps1", "ralph.ps1", "ralph.cmd")
            $cmdFiles = @("ralph.md")
        }

        # Update hook files
        Write-Host "Downloading hook files..." -ForegroundColor Cyan
        foreach ($file in $hookFiles) {
            $url = "$BaseUrl/hooks/$file"
            $dst = "$HooksDir\$file"
            try {
                Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
                Write-Host "  Updated $file" -ForegroundColor Green
            } catch {
                Write-Host "  Failed to update $file" -ForegroundColor Red
            }
        }

        # Update command files
        Write-Host "Downloading command files..." -ForegroundColor Cyan
        foreach ($file in $cmdFiles) {
            $url = "$BaseUrl/commands/$file"
            $dst = "$CommandsDir\$file"
            try {
                Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
                Write-Host "  Updated $file" -ForegroundColor Green
            } catch {
                Write-Host "  Failed to update $file" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "Update complete! Now running v$latestVersion" -ForegroundColor Green
        Write-Host "Restart Claude Code to use the new version." -ForegroundColor Yellow
    }

    "uninstall" {
        Show-Banner
        Write-Host "Uninstalling winRalph..." -ForegroundColor Yellow
        Write-Host ""

        $HooksDir = "$env:USERPROFILE\.claude\hooks"
        $CommandsDir = "$env:USERPROFILE\.claude\commands"
        $SettingsFile = "$env:USERPROFILE\.claude\settings.json"

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
        if (Test-Path $StateDir) {
            Remove-Item $StateDir -Recurse -Force
            Write-Host "  Cleared session data" -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "Uninstall complete!" -ForegroundColor Green
        Write-Host "Restart Claude Code and terminal for changes to take effect." -ForegroundColor Yellow
    }

    "version" {
        Write-Host "winRalph v$Version" -ForegroundColor Cyan
    }

    "help" {
        Show-Banner

        Write-Host "Usage:" -ForegroundColor Cyan
        Write-Host "  ralph start `"Your task here`"     Start a new ralph loop"
        Write-Host "  ralph start `"Task`" -MaxIterations 10"
        Write-Host "  ralph start `"Task`" -Session myproject"
        Write-Host "  ralph stop                        Stop the current loop"
        Write-Host "  ralph status                      Check loop status"
        Write-Host "  ralph list                        List all sessions"
        Write-Host "  ralph log                         View the log"
        Write-Host "  ralph clear                       Clear state and logs"
        Write-Host "  ralph update                      Update to latest version"
        Write-Host "  ralph uninstall                   Remove winRalph completely"
        Write-Host "  ralph version                     Show current version"
        Write-Host ""
        Write-Host "Concurrent Sessions:" -ForegroundColor Cyan
        Write-Host "  By default, each directory gets its own session."
        Write-Host "  Run ralph from different directories for parallel loops."
        Write-Host "  Or use -Session to name sessions explicitly."
        Write-Host ""
        Write-Host "Environment Variables:" -ForegroundColor Cyan
        Write-Host "  RALPH_SESSION_ID           Override session ID"
        Write-Host "  RALPH_MAX_ITERATIONS       Default max iterations (20)"
        Write-Host "  RALPH_COMPLETION_PHRASES   Comma-separated completion phrases"
        Write-Host ""
        Write-Host "How it works:" -ForegroundColor Cyan
        Write-Host "  1. Run 'ralph start `"Your task`"'"
        Write-Host "  2. Run 'claude `"Your task`"'"
        Write-Host "  3. Claude will loop until it says 'TASK_COMPLETE'"
        Write-Host "     or reaches max iterations"
        Write-Host ""
        Write-Host "Completion Phrases (say any to stop):" -ForegroundColor Yellow
        Write-Host "  TASK_COMPLETE, ALL_DONE, MISSION_ACCOMPLISHED"
    }
}
