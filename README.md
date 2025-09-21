# Claude Code Multi-Worktree Helper

> 🚀 **Single-session parallel worktree automation with MCP server orchestration**

## ✨ Features

- 🎯 **Single-Session Architecture**: One Claude Code session manages everything
- 🤖 **Background Agent System**: Parallel work via tmux-based agents
- 🔧 **Modern MCP Server**: TypeScript SDK with Zod validation
- 🎨 **Natural Language Interface**: Intuitive MCP tool commands
- 📦 **Self-Contained Setup**: Zero dependencies beyond Node.js and tmux

## 🚀 Quick Start

### Prerequisites
- Node.js 18+, Git repository, tmux, Claude Code

### Setup (Choose One)

**Option 1: One-Command (Recommended)**
```bash
cd /path/to/your/project
bunx ccmultihelper init
claude
```

**Option 2: Install Globally**
```bash
npm install -g ccmultihelper
cd /path/to/your/project
ccmultihelper init
claude
```

**Option 3: MCP Server Only**
```bash
# Register as MCP server (no installation needed)
claude mcp add worktree-orchestrator --scope project npx -y ccmultihelper
```

## 📖 Usage

### Modern Single-Session (Default)
Use natural language in Claude Code:
- "Create a feature worktree called user-auth"
- "Spawn an agent in feature worktree to implement login"
- "Show me the status of all worktrees"
- "Kill the agent that's stuck"

### Available MCP Tools
- **worktree-create** - Create/manage worktrees
- **worktree-spawn-agent** - Launch background agents
- **worktree-status** - View comprehensive status
- **worktree-agent-status** - Monitor agent lifecycle
- **worktree-agent-logs** - Stream real-time output
- **worktree-agent-progress** - Track file changes
- **worktree-kill-agent** - Terminate agents
- **worktree-integrate** - Merge branch changes

## ⚙️ CLI Commands

### Modern Single-Session (Default)
```bash
bunx ccmultihelper init           # Initialize modern setup
ccmultihelper init                # Same (if installed globally)
```

### Legacy Multi-Session Mode
```bash
bunx ccmultihelper init --legacy  # Legacy multi-session setup
ccmultihelper setup-hooks         # Setup hooks (legacy)
ccmultihelper cleanup             # Clean up everything
```

## 🔧 MCP Server Registration

### Direct Registration (Recommended)
```bash
# Using npx (downloads latest)
claude mcp add worktree-orchestrator --scope project npx -y ccmultihelper

# Using bunx
claude mcp add worktree-orchestrator --scope project bunx -y ccmultihelper

# Verify
claude mcp get worktree-orchestrator
```

### Alternative Methods
```bash
# Local installation
claude mcp add worktree-orchestrator --scope project node dist/mcp-server.js

# Custom environment
claude mcp add worktree-orchestrator --scope project sh -c "MCP_SERVER_MODE=true node $(npm root -g)/ccmultihelper/dist/cli.js"
```

## 🏗️ Architecture

### Single-Session Workflow
```
Claude Code Session
    ↓
MCP Server (worktree-orchestrator)
    ↓
Background Agents (tmux sessions)
    ↓
Git Worktrees (feature/, test/, docs/, bugfix/)
```

### Worktree Structure
- **feature/** - New feature development
- **test/** - Testing and validation
- **docs/** - Documentation updates
- **bugfix/** - Bug fixes

## 🔄 Workflow Examples

### Feature Development
```bash
# In Claude Code
"Create a feature worktree called user-auth"
"Spawn an agent to implement OAuth login in the feature worktree"
"Show me the progress of the authentication agent"
"When done, integrate the feature branch into main"
```

### Parallel Testing
```bash
"Spawn an agent in test worktree to run unit tests"
"Create a bugfix worktree for issue #123"
"Monitor all active agents"
```

## 🛠️ Development

```bash
git clone https://github.com/karlorz/ccmultihelper.git
cd ccmultihelper
bun install
bun run build
bun run test
```

### Local Testing
```bash
# Test MCP server
echo '{}' | node dist/cli.js

# Test CLI
node dist/cli.js --version
```

## 📝 Configuration

Setup creates `.claude/worktree-config.json`:
```json
{
  "projectName": "my-project",
  "version": "1.6.0",
  "createdAt": "2025-01-21T...",
  "mcpServer": {
    "name": "worktree-orchestrator",
    "command": "node",
    "args": ["dist/mcp-server.js"]
  }
}
```

## 🔍 Troubleshooting

**MCP Server Not Found**
```bash
bun run build  # Rebuild components
claude mcp list # Check registered servers
```

**Agent Issues**
```bash
tmux list-sessions  # View tmux sessions
ccmultihelper cleanup # Clean up everything
```

**Git Worktree Issues**
```bash
git worktree list   # List all worktrees
git worktree prune  # Clean stale worktrees
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

## 🔗 Links

- [GitHub Repository](https://github.com/karlorz/ccmultihelper)
- [npm Package](https://www.npmjs.com/package/ccmultihelper)
- [Issues](https://github.com/karlorz/ccmultihelper/issues)