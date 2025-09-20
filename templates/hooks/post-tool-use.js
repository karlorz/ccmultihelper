#!/usr/bin/env node
// PostToolUse Hook - Auto-coordinate worktree workflows
import { readFileSync, existsSync, writeFileSync, unlinkSync } from 'fs';
import { spawn } from 'child_process';
import { join } from 'path';

const input = JSON.parse(readFileSync(0, 'utf8'));
const { tool_name, tool_input } = input;
const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();

// Load configuration
const configPath = join(projectDir, '.claude', 'worktree-config.json');
let config = {
  projectName: 'unknown',
  worktrees: ['feature', 'test', 'docs', 'bugfix'],
  autoSync: true,
  monitoring: false
};

if (existsSync(configPath)) {
  try {
    const configData = readFileSync(configPath, 'utf8');
    config = { ...config, ...JSON.parse(configData) };
  } catch (error) {
    // Config reading failed, use defaults
  }
}

// Function to run command asynchronously
function runCommand(command, args = [], cwd = projectDir) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, stdio: 'pipe' });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(`Command failed with code ${code}: ${stderr}`));
      }
    });

    child.on('error', (error) => {
      reject(error);
    });
  });
}

// Function to log workflow events
function logWorkflowEvent(event, details) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    event,
    details,
    project: config.projectName
  };

  const logPath = join('/tmp', 'claude-worktree-workflows.log');
  try {
    writeFileSync(logPath, JSON.stringify(logEntry) + '\n', { flag: 'a' });
  } catch (error) {
    console.error('Failed to log workflow event:', error);
  }
}

// Check for signal files and trigger workflows
async function checkAndProcessSignals() {
  const worktreesDir = join('..', `${config.projectName}-worktrees`);

  const signals = [
    {
      file: 'feature/.claude-complete',
      action: 'trigger-tests',
      message: 'Feature work completed, triggering test workflow'
    },
    {
      file: 'test/.tests-complete',
      action: 'trigger-docs',
      message: 'Testing completed, triggering documentation workflow'
    },
    {
      file: 'bugfix/.bugfix-complete',
      action: 'trigger-validation',
      message: 'Bugfix completed, triggering validation workflow'
    }
  ];

  for (const signal of signals) {
    const signalPath = join(worktreesDir, signal.file);

    if (existsSync(signalPath)) {
      try {
        logWorkflowEvent('signal_detected', { signal: signal.file, action: signal.action });
        console.log(JSON.stringify({
          hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: `🔄 ${signal.message}`
          }
        }));

        // Process the signal
        await processSignal(signal, worktreesDir);

        // Remove the signal file after processing
        unlinkSync(signalPath);
        logWorkflowEvent('signal_processed', { signal: signal.file });

        break; // Process one signal at a time
      } catch (error) {
        console.error('Error processing signal:', error);
        logWorkflowEvent('signal_error', { signal: signal.file, error: error.message });
      }
    }
  }
}

// Process individual signals
async function processSignal(signal, worktreesDir) {
  switch (signal.action) {
    case 'trigger-tests':
      await triggerTestWorkflow(worktreesDir);
      break;
    case 'trigger-docs':
      await triggerDocsWorkflow(worktreesDir);
      break;
    case 'trigger-validation':
      await triggerValidationWorkflow(worktreesDir);
      break;
  }
}

// Trigger test workflow
async function triggerTestWorkflow(worktreesDir) {
  logWorkflowEvent('workflow_started', { workflow: 'test' });

  try {
    const testWorktree = join(worktreesDir, 'test');

    if (existsSync(testWorktree)) {
      // Pull latest changes from feature branch
      await runCommand('git', ['pull', 'origin', `feature/${config.projectName}`], testWorktree);

      // Run tests if package.json exists
      if (existsSync(join(testWorktree, 'package.json'))) {
        await runCommand('npm', ['test'], testWorktree);
      }

      // Create test completion signal
      writeFileSync(join(testWorktree, '.tests-complete'), '');

      logWorkflowEvent('workflow_completed', { workflow: 'test' });
    }
  } catch (error) {
    logWorkflowEvent('workflow_failed', { workflow: 'test', error: error.message });
  }
}

// Trigger documentation workflow
async function triggerDocsWorkflow(worktreesDir) {
  logWorkflowEvent('workflow_started', { workflow: 'docs' });

  try {
    const docsWorktree = join(worktreesDir, 'docs');

    if (existsSync(docsWorktree)) {
      // Pull latest changes from feature branch
      await runCommand('git', ['pull', 'origin', `feature/${config.projectName}`], docsWorktree);

      // Create documentation needed signal
      writeFileSync(join(docsWorktree, '.docs-needed'), 'Documentation update needed for feature changes');

      logWorkflowEvent('workflow_completed', { workflow: 'docs' });
    }
  } catch (error) {
    logWorkflowEvent('workflow_failed', { workflow: 'docs', error: error.message });
  }
}

// Trigger validation workflow
async function triggerValidationWorkflow(worktreesDir) {
  logWorkflowEvent('workflow_started', { workflow: 'validation' });

  try {
    const testWorktree = join(worktreesDir, 'test');

    if (existsSync(testWorktree)) {
      // Pull latest changes from bugfix branch
      await runCommand('git', ['pull', 'origin', `bugfix/${config.projectName}`], testWorktree);

      // Run validation tests
      if (existsSync(join(testWorktree, 'package.json'))) {
        await runCommand('npm', ['test'], testWorktree);
      }

      // If tests pass, create validation complete signal
      writeFileSync(join(testWorktree, '.validation-complete'), '');

      logWorkflowEvent('workflow_completed', { workflow: 'validation' });
    }
  } catch (error) {
    logWorkflowEvent('workflow_failed', { workflow: 'validation', error: error.message });
  }
}

// Main execution
if (tool_name === 'Write' || tool_name === 'Edit' || tool_name === 'MultiEdit') {
  checkAndProcessSignals().catch(error => {
    console.error('Error in signal processing:', error);
  });
}

// Allow tool execution to continue
process.exit(0);