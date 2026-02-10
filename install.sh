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

# 5. Configure Workspace
echo ""
echo "--- Workspace Configuration ---"
read -p "Enter directory to use as workspace (default: $HOME/workspace): " USER_WS
USER_WS=${USER_WS:-"$HOME/workspace"}

# Expand tilde if present
USER_WS="${USER_WS/#\~/$HOME}"

echo "Using workspace: $USER_WS"
mkdir -p "$USER_WS"

CONFIG_FILE="$INSTALL_DIR/config"
echo "WORKSPACE_DIR=\"$USER_WS\"" > "$CONFIG_FILE"
echo "Configuration saved to $CONFIG_FILE."

