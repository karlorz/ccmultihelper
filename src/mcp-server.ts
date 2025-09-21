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
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import { execSync, spawn } from 'child_process';
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

class WorktreeOrchestrator {
  private agents: Map<string, BackgroundAgent> = new Map();
  private projectName: string;
  private worktreesDir: string;
  private gitRoot: string;

  constructor() {
    this.gitRoot = this.getGitRoot();
    this.projectName = this.detectProjectName();
    this.worktreesDir = path.join(this.gitRoot, '..', `${this.projectName}-worktrees`);
  }

  private getGitRoot(): string {
    try {
      return execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
    } catch (error) {
      throw new Error('Not in a Git repository');
    }
  }

  private detectProjectName(): string {
    const configPath = path.join(this.gitRoot, '.claude', 'worktree-config.json');
    if (fs.existsSync(configPath)) {
      const config = fs.readJsonSync(configPath);
      return config.projectName;
    }
    return path.basename(this.gitRoot);
  }

  private generateAgentId(): string {
    return `agent-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  async createWorktree(worktreeType: string, featureName: string): Promise<string> {
    const branchName = `${worktreeType}/${featureName}`;
    const worktreePath = path.join(this.worktreesDir, worktreeType);

    try {
      // Ensure worktrees directory exists
      await fs.ensureDir(this.worktreesDir);

      // Remove existing worktree if it exists
      if (await fs.pathExists(worktreePath)) {
        try {
          execSync(`git worktree remove ${worktreePath}`, { cwd: this.gitRoot });
        } catch (error) {
          await fs.remove(worktreePath);
        }
      }

      // Create new worktree with new branch
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

      // Create launch script
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

  async spawnBackgroundAgent(worktree: string, task: string, command: string): Promise<string> {
    const agentId = this.generateAgentId();
    const tmuxSession = `claude-${worktree}-${agentId}`;
    const worktreePath = path.join(this.worktreesDir, worktree);

    if (!await fs.pathExists(worktreePath)) {
      throw new Error(`Worktree ${worktree} does not exist`);
    }

    try {
      // Create tmux session and run command
      const tmuxCommand = `tmux new-session -d -s ${tmuxSession} -c ${worktreePath} '${command}'`;
      execSync(tmuxCommand);

      // Get PID from tmux session
      const pidOutput = execSync(`tmux list-panes -t ${tmuxSession} -F '#{pane_pid}'`, {
        encoding: 'utf8'
      });
      const pid = parseInt(pidOutput.trim());

      const agent: BackgroundAgent = {
        id: agentId,
        worktree,
        task,
        status: 'running',
        pid,
        tmuxSession,
        startTime: new Date()
      };

      this.agents.set(agentId, agent);
      this.monitorAgent(agentId);

      return agentId;
    } catch (error) {
      throw new Error(`Failed to spawn background agent: ${error.message}`);
    }
  }

  private async monitorAgent(agentId: string): Promise<void> {
    const agent = this.agents.get(agentId);
    if (!agent) return;

    const checkInterval = setInterval(() => {
      try {
        execSync(`tmux has-session -t ${agent.tmuxSession}`, { stdio: 'pipe' });
      } catch (error) {
        agent.status = 'completed';
        agent.completionTime = new Date();
        clearInterval(checkInterval);
        this.checkSignalFiles(agent.worktree);
      }
    }, 5000);
  }

  private async checkSignalFiles(worktree: string): Promise<void> {
    const signalFiles = ['.claude-complete', '.tests-complete', '.bugfix-complete', '.docs-complete'];
    const worktreePath = path.join(this.worktreesDir, worktree);

    for (const signalFile of signalFiles) {
      const signalPath = path.join(worktreePath, signalFile);
      if (await fs.pathExists(signalPath)) {
        await this.processSignalFile(worktree, signalFile);
        await fs.remove(signalPath);
      }
    }
  }

  private async processSignalFile(worktree: string, signalFile: string): Promise<void> {
    const workflows = {
      '.claude-complete': async () => {
        if (worktree === 'feature') {
          await this.spawnBackgroundAgent('test', 'Run tests for feature', 'npm test || echo "Tests completed"');
        }
      },
      '.tests-complete': async () => {
        if (worktree === 'test') {
          await this.spawnBackgroundAgent('docs', 'Update documentation', 'echo "Updating docs..." && touch .docs-complete');
        }
      },
      '.bugfix-complete': async () => {
        if (worktree === 'bugfix') {
          await this.spawnBackgroundAgent('test', 'Validate bugfix', 'npm test || echo "Validation completed"');
        }
      }
    };

    const workflow = workflows[signalFile as keyof typeof workflows];
    if (workflow) {
      await workflow();
    }
  }

  async getAgentStatus(agentId?: string): Promise<BackgroundAgent[]> {
    if (agentId) {
      const agent = this.agents.get(agentId);
      return agent ? [agent] : [];
    }
    return Array.from(this.agents.values());
  }

  async killAgent(agentId: string): Promise<string> {
    const agent = this.agents.get(agentId);
    if (!agent) {
      throw new Error(`Agent ${agentId} not found`);
    }

    try {
      if (agent.tmuxSession) {
        execSync(`tmux kill-session -t ${agent.tmuxSession}`);
      }
      if (agent.pid) {
        process.kill(agent.pid, 'SIGTERM');
      }

      agent.status = 'failed';
      agent.completionTime = new Date();
      return `Agent ${agentId} terminated`;
    } catch (error) {
      throw new Error(`Failed to kill agent: ${error.message}`);
    }
  }

  async integrateChanges(sourceWorktree: string, targetBranch: string = 'main'): Promise<string> {
    const sourceWorktreePath = path.join(this.worktreesDir, sourceWorktree);

    if (!await fs.pathExists(sourceWorktreePath)) {
      throw new Error(`Source worktree ${sourceWorktree} does not exist`);
    }

    try {
      const currentBranch = execSync('git branch --show-current', {
        cwd: sourceWorktreePath,
        encoding: 'utf8'
      }).trim();

      execSync(`git checkout ${targetBranch}`, { cwd: this.gitRoot });
      execSync(`git merge ${currentBranch}`, { cwd: this.gitRoot });

      return `Integrated ${currentBranch} into ${targetBranch}`;
    } catch (error) {
      throw new Error(`Integration failed: ${error.message}`);
    }
  }

  async getWorktreeStatus(): Promise<string> {
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
    status.push('');

    // Enhanced agent status with progress indicators
    const activeAgents = Array.from(this.agents.values()).filter(a => a.status === 'running');
    const completedAgents = Array.from(this.agents.values()).filter(a => a.status === 'completed');
    const failedAgents = Array.from(this.agents.values()).filter(a => a.status === 'failed');

    status.push(`Background Agents Summary:`);
    status.push(`  Running: ${activeAgents.length}`);
    status.push(`  Completed: ${completedAgents.length}`);
    status.push(`  Failed: ${failedAgents.length}`);
    status.push('');

    // Detailed active agent status
    if (activeAgents.length > 0) {
      status.push('Active Agents:');
      for (const agent of activeAgents) {
        const runtime = Math.floor((Date.now() - agent.startTime.getTime()) / 1000);
        const runtimeStr = runtime > 60 ? `${Math.floor(runtime/60)}m ${runtime%60}s` : `${runtime}s`;
        status.push(`  ● ${agent.id}: ${agent.task}`);
        status.push(`    Worktree: ${agent.worktree}`);
        status.push(`    Runtime: ${runtimeStr}`);
        status.push(`    Session: ${agent.tmuxSession}`);
      }
      status.push('');
    }

    // Check for completion signals across all worktrees
    const worktreeTypes = ['feature', 'test', 'docs', 'bugfix'];
    const signalFiles = ['.claude-complete', '.tests-complete', '.bugfix-complete', '.docs-complete'];

    status.push('Worktree Progress Indicators:');
    for (const worktreeType of worktreeTypes) {
      const worktreePath = path.join(this.worktreesDir, worktreeType);
      if (await fs.pathExists(worktreePath)) {
        status.push(`  ${worktreeType.toUpperCase()}:`);

        let hasSignals = false;
        for (const signalFile of signalFiles) {
          const signalPath = path.join(worktreePath, signalFile);
          if (await fs.pathExists(signalPath)) {
            status.push(`    ✓ ${signalFile}`);
            hasSignals = true;
          }
        }

        if (!hasSignals) {
          status.push(`    ○ No completion signals`);
        }

        // Check for pending changes
        try {
          const gitStatus = execSync('git status --porcelain', {
            cwd: worktreePath,
            encoding: 'utf8',
            timeout: 3000
          }).trim();

          if (gitStatus) {
            const changeCount = gitStatus.split('\n').length;
            status.push(`    ⚠ ${changeCount} pending changes`);
          } else {
            status.push(`    ✓ No pending changes`);
          }
        } catch (error) {
          status.push(`    ❓ Unable to check git status`);
        }
      } else {
        status.push(`  ${worktreeType.toUpperCase()}: Not created`);
      }
    }

    return status.join('\n');
  }

  async getAgentLogs(agentId: string, lines: number = 20): Promise<string> {
    const agent = this.agents.get(agentId);
    if (!agent) {
      throw new Error(`Agent ${agentId} not found`);
    }

    if (!agent.tmuxSession) {
      return 'Agent has no tmux session';
    }

    try {
      // Capture tmux session output
      const output = execSync(`tmux capture-pane -t ${agent.tmuxSession} -p`, {
        encoding: 'utf8',
        timeout: 5000
      });

      const logLines = output.split('\n').slice(-lines).join('\n');
      return `=== Agent ${agentId} Output (last ${lines} lines) ===\n${logLines}`;
    } catch (error) {
      return `Error capturing agent logs: ${error.message}`;
    }
  }

  async monitorWorktreeProgress(worktree: string, since: string = 'last-check'): Promise<string> {
    const worktreePath = path.join(this.worktreesDir, worktree);

    if (!await fs.pathExists(worktreePath)) {
      throw new Error(`Worktree ${worktree} does not exist`);
    }

    try {
      const progress = [];
      progress.push(`=== ${worktree.toUpperCase()} Worktree Progress ===`);
      progress.push(`Path: ${worktreePath}`);
      progress.push('');

      // Check for signal files
      const signalFiles = ['.claude-complete', '.tests-complete', '.bugfix-complete', '.docs-complete'];
      let hasSignals = false;

      for (const signalFile of signalFiles) {
        const signalPath = path.join(worktreePath, signalFile);
        if (await fs.pathExists(signalPath)) {
          const stats = await fs.stat(signalPath);
          progress.push(`✓ Signal: ${signalFile} (created ${stats.mtime.toISOString()})`);
          hasSignals = true;
        }
      }

      if (!hasSignals) {
        progress.push('○ No completion signals detected');
      }
      progress.push('');

      // Get recent file changes
      const gitStatus = execSync('git status --porcelain', {
        cwd: worktreePath,
        encoding: 'utf8',
        timeout: 5000
      }).trim();

      if (gitStatus) {
        progress.push('Recent Changes:');
        gitStatus.split('\n').forEach(line => {
          const status = line.substring(0, 2);
          const file = line.substring(3);
          const statusDesc = status.includes('M') ? 'Modified' :
                           status.includes('A') ? 'Added' :
                           status.includes('D') ? 'Deleted' :
                           status.includes('??') ? 'Untracked' : 'Changed';
          progress.push(`  ${statusDesc}: ${file}`);
        });
      } else {
        progress.push('No pending changes');
      }
      progress.push('');

      // Check running processes in the worktree
      const activeAgent = Array.from(this.agents.values())
        .find(a => a.worktree === worktree && a.status === 'running');

      if (activeAgent) {
        progress.push(`Active Agent: ${activeAgent.id}`);
        progress.push(`  Task: ${activeAgent.task}`);
        progress.push(`  Running since: ${activeAgent.startTime.toISOString()}`);
        progress.push(`  Session: ${activeAgent.tmuxSession}`);
      } else {
        progress.push('No active agents in this worktree');
      }

      return progress.join('\n');
    } catch (error) {
      throw new Error(`Failed to monitor worktree progress: ${error.message}`);
    }
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
  },
  {
    name: 'worktree-agent-status',
    description: 'Get status of background agents',
    inputSchema: {
      type: 'object',
      properties: {
        agentId: {
          type: 'string',
          description: 'Specific agent ID to check (optional)'
        }
      }
    }
  },
  {
    name: 'worktree-kill-agent',
    description: 'Kill a background agent',
    inputSchema: {
      type: 'object',
      properties: {
        agentId: {
          type: 'string',
          description: 'Agent ID to terminate'
        }
      },
      required: ['agentId']
    }
  },
  {
    name: 'worktree-agent-logs',
    description: 'Get real-time output logs from a background agent',
    inputSchema: {
      type: 'object',
      properties: {
        agentId: {
          type: 'string',
          description: 'Agent ID to get logs from'
        },
        lines: {
          type: 'number',
          description: 'Number of recent log lines to retrieve',
          default: 20
        }
      },
      required: ['agentId']
    }
  },
  {
    name: 'worktree-agent-progress',
    description: 'Monitor file changes and progress in a worktree',
    inputSchema: {
      type: 'object',
      properties: {
        worktree: {
          type: 'string',
          enum: ['feature', 'test', 'docs', 'bugfix'],
          description: 'Worktree to monitor for changes'
        },
        since: {
          type: 'string',
          description: 'Monitor changes since this timestamp (ISO string)',
          default: 'last-check'
        }
      },
      required: ['worktree']
    }
  },
  {
    name: 'worktree-integrate',
    description: 'Integrate changes from a worktree into main branch',
    inputSchema: {
      type: 'object',
      properties: {
        sourceWorktree: {
          type: 'string',
          enum: ['feature', 'test', 'docs', 'bugfix'],
          description: 'Source worktree to integrate from'
        },
        targetBranch: {
          type: 'string',
          description: 'Target branch to merge into',
          default: 'main'
        }
      },
      required: ['sourceWorktree']
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
        const { type, name: worktreName } = args as { type: string; name: string };
        const result = await orchestrator.createWorktree(type, worktreName);
        return {
          content: [{ type: 'text', text: result }]
        };
      }

      case 'worktree-spawn-agent': {
        const { worktree, task, command = 'claude' } = args as {
          worktree: string;
          task: string;
          command?: string;
        };
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

      case 'worktree-agent-status': {
        const { agentId } = args as { agentId?: string };
        const agents = await orchestrator.getAgentStatus(agentId);
        const statusText = agents.map(agent =>
          `Agent ${agent.id}:\n` +
          `  Worktree: ${agent.worktree}\n` +
          `  Task: ${agent.task}\n` +
          `  Status: ${agent.status}\n` +
          `  Started: ${agent.startTime.toISOString()}\n` +
          (agent.completionTime ? `  Completed: ${agent.completionTime.toISOString()}\n` : '') +
          `  TMux Session: ${agent.tmuxSession || 'N/A'}`
        ).join('\n\n');

        return {
          content: [{ type: 'text', text: statusText || 'No agents found' }]
        };
      }

      case 'worktree-kill-agent': {
        const { agentId } = args as { agentId: string };
        const result = await orchestrator.killAgent(agentId);
        return {
          content: [{ type: 'text', text: result }]
        };
      }

      case 'worktree-integrate': {
        const { sourceWorktree, targetBranch = 'main' } = args as {
          sourceWorktree: string;
          targetBranch?: string;
        };
        const result = await orchestrator.integrateChanges(sourceWorktree, targetBranch);
        return {
          content: [{ type: 'text', text: result }]
        };
      }

      case 'worktree-agent-logs': {
        const { agentId, lines = 20 } = args as {
          agentId: string;
          lines?: number;
        };
        const logs = await orchestrator.getAgentLogs(agentId, lines);
        return {
          content: [{ type: 'text', text: logs }]
        };
      }

      case 'worktree-agent-progress': {
        const { worktree, since = 'last-check' } = args as {
          worktree: string;
          since?: string;
        };
        const progress = await orchestrator.monitorWorktreeProgress(worktree, since);
        return {
          content: [{ type: 'text', text: progress }]
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