# MCP Development Guide

This document outlines the official Model Context Protocol (MCP) development practices used in this project, following official guidelines and examples from the MCP ecosystem.

## Official MCP Resources

### Primary Documentation
- **Official MCP Documentation**: https://modelcontextprotocol.io/
- **Local Reference**: `/Users/karlchow/Desktop/code/multi-worktree-setup/llms-full.txt`
- **Official Server Examples**: https://github.com/modelcontextprotocol/servers

### Reference Implementation
- **Filesystem Server**: https://raw.githubusercontent.com/modelcontextprotocol/servers/refs/heads/main/src/filesystem/README.md
- **Package**: `@modelcontextprotocol/server-filesystem`

## Our MCP Server Architecture

### Core Implementation: `src/mcp-server.ts`

Our worktree orchestrator follows official MCP patterns:

```typescript
#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';

// Dynamic version reading (official best practice)
import { fileURLToPath } from 'url';
import { dirname } from 'path';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const packagePath = path.join(__dirname, '..', 'package.json');
const packageJson = fs.readJsonSync(packagePath);
const VERSION = packageJson.version;

// Server initialization following official pattern
const server = new Server(
  {
    name: 'worktree-orchestrator',
    version: VERSION, // Dynamic version from package.json
  },
  {
    capabilities: {
      tools: {}, // Tool capabilities
    },
  }
);
```

## MCP Development Best Practices

### 1. Tool Design Patterns

Following the filesystem server example, our tools implement:

#### **Flexible Operation Modes**
```typescript
// Pattern: Support multiple input methods
async createWorktree(worktreeType: string, featureName: string): Promise<string> {
  const branchName = `${worktreeType}/${featureName}`;
  const worktreePath = path.join(this.worktreesDir, worktreeType);

  // Implement robust error handling
  try {
    await fs.ensureDir(this.worktreesDir);
    // Operation logic with fallback handling
  } catch (error) {
    throw new Error(`Failed to create worktree: ${error.message}`);
  }
}
```

#### **Comprehensive Tool Schemas**
```typescript
const tools: Tool[] = [
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
  }
];
```

### 2. Request Handler Pattern

Following official MCP server patterns:

```typescript
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'worktree-create': {
        const { type, name: worktreName } = args as { type: string; name: string };
        const result = await orchestrator.createWorktree(type, worktreName);
        return {
          content: [{ type: 'text', text: result }]
        };
      }

      // Additional tool handlers...

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
```

### 3. Server Lifecycle Management

```typescript
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error('MCP Server error:', error);
  process.exit(1);
});
```

## Advanced MCP Patterns Implemented

### 1. Background Agent Management

Our implementation extends basic MCP patterns with:

```typescript
interface BackgroundAgent {
  id: string;
  worktree: string;
  task: string;
  status: 'running' | 'completed' | 'failed';
  pid?: number;
  tmuxSession?: string;
  startTime: Date;
  completionTime?: Date;
}
```

### 2. Progress Monitoring Tools

Following filesystem server patterns for comprehensive operations:

```typescript
// Real-time output streaming
async getAgentLogs(agentId: string, lines: number = 20): Promise<string> {
  // Capture tmux session output
  const output = execSync(`tmux capture-pane -t ${agent.tmuxSession} -p`);
  return `=== Agent ${agentId} Output (last ${lines} lines) ===\n${logLines}`;
}

// File system monitoring
async monitorWorktreeProgress(worktree: string): Promise<string> {
  // Check for signal files and git status
  const progress = [];
  // Signal file detection
  // Git status monitoring
  // Active agent tracking
  return progress.join('\n');
}
```

### 3. Signal File Coordination

Implementing workflow automation:

```typescript
private async processSignalFile(worktree: string, signalFile: string): Promise<void> {
  const workflows = {
    '.claude-complete': async () => {
      if (worktree === 'feature') {
        await this.spawnBackgroundAgent('test', 'Run tests for feature', 'npm test');
      }
    },
    '.tests-complete': async () => {
      if (worktree === 'test') {
        await this.spawnBackgroundAgent('docs', 'Update documentation', 'npm run docs');
      }
    }
  };
}
```

## Configuration Patterns

### 1. Package.json Integration

Following official versioning practices:

```json
{
  "name": "ccmultihelper",
  "version": "1.3.0",
  "type": "module",
  "bin": {
    "worktree-orchestrator": "dist/mcp-server.js"
  },
  "scripts": {
    "build:mcp": "bun build src/mcp-server.ts --outfile=dist/mcp-server.js --target=node"
  }
}
```

### 2. MCP Server Registration

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

## Testing Patterns

Following official testing approaches:

```typescript
// Test MCP server functionality
describe('MCP Server Tests', () => {
  test('MCP server provides all expected tools', async () => {
    const tools = await server.listTools();
    expect(tools.tools).toHaveLength(8);
    expect(tools.tools.map(t => t.name)).toContain('worktree-create');
  });
});
```

## Deployment Best Practices

### 1. Automated Version Sync

```typescript
// Dynamic version reading for consistency
const packageJson = fs.readJsonSync(packagePath);
const VERSION = packageJson.version;

const server = new Server({
  name: 'worktree-orchestrator',
  version: VERSION, // Always matches package.json
});
```

### 2. Standalone Distribution

```bash
# Fetch latest version dynamically
LATEST_VERSION=$(curl -s https://raw.githubusercontent.com/karlorz/ccmultihelper/main/package.json | grep '"version"' | head -1 | sed 's/.*"version": "\(.*\)",/\1/')

# Download current MCP server
curl -s https://raw.githubusercontent.com/karlorz/ccmultihelper/main/dist/mcp-server.js > dist/mcp-server.js
```

## Official MCP Guidelines Compliance

### ✅ Transport Protocol
- Uses `StdioServerTransport` for communication
- Implements proper request/response handling
- Follows JSON-RPC message format

### ✅ Tool Interface
- Clear tool descriptions and schemas
- Proper input validation
- Comprehensive error handling
- Consistent response formats

### ✅ Server Lifecycle
- Proper initialization and cleanup
- Error handling and logging
- Transport connection management

### ✅ Capability Declaration
- Declares tool capabilities
- Follows semantic versioning
- Provides server metadata

## Development Workflow

### 1. Follow Official Examples
- Study `@modelcontextprotocol/server-filesystem` implementation
- Use official SDK patterns and types
- Implement robust error handling

### 2. Build and Test
```bash
# Build MCP server
bun run build:mcp

# Test functionality
bun run test

# Deploy with version sync
bun run release
```

### 3. Integration Testing
```bash
# Register server locally
claude mcp add worktree-orchestrator --scope project node dist/mcp-server.js

# Verify tools available
claude mcp get worktree-orchestrator

# Test in Claude Code session
claude
```

This guide ensures our MCP server development follows official patterns while implementing advanced worktree orchestration features.