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

# 1. Check Dependencies
echo "Checking dependencies..."
deps=("git" "curl" "unzip" "tar" "jq" "fzf") # Added fzf as it's used in bin/mawt

for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "Error: '$dep' is required but not installed."
        
        OS="$(uname -s)"
        if [ "$OS" = "Darwin" ]; then
            echo "Try running: brew install $dep"
        elif [ -f /etc/debian_version ]; then
            echo "Try running: sudo apt-get install $dep"
        elif [ -f /etc/redhat-release ]; then
            echo "Try running: sudo dnf install $dep"
        fi
        
        exit 1
    fi
done

# 2. Create Installation Directory
mkdir -p "$BIN_DIR"

# 3. Download/Update MAWT via Git Clone (More Robust than curl raw)
echo "Fetching latest version..."
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
    # Fallback to curl if git fails (e.g. firewall blocking git protocol but not https)
    MAWT_SCRIPT_URL="https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/bin/mawt"
    if ! curl -fsSL -4 --retry 3 --retry-delay 2 "$MAWT_SCRIPT_URL" -o "$BIN_DIR/mawt"; then
        echo "Error: Failed to download mawt CLI."
        exit 1
    fi
    chmod +x "$BIN_DIR/mawt"
fi

# 4. Add to PATH
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

# 5. Configure Workspace & Preferences
echo ""
echo "--- Configuration ---"

# Load existing config to check for missing values
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Flag to determine if we need to save/update config
UPDATE_CONFIG=false

# 5.1 Workspace
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

# 5.2 Git Protocol
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

# 5.3 GitLab Base URL (For Private GitLab)
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
    # Remove trailing slash
    GITLAB_BASE_URL=${GITLAB_BASE_URL%/}
    UPDATE_CONFIG=true
fi

# 5.4 GitLab Token (Optional but recommended for API access)
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

# Save Configuration only if needed or forced
if [ "$UPDATE_CONFIG" = true ]; then
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE" # Secure permissions

    {
        echo "WORKSPACE_DIR=\"$WORKSPACE_DIR\""
        echo "GIT_PROTOCOL=\"$GIT_PROTOCOL\""
        echo "GITLAB_BASE_URL=\"$GITLAB_BASE_URL\""
        echo "GITLAB_TOKEN=\"$GITLAB_TOKEN\""
    } > "$CONFIG_FILE"

    echo "Configuration updated securely in $CONFIG_FILE (chmod 600)."
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