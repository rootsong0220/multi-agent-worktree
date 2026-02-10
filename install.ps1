# MAWT Installer for Windows (PowerShell)

$ErrorActionPreference = "Stop"
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
$ScriptUrl = "https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/$InstallBranch/bin/mawt.ps1"
Write-Host "Downloading mawt.ps1 from branch '$InstallBranch' on GitHub..." -ForegroundColor Cyan
Write-Host "Targeting: $MawtScriptPath" -ForegroundColor DarkGray
Invoke-WebRequest -Uri $ScriptUrl -OutFile $MawtScriptPath -UseBasicParsing

if (Test-Path $MawtScriptPath) {
    Write-Host "MAWT script download complete." -ForegroundColor Green
    Write-Host "Verifying downloaded mawt.ps1 content (first 8 lines):" -ForegroundColor DarkGray
    (Get-Content -Path $MawtScriptPath -TotalCount 8) | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
} else {
    Write-Error "Error: Failed to download mawt.ps1 to $MawtScriptPath." -ForegroundColor Red
    exit 1
}

# Create a wrapper batch file for easy execution in cmd/powershell as 'mawt'
$BatchContent = @"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0mawt.ps1" %*
"@
Set-Content -Path "$BinDir\mawt.cmd" -Value $BatchContent
Write-Host "'mawt.cmd' wrapper created at $BinDir" -ForegroundColor Green

Write-Host "MAWT scripts installed to $BinDir" -ForegroundColor Green

# 3. Add to PATH
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($CurrentPath -notlike "*$BinDir*") {
    Write-Host "Adding $BinDir to User PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$BinDir", "User")
    Write-Host "Path updated. You may need to restart your terminal." -ForegroundColor Yellow
} else {
    Write-Host "Path already configured."
}

# 4. Configuration
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
