# Ralph Wiggum Stop Hook (Windows/PowerShell)
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop

$ErrorActionPreference = "Stop"

# Read hook input from stdin (advanced stop hook API)
$hookInput = $input | Out-String

# Check if ralph-loop is active
$ralphStateFile = ".claude/ralph-loop.local.md"

if (-not (Test-Path $ralphStateFile)) {
    # No active loop - allow exit
    exit 0
}

# Read the state file
$content = Get-Content $ralphStateFile -Raw

# Parse YAML frontmatter (between --- markers)
$frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---')
if (-not $frontmatterMatch.Success) {
    Write-Host "Ralph loop: State file corrupted (no frontmatter found)" -ForegroundColor Red
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
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Check if max iterations reached
if ($maxIterations -gt 0 -and $iteration -ge $maxIterations) {
    Write-Host "Ralph loop: Max iterations ($maxIterations) reached."
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Get transcript path from hook input (JSON)
try {
    $hookData = $hookInput | ConvertFrom-Json
    $transcriptPath = $hookData.transcript_path
}
catch {
    Write-Host "Ralph loop: Failed to parse hook input as JSON" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) {
    Write-Host "Ralph loop: Transcript file not found" -ForegroundColor Red
    Write-Host "Expected: $transcriptPath" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

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
    Remove-Item $ralphStateFile -Force
    exit 0
}

if ([string]::IsNullOrEmpty($lastOutput)) {
    Write-Host "Ralph loop: Assistant message contained no text content" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

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

# Not complete - continue loop with SAME PROMPT
$nextIteration = $iteration + 1

# Extract prompt (everything after the closing ---)
$promptMatch = [regex]::Match($content, '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$')
if (-not $promptMatch.Success -or [string]::IsNullOrWhiteSpace($promptMatch.Groups[1].Value)) {
    Write-Host "Ralph loop: State file corrupted - no prompt text found" -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

$promptText = $promptMatch.Groups[1].Value.Trim()

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

Write-Output $result

exit 0
