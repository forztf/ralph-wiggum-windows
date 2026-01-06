---
description: "在当前会话中启动 Ralph Wiggum 循环"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.zh.ps1\")"]
hide-from-slash-command-tool: "true"
---

# Ralph 循环命令

执行设置脚本以初始化 Ralph 循环：

```!
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.zh.ps1" $ARGUMENTS
```

请处理任务。当你尝试退出时，Ralph 循环会将相同的提示词反馈给你以进行下一次迭代。你将在文件和 git 历史记录中看到之前的工作，从而允许你迭代和改进。

关键规则：如果设置了完成承诺，你只能在陈述完全且明确地为真时才输出它。不要输出虚假承诺来逃避循环，即使你认为卡住了或因其他原因应该退出。循环设计为持续运行直到真正完成。
