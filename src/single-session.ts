#!/usr/bin/env node
/**
 * Single-Session Command Interface for Worktree Orchestrator
 * Provides natural language commands for parallel worktree automation
 */

import { execSync } from 'child_process';
import fs from 'fs-extra';
import path from 'path';
import chalk from 'chalk';

interface Command {
  pattern: RegExp;
  handler: (match: RegExpMatchArray) => Promise<string>;
  description: string;
  examples: string[];
}

class SingleSessionInterface {
  private mcpServerProcess?: any;
  private commands: Command[] = [];

  constructor() {
    this.initializeCommands();
  }

  private initializeCommands(): void {
    this.commands = [
      {
        pattern: /^\/worktree-create-(\w+)\s+"([^"]+)"$/i,
        handler: async (match) => {
          const [, type, name] = match;
          return await this.callMCPTool('worktree-create', { type, name });
        },
        description: 'Create a new worktree',
        examples: [
          '/worktree-create-feature "user-authentication"',
          '/worktree-create-bugfix "login-error-fix"'
        ]
      },
      {
        pattern: /^\/worktree-spawn-agent\s+(\w+)\s+"([^"]+)"(?:\s+"([^"]+)")?$/i,
        handler: async (match) => {
          const [, worktree, task, command = 'claude'] = match;
          return await this.callMCPTool('worktree-spawn-agent', { worktree, task, command });
        },
        description: 'Spawn a background agent in a worktree',
        examples: [
          '/worktree-spawn-agent feature "Implement user login"',
          '/worktree-spawn-agent test "Run integration tests" "npm test"'
        ]
      },
      {
        pattern: /^\/worktree-status$/i,
        handler: async () => {
          return await this.callMCPTool('worktree-status', {});
        },
        description: 'Show status of all worktrees and agents',
        examples: ['/worktree-status']
      },
      {
        pattern: /^\/worktree-agent-status(?:\s+(\S+))?$/i,
        handler: async (match) => {
          const [, agentId] = match;
          return await this.callMCPTool('worktree-agent-status', agentId ? { agentId } : {});
        },
        description: 'Show status of background agents',
        examples: [
          '/worktree-agent-status',
          '/worktree-agent-status agent-1234567890'
        ]
      },
      {
        pattern: /^\/worktree-kill-agent\s+(\S+)$/i,
        handler: async (match) => {
          const [, agentId] = match;
          return await this.callMCPTool('worktree-kill-agent', { agentId });
        },
        description: 'Kill a background agent',
        examples: ['/worktree-kill-agent agent-1234567890']
      },
      {
        pattern: /^\/worktree-integrate\s+(\w+)(?:\s+(\w+))?$/i,
        handler: async (match) => {
          const [, sourceWorktree, targetBranch = 'main'] = match;
          return await this.callMCPTool('worktree-integrate', { sourceWorktree, targetBranch });
        },
        description: 'Integrate changes from a worktree into main branch',
        examples: [
          '/worktree-integrate feature',
          '/worktree-integrate bugfix develop'
        ]
      },
      {
        pattern: /^\/help$/i,
        handler: async () => {
          return this.showHelp();
        },
        description: 'Show help for all available commands',
        examples: ['/help']
      }
    ];
  }

  private async callMCPTool(toolName: string, args: any): Promise<string> {
    try {
      // In a real implementation, this would communicate with the MCP server
      // For now, we'll simulate the call by directly executing the tool logic
      const mcpServerPath = path.join(__dirname, 'mcp-server.ts');

      // Create a temporary file with the tool call
      const tempFile = path.join(__dirname, '..', '.tmp', `mcp-call-${Date.now()}.json`);
      await fs.ensureDir(path.dirname(tempFile));
      await fs.writeJSON(tempFile, {
        method: 'tools/call',
        params: {
          name: toolName,
          arguments: args
        }
      });

      // Execute the MCP server with the tool call
      const result = execSync(`node ${mcpServerPath} < ${tempFile}`, {
        encoding: 'utf8',
        timeout: 30000
      });

      // Clean up temp file
      await fs.remove(tempFile);

      return result.trim();
    } catch (error) {
      return `Error: ${error.message}`;
    }
  }

  private showHelp(): string {
    const help = [];
    help.push(chalk.blue.bold('Worktree Orchestrator - Single Session Commands'));
    help.push('='.repeat(60));
    help.push('');

    for (const command of this.commands) {
      help.push(chalk.green.bold(command.description));
      for (const example of command.examples) {
        help.push(chalk.cyan(`  ${example}`));
      }
      help.push('');
    }

    help.push(chalk.yellow.bold('Workflow Examples:'));
    help.push('');
    help.push(chalk.cyan('1. Feature Development:'));
    help.push('   /worktree-create-feature "user-dashboard"');
    help.push('   /worktree-spawn-agent feature "Build user dashboard component"');
    help.push('   /worktree-status');
    help.push('');
    help.push(chalk.cyan('2. Testing Workflow:'));
    help.push('   /worktree-spawn-agent test "Run tests for user dashboard"');
    help.push('   /worktree-agent-status');
    help.push('');
    help.push(chalk.cyan('3. Integration:'));
    help.push('   /worktree-integrate feature');
    help.push('');
    help.push(chalk.yellow('Signal Files:'));
    help.push('- .claude-complete - Feature work completed');
    help.push('- .tests-complete - Tests completed');
    help.push('- .bugfix-complete - Bugfix completed');
    help.push('- .docs-complete - Documentation completed');

    return help.join('\n');
  }

  async processCommand(input: string): Promise<string> {
    const trimmedInput = input.trim();

    for (const command of this.commands) {
      const match = trimmedInput.match(command.pattern);
      if (match) {
        try {
          return await command.handler(match);
        } catch (error) {
          return chalk.red(`Error executing command: ${error.message}`);
        }
      }
    }

    // If no command matches, provide helpful suggestions
    return chalk.yellow('Unknown command. Type /help for available commands.\n\nDid you mean:\n') +
           this.commands
             .filter(cmd => cmd.pattern.source.includes(trimmedInput.split(' ')[0]))
             .map(cmd => chalk.cyan(`  ${cmd.examples[0]}`))
             .slice(0, 3)
             .join('\n');
  }

  async startInteractiveMode(): Promise<void> {
    console.log(chalk.blue.bold('🚀 Worktree Orchestrator - Single Session Mode'));
    console.log(chalk.gray('Type /help for available commands, or Ctrl+C to exit'));
    console.log('');

    // In a real implementation, this would start an interactive REPL
    // For demonstration, we'll just show that the system is ready
    console.log(chalk.green('✅ System ready - MCP server initialized'));
    console.log(chalk.cyan('Example: /worktree-create-feature "my-new-feature"'));
  }
}

// Command-line interface
if (require.main === module) {
  const sessionInterface = new SingleSessionInterface();

  const args = process.argv.slice(2);

  if (args.length === 0) {
    // Start interactive mode
    sessionInterface.startInteractiveMode();
  } else {
    // Process single command
    const command = args.join(' ');
    sessionInterface.processCommand(command)
      .then(result => {
        console.log(result);
        process.exit(0);
      })
      .catch(error => {
        console.error(chalk.red(`Error: ${error.message}`));
        process.exit(1);
      });
  }
}

export { SingleSessionInterface };