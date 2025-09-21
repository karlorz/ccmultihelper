# Claude Code Multi-Worktree Helper

> 🚀 **Single-session parallel worktree automation with MCP server orchestration**

## ✨ What's New in v2.0?

This project has been completely redesigned with a **single-session architecture** that eliminates the complexity of managing multiple Claude Code sessions. Now uses an **MCP server** for background agent orchestration.

### Key Features

- 🎯 **Single-Session Architecture**: One Claude Code session manages everything
- 🤖 **Background Agent System**: Parallel work handled by tmux-based agents
- 🔧 **MCP Server Integration**: Model Context Protocol server for tool orchestration
- 🎨 **Natural Language Commands**: Intuitive slash commands for all operations
- 🔄 **Automatic Workflow Coordination**: Signal files trigger background workflows
- 📦 **Self-Contained Setup**: No external dependencies required

## 🚀 Quick Start

### Prerequisites

Before starting, ensure you have:
- **Node.js 18+** and **bun** (recommended) or **npm** installed
- **Git repository** initialized in your project
- **tmux** installed (`brew install tmux` on macOS, `apt install tmux` on Ubuntu)
- **Claude Code** installed globally

> **Note**: The setup script uses **bun** by default for faster installation and builds, but falls back to npm if bun is not available.

### Option 1: Quick Setup (Existing Project)

```bash
# 1. Navigate to your Git repository
cd /path/to/your/existing/project

# 2. Download and run the standalone setup script
curl -O https://raw.githubusercontent.com/karlorz/ccmultihelper/main/setup-single-session-standalone.sh
chmod +x setup-single-session-standalone.sh
./setup-single-session-standalone.sh

# 3. Start Claude Code with orchestrator
claude
```

### Option 2: Try It First (Demo Project)

```bash
# 1. Clone this repository to try it out
git clone https://github.com/karlorz/ccmultihelper.git
cd ccmultihelper

# 2. Run the standalone setup script
./setup-single-session-standalone.sh demo-project

# 3. Start Claude Code
claude

# 4. Try the demo commands
# /worktree-create "feature" "hello-world"
# /worktree-status
```

### Verify Setup Success

After running the setup script, you should see:

```bash
✅ Single-session setup complete!

🎯 Next Steps:
1. Start Claude Code: claude
2. Use commands like: /worktree-create-feature "my-feature"
3. Spawn background agents: /worktree-spawn-agent feature "implement feature"
4. Monitor progress: /worktree-status
```

If you see this message, the setup was successful!

### What Happens During Setup

The setup script automatically:
- ✅ **Installs dependencies** - Downloads MCP SDK and builds components
- ✅ **Builds MCP server** - Compiles TypeScript to JavaScript
- ✅ **Configures Claude Code** - Sets up hooks and MCP server integration
- ✅ **Creates project config** - Generates worktree configuration
- ✅ **Verifies installation** - Checks all components are working

### First Commands to Try

```bash
# Start Claude Code in your project
claude

# In your Claude Code session, try these commands:
/worktree-create "feature" "user-authentication"    # Create feature worktree
/worktree-spawn-agent "feature" "Build login form"  # Start background work
/worktree-status                                     # Check everything
/help                                               # See all commands
```

### Quick Troubleshooting

**Setup script fails:**
```bash
# Check Node.js version
node --version  # Should be 18+

# Install bun (recommended)
curl -fsSL https://bun.sh/install | bash

# Install dependencies manually
bun install  # or npm install

# Re-run setup
./setup-single-session-standalone.sh
```

**Commands not working in Claude:**
```bash
# Restart Claude Code to pick up new configuration
# Check if MCP server is configured
cat .claude/mcp-servers.json
```

**No worktrees created:**
```bash
# Verify you're in a Git repository
git status

# Check if worktrees exist
git worktree list
```

## 🛠️ Single-Session Commands

### MCP Server Tools (Available via Claude Code)

The orchestrator provides these tools through the MCP server:

#### Worktree Management
- `/worktree-create "feature" "name"` - Create feature worktree with branch
- `/worktree-create "test" "name"` - Create test worktree with branch
- `/worktree-create "docs" "name"` - Create docs worktree with branch
- `/worktree-create "bugfix" "name"` - Create bugfix worktree with branch

#### Background Agent System
- `/worktree-spawn-agent "worktree" "task"` - Launch background Claude agent
- `/worktree-status` - Show all worktrees and active agents

### Legacy CLI Commands (ccmultihelper)

For compatibility, the traditional multi-session CLI is still available:

```bash
# Initialize setup
bunx ccmultihelper init [-p project-name] [-a]

# Setup Claude Code hooks
bunx ccmultihelper setup-hooks

# Create custom slash commands
bunx ccmultihelper create-commands

# Start monitoring service
bunx ccmultihelper start-monitor [-t auto-detect|file-monitor|webhook]

# Clean up everything
bunx ccmultihelper cleanup
```

### Claude Code Slash Commands

Once initialized, you'll have these slash commands available in Claude Code:

#### Worktree Navigation
- `/worktree-feature` - Navigate to feature worktree
- `/worktree-test` - Navigate to test worktree
- `/worktree-docs` - Navigate to docs worktree
- `/worktree-bugfix` - Navigate to bugfix worktree

#### Workflow Management
- `/sync-worktrees` - Synchronize changes between worktrees
- `/status-worktrees` - Show status of all worktrees
- `/monitor-start` - Start worktree monitoring
- `/monitor-stop` - Stop worktree monitoring

## 🤖 Single-Session Architecture

### Traditional vs. New Approach

#### **Old Way (Multi-Session):**
```bash
# Required multiple terminal windows and manual coordination
cd ../my-project-worktrees/feature && claude &
cd ../my-project-worktrees/test && claude &
cd ../my-project-worktrees/docs && claude &
# Manual switching between sessions, complex coordination
```

#### **New Way (Single-Session):**
```bash
# Single Claude Code session manages everything
cd my-project
claude
# Use commands to orchestrate background work
/worktree-create "feature" "user-auth"
/worktree-spawn-agent "feature" "Implement authentication"
/worktree-status
```

### How It Works

#### **MCP Server Orchestration**
- **Background Agents**: Spawn Claude Code agents in tmux sessions
- **Tool Integration**: MCP server provides worktree management tools
- **Agent Lifecycle**: Monitor, coordinate, and manage background work
- **Resource Management**: Efficient allocation of compute resources

#### **Workflow Coordination**
1. **Create Worktrees**: `/worktree-create "feature" "feature-name"`
2. **Spawn Agents**: `/worktree-spawn-agent "feature" "implement feature"`
3. **Monitor Progress**: `/worktree-status`
4. **Signal Completion**: Agents create `.claude-complete` files
5. **Auto-Triggers**: Signal files trigger next workflow steps

### Background Agent System

#### **TMux Session Management**
- Each background agent runs in isolated tmux session
- Agents can execute long-running tasks without blocking main session
- Real-time monitoring of agent status and progress
- Graceful agent termination and cleanup

#### **Signal File Coordination**
- `.claude-complete` - Feature development finished
- `.tests-complete` - Testing phase completed
- `.bugfix-complete` - Bug fix ready for validation
- `.docs-complete` - Documentation updated

#### **Automatic Workflow Chains**
```
Feature Complete → Tests Triggered → Docs Updated → Ready for Review
     ↓                   ↓               ↓              ↓
.claude-complete → .tests-complete → .docs-complete → Integration
```

### Complete Example Workflow

```bash
# 1. Setup (one time)
./setup-single-session-standalone.sh my-project

# 2. Start single Claude Code session
claude

# 3. Create feature worktree and start development
/worktree-create "feature" "user-authentication"
/worktree-spawn-agent "feature" "Implement OAuth login system"

# 4. Monitor progress
/worktree-status
# Output: Shows all worktrees, active agents, signal files

# 5. When feature is complete, agent creates .claude-complete
# This automatically triggers test workflow in the background

# 6. Check final status
/worktree-status
```

## 📁 Project Structure

After running the setup script, your project will have:

```
.your-project/
├── .claude/
│   ├── mcp-servers.json          # MCP server configuration
│   ├── hooks/
│   │   └── session-start.js      # Single-session initialization hook
│   ├── hooks.json                # Hooks configuration
│   └── worktree-config.json      # Project configuration
├── src/
│   ├── mcp-server.ts             # MCP server implementation
│   ├── single-session.ts         # Command interface
│   └── cli.ts                    # Legacy CLI (compatibility)
├── dist/
│   ├── mcp-server.js             # Compiled MCP server
│   ├── single-session.js         # Compiled command interface
│   └── cli.js                    # Compiled legacy CLI
├── ../your-project-worktrees/
│   ├── feature/                  # Feature development
│   │   └── launch-claude.sh      # Quick launch script
│   ├── test/                     # Testing & validation
│   │   └── launch-claude.sh
│   ├── docs/                     # Documentation
│   │   └── launch-claude.sh
│   └── bugfix/                   # Bug fixes
│       └── launch-claude.sh
├── setup-single-session.sh      # Single-session setup script
└── package.json                  # Updated with MCP dependencies
```

## 🔧 Configuration

### MCP Server Configuration

The MCP server is configured in `.claude/mcp-servers.json`:

```json
{
  "mcpServers": {
    "worktree-orchestrator": {
      "command": "node",
      "args": ["dist/mcp-server.js"],
      "env": {}
    }
  }
}
```

### Project Configuration

The system creates `.claude/worktree-config.json`:

```json
{
  "projectName": "your-project",
  "mode": "single-session",
  "mcpServer": "worktree-orchestrator",
  "createdAt": "2024-01-15T10:30:00Z",
  "version": "2.0.0"
}
```

### Hooks Configuration

Claude Code hooks are configured in `.claude/hooks.json`:

```json
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
```

## 🚀 Advanced Usage

### Custom Agent Commands

You can spawn agents with custom commands:

```bash
# Run tests in background
/worktree-spawn-agent test "Run full test suite" "npm test"

# Build documentation
/worktree-spawn-agent docs "Generate API docs" "npm run docs"

# Custom development task
/worktree-spawn-agent feature "Complex refactoring" "echo 'Starting refactor...' && touch .claude-complete"
```

### Agent Lifecycle Management

```bash
# Check all agents
/worktree-agent-status

# Check specific agent
/worktree-agent-status agent-1234567890

# Kill problematic agent
/worktree-kill-agent agent-1234567890

# Create new agent for different task
/worktree-spawn-agent bugfix "Fix authentication bug"
```

### Signal File Workflows

The system automatically processes these signal files:

- **`.claude-complete`** → Triggers test workflow if in feature worktree
- **`.tests-complete`** → Triggers documentation workflow if in test worktree
- **`.bugfix-complete`** → Triggers validation workflow if in bugfix worktree
- **`.docs-complete`** → Marks documentation workflow as complete

### Integration Strategies

```bash
# Direct integration to main
/worktree-integrate feature main

# Integration to development branch
/worktree-integrate feature develop

# Integration with conflict resolution
/worktree-integrate bugfix main
# If conflicts occur, the tool will provide guidance
```

## 📈 Benefits Over Multi-Session Approach

### **Single-Session vs Multi-Session**
- ✅ **Unified Control**: One session manages all parallel work
- ✅ **Resource Efficiency**: Background agents use fewer resources than full Claude sessions
- ✅ **Simplified Management**: No window switching or session coordination
- ✅ **Centralized Monitoring**: View all work from one interface

### **MCP Server vs Manual Coordination**
- ✅ **Automated Workflows**: Signal files trigger background work automatically
- ✅ **Tool Integration**: Native Claude Code tool access through MCP
- ✅ **Background Processing**: Long-running tasks don't block main session
- ✅ **Intelligent Coordination**: Automatic workflow chains and dependencies

### **vs Traditional Git Worktrees**
- ✅ **Claude Code Integration**: Purpose-built for Claude Code workflows
- ✅ **Smart Branching**: Automatic branch creation and management
- ✅ **Parallel Development**: Multiple workstreams without conflicts
- ✅ **Easy Integration**: Simple merge commands with conflict detection

## 🧹 Troubleshooting

### Common Issues

**MCP Server not starting:**
```bash
# Check if dependencies are installed
npm install

# Verify build completed
npm run build

# Check MCP server configuration
cat .claude/mcp-servers.json
```

**Commands not working:**
```bash
# Restart Claude Code to pick up MCP server
# Check if hooks are properly configured
cat .claude/hooks.json

# Verify setup script completed successfully
./setup-single-session.sh
```

**Background agents not spawning:**
```bash
# Check if tmux is installed
tmux --version

# Verify worktrees exist
/worktree-status

# Check agent status
/worktree-agent-status
```

**Worktree integration issues:**
```bash
# Check worktree status
git worktree list

# Verify branch status
git status

# Use detailed status command
/worktree-status
```

### Debug Mode

Enable debug logging:

```bash
# Check MCP server logs (when running in development)
npm run dev:mcp

# Check Claude Code debug output
claude --debug

# Monitor tmux sessions
tmux list-sessions

# Check agent sessions directly
tmux attach -t claude-feature-agent-123456789
```

## 🎯 Roadmap

### v2.1 - Enhanced Agent Management
- [ ] Agent persistence across Claude Code restarts
- [ ] Agent output streaming to main session
- [ ] Custom agent templates and presets
- [ ] Agent resource usage monitoring

### v2.2 - Workflow Extensions
- [ ] Visual workflow designer
- [ ] Custom signal file processors
- [ ] Integration with external CI/CD systems
- [ ] Team collaboration features

### v2.3 - Developer Experience
- [ ] VS Code extension integration
- [ ] Web dashboard for monitoring
- [ ] Advanced debugging tools
- [ ] Performance analytics

## 🤝 Contributing

Contributions are welcome! This project uses:
- **TypeScript** for type safety
- **MCP SDK** for tool integration
- **Bun** for fast builds and testing
- **TMux** for background session management

### Development Setup

```bash
# Clone the repository
git clone <repository-url>
cd multi-worktree-setup

# Install dependencies
npm install

# Run in development mode
npm run dev:mcp      # MCP server
npm run dev:session  # Command interface
npm run dev          # Legacy CLI

# Build for production
npm run build
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Powered by [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- Inspired by Git worktree workflows and parallel development patterns
- Enhanced with tmux session management and background agent orchestration

---

**🚀 Built for the Claude Code community - From multi-session complexity to single-session simplicity**