#!/bin/bash
# Single-Session Worktree Setup Script
# Sets up the MCP server and single-session interface

set -e

PROJECT_NAME="${1:-$(basename $(pwd))}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Setting up Single-Session Worktree Orchestration..."
echo "Project: $PROJECT_NAME"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a Git repository. Please run this from your project root."
    exit 1
fi

# Build the MCP server and components
echo "📦 Building MCP server components..."
npm run build

# Create .claude directory structure
echo "📁 Creating Claude Code configuration..."
mkdir -p .claude/{commands,hooks}

# Copy MCP server configuration
echo "🔧 Configuring MCP server..."
cp .claude/mcp-servers.json .claude/

# Create session start hook for single-session mode
cat > .claude/hooks/session-start.js << 'EOF'
#!/usr/bin/env node
// SessionStart Hook - Single-Session Worktree Orchestrator

console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: `🔄 Single-Session Worktree Orchestrator Active

Available Commands:
- /worktree-create-feature "name" - Create feature worktree
- /worktree-create-test "name" - Create test worktree
- /worktree-create-docs "name" - Create docs worktree
- /worktree-create-bugfix "name" - Create bugfix worktree
- /worktree-spawn-agent worktree "task" - Spawn background agent
- /worktree-status - Show worktree and agent status
- /worktree-integrate worktree - Integrate changes to main
- /help - Show all commands

Background Agent System:
- Agents run in tmux sessions for parallel execution
- Signal files (.claude-complete, .tests-complete) trigger workflows
- Automatic coordination between worktrees

Single-Session Architecture:
- No need for multiple Claude Code instances
- Background agents handle parallel work
- Unified command interface for all operations`
  }
}));
EOF

chmod +x .claude/hooks/session-start.js

# Create hooks configuration
cat > .claude/hooks.json << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/hooks/session-start.js"
          }
        ]
      }
    ]
  }
}
EOF

# Create project configuration
cat > .claude/worktree-config.json << EOF
{
  "projectName": "$PROJECT_NAME",
  "mode": "single-session",
  "mcpServer": "worktree-orchestrator",
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "2.0.0"
}
EOF

echo "✅ Single-session setup complete!"
echo ""
echo "🎯 Next Steps:"
echo "1. Start Claude Code: claude"
echo "2. Use commands like: /worktree-create-feature \"my-feature\""
echo "3. Spawn background agents: /worktree-spawn-agent feature \"implement feature\""
echo "4. Monitor progress: /worktree-status"
echo ""
echo "📖 Key Differences from Multi-Session:"
echo "• Single Claude Code session manages everything"
echo "• Background agents handle parallel work in tmux"
echo "• Natural language commands for all operations"
echo "• Automatic workflow coordination via signal files"
echo ""
echo "🔍 For help anytime, use: /help"