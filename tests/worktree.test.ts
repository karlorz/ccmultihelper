import { test, expect, beforeEach, afterEach } from 'bun:test';
import fs from 'fs-extra';
import { execSync } from 'child_process';
import { mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join, dirname } from 'path';

// Helper function to validate project name for tests
function validateProjectName(name: string): boolean {
  // Basic validation to prevent path traversal and injection
  const safePattern = /^[a-zA-Z0-9_-]+$/;
  return safePattern.test(name) && name.length > 0 && name.length <= 50;
}

// Helper function to create a test git repository
function createTestRepo(projectName: string): string {
  if (!validateProjectName(projectName)) {
    throw new Error(`Invalid project name: ${projectName}`);
  }

  const tempDir = mkdtempSync(join(tmpdir(), 'ccm-test-'));
  const repoPath = join(tempDir, projectName);

  // Create the directory first
  fs.ensureDirSync(repoPath);

  try {
    // Initialize git repo
    execSync('git init', { cwd: repoPath });
    execSync('git config user.name "Test User"', { cwd: repoPath });
    execSync('git config user.email "test@example.com"', { cwd: repoPath });

    // Create initial commit
    fs.writeFileSync(join(repoPath, 'README.md'), `# ${projectName}\n`);
    execSync('git add README.md', { cwd: repoPath });
    execSync('git commit -m "Initial commit"', { cwd: repoPath });

    return repoPath;
  } catch (error) {
    // Clean up on failure
    if (fs.existsSync(repoPath)) {
      fs.removeSync(repoPath);
    }
    throw error;
  }
}

// Helper function to run the CLI with timeout protection
function runCLI(repoPath: string, args: string[] = []): { stdout: string; stderr: string; code: number | null } {
  try {
    const cliPath = join(process.cwd(), 'dist', 'cli.js');

    // Check if CLI exists
    if (!fs.existsSync(cliPath)) {
      throw new Error(`CLI not found at: ${cliPath}`);
    }

    // Set timeout for child process (30 seconds)
    const timeout = 30000;
    const result = execSync(`node ${cliPath} ${args.join(' ')}`, {
      cwd: repoPath,
      encoding: 'utf8',
      stdio: 'pipe',
      timeout: timeout
    });
    return { stdout: result, stderr: '', code: 0 };
  } catch (error: any) {
    if (error.signal === 'SIGTERM') {
      return {
        stdout: '',
        stderr: `Command timed out after 30 seconds`,
        code: 124 // Timeout exit code
      };
    }
    return {
      stdout: error.stdout || '',
      stderr: error.stderr || error.message || '',
      code: error.status || 1
    };
  }
}

// Helper function to clean up worktrees with improved error handling
function cleanupWorktrees(repoPath: string, projectName: string) {
  const worktreesDir = join(dirname(repoPath), `${projectName}-worktrees`);

  if (!fs.existsSync(repoPath)) {
    return; // Repository already cleaned up
  }

  // Clean up worktrees
  try {
    // Get list of worktrees
    const worktreeList = execSync('git worktree list', { cwd: repoPath, encoding: 'utf8' });
    const worktrees = worktreeList.split('\n')
      .filter(line => line.includes('-worktrees/'))
      .map(line => line.split(' ')[0])
      .filter(Boolean);

    // Remove each worktree with retries
    for (const worktreePath of worktrees) {
      let attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        try {
          if (fs.existsSync(worktreePath)) {
            execSync(`git worktree remove --force ${worktreePath}`, {
              cwd: repoPath,
              stdio: 'pipe',
              timeout: 10000
            });
          }
          break;
        } catch (error) {
          attempts++;
          if (attempts === maxAttempts) {
            console.warn(`Warning: Failed to remove worktree ${worktreePath}: ${error.message}`);
          } else {
            // Wait before retry
            const startTime = Date.now();
            while (Date.now() - startTime < 1000) {
              // Small delay
            }
          }
        }
      }
    }

    // Clean up git worktree list
    try {
      execSync('git worktree prune', {
        cwd: repoPath,
        stdio: 'pipe',
        timeout: 10000
      });
    } catch (error) {
      console.warn(`Warning: Failed to prune worktree list: ${error.message}`);
    }

    // Remove worktrees directory with force
    if (fs.existsSync(worktreesDir)) {
      try {
        fs.removeSync(worktreesDir);
      } catch (error) {
        console.warn(`Warning: Failed to remove worktrees directory: ${error.message}`);
      }
    }
  } catch (error) {
    console.warn(`Warning: Error during worktree cleanup: ${error.message}`);
  }

  // Clean up Git configuration
  try {
    if (fs.existsSync(join(repoPath, '.git'))) {
      execSync('git config --local --unset user.name', { cwd: repoPath, stdio: 'pipe' });
      execSync('git config --local --unset user.email', { cwd: repoPath, stdio: 'pipe' });
    }
  } catch {
    // Ignore git config cleanup errors
  }
}

let testRepo: string;
const testProjectName = 'test-project';

beforeEach(() => {
  testRepo = createTestRepo(testProjectName);
});

afterEach(() => {
  if (testRepo) {
    cleanupWorktrees(testRepo, testProjectName);
    rmSync(dirname(testRepo), { recursive: true, force: true });
  }
});

test('CLI init creates proper Git worktrees', () => {
  const result = runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  expect(result.code).toBe(0);
  expect(result.stdout).toContain('Git worktrees created');
  expect(result.stdout).toContain('Setup completed successfully');
});

test('Git worktrees are properly registered', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const worktreeList = execSync('git worktree list', { cwd: testRepo, encoding: 'utf8' });

  expect(worktreeList).toContain(`feature/${testProjectName}`);
  expect(worktreeList).toContain(`test/${testProjectName}`);
  expect(worktreeList).toContain(`docs/${testProjectName}`);
  expect(worktreeList).toContain(`bugfix/${testProjectName}`);
});

test('Worktree directories contain actual project files', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const worktreesDir = join(dirname(testRepo), `${testProjectName}-worktrees`);

  // Check each worktree contains README.md
  const worktrees = ['feature', 'test', 'docs', 'bugfix'];
  for (const worktree of worktrees) {
    const readmePath = join(worktreesDir, worktree, 'README.md');
    expect(fs.existsSync(readmePath)).toBe(true);

    const launchScriptPath = join(worktreesDir, worktree, 'launch-claude.sh');
    expect(fs.existsSync(launchScriptPath)).toBe(true);

    // Verify launch script content
    const launchScript = fs.readFileSync(launchScriptPath, 'utf8');
    expect(launchScript).toContain('#!/bin/bash');
    expect(launchScript).toContain('echo "Current branch: $(git branch --show-current)"');
    expect(launchScript).toContain('echo "Worktree path: $(pwd)"');
  }
});

test('Worktrees are on correct branches', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const worktreesDir = join(dirname(testRepo), `${testProjectName}-worktrees`);

  // Test feature worktree
  const featureBranch = execSync('git branch --show-current', {
    cwd: join(worktreesDir, 'feature'),
    encoding: 'utf8'
  }).trim();
  expect(featureBranch).toBe(`feature/${testProjectName}`);

  // Test worktree
  const testBranch = execSync('git branch --show-current', {
    cwd: join(worktreesDir, 'test'),
    encoding: 'utf8'
  }).trim();
  expect(testBranch).toBe(`test/${testProjectName}`);
});

test('Worktrees can make independent commits', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const worktreesDir = join(dirname(testRepo), `${testProjectName}-worktrees`);
  const featurePath = join(worktreesDir, 'feature');

  // Make a commit in feature worktree
  fs.writeFileSync(join(featurePath, 'feature-file.txt'), 'Feature content');
  execSync('git add feature-file.txt', { cwd: featurePath });
  execSync('git commit -m "Add feature file"', { cwd: featurePath });

  // Verify the commit exists in feature branch
  const featureLog = execSync('git log --oneline', { cwd: featurePath, encoding: 'utf8' });
  expect(featureLog).toContain('Add feature file');

  // Verify the commit doesn't exist in main worktree
  const mainLog = execSync('git log --oneline', { cwd: testRepo, encoding: 'utf8' });
  expect(mainLog).not.toContain('Add feature file');
});

test('CLI creates .claude directory structure', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const claudeDir = join(testRepo, '.claude');
  expect(fs.existsSync(claudeDir)).toBe(true);
  expect(fs.existsSync(join(claudeDir, 'commands'))).toBe(true);
  expect(fs.existsSync(join(claudeDir, 'hooks'))).toBe(true);
});

test('Error handling for invalid project names', () => {
  // Test project name with path traversal
  const result = runCLI(testRepo, ['init', '--legacy', '--project-name', '../malicious', '--auto-setup']);
  expect(result.code).not.toBe(0);
  expect(result.stderr).toContain('Invalid project name');
});

test('Error handling for existing worktrees', () => {
  // Run init twice
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);
  const result = runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  // Should handle gracefully with warnings
  expect(result.stdout).toContain('Failed to create');
  expect(result.stdout).toContain('Setup completed successfully');
});

test('Launch scripts are executable', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const worktreesDir = join(dirname(testRepo), `${testProjectName}-worktrees`);
  const launchScript = join(worktreesDir, 'feature', 'launch-claude.sh');

  // Check file permissions (cross-platform compatible)
  const stats = fs.statSync(launchScript);

  // On Unix-like systems, check for execute permission
  if (process.platform !== 'win32') {
    expect(stats.mode & 0o111).toBeGreaterThan(0); // Has execute permission
  } else {
    // On Windows, just verify the file exists and has content
    expect(fs.existsSync(launchScript)).toBe(true);
    const content = fs.readFileSync(launchScript, 'utf8');
    expect(content.length).toBeGreaterThan(0);
  }
});

test('Worktree branch naming convention', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const worktreeList = execSync('git worktree list', { cwd: testRepo, encoding: 'utf8' });

  // Verify branch naming follows convention: <type>/<project-name>
  expect(worktreeList).toMatch(/feature\/test-project/);
  expect(worktreeList).toMatch(/test\/test-project/);
  expect(worktreeList).toMatch(/docs\/test-project/);
  expect(worktreeList).toMatch(/bugfix\/test-project/);
});

test('Worktree paths are correct', () => {
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  const expectedWorktreesDir = join(dirname(testRepo), `${testProjectName}-worktrees`);
  const worktreeList = execSync('git worktree list', { cwd: testRepo, encoding: 'utf8' });

  // Verify worktree paths are correct
  expect(worktreeList).toContain(join(expectedWorktreesDir, 'feature'));
  expect(worktreeList).toContain(join(expectedWorktreesDir, 'test'));
  expect(worktreeList).toContain(join(expectedWorktreesDir, 'docs'));
  expect(worktreeList).toContain(join(expectedWorktreesDir, 'bugfix'));
});

test('No duplicate branches created on re-init', () => {
  // Initial setup
  runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  // Get initial branch count
  const initialBranches = execSync('git branch -a', { cwd: testRepo, encoding: 'utf8' });

  // Re-initialize
  const result = runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  // Should handle gracefully
  expect(result.code).toBe(0) || expect(result.stdout).toContain('Failed');

  // Check branch count (shouldn't create duplicates)
  const finalBranches = execSync('git branch -a', { cwd: testRepo, encoding: 'utf8' });
  expect(finalBranches.split('\n').length).toBeLessThanOrEqual(initialBranches.split('\n').length + 4);
});

test('Worktree cleanup on failure', () => {
  // Create a directory that would conflict with worktree creation
  const worktreesDir = join(dirname(testRepo), `${testProjectName}-worktrees`);
  fs.ensureDirSync(join(worktreesDir, 'feature'));

  // Run init (should handle existing directories)
  const result = runCLI(testRepo, ['init', '--legacy', '--project-name', testProjectName, '--auto-setup']);

  // Should still succeed or fail gracefully
  expect(result.code === 0 || result.stdout.includes('Failed')).toBe(true);
});