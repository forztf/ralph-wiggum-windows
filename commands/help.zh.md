---
description: "解释 Ralph Wiggum 技术和可用命令"
---

# Ralph Wiggum 插件帮助 (Windows)

请向用户解释以下内容：

## 什么是 Ralph Wiggum 技术？

Ralph Wiggum 技术是由 Geoffrey Huntley 开创的迭代开发方法论，基于连续的 AI 循环。

**核心概念：**
```powershell
while ($true) {
  Get-Content PROMPT.md | claude-code --continue
}
```

相同的提示词会重复地提供给 Claude。"自引用"方面来自 Claude 在文件和 git 历史记录中看到自己之前的工作，而不是将输出反馈作为输入。

**每次迭代：**
1. Claude 收到相同的提示词
2. 处理任务，修改文件
3. 尝试退出
4. 停止钩子拦截并再次提供相同的提示词
5. Claude 在文件中看到之前的工作
6. 迭代改进直到完成

## 可用命令

### /ralph-loop <PROMPT> [OPTIONS]

在当前会话中启动 Ralph 循环。

**用法：**
```
/ralph-loop "重构缓存层" --max-iterations 20
/ralph-loop "添加测试" --completion-promise "TESTS COMPLETE"
```

**选项：**
- `--max-iterations <n>` - 自动停止前的最大迭代次数
- `--completion-promise <text>` - 表示完成的承诺短语

**工作原理：**
1. 创建 `.claude/.ralph-loop.local.md` 状态文件
2. 你处理任务
3. 当你尝试退出时，停止钩子拦截
4. 相同的提示词再次提供
5. 你看到之前的工作
6. 持续直到检测到承诺或达到最大迭代次数

---

### /cancel-ralph

取消活动的 Ralph 循环（删除循环状态文件）。

**用法：**
```
/cancel-ralph
```

---

## Windows 特定说明

这是一个与 Windows 兼容的分支，使用 PowerShell 而不是 bash/jq：

- **停止钩子**：`stop-hook.ps1` (PowerShell)
- **设置脚本**：`setup-ralph-loop.ps1` (PowerShell)
- **无 jq 依赖**：使用 `ConvertFrom-Json`
- **无 bash 依赖**：纯 PowerShell

## 核心概念

### 完成承诺

要表示完成，Claude 必须输出 `<promise>` 标签：

```
<promise>TASK COMPLETE</promise>
```

停止钩子查找此特定标签。如果没有它（或 `--max-iterations`），Ralph 将无限运行。

### 自引用机制

"循环"并不意味着 Claude 自言自语。它意味着：
- 相同的提示词重复
- Claude 的工作持久保存在文件中
- 每次迭代都看到之前的尝试
- 朝目标增量构建

## 何时使用 Ralph

**适合：**
- 有明确成功标准的明确定义的任务
- 需要迭代和改进的任务
- 具有自我修正的迭代开发
- 全新项目

**不适合：**
- 需要人工判断或设计决策的任务
- 一次性操作
- 成功标准不明确的任务
- 调试生产问题

## 了解更多

- 原始技术：https://ghuntley.com/ralph/
- 原始插件：https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum
- Windows 问题：https://github.com/anthropics/claude-code/issues/14817
