#!/bin/bash
# Setup Git hooks for automated workflow triggering

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Check if we're in a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not a Git repository. Run this from your project root."
fi

log "🔧 Setting up Git hooks for automated workflows"

# Create hooks directory if it doesn't exist
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
mkdir -p "$HOOKS_DIR"

# Post-commit hook for auto-triggering workflows
cat > "$HOOKS_DIR/post-commit" << 'EOF'
#!/bin/bash
# Post-commit hook: Auto-trigger workflows based on branch type

set -euo pipefail

CURRENT_BRANCH=$(git branch --show-current)
LOG_FILE="/tmp/claude-git-hooks.log"
PROJECT_NAME=""

# Extract project name from branch (format: type/project-name)
if [[ $CURRENT_BRANCH =~ ^([a-z]+)/(.+)$ ]]; then
    BRANCH_TYPE="${BASH_REMATCH[1]}"
    PROJECT_NAME="${BASH_REMATCH[2]}"
else
    # Skip hook for main/master branches
    exit 0
fi

# Log the event
echo "[$(date)] Post-commit hook triggered for branch: $CURRENT_BRANCH" >> "$LOG_FILE"

# Function to trigger workflow
trigger_workflow() {
    local workflow_type="$1"
    local target_branch="$2"

    echo "[$(date)] Triggering $workflow_type workflow" >> "$LOG_FILE"

    # Try to push changes first
    if git push origin "$CURRENT_BRANCH" 2>> "$LOG_FILE"; then
        echo "[$(date] Successfully pushed $CURRENT_BRANCH to remote" >> "$LOG_FILE"
    else
        echo "[$(date)] Failed to push $CURRENT_BRANCH (may not have remote access)" >> "$LOG_FILE"
    fi

    # Look for worktrees
    local worktree_base=""
    local repo_root=$(git rev-parse --show-toplevel)
    local repo_name=$(basename "$repo_root")

    # Check different possible worktree locations
    if [[ -d "../${repo_name}-worktrees" ]]; then
        worktree_base="../${repo_name}-worktrees"
    elif [[ -d "../${PROJECT_NAME}-worktrees" ]]; then
        worktree_base="../${PROJECT_NAME}-worktrees"
    else
        echo "[$(date)] No worktrees found for $PROJECT_NAME" >> "$LOG_FILE"
        return 1
    fi

    echo "[$(date)] Found worktree base: $worktree_base" >> "$LOG_FILE"

    # Trigger specific workflow
    case "$workflow_type" in
        "test")
            local test_worktree="$worktree_base/test"
            if [[ -d "$test_worktree" ]]; then
                cd "$test_worktree"
                echo "[$(date)] Running test workflow in $test_worktree" >> "$LOG_FILE"

                # Pull latest changes
                if git pull origin "$target_branch" 2>> "$LOG_FILE"; then
                    echo "[$(date)] Successfully pulled changes" >> "$LOG_FILE"
                fi

                # Run tests
                if [[ -f "package.json" ]]; then
                    echo "[$(date)] Running npm tests" >> "$LOG_FILE"
                    npm test >> "$LOG_FILE" 2>&1
                elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
                    echo "[$(date)] Running Python tests" >> "$LOG_FILE"
                    if command -v pytest &> /dev/null; then
                        pytest >> "$LOG_FILE" 2>&1
                    fi
                fi

                # Commit test results
                if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
                    git add .
                    git commit -m "Auto-test: Test results for $target_branch $(date '+%Y-%m-%d %H:%M:%S')"
                    git push origin test/"$PROJECT_NAME" 2>> "$LOG_FILE" || true
                fi

                echo "[$(date)] Test workflow completed" >> "$LOG_FILE"
            fi
            ;;
        "docs")
            local docs_worktree="$worktree_base/docs"
            if [[ -d "$docs_worktree" ]]; then
                cd "$docs_worktree"
                echo "[$(date)] Triggering documentation workflow in $docs_worktree" >> "$LOG_FILE"

                # Pull latest changes
                if git pull origin "$target_branch" 2>> "$LOG_FILE"; then
                    echo "[$(date)] Successfully pulled changes" >> "$LOG_FILE"
                fi

                # Create documentation needed signal
                echo "Documentation update needed for $target_branch" > .docs-needed
                echo "[$(date)] Documentation workflow triggered" >> "$LOG_FILE"
            fi
            ;;
        "validation")
            local test_worktree="$worktree_base/test"
            if [[ -d "$test_worktree" ]]; then
                cd "$test_worktree"
                echo "[$(date)] Running validation workflow in $test_worktree" >> "$LOG_FILE"

                # Pull latest changes
                if git pull origin "$target_branch" 2>> "$LOG_FILE"; then
                    echo "[$(date)] Successfully pulled changes" >> "$LOG_FILE"

                    # Run validation tests
                    if [[ -f "package.json" ]]; then
                        npm test >> "$LOG_FILE" 2>&1
                    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
                        if command -v pytest &> /dev/null; then
                            pytest >> "$LOG_FILE" 2>&1
                        fi
                    fi

                    # If validation passes, trigger merge to main
                    if [[ $? -eq 0 ]]; then
                        echo "[$(date)] Validation passed, triggering merge to main" >> "$LOG_FILE"
                        # Create signal for merge
                        touch .validation-complete
                    fi
                fi
            fi
            ;;
    esac
}

# Trigger workflows based on branch type
case "$BRANCH_TYPE" in
    "feature")
        echo "[$(date)] Feature branch detected: $CURRENT_BRANCH" >> "$LOG_FILE"
        trigger_workflow "test" "$CURRENT_BRANCH"
        ;;
    "test")
        echo "[$(date)] Test branch detected: $CURRENT_BRANCH" >> "$LOG_FILE"
        # Test branch commits might trigger documentation updates
        trigger_workflow "docs" "$CURRENT_BRANCH"
        ;;
    "bugfix")
        echo "[$(date)] Bugfix branch detected: $CURRENT_BRANCH" >> "$LOG_FILE"
        trigger_workflow "validation" "$CURRENT_BRANCH"
        ;;
    "docs")
        echo "[$(date)] Docs branch detected: $CURRENT_BRANCH" >> "$LOG_FILE"
        # Documentation branches don't trigger additional workflows
        ;;
    *)
        echo "[$(date)] Unknown branch type: $BRANCH_TYPE" >> "$LOG_FILE"
        ;;
esac

echo "[$(date)] Post-commit hook completed for $CURRENT_BRANCH" >> "$LOG_FILE"
EOF

# Post-merge hook for handling merges
cat > "$HOOKS_DIR/post-merge" << 'EOF'
#!/bin/bash
# Post-merge hook: Handle merge events

set -euo pipefail

LOG_FILE="/tmp/claude-git-hooks.log"
CURRENT_BRANCH=$(git branch --show-current)

echo "[$(date)] Post-merge hook triggered for branch: $CURRENT_BRANCH" >> "$LOG_FILE"

# If we're on main branch and a merge just happened, check if it was a validated bugfix
if [[ "$CURRENT_BRANCH" == "main" ]] || [[ "$CURRENT_BRANCH" == "master" ]]; then
    # Check if the last commit was a merge
    if git log --oneline -1 | grep -q "Merge"; then
        echo "[$(date)] Merge detected on main branch" >> "$LOG_FILE"

        # Could trigger deployment workflows here
        echo "[$(date)] Main branch updated, could trigger deployment" >> "$LOG_FILE"
    fi
fi

echo "[$(date)] Post-merge hook completed" >> "$LOG_FILE"
EOF

# Make hooks executable
chmod +x "$HOOKS_DIR/post-commit"
chmod +x "$HOOKS_DIR/post-merge"

log "✅ Git hooks installed successfully"
log ""
log "Available hooks:"
log "  • post-commit: Triggers workflows based on branch type"
log "  • post-merge: Handles merge events"
log ""
log "Hook behaviors:"
log "  • feature/* branches → Trigger test workflow"
log "  • test/* branches → Trigger documentation workflow"
log "  • bugfix/* branches → Trigger validation workflow"
log "  • docs/* branches → No automatic triggering"
log ""
log "Logs are written to: /tmp/claude-git-hooks.log"
log ""
log "To disable hooks temporarily:"
log "  cd .git/hooks && chmod -x post-commit post-merge"
log ""
log "To re-enable hooks:"
log "  cd .git/hooks && chmod +x post-commit post-merge"