# Ralph Wiggum Stop Hook 使用指南

## 快速开始

### 1. 启动 Ralph 循环

```powershell
/ralph-wiggum-windows:windows:ralph-loop "构建一个待办事项 REST API" --completion-promise "API COMPLETE" --max-iterations 30
```

### 2. 循环工作流程

1. **初始提示** → Claude 开始处理任务
2. **尝试退出** → Stop Hook 拦截退出
3. **状态检查** → 检查循环状态和完成条件
4. **输出解析** → 提取 Claude 的最后输出
5. **继续循环** → 使用相同提示重新开始
6. **重复步骤 2-5** → 直到满足完成条件

## 配置选项详解

### --completion-promise

**作用：** 设置完成承诺文本，当 Claude 输出包含 `<promise>文本</promise>` 时停止循环

**示例：**
```powershell
# 设置简单的完成承诺
/ralph-wiggum-windows:windows:ralph-loop "重构代码" --completion-promise "DONE"

# 设置复杂的完成承诺
/ralph-wiggum-windows:windows:ralph-loop "实现功能" --completion-promise "ALL TESTS PASS"
```

**使用规则：**
- 承诺文本必须完全匹配（包括大小写和空格）
- Claude 只能在陈述真正为真时输出承诺
- 支持包含空格和特殊字符的文本

### --max-iterations

**作用：** 设置最大迭代次数，防止无限循环

**示例：**
```powershell
# 限制为 10 次迭代
/ralph-wiggum-windows:windows:ralph-loop "优化性能" --max-iterations 10

# 结合完成承诺使用
/ralph-wiggum-windows:windows:ralph-loop "开发功能" --completion-promise "COMPLETE" --max-iterations 50
```

**行为说明：**
- 达到最大迭代次数后自动停止循环
- 优先级低于完成承诺（即使未达到最大次数，完成承诺也会停止循环）
- 设置为 0 或不设置表示无限制

## 监控和调试

### 1. 查看循环状态

```powershell
# 查看当前迭代次数
Select-String '^iteration:' .claude/ralph-loop.local.md

# 查看完整状态信息
Get-Content .claude/ralph-loop.local.md -Head 10

# 查看调试日志
Get-Content .claude/ralph-debug.log -Tail 20
```

### 2. 状态文件格式

```markdown
---
iteration: 5
max_iterations: 30
completion_promise: "TASK COMPLETE"
---

# 原始提示文本
构建一个支持用户注册、登录和数据同步的移动应用后端 API。
```

**字段说明：**
- `iteration` - 当前迭代次数
- `max_iterations` - 最大迭代次数（null 表示无限制）
- `completion_promise` - 完成承诺文本（null 表示未设置）

### 3. 调试日志分析

```powershell
# 查看最近的调试信息
Get-Content .claude/ralph-debug.log | Select-Object -Last 50

# 过滤特定类型的日志
Select-String "ERROR" .claude/ralph-debug.log
Select-String "SUCCESS" .claude/ralph-debug.log
```

**日志级别：**
- `=== Stop hook triggered ===` - 钩子触发
- `Hook input received` - 接收输入
- `State file found` - 状态文件存在
- `SUCCESS: Blocking exit` - 成功阻止退出
- `ERROR: ...` - 错误信息

## 故障排除

### 1. 循环无法启动

**症状：** 执行命令后没有反应或立即退出

**检查步骤：**
```powershell
# 1. 检查插件是否正确安装
Get-ChildItem ~/.claude/plugins/ralph-wiggum-windows

# 2. 检查状态文件是否存在
Test-Path .claude/ralph-loop.local.md

# 3. 检查调试日志
Get-Content .claude/ralph-debug.log
```

**常见原因：**
- 插件未正确安装
- PowerShell 执行策略阻止脚本运行
- 状态文件损坏

### 2. 循环无法停止

**症状：** 循环持续运行，不响应完成承诺

**检查步骤：**
```powershell
# 1. 检查完成承诺格式
Select-String '<promise>' .claude/ralph-loop.local.md

# 2. 检查调试日志中的承诺检测
Select-String 'promise' .claude/ralph-debug.log

# 3. 手动停止循环
/ralph-wiggum-windows:windows:cancel-ralph
```

**解决方法：**
- 确保 Claude 输出正确的 `<promise>文本</promise>` 格式
- 检查承诺文本是否完全匹配
- 使用取消命令强制停止

### 3. 解析错误

**症状：** 显示 "Failed to parse" 错误

**常见错误类型：**
```powershell
# JSON 解析错误
"Ralph loop: Failed to parse hook input as JSON"

# 状态文件错误
"Ralph loop: State file corrupted (no frontmatter found)"

# 传输文件错误
"Ralph loop: No assistant messages found in transcript"
```

**解决步骤：**
1. 检查相关文件是否存在
2. 验证文件格式是否正确
3. 查看详细错误日志
4. 重新启动循环

### 4. PowerShell 执行策略问题

**症状：** 脚本被阻止执行

**解决方法：**
```powershell
# 以管理员身份运行 PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**执行策略说明：**
- `RemoteSigned` - 允许本地脚本，远程脚本需要签名
- `Unrestricted` - 允许所有脚本（不推荐）
- `AllSigned` - 所有脚本都需要签名

## 高级用法

### 1. 自定义完成条件

```powershell
# 使用复杂的完成承诺
/ralph-wiggum-windows:windows:ralph-loop "实现算法" --completion-promise "TIME COMPLEXITY O(N LOG N)"

# 使用简短的完成承诺
/ralph-wiggum-windows:windows:ralph-loop "修复 bug" --completion-promise "FIXED"
```

### 2. 迭代监控脚本

```powershell
# 创建监控脚本
$monitorScript = @'
while ($true) {
    if (Test-Path ".claude/ralph-loop.local.md") {
        $content = Get-Content ".claude/ralph-loop.local.md" -Head 5
        Write-Host "当前状态: $($content -join ' ')"
    }
    Start-Sleep 5
}
'@

# 保存并运行监控
Set-Content -Path "monitor-loop.ps1" -Value $monitorScript
.\monitor-loop.ps1
```

### 3. 批量处理

```powershell
# 创建多个循环任务
$tasks = @(
    "重构缓存层",
    "优化数据库查询", 
    "改进错误处理"
)

foreach ($task in $tasks) {
    /ralph-wiggum-windows:windows:ralph-loop $task --completion-promise "DONE" --max-iterations 20
    Start-Sleep 60  # 等待 1 分钟
}
```

## 最佳实践

### 1. 提示词设计

**好的提示词特点：**
- 明确的任务描述
- 具体的成功标准
- 可衡量的结果

**示例：**
```powershell
# 好的提示词
/ralph-wiggum-windows:windows:ralph-loop "实现用户认证系统，包含注册、登录、密码重置功能，所有功能都有单元测试覆盖"

# 不好的提示词
/ralph-wiggum-windows:windows:ralph-loop "做点什么"
```

### 2. 完成承诺设置

**建议：**
- 使用简洁明确的文本
- 避免模糊或主观的描述
- 确保承诺文本与任务相关

**示例：**
```powershell
# 好的完成承诺
--completion-promise "ALL TESTS PASS"
--completion-promise "API DOCUMENTED"
--completion-promise "PERFORMANCE IMPROVED"

# 不好的完成承诺
--completion-promise "done"  # 太简单
--completion-promise "I think it's good enough"  # 主观
```

### 3. 迭代次数设置

**建议：**
- 根据任务复杂度设置合理的最大迭代次数
- 对于简单任务，设置较小的迭代次数
- 对于复杂任务，设置较大的迭代次数或不限制

**参考值：**
- 简单任务：10-20 次迭代
- 中等任务：30-50 次迭代
- 复杂任务：50-100 次迭代或不限制

### 4. 错误处理

**建议：**
- 定期检查调试日志
- 设置合理的超时机制
- 准备备用方案

**监控脚本示例：**
```powershell
# 创建错误监控脚本
$monitorScript = @'
$lastErrorTime = Get-Date
while ($true) {
    if (Test-Path ".claude/ralph-debug.log") {
        $logContent = Get-Content ".claude/ralph-debug.log" -Tail 10
        if ($logContent -match "ERROR") {
            $currentTime = Get-Date
            if ($currentTime - $lastErrorTime -gt [TimeSpan]::FromMinutes(5)) {
                Write-Host "检测到错误，建议检查循环状态"
                $lastErrorTime = $currentTime
            }
        }
    }
    Start-Sleep 30
}
'@
```

## 性能优化

### 1. 减少日志输出

```powershell
# 在不需要详细日志时，可以临时禁用
$DEBUG_LOG = $null  # 或者注释掉 Write-DebugLog 调用
```

### 2. 优化文件操作

```powershell
# 对于大文件，考虑分块处理
$transcriptPath = $hookData.transcript_path
$lines = Get-Content $transcriptPath -ReadCount 1000  # 分块读取
```

### 3. 内存管理

```powershell
# 及时清理大对象
$transcriptLines = $null
[GC]::Collect()  # 强制垃圾回收
```

## 安全考虑

### 1. 文件权限

```powershell
# 确保状态文件有适当的权限
$acl = Get-Acl ".claude/ralph-loop.local.md"
$acl.SetAccessRuleProtection($true, $false)  # 禁用继承
Set-Acl ".claude/ralph-loop.local.md" $acl
```

### 2. 输入验证

```powershell
# 验证提示词长度
if ($prompt.Length -gt 10000) {
    Write-Host "提示词过长，请缩短到 10000 字符以内"
    exit 1
}
```

### 3. 资源限制

```powershell
# 设置最大运行时间
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
if ($stopwatch.Elapsed.TotalHours -gt 2) {
    Write-Host "循环运行超过 2 小时，建议停止"
    exit 1
}
```

## 总结

Ralph Wiggum Stop Hook 是一个强大的工具，通过理解其工作原理和正确使用，可以大大提高 AI 辅助开发的效率。关键是要：

1. **合理设置参数** - 根据任务特点设置合适的完成承诺和迭代次数
2. **监控循环状态** - 定期检查状态文件和调试日志
3. **及时处理错误** - 遇到问题时快速定位和解决
4. **遵循最佳实践** - 使用清晰的提示词和完成承诺

通过这些指南，你可以充分利用 Ralph Wiggum 技术的优势，实现高效的迭代式 AI 开发。