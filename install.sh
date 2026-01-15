#!/bin/bash
# ContextViewer Installer for Claude Code

set -e

REPO="https://raw.githubusercontent.com/KBLCode/ContextViewer/main"
CONFIG_DIR="$HOME/.config/context-viewer"
COMMANDS_DIR="$HOME/.claude/commands"

echo "Installing ContextViewer for Claude Code..."
echo ""

# Create directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$COMMANDS_DIR"

# Download scripts
echo "Downloading statusline.sh..."
curl -fsSL "$REPO/statusline.sh" -o "$CONFIG_DIR/statusline.sh"

echo "Downloading cmap.sh..."
curl -fsSL "$REPO/cmap.sh" -o "$CONFIG_DIR/cmap.sh"

echo "Downloading /cmap command..."
curl -fsSL "$REPO/cmap.md" -o "$COMMANDS_DIR/cmap.md"

# Make executable
chmod +x "$CONFIG_DIR/statusline.sh"
chmod +x "$CONFIG_DIR/cmap.sh"

echo ""
echo "============================================"
echo "  Installation complete!"
echo "============================================"
echo ""
echo "Files installed:"
echo "  $CONFIG_DIR/statusline.sh"
echo "  $CONFIG_DIR/cmap.sh"
echo "  $COMMANDS_DIR/cmap.md"
echo ""
echo "Usage:"
echo "  /cmap  - View token usage statistics"
echo ""
echo "The statusline will activate automatically."
echo ""
