# ContextViewer for Claude Code

Real-time token usage visualization for Claude Code.

```
Sonnet 4 $14.91 1M↑ 626k↓
▁▁▁▁▁▁▁▁▁▁▁▁▃▁▄▂█▂▁▃▁▅▂▁▇▁▆▂▁▄▃▁▁▁▁▁▁▁▁▄ 12k↑ ▁▁▁▁▁▁▁▁▁▁▁▁▃▁▄▂█▂▁▃▁▅▂▁▇▁▆▂▁▄▃▁▁▁▁▁▁▁▁▃ 5k↓
██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 6% 12k/200k
```

## Features

- **Block bar visualization** of input/output token history (▁▂▃▄▅▆▇█)
- **Responsive width** - adapts to terminal size
- **Session cost tracking** with running totals
- **Context window bar** with color gradient (green → yellow → red)
- **`/cmap` command** for comprehensive 24h/7d/30d statistics
- **SQLite database** for persistent history across sessions

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextViewer/main/install.sh | bash
```

This installs:
- `~/.config/context-viewer/statusline.sh` - Statusline script
- `~/.config/context-viewer/cmap.sh` - Statistics script
- `~/.claude/commands/cmap.md` - `/cmap` slash command

## Manual Install

```bash
# Create directories
mkdir -p ~/.config/context-viewer
mkdir -p ~/.claude/commands

# Download scripts
curl -o ~/.config/context-viewer/statusline.sh \
  https://raw.githubusercontent.com/KBLCode/ContextViewer/main/statusline.sh
curl -o ~/.config/context-viewer/cmap.sh \
  https://raw.githubusercontent.com/KBLCode/ContextViewer/main/cmap.sh
curl -o ~/.claude/commands/cmap.md \
  https://raw.githubusercontent.com/KBLCode/ContextViewer/main/cmap.md

# Make executable
chmod +x ~/.config/context-viewer/*.sh
```

## Usage

### `/cmap` Command

Type `/cmap` in Claude Code to view comprehensive token statistics:

```
                             CONTEXT MAP
──────────────────────────────────────────────────────────────────────

Period         Msgs      Input     Output       Cost
────────── ──────── ────────── ────────── ──────────
24 hours        167       1.8M       626k     $14.91
7 days          167       1.8M       626k     $14.91
30 days         167       1.8M       626k     $14.91
All time        167       1.8M       626k     $14.91

24h Activity
0     3     6     9    12    15    18    21   23
▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ IN
▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ OUT

7-Day Trend
Fri Sat Sun Mon Tue Wed Thu
▁▁▁ ▁▁▁ ▁▁▁ ▁▁▁ ▁▁▁ ███ ▁▁▁ IN
▁▁▁ ▁▁▁ ▁▁▁ ▁▁▁ ▁▁▁ ███ ▁▁▁ OUT
```

### Statusline

The statusline displays automatically:
- **Line 1**: Model name, session cost, total IN/OUT tokens
- **Line 2**: IN history (cyan) + current, OUT history (magenta) + current
- **Line 3**: Context window bar + percentage + used/max

## How It Works

- **Block bars** (▁▂▃▄▅▆▇█): Height = token count relative to max
- **Colors**: Cyan = input, Magenta = output, Green→Yellow→Red = context
- **History**: Last 50 messages in `~/.config/context-viewer/history.txt`
- **Database**: SQLite at `~/.config/context-viewer/tokens.db`

## Requirements

- `jq` - JSON parsing
- `sqlite3` - Database storage  
- `bc` - Cost calculations
- Bash 4+

## Files

```
~/.config/context-viewer/
├── statusline.sh    # Statusline script
├── cmap.sh          # Statistics script
├── history.txt      # Recent IN/OUT (last 50)
└── tokens.db        # SQLite database

~/.claude/commands/
└── cmap.md          # /cmap slash command
```

## Uninstall

```bash
rm -rf ~/.config/context-viewer
rm ~/.claude/commands/cmap.md
```

## License

MIT
