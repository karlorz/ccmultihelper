---
description: Create signal files to coordinate worktree workflows
argument-hint: <signal-type> (claude-complete, tests-complete, bugfix-complete, docs-needed)
allowed-tools: Bash(*), Write(*), Read(*)
---

# Create signal file for workflow coordination

## Context

- Project: ${PROJECT_NAME}
- Current directory: !`pwd`
- Available worktrees: !`ls ../${PROJECT_NAME}-worktrees/ 2>/dev/null | tr '\n' ' ' || echo "none"`

## Signal types available

- **claude-complete**: Feature work completed, trigger test workflow
- **tests-complete**: Testing completed, trigger documentation workflow
- **bugfix-complete**: Bugfix completed, trigger validation workflow
- **docs-needed**: Documentation updates needed

## Requested signal

Signal type: **$ARGUMENTS**

## Your task

Create the appropriate signal file in the correct worktree directory:

1. **Validate signal type**: Ensure the requested signal type is valid
2. **Determine target worktree**: Choose the correct worktree for this signal
3. **Create signal file**: Create the signal file in the appropriate location
4. **Confirm creation**: Verify the signal file was created successfully
5. **Next steps**: Explain what workflow this signal will trigger

## Signal file locations:

- `../${PROJECT_NAME}-worktrees/feature/.claude-complete` → Trigger test workflow
- `../${PROJECT_NAME}-worktrees/test/.tests-complete` → Trigger documentation workflow
- `../${PROJECT_NAME}-worktrees/bugfix/.bugfix-complete` → Trigger validation workflow
- `../${PROJECT_NAME}-worktrees/docs/.docs-needed` → Documentation needed

## Expected workflow:

1. You create the signal file
2. Claude Code hooks detect the signal
3. Appropriate workflow is automatically triggered
4. Next stage of worktree coordination begins

Please create the signal file and explain what will happen next.