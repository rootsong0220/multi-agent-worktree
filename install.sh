#!/bin/bash
set -e

# Multi-Agent Worktree (MAWT) Installer

REPO_URL="https://github.com/rootsong0220/multi-agent-worktree"
INSTALL_DIR="$HOME/.mawt"
BIN_DIR="$INSTALL_DIR/bin"
MAWT_SCRIPT_URL="https://raw.githubusercontent.com/rootsong0220/multi-agent-worktree/main/bin/mawt"

echo "Installing Multi-Agent Worktree Manager (MAWT)..."

# 1. Check Dependencies
echo "Checking dependencies..."
deps=("git" "curl" "unzip" "tar")
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "Error: '$dep' is not installed. Please install it and try again."
        exit 1
    fi
done

# 2. Create Installation Directory
echo "Creating installation directory at $INSTALL_DIR..."
mkdir -p "$BIN_DIR"

# 3. Download MAWT Script
echo "Downloading mawt CLI..."
# For now, we are simulating the download from the repo we are building.
# In a real scenario, we would download from the raw URL of the main branch.
# Since we are developing locally, we will just copy if the file exists locally, otherwise curl.
if [ -f "bin/mawt" ]; then
    cp bin/mawt "$BIN_DIR/mawt"
else
    curl -fsSL "$MAWT_SCRIPT_URL" -o "$BIN_DIR/mawt"
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
        echo "export PATH="\$PATH:$BIN_DIR"" >> "$SHELL_CONFIG"
        echo "Please restart your shell or run 'source $SHELL_CONFIG' to use 'mawt'."
    else
        echo "$BIN_DIR is already in $SHELL_CONFIG."
    fi
fi

echo "Installation complete! Try running 'mawt --help'."

# 5. Configure Workspace & Preferences
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

# 5.3 GitLab Token (Optional)
echo ""
echo "Enter GitLab Personal Access Token (Optional)."
echo "This can be used by agents or for HTTPS authentication helper."
echo "If strictly using SSH, you can skip this."
read -s -p "Token (input will be hidden): " GITLAB_TOKEN
echo ""

# Save Configuration
CONFIG_FILE="$INSTALL_DIR/config"
touch "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE" # Secure permissions

{
    echo "WORKSPACE_DIR=\"$USER_WS\""
    echo "GIT_PROTOCOL=\"$GIT_PROTOCOL\""
    echo "GITLAB_TOKEN=\"$GITLAB_TOKEN\""
} > "$CONFIG_FILE"

echo "Configuration saved securely to $CONFIG_FILE (chmod 600)."

