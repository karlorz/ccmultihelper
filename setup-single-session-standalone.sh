#!/bin/bash

# Single-Session Worktree Orchestration Setup Script
# Modern MCP-based approach for Claude Code

set -e

PROJECT_NAME="$1"

echo "🚀 Setting up Single-Session Worktree Orchestration..."
echo "Project: ${PROJECT_NAME}"
echo ""

# Check if we're in a Git repository
if [ ! -d .git ]; then
    echo "❌ Error: Not a Git repository. Please run this from your project root."
    exit 1
fi

echo "📁 Creating project structure..."
mkdir -p src dist .claude/commands .claude/hooks

# Get latest version from GitHub
echo "📡 Fetching latest version..."
LATEST_VERSION=$(curl -s https://raw.githubusercontent.com/karlorz/ccmultihelper/main/package.json | grep '"version"' | head -1 | sed 's/.*"version": "\(.*\)",/\1/')

if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="1.7.2"
fi

echo "✅ Latest version: $LATEST_VERSION"

# Update package.json with required dependencies
if [ ! -f package.json ]; then
    echo "📦 Creating package.json..."
    cat > package.json << EOF
{
  "name": "${PROJECT_NAME}-worktree-orchestrator",
  "type": "module",
  "version": "1.0.0",
  "description": "Worktree orchestration for ${PROJECT_NAME}",
  "main": "dist/mcp-server.js",
  "scripts": {
    "start": "node dist/mcp-server.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.18.1",
    "fs-extra": "^11.3.2"
  }
}
EOF
else
    echo "📦 Updating existing package.json with required dependencies..."
    # Ensure package.json has ES modules enabled
    if ! grep -q '"type".*"module"' package.json; then
        # Get current project name from package.json or use provided name
        CURRENT_NAME=$(grep -o '"name":\s*"[^"]*"' package.json | sed 's/"name":\s*"\([^"]*\)"/\1/' || echo "${PROJECT_NAME}")
        sed -i.bak 's/"name":\s*"[^"]*",/"name": "'${PROJECT_NAME}'-worktree-orchestrator",\n  "type": "module",/' package.json
    fi
fi

# Install dependencies
if command -v bun >/dev/null 2>&1; then
    echo "Adding required dependencies with bun..."
    bun add @modelcontextprotocol/sdk fs-extra
    echo "📦 Installing dependencies..."
    echo "Using bun for installation..."
    bun install
else
    echo "Adding required dependencies with npm..."
    npm install @modelcontextprotocol/sdk fs-extra
    echo "📦 Installing dependencies..."
    echo "Using npm for installation..."
    npm install
fi

# Extract MCP server from npm package
echo "🔨 Creating MCP server..."
echo "Extracting MCP server from published package..."

if command -v bunx >/dev/null 2>&1; then
    # Install package globally and copy the MCP server
    npm install -g ccmultihelper@latest
    NPM_PKG_PATH=$(npm root -g)/ccmultihelper
    if [ -f "$NPM_PKG_PATH/dist/mcp-server.js" ]; then
        cp "$NPM_PKG_PATH/dist/mcp-server.js" dist/
        echo "✅ Successfully extracted MCP server from package"
    else
        echo "❌ Could not extract MCP server, setup incomplete"
        exit 1
    fi
elif command -v npx >/dev/null 2>&1; then
    # Fallback to npx
    npm install -g ccmultihelper@latest
    NPM_PKG_PATH=$(npm root -g)/ccmultihelper
    if [ -f "$NPM_PKG_PATH/dist/mcp-server.js" ]; then
        cp "$NPM_PKG_PATH/dist/mcp-server.js" dist/
        echo "✅ Successfully extracted MCP server from package"
    else
        echo "❌ Could not extract MCP server, setup incomplete"
        exit 1
    fi
else
    echo "❌ Neither bunx nor npx available, cannot setup MCP server"
    exit 1
fi

echo "📦 Preparing distribution files..."

# Register the MCP server with Claude Code CLI
echo "📋 Registering MCP server with Claude Code..."
if command -v claude >/dev/null 2>&1; then
    # Remove any existing worktree-orchestrator entries first
    echo "Cleaning up any existing MCP server entries..."
    claude mcp remove worktree-orchestrator -s project 2>/dev/null || true
    claude mcp remove worktree-orchestrator 2>/dev/null || true

    # Add as user-scoped server so it appears in claude mcp list
    echo "Adding MCP server to user scope for visibility in claude mcp list..."
    if claude mcp add worktree-orchestrator node "$(pwd)/dist/mcp-server.js"; then
        echo "✅ Successfully added to user scope"
    else
        echo "⚠️ Failed to add to user scope, but continuing..."
    fi

    # Also add as project-scoped for local usage
    echo "Adding MCP server to project scope for immediate use..."
    if claude mcp add worktree-orchestrator --scope project node dist/mcp-server.js; then
        echo "✅ Successfully added to project scope"
    else
        echo "⚠️ Failed to add to project scope, but continuing..."
    fi

    echo "✅ MCP server registration completed"

    # Verify the configuration was created
    if [ -f ".mcp.json" ]; then
        echo "✅ .mcp.json configuration file created"
    else
        echo "⚠️ .mcp.json not created - manual setup may be required"
    fi
else
    echo "⚠️ Claude Code CLI not found - creating manual .mcp.json configuration"

    # Create manual MCP configuration
    cat > .mcp.json << 'EOF'
{
  "mcpServers": {
    "worktree-orchestrator": {
      "type": "stdio",
      "command": "node",
      "args": ["dist/mcp-server.js"],
      "env": {}
    }
  }
}
EOF
    echo "📋 Manual .mcp.json created - you may need to register with: claude mcp add worktree-orchestrator --scope project node dist/mcp-server.js"
fi

# Create session start hook
cat > .claude/hooks/session-start.js << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: `🔄 Single-Session Worktree Orchestrator Active

Available MCP Tools:
- mcp__worktree-orchestrator__worktree-create - Create worktrees (feature/test/docs/bugfix)
- mcp__worktree-orchestrator__worktree-spawn-agent - Spawn background agents
- mcp__worktree-orchestrator__worktree-status - Show worktree and agent status

Usage Examples:
Use the Claude Code tool calling interface to access these MCP tools:
• "Create a feature worktree called user-auth"
• "Spawn an agent in the feature worktree to implement login"
• "Show me the status of all worktrees"

Background agents run in tmux sessions for parallel development.`
  }
}));
EOF

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
  "projectName": "${PROJECT_NAME}",
  "version": "${LATEST_VERSION}",
  "createdAt": "$(date -Iseconds)",
  "mcpServer": {
    "name": "worktree-orchestrator",
    "command": "node",
    "args": ["dist/mcp-server.js"]
  }
}
EOF

echo "✅ Single-session setup complete!"
echo ""
echo "🎯 Next Steps:"
echo "1. Restart Claude Code: claude"
echo "   (Important: Restart to pick up the new MCP server)"
echo "2. Use natural language to access MCP tools:"
echo "   • 'Create a feature worktree called my-feature'"
echo "   • 'Spawn an agent in the feature worktree to implement feature'"
echo "   • 'Show me the status of all worktrees'"
echo ""
echo "📖 Key Features:"
echo "• Single Claude Code session manages everything"
echo "• Background agents handle parallel work in tmux"
echo "• MCP server provides native tool integration"
echo "• Natural language interface - no slash commands needed"
echo ""
echo "🔧 Verify MCP Setup:"
echo "   claude mcp get worktree-orchestrator"
echo "   (should show Status: ✓ Connected)"
echo ""
echo "📋 Note: Project-scoped servers won't appear in 'claude mcp list'"
echo "   but can be accessed via 'claude mcp get <name>'"
echo ""
echo "⚠️  If MCP server shows 'Failed to connect':"
echo "   1. Make sure all dependencies are installed: bun install"
echo "   2. Check Node.js module type: package.json should have '\"type\": \"module\"'"
echo "   3. Re-register the server: claude mcp remove worktree-orchestrator -s project"
echo "      then: claude mcp add worktree-orchestrator --scope project node dist/mcp-server.js"
echo ""
echo "🚨 Important: Make sure you have tmux installed for background agents:"
echo "   macOS: brew install tmux"
echo "   Ubuntu: sudo apt install tmux"