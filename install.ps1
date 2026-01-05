# Ralph Wiggum Windows - Project-Level Installer
# Installs the Ralph Wiggum plugin to the current project's .claude directory

param(
    [switch]$KeepSource,
    [string]$SourcePath = ""
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Ralph Wiggum Windows - Project-Level Installer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Determine source path
$repoUrl = "https://github.com/Arthur742Ramos/ralph-wiggum-windows"
$tempClone = $false

if ($SourcePath -and (Test-Path $SourcePath)) {
    Write-Host "Using existing source: $SourcePath" -ForegroundColor Gray
}
elseif (Test-Path ".claude/ralph-wiggum-windows/.claude-plugin/plugin.json") {
    $SourcePath = ".claude/ralph-wiggum-windows"
    Write-Host "Using existing clone: $SourcePath" -ForegroundColor Gray
}
else {
    # Clone to temp location
    $SourcePath = ".claude/ralph-wiggum-windows-temp"
    Write-Host "Cloning repository..." -ForegroundColor Yellow

    if (Test-Path $SourcePath) {
        Remove-Item $SourcePath -Recurse -Force
    }

    git clone --depth 1 $repoUrl $SourcePath 2>&1 | Out-Null

    if (-not (Test-Path "$SourcePath/.claude-plugin/plugin.json")) {
        Write-Host "ERROR: Failed to clone repository" -ForegroundColor Red
        exit 1
    }

    $tempClone = $true
    Write-Host "Repository cloned successfully" -ForegroundColor Green
}

# Create target directories
Write-Host "Creating directories..." -ForegroundColor Yellow
$targetDir = ".claude/plugins/ralph-wiggum-windows"

New-Item -ItemType Directory -Path "$targetDir/.claude-plugin" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDir/commands" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDir/hooks" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDir/scripts" -Force | Out-Null

# Copy files
Write-Host "Copying files..." -ForegroundColor Yellow

Copy-Item "$SourcePath/.claude-plugin/plugin.json" "$targetDir/.claude-plugin/" -Force
Copy-Item "$SourcePath/commands/*.md" "$targetDir/commands/" -Force
Copy-Item "$SourcePath/hooks/*.ps1" "$targetDir/hooks/" -Force
Copy-Item "$SourcePath/scripts/*.ps1" "$targetDir/scripts/" -Force

# Copy optional files if they exist
if (Test-Path "$SourcePath/README.md") {
    Copy-Item "$SourcePath/README.md" "$targetDir/" -Force
}
if (Test-Path "$SourcePath/LICENSE") {
    Copy-Item "$SourcePath/LICENSE" "$targetDir/" -Force
}

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Yellow

$requiredFiles = @(
    "$targetDir/.claude-plugin/plugin.json",
    "$targetDir/commands/ralph-loop.md",
    "$targetDir/commands/cancel-ralph.md",
    "$targetDir/commands/help-ralph.md",
    "$targetDir/hooks/stop-hook.ps1",
    "$targetDir/scripts/setup-ralph-loop.ps1"
)

$allPresent = $true
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "  MISSING: $file" -ForegroundColor Red
        $allPresent = $false
    }
}

if (-not $allPresent) {
    Write-Host ""
    Write-Host "ERROR: Installation incomplete - some files are missing" -ForegroundColor Red
    exit 1
}

# Cleanup temp clone
if ($tempClone -and -not $KeepSource) {
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    Remove-Item $SourcePath -Recurse -Force -ErrorAction SilentlyContinue
}
elseif ($KeepSource) {
    Write-Host "Keeping source at: $SourcePath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Installation successful!" -ForegroundColor Green
Write-Host ""
Write-Host "Installed to: $targetDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available commands:" -ForegroundColor White
Write-Host "  /ralph-wiggum-windows:ralph-loop  - Start a Ralph loop" -ForegroundColor Gray
Write-Host "  /ralph-wiggum-windows:cancel-ralph - Cancel active loop" -ForegroundColor Gray
Write-Host "  /ralph-wiggum-windows:help-ralph   - Show help" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Restart Claude Code to load the plugin" -ForegroundColor Gray
Write-Host "  2. Run: claude plugin validate $targetDir" -ForegroundColor Gray
Write-Host ""
