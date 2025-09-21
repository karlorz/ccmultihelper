#!/bin/bash
# Single-Session Worktree Setup Script
# Self-contained setup that creates the MCP server components inline

set -e

PROJECT_NAME="${1:-$(basename $(pwd))}"

echo "🚀 Setting up Single-Session Worktree Orchestration..."
echo "Project: $PROJECT_NAME"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a Git repository. Please run this from your project root."
    exit 1
fi

# Create project structure
echo "📁 Creating project structure..."
mkdir -p {src,dist,.claude/{commands,hooks}}

# Get the latest package version from GitHub
echo "📡 Fetching latest version..."
LATEST_VERSION=$(curl -s https://raw.githubusercontent.com/karlorz/ccmultihelper/main/package.json | grep '"version"' | head -1 | sed 's/.*"version": "\(.*\)",/\1/')
if [ -z "$LATEST_VERSION" ]; then
    echo "⚠️  Could not fetch latest version, using fallback version 1.3.0"
    LATEST_VERSION="1.3.0"
else
    echo "✅ Latest version: $LATEST_VERSION"
fi

# Create package.json if it doesn't exist
if [ ! -f "package.json" ]; then
    echo "📦 Creating package.json..."
    cat > package.json << EOF
{
  "name": "$(basename $(pwd))-worktree-orchestrator",
  "version": "$LATEST_VERSION",
  "type": "module",
  "scripts": {
    "build": "bun build src/mcp-server.js --outfile=dist/mcp-server.js --target=node",
    "dev": "node src/mcp-server.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "fs-extra": "^11.3.2",
    "zod": "^4.1.11"
  }
}
EOF
else
    echo "📦 Updating existing package.json with required dependencies..."
    # Check if package.json has type: module, if not add it
    if ! grep -q '"type".*"module"' package.json; then
        # Add type: module after name field
        sed -i.bak 's/"name":\s*"[^"]*",/"name": "'$(basename $(pwd))'-worktree-orchestrator",\n  "type": "module",/' package.json
    fi

    # Install required dependencies if not already present
    if command -v bun >/dev/null 2>&1; then
        echo "Adding required dependencies with bun..."
        bun add @modelcontextprotocol/sdk fs-extra
    else
        echo "Adding required dependencies with npm..."
        npm install @modelcontextprotocol/sdk fs-extra
    fi
fi

# Install dependencies
echo "📦 Installing dependencies..."
if command -v bun >/dev/null 2>&1; then
    echo "Using bun for installation..."
    bun install
else
    echo "Using npm for installation..."
    npm install
fi

# Create MCP server (Download latest version)
echo "🔨 Creating MCP server..."
echo "Downloading latest MCP server from GitHub..."
curl -s https://raw.githubusercontent.com/karlorz/ccmultihelper/main/dist/mcp-server.js > dist/mcp-server.js

# Check if download was successful by looking for valid JavaScript content
if [ ! -s dist/mcp-server.js ] || grep -q "404.*Not Found" dist/mcp-server.js; then
    echo "⚠️  Failed to download MCP server, creating fallback version..."
    # Fallback to embedded version with modern MCP patterns
    cat > src/mcp-server.js << 'EOF'
#!/usr/bin/env node
/**
 * Worktree Orchestrator MCP Server
 * Single-session parallel worktree automation system
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { execSync } from 'child_process';
import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Get package version dynamically
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const packagePath = path.join(__dirname, '..', 'package.json');
const packageJson = fs.readJsonSync(packagePath);
const VERSION = packageJson.version;

class WorktreeOrchestrator {
  constructor() {
    this.agents = new Map();
    this.gitRoot = this.getGitRoot();
    this.projectName = this.detectProjectName();
    this.worktreesDir = path.join(this.gitRoot, '..', `${this.projectName}-worktrees`);
  }

  getGitRoot() {
    try {
      return execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
    } catch (error) {
      throw new Error('Not in a Git repository');
    }
  }

  detectProjectName() {
    const configPath = path.join(this.gitRoot, '.claude', 'worktree-config.json');
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      return config.projectName;
    }
    return path.basename(this.gitRoot);
  }

  async createWorktree(worktreeType, featureName) {
    const branchName = `${worktreeType}/${featureName}`;
    const worktreePath = path.join(this.worktreesDir, worktreeType);

    try {
      await fs.ensureDir(this.worktreesDir);

      if (await fs.pathExists(worktreePath)) {
        try {
          execSync(`git worktree remove ${worktreePath}`, { cwd: this.gitRoot });
        } catch (error) {
          await fs.remove(worktreePath);
        }
      }

      try {
        execSync(`git worktree add -b ${branchName} ${worktreePath}`, {
          cwd: this.gitRoot,
          stdio: 'pipe'
        });
      } catch (error) {
        execSync(`git worktree add ${worktreePath} ${branchName}`, {
          cwd: this.gitRoot,
          stdio: 'pipe'
        });
      }

      const launchScript = `#!/bin/bash
echo "Starting Claude Code in ${worktreeType} environment..."
echo "Feature: ${featureName}"
echo "Branch: ${branchName}"
echo "Path: $(pwd)"
claude
`;
      await fs.writeFile(path.join(worktreePath, 'launch-claude.sh'), launchScript);
      await fs.chmod(path.join(worktreePath, 'launch-claude.sh'), '755');

      return `Created ${worktreeType} worktree for ${featureName} → ${branchName}`;
    } catch (error) {
      throw new Error(`Failed to create worktree: ${error.message}`);
    }
  }

  async spawnBackgroundAgent(worktree, task, command) {
    const agentId = `agent-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const tmuxSession = `claude-${worktree}-${agentId}`;
    const worktreePath = path.join(this.worktreesDir, worktree);

    if (!await fs.pathExists(worktreePath)) {
      throw new Error(`Worktree ${worktree} does not exist`);
    }

    try {
      const tmuxCommand = `tmux new-session -d -s ${tmuxSession} -c ${worktreePath} '${command}'`;
      execSync(tmuxCommand);

      const agent = {
        id: agentId,
        worktree,
        task,
        status: 'running',
        tmuxSession,
        startTime: new Date()
      };

      this.agents.set(agentId, agent);
      return agentId;
    } catch (error) {
      throw new Error(`Failed to spawn background agent: ${error.message}`);
    }
  }

  async getWorktreeStatus() {
    const status = [];
    status.push(`Project: ${this.projectName}`);
    status.push(`Worktrees directory: ${this.worktreesDir}`);
    status.push('');

    try {
      const worktreeList = execSync('git worktree list', {
        cwd: this.gitRoot,
        encoding: 'utf8'
      });
      status.push('Git Worktrees:');
      status.push(worktreeList);
    } catch (error) {
      status.push('No worktrees found');
    }

    const activeAgents = Array.from(this.agents.values()).filter(a => a.status === 'running');
    status.push(`Active background agents: ${activeAgents.length}`);

    for (const agent of activeAgents) {
      status.push(`  - ${agent.id}: ${agent.task} (${agent.worktree})`);
    }

    return status.join('\n');
  }
}

const server = new Server(
  {
    name: 'worktree-orchestrator',
    version: VERSION,
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

const orchestrator = new WorktreeOrchestrator();

const tools = [
  {
    name: 'worktree-create',
    description: 'Create a new worktree for parallel development',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          enum: ['feature', 'test', 'docs', 'bugfix'],
          description: 'Type of worktree to create'
        },
        name: {
          type: 'string',
          description: 'Name/identifier for the worktree branch'
        }
      },
      required: ['type', 'name']
    }
  },
  {
    name: 'worktree-spawn-agent',
    description: 'Spawn a background Claude Code agent in a worktree',
    inputSchema: {
      type: 'object',
      properties: {
        worktree: {
          type: 'string',
          enum: ['feature', 'test', 'docs', 'bugfix'],
          description: 'Target worktree for the agent'
        },
        task: {
          type: 'string',
          description: 'Task description for the agent'
        },
        command: {
          type: 'string',
          description: 'Command to execute in the background agent',
          default: 'claude'
        }
      },
      required: ['worktree', 'task']
    }
  },
  {
    name: 'worktree-status',
    description: 'Get status of all worktrees and background agents',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'worktree-create': {
        const { type, name: worktreName } = args;
        const result = await orchestrator.createWorktree(type, worktreName);
        return {
          content: [{ type: 'text', text: result }]
        };
      }

      case 'worktree-spawn-agent': {
        const { worktree, task, command = 'claude' } = args;
        const agentId = await orchestrator.spawnBackgroundAgent(worktree, task, command);
        return {
          content: [
            {
              type: 'text',
              text: `Background agent spawned: ${agentId}\nWorktree: ${worktree}\nTask: ${task}`
            }
          ]
        };
      }

      case 'worktree-status': {
        const status = await orchestrator.getWorktreeStatus();
        return {
          content: [{ type: 'text', text: status }]
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [{ type: 'text', text: `Error: ${error.message}` }],
      isError: true
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error('MCP Server error:', error);
  process.exit(1);
});
EOF

    # Copy fallback to dist directory
    cp src/mcp-server.js dist/mcp-server.js
else
    echo "✅ Successfully downloaded latest MCP server"
fi

# Prepare distribution files if needed
echo "📦 Preparing distribution files..."

# Register the MCP server with Claude Code CLI
echo "📋 Registering MCP server with Claude Code..."
if command -v claude >/dev/null 2>&1; then
    # Remove existing project-scoped server first
    claude mcp remove worktree-orchestrator -s project 2>/dev/null || true

    # Add as user-scoped server so it appears in claude mcp list
    echo "Adding MCP server to user scope for visibility in claude mcp list..."
    claude mcp add worktree-orchestrator node "$(pwd)/dist/mcp-server.js"

    # Also add as project-scoped for local usage
    echo "Adding MCP server to project scope for immediate use..."
    claude mcp add worktree-orchestrator --scope project node dist/mcp-server.js

    echo "✅ MCP server registered in both user and project scopes"

    # Verify the configuration was created
    if [ -f ".mcp.json" ]; then
        echo "✅ .mcp.json configuration file created"
    else
        echo "⚠️ .mcp.json not created - manual setup may be required"
    fi
else
    echo "⚠️ Claude CLI not found. Creating .mcp.json manually..."
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

Background Agent System:
- Agents run in tmux sessions for parallel execution
- Signal files (.claude-complete, .tests-complete) trigger workflows
- Automatic coordination between worktrees

Single-Session Architecture:
- No need for multiple Claude Code instances
- Background agents handle parallel work
- Unified MCP tool interface for all operations`
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
  "version": "$LATEST_VERSION"
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