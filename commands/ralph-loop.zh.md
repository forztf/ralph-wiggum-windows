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

# 如果设置了完成承诺，则提取并显示
if (Test-Path .claude/ralph-loop.local.md) {
  $content = Get-Content .claude/ralph-loop.local.md -Raw
  if ($content -match 'completion_promise:\s*"([^"]+)"') {
    $promise = $Matches[1]
    Write-Host ""
    Write-Host "CRITICAL - Ralph 循环完成承诺"
    Write-Host ""
    Write-Host "要完成此循环，输出此确切的文本："
    Write-Host "  <promise>$promise</promise>"
    Write-Host ""
    Write-Host "严格要求（不得违反）："
    Write-Host "  - 完全按照上面显示使用 <promise> XML 标签"
    Write-Host "  - 陈述必须完全且明确地为真"
    Write-Host "  - 不要输出虚假承诺来退出循环"
    Write-Host "  - 即使你认为应该退出也不要撒谎"
    Write-Host ""
    Write-Host "重要 - 不要绕过循环："
    Write-Host "  即使你认为自己卡住了、任务是不可能的，"
    Write-Host "  或者你已经运行了太久 - 你绝不能输出"
    Write-Host "  虚假的承诺陈述。循环设计为持续运行"
    Write-Host "  直到承诺真正为真。相信这个过程。"
  }
}
```

请处理任务。当你尝试退出时，Ralph 循环会将相同的提示词反馈给你以进行下一次迭代。你将在文件和 git 历史记录中看到之前的工作，从而允许你迭代和改进。

关键规则：如果设置了完成承诺，你只能在陈述完全且明确地为真时才输出它。不要输出虚假承诺来逃避循环，即使你认为卡住了或因其他原因应该退出。循环设计为持续运行直到真正完成。
