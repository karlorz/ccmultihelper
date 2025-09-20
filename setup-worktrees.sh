#!/bin/bash
# Simple Git Worktree Setup for Claude Code
# Creates parallel development environments using standard Git worktrees

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-}"
WORKTREES=("feature" "test" "docs" "bugfix")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Validate inputs
if [[ -z "$PROJECT_NAME" ]]; then
    error "Usage: $0 <project-name>"
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not a Git repository. Run this from your project root."
fi

# Check for Claude Code
if ! command -v claude &> /dev/null; then
    error "Claude Code not found. Install with: npm install -g @anthropic-ai/claude-code"
fi

log "Setting up worktrees for $PROJECT_NAME"

# Create worktrees directory
WORKTREE_BASE="../${PROJECT_NAME}-worktrees"
mkdir -p "$WORKTREE_BASE"

# Create each worktree
for worktree in "${WORKTREES[@]}"; do
    worktree_path="${WORKTREE_BASE}/${worktree}"
    branch_name="${worktree}/${PROJECT_NAME}"

    if [[ -d "$worktree_path" ]]; then
        log "Worktree already exists: $worktree"
        continue
    fi

    log "Creating $worktree worktree..."

    # Create branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log "Creating branch: $branch_name"
        git checkout main 2>/dev/null || git checkout master || error "Cannot find main or master branch"
        if ! git checkout -b "$branch_name"; then
            error "Failed to create branch: $branch_name"
        fi
        git checkout main 2>/dev/null || git checkout master || error "Cannot return to main branch"
    fi

    # Create worktree
    if ! git worktree add "$worktree_path" "$branch_name"; then
        error "Failed to create worktree: $worktree_path"
    fi

    # Create simple launch script
    cat > "${worktree_path}/launch-claude.sh" << EOF
#!/bin/bash
# Launch Claude Code in $worktree worktree
echo "Starting Claude Code in $worktree environment..."
claude
EOF
    chmod +x "${worktree_path}/launch-claude.sh"

    log "✓ Created $worktree worktree: $worktree_path"
done

# Create main launch script
cat > "${WORKTREE_BASE}/launch-all.sh" << EOF
#!/bin/bash
# Launch all Claude Code sessions

echo "Opening Claude Code sessions for $PROJECT_NAME..."

# Open terminals for each worktree
for worktree in "${WORKTREES[@]}"; do
    worktree_path="\$(dirname "\$0")/\$worktree"
    echo "Starting \$worktree session..."

    # Try to open in new terminal window
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "cd '\$worktree_path' && claude; exec bash"
    elif command -v xterm &> /dev/null; then
        xterm -e "cd '\$worktree_path' && claude" &
    elif command -v osascript &> /dev/null; then
        # macOS
        osascript -e "tell app \"Terminal\" to do script \"cd '\$worktree_path' && claude\""
    else
        echo "Could not open terminal. Please run manually:"
        echo "  cd '\$worktree_path' && claude"
    fi
done

echo "All sessions started!"
EOF
chmod +x "${WORKTREE_BASE}/launch-all.sh"

log ""
log "✅ Setup complete!"
log ""
log "Worktrees created:"
log "  Base: $WORKTREE_BASE"
for worktree in "${WORKTREES[@]}"; do
    log "  • $worktree: ${WORKTREE_BASE}/${worktree}"
done
log ""
log "Usage:"
log "  Launch all: ${WORKTREE_BASE}/launch-all.sh"
log "  Launch one: ${WORKTREE_BASE}/feature/launch-claude.sh"
log "  Or manually: cd ${WORKTREE_BASE}/feature && claude"
log ""
log "Git worktree commands:"
log "  List:    git worktree list"
log "  Remove:  git worktree remove <path>"
log "  Prune:   git worktree prune"