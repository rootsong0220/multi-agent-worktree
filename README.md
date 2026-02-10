# Multi-Agent Worktree Manager (MAWT)

A CLI wrapper to manage GitLab repositories using Git Worktrees, specifically designed to orchestrate AI agents (Gemini, ClaudeCode, Codex) in isolated environments.

## Overview

MAWT simplifies the workflow of using multiple AI agents on the same codebase without conflicts. It handles:
- **Private GitLab Integration**: Fetches repository lists from your GitLab instance.
- **Smart Cloning**: Clones repositories as "bare" repos by default to enable Git Worktrees.
- **Conversion**: Detects existing standard repositories and converts them to a Worktree structure upon request.
- **Agent Dispatch**: Launches specific AI CLI tools in their own isolated worktrees.
- **WSL Optimized**: Built with Windows Subsystem for Linux in mind.

## Prerequisites

- **Tools**: `git`, `curl`, `jq`, `unzip`, `tar`
- **Optional**: `fzf` (for better interactive selection)

## Installation & Updates

To install or update **mawt**, run the following command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/install.sh | bash
```

**After Installation:**
To use `mawt` immediately in your current terminal session, run:
```bash
# For Bash users
source ~/.bashrc

# For Zsh users
source ~/.zshrc
```
Alternatively, simply restart your terminal.

### First-Time Setup
During the first installation, the script will interactively ask for your preferences:
1.  **Workspace Directory**: Where to store your repositories.
2.  **Git Protocol**: Choose between `SSH` (recommended) or `HTTPS`.
3.  **GitLab Base URL**: (New) URL of your GitLab instance (e.g., `http://gitlab.mycompany.com`).
4.  **GitLab Token**: Required for fetching the project list from your Private GitLab instance.

*These settings are saved to `~/.mawt/config`.*

### Updating
To update `mawt` to the latest version, simply run the installation command again. It will detect your existing configuration and update the binary without overwriting your settings.

## Usage

### 1. Initialize a Repository (`init`)
Prepares a repository for worktree management. You can provide arguments or use the interactive mode.

```bash
mawt init
# Follow the prompts to enter the repo URL or path
```
Or directly:
```bash
mawt init group/project
```

### 2. Start an Agent Session (`work`)
Creates a new isolated worktree and launches an AI agent.

**Interactive Mode (Recommended):**
```bash
mawt work
```
1.  Select a repository from your workspace.
2.  Choose an agent (`gemini`, `claude`, `codex`).
3.  Enter a name for the task (e.g., `fix-bug`).

**Direct Mode:**
```bash
# Syntax: mawt work <repo_name> <agent_name> [task_name]
mawt work my-project gemini fix-login-bug
```

### 3. List Repositories (`list`)
Shows all repositories managed by MAWT and their active worktrees.


```bash
mawt list
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the detailed development plan.
