#!/bin/bash
# Single-Session Worktree Setup Script
# Sets up the MCP server and single-session interface

set -e

PROJECT_NAME="${1:-$(basename $(pwd))}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_PROJECT_DIR="$(pwd)"

echo "🚀 Setting up Single-Session Worktree Orchestration..."
echo "Project: $PROJECT_NAME"
echo "Script location: $SCRIPT_DIR"
echo "User project: $USER_PROJECT_DIR"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a Git repository. Please run this from your project root."
    exit 1
fi

# Check if we need to download and setup the MCP components
if [ ! -f "$USER_PROJECT_DIR/package.json" ] || ! grep -q "ccmultihelper" "$USER_PROJECT_DIR/package.json" 2>/dev/null; then
    echo "📦 Setting up ccmultihelper components..."

    # Download ccmultihelper via npm/bun
    if command -v bun >/dev/null 2>&1; then
        echo "📥 Installing ccmultihelper package with bun..."
        bun add ccmultihelper@latest
    else
        echo "📥 Installing ccmultihelper package with npm..."
        npm install ccmultihelper@latest
    fi

    echo "✅ Installed ccmultihelper components"
else
    echo "📦 Found existing ccmultihelper components"
fi

# Ensure we have the required dependencies
echo "📦 Installing dependencies..."
if [ ! -d "node_modules" ] || [ ! -f "node_modules/@modelcontextprotocol/sdk/package.json" ]; then
    # Use bun by default, fallback to npm
    if command -v bun >/dev/null 2>&1; then
        echo "Using bun for dependency installation..."
        bun install
    else
        echo "Using npm for dependency installation..."
        npm install
    fi
fi

# Check if we have source files or need to use npm package files
if [ -f "src/mcp-server.ts" ]; then
    echo "🔨 Building MCP server components from source..."

    # Use bun by default, fallback to npm/npx
    if command -v bun >/dev/null 2>&1; then
        echo "Using bun for building..."
        bun run build 2>/dev/null || {
            echo "⚠️ Build script not found, building manually with bun..."
            mkdir -p dist
            bun build src/mcp-server.ts --outfile=dist/mcp-server.js --target=node
            bun build src/single-session.ts --outfile=dist/single-session.js --target=node
            bun build src/cli.ts --outfile=dist/cli.js --target=node
        }
    else
        echo "Building with npm/npx (bun not available)..."
        npm run build 2>/dev/null || {
            echo "⚠️ Build script not found, building manually..."
            mkdir -p dist

            # Use npx tsc if available, or create simplified JS versions
            if command -v npx >/dev/null 2>&1 && npx tsc --version >/dev/null 2>&1; then
                npx tsc src/mcp-server.ts --outDir dist --target es2020 --module commonjs
                npx tsc src/single-session.ts --outDir dist --target es2020 --module commonjs
                npx tsc src/cli.ts --outDir dist --target es2020 --module commonjs
            else
                echo "⚠️ TypeScript not available, copying source files..."
                cp src/mcp-server.ts dist/mcp-server.js
                cp src/single-session.ts dist/single-session.js
                cp src/cli.ts dist/cli.js
            fi
        }
    fi
    echo "✅ Built MCP server components"
elif [ -f "node_modules/ccmultihelper/dist/mcp-server.js" ]; then
    echo "📦 Using pre-built components from ccmultihelper package..."
    mkdir -p dist
    cp node_modules/ccmultihelper/dist/* dist/ 2>/dev/null || true
    echo "✅ Copied pre-built MCP server components"
else
    echo "❌ No MCP server components found. Please ensure ccmultihelper is installed correctly."
    exit 1
fi

# Create .claude directory structure
echo "📁 Creating Claude Code configuration..."
mkdir -p .claude/{commands,hooks}

# Create MCP server configuration
echo "🔧 Configuring MCP server..."
cat > .claude/mcp-servers.json << 'EOF'
{
  "mcpServers": {
    "worktree-orchestrator": {
      "command": "node",
      "args": ["dist/mcp-server.js"],
      "env": {}
    }
  }
}
EOF

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
echo ""
echo "🚨 Important: Make sure you have tmux installed for background agents:"
echo "   macOS: brew install tmux"
echo "   Ubuntu: sudo apt install tmux"