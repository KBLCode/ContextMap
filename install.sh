#!/bin/bash
# ContextMap Installer for Claude Code

set -e

REPO="https://raw.githubusercontent.com/KBLCode/ContextMap/main"
CONFIG_DIR="$HOME/.config/contextmap"
COMMANDS_DIR="$HOME/.claude/commands"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║            ContextMap for Claude Code                  ║"
echo "║            Token Usage Visualization                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Create directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$COMMANDS_DIR"
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Download scripts
echo "→ Downloading statusline.sh..."
curl -fsSL "$REPO/statusline.sh" -o "$CONFIG_DIR/statusline.sh"

echo "→ Downloading cmap.sh..."
curl -fsSL "$REPO/cmap.sh" -o "$CONFIG_DIR/cmap.sh"

echo "→ Downloading /cmap command..."
curl -fsSL "$REPO/cmap.md" -o "$COMMANDS_DIR/cmap.md"

# Make executable
chmod +x "$CONFIG_DIR/statusline.sh"
chmod +x "$CONFIG_DIR/cmap.sh"

# Configure Claude settings
echo "→ Configuring Claude Code settings..."

if [ -f "$SETTINGS_FILE" ]; then
    # Check if statusLine already configured
    if grep -q "statusLine" "$SETTINGS_FILE" 2>/dev/null; then
        echo "  (statusLine already configured, skipping)"
    else
        # Add statusLine to existing settings
        # Remove trailing } and add statusLine config
        tmp=$(mktemp)
        sed '$ d' "$SETTINGS_FILE" > "$tmp"
        if [ -s "$tmp" ]; then
            # Check if file has content (not just {})
            if grep -q ":" "$tmp"; then
                echo "," >> "$tmp"
            fi
        fi
        cat >> "$tmp" << 'EOF'
  "statusLine": {
    "type": "command",
    "command": "~/.config/contextmap/statusline.sh"
  }
}
EOF
        mv "$tmp" "$SETTINGS_FILE"
        echo "  ✓ Added statusLine configuration"
    fi
else
    # Create new settings file
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.config/contextmap/statusline.sh"
  }
}
EOF
    echo "  ✓ Created settings.json with statusLine"
fi

# Import historical data
echo ""
echo "→ Importing historical chat data..."
"$CONFIG_DIR/cmap.sh" --init

echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "  ✓ Installation complete!"
echo ""
echo "  Files installed:"
echo "    • $CONFIG_DIR/statusline.sh"
echo "    • $CONFIG_DIR/cmap.sh"  
echo "    • $COMMANDS_DIR/cmap.md"
echo "    • $SETTINGS_FILE (configured)"
echo ""
echo "  Usage:"
echo "    • Statusline appears automatically in Claude Code"
echo "    • Type /cmap to view detailed token statistics"
echo "    • Type /cmap -c to see chat history with costs"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""
