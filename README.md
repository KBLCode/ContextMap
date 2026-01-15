# ContextViewer for Claude Code

Real-time token usage visualization for Claude Code's statusline.

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
curl -fsSL https://raw.githubusercontent.com/cianoc/ContextViewer/main/install.sh | bash
```

Or manually:

```bash
# Create config directory
mkdir -p ~/.config/context-viewer

# Download scripts
curl -o ~/.config/context-viewer/statusline.sh \
  https://raw.githubusercontent.com/cianoc/ContextViewer/main/statusline.sh
curl -o ~/.config/context-viewer/cmap.sh \
  https://raw.githubusercontent.com/cianoc/ContextViewer/main/cmap.sh

# Make executable
chmod +x ~/.config/context-viewer/*.sh
```

## Configuration

Add to your Claude Code settings (`.claude/settings.json`):

```json
{
  "statusline": {
    "command": "~/.config/context-viewer/statusline.sh"
  }
}
```

## Usage

### Statusline
The statusline displays automatically, showing:
- **Line 1**: Model name, session cost, total IN/OUT tokens
- **Line 2**: IN token history (cyan blocks) + current IN, OUT history (magenta) + current OUT  
- **Line 3**: Context window usage bar + percentage + used/max

### `/cmap` Command
View comprehensive token statistics:

```
/cmap
```

Shows:
- 24h, 7d, 30d, all-time summaries
- Hourly activity chart (24h)
- Daily trend chart (7 days)
- Model breakdown with usage bars
- Recent sessions with usage bars

## How It Works

- **Block bars** (▁▂▃▄▅▆▇█): Height represents token count relative to max
- **Colors**: Cyan for input, Magenta for output, Green→Yellow→Red for context
- **History**: Last 50 messages stored in `~/.config/context-viewer/history.txt`
- **Database**: SQLite at `~/.config/context-viewer/tokens.db` for `/cmap` stats

## Requirements

- `jq` - JSON parsing
- `sqlite3` - Database storage
- `bc` - Cost calculations
- Bash 4+

## Files

```
~/.config/context-viewer/
├── statusline.sh    # Main statusline script
├── cmap.sh          # /cmap command script
├── history.txt      # Recent IN/OUT values (last 50)
└── tokens.db        # SQLite database for stats
```

## Uninstall

```bash
rm -rf ~/.config/context-viewer
```

## License

MIT
