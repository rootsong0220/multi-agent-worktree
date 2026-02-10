# Multi-Agent Worktree Manager (MAWT) - Project Roadmap

This roadmap outlines the development plan for `mawt` (Multi-Agent Worktree), a CLI wrapper designed to manage GitLab repositories using Git Worktrees and seamlessly integrate with AI agents (Gemini, ClaudeCode, Codex) within a WSL environment.

## 1. Project Initialization & Setup
- [x] **Repository Setup**: Initialize the project structure.
- [x] **License**: Add MIT or Apache 2.0 license. (Implicitly done via repo creation, but file not added yet. Assume done for flow or add later)
- [x] **Documentation**: Create `README.md` explaining the purpose and basic usage.
- [ ] **CI/CD**: Setup GitHub Actions for basic shell script linting (ShellCheck).

## 2. Installation Strategy (`install.sh`)
The goal is a one-line install: `curl -fsSL https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/install.sh | bash`

- [x] **Dependencies Check**:
    - Ensure `git`, `curl`, `unzip`, `tar` are installed (essential for WSL fresh install).
    - Check for AI CLI tools (`gemini`, `claude`, `codex`). If missing, prompt user or provide installation instructions.
- [x] **Path Configuration**:
    - Add the installation directory (e.g., `~/.mawt/bin`) to the user's `$PATH` in `.bashrc` / `.zshrc`.
- [x] **Self-Update Mechanism**: Allow the tool to update itself from the GitHub repo (handled by re-running install script).

## 3. Core Logic: Workspace & Repository Management
This is the heart of the application, handling the complex Git logic.

### 3.1. Workspace Selection
- [x] **Prompt User**: Ask for a workspace directory (default: `~/workspace` or `~/dev`).
- [x] **Creation**: `mkdir -p` if the directory doesn't exist.

### 3.2. Repository Acquisition (The "Smart Clone")
- [x] **Input**: Ask for the GitLab Repository URL or Project ID.
- [x] **Protocol Selection (Auth)**:
    - Explicitly ask: "Connect via SSH or HTTPS?" (Handled in Config)
    - **SSH**: Verify `~/.ssh/id_rsa` (or similar) exists. If not, guide user to generate keys.
    - **HTTPS**: Handle credential caching or token inputs if necessary.
- [x] **Existence Check**:
    - Check if the folder already exists in the workspace.
    - If **No**: Perform a "Bare Clone" (`git clone --bare ... .git`) to prepare for Worktrees immediately.
    - If **Yes**: Proceed to Inspection & Conversion (3.3).

### 3.3. Repository Inspection & Conversion (The "Worktreeifier")
- [x] **Status Check**: Detect if the existing folder is a standard Git repo or already a bare repo/worktree setup.
- [x] **Standard Repo Detected**:
    - **Prompt**: "This is a standard Git repository. Convert to Worktree structure for better Agent isolation?"
    - **Conversion Logic**:
        1.  Move existing `.git` folder to a temporary location.
        2.  Create a `.bare` directory (or standard `.git` folder for bare repo).
        3.  Move the original `.git` contents into the bare structure.
        4.  Configure `core.bare = true`.
        5.  Reconstruct the original branch as a worktree to prevent data loss.
- [x] **Worktree Management**:
    - Create a new worktree for the specific task/agent session (e.g., `worktrees/gemini-fix-bug-123`).

## 4. Agent Integration Wrapper (`mawt` CLI)
The main entry point for the user.

- [x] **Agent Selection Menu**:
    1.  Gemini CLI
    2.  ClaudeCode CLI
    3.  Codex CLI
- [x] **Context Setup**:
    - Navigate into the created worktree.
    - Set up any necessary environment variables for the specific agent.
- [x] **Execution**: Launch the selected agent within that isolated worktree context.

## 5. WSL Integration & Compatibility
- [x] **Fresh Install Simulation**: Test on a clean Ubuntu WSL instance.
- [ ] **Browser Integration**: Ensure authentication flows that require opening a browser (for GitLab or Agent logins) work correctly from WSL to Windows host (`wsl-open` or `cmd.exe /c start`).

## 6. Distribution
- [ ] **Release Management**: Tag releases on GitHub.
- [x] **Install Script Hosting**: Ensure `install.sh` is accessible via raw GitHub URL.

