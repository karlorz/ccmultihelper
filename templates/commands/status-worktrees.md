---
description: Show status of all worktrees and their workflows
allowed-tools: Bash(git*), Read(*), Write(*)
---

# Show worktree status for ${PROJECT_NAME}

## Context

- Current project: !`basename "$PWD"`
- Project directory: !`pwd`
- Current time: !`date`

## Worktree status

!`if [ -d "../${PROJECT_NAME}-worktrees" ]; then
  echo "Worktrees directory: ../${PROJECT_NAME}-worktrees/"
  echo ""
  for worktree in feature test docs bugfix; do
    if [ -d "../${PROJECT_NAME}-worktrees/$worktree" ]; then
      echo "### $worktree worktree"
      echo "Location: ../${PROJECT_NAME}-worktrees/$worktree"
      echo "Branch: $(cd "../${PROJECT_NAME}-worktrees/$worktree" && git branch --show-current 2>/dev/null || echo "no branch")"
      echo "Last commit: $(cd "../${PROJECT_NAME}-worktrees/$worktree" && git log -1 --oneline 2>/dev/null || echo "no commits")"
      echo "Uncommitted changes: $(cd "../${PROJECT_NAME}-worktrees/$worktree" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ') files"

      # Check for signal files
      if [ -f "../${PROJECT_NAME}-worktrees/$worktree/.claude-complete" ]; then
        echo "Signal: .claude-complete (feature ready for testing)"
      fi
      if [ -f "../${PROJECT_NAME}-worktrees/$worktree/.tests-complete" ]; then
        echo "Signal: .tests-complete (tests ready for documentation)"
      fi
      if [ -f "../${PROJECT_NAME}-worktrees/$worktree/.bugfix-complete" ]; then
        echo "Signal: .bugfix-complete (bugfix ready for validation)"
      fi
      if [ -f "../${PROJECT_NAME}-worktrees/$worktree/.docs-needed" ]; then
        echo "Signal: .docs-needed (documentation updates needed)"
      fi
      echo ""
    fi
  done
else
  echo "No worktrees found"
fi`

## Signal files status

!`echo "Active signals across all worktrees:"
find "../${PROJECT_NAME}-worktrees/" -name ".*-complete" -o -name ".*-needed" 2>/dev/null | head -10 || echo "No active signals"`

## Monitoring status

!`if pgrep -f "claude.*monitor" > /dev/null; then
  echo "✅ Monitoring services are running"
  ps aux | grep "claude.*monitor" | grep -v grep | head -5
else
  echo "⚠️  No monitoring services running"
fi`

## Git worktree status

!`git worktree list 2>/dev/null || echo "No additional worktrees configured"`

## Your task

Provide a comprehensive status report covering:

1. **Worktree overview**: Which worktrees exist and their basic state
2. **Signal file status**: What workflows are ready to be triggered
3. **Monitoring status**: Whether automated coordination is active
4. **Git synchronization**: Current sync state across worktrees
5. **Recommendations**: What actions should be taken next

Focus on highlighting any pending workflows, conflicts, or issues that need attention.