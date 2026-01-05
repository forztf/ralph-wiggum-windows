# Windows 版 Ralph Wiggum 插件

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-purple.svg)](https://claude.ai/code)

一个与 Windows 兼容的 [Claude Code](https://claude.ai/code) 插件，实现了 **Ralph Wiggum 技术** - 使用 PowerShell 的迭代式、自引用 AI 开发循环。

> *"我英语不及格？那是不可能的！"* - Ralph Wiggum

## 什么是 Ralph Wiggum 技术？

Ralph Wiggum 技术是由 [Geoffrey Huntley](https://ghuntley.com/ralph/) 开创的迭代开发方法论，基于连续的 AI 循环：

```powershell
while ($true) {
  Get-Content PROMPT.md | claude --continue
}
```

**核心概念**：相同的提示词会重复地提供给 Claude。Claude 在文件和 git 历史记录中看到自己之前的工作，从而能够迭代改进直到任务完成。

### 工作原理

1. 你使用任务提示词启动 Ralph 循环
2. Claude 处理任务，修改文件
3. 当 Claude 尝试退出时，**停止钩子会拦截**
4.**相同的提示词**再次提供给 Claude
5. Claude 看到之前的工作并继续改进
6. 循环持续直到满足完成条件

## 安装

```powershell
/plugin marketplace add forztf/ralph-wiggum-windows
/plugin install ralph-wiggum-windows@forztf-marketplace
```

### 验证安装

安装后，你应该在 Claude Code 中看到这些命令可用：
- `/ralph-wiggum-windows:windows:ralph-loop` - 启动 Ralph 循环
- `/ralph-wiggum-windows:windows:cancel-ralph` - 取消活动循环
- `/ralph-wiggum-windows:windows:help` - 显示帮助

## 快速开始

```
/ralph-wiggum-windows:windows:ralph-loop "构建一个待办事项 REST API，包含 CRUD 操作、验证和测试" --completion-promise "API COMPLETE" --max-iterations 30
```

## 命令

### `/ralph-wiggum-windows:windows:ralph-loop`

在当前会话中启动 Ralph 循环。

**用法：**
```
/ralph-wiggum-windows:windows:ralph-loop "<提示词>" [--max-iterations N] [--completion-promise "<文本>"]
```

**选项：**
| 选项 | 描述 | 默认值 |
|--------|-------------|---------|
| `--max-iterations <n>` | 自动停止前的最大迭代次数 | 无限制 |
| `--completion-promise <text>` | 表示成功完成的短语 | 无 |

**示例：**
```
# 运行直到完成 "DONE"，最多 50 次迭代
/ralph-wiggum-windows:windows:ralph-loop "重构缓存层以提高性能" --completion-promise "DONE" --max-iterations 50

# 精确运行 10 次迭代
/ralph-wiggum-windows:windows:ralph-loop "探索优化机会" --max-iterations 10

# 无限期运行（谨慎使用！）
/ralph-wiggum-windows:windows:ralph-loop "持续改进测试覆盖率"
```

### `/ralph-wiggum-windows:windows:cancel-ralph`

立即取消活动的 Ralph 循环。

```
/ralph-wiggum-windows:windows:cancel-ralph
```

### `/ralph-wiggum-windows:windows:help`

显示关于 Ralph Wiggum 技术和所有可用命令的综合帮助。

```
/ralph-wiggum-windows:windows:help
```

## 完成承诺

要表示任务完成，Claude 必须输出 `<promise>` 标签：

```
<promise>TASK COMPLETE</promise>
```

**重要规则：**
- 承诺文本必须与你在 `--completion-promise` 中指定的完全匹配
- Claude 应该只在陈述真正为真时才输出承诺
- 停止钩子专门查找 `<promise>...</promise>` 标签

## 监控你的循环

当 Ralph 循环运行时，你可以检查其状态：

```powershell
# 查看当前迭代
Select-String '^iteration:' .claude/ralph-loop.local.md

# 查看完整状态
Get-Content .claude/ralph-loop.local.md -Head 10
```

## 何时使用 Ralph

### 适合的使用场景

- **明确定义的任务**，有明确的成功标准
- **迭代开发**需要改进周期
- **全新项目**，Claude 可以增量构建
- **重构任务**有可衡量的结果
- **测试覆盖率**改进

### 不推荐使用

- 需要人工判断或设计决策的任务
- 一次性操作（只需正常使用 Claude）
- 成功标准不明确或主观的任务
- 调试生产问题（需要人工监督）
- 你需要频繁提供反馈的任务

## Windows 兼容性

这个分支专门为 Windows 用户创建。[原始的 Ralph Wiggum 插件](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)使用 bash/jq，在 Windows 上原生无法工作。

**与原始版本的变更：**
| 原始版本 (Unix) | 此分支 (Windows) |
|-----------------|---------------------|
| `stop-hook.sh` | `stop-hook.ps1` |
| `jq` 用于 JSON 解析 | `ConvertFrom-Json` |
| bash 脚本 | PowerShell 脚本 |
| Unix 路径约定 | Windows 路径约定 |

## 文件结构

```
ralph-wiggum-windows/
├── .claude-plugin/
│   └── plugin.json          # 插件清单
├── commands/
│   ├── cancel-ralph.md      # /cancel-ralph 命令
│   ├── help.md              # /help 命令
│   └── ralph-loop.md        # /ralph-loop 命令
├── hooks/
│   └── stop-hook.ps1        # 停止钩子 (PowerShell)
├── scripts/
│   └── setup-ralph-loop.ps1 # 设置脚本 (PowerShell)
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

## 故障排除

### 循环无法启动
- 验证插件已安装在 `~/.claude/plugins/ralph-wiggum-windows`
- 检查 `.claude-plugin/` 中是否存在 `plugin.json`
- 重启 Claude Code

### 循环无法停止
- 使用 `/ralph-wiggum-windows:windows:cancel-ralph` 强制停止
- 手动删除项目目录中的 `.claude/ralph-loop.local.md`

### PowerShell 执行策略错误
以管理员身份运行 PowerShell 并执行：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 贡献

欢迎贡献！请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解指南。

## 致谢

- **原始技术**：[Geoffrey Huntley](https://ghuntley.com/ralph/)
- **原始插件**：[Anthropic Claude Code 团队](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
- **Windows 分支**：CloudBuild Team

## 许可证

本项目在 MIT 许可证下授权 - 详见 [LICENSE](LICENSE) 文件。

## 相关链接

- [Ralph Wiggum 技术 (ghuntley.com)](https://ghuntley.com/ralph/)
- [原始 Ralph Wiggum 插件](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
- [Claude Code 文档](https://docs.anthropic.com/claude-code)
- [Windows 兼容性问题 #14817](https://github.com/anthropics/claude-code/issues/14817)
