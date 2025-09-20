#!/usr/bin/env node
// UserPromptSubmit Hook - Validate and enhance user prompts for worktree workflows
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const input = JSON.parse(readFileSync(0, 'utf8'));
const { prompt } = input;
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

// Check if prompt is asking for worktree-related help
const worktreeKeywords = [
  'worktree', 'sync', 'monitor', 'signal', 'workflow',
  'feature', 'test', 'docs', 'bugfix', 'claude-complete',
  'tests-complete', 'bugfix-complete'
];

const hasWorktreeKeyword = worktreeKeywords.some(keyword =>
  prompt.toLowerCase().includes(keyword)
);

if (hasWorktreeKeyword) {
  // Add worktree context to the prompt
  const additionalContext = `

📋 Multi-Worktree Context:
Project: ${config.projectName}
Active worktrees: ${config.worktrees.join(', ')}

Available slash commands:
- /worktree-feature - Navigate to feature worktree
- /worktree-test - Navigate to test worktree
- /worktree-docs - Navigate to docs worktree
- /worktree-bugfix - Navigate to bugfix worktree
- /sync-worktrees - Synchronize changes between worktrees
- /monitor-start - Start worktree monitoring
- /monitor-stop - Stop worktree monitoring
- /status-worktrees - Show worktree status

Signal files for automated workflows:
- .claude-complete - Feature work completed (triggers tests)
- .tests-complete - Tests completed (triggers documentation)
- .bugfix-complete - Bugfix completed (triggers validation)
- .docs-needed - Documentation updates needed

Current working directory: ${process.cwd()}
Project root: ${projectDir}

Tips:
- Use signal files to coordinate automated workflows
- Worktrees are isolated, use sync commands to share changes
- Monitoring can be started for automated coordination
- Each worktree has its own Git branch and working directory`;

  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext
    }
  }));
}

// Allow prompt processing to continue
process.exit(0);