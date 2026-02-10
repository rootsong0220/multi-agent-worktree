# Multi-Agent Worktree Manager (MAWT)

A CLI wrapper to manage GitLab repositories using Git Worktrees, specifically designed to orchestrate AI agents (Gemini, ClaudeCode, Codex) in isolated environments.

## Overview

MAWT simplifies the workflow of using multiple AI agents on the same codebase without conflicts. It handles:
- **Smart Cloning**: Clones repositories as "bare" repos by default to enable Git Worktrees.
- **Conversion**: Detects existing standard repositories and converts them to a Worktree structure upon request.
- **Agent Dispatch**: Launches specific AI CLI tools in their own isolated worktrees.
- **WSL Optimized**: Built with Windows Subsystem for Linux in mind.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the detailed development plan.

## Installation (Coming Soon)

```bash
curl -fsSL https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/install.sh | bash
```
