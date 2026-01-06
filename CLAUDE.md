# winRalph - Development Guide

## Project Overview

Windows-native autonomous loop for Claude Code. Allows Claude to run continuously until a task is complete, using PowerShell hooks.

## Architecture

```
~/.claude/
├── hooks/
│   ├── ralph-loop.ps1    # Stop hook - intercepts Claude exit, checks completion
│   ├── ralph.ps1         # Main CLI - all commands (start, stop, update, etc.)
│   └── ralph.cmd         # PATH wrapper for Windows
├── commands/
│   └── ralph.md          # Slash command for /ralph in Claude Code
└── settings.json         # Hook configuration
```

Session state stored in: `$env:TEMP\ralph-sessions\`

## Key Files

### manifest.json
Central source of truth for:
- **version**: Current version string (e.g., "1.0.0")
- **files.hooks**: Array of hook files to install/update
- **files.commands**: Array of command files to install/update

### hooks/ralph.ps1
Main CLI with commands:
- `start` - Start autonomous loop with prompt
- `stop` - Stop current loop
- `status` - Check loop status
- `list` - List all sessions
- `log` - View session log
- `clear` - Clear session state
- `update` - Self-update from GitHub (uses manifest)
- `uninstall` - Remove winRalph completely
- `version` - Show current version

**Important**: Has `$Version` variable that MUST match manifest.json version.

### hooks/ralph-loop.ps1
Stop hook that:
1. Checks if ralph loop is active for current directory
2. Looks for completion phrases in Claude's output
3. Returns exit code 2 to block exit and continue loop
4. Returns exit code 0 to allow normal exit

### commands/ralph.md
Slash command that:
- Parses `/ralph <command>` arguments
- For `/ralph start` without prompt: generates thorough analysis prompt from context
- Includes deep analysis instructions (second-order consequences, edge cases, etc.)

## Versioning

When releasing updates:

1. **Update version in TWO places**:
   - `manifest.json` → `version` field
   - `hooks/ralph.ps1` → `$Version` variable

2. **If adding new files**:
   - Add file to appropriate directory
   - Add filename to `manifest.json` under `files.hooks` or `files.commands`

3. **Version format**: Semantic versioning (MAJOR.MINOR.PATCH)

## Update Flow

When user runs `ralph update`:
1. Fetches `manifest.json` from GitHub
2. Compares versions
3. If newer, downloads all files listed in manifest
4. Falls back to hardcoded file list if manifest unavailable

## Smart Start Analysis

When `/ralph start` is called without a prompt, it auto-generates one with:
- Task description from conversation context
- Second and third-order consequence analysis
- Edge case and failure mode consideration
- Impact tracing through dependent systems
- Reasoning documentation requirements

## Session Management

- Sessions identified by MD5 hash of current directory path
- Each directory gets independent loop state
- Explicit session names supported via `-Session` parameter
- State persists in JSON files in temp directory

## Completion Phrases

Default phrases that stop the loop:
- `TASK_COMPLETE`
- `ALL_DONE`
- `MISSION_ACCOMPLISHED`

Configurable via `$env:RALPH_COMPLETION_PHRASES` or `-CompletionPhrases` parameter.

## Testing Changes

1. Make changes to files in repo
2. Copy to local install: `cp hooks/* ~/.claude/hooks/`
3. Test commands: `ralph version`, `ralph status`, etc.
4. For hook testing, start a loop and verify behavior

## GitHub Repository

- Repo: https://github.com/Kukks/winRalph
- One-liner install: `iwr -useb https://raw.githubusercontent.com/Kukks/winRalph/master/install-remote.ps1 | iex`
- Raw file base URL: `https://raw.githubusercontent.com/Kukks/winRalph/master/`
