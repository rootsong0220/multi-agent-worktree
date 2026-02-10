#!/bin/bash
set -e

# Multi-Agent Worktree (MAWT) Installer

REPO_URL="https://github.com/rootsong0220/multi-agent-worktree.git"
INSTALL_DIR="$HOME/.mawt"
BIN_DIR="$INSTALL_DIR/bin"
CONFIG_FILE="$INSTALL_DIR/config"

if [ -f "$BIN_DIR/mawt" ]; then
    echo "Updating Multi-Agent Worktree Manager (MAWT)..."
else
    echo "Installing Multi-Agent Worktree Manager (MAWT)..."
fi

# Detect OS
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Linux*)     OS_NAME="linux";;
    Darwin*)    OS_NAME="macos";;
    CYGWIN*)    OS_NAME="cygwin";;
    MINGW*)     OS_NAME="mingw";;
    *)          OS_NAME="unknown";;
esac

echo "Detected OS: $OS_NAME"

# Function to install system packages
install_sys_pkg() {
    local pkg="$1"
    
    # Check if user wants to install
    echo "Required package '$pkg' is missing."
    read -p "Do you want to attempt installation? (y/N) " confirm < /dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Skipping installation of '$pkg'. MAWT might not function correctly."
        return 1
    fi

    if [ "$OS_NAME" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew install "$pkg"
        else
            echo "Error: Homebrew not found. Please install '$pkg' manually."
            return 1
        fi
    elif [ "$OS_NAME" = "linux" ]; then
        if [ -f /etc/debian_version ]; then
            sudo apt-get update && sudo apt-get install -y "$pkg"
        elif [ -f /etc/redhat-release ]; then
            sudo dnf install -y "$pkg" || sudo yum install -y "$pkg"
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S --noconfirm "$pkg"
        else
            echo "Unknown Linux distribution. Please install '$pkg' manually."
            return 1
        fi
    else
        echo "Cannot automatically install on $OS_NAME. Please install '$pkg' manually."
        return 1
    fi
}

# 1. Check System Dependencies
echo "Checking system dependencies..."
# Added 'npm' to dependencies list as AI CLIs are npm packages
deps=("git" "curl" "unzip" "tar" "jq" "fzf" "npm")

for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        # Special handling for npm -> usually installed via nodejs
        if [ "$dep" == "npm" ]; then
             echo "npm is required for installing AI CLIs."
             install_sys_pkg "nodejs" || install_sys_pkg "npm" || {
                echo "Warning: failed to install npm/nodejs. AI CLI auto-installation will be skipped."
             }
        else
             install_sys_pkg "$dep" || {
                 echo "Error: Failed to satisfy dependency '$dep'. Exiting."
                 exit 1
             }
        fi
    else
        echo " - $dep: Found"
    fi
done

# Function to check and install AI CLI tools via NPM
check_ai_cli() {
    local tool_cmd="$1"
    local npm_pkg="$2"

    if ! command -v "$tool_cmd" &> /dev/null; then
        echo "AI CLI '$tool_cmd' is not installed."
        
        if ! command -v npm &> /dev/null; then
            echo "npm not found. Cannot install '$tool_cmd'."
            return
        fi

        read -p "Install '$tool_cmd' via npm? (y/N) " confirm < /dev/tty
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo "Installing '$npm_pkg'..."
            # Try installing globally without sudo first, then with sudo if permission denied
            if npm install -g "$npm_pkg"; then
                echo "'$tool_cmd' installed successfully."
            else
                echo "Permission denied or failed. Trying with sudo..."
                if sudo npm install -g "$npm_pkg"; then
                     echo "'$tool_cmd' installed successfully with sudo."
                else
                     echo "Failed to install '$tool_cmd'. Please run: npm install -g $npm_pkg"
                fi
            fi
        else
            echo "Skipping '$tool_cmd'. You can install it later: npm install -g $npm_pkg"
        fi
    else
        echo " - AI CLI '$tool_cmd': Found"
    fi
}

# 2. Check AI CLI Tools
echo ""
echo "Checking AI Agent CLIs..."

# Gemini CLI
check_ai_cli "gemini" "@google/gemini-cli"

# Claude Code
check_ai_cli "claude" "@anthropic-ai/claude-code"

# Codex CLI
check_ai_cli "codex" "@openai/codex"


# 3. Create Installation Directory
mkdir -p "$BIN_DIR"

# 4. Download/Update MAWT via Git Clone
echo ""
echo "Fetching latest version of MAWT..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

if git clone --depth 1 "$REPO_URL" "$TEMP_DIR" >/dev/null 2>&1; then
    echo "Repository cloned successfully."
    # Install binary
    cp "$TEMP_DIR/bin/mawt" "$BIN_DIR/mawt"
    chmod +x "$BIN_DIR/mawt"
    echo "Updated $BIN_DIR/mawt"
else
    echo "Error: Failed to clone repository."
    echo "Trying fallback to curl..."
    MAWT_SCRIPT_URL="https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/bin/mawt"
    if ! curl -fsSL -4 --retry 3 --retry-delay 2 "$MAWT_SCRIPT_URL" -o "$BIN_DIR/mawt"; then
        echo "Error: Failed to download mawt CLI."
        exit 1
    fi
    chmod +x "$BIN_DIR/mawt"
fi

# 5. Add to PATH
SHELL_CONFIG=""
case "$SHELL" in
    */zsh) SHELL_CONFIG="$HOME/.zshrc" ;;
    */bash) SHELL_CONFIG="$HOME/.bashrc" ;;
    *) echo "Warning: Unknown shell. Please manually add $BIN_DIR to your PATH." ;;
esac

if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -q "$BIN_DIR" "$SHELL_CONFIG"; then
        echo "Adding $BIN_DIR to $SHELL_CONFIG..."
        echo "" >> "$SHELL_CONFIG"
        echo "# MAWT CLI" >> "$SHELL_CONFIG"
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_CONFIG"
        echo "Please restart your shell or run 'source $SHELL_CONFIG' to use 'mawt'."
    else
        echo "$BIN_DIR is already in $SHELL_CONFIG."
    fi
fi

# 6. Configure Workspace & Preferences
echo ""
echo "--- Configuration ---"

# Load existing config to check for missing values
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

UPDATE_CONFIG=false

# 6.1 Workspace
if [ -z "$WORKSPACE_DIR" ]; then
    read -p "Enter directory to use as workspace (default: $HOME/workspace): " USER_WS < /dev/tty
    USER_WS=${USER_WS:-"$HOME/workspace"}
    USER_WS="${USER_WS/#\~/$HOME}" # Expand tilde
    echo "Using workspace: $USER_WS"
    mkdir -p "$USER_WS"
    WORKSPACE_DIR="$USER_WS"
    UPDATE_CONFIG=true
else
    echo "Using existing workspace: $WORKSPACE_DIR"
fi

# 6.2 Git Protocol
if [ -z "$GIT_PROTOCOL" ]; then
    echo ""
    echo "Select default Git protocol for cloning repositories:"
    echo "1) SSH (git@gitlab.com:...)"
    echo "2) HTTPS (https://gitlab.com/...)"
    read -p "Enter choice [1/2] (default: 1): " PROTO_CHOICE < /dev/tty
    if [ "$PROTO_CHOICE" == "2" ]; then
        GIT_PROTOCOL="https"
    else
        GIT_PROTOCOL="ssh"
    fi
    echo "Selected protocol: $GIT_PROTOCOL"
    UPDATE_CONFIG=true
fi

# 6.3 GitLab Base URL
if [ -z "$GITLAB_BASE_URL" ]; then
    echo ""
    echo "Enter GitLab Base URL (e.g., http://gitlab.company.com)."
    echo "Press Enter to use default (https://gitlab.com)."
    read -p "Base URL: " INPUT_BASE_URL < /dev/tty
    if [ -z "$INPUT_BASE_URL" ]; then
        GITLAB_BASE_URL="https://gitlab.com"
    else
        GITLAB_BASE_URL="$INPUT_BASE_URL"
    fi
    GITLAB_BASE_URL=${GITLAB_BASE_URL%/}
    UPDATE_CONFIG=true
fi

# 6.4 GitLab Token
if [ -z "$GITLAB_TOKEN" ]; then
    echo ""
    echo "Enter GitLab Personal Access Token."
    echo "Required for fetching repository lists from Private GitLab."
    read -s -p "Token (input will be hidden): " GITLAB_TOKEN < /dev/tty
    echo ""
    if [ -n "$GITLAB_TOKEN" ]; then
        UPDATE_CONFIG=true
    fi
fi

if [ "$UPDATE_CONFIG" = true ]; then
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    {
        echo "WORKSPACE_DIR=\"$WORKSPACE_DIR\""
        echo "GIT_PROTOCOL=\"$GIT_PROTOCOL\""
        echo "GITLAB_BASE_URL=\"$GITLAB_BASE_URL\""
        echo "GITLAB_TOKEN=\"$GITLAB_TOKEN\""
    } > "$CONFIG_FILE"
    echo "Configuration updated."
else
    echo "Configuration is up to date."
fi

echo ""
echo "============================================================"
echo "  Installation/Update complete!"
echo "============================================================"
echo ""
echo "To use 'mawt' immediately in this current session, please run:"
echo ""
echo "    source $SHELL_CONFIG"
echo ""
echo "Alternatively, restart your terminal."
echo "============================================================"