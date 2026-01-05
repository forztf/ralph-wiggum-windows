# Ralph Wiggum Plugin for Windows

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-purple.svg)](https://claude.ai/code)

A Windows-compatible [Claude Code](https://claude.ai/code) plugin implementing the **Ralph Wiggum technique** - iterative, self-referential AI development loops using PowerShell.

> *"Me fail English? That's unpossible!"* - Ralph Wiggum

## What is the Ralph Wiggum Technique?

The Ralph Wiggum technique, pioneered by [Geoffrey Huntley](https://ghuntley.com/ralph/), is an iterative development methodology based on continuous AI loops:

```powershell
while ($true) {
  Get-Content PROMPT.md | claude --continue
}
```

**Core concept**: The same prompt is fed to Claude repeatedly. Claude sees its own previous work in files and git history, allowing it to iteratively improve until the task is complete.

### How It Works

1. You start a Ralph loop with a task prompt
2. Claude works on the task, modifying files
3. When Claude tries to exit, the **stop hook intercepts**
4. The **same prompt** is fed back to Claude
5. Claude sees its previous work and continues improving
6. Loop continues until completion criteria are met

## Installation

```powershell
/plugin marketplace add forztf/ralph-wiggum-windows
/plugin install ralph-wiggum-windows@forztf-marketplace
```



### Verify Installation

After installation, you should see these commands available in Claude Code:
- `/ralph-wiggum-windows:ralph-loop` - Start a Ralph loop
- `/ralph-wiggum-windows:cancel-ralph` - Cancel active loop
- `/ralph-wiggum-windows:help` - Show help

## Quick Start

```
/ralph-wiggum-windows:ralph-loop "Build a REST API for todos with CRUD operations, validation, and tests" --completion-promise "API COMPLETE" --max-iterations 30
```

## Commands

### `/ralph-wiggum-windows:ralph-loop`

Start a Ralph loop in your current session.

**Usage:**
```
/ralph-wiggum-windows:ralph-loop "<prompt>" [--max-iterations N] [--completion-promise "<text>"]
```

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `--max-iterations <n>` | Maximum iterations before auto-stop | unlimited |
| `--completion-promise <text>` | Phrase that signals successful completion | none |

**Examples:**
```
# Run until "DONE" is achieved, max 50 iterations
/ralph-wiggum-windows:ralph-loop "Refactor the cache layer for better performance" --completion-promise "DONE" --max-iterations 50

# Run for exactly 10 iterations
/ralph-wiggum-windows:ralph-loop "Explore optimization opportunities" --max-iterations 10

# Run indefinitely (use with caution!)
/ralph-wiggum-windows:ralph-loop "Continuously improve test coverage"
```

### `/ralph-wiggum-windows:cancel-ralph`

Cancel an active Ralph loop immediately.

```
/ralph-wiggum-windows:cancel-ralph
```

### `/ralph-wiggum-windows:help`

Display comprehensive help about the Ralph Wiggum technique and all available commands.

```
/ralph-wiggum-windows:help
```

## Completion Promises

To signal that a task is complete, Claude must output a `<promise>` tag:

```
<promise>TASK COMPLETE</promise>
```

**Important rules:**
- The promise text must match exactly what you specified in `--completion-promise`
- Claude should only output the promise when the statement is genuinely true
- The stop hook specifically looks for `<promise>...</promise>` tags

## Monitoring Your Loop

While a Ralph loop is running, you can check its status:

```powershell
# View current iteration
Select-String '^iteration:' .claude/ralph-loop.local.md

# View full state
Get-Content .claude/ralph-loop.local.md -Head 10
```

## When to Use Ralph

### Good Use Cases

- **Well-defined tasks** with clear success criteria
- **Iterative development** requiring refinement cycles
- **Greenfield projects** where Claude can build incrementally
- **Refactoring tasks** with measurable outcomes
- **Test coverage** improvements

### Not Recommended For

- Tasks requiring human judgment or design decisions
- One-shot operations (just use Claude normally)
- Tasks with unclear or subjective success criteria
- Debugging production issues (need human oversight)
- Tasks where you need to provide frequent feedback

## Windows Compatibility

This fork was created specifically for Windows users. The [original Ralph Wiggum plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) uses bash/jq which don't work natively on Windows.

**Changes from the original:**
| Original (Unix) | This Fork (Windows) |
|-----------------|---------------------|
| `stop-hook.sh` | `stop-hook.ps1` |
| `jq` for JSON parsing | `ConvertFrom-Json` |
| bash scripts | PowerShell scripts |
| Unix path conventions | Windows path conventions |

## File Structure

```
ralph-wiggum-windows/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/
│   ├── cancel-ralph.md      # /cancel-ralph command
│   ├── help.md              # /help command
│   └── ralph-loop.md        # /ralph-loop command
├── hooks/
│   └── stop-hook.ps1        # Stop hook (PowerShell)
├── scripts/
│   └── setup-ralph-loop.ps1 # Setup script (PowerShell)
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

## Troubleshooting

### Loop not starting
- Verify the plugin is installed in `~/.claude/plugins/ralph-wiggum-windows`
- Check that `plugin.json` exists in `.claude-plugin/`
- Restart Claude Code

### Loop not stopping
- Use `/ralph-wiggum-windows:cancel-ralph` to force stop
- Manually delete `.claude/ralph-loop.local.md` in your project directory

### PowerShell execution policy errors
Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Credits

- **Original technique**: [Geoffrey Huntley](https://ghuntley.com/ralph/)
- **Original plugin**: [Anthropic Claude Code team](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
- **Windows fork**: CloudBuild Team

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Links

- [Ralph Wiggum Technique (ghuntley.com)](https://ghuntley.com/ralph/)
- [Original Ralph Wiggum Plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Windows compatibility issue #14817](https://github.com/anthropics/claude-code/issues/14817)
