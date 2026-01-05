---
name: ralph
description: Control the Ralph autonomous loop - start, stop, status, list, log
allowed-tools: Bash
---

# Ralph Loop Control

You are handling a `/ralph` command. Parse the arguments and execute the appropriate action.

**Arguments received:** $ARGUMENTS

## Instructions

1. **Parse the command** from the arguments:
   - `/ralph` or `/ralph help` → Show help
   - `/ralph status` → Check current session status
   - `/ralph list` → List all sessions
   - `/ralph log` → Show session log
   - `/ralph stop` → Stop the current loop
   - `/ralph start` → Start a loop (see below for prompt handling)
   - `/ralph start "explicit prompt"` → Start with the given prompt
   - `/ralph clear` → Clear session state

2. **For `/ralph start` WITHOUT a prompt:**
   - Look at the conversation context above this command
   - Summarize what we've been working on into a clear, actionable task prompt
   - The prompt should be specific and include a clear completion goal
   - Add "Say TASK_COMPLETE when finished." to the end
   - Then start ralph with that generated prompt

3. **Execute the ralph command:**
   ```bash
   powershell -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/ralph.ps1" <command> [args]
   ```

4. **After starting a ralph loop:**
   - Tell the user the loop is active
   - Remind them that you (Claude) will keep working until you say TASK_COMPLETE
   - If this is a restart, immediately continue working on the task

## Context-Aware Prompt Generation

When generating a prompt from context, create something like:
- "Continue implementing [feature] - [specific next steps]. Say TASK_COMPLETE when finished."
- "Fix the [issue] by [approach]. Say TASK_COMPLETE when finished."
- "Complete the [task] including [remaining items]. Say TASK_COMPLETE when finished."

Be specific about what needs to be done based on our conversation.

## Example Executions

For `/ralph status`:
```bash
powershell -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/ralph.ps1" status
```

For `/ralph start "Build the API"`:
```bash
powershell -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/ralph.ps1" start "Build the API. Say TASK_COMPLETE when finished."
```

For `/ralph start` (no prompt - generate from context):
1. Analyze conversation
2. Generate prompt
3. Run: `powershell -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/ralph.ps1" start "<generated prompt>"`

Now execute the ralph command based on the arguments provided.
