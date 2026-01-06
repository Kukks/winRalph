<#
.SYNOPSIS
    Ralph Loop for Windows - Autonomous Claude Code loop using hooks
.DESCRIPTION
    PowerShell implementation of the Ralph Wiggum technique for Claude Code.
    Intercepts Claude's exit and re-feeds the prompt until completion.
    Supports concurrent sessions using working directory as session key.
.NOTES
    Place in ~/.claude/hooks/ralph-loop.ps1
    Configure in ~/.claude/settings.json under "hooks"
#>

param(
    [Parameter(ValueFromPipeline=$true)]
    [string]$InputJson
)

# Get session ID from environment or generate from current directory
function Get-SessionId {
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

# Configuration - customize these via environment
$MaxIterations = if ($env:RALPH_MAX_ITERATIONS) { [int]$env:RALPH_MAX_ITERATIONS } else { 20 }
$CompletionPhrases = if ($env:RALPH_COMPLETION_PHRASES) { $env:RALPH_COMPLETION_PHRASES } else { "TASK_COMPLETE,ALL_DONE,MISSION_ACCOMPLISHED" }

# Parse input from Claude Code hook
$hookData = $null
if ($InputJson) {
    try {
        $hookData = $InputJson | ConvertFrom-Json -ErrorAction SilentlyContinue
    } catch {}
}

# Initialize or load state
function Get-RalphState {
    if (Test-Path $StateFile) {
        try {
            return Get-Content $StateFile -Raw | ConvertFrom-Json
        } catch {
            return @{ iterations = 0; active = $false; prompt = ""; startTime = $null; cwd = "" }
        }
    }
    return @{ iterations = 0; active = $false; prompt = ""; startTime = $null; cwd = "" }
}

function Save-RalphState($state) {
    $state | ConvertTo-Json | Set-Content $StateFile -Force
}

function Write-RalphLog($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] [$SessionId] $message" | Add-Content $LogFile
}

function Test-CompletionPhrase($transcript) {
    $phrases = $CompletionPhrases -split ","
    foreach ($phrase in $phrases) {
        if ($transcript -match [regex]::Escape($phrase.Trim())) {
            return $true
        }
    }
    return $false
}

# Main logic
$state = Get-RalphState

# Auto-start smart mode if enabled (via env var OR state file) and no active session
if (-not $state.active -and ($env:RALPH_SMART_MODE -eq "true" -or $state.smartMode)) {
    $state = @{
        active = $true
        iterations = 0
        maxIterations = $MaxIterations
        prompt = "AUTO_SMART_MODE"
        startTime = (Get-Date).ToString("o")
        completionPhrases = $CompletionPhrases
        cwd = (Get-Location).Path
        sessionId = $SessionId
        smartMode = $true
    }
    Save-RalphState $state
    Write-RalphLog "Auto-started smart mode session"
}

# Check if ralph loop is active for this session
if (-not $state.active) {
    # Not in ralph mode, allow normal exit
    exit 0
}

# Get the transcript/last message from hook data
$transcript = ""
if ($hookData) {
    if ($hookData.transcript) {
        $transcript = $hookData.transcript | Out-String
    } elseif ($hookData.stopHookInput) {
        $transcript = $hookData.stopHookInput | Out-String
    } elseif ($hookData.lastAssistantMessage) {
        $transcript = $hookData.lastAssistantMessage | Out-String
    }
    # Also check the full hook data as string
    $transcript += ($hookData | Out-String)
}

# Check for completion phrases
if (Test-CompletionPhrase $transcript) {
    Write-RalphLog "Completion phrase detected. Stopping loop after $($state.iterations) iterations."
    $state.active = $false
    Save-RalphState $state

    Write-Output "Ralph loop completed successfully after $($state.iterations) iterations."
    exit 0
}

# Check iteration limit
if ($state.iterations -ge $MaxIterations) {
    Write-RalphLog "Max iterations ($MaxIterations) reached. Stopping loop."
    $state.active = $false
    Save-RalphState $state

    Write-Output "Ralph loop stopped: max iterations ($MaxIterations) reached."
    exit 0
}

# Increment iteration and continue
$state.iterations++
Save-RalphState $state
Write-RalphLog "Iteration $($state.iterations) of $MaxIterations - continuing loop"

# Output the decision to block exit and re-inject prompt
# Exit code 2 tells Claude Code to continue with the original prompt
$feedbackMessage = "Continue working. Iteration $($state.iterations) of $MaxIterations. Say 'TASK_COMPLETE' when finished."

# Add thorough analysis instructions for smart mode
if ($state.smartMode -or $env:RALPH_SMART_MODE -eq "true") {
    $feedbackMessage = @"
Continue working. Iteration $($state.iterations) of $MaxIterations.

Approach thoroughly:
- Analyze second and third-order consequences of changes
- Consider edge cases, failure modes, and cascading effects
- Trace impacts through all dependent code and systems
- Document reasoning for significant decisions

Say 'TASK_COMPLETE' when finished.
"@
}

$output = @{
    decision = "block"
    reason = "Ralph loop iteration $($state.iterations)/$MaxIterations - task not complete"
    feedbackToModel = $feedbackMessage
}

$output | ConvertTo-Json -Compress
exit 2
