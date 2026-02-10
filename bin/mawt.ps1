# MAWT: Multi-Agent Worktree Manager (PowerShell Version)
# Usage: mawt.ps1 [command]

$ErrorActionPreference = "Stop"

# Configuration
$MAWT_ROOT = "$HOME\.mawt"
$CONFIG_FILE = "$MAWT_ROOT\config"
$WORKSPACE_DIR = "$HOME\workspace"
$GITLAB_BASE_URL = "https://gitlab.com"
$GITLAB_TOKEN = $null


# Load Config
if (Test-Path $CONFIG_FILE) {
    Write-Host "DEBUG: Loading config from $CONFIG_FILE" -ForegroundColor DarkGray
    Get-Content $CONFIG_FILE | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return }
        
        Write-Host "DEBUG: Read line: '$line'" -ForegroundColor DarkGray
        
        # Allow spaces around '=', and optional quotes for value
        if ($line -match '^\s*(\w+)\s*=\s*"?([^"]*)"?\s*$') {
            $key = $matches[1]
            $val = $matches[2]
            Write-Host "DEBUG: Set $key = *** (hidden)" -ForegroundColor DarkGray
            switch ($key) {
                "GITLAB_TOKEN" { $script:GITLAB_TOKEN = $val }
                "GITLAB_BASE_URL" { $script:GITLAB_BASE_URL = $val }
                "WORKSPACE_DIR" { $script:WORKSPACE_DIR = $val }
                "GIT_PROTOCOL" { $script:GIT_PROTOCOL = $val }
                "GEMINI_AUTH_MODE" { $env:GEMINI_AUTH_MODE = $val }
            }
        } else {
            Write-Host "DEBUG: Line did not match regex" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "DEBUG: Config file not found at $CONFIG_FILE" -ForegroundColor Red
}

Write-Host "DEBUG: Final GITLAB_TOKEN status: $(if ($GITLAB_TOKEN) { 'Set' } else { 'NULL' })" -ForegroundColor DarkGray

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
    } else {
        # Text-based fallback
        Write-Host "${PromptText}:" -ForegroundColor Cyan
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
    # Default to HTTPS unless GIT_PROTOCOL is explicitly set to "ssh"
    $cloneUrl = $RepoInfo.HttpUrl
    if ($GIT_PROTOCOL -eq "ssh") {
        $cloneUrl = $RepoInfo.SshUrl
    } else {
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
    
    $worktrees = git worktree list | Where-Object { $_ -notmatch ".bare" } | ForEach-Object { 
        # Extract path from line like "/path/to/worktree   commit-hash [branch-name]"
        if ($_ -match "^(.+?)\s+[0-9a-fA-F]+\s+\[(.+)\]$") {
            return "$($matches[1]) [$($matches[2])]"
        } else {
            return $_ # Fallback for unexpected format
        }
    }
    
    $action = "Create New Worktree"
    $selection = $null
    
    if ($worktrees.Count -gt 0) {
        $menuItems = @("Create New Worktree") + $worktrees
        $selection = Select-Item -Items $menuItems -PromptText "Choose Action"
    } else {
        $selection = "Create New Worktree"
    }
    
    if (-not $selection) { Pop-Location; exit 0 }
    
    if ($selection -eq "Create New Worktree") {
        $createdWorktreePath = Create-NewWorktree -RepoDir $repoDir
        Pop-Location
        return $createdWorktreePath
    } else {
        # Extract path from line, which is the first part before '['
        if ($selection -match "^(.+?)\s+\[") {
            Pop-Location
            return $matches[1].Trim()
        }
        Pop-Location
        return $null
    }
}

function Create-NewWorktree {
    param ($RepoDir)
    Push-Location (Join-Path $RepoDir ".bare")
    
    Write-Host "Fetching branches..."
    $branches = git branch -r | Where-Object { $_ -notmatch "HEAD" } | ForEach-Object { $_.Trim() -replace "^origin/", "" }
    
    $baseBranch = Select-Item -Items $branches -PromptText "Select Base Branch"
    if (-not $baseBranch) { Write-Error "No base branch selected."; Pop-Location; exit 1 }
    
    $inputNewBranchName = Read-Host "Enter new branch name (Leave empty to attach to existing '$baseBranch')"
    
    $isNewBranchCreation = ![string]::IsNullOrWhiteSpace($inputNewBranchName)
    $worktreeTargetBranchName = if ($isNewBranchCreation) { $inputNewBranchName } else { $baseBranch }

    # Construct target path for the worktree directory
    $worktreeDirName = $worktreeTargetBranchName
    $targetPath = Join-Path $RepoDir $worktreeDirName
    if (Test-Path $targetPath) {
        $targetPath = "${targetPath}_$(Get-Date -Format 'yyyyMMddHHmmss')"
    }
    
    Write-Host "Preparing to create worktree for branch '$worktreeTargetBranchName' at '$targetPath'..." -ForegroundColor Cyan
    
    $commandArgs = @("worktree", "add", "$targetPath")
    
    # --- Logic for handling existing branches / force attaching ---
    $branchExistsLocally = git show-ref --verify --quiet "refs/heads/$worktreeTargetBranchName"
    $branchIsUsedByOtherWorktree = (git worktree list | Select-String -Pattern "$worktreeTargetBranchName").Count -gt 1

    if ($isNewBranchCreation) {
        # User explicitly asked to create a NEW branch with $inputNewBranchName
        if ($branchExistsLocally) {
            # If the user asked to create a *new* branch but a local branch with that name already exists.
            Write-Host "A local branch named '$worktreeTargetBranchName' already exists. Attempting to attach to it." -ForegroundColor Yellow
            $commandArgs += $worktreeTargetBranchName # Attach to the existing local branch
            if ($branchIsUsedByOtherWorktree) {
                Write-Host "Branch '$worktreeTargetBranchName' is also currently checked out in another worktree." -ForegroundColor Yellow
                $force = Read-Host "Force attach? This may detach another worktree. (y/N)"
                if ($force -match "^[yY]$") {
                    $commandArgs += "-f"
                } else {
                    Write-Host "Aborted." -ForegroundColor Yellow; Pop-Location; return $null
                }
            }
        } else {
            # Create a genuinely new local branch
            $commandArgs += "-b"; $commandArgs += "$worktreeTargetBranchName"; $commandArgs += "origin/$baseBranch"
        }
    } else {
        # User left branch name empty, meaning they want to attach to the existing $baseBranch
        $commandArgs += "$worktreeTargetBranchName" # This is $baseBranch
        if ($branchIsUsedByOtherWorktree) {
            Write-Host "Branch '$worktreeTargetBranchName' is already checked out in another worktree." -ForegroundColor Yellow
            $force = Read-Host "Force attach? This may detach another worktree. (y/N)"
            if ($force -match "^[yY]$") {
                $commandArgs += "-f"
            } else {
                Write-Host "Aborted." -ForegroundColor Yellow; Pop-Location; return $null
            }
        }
    }

    # Execute git worktree add and capture output
    # Use call operator and redirect all streams for better compatibility with older PowerShell
    $command = "git"

    # Define temp file paths within the function for explicit stream capture
    $tempGitStdoutPath = Join-Path $env:TEMP "mawt_git_stdout_$(Get-Random).txt"
    $tempGitStderrPath = Join-Path $env:TEMP "mawt_git_stderr_$(Get-Random).txt"

    # Clear $Error before invoking to prevent previous errors from affecting $?
    $Error.Clear()
    
    # Execute git worktree add using Start-Process for better control over output streams
    try {
        Write-Host "Executing git command: git $($commandArgs -join ' ')" -ForegroundColor DarkGray
        $process = Start-Process -FilePath $command -ArgumentList $commandArgs -RedirectStandardOutput $tempGitStdoutPath -RedirectStandardError $tempGitStderrPath -PassThru -Wait -ErrorAction Stop # -NoNewWindow removed
        $exitCode = $process.ExitCode

        # Give a small moment for file system to sync, though typically not needed in PowerShell
        Start-Sleep -Milliseconds 100
        
        $stdoutContent = if (Test-Path $tempGitStdoutPath) { Get-Content $tempGitStdoutPath | Out-String } else { "" }
        $stderrContent = if (Test-Path $tempGitStderrPath) { Get-Content $tempGitStderrPath | Out-String } else { "" }

    } catch {
        Write-Error "Error executing git command: $($_.Exception.Message)" -ForegroundColor Red
        Pop-Location
        return $null
    } finally {
        # Ensure temp files are cleaned up
        if (Test-Path $tempGitStdoutPath) { Remove-Item $tempGitStdoutPath -ErrorAction SilentlyContinue }
        if (Test-Path $tempGitStderrPath) { Remove-Item $tempGitStderrPath -ErrorAction SilentlyContinue }
    }
    
    # Display git's raw output for diagnostics
    if (-not [string]::IsNullOrEmpty($stdoutContent.Trim())) {
        Write-Host "Git stdout: $($stdoutContent.Trim())" -ForegroundColor DarkGray
    }
    if (-not [string]::IsNullOrEmpty($stderrContent.Trim())) {
        Write-Host "Git stderr: $($stderrContent.Trim())" -ForegroundColor Yellow # Use yellow for stderr
    }
    Write-Host "Git command ExitCode: $exitCode" -ForegroundColor DarkGray # Explicitly show Git's ExitCode

    if ($exitCode -ne 0) {
        Write-Error "Error creating worktree (Git Exit Code $exitCode). See above output for details." -ForegroundColor Red
        Pop-Location
        return $null
    } else {
        # If exit code is 0, but there's stderr output, treat as warning.
        if (-not [string]::IsNullOrWhiteSpace($stderrContent)) {
            Write-Warning "Git command produced stderr output, but exited with code 0: $($stderrContent.Trim())"
        }
        Write-Host "Worktree for '$worktreeTargetBranchName' created at $targetPath." -ForegroundColor Green
        Pop-Location
        return $targetPath
    }
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
    
    $agentArgs = @()
    $selectedModel = $null

    switch ($agent) {
        "gemini" {
            $models = @("gemini-3-pro-preview", "gemini-3-flash-preview", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro") # 업데이트된 Gemini 모델 목록
            $selectedModel = Select-Item -Items $models -PromptText "Select Gemini Model"
            if ($selectedModel) {
                # Directly call Node.js with the Gemini CLI entry point, bypassing gemini.ps1 wrapper.
                # We need to find node.exe and the correct path to index.js.
                # Path to index.js is likely relative to global npm install location.
                # Assuming node.exe is in PATH.
                
                # Construct the path to the Gemini CLI index.js script.
                # This path is based on common global npm install locations on Windows (e.g., %APPDATA%\npm).
                # The original gemini.ps1 used $basedir which was C:\Users\User\AppData\Roaming\npm
                # So, index.js path is C:\Users\User\AppData\Roaming\npm\node_modules\@google\gemini-cli\dist\index.js
                # Use $env:APPDATA\npm for the global npm prefix path.
                $geminiCliJsPath = Join-Path $env:APPDATA\npm "node_modules\@google\gemini-cli\dist\index.js"
                
                # Check if node is available in PATH
                if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
                    Write-Error "Node.js is not found in PATH. Please install Node.js or ensure it's in your PATH."
                    return # Exit Launch-Agent
                }

                # Construct arguments for Node.js
                $nodeArgs = @(
                    $geminiCliJsPath,
                    "--model",
                    $selectedModel
                )

                Write-Host "DEBUG: Running Gemini CLI directly via Node.js:" -ForegroundColor Magenta
                Write-Host "DEBUG: Node executable: 'node'" -ForegroundColor Magenta
                Write-Host "DEBUG: Node arguments: '$($nodeArgs -join ' ')'" -ForegroundColor Magenta
                
                # Execute Node.js with the Gemini CLI script and arguments using Start-Process
                # Start-Process is generally robust for passing arguments and handling output.
                try {
                    # Ensure process details are captured and wait for completion.
                    # Redirecting output to temp files to inspect it.
                    $tempOut = Join-Path $env:TEMP "gemini_out.txt"
                    $tempErr = Join-Path $env:TEMP "gemini_err.txt"
                    
                    # Use -NoNewWindow for a cleaner execution within the CLI.
                    # -Wait ensures the script waits for Node.js to finish.
                    $proc = Start-Process -FilePath "node" -ArgumentList $nodeArgs -Wait -PassThru -NoNewWindow
                    $exitCode = $proc.ExitCode

                    # Read output from temp files
                    $stdoutContent = if (Test-Path $tempOut) { Get-Content $tempOut | Out-String } else { "" }
                    $stderrContent = if (Test-Path $tempErr) { Get-Content $tempErr | Out-String } else { "" }

                    if ($stdoutContent) { Write-Host "Gemini stdout: $($stdoutContent.Trim())" }
                    if ($stderrContent) { Write-Host "Gemini stderr: $($stderrContent.Trim())" -ForegroundColor Yellow }

                    if ($exitCode -ne 0) {
                        Write-Error "Gemini CLI exited with code $exitCode."
                    }
                } catch {
                    Write-Error "Error running Gemini CLI: $($_.Exception.Message)"
                } finally {
                    # Clean up temp files
                    if (Test-Path $tempOut) { Remove-Item $tempOut -ErrorAction SilentlyContinue }
                    if (Test-Path $tempErr) { Remove-Item $tempErr -ErrorAction SilentlyContinue }
                }
                
                # Exit Launch-Agent after invoking Gemini CLI directly
                return 
            }
        }
        "claude" {
            $models = @("claude-opus-4-6", "claude-sonnet-4-5-20250929") # 업데이트된 Claude 모델 목록
            $selectedModel = Select-Item -Items $models -PromptText "Select Claude Model"
            if ($selectedModel) { $agentArgs += "--model"; $agentArgs += "$selectedModel" }
        }
        "codex" {
            $models = @("gpt-5.3-codex", "gpt-5.2-codex", "gpt-5.1-codex-mini") # 업데이트된 Codex 모델 목록
            $selectedModel = Select-Item -Items $models -PromptText "Select Codex Model"
            if ($selectedModel) { $agentArgs += "--model"; $agentArgs += "$selectedModel" }
        }
    }

    if ($agent -eq "powershell") {
        # Start a nested shell
        pwsh
    } else {
        if (Get-Command $agent -ErrorAction SilentlyContinue) {
            Write-Host "DEBUG: Agent command: '$agent'" -ForegroundColor Magenta
            Write-Host "DEBUG: Agent arguments: '$($agentArgs -join ' ')'" -ForegroundColor Magenta
            & $agent $agentArgs
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
    
    # Gemini Special Handling
    if ($Agent -eq "gemini") {
        if (-not (Get-Item "Env:GEMINI_AUTH_MODE" -ErrorAction SilentlyContinue)) {
             # Auto-detect: If API Key is present, assume API mode.
             # Otherwise, default to OAuth (System Login).
             if (Get-Item "Env:GEMINI_API_KEY" -ErrorAction SilentlyContinue) {
                 $env:GEMINI_AUTH_MODE = "api"
             } else {
                 $env:GEMINI_AUTH_MODE = "oauth"
             }
        }
        
        if ($env:GEMINI_AUTH_MODE -eq "oauth") {
            # Skip API key check
            return
        }
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
