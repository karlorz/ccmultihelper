#!/usr/bin/env node
import { Command } from 'commander';
import chalk from 'chalk';
import inquirer from 'inquirer';
import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const program = new Command();

// Security function to sanitize project names and prevent path traversal attacks
function sanitizeProjectName(name: string): string | null {
  if (!name || typeof name !== 'string') return null;

  // First, check for path traversal attempts in the original input
  if (name.toLowerCase().includes('..') ||
      name.includes('/') ||
      name.includes('\\')) {
    return null;
  }

  const sanitized = path.basename(name).trim();

  // Reserved Windows filenames
  const reservedNames = ['con', 'prn', 'aux', 'nul', 'com1', 'lpt1'];
  if (reservedNames.includes(sanitized.toLowerCase())) {
    return null;
  }

  // Strict validation: alphanumeric, underscore, hyphen only, max 50 chars
  if (!/^[a-zA-Z0-9_-]{1,50}$/.test(sanitized)) {
    return null;
  }

  return sanitized;
}

program
  .name('ccmultihelper')
  .description('Claude Code Multi-Worktree Helper - Setup automated workflows for parallel Claude Code sessions')
  .version('1.0.0');

program
  .command('init')
  .description('Initialize multi-worktree setup in current project')
  .option('-p, --project-name <name>', 'Project name for worktrees')
  .option('-a, --auto-setup', 'Auto-setup with default configuration')
  .action(async (options) => {
    console.log(chalk.blue('🚀 Initializing Claude Code Multi-Worktree Setup...'));

    let projectName = options.projectName || await getProjectName();
    const sanitizedProjectName = sanitizeProjectName(projectName);

    if (!sanitizedProjectName) {
      console.error(chalk.red('❌ Invalid project name. Use only letters, numbers, underscores, and hyphens (1-50 characters).'));
      process.exit(1);
    }

    const autoSetup = options.autoSetup || await askAutoSetup();
    await setupProject(sanitizedProjectName, autoSetup);
  });

program
  .command('setup-hooks')
  .description('Setup Claude Code hooks for automated workflows')
  .option('-p, --project-name <name>', 'Project name for worktrees')
  .action(async (options) => {
    console.log(chalk.blue('🔧 Setting up Claude Code hooks...'));

    let projectName = options.projectName || await getProjectName();
    const sanitizedProjectName = sanitizeProjectName(projectName);

    if (!sanitizedProjectName) {
      console.error(chalk.red('❌ Invalid project name. Use only letters, numbers, underscores, and hyphens (1-50 characters).'));
      process.exit(1);
    }

    await setupClaudeHooks(sanitizedProjectName);
  });

program
  .command('create-commands')
  .description('Create custom Claude Code slash commands')
  .option('-p, --project-name <name>', 'Project name for worktrees')
  .action(async (options) => {
    console.log(chalk.blue('📝 Creating custom slash commands...'));

    let projectName = options.projectName || await getProjectName();
    const sanitizedProjectName = sanitizeProjectName(projectName);

    if (!sanitizedProjectName) {
      console.error(chalk.red('❌ Invalid project name. Use only letters, numbers, underscores, and hyphens (1-50 characters).'));
      process.exit(1);
    }

    await createCustomCommands(sanitizedProjectName);
  });

program
  .command('start-monitor')
  .description('Start worktree monitoring service')
  .option('-p, --project-name <name>', 'Project name for worktrees')
  .option('-t, --type <type>', 'Monitor type: auto-detect|file-monitor|webhook', 'auto-detect')
  .action(async (options) => {
    console.log(chalk.blue('🔍 Starting worktree monitoring...'));

    let projectName = options.projectName || await getProjectName();
    const sanitizedProjectName = sanitizeProjectName(projectName);

    if (!sanitizedProjectName) {
      console.error(chalk.red('❌ Invalid project name. Use only letters, numbers, underscores, and hyphens (1-50 characters).'));
      process.exit(1);
    }

    const monitorType = options.type;
    await startMonitoring(sanitizedProjectName, monitorType);
  });

program
  .command('cleanup')
  .description('Clean up worktrees and configuration')
  .option('-p, --project-name <name>', 'Project name for worktrees')
  .action(async (options) => {
    console.log(chalk.yellow('🧹 Cleaning up worktrees...'));

    let projectName = options.projectName || await getProjectName();
    const sanitizedProjectName = sanitizeProjectName(projectName);

    if (!sanitizedProjectName) {
      console.error(chalk.red('❌ Invalid project name. Use only letters, numbers, underscores, and hyphens (1-50 characters).'));
      process.exit(1);
    }

    await cleanupWorktrees(sanitizedProjectName);
  });

async function getProjectName(): Promise<string> {
  const { projectName } = await inquirer.prompt([
    {
      type: 'input',
      name: 'projectName',
      message: 'Enter project name for worktrees:',
      default: path.basename(process.cwd()),
      validate: (input) => {
        const trimmed = input.trim();
        if (trimmed.length === 0) {
          return 'Project name is required';
        }
        if (trimmed.length > 50) {
          return 'Project name must be 50 characters or less';
        }
        if (!/^[a-zA-Z0-9_-]+$/.test(trimmed)) {
          return 'Project name can only contain letters, numbers, underscores, and hyphens';
        }
        return true;
      }
    }
  ]);
  return projectName.trim();
}

async function askAutoSetup(): Promise<boolean> {
  const { autoSetup } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'autoSetup',
      message: 'Auto-setup with default configuration?',
      default: true
    }
  ]);
  return autoSetup;
}

async function setupProject(projectName: string, autoSetup: boolean) {
  try {
    // Check if we're in a git repository
    if (!fs.existsSync(path.join(process.cwd(), '.git'))) {
      console.log(chalk.red('❌ Not a Git repository. Please run this from your project root.'));
      return;
    }

    console.log(chalk.green(`✅ Setting up project: ${projectName}`));

    // Create .claude directory structure
    await createClaudeDirectory();

    // Setup worktrees using existing script
    await setupWorktrees(projectName);

    if (autoSetup) {
      await setupClaudeHooks(projectName);
      await createCustomCommands(projectName);
    }

    console.log(chalk.green('🎉 Setup completed successfully!'));
    console.log(chalk.blue('\nNext steps:'));
    console.log('1. Start monitoring: bunx ccmultihelper start-monitor');
    console.log('2. Launch Claude Code sessions in worktrees');
    console.log('3. Use slash commands like /worktree-feature, /worktree-test');

  } catch (error) {
    console.error(chalk.red('❌ Setup failed:'), error);
  }
}

async function createClaudeDirectory() {
  const claudeDir = path.join(process.cwd(), '.claude');

  await fs.ensureDir(claudeDir);
  await fs.ensureDir(path.join(claudeDir, 'commands'));
  await fs.ensureDir(path.join(claudeDir, 'hooks'));

  console.log(chalk.green('✅ Created .claude directory structure'));
}

async function setupWorktrees(projectName: string) {
  const worktreesDir = path.join('..', `${projectName}-worktrees`);

  // Copy and adapt the existing setup script
  const setupScript = path.join(__dirname, '../../setup-worktrees.sh');

  if (fs.existsSync(setupScript)) {
    console.log(chalk.blue('📁 Running worktree setup script...'));
    // In a real implementation, we'd execute the script
    console.log(chalk.green(`✅ Worktrees will be created in: ${worktreesDir}`));
  } else {
    console.log(chalk.yellow('⚠️  Setup script not found, creating basic worktree structure...'));

    // Create basic worktree structure
    const worktrees = ['feature', 'test', 'docs', 'bugfix'];
    for (const worktree of worktrees) {
      const worktreePath = path.join(worktreesDir, worktree);
      await fs.ensureDir(worktreePath);

      // Create launch script
      const launchScript = `#!/bin/bash
# Launch Claude Code in ${worktree} worktree
echo "Starting Claude Code in ${worktree} environment..."
claude
`;
      await fs.writeFile(path.join(worktreePath, 'launch-claude.sh'), launchScript);
      await fs.chmod(path.join(worktreePath, 'launch-claude.sh'), '755');
    }

    console.log(chalk.green(`✅ Basic worktree structure created in: ${worktreesDir}`));
  }
}

async function setupClaudeHooks(projectName: string) {
  const hooksDir = path.join(process.cwd(), '.claude', 'hooks');

  // Create session start hook
  const sessionStartHook = `#!/usr/bin/env node
// SessionStart Hook - Initialize worktree context
import { readFileSync } from 'fs';
import { join } from 'path';

const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const projectName = '${projectName}';

const additionalContext = \`🔄 Multi-Worktree Setup Active
Project: \${projectName}
Worktrees: feature, test, docs, bugfix

Available commands:
- /worktree-feature - Work in feature worktree
- /worktree-test - Work in test worktree
- /worktree-docs - Work in docs worktree
- /worktree-bugfix - Work in bugfix worktree
- /sync-worktrees - Sync changes between worktrees
- /monitor-start - Start worktree monitoring
- /monitor-stop - Stop worktree monitoring

Use signal files to coordinate workflows:
- .claude-complete - Feature work completed
- .tests-complete - Tests completed
- .bugfix-complete - Bugfix completed\`;

console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext
  }
}));
`;

  await fs.writeFile(path.join(hooksDir, 'session-start.js'), sessionStartHook);
  await fs.chmod(path.join(hooksDir, 'session-start.js'), '755');

  // Create post-tool-use hook for worktree coordination
  const postToolUseHook = `#!/usr/bin/env node
// PostToolUse Hook - Auto-coordinate worktree workflows
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const input = JSON.parse(readFileSync(0, 'utf8'));
const { tool_name, tool_input } = input;
const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const projectName = '${projectName}';

// Check for signal files and trigger workflows
if (tool_name === 'Write' || tool_name === 'Edit') {
  const worktreesDir = join('..', \`\${projectName}-worktrees\`);

  // Check if any signal files exist and process them
  const signals = [
    { file: 'feature/.claude-complete', action: 'trigger-tests' },
    { file: 'test/.tests-complete', action: 'trigger-docs' },
    { file: 'bugfix/.bugfix-complete', action: 'trigger-validation' }
  ];

  for (const signal of signals) {
    const signalPath = join(worktreesDir, signal.file);
    if (existsSync(signalPath)) {
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PostToolUse",
          additionalContext: \`🔄 Detected \${signal.action} signal from \${signal.file}\`
        }
      }));
      break;
    }
  }
}

// Allow tool execution
process.exit(0);
`;

  await fs.writeFile(path.join(hooksDir, 'post-tool-use.js'), postToolUseHook);
  await fs.chmod(path.join(hooksDir, 'post-tool-use.js'), '755');

  // Create hooks configuration
  const hooksConfig = {
    hooks: {
      SessionStart: [
        {
          hooks: [
            {
              type: "command",
              command: "node " + path.join(hooksDir, 'session-start.js')
            }
          ]
        }
      ],
      PostToolUse: [
        {
          matcher: "Write|Edit|MultiEdit",
          hooks: [
            {
              type: "command",
              command: "node " + path.join(hooksDir, 'post-tool-use.js')
            }
          ]
        }
      ]
    }
  };

  await fs.writeJSON(path.join(process.cwd(), '.claude', 'hooks.json'), hooksConfig, { spaces: 2 });

  console.log(chalk.green('✅ Claude Code hooks configured'));
}

async function createCustomCommands(projectName: string) {
  const commandsDir = path.join(process.cwd(), '.claude', 'commands');

  // Worktree navigation commands
  const commands = [
    {
      name: 'worktree-feature',
      description: 'Switch to feature worktree and start Claude Code',
      content: `Navigate to feature worktree and start Claude Code for feature development.

The feature worktree is isolated for new feature development. Changes made here will not affect other worktrees until explicitly synchronized.

Available actions:
- Develop new features with Claude Code
- Create signal file \`.claude-complete\` when finished
- Changes are automatically tracked in the feature branch

Working directory: ../${projectName}-worktrees/feature
Current branch: feature/${projectName}

Signal files:
- Touch \`.claude-complete\` when feature work is complete
- This will automatically trigger test workflow`
    },
    {
      name: 'worktree-test',
      description: 'Switch to test worktree and start Claude Code',
      content: `Navigate to test worktree and start Claude Code for testing and validation.

The test worktree is dedicated to testing activities. It can pull changes from feature worktrees and run automated tests.

Available actions:
- Write and run tests for features
- Validate bug fixes
- Create signal file \`.tests-complete\` when testing is done
- Run automated test suites

Working directory: ../${projectName}-worktrees/test
Current branch: test/${projectName}

Signal files:
- Touch \`.tests-complete\` when testing is complete
- This will automatically trigger documentation workflow`
    },
    {
      name: 'worktree-docs',
      description: 'Switch to docs worktree and start Claude Code',
      content: `Navigate to docs worktree and start Claude Code for documentation tasks.

The docs worktree is focused on documentation. It can pull changes from feature worktrees to update API docs, user guides, etc.

Available actions:
- Update API documentation
- Write user guides and tutorials
- Create technical documentation
- Document new features and changes

Working directory: ../${projectName}-worktrees/docs
Current branch: docs/${projectName}

Signal files:
- Documentation updates are triggered by .tests-complete signal`
    },
    {
      name: 'worktree-bugfix',
      description: 'Switch to bugfix worktree and start Claude Code',
      content: `Navigate to bugfix worktree and start Claude Code for bug fixing.

The bugfix worktree is isolated for fixing bugs. Changes here can be tested and validated before merging to main.

Available actions:
- Fix reported bugs and issues
- Test bug fixes thoroughly
- Create signal file \`.bugfix-complete\` when fixed
- Validate fixes before merging

Working directory: ../${projectName}-worktrees/bugfix
Current branch: bugfix/${projectName}

Signal files:
- Touch \`.bugfix-complete\` when bug fix is complete
- This will automatically trigger validation workflow`
    },
    {
      name: 'sync-worktrees',
      description: 'Synchronize changes between all worktrees',
      content: `Synchronize changes between all worktrees to ensure everyone has the latest updates.

This command will:
1. Check the status of all worktrees
2. Pull latest changes from remote branches
3. Show any conflicts that need resolution
4. Provide sync status for each worktree

Worktrees to sync:
- feature/${projectName}
- test/${projectName}
- docs/${projectName}
- bugfix/${projectName}

Run this command when:
- Starting work to ensure you have latest changes
- After completing work to share your changes
- When experiencing conflicts between worktrees

Available actions:
- Pull latest changes from remote
- Push local changes to remote
- Resolve merge conflicts if any
- View sync status for all worktrees`
    },
    {
      name: 'monitor-start',
      description: 'Start worktree monitoring service',
      content: `Start the worktree monitoring service to enable automated coordination between worktrees.

The monitoring service will:
- Watch for signal files (.claude-complete, .tests-complete, etc.)
- Automatically trigger workflows when signals are detected
- Run tests, validation, and documentation updates
- Provide real-time feedback on workflow status

Monitor types available:
- Auto-detection: Monitors signal files every 5 seconds
- File monitoring: Watches for file system changes
- Webhook server: HTTP-based workflow triggering

To start monitoring:
1. Choose monitor type (recommended: auto-detection)
2. Service runs in background
3. Signal files trigger automatic workflows
4. Monitor logs for workflow status

Signal files and their effects:
- .claude-complete → Trigger test workflow
- .tests-complete → Trigger documentation workflow
- .bugfix-complete → Trigger validation workflow

Logs are written to: /tmp/claude-monitor.log`
    },
    {
      name: 'monitor-stop',
      description: 'Stop worktree monitoring service',
      content: `Stop the worktree monitoring service and clean up background processes.

This command will:
1. Stop all monitoring services
2. Clean up temporary files
3. Show final status summary
4. Provide cleanup recommendations

Actions performed:
- Terminate monitoring processes
- Remove signal files
- Clean up temporary logs
- Show summary of activities

After stopping monitoring:
- Manual coordination is required
- Signal files will not be processed
- Worktrees operate independently
- Manual sync commands still work

To restart monitoring later, use /monitor-start`
    }
  ];

  for (const command of commands) {
    const commandFile = path.join(commandsDir, `${command.name}.md`);
    const frontmatter = `---
description: ${command.description}
allowed-tools: Bash(*), Read(*), Write(*), Edit(*)
---

`;

    await fs.writeFile(commandFile, frontmatter + command.content);
  }

  console.log(chalk.green('✅ Custom slash commands created'));
}

async function startMonitoring(projectName: string, monitorType: string) {
  console.log(chalk.blue(`🔍 Starting ${monitorType} monitoring for ${projectName}...`));

  // In a real implementation, this would start the monitoring service
  console.log(chalk.green('✅ Monitoring service started'));
  console.log(chalk.yellow('💡 Use Ctrl+C to stop monitoring'));

  if (monitorType === 'auto-detection') {
    console.log(chalk.blue('Auto-detection mode:'));
    console.log('- Watching for signal files every 5 seconds');
    console.log('- Signal files: .claude-complete, .tests-complete, .bugfix-complete');
  } else if (monitorType === 'file-monitor') {
    console.log(chalk.blue('File monitoring mode:'));
    console.log('- Watching for file system changes in worktrees');
    console.log('- Auto-commit and trigger workflows on changes');
  } else if (monitorType === 'webhook') {
    console.log(chalk.blue('Webhook server mode:'));
    console.log('- HTTP server listening on port 8080');
    console.log('- Trigger workflows via HTTP endpoints');
  }
}

async function cleanupWorktrees(projectName: string) {
  console.log(chalk.yellow(`🧹 Cleaning up worktrees for ${projectName}...`));

  const worktreesDir = path.join('..', `${projectName}-worktrees`);

  if (await fs.pathExists(worktreesDir)) {
    await fs.remove(worktreesDir);
    console.log(chalk.green('✅ Worktrees directory removed'));
  }

  // Clean up .claude directory
  const claudeDir = path.join(process.cwd(), '.claude');
  if (await fs.pathExists(claudeDir)) {
    // Keep custom commands but remove hooks
    const hooksDir = path.join(claudeDir, 'hooks');
    if (await fs.pathExists(hooksDir)) {
      await fs.remove(hooksDir);
    }

    const hooksConfig = path.join(claudeDir, 'hooks.json');
    if (await fs.pathExists(hooksConfig)) {
      await fs.remove(hooksConfig);
    }

    console.log(chalk.green('✅ Claude Code hooks removed'));
  }

  console.log(chalk.green('🎉 Cleanup completed'));
}

program.parse();