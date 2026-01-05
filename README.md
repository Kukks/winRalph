# winRalph

**Windows-native autonomous loop for Claude Code** - A PowerShell implementation of the [Ralph Wiggum technique](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/) that works natively on Windows without WSL.

```
  ____       _       _
 |  _ \ __ _| |_ __ | |__
 | |_) / _` | | '_ \| '_ \
 |  _ < (_| | | |_) | | | |
 |_| \_\__,_|_| .__/|_| |_|
              |_|
  Windows Edition
```

## What is this?

winRalph lets Claude Code run autonomously in a loop until a task is complete. Instead of Claude stopping after one response, it keeps working iteration after iteration until it says "TASK_COMPLETE" or hits a safety limit.

**Perfect for:**
- Large refactoring tasks
- Multi-file implementations
- Test coverage improvements
- Documentation generation
- Any task that takes multiple iterations

## Features

- **Windows Native** - Pure PowerShell, no WSL or Bash required
- **Concurrent Sessions** - Each directory gets its own independent loop
- **Smart Context** - `/ralph start` can auto-generate prompts from conversation context
- **Safety Limits** - Configurable max iterations to prevent runaway loops
- **Session Management** - List, monitor, and control all active loops
- **Claude Code Integration** - Works via hooks and slash commands

## Installation

### Quick Install (Recommended)

```powershell
# Clone the repo
git clone https://github.com/Kukks/winRalph.git
cd winRalph

# Run the installer
.\install.ps1
```

### Manual Installation

1. **Copy hooks to Claude Code:**
```powershell
# Create directories if needed
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\hooks"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\commands"

# Copy files
Copy-Item .\hooks\* "$env:USERPROFILE\.claude\hooks\" -Force
Copy-Item .\commands\* "$env:USERPROFILE\.claude\commands\" -Force
```

2. **Add hooks directory to PATH** (optional, for `ralph` command):
```powershell
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$currentPath;$env:USERPROFILE\.claude\hooks", "User")
```

3. **Configure Claude Code hooks** - Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\hooks\\ralph-loop.ps1\"",
            "statusMessage": "Ralph loop checking..."
          }
        ]
      }
    ]
  }
}
```

4. **Restart Claude Code** to load the hooks.

## Usage

### From PowerShell/Terminal

```powershell
# Start a loop
ralph start "Build a REST API with Express. Say TASK_COMPLETE when finished."

# Then run Claude with the same prompt
claude "Build a REST API with Express. Say TASK_COMPLETE when finished."

# Check status
ralph status

# View all sessions
ralph list

# View log
ralph log

# Stop the loop
ralph stop
```

### From Inside Claude Code (Slash Command)

```
/ralph status              # Check current session
/ralph list                # See all sessions
/ralph start               # Smart start - generates prompt from context
/ralph start "my task"     # Start with explicit prompt
/ralph stop                # Stop the loop
/ralph log                 # View session log
```

### Concurrent Sessions

Each directory automatically gets its own session:

```powershell
# Terminal 1 - in C:\Projects\frontend
cd C:\Projects\frontend
ralph start "Build React components"
claude "Build React components"

# Terminal 2 - in C:\Projects\backend (runs independently!)
cd C:\Projects\backend
ralph start "Fix API bugs"
claude "Fix API bugs"

# Check all sessions from anywhere
ralph list
```

### Explicit Session Names

```powershell
ralph start "My task" -Session myproject
ralph status -Session myproject
ralph stop -Session myproject
```

## Completion Phrases

Say any of these to stop the loop:
- `TASK_COMPLETE`
- `ALL_DONE`
- `MISSION_ACCOMPLISHED`

Or customize via environment variable:
```powershell
$env:RALPH_COMPLETION_PHRASES = "DONE,FINISHED,COMPLETE"
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_MAX_ITERATIONS` | `20` | Max iterations before auto-stop |
| `RALPH_COMPLETION_PHRASES` | `TASK_COMPLETE,ALL_DONE,MISSION_ACCOMPLISHED` | Phrases that trigger completion |
| `RALPH_SESSION_ID` | (auto) | Override session ID |

### Command Line Options

```powershell
ralph start "task" -MaxIterations 10
ralph start "task" -Session myproject
ralph start "task" -CompletionPhrases "DONE,FINISHED"
```

## How It Works

1. **`ralph start`** creates a state file for the current session
2. **Claude Code runs** and works on your task
3. **When Claude tries to exit**, the Stop hook intercepts it
4. **Hook checks** if Claude said a completion phrase
5. **If not complete** → blocks exit, feeds back the prompt (exit code 2)
6. **If complete** → allows normal exit
7. **Repeat** until complete or max iterations reached

## File Structure

```
~/.claude/
├── hooks/
│   ├── ralph-loop.ps1    # Stop hook - intercepts Claude exit
│   ├── ralph.ps1         # CLI for controlling loops
│   └── ralph.cmd         # Wrapper for PATH access
├── commands/
│   └── ralph.md          # Slash command for Claude Code
└── settings.json         # Hook configuration
```

State files are stored in:
```
$env:TEMP\ralph-sessions\
├── ralph-state-{session-id}.json
└── ralph-log-{session-id}.txt
```

## Safety

- **Max iterations** - Always set to prevent infinite loops
- **Manual stop** - `ralph stop` works anytime
- **Session isolation** - Different directories can't interfere
- **Clear completion** - Explicit phrases required to complete

## Troubleshooting

### Hook not firing
- Restart Claude Code after installation
- Check `~/.claude/settings.json` has the hook configured
- Run `ralph status` to verify session is active

### PATH not working
- Restart your terminal after installation
- Or run directly: `powershell -File "$env:USERPROFILE\.claude\hooks\ralph.ps1" status`

### Session conflicts
- Each directory has its own session by default
- Use `ralph list` to see all sessions
- Use `-Session name` for explicit control

## Credits

- Inspired by [Geoffrey Huntley's Ralph technique](https://ghuntley.com/ralph/)
- Based on the [Ralph Wiggum plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-wiggum) for Claude Code
- Windows adaptation by the community

## License

MIT License - See [LICENSE](LICENSE) file.

## Contributing

Contributions welcome! Please open an issue or PR.
