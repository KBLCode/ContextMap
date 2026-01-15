#!/bin/bash
# ContextViewer Installer for Claude Code

set -e

REPO="https://raw.githubusercontent.com/cianoc/ContextViewer/main"
DEST="$HOME/.config/context-viewer"

echo "Installing ContextViewer for Claude Code..."

# Create directory
mkdir -p "$DEST"

# Download scripts
echo "Downloading statusline.sh..."
curl -fsSL "$REPO/statusline.sh" -o "$DEST/statusline.sh"

echo "Downloading cmap.sh..."
curl -fsSL "$REPO/cmap.sh" -o "$DEST/cmap.sh"

# Make executable
chmod +x "$DEST/statusline.sh"
chmod +x "$DEST/cmap.sh"

echo ""
echo "Installation complete!"
echo ""
echo "Files installed to: $DEST"
echo ""
echo "To configure Claude Code, add to your settings:"
echo ""
echo '  "statusline": {'
echo '    "command": "~/.config/context-viewer/statusline.sh"'
echo '  }'
echo ""
echo "Use /cmap in Claude Code to view token statistics."
echo ""
