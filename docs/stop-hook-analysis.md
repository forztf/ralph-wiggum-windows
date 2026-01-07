# Ralph Wiggum Stop Hook 详细解析

## 概述

`stop-hook.ps1` 是 Ralph Wiggum Windows 插件的核心组件，负责拦截 Claude Code 会话的退出操作，实现自引用的迭代式 AI 开发循环。

## 核心功能

### 1. 会话拦截机制
- **拦截退出**：当用户尝试退出 Claude Code 会话时，钩子会拦截此操作
- **状态检查**：检查是否存在活跃的 Ralph 循环状态
- **循环继续**：如果循环活跃，将 Claude 的输出作为新的输入继续循环

### 2. 状态管理
- **状态文件**：`.claude/ralph-loop.local.md` 存储循环状态
- **迭代计数**：跟踪当前迭代次数和最大迭代限制
- **完成承诺**：支持基于特定文本标记的完成检测

### 3. 输出解析
- **JSONL 解析**：解析 Claude 的 transcript 文件（JSONL 格式）
- **消息提取**：提取最后的 assistant 消息作为下一轮输入
- **文本处理**：处理多块文本内容，合并为单一输入

## 代码结构分析

### 初始化阶段 (第1-16行)

```powershell
# Ralph Wiggum Stop Hook (Windows/PowerShell)
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop

$ErrorActionPreference = "Stop"

# Debug log file
$DEBUG_LOG = ".claude/ralph-debug.log"

function Write-DebugLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $DEBUG_LOG -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

Write-DebugLog "=== Stop hook triggered ==="
```

**功能说明：**
- 设置错误处理策略为 "Stop"，确保任何错误都会终止脚本
- 定义调试日志文件路径
- 创建调试日志函数，记录时间戳和消息
- 记录钩子触发事件

### 输入处理阶段 (第18-28行)

```powershell
# Read hook input from stdin (advanced stop hook API)
$hookInput = $input | Out-String
Write-DebugLog "Hook input received: $($hookInput.Substring(0, [Math]::Min(500, $hookInput.Length)))"

# Check if ralph-loop is active
$ralphStateFile = ".claude/ralph-loop.local.md"

if (-not (Test-Path $ralphStateFile)) {
    # No active loop - allow exit
    Write-DebugLog "No state file found - allowing exit"
    exit 0
}
```

**功能说明：**
- 从标准输入读取钩子输入（Claude Code 的高级停止钩子 API）
- 记录接收到的输入（截取前500字符以避免日志过长）
- 检查状态文件是否存在，如果不存在则允许正常退出

### 状态文件解析 (第33-73行)

```powershell
# Read the state file
$content = Get-Content $ralphStateFile -Raw

# Parse YAML frontmatter (between --- markers)
$frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---')
if (-not $frontmatterMatch.Success) {
    Write-Host "Ralph loop: State file corrupted (no frontmatter found)" -ForegroundColor Red
    Write-DebugLog "ERROR: No frontmatter found"
    Remove-Item $ralphStateFile -Force
    exit 0
}

$frontmatter = $frontmatterMatch.Groups[1].Value

# Parse frontmatter values
$iteration = 0
$maxIterations = 0
$completionPromise = $null

foreach ($line in $frontmatter -split '\r?\n') {
    if ($line -match '^iteration:\s*(.+)$') {
        $iteration = [int]$Matches[1]
    }
    elseif ($line -match '^max_iterations:\s*(.+)$') {
        $maxIterations = [int]$Matches[1]
    }
    elseif ($line -match '^completion_promise:\s*"?([^"]*)"?$') {
        $completionPromise = $Matches[1]
        if ($completionPromise -eq 'null') {
            $completionPromise = $null
        }
    }
}

# Validate iteration is a valid number
if ($iteration -lt 0) {
    Write-Host "Ralph loop: State file corrupted - 'iteration' is invalid" -ForegroundColor Red
    Write-DebugLog "ERROR: Invalid iteration value: $iteration"
    Remove-Item $ralphStateFile -Force
    exit 0
}
```

**功能说明：**
- 读取状态文件的完整内容
- 使用正则表达式解析 YAML 前置元数据（frontmatter）
- 提取迭代次数、最大迭代次数和完成承诺
- 验证迭代值的有效性

### 迭代限制检查 (第77-83行)

```powershell
# Check if max iterations reached
if ($maxIterations -gt 0 -and $iteration -ge $maxIterations) {
    Write-Host "Ralph loop: Max iterations ($maxIterations) reached."
    Write-DebugLog "Max iterations reached - stopping loop"
    Remove-Item $ralphStateFile -Force
    exit 0
}
```

**功能说明：**
- 检查是否达到最大迭代次数
- 如果达到，则显示消息，删除状态文件，允许退出

### 传输文件处理 (第85-105行)

```powershell
# Get transcript path from hook input (JSON)
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

if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) {
    Write-Host "Ralph loop: Transcript file not found" -ForegroundColor Red
    Write-Host "Expected: $transcriptPath" -ForegroundColor Red
    Write-DebugLog "ERROR: Transcript file not found at: $transcriptPath"
    Remove-Item $ralphStateFile -Force
    exit 0
}
```

**功能说明：**
- 从钩子输入的 JSON 中提取传输文件路径
- 验证传输文件是否存在
- 处理 JSON 解析错误和文件不存在的情况

### 助手消息提取 (第107-151行)

```powershell
# Read transcript (JSONL format - one JSON per line)
$transcriptLines = Get-Content $transcriptPath

# Find last assistant message
$lastAssistantLine = $null
foreach ($line in $transcriptLines) {
    if ($line -match '"role"\s*:\s*"assistant"') {
        $lastAssistantLine = $line
    }
}

if (-not $lastAssistantLine) {
    Write-Host "Ralph loop: No assistant messages found in transcript" -ForegroundColor Red
    Write-DebugLog "ERROR: No assistant messages in transcript"
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Parse the assistant message JSON
try {
    $assistantMsg = $lastAssistantLine | ConvertFrom-Json
    $textContent = @()
    foreach ($block in $assistantMsg.message.content) {
        if ($block.type -eq 'text') {
            $textContent += $block.text
        }
    }
    $lastOutput = $textContent -join "`n"
}
catch {
    Write-Host "Ralph loop: Failed to parse assistant message JSON" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-DebugLog "ERROR: Failed to parse assistant message JSON: $_"
    Remove-Item $ralphStateFile -Force
    exit 0
}

if ([string]::IsNullOrEmpty($lastOutput)) {
    Write-Host "Ralph loop: Assistant message contained no text content" -ForegroundColor Red
    Write-DebugLog "ERROR: No text content in assistant message"
    Remove-Item $ralphStateFile -Force
    exit 0
}
```

**功能说明：**
- 读取传输文件（JSONL 格式，每行一个 JSON 对象）
- 查找最后一条 assistant 消息
- 解析消息的 JSON 结构，提取文本内容
- 处理各种解析错误和空内容情况

### 完成承诺检测 (第155-170行)

```powershell
# Check for completion promise (only if set)
if ($completionPromise) {
    # Extract text from <promise> tags
    $promiseMatch = [regex]::Match($lastOutput, '<promise>(.*?)</promise>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($promiseMatch.Success) {
        $promiseText = $promiseMatch.Groups[1].Value.Trim()
        # Normalize whitespace
        $promiseText = $promiseText -replace '\s+', ' '

        if ($promiseText -eq $completionPromise) {
            Write-Host "Ralph loop: Detected <promise>$completionPromise</promise>"
            Remove-Item $ralphStateFile -Force
            exit 0
        }
    }
}
```

**功能说明：**
- 如果设置了完成承诺，检查输出中是否包含 `<promise>` 标签
- 提取标签内的文本并与设置的承诺进行比较
- 如果匹配，则删除状态文件并允许退出

### 循环继续逻辑 (第172-209行)

```powershell
# Not complete - continue loop with SAME PROMPT
$nextIteration = $iteration + 1

# Extract prompt (everything after the closing ---)
$promptMatch = [regex]::Match($content, '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$')
if (-not $promptMatch.Success -or [string]::IsNullOrWhiteSpace($promptMatch.Groups[1].Value)) {
    Write-Host "Ralph loop: State file corrupted - no prompt text found" -ForegroundColor Red
    Write-DebugLog "ERROR: No prompt text found in state file"
    Remove-Item $ralphStateFile -Force
    exit 0
}

$promptText = $promptMatch.Groups[1].Value.Trim()
Write-DebugLog "Extracted prompt: $($promptText.Substring(0, [Math]::Min(100, $promptText.Length)))"

# Update iteration in state file
$newContent = $content -replace 'iteration:\s*\d+', "iteration: $nextIteration"
Set-Content $ralphStateFile -Value $newContent -NoNewline -Encoding UTF8

# Build system message
if ($completionPromise) {
    $systemMsg = "Ralph iteration $nextIteration | To stop: output <promise>$completionPromise</promise> (ONLY when statement is TRUE - do not lie to exit!)"
}
else {
    $systemMsg = "Ralph iteration $nextIteration | No completion promise set - loop runs infinitely"
}

# Output JSON to block the stop and feed prompt back
$result = @{
    decision = "block"
    reason = $promptText
    systemMessage = $systemMsg
} | ConvertTo-Json -Compress

Write-DebugLog "SUCCESS: Blocking exit, continuing to iteration $nextIteration"
Write-Output $result

exit 0
```

**功能说明：**
- 增加迭代计数
- 从状态文件中提取原始提示文本
- 更新状态文件中的迭代次数
- 构建系统消息，包含迭代信息和完成条件
- 输出 JSON 响应，阻止退出并提供新的输入

## 关键技术点

### 1. YAML 前置元数据解析
使用正则表达式 `(?s)^---\r?\n(.*?)\r?\n---` 解析 YAML 前置元数据，其中：
- `(?s)` 启用单行模式，使 `.` 匹配换行符
- `^---\r?\n` 匹配起始分隔符
- `(.*?)` 非贪婪匹配内容
- `\r?\n---` 匹配结束分隔符

### 2. JSONL 文件处理
传输文件采用 JSONL 格式（每行一个 JSON 对象），通过逐行读取和正则匹配找到最后的 assistant 消息。

### 3. 错误处理策略
- 使用 `try-catch` 块处理 JSON 解析错误
- 验证所有关键数据的有效性
- 在遇到错误时清理状态文件并允许退出

### 4. 文本规范化
对完成承诺文本进行规范化处理，将多个空白字符替换为单个空格，确保比较的准确性。

## 安全考虑

### 1. 输入验证
- 验证迭代值为非负整数
- 检查文件路径的有效性
- 验证 JSON 格式的正确性

### 2. 错误恢复
- 在遇到错误时自动清理状态文件
- 提供详细的错误日志
- 确保不会留下损坏的状态

### 3. 资源管理
- 使用 `Remove-Item -Force` 强制删除状态文件
- 设置适当的错误处理策略
- 避免无限循环的风险

## 性能优化

### 1. 日志截取
- 对长输入进行截取，避免日志文件过大
- 使用 `[Math]::Min()` 函数限制日志长度

### 2. 正则表达式优化
- 使用非贪婪匹配避免过度捕获
- 合理使用正则表达式选项提高性能

### 3. 文件操作
- 使用 `-NoNewline` 参数避免额外的换行符
- 使用 `-Encoding UTF8` 确保正确的字符编码

## 使用场景

### 1. 迭代开发
适合需要多次迭代改进的任务，如：
- 代码重构
- 性能优化
- 测试覆盖率提升

### 2. 自动化任务
可以自动执行重复性任务，如：
- 代码生成
- 文档更新
- 配置管理

### 3. 学习和探索
适合探索性任务，如：
- 新技术学习
- 架构设计
- 算法实现

## 限制和注意事项

### 1. 依赖状态文件
- 必须存在有效的状态文件才能继续循环
- 状态文件损坏会导致循环终止

### 2. 传输文件要求
- 传输文件必须存在且格式正确
- 必须包含有效的 assistant 消息

### 3. 完成承诺限制
- 完成承诺文本必须完全匹配
- 不支持模糊匹配或正则表达式

### 4. 性能考虑
- 大型传输文件可能影响解析性能
- 长时间运行可能产生大量日志

## 故障排除

### 1. 循环无法启动
- 检查状态文件是否存在
- 验证状态文件格式是否正确
- 查看调试日志了解具体错误

### 2. 循环无法停止
- 使用 `/cancel-ralph` 命令强制停止
- 手动删除状态文件
- 检查完成承诺设置是否正确

### 3. 解析错误
- 检查传输文件格式
- 验证 JSON 语法正确性
- 查看调试日志定位问题

## 总结

`stop-hook.ps1` 是一个精心设计的 PowerShell 脚本，实现了 Ralph Wiggum 技术的核心机制。它通过拦截会话退出、解析状态和传输文件、检测完成条件等步骤，实现了自引用的迭代式 AI 开发循环。脚本具有完善的错误处理、详细的日志记录和灵活的配置选项，是一个功能强大且可靠的工具。