---
description: "取消活动的 Ralph Wiggum 循环"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# 取消 Ralph 循环

```!
powershell.exe -NoProfile -Command "
if (Test-Path .claude/ralph-loop.local.md) {
  \$content = Get-Content .claude/ralph-loop.local.md -Raw
  if (\$content -match 'iteration:\s*(\d+)') {
    Write-Host \"FOUND_LOOP=true\"
    Write-Host \"ITERATION=\$(\$Matches[1])\"
  }
} else {
  Write-Host \"FOUND_LOOP=false\"
}
"
```

检查上面的输出：

1. **如果 FOUND_LOOP=false**：
   - 说"未找到活动的 Ralph 循环。"

2. **如果 FOUND_LOOP=true**：
   - 使用 Bash：`powershell.exe -NoProfile -Command "Remove-Item .claude/ralph-loop.local.md -Force"`
   - 报告："已取消 Ralph 循环（处于第 N 次迭代）"，其中 N 是上面的 ITERATION 值。
