---
description: Synchronize changes between all worktrees
allowed-tools: Bash(git*), Read(*), Write(*)
---

# Synchronize all worktrees for ${PROJECT_NAME}

## Context

- Current project: !`basename "$PWD"`
- Worktrees location: !`ls -la ../${PROJECT_NAME}-worktrees/ 2>/dev/null || echo "Worktrees not found"`
- Current git status: !`git status --porcelain`
- Current branch: !`git branch --show-current`

## Available worktrees

!`if [ -d "../${PROJECT_NAME}-worktrees" ]; then
  for worktree in feature test docs bugfix; do
    if [ -d "../${PROJECT_NAME}-worktrees/$worktree" ]; then
      echo "- $worktree: $(cd "../${PROJECT_NAME}-worktrees/$worktree" && git branch --show-current 2>/dev/null || echo "no branch")"
    fi
  done
else
  echo "No worktrees found"
fi`

## Git remote status

!`git remote -v 2>/dev/null || echo "No remote configured"`

## Your task

Analyze the current state of all worktrees and provide synchronization recommendations:

1. **Check worktree status**: Show the current git status of each worktree
2. **Identify conflicts**: Look for any merge conflicts or uncommitted changes
3. **Recommend sync actions**: Suggest which worktrees need to be synchronized
4. **Provide sync commands**: Give specific git commands to sync the worktrees

## Expected output

Provide a clear analysis of:
- Which worktrees have uncommitted changes
- Which worktrees are out of sync with remote
- Any conflicts that need resolution
- Step-by-step sync commands for each worktree

Focus on the most critical sync actions first and provide clear, executable commands.