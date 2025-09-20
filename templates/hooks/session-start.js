#!/usr/bin/env node
// SessionStart Hook - Initialize worktree context
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const projectName = process.env.CLAUDE_PROJECT_NAME || 'unknown';

// Load configuration
const configPath = join(projectDir, '.claude', 'worktree-config.json');
let config = {
  projectName,
  worktrees: ['feature', 'test', 'docs', 'bugfix'],
  autoSync: true,
  monitoring: false
};

if (existsSync(configPath)) {
  try {
    const configData = readFileSync(configPath, 'utf8');
    config = { ...config, ...JSON.parse(configData) };
  } catch (error) {
    console.error('Error reading config:', error);
  }
}

const additionalContext = `🔄 Multi-Worktree Setup Active
Project: ${config.projectName}
Worktrees: ${config.worktrees.join(', ')}

Available slash commands:
- /worktree-feature - Work in feature worktree
- /worktree-test - Work in test worktree
- /worktree-docs - Work in docs worktree
- /worktree-bugfix - Work in bugfix worktree
- /sync-worktrees - Sync changes between worktrees
- /monitor-start - Start worktree monitoring
- /monitor-stop - Stop worktree monitoring
- /status-worktrees - Show worktree status

Signal files for workflow coordination:
- .claude-complete - Feature work completed
- .tests-complete - Tests completed
- .bugfix-complete - Bugfix completed
- .docs-needed - Documentation updates needed

Auto-sync: ${config.autoSync ? 'Enabled' : 'Disabled'}
Monitoring: ${config.monitoring ? 'Active' : 'Inactive'}

Use these signal files to coordinate automated workflows between worktrees. When you complete work in one worktree, create the appropriate signal file to trigger the next workflow stage.`;

console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext
  }
}));