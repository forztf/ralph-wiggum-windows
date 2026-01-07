# Ralph Wiggum Stop Hook 技术细节

## PowerShell 特定实现

### 1. 错误处理策略

```powershell
$ErrorActionPreference = "Stop"
```

**作用：**
- 设置全局错误处理策略为 "Stop"
- 确保任何非终止错误都会导致脚本立即停止执行
- 避免脚本在错误状态下继续运行

**优势：**
- 提高脚本的可靠性
- 防止错误累积导致的意外行为
- 简化错误处理逻辑

### 2. 调试日志系统

```powershell
function Write-DebugLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $DEBUG_LOG -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}
```

**设计特点：**
- 使用参数化函数提高代码复用性
- 包含时间戳便于问题追踪
- 使用 `SilentlyContinue` 避免日志写入失败影响主流程

**日志格式：**
```
[2024-01-15 14:30:25] === Stop hook triggered ===
[2024-01-15 14:30:25] Hook input received: {"transcript_path":"/path/to/transcript.jsonl"}
[2024-01-15 14:30:25] State file found - processing loop
```

## 正则表达式详解

### 1. YAML 前置元数据解析

```powershell
$frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---')
```

**正则表达式分解：**
- `(?s)` - 单行模式修饰符，使 `.` 匹配包括换行符在内的所有字符
- `^---` - 匹配行首的三个连字符
- `\r?\n` - 匹配可选的回车符和必需的换行符（兼容 Windows 和 Unix 换行符）
- `(.*?)` - 非贪婪捕获组，匹配前置元数据内容
- `\r?\n---` - 匹配结束的三个连字符

**为什么使用非贪婪匹配：**
- 避免匹配到后续的 `---` 分隔符
- 确保只捕获第一个前置元数据块

### 2. 键值对解析

```powershell
foreach ($line in $frontmatter -split '\r?\n') {
    if ($line -match '^iteration:\s*(.+)$') {
        $iteration = [int]$Matches[1]
    }
    elseif ($line -match '^max_iterations:\s*(.+)$') {
        $maxIterations = [int]$Matches[1]
    }
    elseif ($line -match '^completion_promise:\s*"?([^"]*)"?$') {
        $completionPromise = $Matches[1]
    }
}
```

**正则表达式说明：**
- `^iteration:\s*(.+)$` - 匹配以 "iteration:" 开头的行，捕获冒号后的值
- `\s*` - 匹配零个或多个空白字符
- `(.+)` - 捕获一个或多个任意字符
- `^completion_promise:\s*"?([^"]*)"?$` - 处理可选的引号包围的值

### 3. 提示文本提取

```powershell
$promptMatch = [regex]::Match($content, '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$')
```

**功能：**
- 提取 YAML 前置元数据之后的所有内容作为提示文本
- 使用单行模式确保跨行匹配
- 非贪婪匹配前置元数据部分

### 4. 完成承诺检测

```powershell
$promiseMatch = [regex]::Match($lastOutput, '<promise>(.*?)</promise>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
```

**特点：**
- 使用 `[System.Text.RegularExpressions.RegexOptions]::Singleline` 明确指定单行模式
- 非贪婪匹配确保正确处理嵌套标签
- 支持跨行的承诺文本

## JSON 处理机制

### 1. 钩子输入解析

```powershell
$hookData = $hookInput | ConvertFrom-Json
$transcriptPath = $hookData.transcript_path
```

**处理流程：**
- 从标准输入读取 JSON 字符串
- 使用 `ConvertFrom-Json` 转换为 PowerShell 对象
- 提取 `transcript_path` 字段

### 2. JSONL 文件处理

```powershell
$transcriptLines = Get-Content $transcriptPath
$lastAssistantLine = $null
foreach ($line in $transcriptLines) {
    if ($line -match '"role"\s*:\s*"assistant"') {
        $lastAssistantLine = $line
    }
}
```

**JSONL 格式特点：**
- 每行一个独立的 JSON 对象
- 不需要逗号分隔
- 易于流式处理和逐行读取

**查找最后 assistant 消息：**
- 逐行扫描传输文件
- 使用正则表达式匹配 role 字段
- 保留最后一个匹配项

### 3. 助手消息解析

```powershell
$assistantMsg = $lastAssistantLine | ConvertFrom-Json
$textContent = @()
foreach ($block in $assistantMsg.message.content) {
    if ($block.type -eq 'text') {
        $textContent += $block.text
    }
}
$lastOutput = $textContent -join "`n"
```

**消息结构分析：**
```json
{
  "message": {
    "content": [
      {
        "type": "text",
        "text": "这是文本内容"
      },
      {
        "type": "image",
        "source": {
          "type": "base64",
          "media_type": "image/png",
          "data": "..."
        }
      }
    ],
    "role": "assistant"
  }
}
```

**处理逻辑：**
- 遍历 content 数组中的每个块
- 只提取 type 为 "text" 的块
- 将所有文本块用换行符连接

### 4. 响应 JSON 构建

```powershell
$result = @{
    decision = "block"
    reason = $promptText
    systemMessage = $systemMsg
} | ConvertTo-Json -Compress
```

**响应格式：**
```json
{
  "decision": "block",
  "reason": "原始提示文本",
  "systemMessage": "Ralph iteration 2 | To stop: output <promise>DONE</promise>"
}
```

**决策类型：**
- `"block"` - 阻止退出，继续循环
- `"allow"` - 允许退出（当前未使用）

## 文件操作最佳实践

### 1. 文件存在性检查

```powershell
if (-not (Test-Path $ralphStateFile)) {
    Write-DebugLog "No state file found - allowing exit"
    exit 0
}
```

**使用 `Test-Path` 的优势：**
- 跨平台兼容性
- 支持文件和目录检查
- 返回布尔值便于条件判断

### 2. 文件读取

```powershell
$content = Get-Content $ralphStateFile -Raw
```

**`-Raw` 参数的作用：**
- 将整个文件读取为单个字符串
- 保持原始换行符格式
- 避免数组处理的复杂性

### 3. 文件写入

```powershell
Set-Content $ralphStateFile -Value $newContent -NoNewline -Encoding UTF8
```

**参数说明：**
- `-NoNewline` - 避免在文件末尾添加额外的换行符
- `-Encoding UTF8` - 确保使用 UTF-8 编码
- 直接替换整个文件内容

### 4. 文件删除

```powershell
Remove-Item $ralphStateFile -Force
```

**`-Force` 参数的作用：**
- 强制删除只读文件
- 不提示确认
- 提高自动化程度

## 字符串处理技巧

### 1. 文本截取

```powershell
$hookInput.Substring(0, [Math]::Min(500, $hookInput.Length))
```

**作用：**
- 限制日志长度，避免过长的输入影响日志文件
- 使用 `[Math]::Min()` 确保不会超出字符串长度

### 2. 空白字符规范化

```powershell
$promiseText = $promiseText -replace '\s+', ' '
```

**正则表达式说明：**
- `\s+` - 匹配一个或多个空白字符（空格、制表符、换行符等）
- `' '` - 替换为单个空格
- 确保文本比较的一致性

### 3. 字符串连接

```powershell
$lastOutput = $textContent -join "`n"
```

**使用反引号 n 的原因：**
- 在 PowerShell 中表示换行符
- 比使用 `[Environment]::NewLine` 更简洁
- 跨平台兼容

## 错误处理模式

### 1. Try-Catch 结构

```powershell
try {
    $hookData = $hookInput | ConvertFrom-Json
    $transcriptPath = $hookData.transcript_path
    Write-DebugLog "Transcript path: $transcriptPath"
}
catch {
    Write-Host "Ralph loop: Failed to parse hook input as JSON" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-DebugLog "ERROR: Failed to parse transcript_path from hook input"
    Remove-Item $ralphStateFile -Force
    exit 0
}
```

**错误处理原则：**
- 捕获具体类型的异常
- 提供用户友好的错误消息
- 记录详细的调试信息
- 清理状态并优雅退出

### 2. 验证链

```powershell
if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) {
    Write-Host "Ralph loop: Transcript file not found" -ForegroundColor Red
    Write-Host "Expected: $transcriptPath" -ForegroundColor Red
    Write-DebugLog "ERROR: Transcript file not found at: $transcriptPath"
    Remove-Item $ralphStateFile -Force
    exit 0
}
```

**验证模式：**
- 先检查变量是否为空
- 再检查文件是否存在
- 提供具体的错误信息
- 包含预期路径便于调试

### 3. 状态清理

```powershell
Remove-Item $ralphStateFile -Force
exit 0
```

**清理原则：**
- 在错误发生时立即清理状态文件
- 使用 `exit 0` 允许正常退出
- 避免留下损坏的状态

## 性能优化考虑

### 1. 内存管理

```powershell
$transcriptLines = Get-Content $transcriptPath
```

**潜在问题：**
- `Get-Content` 会将整个文件加载到内存
- 对于大文件可能影响性能

**优化建议：**
- 对于大文件，考虑使用流式处理
- 限制读取的行数

### 2. 正则表达式优化

```powershell
$frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---')
```

**优化特点：**
- 使用非贪婪匹配避免过度捕获
- 明确指定单行模式
- 避免复杂的嵌套结构

### 3. 日志性能

```powershell
Write-DebugLog "Hook input received: $($hookInput.Substring(0, [Math]::Min(500, $hookInput.Length)))"
```

**性能考虑：**
- 限制日志内容长度
- 避免记录大量数据
- 使用异步写入（如果需要）

## 安全性考虑

### 1. 输入验证

```powershell
if ($iteration -lt 0) {
    Write-Host "Ralph loop: State file corrupted - 'iteration' is invalid" -ForegroundColor Red
    Write-DebugLog "ERROR: Invalid iteration value: $iteration"
    Remove-Item $ralphStateFile -Force
    exit 0
}
```

**安全措施：**
- 验证所有解析的数值
- 检查文件路径的有效性
- 防止注入攻击

### 2. 文件权限

```powershell
Remove-Item $ralphStateFile -Force
```

**权限处理：**
- 使用 `-Force` 处理只读文件
- 确保脚本有足够的文件操作权限
- 避免权限提升攻击

### 3. 路径安全

```powershell
$ralphStateFile = ".claude/ralph-loop.local.md"
```

**路径特点：**
- 使用相对路径
- 位于项目目录内
- 避免绝对路径的安全风险

## 跨平台兼容性

### 1. 换行符处理

```powershell
\r?\n
```

**兼容性：**
- `\r?\n` 匹配 Windows (CRLF) 和 Unix (LF) 换行符
- 确保在不同平台上正确解析

### 2. 路径分隔符

```powershell
$ralphStateFile = ".claude/ralph-loop.local.md"
```

**路径约定：**
- 使用正斜杠 `/` 作为路径分隔符
- PowerShell 支持正斜杠，提高跨平台兼容性

### 3. 编码处理

```powershell
-Encoding UTF8
```

**编码选择：**
- 使用 UTF-8 确保 Unicode 字符正确处理
- 避免编码相关的错误

## 调试和监控

### 1. 详细日志

```powershell
Write-DebugLog "Parsed: iteration=$iteration, max=$maxIterations, promise=$completionPromise"
```

**日志内容：**
- 关键变量的值
- 处理步骤的状态
- 错误和异常信息

### 2. 用户反馈

```powershell
Write-Host "Ralph loop: Max iterations ($maxIterations) reached." -ForegroundColor Red
```

**用户界面：**
- 使用彩色输出提高可读性
- 提供清晰的状态信息
- 显示具体的错误原因

### 3. 调试工具

```powershell
Write-DebugLog "Extracted prompt: $($promptText.Substring(0, [Math]::Min(100, $promptText.Length)))"
```

**调试信息：**
- 截取关键内容便于查看
- 记录处理过程中的中间状态
- 便于问题定位和修复

## 总结

`stop-hook.ps1` 展示了 PowerShell 在处理复杂文件操作、JSON 解析和正则表达式方面的强大能力。通过精心设计的错误处理、详细的日志记录和灵活的配置选项，这个脚本实现了一个可靠且高效的 Ralph Wiggum 循环机制。

关键的技术亮点包括：
- 完善的错误处理和恢复机制
- 高效的文件和 JSON 处理
- 灵活的正则表达式匹配
- 详细的调试和监控功能
- 良好的跨平台兼容性