# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Git worktree setup example for running multiple Claude Code sessions in parallel. The repository contains a bash script and documentation for setting up isolated development environments using Git worktrees, following official Claude Code parallel development patterns.

## Architecture

The project consists of two main components:

1. **setup-worktrees.sh** (lines 1-132): Main bash script that creates parallel Git worktrees for different development tasks
2. **README.md** (lines 1-200): Comprehensive documentation with usage instructions and best practices

The setup creates four standardized worktrees:
- **feature/**: For new feature development
- **test/**: For testing and validation work
- **docs/**: For documentation tasks
- **bugfix/**: For bug fixing

## Common Commands

### Setup Worktrees
```bash
# From your Git repository root
./examples/multi-worktree-setup/setup-worktrees.sh <project-name>
```

### Launch Sessions
```bash
# Launch all Claude Code sessions at once
../<project-name>-worktrees/launch-all.sh

# Launch individual session
cd ../<project-name>-worktrees/feature && claude

# Or use provided launch script
../<project-name>-worktrees/feature/launch-claude.sh
```

### Git Worktree Management
```bash
# List all worktrees
git worktree list

# Remove a worktree
git worktree remove ../<project-name>-worktrees/feature

# Clean up stale worktrees
git worktree prune
```

## Worktree Synchronization and Information Sharing

### How Worktrees Share Information
All worktrees share the same underlying Git repository, which means:
- **Commits are shared**: Changes committed in one worktree are visible in all other worktrees
- **Branches are global**: All worktrees can access all branches in the repository
- **Remote synchronization**: Changes pushed from any worktree are available to all worktrees via `git pull`

### Synchronizing Changes Between Worktrees

**Method 1: Git Pull/Push (Recommended)**
```bash
# In feature worktree - commit and push changes
cd ../my-project-worktrees/feature
git add .
git commit -m "Add new feature"
git push origin feature/my-project

# In test worktree - pull the latest changes
cd ../my-project-worktrees/test
git pull origin feature/my-project
```

**Method 2: Direct Branch Checkout**
```bash
# In test worktree - checkout the feature branch to see changes
cd ../my-project-worktrees/test
git checkout feature/my-project
# Now you can see all changes from the feature worktree

# Return to your test branch when done
git checkout test/my-project
```

**Method 3: Merge Changes**
```bash
# In test worktree - merge feature changes into test branch
cd ../my-project-worktrees/test
git merge feature/my-project
```

### Claude Code Commit Workflow

**Basic Commit Process:**
```bash
# In any worktree, make changes with Claude Code
cd ../my-project-worktrees/feature
claude

# After Claude Code makes changes, commit them
git add .
git commit -m "Implement feature changes with Claude Code"
git push origin feature/my-project
```

**Multi-Worktree Collaboration Example:**
```bash
# 1. Feature development in feature worktree
cd ../my-project-worktrees/feature
claude  # Claude implements new feature
git add .
git commit -m "Add user authentication feature"
git push origin feature/my-project

# 2. Testing in test worktree
cd ../my-project-worktrees/test
git pull origin feature/my-project
claude  # Claude writes tests for the feature
git add .
git commit -m "Add tests for user authentication"
git push origin test/my-project

# 3. Documentation in docs worktree
cd ../my-project-worktrees/docs
git pull origin feature/my-project
claude  # Claude updates documentation
git add .
git commit -m "Update API documentation for auth feature"
git push origin docs/my-project
```

### Real-time Information Sharing

**Sharing Files Between Worktrees:**
```bash
# Copy specific files between worktrees
cp ../my-project-worktrees/feature/new-component.js ../my-project-worktrees/test/

# Or use Git to checkout specific files
cd ../my-project-worktrees/test
git checkout feature/my-project -- path/to/file.js
```

**Viewing Changes Across Worktrees:**
```bash
# See what's different between worktrees
cd ../my-project-worktrees/test
git diff feature/my-project

# See commit history from other worktrees
git log feature/my-project --oneline
```

### Branch Management Workflow

**Creating Related Branches:**
```bash
# Create a new feature branch based on existing work
cd ../my-project-worktrees/feature
git checkout -b feature/my-project-v2 feature/my-project

# Track it in other worktrees
cd ../my-project-worktrees/test
git checkout --track origin/feature/my-project-v2
```

**Integrating Changes to Main:**
```bash
# When feature is ready, merge to main branch
cd ../my-project-worktrees/feature
git checkout main
git merge feature/my-project
git push origin main

# Update other worktrees with main branch changes
cd ../my-project-worktrees/test
git pull origin main
```

## Development Workflow

The worktree setup enables parallel development where each worktree:
- Has its own working directory and Git state
- Can run independent Claude Code sessions
- Shares the same underlying Git repository history
- Synchronizes changes via standard Git operations
- Can access commits and branches from other worktrees

### Best Practices
- Use different worktrees for different types of development tasks
- Keep feature development in the `feature/` worktree
- Use `test/` worktree for running tests and validation
- Isolate documentation work in the `docs/` worktree
- Fix bugs in the dedicated `bugfix/` worktree
- **Pull changes regularly** to stay synchronized with other worktrees
- **Push changes frequently** to make them available to other worktrees
- **Use descriptive commit messages** to track changes across worktrees

## Configuration

The script automatically:
- Creates worktree branches with naming pattern `<type>/<project-name>`
- Generates launch scripts for each worktree
- Sets up a master launch script for all sessions
- Handles cross-platform terminal detection (macOS, Linux with gnome-terminal/xterm)

## Prerequisites

- Git repository initialized in parent directory
- Claude Code installed globally: `npm install -g @anthropic-ai/claude-code`
- Bash shell for script execution

## Automated Workflows

### Overview

The basic worktree setup can be enhanced with **automated workflows** that enable:
- **Auto-detection**: Detect when Claude Code completes work in one worktree
- **Auto-triggering**: Automatically trigger workflows in other worktrees
- **Auto-coordination**: Coordinate multiple Claude Code sessions without manual intervention

### Automation Methods

#### 1. File System Monitoring (Recommended)
```bash
# Monitor feature worktree for changes and auto-run tests
./monitor-feature.sh <project-name>

# This script will:
# - Watch for file changes in feature worktree
# - Auto-commit changes when detected
# - Trigger test workflow automatically
# - Run tests and commit results
```

#### 2. Auto-Detection with Signal Files
```bash
# Start auto-detection system
./auto-detect-workflow.sh <project-name>

# When Claude Code finishes in feature worktree:
touch ../my-project-worktrees/feature/.claude-complete

# Auto-detection will:
# - Detect completion signal
# - Trigger test workflow
# - Tests complete → trigger documentation workflow
```

#### 3. Git Hooks Automation
```bash
# Install Git hooks for automated workflows
./setup-git-hooks.sh

# This creates hooks that:
# - Auto-trigger workflows on commits based on branch type
# - feature/* branches → trigger test workflow
# - test/* branches → trigger documentation workflow
# - bugfix/* branches → trigger validation workflow
```

#### 4. Webhook-Based Automation
```bash
# Start webhook server (Python)
./webhook-server.py [port]

# Send webhooks to trigger workflows:
curl -X POST http://localhost:8080/webhook/claude-complete \
  -H "Content-Type: application/json" \
  -d '{"project_name": "my-project", "worktree_type": "feature"}'
```

### Real-World Automation Scenarios

#### Scenario 1: Feature → Test → Documentation Pipeline
```bash
# 1. Start automation system
./auto-detect-workflow.sh my-project &

# 2. Work in feature worktree
cd ../my-project-worktrees/feature
claude  # Claude develops feature

# 3. Signal completion (Claude can do this automatically)
touch .claude-complete

# 4. Automation handles the rest:
#    → Test workflow triggered automatically
#    → Tests run in test worktree
#    → Documentation workflow triggered
#    → Documentation updated in docs worktree
```

#### Scenario 2: Bug Fix → Validation → Auto-Merge
```bash
# 1. Fix bug in bugfix worktree
cd ../my-project-worktrees/bugfix
claude  # Claude fixes bug
touch .bugfix-complete

# 2. Auto-detection triggers validation
#    → Tests run in test worktree
#    → If tests pass, auto-merge to main
#    → Changes deployed to main branch
```

#### Scenario 3: Continuous Integration with Multiple Agents
```bash
# 1. Start monitoring system
./monitor-feature.sh my-project &

# 2. Multiple Claude Code sessions running in parallel:
#    - Feature worktree: Active development
#    - Test worktree: Continuous testing
#    - Docs worktree: Documentation updates
#    - Bugfix worktree: Bug fixes

# 3. Changes automatically flow between worktrees:
#    Feature complete → Test → Validate → Document → Deploy
```

### Claude Code Integration

#### Signal Files for Workflow Coordination
Create these files to signal workflow completion:
```bash
# In feature worktree
touch .claude-complete        # Signals feature completion

# In test worktree
touch .tests-complete        # Signals test completion

# In bugfix worktree
touch .bugfix-complete       # Signals bugfix completion
```

#### Automated Commit Messages
The automation system creates standardized commit messages:
```
Auto-commit: Claude Code changes detected 2024-01-15 14:30:25
Auto-test: Test results for feature changes 2024-01-15 14:32:10
Auto-docs: Documentation updates for feature 2024-01-15 14:35:00
```

### Implementation Steps

1. **Choose automation method**: File monitoring recommended for most use cases
2. **Install dependencies**: `brew install fswatch` (macOS) or `sudo apt-get install inotify-tools` (Linux)
3. **Setup automation scripts**: Choose monitoring, auto-detection, or webhook approach
4. **Test the workflow**: Verify signals and triggers work correctly
5. **Deploy to production**: Run automation scripts in background or dedicated terminals

### Monitoring and Logging

All automation methods create detailed logs:
- `/tmp/claude-workflow.log` - File monitoring logs
- `/tmp/claude-auto-detect.log` - Auto-detection logs
- `/tmp/claude-git-hooks.log` - Git hook logs
- `/tmp/claude-webhook.log` - Webhook server logs

### Best Practices

- **Use signal files**: Create `.claude-complete`, `.tests-complete`, etc. to mark workflow stages
- **Monitor logs**: Check log files to debug automation issues
- **Start small**: Begin with one automation method before adding others
- **Test thoroughly**: Verify each workflow stage works as expected
- **Handle failures**: Build in error handling for when workflows fail
- **Resource management**: Monitor system resources with multiple automation processes

This automation transforms basic worktrees into a **self-coordinating development system** where Claude Code agents can automatically detect and respond to each other's work.

## Cleanup

Remove all worktrees:
```bash
git worktree remove ../<project-name>-worktrees/feature
git worktree remove ../<project-name>-worktrees/test
git worktree remove ../<project-name>-worktrees/docs
git worktree remove ../<project-name>-worktrees/bugfix
git worktree prune
rm -rf ../<project-name>-worktrees
```

This setup follows the official Claude Code documentation for parallel development workflows using Git worktrees.