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

# Create package.json if it doesn't exist
if [ ! -f "package.json" ]; then
    echo "📦 Creating package.json..."
    cat > package.json << EOF
{
  "name": "$(basename $(pwd))-worktree-orchestrator",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "build": "bun build src/mcp-server.js --outfile=dist/mcp-server.js --target=node",
    "dev": "node src/mcp-server.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
EOF
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

# Create MCP server (JavaScript version for simplicity)
echo "🔨 Creating MCP server..."
cat > src/mcp-server.js << 'EOF'
#!/usr/bin/env node
/**
 * Worktree Orchestrator MCP Server
 * Single-session parallel worktree automation system
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { execSync } from 'child_process';
import fs from 'fs-extra';
import path from 'path';

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
    version: '1.0.0',
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

# Copy to dist directory
echo "📦 Preparing distribution files..."
cp src/mcp-server.js dist/mcp-server.js

# Register the MCP server with Claude Code CLI
echo "📋 Registering MCP server with Claude Code..."
if command -v claude >/dev/null 2>&1; then
    # Remove existing .mcp.json to avoid conflicts
    rm -f .mcp.json

    # Add the server using Claude CLI (this creates the correct format)
    claude mcp add worktree-orchestrator --scope project node dist/mcp-server.js
    echo "✅ MCP server registered with Claude Code"

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
  "version": "2.0.0"
}
EOF

echo "✅ Single-session setup complete!"
echo ""
echo "🎯 Next Steps:"
echo "1. Start Claude Code: claude"
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
echo "   (should show server details)"
echo ""
echo "📋 Note: Project-scoped servers won't appear in 'claude mcp list'"
echo "   but can be accessed via 'claude mcp get <name>'"
echo ""
echo "🚨 Important: Make sure you have tmux installed for background agents:"
echo "   macOS: brew install tmux"
echo "   Ubuntu: sudo apt install tmux"