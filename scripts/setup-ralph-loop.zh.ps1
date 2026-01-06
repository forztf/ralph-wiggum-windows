# Ralph 循环设置脚本 (Windows/PowerShell)
# 为会话内 Ralph 循环创建状态文件

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

# 解析参数
$promptParts = @()
$maxIterations = 0
$completionPromise = "null"

$i = 0
while ($i -lt $Arguments.Count) {
    $arg = $Arguments[$i]

    switch -Regex ($arg) {
        '^(-h|--help)$' {
            Write-Host @"
Ralph 循环 - 交互式自引用开发循环 (Windows)

用法:
  /ralph-loop [提示词...] [选项]

参数:
  提示词...    启动循环的初始提示词（可以是不带引号的多个词）

选项:
  --max-iterations <n>           自动停止前的最大迭代次数（默认：无限制）
  --completion-promise '<文本>'  承诺短语（多词时请使用引号）
  -h, --help                     显示此帮助信息

描述:
  在当前会话中启动 Ralph Wiggum 循环。停止钩子会阻止退出，
  并将你的输出反馈作为输入，直到完成或达到迭代限制。

  要表示完成，你必须输出：<promise>你的短语</promise>

示例:
  /ralph-loop 构建待办事项 API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 修复认证 Bug
  /ralph-loop 重构缓存层  (永久运行)

停止方式:
  只能通过达到 --max-iterations 或检测到 --completion-promise
  无法手动停止 - Ralph 默认无限运行！

监控:
  # 查看当前迭代:
  Select-String '^iteration:' .claude/ralph-loop.local.md

  # 查看完整状态:
  Get-Content .claude/ralph-loop.local.md -Head 10
"@
            exit 0
        }
        '^--max-iterations$' {
            $i++
            if ($i -ge $Arguments.Count) {
                Write-Host "错误：--max-iterations 需要一个数字参数" -ForegroundColor Red
                exit 1
            }
            $val = $Arguments[$i]
            if ($val -notmatch '^\d+$') {
                Write-Host "错误：--max-iterations 必须是正整数或 0，收到：$val" -ForegroundColor Red
                exit 1
            }
            $maxIterations = [int]$val
            break
        }
        '^--completion-promise$' {
            $i++
            if ($i -ge $Arguments.Count) {
                Write-Host "错误：--completion-promise 需要一个文本参数" -ForegroundColor Red
                exit 1
            }
            $completionPromise = $Arguments[$i]
            break
        }
        default {
            $promptParts += $arg
        }
    }
    $i++
}

# 用空格连接所有提示词部分
$prompt = $promptParts -join ' '

# 验证提示词非空
if ([string]::IsNullOrWhiteSpace($prompt)) {
    Write-Host "错误：未提供提示词" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Ralph 需要一个任务描述才能工作。"
    Write-Host ""
    Write-Host "   示例："
    Write-Host "     /ralph-loop 为待办事项构建 REST API"
    Write-Host "     /ralph-loop 修复认证 Bug --max-iterations 20"
    Write-Host ""
    Write-Host "   查看所有选项：/ralph-loop --help"
    exit 1
}

# 为停止钩子创建状态文件（带 YAML 前置数据的 markdown）
if (-not (Test-Path ".claude")) {
    New-Item -ItemType Directory -Path ".claude" -Force | Out-Null
}

# 如果完成承诺包含特殊字符或非 null，则为 YAML 引用它
if ($completionPromise -and $completionPromise -ne "null") {
    $completionPromiseYaml = "`"$completionPromise`""
}
else {
    $completionPromiseYaml = "null"
}

$startedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

$stateContent = @"
---
active: true
iteration: 1
max_iterations: $maxIterations
completion_promise: $completionPromiseYaml
started_at: "$startedAt"
---
[PERSONA]你是一名有15年经验的软件开发专家。
[STAKES]这个任务会直接影响我们系统的成功与否，如果方案足够好，能帮我们一年省下 $ 50,000 的基础设施成本。
[INCENTIVE]如果你能给出一个真正可用于生产的完美方案，这个答案至少值 $ 200。
[CHALLENGE]我打赌你很难一次做到位。
[METHODOLOGY]先深呼吸，然后一步步来。
[QUALITY CONTROL]回答完之后，请你对自己的答案按 0～1 打一个信心分：
0.0：纯瞎猜
0.5：一般有点把握
0.8：比较有信心
1.0：非常确信 如果任一维度低于 0.9，请说明缺什么信息，然后重新改进答案。
[TASK]
$prompt
"@

Set-Content -Path ".claude/ralph-loop.local.md" -Value $stateContent -Encoding UTF8

# 输出设置消息
$maxIterDisplay = if ($maxIterations -gt 0) { $maxIterations } else { "无限制" }
$promiseDisplay = if ($completionPromise -ne "null") { "$completionPromise (仅在为 TRUE 时输出 - 不要撒谎！)" } else { "无（永久运行）" }

Write-Host @"

Ralph 循环已在当前会话中激活！

迭代次数：1
最大迭代次数：$maxIterDisplay
完成承诺：$promiseDisplay

停止钩子现已激活。当你尝试退出时，相同的提示词将再次提供给你。
你将在文件中看到之前的工作，创建一个自引用循环，让你在同一任务上迭代改进。

监控：Get-Content .claude/ralph-loop.local.md -Head 10

警告：此循环无法手动停止！它将无限运行，
除非你设置了 --max-iterations 或 --completion-promise。


"@

# 输出初始提示词
if ($prompt) {
    Write-Host ""
    Write-Host $prompt
}

