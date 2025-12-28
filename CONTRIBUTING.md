# Contributing to Ralph Wiggum Windows

Thank you for your interest in contributing to the Ralph Wiggum Windows plugin!

## How to Contribute

### Reporting Issues

1. Check if the issue already exists in [GitHub Issues](https://github.com/Arthur742Ramos/ralph-wiggum-windows/issues)
2. If not, create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Windows version and PowerShell version
   - Claude Code version

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test thoroughly on Windows
5. Commit with clear messages: `git commit -m "Add feature X"`
6. Push to your fork: `git push origin feature/your-feature-name`
7. Open a Pull Request

### Code Guidelines

- **PowerShell**: Follow [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- **Error Handling**: Use `$ErrorActionPreference = "Stop"` and try/catch blocks
- **Comments**: Document complex logic
- **Testing**: Test on multiple Windows versions if possible

### Plugin Structure

```
.claude-plugin/plugin.json  - Plugin manifest (name, version, description)
commands/*.md               - Slash command definitions
hooks/*.ps1                 - PowerShell hooks (stop-hook.ps1)
scripts/*.ps1               - Helper scripts
```

### Testing Your Changes

1. Copy your modified plugin to `~/.claude/plugins/ralph-wiggum-windows`
2. Restart Claude Code
3. Test all commands:
   - `/ralph-wiggum:help`
   - `/ralph-wiggum:ralph-loop "test task" --max-iterations 2`
   - `/ralph-wiggum:cancel-ralph`

## Questions?

Feel free to open an issue for questions or discussions!
