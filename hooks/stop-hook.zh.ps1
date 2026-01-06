# Ralph Wiggum 停止钩子 (Windows/PowerShell)
# 当 ralph-loop 激活时阻止会话退出
# 将 Claude 的输出反馈作为输入以继续循环

$ErrorActionPreference = "Stop"

# 从 stdin 读取钩子输入（高级停止钩子 API）
$hookInput = $input | Out-String

# ====================================================================
# RALPH WIGGUM STOP HOOK TRIGGERED
# ====================================================================
Write-Host ""
Write-Host "===================================================================="
Write-Host "  STOP HOOK TRIGGERED - Ralph Loop Active"
Write-Host "===================================================================="
Write-Host ""

# 检查 ralph-loop 是否激活
$ralphStateFile = ".claude/ralph-loop.local.md"

if (-not (Test-Path $ralphStateFile)) {
    # 无活动循环 - 允许退出
    exit 0
}

# 读取状态文件
$content = Get-Content $ralphStateFile -Raw

# 解析 YAML 前置数据（在 --- 标记之间）
$frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---')
if (-not $frontmatterMatch.Success) {
    Write-Host "Ralph 循环：状态文件损坏（未找到前置数据）" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

$frontmatter = $frontmatterMatch.Groups[1].Value

# 解析前置数据值
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

# 验证迭代是有效数字
if ($iteration -lt 0) {
    Write-Host "Ralph 循环：状态文件损坏 - 'iteration' 无效" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

# 检查是否达到最大迭代次数
if ($maxIterations -gt 0 -and $iteration -ge $maxIterations) {
    Write-Host "Ralph 循环：已达到最大迭代次数 ($maxIterations)。"
    Remove-Item $ralphStateFile -Force
    exit 0
}

# 从钩子输入获取记录路径（JSON）
try {
    $hookData = $hookInput | ConvertFrom-Json
    $transcriptPath = $hookData.transcript_path
}
catch {
    Write-Host "Ralph 循环：无法将钩子输入解析为 JSON" -ForegroundColor Red
    Write-Host "错误：$_" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) {
    Write-Host "Ralph 循环：未找到记录文件" -ForegroundColor Red
    Write-Host "期望路径：$transcriptPath" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

# 读取记录（JSONL 格式 - 每行一个 JSON）
$transcriptLines = Get-Content $transcriptPath

# 查找最后的助手消息
$lastAssistantLine = $null
foreach ($line in $transcriptLines) {
    if ($line -match '"role"\s*:\s*"assistant"') {
        $lastAssistantLine = $line
    }
}

if (-not $lastAssistantLine) {
    Write-Host "Ralph 循环：在记录中未找到助手消息" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

# 解析助手消息 JSON
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
    Write-Host "Ralph 循环：无法解析助手消息 JSON" -ForegroundColor Red
    Write-Host "错误：$_" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

if ([string]::IsNullOrEmpty($lastOutput)) {
    Write-Host "Ralph 循环：助手消息不包含文本内容" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

# 检查完成承诺（仅当设置时）
if ($completionPromise) {
    # 从 <promise> 标签提取文本
    $promiseMatch = [regex]::Match($lastOutput, '<promise>(.*?)</promise>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($promiseMatch.Success) {
        $promiseText = $promiseMatch.Groups[1].Value.Trim()
        # 标准化空白字符
        $promiseText = $promiseText -replace '\s+', ' '

        if ($promiseText -eq $completionPromise) {
            Write-Host "Ralph 循环：检测到 <promise>$completionPromise</promise>"
            Remove-Item $ralphStateFile -Force
            exit 0
        }
    }
}

# 未完成 - 使用相同的提示词继续循环
$nextIteration = $iteration + 1

# 提取提示词（结束 --- 之后的所有内容）
$promptMatch = [regex]::Match($content, '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$')
if (-not $promptMatch.Success -or [string]::IsNullOrWhiteSpace($promptMatch.Groups[1].Value)) {
    Write-Host "Ralph 循环：状态文件损坏 - 未找到提示词文本" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

$promptText = $promptMatch.Groups[1].Value.Trim()

# 更新状态文件中的迭代
$newContent = $content -replace 'iteration:\s*\d+', "iteration: $nextIteration"
Set-Content $ralphStateFile -Value $newContent -NoNewline -Encoding UTF8

# 构建系统消息
if ($completionPromise) {
    $systemMsg = "Ralph 迭代 $nextIteration | 停止方式：输出 <promise>$completionPromise</promise>（仅在陈述为 TRUE 时 - 不要撒谎退出！）"
}
else {
    $systemMsg = "Ralph 迭代 $nextIteration | 未设置完成承诺 - 循环无限运行"
}

# 输出 JSON 以阻止停止并将提示词反馈
$result = @{
    decision = "block"
    reason = $promptText
    systemMessage = $systemMsg
} | ConvertTo-Json -Compress

Write-Output $result

exit 0
