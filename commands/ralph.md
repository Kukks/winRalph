---
name: ralph
description: Control the Ralph autonomous loop - start, stop, status, list, log, smart (user)
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
   - `/ralph smart` → Show smart mode status
   - `/ralph smart on` → Enable smart mode (thorough analysis + todo tracking)
   - `/ralph smart off` → Disable smart mode

2. **For `/ralph start` WITHOUT a prompt:**
   - Look at the conversation context above this command
   - Summarize what we've been working on into a clear, actionable task prompt
   - The prompt should be specific and include a clear completion goal
   - **IMPORTANT: Include thorough analysis instructions:**
     - Analyze second and third-order consequences of changes
     - Consider edge cases, failure modes, and cascading effects
     - Trace impacts through dependent code/systems
     - Document reasoning chain for significant decisions
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

When generating a prompt from context, create comprehensive prompts that enforce deep analysis:

**Template:**
```
[Task description from context].

Approach thoroughly:
- Before each change, analyze second and third-order consequences
- Consider edge cases, failure modes, and cascading effects
- Trace impacts through all dependent code and systems
- Document reasoning for significant decisions
- Verify changes don't introduce regressions

Say TASK_COMPLETE when finished.
```

**Examples:**
- "Refactor the authentication module to use JWT. Analyze impact on all auth-dependent services, consider security implications at each step, trace session handling through the entire codebase, and document breaking changes. Say TASK_COMPLETE when finished."
- "Fix the race condition in the worker queue. Identify all code paths that could trigger it, analyze consequences of each fix approach, consider performance implications, and verify no new deadlocks are introduced. Say TASK_COMPLETE when finished."
- "Implement the caching layer for API responses. Evaluate cache invalidation strategies and their failure modes, analyze memory implications, consider stale data scenarios, and trace effects on downstream consumers. Say TASK_COMPLETE when finished."

Be specific about what needs to be done and always include the thorough analysis requirements.

## Smart Mode (Comprehensive Autonomous Mode)

Smart mode provides comprehensive autonomous behavior with:
- **Thorough analysis**: Second-order consequences, edge cases, failure modes
- **Todo tracking**: Integrated with Claude Code's native TodoWrite
- **Retrospective checks**: Verify completed work, check for regressions
- **Auto-discovery**: Identify and add new tasks while working

**For `/ralph smart on`:**
1. Run `ralph smart session` to create the flag file
2. Tell user: "Smart mode enabled. I'll work thoroughly with todo tracking, retrospectives, and discovery."

**For `/ralph smart off`:**
1. Run `ralph smart off` to remove the flag file
2. Tell user: "Smart mode disabled."

**For `/ralph smart`** (no argument):
1. Run `ralph smart` to check status
2. Report whether smart mode is enabled or disabled

When smart mode is ON, you (Claude) should:
- Analyze second and third-order consequences of changes
- Consider edge cases, failure modes, and cascading effects
- Use TodoWrite to track progress on complex tasks
- Verify completed work functions correctly (retrospective)
- Identify and add new tasks discovered during work (discovery)
- Be thorough rather than quick

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

For `/ralph smart`:
```bash
powershell -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/ralph.ps1" smart
```

For `/ralph smart on` (session only):
```bash
powershell -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/ralph.ps1" smart session
```
Then confirm to user that smart mode is enabled for this session.

For `/ralph smart off`:
```bash
powershell -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/ralph.ps1" smart off
```

Now execute the ralph command based on the arguments provided.
