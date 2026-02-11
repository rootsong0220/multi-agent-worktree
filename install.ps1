# MAWT Installer for Windows (PowerShell)

$ErrorActionPreference = "Stop"

# Helper: Check Dependencies
function Check-Deps {
    $deps = @("git", "node", "npm") # Added node and npm
    foreach ($dep in $deps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            Write-Host "Error: '$dep' is required but not installed." -ForegroundColor Red
            Write-Host "To install '$dep', follow these steps:" -ForegroundColor Yellow
            if ($dep -eq "node" -or $dep -eq "npm") {
                Write-Host "  1. Download and install the LTS version from the official Node.js website (https://nodejs.org)."
                Write-Host "  2. Alternatively, if you use Winget (Windows Package Manager), run the following in PowerShell:"
                Write-Host "     winget install OpenJS.NodeJS.LTS"
                Write-Host "  3. After installation, open a new PowerShell window to confirm Path is updated."
            } else {
                Write-Host "  Please manually install '$dep' using your preferred package manager."
            }
            throw "Missing dependency: $dep"
        }
    }
}

# Run dependency check early
Check-Deps

$RepoUrl = "https://github.com/rootsong0220/multi-agent-worktree.git"
$InstallDir = "$HOME\.mawt"
$BinDir = "$InstallDir\bin"
$ConfigFile = "$InstallDir\config"

# Default branch
$InstallBranch = "main"

# Parse arguments from $args (for broader compatibility)
if ($args.Length -ge 2 -and $args[0] -eq "-Branch") {
    $InstallBranch = $args[1]
} elseif ($args.Length -ge 1 -and -not ($args[0] -match '^-')) { # Positional arg for branch
    # This allows for `./install.ps1 feature/windows-support` (less standard for PowerShell)
    # For now, let's stick to named parameter style parsing.
    # If no named parameter, default to main.
    $InstallBranch = "main"
}

Write-Host "Installing Multi-Agent Worktree Manager (MAWT) from branch '$InstallBranch'..." -ForegroundColor Cyan

# 1. Create Directories
if (-not (Test-Path $BinDir)) {
    Write-Host "Creating installation directory: $BinDir" -ForegroundColor DarkGray
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
} else {
    Write-Host "Installation directory already exists: $BinDir" -ForegroundColor DarkGray
}
Write-Host "MAWT installation directory set to: $InstallDir" -ForegroundColor DarkGray
Write-Host "MAWT binaries directory set to: $BinDir" -ForegroundColor DarkGray

# 2. Download MAWT Script
$MawtScriptPath = "$BinDir\mawt.ps1"
$ScriptUrl = "https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/$InstallBranch/bin/mawt.ps1?_=$([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds())"
Write-Host "Downloading mawt.ps1 from branch '$InstallBranch' on GitHub..." -ForegroundColor Cyan
Write-Host "Targeting: $MawtScriptPath" -ForegroundColor DarkGray

$mawtScriptFoundLocally = $false
$currentScriptDir = $null
if ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    $currentScriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
}

# Check if install.ps1 is run from a cloned git repository's root
# This assumes install.ps1 is in the root of the repo (or a parent directory of bin/mawt.ps1)
if ($currentScriptDir -and (Test-Path (Join-Path $currentScriptDir ".git"))) {
    $localMawtPath = Join-Path $currentScriptDir "bin\mawt.ps1"
    if (Test-Path $localMawtPath) {
        Write-Host "Found local mawt.ps1 at $localMawtPath. Copying instead of downloading." -ForegroundColor DarkGreen
        Copy-Item $localMawtPath -Destination $MawtScriptPath -Force
        $mawtScriptFoundLocally = $true
    } else {
        Write-Host "Running from Git repo, but local bin\mawt.ps1 not found. Proceeding with remote download." -ForegroundColor Yellow
    }
}

if (-not $mawtScriptFoundLocally) {
    $maxRetries = 5
    $retryDelaySec = 5
    $downloadSuccess = $false

    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            Write-Host "Attempting download (Attempt $($i + 1)/$maxRetries)..." -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $ScriptUrl -OutFile $MawtScriptPath -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            $downloadSuccess = $true
            break # Exit loop if successful
        } catch {
            Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Yellow
            if ($i -lt ($maxRetries - 1)) {
                Write-Host "Retrying in $retryDelaySec seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $retryDelaySec
            }
        }
    }

    if (-not $downloadSuccess) {
        Write-Error "Error: Failed to download mawt.ps1 after multiple retries to $MawtScriptPath." -ForegroundColor Red
        exit 1
    }
}

if (Test-Path $MawtScriptPath) {
    Write-Host "MAWT script setup complete." -ForegroundColor Green # Changed message
    Write-Host "Verifying mawt.ps1 content (first 8 lines from $MawtScriptPath):" -ForegroundColor DarkGray # Changed message
    (Get-Content -Path $MawtScriptPath -TotalCount 8) | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
} else {
    Write-Error "Error: mawt.ps1 not found at $MawtScriptPath after setup attempts." -ForegroundColor Red # Changed message
    exit 1
}

# Create a wrapper batch file for easy execution in cmd/powershell as 'mawt'
$BatchContent = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"%~dp0mawt.ps1`" %*"
Set-Content -Path "$BinDir\mawt.cmd" -Value $BatchContent
Write-Host "'mawt.cmd' wrapper created at $BinDir" -ForegroundColor Green

Write-Host "MAWT scripts installed to $BinDir" -ForegroundColor Green

# Function to check and install AI CLI tools via NPM
function Check-AiCli {
    param (
        [string]$ToolCommand,
        [string]$NpmPackage
    )

    if (-not (Get-Command $ToolCommand -ErrorAction SilentlyContinue)) {
        Write-Host "AI CLI '$ToolCommand' is not installed." -ForegroundColor Yellow
        
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-Host "npm is not found. Cannot install '$ToolCommand'." -ForegroundColor Yellow
            return
        }

        $confirm = Read-Host "Do you want to install '$ToolCommand' with npm? (y/N)"
        if ($confirm -match "^[yY]$") {
            Write-Host "Installing '$NpmPackage'..." -ForegroundColor Cyan
            try {
                npm install -g $NpmPackage | Out-Null # Suppress npm output
                Write-Host "'$ToolCommand' installed successfully." -ForegroundColor Green
            } catch {
                Write-Error "'$ToolCommand' installation failed: $($_.Exception.Message). Please run manually: npm install -g $NpmPackage" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Skipping '$ToolCommand' installation. You can install it manually later: npm install -g $NpmPackage" -ForegroundColor Yellow
        }
    } else {
        Write-Host "- AI CLI '$ToolCommand': Installed" -ForegroundColor Green
    }
} # Closing brace for function Check-AiCli


# 2. Check AI CLI Tools
Write-Host "`n--- Checking AI Agent CLI Tools ---" -ForegroundColor Cyan

# Gemini CLI
Check-AiCli -ToolCommand "gemini" -NpmPackage "@google/gemini-cli"

# Claude Code
Check-AiCli -ToolCommand "claude" -NpmPackage "@anthropic-ai/claude-code"

# Codex CLI
Check-AiCli -ToolCommand "codex" -NpmPackage "@openai/codex"

# 3. Add to PATH (Previous step 3, now moved after CLI checks)
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($CurrentPath -notlike "*$BinDir*") {
    Write-Host "Adding $BinDir to User PATH..." -ForegroundColor Cyan
    $pathValue = "$CurrentPath;$BinDir"
    [Environment]::SetEnvironmentVariable("Path", $pathValue, "User")
    Write-Host "Path updated. You may need to restart your terminal." -ForegroundColor Yellow
} else {
    Write-Host "Path already configured." -ForegroundColor DarkGray
}

# 4. Configuration (Previous step 4, now moved after Path config)
Write-Host "`n--- Configuration ---" -ForegroundColor Cyan

# Load existing config
$Config = @{}
if (Test-Path $ConfigFile) {
    Get-Content $ConfigFile | ForEach-Object {
        if ($_ -match '^(\w+)="(.*)"$') {
            $Config[$matches[1]] = $matches[2]
        }
    }
}

# Workspace
if (-not $Config.ContainsKey("WORKSPACE_DIR")) {
    $ws = Read-Host "Enter workspace directory (Default: $HOME\workspace)"
    if (-not $ws) { $ws = "$HOME\workspace" }
    $Config["WORKSPACE_DIR"] = $ws
    New-Item -ItemType Directory -Force -Path $ws | Out-Null
}

# Git Protocol
if (-not $Config.ContainsKey("GIT_PROTOCOL")) {
    $proto = Read-Host "Select Git Protocol [1] SSH (Default), [2] HTTPS"
    if ($proto -eq "2") {
        $Config["GIT_PROTOCOL"] = "https"
    } else {
        $Config["GIT_PROTOCOL"] = "ssh"
    }
}

# GitLab URL
if (-not $Config.ContainsKey("GITLAB_BASE_URL")) {
    $url = Read-Host "Enter GitLab Base URL (Default: https://gitlab.com)"
    if (-not $url) { $url = "https://gitlab.com" }
    $Config["GITLAB_BASE_URL"] = $url
}

# GitLab Token
if (-not $Config.ContainsKey("GITLAB_TOKEN")) {
    $token = Read-Host "Enter GitLab Personal Access Token (Required for Private Repos)" -AsSecureString
    if ($token) {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
        $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $Config["GITLAB_TOKEN"] = $plainToken
    }
}

# Save Config
$ConfigContent = ""
foreach ($key in $Config.Keys) {
    $ConfigContent += "$key=`"$($Config[$key])`"`n"
}
Set-Content -Path $ConfigFile -Value $ConfigContent
Write-Host "Configuration saved to $ConfigFile" -ForegroundColor Green

Write-Host "`nInstallation Complete!" -ForegroundColor Green
Write-Host "Please restart your terminal to use 'mawt'."
