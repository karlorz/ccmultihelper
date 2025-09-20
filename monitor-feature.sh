#!/bin/bash
# Monitor feature worktree for file changes and auto-run tests

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-test-project}"
FEATURE_WORKTREE="../${PROJECT_NAME}-worktrees/feature"
TEST_WORKTREE="../${PROJECT_NAME}-worktrees/test"
LOG_FILE="/tmp/claude-workflow.log"

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
if [[ ! -d "$FEATURE_WORKTREE" ]]; then
    error "Feature worktree not found: $FEATURE_WORKTREE"
fi

if [[ ! -d "$TEST_WORKTREE" ]]; then
    error "Test worktree not found: $TEST_WORKTREE"
fi

# Check for monitoring tools
if command -v fswatch &> /dev/null; then
    MONITOR_CMD="fswatch"
    MONITOR_OPTS="-o"
elif command -v inotifywait &> /dev/null; then
    MONITOR_CMD="inotifywait"
    MONITOR_OPTS="-q -e modify -e create -e delete -e move -r"
else
    error "No file monitoring tool found. Install fswatch (macOS) or inotify-tools (Linux)"
fi

log "🔍 Starting feature worktree monitoring for $PROJECT_NAME"
log "Feature worktree: $FEATURE_WORKTREE"
log "Test worktree: $TEST_WORKTREE"
log "Log file: $LOG_FILE"
log "Monitoring tool: $MONITOR_CMD"
log ""

# Create a temporary file to track recent changes to avoid duplicate processing
TEMP_FILE="/tmp/claude-monitor-$$.tmp"
touch "$TEMP_FILE"

# Monitor for file changes
$MONITOR_CMD $MONITOR_OPTS "$FEATURE_WORKTREE" | while read change; do
    # Check if we've processed a change recently (within 5 seconds)
    if [[ -f "$TEMP_FILE" ]] && [[ $(find "$TEMP_FILE" -mmin -0.083 2>/dev/null) ]]; then
        continue
    fi

    # Update timestamp
    touch "$TEMP_FILE"

    log "📝 Change detected in feature worktree"

    # Wait 3 seconds to capture batch changes
    sleep 3

    # Check if there are uncommitted changes
    cd "$FEATURE_WORKTREE"
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        log "💾 Auto-committing changes in feature worktree"

        # Add all changes
        git add .

        # Commit with descriptive message
        COMMIT_MSG="Auto-commit: Claude Code changes detected $(date '+%Y-%m-%d %H:%M:%S')"
        git commit -m "$COMMIT_MSG"

        # Push to remote
        if git push origin feature/"$PROJECT_NAME" 2>/dev/null; then
            log "✅ Changes pushed to remote"
        else
            warn "⚠️  Failed to push to remote (may not have write access)"
        fi

        # Trigger test workflow
        log "🧪 Triggering test workflow"
        cd "$TEST_WORKTREE"

        # Pull latest changes
        if git pull origin feature/"$PROJECT_NAME" 2>/dev/null; then
            log "✅ Latest changes pulled into test worktree"
        else
            warn "⚠️  Failed to pull latest changes"
        fi

        # Detect project type and run appropriate tests
        log "🔍 Detecting project type and running tests"
        TEST_RAN=false

        # Node.js projects
        if [[ -f "package.json" ]]; then
            log "📦 Node.js project detected"
            if npm test 2>> "$LOG_FILE"; then
                log "✅ npm tests passed"
                TEST_RAN=true
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
                    TEST_RAN=true
                else
                    warn "⚠️  pytest tests failed"
                fi
            elif command -v python &> /dev/null; then
                if python -m pytest 2>> "$LOG_FILE"; then
                    log "✅ Python tests passed"
                    TEST_RAN=true
                else
                    warn "⚠️  Python tests failed"
                fi
            fi
        fi

        # Generic test detection
        if [[ "$TEST_RAN" = false ]]; then
            # Look for common test files
            if find . -name "*test*" -type f | grep -q .; then
                log "🔍 Test files found but no specific test runner detected"
                # Try to run any executable test files
                find . -name "*test*" -type f -executable -exec {} \; 2>/dev/null || true
            else
                log "ℹ️  No test files detected, skipping test execution"
            fi
        fi

        # Commit test results if there are any changes
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            log "💾 Committing test results"
            git add .
            git commit -m "Auto-test: Test results for feature changes $(date '+%Y-%m-%d %H:%M:%S')"

            if git push origin test/"$PROJECT_NAME" 2>/dev/null; then
                log "✅ Test results pushed to remote"
            else
                warn "⚠️  Failed to push test results to remote"
            fi
        fi

        log "🎉 Feature → Test workflow completed"
        echo "----------------------------------------" >> "$LOG_FILE"
    fi
done

# Cleanup
rm -f "$TEMP_FILE"