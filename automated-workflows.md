# Automated Worktree Workflows

## Current Limitation

The basic worktree setup has **no automatic detection** between worktrees. Each worktree operates independently and requires manual synchronization.

## Automated Solutions

### 1. File System Monitoring (Recommended)

**Monitor Feature Worktree for Changes:**
```bash
# Install inotify-tools (Linux) or fswatch (macOS)
# macOS: brew install fswatch
# Linux: sudo apt-get install inotify-tools

# Create monitor script
cat > monitor-feature.sh << 'EOF'
#!/bin/bash
# Monitor feature worktree for file changes and auto-run tests

FEATURE_WORKTREE="../my-project-worktrees/feature"
TEST_WORKTREE="../my-project-worktrees/test"
LOG_FILE="/tmp/claude-workflow.log"

echo "🔍 Monitoring feature worktree for changes..."
echo "Log: $LOG_FILE"

# Watch for file changes in feature worktree
fswatch -o "$FEATURE_WORKTREE" | while read change; do
    echo "[$(date)] Change detected in feature worktree" >> "$LOG_FILE"

    # Wait 2 seconds to capture batch changes
    sleep 2

    # Check if there are uncommitted changes
    cd "$FEATURE_WORKTREE"
    if [[ -n $(git status --porcelain) ]]; then
        echo "[$(date)] Auto-committing changes in feature worktree" >> "$LOG_FILE"
        git add .
        git commit -m "Auto-commit: Claude Code changes detected $(date)"
        git push origin feature/my-project

        # Trigger test workflow
        echo "[$(date)] Triggering test workflow" >> "$LOG_FILE"
        cd "$TEST_WORKTREE"
        git pull origin feature/my-project

        # Run tests automatically
        if command -v npm &> /dev/null; then
            npm test
        elif command -v pytest &> /dev/null; then
            pytest
        elif command -v python &> /dev/null; then
            python -m pytest
        fi

        # Commit test results
        git add .
        git commit -m "Auto-test: Test results for feature changes $(date)"
        git push origin test/my-project

        echo "[$(date)] Workflow completed" >> "$LOG_FILE"
    fi
done
EOF

chmod +x monitor-feature.sh
```

**Run the Monitor:**
```bash
# Start monitoring in background
./monitor-feature.sh &

# Or run in a dedicated terminal
./monitor-feature.sh
```

### 2. Git Hook Automation

**Post-Commit Hook for Auto-Testing:**
```bash
# Create post-commit hook in .git/hooks/
cat > .git/hooks/post-commit << 'EOF'
#!/bin/bash
# Auto-trigger test workflow when commits are made in feature worktree

CURRENT_BRANCH=$(git branch --show-current)
LOG_FILE="/tmp/claude-git-hooks.log"

# Only trigger for feature branches
if [[ $CURRENT_BRANCH == feature/* ]]; then
    echo "[$(date)] Feature branch commit detected: $CURRENT_BRANCH" >> "$LOG_FILE"

    # Push changes
    git push origin "$CURRENT_BRANCH"

    # Trigger test workflow
    PROJECT_NAME=$(echo "$CURRENT_BRANCH" | cut -d'/' -f2)
    TEST_WORKTREE="../$(basename "$PWD")-worktrees/test"

    if [[ -d "$TEST_WORKTREE" ]]; then
        echo "[$(date)] Triggering test workflow in $TEST_WORKTREE" >> "$LOG_FILE"
        cd "$TEST_WORKTREE"

        # Pull latest changes
        git pull origin "$CURRENT_BRANCH"

        # Run automated tests
        echo "[$(date)] Running automated tests" >> "$LOG_FILE"
        if command -v npm &> /dev/null; then
            npm test 2>&1 | tee -a "$LOG_FILE"
        elif command -v pytest &> /dev/null; then
            pytest 2>&1 | tee -a "$LOG_FILE"
        fi

        # Commit test results
        git add .
        git commit -m "Auto-test: Test results for $CURRENT_BRANCH $(date)"
        git push origin test/"$PROJECT_NAME"

        echo "[$(date)] Test workflow completed" >> "$LOG_FILE"
    fi
fi
EOF

chmod +x .git/hooks/post-commit
```

### 3. Claude Code Integration with Custom Commands

**Auto-Detect Completion Script:**
```bash
# Create auto-detect script
cat > auto-detect-workflow.sh << 'EOF'
#!/bin/bash
# Auto-detect when Claude Code completes work and trigger next steps

PROJECT_NAME="$1"
WORKTREE_BASE="../${PROJECT_NAME}-worktrees"
LOG_FILE="/tmp/claude-auto-detect.log"

echo "🤖 Auto-detect workflow started for $PROJECT_NAME" >> "$LOG_FILE"

# Monitor feature worktree for completion signals
while true; do
    # Check for completion file (Claude Code can create this when done)
    if [[ -f "$WORKTREE_BASE/feature/.claude-complete" ]]; then
        echo "[$(date)] Claude Code completion detected in feature worktree" >> "$LOG_FILE"

        # Remove completion signal
        rm "$WORKTREE_BASE/feature/.claude-complete"

        # Trigger test workflow
        cd "$WORKTREE_BASE/test"
        git pull origin feature/"$PROJECT_NAME"

        echo "[$(date)] Running automated tests" >> "$LOG_FILE"
        if command -v npm &> /dev/null; then
            npm test
        elif command -v pytest &> /dev/null; then
            pytest
        fi

        # Create test completion signal
        touch "$WORKTREE_BASE/test/.tests-complete"

        echo "[$(date)] Test workflow completed" >> "$LOG_FILE"
    fi

    # Check for test completion to trigger documentation
    if [[ -f "$WORKTREE_BASE/test/.tests-complete" ]]; then
        echo "[$(date)] Tests completed, triggering documentation workflow" >> "$LOG_FILE"

        rm "$WORKTREE_BASE/test/.tests-complete"

        cd "$WORKTREE_BASE/docs"
        git pull origin feature/"$PROJECT_NAME"

        # Trigger documentation update
        echo "Documentation update needed" > .docs-needed

        echo "[$(date)] Documentation workflow triggered" >> "$LOG_FILE"
    fi

    sleep 5  # Check every 5 seconds
done
EOF

chmod +x auto-detect-workflow.sh
```

### 4. Claude Code Task Completion Detection

**Add this to your Claude Code workflow:**
```bash
# When Claude Code completes a task, create a completion signal
# In your feature worktree:

# 1. Claude Code finishes coding
touch .claude-complete

# 2. Auto-detect script triggers test workflow
# 3. Tests run automatically
# 4. Test completion triggers documentation workflow
```

### 5. Webhook-Based Automation

**Create a simple webhook server:**
```bash
# webhook-server.py
import os
import subprocess
import http.server
import json
import threading

class WebhookHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/webhook':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)

            try:
                data = json.loads(post_data.decode('utf-8'))
                event_type = data.get('event')

                if event_type == 'claude_complete':
                    # Trigger test workflow
                    subprocess.run(['./trigger-test-workflow.sh'], check=True)
                elif event_type == 'tests_complete':
                    # Trigger documentation workflow
                    subprocess.run(['./trigger-docs-workflow.sh'], check=True)

                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'Webhook received')
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f'Error: {str(e)}'.encode())

def run_webhook_server():
    server = http.server.HTTPServer(('localhost', 8080), WebhookHandler)
    print("Webhook server running on port 8080")
    server.serve_forever()

# Start webhook server in background
threading.Thread(target=run_webhook_server, daemon=True).start()
```

## Real-World Automation Scenarios

### Scenario 1: Feature Development → Testing → Documentation
1. **Feature worktree**: Claude Code completes feature → creates `.claude-complete`
2. **Auto-detection**: Monitor script detects completion → triggers test workflow
3. **Test worktree**: Pulls changes → runs tests → creates `.tests-complete`
4. **Auto-detection**: Detects test completion → triggers documentation workflow
5. **Documentation worktree**: Pulls changes → Claude Code updates documentation

### Scenario 2: Bug Fix → Validation → Merge
1. **Bugfix worktree**: Claude Code fixes bug → creates `.bugfix-complete`
2. **Auto-detection**: Triggers validation workflow
3. **Test worktree**: Pulls bugfix → runs validation tests
4. **Auto-merge**: Tests pass → automatically merges to main branch

## Implementation Steps

1. **Choose your automation method** (file monitoring recommended)
2. **Install dependencies** (fswatch/inotify-tools)
3. **Set up monitoring scripts**
4. **Configure Git hooks** (optional)
5. **Test the workflow**
6. **Deploy to production**

## Monitoring and Logging

All automated workflows create log files:
- `/tmp/claude-workflow.log` - General workflow logs
- `/tmp/claude-git-hooks.log` - Git hook specific logs
- `/tmp/claude-auto-detect.log` - Auto-detection logs

Check these logs to monitor automated workflow execution and debug issues.

This automation transforms the basic worktree setup into a **self-coordinating development system** where Claude Code agents can automatically trigger and respond to each other's work.