# MAWT: Multi-Agent Worktree Manager (PowerShell Version)
# Usage: mawt.ps1 [command]

$ErrorActionPreference = "Stop"

# Configuration
$MAWT_ROOT = "$HOME\.mawt"
$CONFIG_FILE = "$MAWT_ROOT\config"
$WORKSPACE_DIR = "$HOME\workspace"
$GITLAB_BASE_URL = "https://gitlab.com"
$GITLAB_TOKEN = $null
$GIT_PROTOCOL = "ssh"

# Load Config
if (Test-Path $CONFIG_FILE) {
    Get-Content $CONFIG_FILE | ForEach-Object {
        # Allow spaces around '=', and optional quotes for value
        if ($_ -match '^\s*(\w+)\s*=\s*"?([^"]*)"?\s*$') {
            Set-Variable -Name $matches[1] -Value $matches[2] -Scope Global
        }
    }
}

# Ensure trailing slash removal
if ($GITLAB_BASE_URL.EndsWith("/")) {
    $GITLAB_BASE_URL = $GITLAB_BASE_URL.Substring(0, $GITLAB_BASE_URL.Length - 1)
}

# Helper: Check Dependencies
function Check-Deps {
    $deps = @("git")
    foreach ($dep in $deps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            Write-Error "Error: '$dep' is required but not installed."
            exit 1
        }
    }
}

# Helper: Interactive Selection
function Select-Item {
    param (
        [string[]]$Items,
        [string]$PromptText
    )

    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        # Use fzf if available
        $selected = $Items | fzf --prompt="$PromptText> " --height=40% --layout=reverse
        return $selected
    } elseif ($Host.UI.RawUI.WindowTitle -ne "" -and (Get-Command Out-GridView -ErrorAction SilentlyContinue)) {
        # Use Out-GridView if in a GUI environment
        return $Items | Out-GridView -Title $PromptText -OutputMode Single
    } else {
        # Text-based fallback
        Write-Host $PromptText -ForegroundColor Cyan
        for ($i = 0; $i -lt $Items.Count; $i++) {
            Write-Host "[$($i+1)] $($Items[$i])"
        }
        $choice = Read-Host "Select number"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $Items.Count) {
            return $Items[[int]$choice - 1]
        }
        return $null
    }
}

# 1. Repository Selection
function Select-Repository {
    param ([string]$TargetRepo)

    Write-Host "Fetching project list from GitLab ($GITLAB_BASE_URL)..." -ForegroundColor Cyan

    if (-not $GITLAB_TOKEN) {
        Write-Error "Error: GITLAB_TOKEN is missing in config ($CONFIG_FILE)."
        exit 1
    }

    try {
        $headers = @{ "PRIVATE-TOKEN" = $GITLAB_TOKEN }
        $url = "$GITLAB_BASE_URL/api/v4/projects?membership=true&simple=true&per_page=100&order_by=last_activity_at"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    } catch {
        Write-Error "Error: Failed to fetch projects. Check your token and URL."
        exit 1
    }

    $displayList = @()
    $repoMap = @{}

    foreach ($project in $response) {
        $path = $project.path_with_namespace
        $localPath = Join-Path $WORKSPACE_DIR $project.path
        
        $prefix = "[Remote]"
        if (Test-Path $localPath) {
            $prefix = "[Local] "
        }
        
        $displayString = "$prefix $path"
        $displayList += $displayString
        $repoMap[$displayString] = $project
    }

    $selectedLine = $null
    if ($TargetRepo) {
        $selectedLine = $displayList | Where-Object { $_ -match "$TargetRepo$" } | Select-Object -First 1
        if (-not $selectedLine) {
            Write-Error "Repository '$TargetRepo' not found."
            exit 1
        }
    } else {
        $selectedLine = Select-Item -Items $displayList -PromptText "Select Repository"
    }

    if (-not $selectedLine) {
        Write-Host "No repository selected."
        exit 0
    }

    $project = $repoMap[$selectedLine]
    
    # Return object with details
    return @{
        Name = $project.path
        Path = $project.path_with_namespace
        SshUrl = $project.ssh_url_to_repo
        HttpUrl = $project.http_url_to_repo
    }
}

# 2. Ensure Clone (Bare Repo)
function Ensure-Cloned {
    param ($RepoInfo)

    $targetDir = Join-Path $WORKSPACE_DIR $RepoInfo.Name

    if (Test-Path $targetDir) {
        if (Test-Path (Join-Path $targetDir ".bare")) {
            return # Already set up
        } elseif (Test-Path (Join-Path $targetDir ".git")) {
            Write-Host "Standard repository detected at $targetDir." -ForegroundColor Yellow
            $confirm = Read-Host "Convert to Worktree structure? (y/N)"
            if ($confirm -match "^[yY]$") {
                Convert-ToWorktree -RepoPath $targetDir
                return
            } else {
                Write-Error "Cannot proceed without conversion."
                exit 1
            }
        } else {
            Write-Error "Directory $targetDir exists but is not a valid git repo structure for MAWT."
            exit 1
        }
    }

    # Determine URL
    $cloneUrl = $RepoInfo.SshUrl
    if ($GIT_PROTOCOL -eq "https") {
        $cloneUrl = $RepoInfo.HttpUrl
        if ($GITLAB_TOKEN) {
            # Inject token: https://oauth2:TOKEN@gitlab.com/...
            $parts = $cloneUrl -split "://"
            $cloneUrl = "$($parts[0])://oauth2:$($GITLAB_TOKEN)@$($parts[1])"
        }
    }

    Write-Host "Cloning $($RepoInfo.Name)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    
    # Clone bare
    git clone --bare $cloneUrl (Join-Path $targetDir ".bare")

    # Configure fetch
    Push-Location (Join-Path $targetDir ".bare")
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    Pop-Location
    
    Write-Host "Repository cloned successfully." -ForegroundColor Green
}

function Convert-ToWorktree {
    param ($RepoPath)
    Write-Host "Converting '$RepoPath'..."
    Move-Item (Join-Path $RepoPath ".git") (Join-Path $RepoPath ".bare")
    
    Push-Location (Join-Path $RepoPath ".bare")
    git config --bool core.bare true
    $branchName = git symbolic-ref --short HEAD
    Pop-Location
    
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath $branchName) | Out-Null
    
    Push-Location (Join-Path $RepoPath ".bare")
    git worktree add "../$branchName" "$branchName"
    Pop-Location
    
    Write-Host "Converted." -ForegroundColor Green
}

# 3. Worktree Selection
function Select-Worktree {
    param ($RepoInfo)
    $repoDir = Join-Path $WORKSPACE_DIR $RepoInfo.Name
    $bareDir = Join-Path $repoDir ".bare"
    
    Push-Location $bareDir
    Write-Host "Fetching updates..." -ForegroundColor Gray
    git fetch --all --prune | Out-Null
    
    $worktrees = git worktree list
    $wtList = @()
    foreach ($line in $worktrees) {
        # git worktree list format: path    commit-hash [branch]
        # Use greedy match for path to handle spaces, expecting hash and branch at the end
        if ($line -match "^(.+)\s+([0-9a-fA-F]+)\s+\[(.*)\]") {
           if ($line -notmatch ".bare") {
               $wtList += $line
           }
        }
    }
    
    $action = "Create New Worktree"
    $selection = $null
    
    if ($wtList.Count -gt 0) {
        $menuItems = @("Create New Worktree") + $wtList
        $selection = Select-Item -Items $menuItems -PromptText "Choose Action"
    } else {
        $selection = "Create New Worktree"
    }
    
    if (-not $selection) { exit 0 }
    
    if ($selection -eq "Create New Worktree") {
        return Create-NewWorktree -RepoDir $repoDir
    } else {
        # Extract path.
        if ($selection -match "^(.+)\s+[0-9a-fA-F]+") {
            return $matches[1]
        }
        return $null
    }
    Pop-Location
}

function Create-NewWorktree {
    param ($RepoDir)
    Push-Location (Join-Path $RepoDir ".bare")
    
    Write-Host "Fetching branches..."
    $branches = git branch -r | Where-Object { $_ -notmatch "HEAD" } | ForEach-Object { $_.Trim() -replace "^origin/", "" }
    
    $baseBranch = Select-Item -Items $branches -PromptText "Select Base Branch"
    if (-not $baseBranch) { Write-Error "No base branch selected."; exit 1 }
    
    $newBranch = Read-Host "Enter new branch name (Leave empty to use '$baseBranch')"
    if (-not $newBranch) { $newBranch = $baseBranch }
    
    $targetPath = Join-Path $RepoDir $newBranch
    if (Test-Path $targetPath) {
        $targetPath = "${targetPath}_$(Get-Date -Format 'yyyyMMddHHmmss')"
    }
    
    Write-Host "Creating worktree '$newBranch'..."
    
    # Check if branch exists locally
    if (git show-ref --verify --quiet "refs/heads/$newBranch") {
        Write-Host "Branch '$newBranch' exists locally."
        git worktree add "$targetPath" "$newBranch"
    } else {
        git worktree add "$targetPath" -b "$newBranch" "origin/$baseBranch"
    }
    
    Pop-Location
    return $targetPath
}

# 4. Agent Launch
function Launch-Agent {
    param ($WorktreePath)
    
    if (-not (Test-Path $WorktreePath)) {
        Write-Error "Worktree path not found: $WorktreePath"
        exit 1
    }
    
    Set-Location $WorktreePath
    Write-Host "Switched to: $WorktreePath" -ForegroundColor Green
    
    $agents = @("gemini", "claude", "codex", "powershell")
    $agent = Select-Item -Items $agents -PromptText "Select AI Agent"
    
    if (-not $agent) { exit 0 }
    
    Check-Auth -Agent $agent
    
    Write-Host "Launching $agent..." -ForegroundColor Cyan
    
    if ($agent -eq "powershell") {
        # Start a nested shell
        pwsh
    } else {
        if (Get-Command $agent -ErrorAction SilentlyContinue) {
            & $agent
        } else {
            Write-Error "$agent not found in PATH."
        }
    }
}

function Check-Auth {
    param ($Agent)
    $keyVar = ""
    $keyName = ""
    
    switch ($Agent) {
        "gemini" { $keyVar = "GEMINI_API_KEY"; $keyName = "Gemini API Key" }
        "claude" { $keyVar = "ANTHROPIC_API_KEY"; $keyName = "Anthropic API Key" }
        "codex"  { $keyVar = "OPENAI_API_KEY"; $keyName = "OpenAI API Key" }
    }
    
    if ($keyVar -and -not (Get-Item "Env:$keyVar" -ErrorAction SilentlyContinue)) {
        Write-Host "Authentication required for $Agent."
        $choice = Read-Host "1) Enter API Key  2) Skip (Use system auth) [1/2]"
        if ($choice -eq "1") {
            $key = Read-Host "Enter $keyName" -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($key)
            $plainKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            
            # Export to current session
            Set-Item -Path "Env:$keyVar" -Value $plainKey
            
            # Save to config
            Add-Content -Path $CONFIG_FILE -Value "`n$keyVar=`"$plainKey`""
            Write-Host "Key saved to config."
        }
    }
}

# Main Dispatch
Check-Deps

$command = $args[0]
$arg2 = $args[1]

switch ($command) {
    "init" {
        if (-not $arg2) { Write-Error "Usage: mawt init <group/project>"; exit 1 }
        $repo = Select-Repository -TargetRepo $arg2
        Ensure-Cloned -RepoInfo $repo
    }
    "list" {
        Write-Host "Managed Repositories in ${WORKSPACE_DIR}:"
        Get-ChildItem $WORKSPACE_DIR | ForEach-Object {
            if (Test-Path (Join-Path $_.FullName ".bare")) {
                Write-Host "- $($_.Name)" -ForegroundColor Cyan
                Push-Location (Join-Path $_.FullName ".bare")
                git worktree list | ForEach-Object { Write-Host "    $_" }
                Pop-Location
            }
        }
    }
    "uninstall" {
        $confirm = Read-Host "Uninstall MAWT? (yes/no)"
        if ($confirm -eq "yes") {
            Remove-Item -Recurse -Force $MAWT_ROOT
            Write-Host "Uninstalled."
        }
    }
    "help" {
        Write-Host "Usage: mawt [command]"
        Write-Host "  (No args)  Start interactive workflow"
        Write-Host "  init <repo> Initialize repository"
        Write-Host "  list       List repositories"
        Write-Host "  uninstall  Remove MAWT"
    }
    Default {
        $repo = Select-Repository
        Ensure-Cloned -RepoInfo $repo
        $wt = Select-Worktree -RepoInfo $repo
        if ($wt) {
            Launch-Agent -WorktreePath $wt
        }
    }
}
