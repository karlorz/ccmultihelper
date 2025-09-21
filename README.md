# Claude Code Multi-Worktree Helper

> 🚀 **Single-session parallel worktree automation with modern MCP server orchestration**

## ✨ What's New in v1.4+?

This project has been completely **refactored to follow official MCP guidelines** using the latest TypeScript SDK patterns. The **single-session architecture** eliminates the complexity of managing multiple Claude Code sessions with a modern **MCP server** for background agent orchestration.

### Key Features

- 🎯 **Single-Session Architecture**: One Claude Code session manages everything
- 🤖 **Background Agent System**: Parallel work handled by tmux-based agents
- 🔧 **Modern MCP Server**: Built with latest TypeScript SDK and Zod validation
- 🎨 **Natural Language Interface**: Intuitive commands through MCP tool integration
- 🔄 **Automatic Workflow Coordination**: Signal files trigger background workflows
- 📦 **Self-Contained Setup**: Zero external dependencies beyond Node.js and tmux
- ⚡ **Official MCP Patterns**: Follows Model Context Protocol best practices

## 🚀 Quick Start

### Prerequisites

Before starting, ensure you have:
- **Node.js 18+** installed
- **Git repository** initialized in your project
- **tmux** installed (`brew install tmux` on macOS, `apt install tmux` on Ubuntu)
- **Claude Code** installed globally

### Option 1: One-Command Setup (Recommended)

```bash
# 1. Navigate to your Git repository
cd /path/to/your/existing/project

# 2. Run single-session setup with bunx (no installation needed)
bunx ccmultihelper init

# 3. Start Claude Code with orchestrator
claude
```

### Option 2: Install and Use

```bash
# 1. Install globally
npm install -g ccmultihelper

# 2. Navigate to your Git repository
cd /path/to/your/existing/project

# 3. Initialize single-session setup
ccmultihelper init

# 4. Start Claude Code
claude
```

### Option 3: Standalone Script (Advanced)

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

### Option 4: Try It First (Demo Project)

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

# Verify MCP server is registered
claude mcp get worktree-orchestrator
# (should show server details)

# In your Claude Code session, use natural language:
"Create a feature worktree called user-authentication"
"Spawn an agent in the feature worktree to build login form"
"Show me the status of all worktrees"
```

> **Note**: Project-scoped MCP servers don't appear in `claude mcp list` but can be verified with `claude mcp get <name>`.

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

### MCP Server Tools (Natural Language Interface)

The refactored orchestrator provides these tools through the modern MCP server. Use natural language to access them:

#### Worktree Management
- **Create Worktree** - Create worktrees (feature/test/docs/bugfix)
  - *Usage*: "Create a feature worktree called user-auth"
  - *Usage*: "Set up a test worktree for integration testing"

#### Background Agent System
- **Spawn Agent** - Launch background Claude agents
  - *Usage*: "Spawn an agent in the feature worktree to implement login"
  - *Usage*: "Start a background agent to run tests"

#### Status and Monitoring
- **Worktree Status** - Show comprehensive worktree and agent status
  - *Usage*: "Show me the status of all worktrees"
  - *Usage*: "What agents are currently running?"

- **Agent Status** - Get detailed agent information
  - *Usage*: "Get status of all background agents"
  - *Usage*: "Check the status of agent-123456789"

- **Agent Logs** - Stream real-time agent output
  - *Usage*: "Show me the logs from the running agent"
  - *Usage*: "Get the last 50 lines from agent-123456789"

- **Worktree Progress** - Monitor worktree file changes
  - *Usage*: "Monitor progress in the feature worktree"
  - *Usage*: "Check what changes are happening in the test worktree"

#### Agent Lifecycle Management
- **Kill Agent** - Terminate background agents
  - *Usage*: "Kill the agent that's stuck"
  - *Usage*: "Terminate agent-123456789"

- **Integrate Changes** - Merge worktree changes
  - *Usage*: "Integrate feature changes into main branch"
  - *Usage*: "Merge the bugfix worktree into develop"

> **Note**: You don't need to use the technical tool names directly. Claude Code will automatically map your natural language requests to the appropriate MCP tools.

### CLI Commands (ccmultihelper)

> **Recommendation**: Use the modern single-session approach for new projects. The legacy multi-session mode is maintained for compatibility.

The package provides both modern single-session and legacy multi-session approaches:

#### Modern Single-Session (Default)
```bash
# Initialize single-session setup (default behavior)
bunx ccmultihelper init [-p project-name]

# Or install and use
npm install -g ccmultihelper
ccmultihelper init [-p project-name]
```

#### Legacy Multi-Session Mode
```bash
# Initialize legacy multi-session setup
bunx ccmultihelper init --legacy [-p project-name] [-a]

# Setup Claude Code hooks (legacy)
bunx ccmultihelper setup-hooks

# Create custom slash commands (legacy)
bunx ccmultihelper create-commands

# Start monitoring service (legacy)
bunx ccmultihelper start-monitor [-t auto-detect|file-monitor|webhook]

# Clean up everything
bunx ccmultihelper cleanup
```

### Claude Code Slash Commands (Legacy Multi-Session)

**Note**: These slash commands are for the legacy multi-session approach. For the new single-session architecture, use natural language with MCP tools instead.

Once initialized with the legacy CLI, you'll have these slash commands available:

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

> **Migration Note**: Consider migrating to the single-session architecture for better performance and monitoring capabilities. The new MCP-based system provides real-time agent monitoring, progress tracking, and simplified workflow management.

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
# Use natural language to orchestrate background work
"Create a feature worktree called user-auth"
"Spawn an agent in the feature worktree to implement authentication"
"Show me the status of all worktrees"
```

### How It Works

#### **MCP Server Architecture**
- **Modern TypeScript SDK**: Built with latest `@modelcontextprotocol/sdk` v1.18.1+
- **Zod Validation**: Type-safe input schemas with descriptive error messages
- **Background Agents**: Spawn Claude Code agents in isolated tmux sessions
- **Tool Integration**: 8 comprehensive tools for complete worktree lifecycle management
- **Agent Lifecycle**: Monitor, coordinate, and manage background work efficiently
- **Resource Management**: Efficient allocation and cleanup of compute resources

#### **Workflow Coordination**
1. **Create Worktrees**: "Create a feature worktree called feature-name"
2. **Spawn Agents**: "Spawn an agent in the feature worktree to implement feature"
3. **Monitor Progress**: "Show me the status of all worktrees"
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

# 3. Verify MCP server is registered
claude mcp get worktree-orchestrator
# Should show server configuration details

# 4. Create feature worktree and start development
"Create a feature worktree called user-authentication"
"Spawn an agent in the feature worktree to implement OAuth login system"

# 5. Monitor progress
"Show me the status of all worktrees"
# Output: Shows all worktrees, active agents, signal files

# 6. When feature is complete, agent creates .claude-complete
# This automatically triggers test workflow in the background

# 7. Check final status
"What's the current status of all my worktrees and agents?"
```

## 📁 Project Structure

After running the setup script, your project will have:

```
.your-project/
├── .claude/
│   ├── hooks/
│   │   └── session-start.js      # Single-session initialization hook
│   ├── hooks.json                # Hooks configuration
│   └── worktree-config.json      # Project configuration
├── .mcp.json                     # MCP server configuration (project root)
├── src/
│   └── mcp-server.ts             # Modern MCP server implementation
├── dist/
│   └── mcp-server.js             # Compiled MCP server with Zod schemas
├── ../your-project-worktrees/
│   ├── feature/                  # Feature development
│   │   └── launch-claude.sh      # Quick launch script
│   ├── test/                     # Testing & validation
│   │   └── launch-claude.sh
│   ├── docs/                     # Documentation
│   │   └── launch-claude.sh
│   └── bugfix/                   # Bug fixes
│       └── launch-claude.sh
├── setup-single-session-standalone.sh  # Single-session setup script
├── package.json                  # Node.js dependencies
└── node_modules/                 # Installed dependencies
```

## 🔧 Configuration

### MCP Server Configuration

The MCP server is configured in `.mcp.json` at the project root:

```json
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
```

You can verify the server is registered with:
```bash
claude mcp get worktree-orchestrator
# Should show server configuration details
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

You can spawn agents with custom commands using natural language:

```bash
# Examples with natural language
"Spawn an agent in the test worktree to run the full test suite with command 'npm test'"
"Start a background agent in docs worktree to generate API documentation using 'npm run docs'"
"Create an agent in feature worktree to run complex refactoring with command 'echo Starting refactor && touch .claude-complete'"
```

### Agent Lifecycle Management

Use natural language for agent management:

```bash
# Check all agents
"Show me the status of all background agents"
"What agents are currently running?"

# Check specific agent
"Get detailed status for agent-1234567890"
"Show me information about the running agent"

# Monitor agent output
"Get logs from agent-1234567890"
"Show me the last 30 lines of output from the active agent"

# Monitor worktree progress
"Monitor progress in the feature worktree"
"Check what changes are happening in the test worktree"

# Kill problematic agent
"Kill agent-1234567890"
"Terminate the stuck background agent"

# Create new agent for different task
"Spawn an agent in bugfix worktree to fix authentication bug"
```

### Signal File Workflows

The system automatically processes these signal files:

- **`.claude-complete`** → Triggers test workflow if in feature worktree
- **`.tests-complete`** → Triggers documentation workflow if in test worktree
- **`.bugfix-complete`** → Triggers validation workflow if in bugfix worktree
- **`.docs-complete`** → Marks documentation workflow as complete

### Integration Strategies

Use natural language for worktree integration:

```bash
# Direct integration to main
"Integrate feature worktree changes into main branch"
"Merge the feature worktree into main"

# Integration to development branch
"Integrate feature worktree into develop branch"
"Merge bugfix changes into development"

# Integration with conflict resolution
"Integrate bugfix worktree into main branch"
# If conflicts occur, the tool will provide guidance
```

## 📈 Benefits Over Multi-Session Approach

### **Single-Session vs Multi-Session**
- ✅ **Unified Control**: One session manages all parallel work
- ✅ **Resource Efficiency**: Background agents use fewer resources than full Claude sessions
- ✅ **Simplified Management**: No window switching or session coordination
- ✅ **Centralized Monitoring**: View all work from one interface

### **MCP Server vs Manual Coordination**
- ✅ **Modern TypeScript SDK**: Built with latest official MCP patterns and Zod validation
- ✅ **Type-Safe Schemas**: Input validation with descriptive error messages
- ✅ **Automated Workflows**: Signal files trigger background work automatically
- ✅ **Tool Integration**: Native Claude Code tool access through MCP protocol
- ✅ **Background Processing**: Long-running tasks don't block main session
- ✅ **Intelligent Coordination**: Automatic workflow chains and dependencies
- ✅ **Real-time Monitoring**: Stream agent output and track progress in real-time
- ✅ **Agent Lifecycle Management**: Complete control over background agent operations

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
"Show me the status of all worktrees"

# Check agent status
"What agents are currently running?"
```

**Worktree integration issues:**
```bash
# Check worktree status
git worktree list

# Verify branch status
git status

# Use detailed status command
"Show me comprehensive worktree status"
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
- ✅ **Agent output streaming to main session** - Real-time tmux output capture
- ✅ **Agent resource usage monitoring** - Runtime tracking and session management
- [ ] Agent persistence across Claude Code restarts
- [ ] Custom agent templates and presets

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
- **Modern MCP SDK** for tool integration following official patterns
- **Zod** for runtime type validation and input schemas
- **Bun** for fast builds and testing
- **TMux** for background session management

### Development Setup

```bash
# Clone the repository
git clone <repository-url>
cd multi-worktree-setup

# Install dependencies
bun install

# Run in development mode
bun run dev:mcp      # MCP server
bun run dev:session  # Command interface
bun run dev          # Legacy CLI

# Build for production
bun run build

# Run tests
bun run test
```

### MCP Development Guidelines

This project follows the official Model Context Protocol patterns:
- Uses `McpServer` class instead of low-level `Server`
- Implements Zod schemas for type-safe validation
- Follows official SDK examples and patterns
- Maintains compatibility with latest MCP specification

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Powered by [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- Inspired by Git worktree workflows and parallel development patterns
- Enhanced with tmux session management and background agent orchestration

---

**🚀 Built for the Claude Code community - From multi-session complexity to single-session simplicity**