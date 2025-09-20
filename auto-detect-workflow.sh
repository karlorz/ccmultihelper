#!/bin/bash
# Auto-detect when Claude Code completes work and trigger next steps

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-test-project}"
WORKTREE_BASE="../${PROJECT_NAME}-worktrees"
LOG_FILE="/tmp/claude-auto-detect.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# Validate setup
if [[ ! -d "$WORKTREE_BASE" ]]; then
    error "Worktree base not found: $WORKTREE_BASE"
fi

log "🤖 Auto-detect workflow started for $PROJECT_NAME"
log "Worktree base: $WORKTREE_BASE"
log "Log file: $LOG_FILE"
log ""

# Function to trigger test workflow
trigger_test_workflow() {
    log "🧪 Triggering test workflow"

    local test_worktree="$WORKTREE_BASE/test"
    if [[ ! -d "$test_worktree" ]]; then
        warn "Test worktree not found: $test_worktree"
        return 1
    fi

    cd "$test_worktree"

    # Pull latest changes from feature worktree
    log "📥 Pulling latest changes from feature worktree"
    if git pull origin feature/"$PROJECT_NAME" 2>/dev/null; then
        log "✅ Successfully pulled changes"
    else
        warn "⚠️  Failed to pull changes (branch may not exist or no remote access)"
    fi

    # Detect and run tests
    log "🔍 Detecting project type and running tests"
    local test_success=false

    # Node.js projects
    if [[ -f "package.json" ]]; then
        log "📦 Node.js project detected"
        if npm test 2>> "$LOG_FILE"; then
            log "✅ npm tests passed"
            test_success=true
        else
            warn "⚠️  npm tests failed"
        fi
    fi

    # Python projects
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
        log "🐍 Python project detected"
        if command -v pytest &> /dev/null; then
            if pytest 2>> "$LOG_FILE"; then
                log "✅ pytest tests passed"
                test_success=true
            else
                warn "⚠️  pytest tests failed"
            fi
        elif command -v python &> /dev/null; then
            if python -m pytest 2>> "$LOG_FILE"; then
                log "✅ Python tests passed"
                test_success=true
            else
                warn "⚠️  Python tests failed"
            fi
        fi
    fi

    # Generic test detection
    if [[ "$test_success" = false ]]; then
        if find . -name "*test*" -type f | grep -q .; then
            log "🔍 Test files found but no specific test runner detected"
            # Try to run any executable test files
            find . -name "*test*" -type f -executable -exec {} \; 2>/dev/null || true
        else
            log "ℹ️  No test files detected, creating test completion signal anyway"
        fi
    fi

    # Commit test results if there are any changes
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        log "💾 Committing test results"
        git add .
        git commit -m "Auto-test: Test results for $PROJECT_NAME $(date '+%Y-%m-%d %H:%M:%S')"

        if git push origin test/"$PROJECT_NAME" 2>/dev/null; then
            log "✅ Test results pushed to remote"
        else
            warn "⚠️  Failed to push test results to remote"
        fi
    fi

    # Create test completion signal
    touch "$test_worktree/.tests-complete"
    log "✅ Test completion signal created"

    log "🎉 Test workflow completed"
    return 0
}

# Function to trigger documentation workflow
trigger_docs_workflow() {
    log "📚 Triggering documentation workflow"

    local docs_worktree="$WORKTREE_BASE/docs"
    if [[ ! -d "$docs_worktree" ]]; then
        warn "Documentation worktree not found: $docs_worktree"
        return 1
    fi

    cd "$docs_worktree"

    # Pull latest changes
    log "📥 Pulling latest changes from feature worktree"
    if git pull origin feature/"$PROJECT_NAME" 2>/dev/null; then
        log "✅ Successfully pulled changes"
    else
        warn "⚠️  Failed to pull changes"
    fi

    # Create documentation needed signal
    log "📝 Creating documentation update needed signal"
    echo "Documentation update needed for feature: $PROJECT_NAME" > .docs-needed

    log "✅ Documentation workflow triggered"
    return 0
}

# Function to trigger bugfix validation workflow
trigger_bugfix_validation() {
    log "🔧 Triggering bugfix validation workflow"

    local test_worktree="$WORKTREE_BASE/test"
    if [[ ! -d "$test_worktree" ]]; then
        warn "Test worktree not found: $test_worktree"
        return 1
    fi

    cd "$test_worktree"

    # Pull latest bugfix changes
    log "📥 Pulling latest bugfix changes"
    if git pull origin bugfix/"$PROJECT_NAME" 2>/dev/null; then
        log "✅ Successfully pulled bugfix changes"

        # Run validation tests
        log "🧪 Running validation tests"
        if command -v npm &> /dev/null && [[ -f "package.json" ]]; then
            npm test 2>> "$LOG_FILE"
        elif command -v pytest &> /dev/null; then
            pytest 2>> "$LOG_FILE"
        fi

        # If tests pass, trigger merge to main
        log "✅ Bugfix validation completed"
        touch "$test_worktree/.bugfix-validated"
    else
        warn "⚠️  Failed to pull bugfix changes"
    fi

    return 0
}

# Main monitoring loop
log "🔄 Starting auto-detection loop (checking every 5 seconds)"

while true; do
    # Check for feature completion
    if [[ -f "$WORKTREE_BASE/feature/.claude-complete" ]]; then
        log "🎯 Claude Code completion detected in feature worktree"

        # Remove completion signal
        rm -f "$WORKTREE_BASE/feature/.claude-complete"

        # Trigger test workflow
        if trigger_test_workflow; then
            log "✅ Test workflow completed successfully"
        else
            warn "⚠️  Test workflow failed"
        fi
    fi

    # Check for test completion to trigger documentation
    if [[ -f "$WORKTREE_BASE/test/.tests-complete" ]]; then
        log "📚 Test completion detected, triggering documentation workflow"

        rm -f "$WORKTREE_BASE/test/.tests-complete"

        # Trigger documentation workflow
        if trigger_docs_workflow; then
            log "✅ Documentation workflow completed successfully"
        else
            warn "⚠️  Documentation workflow failed"
        fi
    fi

    # Check for bugfix completion
    if [[ -f "$WORKTREE_BASE/bugfix/.bugfix-complete" ]]; then
        log "🔧 Bugfix completion detected, triggering validation"

        rm -f "$WORKTREE_BASE/bugfix/.bugfix-complete"

        # Trigger bugfix validation workflow
        if trigger_bugfix_validation; then
            log "✅ Bugfix validation completed successfully"
        else
            warn "⚠️  Bugfix validation failed"
        fi
    fi

    # Check for bugfix validation to trigger merge
    if [[ -f "$WORKTREE_BASE/test/.bugfix-validated" ]]; then
        log "🔀 Bugfix validation detected, triggering merge to main"

        rm -f "$WORKTREE_BASE/test/.bugfix-validated"

        # Auto-merge to main (if tests pass)
        cd "$WORKTREE_BASE/bugfix"
        if git checkout main 2>/dev/null; then
            if git merge bugfix/"$PROJECT_NAME" 2>/dev/null; then
                log "✅ Successfully merged bugfix to main"
                git push origin main 2>/dev/null || warn "⚠️  Failed to push main to remote"
            else
                warn "⚠️  Failed to merge bugfix to main"
            fi
            git checkout bugfix/"$PROJECT_NAME" 2>/dev/null || true
        fi
    fi

    # Sleep before next check
    sleep 5
done