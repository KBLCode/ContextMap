# ContextViewer for Claude Code

Real-time token usage visualization with beautiful Unicode charts.

## What You Get

### Statusline (Always Visible)
<img width="1250" height="104" alt="CleanShot 2026-01-15 at 05 11 04@2x" src="https://github.com/user-attachments/assets/d863dd33-3597-4363-b9f5-2b45498aa30f" />
<img width="800" height="132" alt="CleanShot 2026-01-15 at 05 11 28@2x" src="https://github.com/user-attachments/assets/bcf39019-b6e2-4c04-81db-0876ce52dfe9" />



### `/cmap` Command (Full Analytics)
```
  ╔═══════════════════════════════════════════════════════════════════╗
  ║                        ◆ CONTEXT MAP ◆                            ║
  ╚═══════════════════════════════════════════════════════════════════╝

  TODAY  │  97 msgs  │  ▲ 3.8M  │  ▼ 590k  │  ◆ $20.30

  ┌─────────────┬────────┬────────────┬────────────┬──────────────┐
  │ Period      │  Msgs  │   Input    │   Output   │     Cost     │
  ├─────────────┼────────┼────────────┼────────────┼──────────────┤
  │ 1 hour      │     12 │        45k │        12k │        $0.31 │
  │ 6 hours     │     34 │       890k │       156k │        $5.01 │
  │ 24 hours    │     97 │       3.8M │       590k │       $20.30 │
  │ 7 days      │    456 │      18.2M │       2.8M │       $96.60 │
  │ 30 days     │   1823 │      72.4M │      11.2M │      $385.20 │
  ├─────────────┼────────┼────────────┼────────────┼──────────────┤
  │ ALL TIME    │   2156 │      89.1M │      14.6M │      $486.30 │
  └─────────────┴────────┴────────────┴────────────┴──────────────┘

  ┌─ 24 HOURS ───────────────────────────────────────────────────────┐
  │ 15-minute intervals
  │ ⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 797k
  │ ⠀⠀⡄⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  │ ⠀⠀⡇⠀⠀⢰⣷⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  │ ⠀⢀⣇⡄⠀⣼⣿⠀⠀⠀⠀⠀⡄⠀⣧⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  │ ⠀⢸⣿⡇⠀⣿⣿⡇⡆⠀⠀⠀⡇⠀⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⠀⠀
  └────────────────────────────────────────────────
  │ ◀─── 24 hours ago ───────────────────────────────── now ───▶
  └─────────────────────────────────────────────────────────────────┘
```

## Features

- **Braille dot charts** (⠀⡀⣀⣿) - High-resolution visualization with 2x4 dot matrix per character
- **Block bar sparklines** (▁▂▃▄▅▆▇█) - Token history in the statusline
- **Color-coded display** - Cyan=input, Magenta=output, Green→Yellow→Red=context
- **Multiple time ranges** - 1h, 6h, 24h, 7d, 30d, all-time
- **Session tracking** - Costs and duration per session
- **Model breakdown** - Usage by model
- **SQLite storage** - Persistent history across sessions

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextViewer/main/install.sh | bash
```

## Manual Install

```bash
# Create directories
mkdir -p ~/.config/context-viewer ~/.claude/commands

# Download scripts
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextViewer/main/statusline.sh \
  -o ~/.config/context-viewer/statusline.sh
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextViewer/main/cmap.sh \
  -o ~/.config/context-viewer/cmap.sh
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextViewer/main/cmap.md \
  -o ~/.claude/commands/cmap.md

# Make executable
chmod +x ~/.config/context-viewer/*.sh

# Configure Claude Code (add to ~/.claude/settings.json)
cat >> ~/.claude/settings.json << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.config/context-viewer/statusline.sh"
  }
}
EOF
```

## Usage

| Command | Description |
|---------|-------------|
| (automatic) | Statusline shows in Claude Code footer |
| `/cmap` | Full analytics dashboard with charts |

## How It Works

**Statusline** (3 lines):
1. Model name, session cost, total IN/OUT
2. IN history sparkline + current, OUT history sparkline + current  
3. Context window bar with percentage

**Charts** use Unicode braille (U+2800-U+28FF):
- Each character = 2 columns × 4 rows = 8 dots
- Bars fill from bottom up for proper visualization
- Different colors for different time ranges

**Pricing**: $3/M input, $15/M output (Claude Sonnet 4)

## Files

```
~/.config/context-viewer/
├── statusline.sh    # Statusline script
├── cmap.sh          # Analytics dashboard
├── history.txt      # Recent IN/OUT (last 50)
└── tokens.db        # SQLite database

~/.claude/commands/
└── cmap.md          # /cmap slash command
```

## Requirements

- `jq` - JSON parsing
- `sqlite3` - Database storage  
- `bc` - Cost calculations
- Bash 4+
- Terminal with Unicode support

## Uninstall

```bash
rm -rf ~/.config/context-viewer
rm ~/.claude/commands/cmap.md
```

## License

MIT
