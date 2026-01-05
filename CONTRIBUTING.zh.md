# 为 Ralph Wiggum Windows 贡献

感谢你对 Ralph Wiggum Windows 插件贡献的兴趣！

## 如何贡献

### 报告问题

1. 检查问题是否已存在于 [GitHub Issues](https://github.com/forztf/ralph-wiggum-windows/issues)
2. 如果不存在，创建一个新问题，包含：
   - 问题的清晰描述
   - 重现步骤
   - 预期行为与实际行为
   - Windows 版本和 PowerShell 版本
   - Claude Code 版本

### 提交更改

1. Fork 仓库
2. 创建功能分支：`git checkout -b feature/your-feature-name`
3. 进行更改
4. 在 Windows 上彻底测试
5. 使用清晰的消息提交：`git commit -m "Add feature X"`
6. 推送到你的 fork：`git push origin feature/your-feature-name`
7. 打开 Pull Request

### 代码指南

- **PowerShell**：遵循 [PowerShell 最佳实践](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- **错误处理**：使用 `$ErrorActionPreference = "Stop"` 和 try/catch 块
- **注释**：记录复杂逻辑
- **测试**：如果可能，在多个 Windows 版本上测试

### 插件结构

```
.claude-plugin/plugin.json  - 插件清单（名称、版本、描述）
commands/*.md               - 斜杠命令定义
hooks/*.zh.ps1                 - PowerShell 钩子（stop-hook.zh.ps1）
scripts/*.zh.ps1               - 辅助脚本
```

### 测试你的更改

1. 将修改后的插件复制到 `~/.claude/plugins/ralph-wiggum-windows`
2. 重启 Claude Code
3. 测试所有命令：
   - `/ralph-wiggum-windows:help`
   - `/ralph-wiggum-windows:ralph-loop "test task" --max-iterations 2`
   - `/ralph-wiggum-windows:cancel-ralph`

## 有问题？

欢迎为问题或讨论打开 issue！
