#!/bin/bash
set -e

# Multi-Agent Worktree (MAWT) Installer

REPO_URL="https://github.com/rootsong0220/multi-agent-worktree"
INSTALL_DIR="$HOME/.mawt"
BIN_DIR="$INSTALL_DIR/bin"
MAWT_SCRIPT_URL="https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/bin/mawt"
CONFIG_FILE="$INSTALL_DIR/config"

if [ -f "$BIN_DIR/mawt" ]; then
    echo "Updating Multi-Agent Worktree Manager (MAWT)..."
else
    echo "Installing Multi-Agent Worktree Manager (MAWT)..."
fi

# 1. Check Dependencies
echo "Checking dependencies..."
deps=("git" "curl" "unzip" "tar" "jq")
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "Error: '$dep' is not installed. Please install it and try again."
        exit 1
    fi
done

# 2. Create Installation Directory
mkdir -p "$BIN_DIR"

# 3. Download MAWT Script
echo "Downloading mawt CLI..."
# For now, we are simulating the download from the repo we are building.
# In a real scenario, we would download from the raw URL of the main branch.
# Since we are developing locally, we will just copy if the file exists locally, otherwise curl with retry.
if [ -f "bin/mawt" ]; then
    cp bin/mawt "$BIN_DIR/mawt"
else
    # Retry logic: 3 attempts with 2-second delay
    if ! curl -fsSL --retry 3 --retry-delay 2 "$MAWT_SCRIPT_URL" -o "$BIN_DIR/mawt"; then
        echo "Error: Failed to download mawt CLI from GitHub."
        echo "Please check your internet connection or try again later."
        exit 1
    fi
fi

chmod +x "$BIN_DIR/mawt"

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
if [ -f "$CONFIG_FILE" ]; then
    echo "Configuration already exists at $CONFIG_FILE. Skipping setup."
else
    echo ""
    echo "--- Configuration ---"

    # 5.1 Workspace
    read -p "Enter directory to use as workspace (default: $HOME/workspace): " USER_WS
    USER_WS=${USER_WS:-"$HOME/workspace"}
    USER_WS="${USER_WS/#\~/$HOME}" # Expand tilde
    echo "Using workspace: $USER_WS"
    mkdir -p "$USER_WS"

    # 5.2 Git Protocol
    echo ""
    echo "Select default Git protocol for cloning repositories:"
    echo "1) SSH (git@gitlab.com:...)"
    echo "2) HTTPS (https://gitlab.com/...)"
    read -p "Enter choice [1/2] (default: 1): " PROTO_CHOICE
    if [ "$PROTO_CHOICE" == "2" ]; then
        GIT_PROTOCOL="https"
    else
        GIT_PROTOCOL="ssh"
    fi
    echo "Selected protocol: $GIT_PROTOCOL"

    # 5.3 GitLab Base URL (For Private GitLab)
    echo ""
    echo "Enter GitLab Base URL (e.g., http://gitlab.company.com)."
    echo "Press Enter to use default (https://gitlab.com)."
    read -p "Base URL: " GITLAB_BASE_URL
    if [ -z "$GITLAB_BASE_URL" ]; then
        GITLAB_BASE_URL="https://gitlab.com"
    fi
    # Remove trailing slash
    GITLAB_BASE_URL=${GITLAB_BASE_URL%/}

    # 5.4 GitLab Token (Optional but recommended for API access)
    echo ""
    echo "Enter GitLab Personal Access Token."
    echo "Required for fetching repository lists from Private GitLab."
    read -s -p "Token (input will be hidden): " GITLAB_TOKEN
    echo ""

    # Save Configuration
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE" # Secure permissions

    {
        echo "WORKSPACE_DIR=\"$USER_WS\""
        echo "GIT_PROTOCOL=\"$GIT_PROTOCOL\""
        echo "GITLAB_BASE_URL=\"$GITLAB_BASE_URL\""
        echo "GITLAB_TOKEN=\"$GITLAB_TOKEN\""
    } > "$CONFIG_FILE"

    echo "Configuration saved securely to $CONFIG_FILE (chmod 600)."
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