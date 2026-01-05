# Ralph Loop Setup Script (Windows/PowerShell)
# Creates state file for in-session Ralph loop

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

# Parse arguments
$promptParts = @()
$maxIterations = 0
$completionPromise = "null"

$i = 0
while ($i -lt $Arguments.Count) {
    $arg = $Arguments[$i]

    switch -Regex ($arg) {
        '^(-h|--help)$' {
            Write-Host @"
Ralph Loop - Interactive self-referential development loop (Windows)

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Wiggum loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs forever)

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Ralph runs infinitely by default!

MONITORING:
  # View current iteration:
  Select-String '^iteration:' .claude/ralph-loop.local.md

  # View full state:
  Get-Content .claude/ralph-loop.local.md -Head 10
"@
            exit 0
        }
        '^--max-iterations$' {
            $i++
            if ($i -ge $Arguments.Count) {
                Write-Host "Error: --max-iterations requires a number argument" -ForegroundColor Red
                exit 1
            }
            $val = $Arguments[$i]
            if ($val -notmatch '^\d+$') {
                Write-Host "Error: --max-iterations must be a positive integer or 0, got: $val" -ForegroundColor Red
                exit 1
            }
            $maxIterations = [int]$val
            break
        }
        '^--completion-promise$' {
            $i++
            if ($i -ge $Arguments.Count) {
                Write-Host "Error: --completion-promise requires a text argument" -ForegroundColor Red
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

# Join all prompt parts with spaces
$prompt = $promptParts -join ' '

# Validate prompt is non-empty
if ([string]::IsNullOrWhiteSpace($prompt)) {
    Write-Host "Error: No prompt provided" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Ralph needs a task description to work on."
    Write-Host ""
    Write-Host "   Examples:"
    Write-Host "     /ralph-loop Build a REST API for todos"
    Write-Host "     /ralph-loop Fix the auth bug --max-iterations 20"
    Write-Host ""
    Write-Host "   For all options: /ralph-loop --help"
    exit 1
}

# Create state file for stop hook (markdown with YAML frontmatter)
if (-not (Test-Path ".claude")) {
    New-Item -ItemType Directory -Path ".claude" -Force | Out-Null
}

# Quote completion promise for YAML if it contains special chars or is not null
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

$prompt
"@

Set-Content -Path ".claude/ralph-loop.local.md" -Value $stateContent -Encoding UTF8

# Output setup message
$maxIterDisplay = if ($maxIterations -gt 0) { $maxIterations } else { "unlimited" }
$promiseDisplay = if ($completionPromise -ne "null") { "$completionPromise (ONLY output when TRUE - do not lie!)" } else { "none (runs forever)" }

Write-Host @"

Ralph loop activated in this session!

Iteration: 1
Max iterations: $maxIterDisplay
Completion promise: $promiseDisplay

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

To monitor: Get-Content .claude/ralph-loop.local.md -Head 10

WARNING: This loop cannot be stopped manually! It will run infinitely
unless you set --max-iterations or --completion-promise.


"@

# Output the initial prompt
if ($prompt) {
    Write-Host ""
    Write-Host $prompt
}
