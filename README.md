# Claude Code Multi-Worktree Helper

> 🚀 **Automated workflows for parallel Claude Code sessions using native Claude Code hooks and commands**

## ✨ What's New?

This project has been transformed into a proper npm package that leverages **Claude Code's native hooks and custom commands** for seamless workflow automation.

### Key Features

- 🎯 **Native Claude Code Integration**: Uses Claude Code's built-in hooks and slash commands
- 🔄 **Automated Workflows**: Signal file-based coordination between worktrees
- 📦 **npm Package**: Easy installation with `bunx ccmultihelper`
- 🔧 **Zero Configuration**: Auto-detects project setup and configures hooks
- 🎨 **Interactive CLI**: User-friendly command-line interface

## 🚀 Quick Start

### 1. Install and Initialize

```bash
# Navigate to your Git repository
cd /path/to/your/project

# Initialize multi-worktree setup
bunx ccmultihelper init
```

### 2. Choose Setup Options

The CLI will guide you through:
- Project naming
- Auto-setup preferences
- Claude Code hooks configuration
- Custom commands creation

### 3. Start Using Worktrees

```bash
# Use native Claude Code slash commands
claude

# In Claude Code session:
> /worktree-feature     # Switch to feature worktree
> /worktree-test        # Switch to test worktree
> /sync-worktrees       # Synchronize all worktrees
> /status-worktrees     # View worktree status
> /create-signal claude-complete  # Trigger workflows
```

## 🛠️ Commands

### CLI Commands

```bash
# Initialize setup
bunx ccmultihelper init [-p project-name] [-a]

# Setup Claude Code hooks
bunx ccmultihelper setup-hooks

# Create custom slash commands
bunx ccmultihelper create-commands

# Start monitoring service
bunx ccmultihelper start-monitor [-t auto-detect|file-monitor|webhook]

# Clean up everything
bunx ccmultihelper cleanup
```

### Claude Code Slash Commands

Once initialized, you'll have these slash commands available in Claude Code:

#### Worktree Navigation
- `/worktree-feature` - Navigate to feature worktree
- `/worktree-test` - Navigate to test worktree
- `/worktree-docs` - Navigate to docs worktree
- `/worktree-bugfix` - Navigate to bugfix worktree

#### Workflow Management
- `/sync-worktrees` - Synchronize changes between worktrees
- `/status-worktrees` - Show status of all worktrees
- `/create-signal <type>` - Create signal files for workflow coordination
- `/monitor-start` - Start worktree monitoring
- `/monitor-stop` - Stop worktree monitoring

## 🤖 How It Works

### Native Claude Code Integration

This package leverages Claude Code's native capabilities:

#### **Hooks System**
- **SessionStart Hook**: Injects worktree context when Claude Code starts
- **PostToolUse Hook**: Coordinates workflows between worktrees automatically
- **UserPromptSubmit Hook**: Enhances prompts with worktree context

#### **Custom Commands**
- **Slash Commands**: Native Claude Code command system
- **Dynamic Context**: Commands automatically gather current project status
- **Tool Integration**: Commands have access to git, file system, and other tools

### Automated Workflow Coordination

The system uses **signal files** to coordinate workflows:

1. **Feature Development** → Create `.claude-complete` signal
2. **Auto-Detection** → Hooks detect signal and trigger test workflow
3. **Testing** → Create `.tests-complete` signal
4. **Documentation** → Auto-trigger documentation updates
5. **Validation** → Bug fixes are automatically validated

### Example Workflow

```bash
# 1. Initialize
bunx ccmultihelper init --auto-setup

# 2. Start Claude Code
claude

# 3. Work in feature worktree
> /worktree-feature
# Claude develops feature...

# 4. Signal completion (Claude can do this automatically)
touch .claude-complete

# 5. Auto-coordination begins:
#    → Test workflow triggers automatically
#    → Tests run in test worktree
#    → Documentation workflow triggers
#    → Documentation updates in docs worktree
```

## 📁 Project Structure

After initialization, your project will have:

```
.your-project/
├── .claude/
│   ├── commands/
│   │   ├── worktree-feature.md
│   │   ├── worktree-test.md
│   │   ├── worktree-docs.md
│   │   ├── worktree-bugfix.md
│   │   ├── sync-worktrees.md
│   │   ├── status-worktrees.md
│   │   └── create-signal.md
│   ├── hooks/
│   │   ├── session-start.js
│   │   ├── post-tool-use.js
│   │   └── user-prompt-submit.js
│   └── hooks.json
├── ../your-project-worktrees/
│   ├── feature/    # Feature development
│   ├── test/       # Testing & validation
│   ├── docs/       # Documentation
│   └── bugfix/     # Bug fixes
└── ...
```

## 🔧 Configuration

### Worktree Configuration

The system creates `.claude/worktree-config.json`:

```json
{
  "projectName": "your-project",
  "worktrees": ["feature", "test", "docs", "bugfix"],
  "autoSync": true,
  "monitoring": false
}
```

### Hooks Configuration

Claude Code hooks are configured in `.claude/hooks.json`:

```json
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
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/hooks/post-tool-use.js"
          }
        ]
      }
    ]
  }
}
```

## 🚀 Advanced Usage

### Custom Signal Types

You can extend the system with custom signal types:

```bash
# Create custom signal
> /create-signal custom-signal-type

# The system will process it based on your workflow
```

### Monitoring Modes

Choose from three monitoring modes:

- **Auto-Detection**: Monitors signal files every 5 seconds (recommended)
- **File Monitor**: Watches for file system changes in real-time
- **Webhook Server**: HTTP-based workflow triggering

### Integration with CI/CD

The signal files can be integrated with CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Trigger test workflow
  run: |
    touch .claude-complete
    # Wait for automated workflow to complete
```

## 📈 Benefits Over Previous Version

### **vs External Scripts**
- ✅ **Native Integration**: Uses Claude Code's built-in hooks system
- ✅ **Better Performance**: No external process monitoring needed
- ✅ **Seamless Experience**: Works within Claude Code's native interface
- ✅ **Context Awareness**: Commands have access to full project context

### **vs Manual Worktree Management**
- ✅ **Automated Coordination**: Signal files handle workflow triggering
- ✅ **Smart Sync**: Intelligent worktree synchronization
- ✅ **Status Tracking**: Real-time worktree status monitoring
- ✅ **Error Handling**: Robust error handling and recovery

## 🧹 Troubleshooting

### Common Issues

**Hooks not working:**
```bash
# Check Claude Code configuration
cat ~/.claude/config.json

# Verify hooks are properly installed
ls -la .claude/hooks/
```

**Commands not available:**
```bash
# Restart Claude Code to pick up new commands
# Check command files exist
ls -la .claude/commands/
```

**Worktree sync issues:**
```bash
# Check worktree status
git worktree list

# Use the status command
> /status-worktrees
```

### Debug Mode

Enable debug logging:

```bash
# Check workflow logs
cat /tmp/claude-worktree-workflows.log

# Check Claude Code debug output
claude --debug
```

## 🎯 Roadmap

- [ ] VS Code extension integration
- [ ] Web dashboard for monitoring
- [ ] Advanced workflow templates
- [ ] Team collaboration features
- [ ] GitHub Actions integration

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Inspired by official Claude Code worktree patterns
- Enhanced with native hooks and custom commands

---

**Built with ❤️ for the Claude Code community**