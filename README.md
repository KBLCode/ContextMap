# ContextMap for Claude Code

Real-time token usage visualization with beautiful Unicode charts.

## What You Get

### Statusline (Always Visible)
A compact 3-line display showing:
- Model name, session cost, total IN/OUT tokens
- Input/output sparkline history with current values
- Context window usage bar with percentage

### `/cmap` Command (Full Analytics)
```
╔══════════════════════════════════════════════════════════════════════════════════════╗
║                              ◆ CONTEXT MAP ◆                                         ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║ TODAY  12 msgs ▲  45k ▼  12k $0.31                                                   ║
╟──────────────────────────────────────────────────────────────────────────────────────╢
║ Period    │ Msgs │   In   │  Out   │    Cost                                         ║
╟──────────────────────────────────────────────────────────────────────────────────────╢
║ 1 hour    │   12 │    45k │    12k │    $0.31                                        ║
║ 6 hours   │   34 │   890k │   156k │    $5.01                                        ║
║ 24 hours  │   97 │   3.8M │   590k │   $20.30                                        ║
║ 7 days    │  456 │  18.2M │   2.8M │   $96.60                                        ║
║ 30 days   │ 1823 │  72.4M │  11.2M │  $385.20                                        ║
╟──────────────────────────────────────────────────────────────────────────────────────╢
║ ALL TIME  │ 2156 │  89.1M │  14.6M │  $486.30                                        ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║ 1 HOUR (2-min)                            ▌in ▐out                                   ║
║ ⡀⡀⣀⣀⣄⣄⣤⣤⣦⣦⣶⣶⣷⣷⣿⣿⣿⣿⣷⣷⣶⣶⣦⣦⣤⣤⣄⣄⣀⣀ 45k                                   ║
║ ◀─ 60m ago ─────────────────────────────── now ─▶                                    ║
╚══════════════════════════════════════════════════════════════════════════════════════╝
```

### `/cmap -c` Chat History
```
╔══════════════════════════════════════════════════════════════════════════════════════╗
║                              ◆ CHAT HISTORY ◆                                        ║
║                            29 chats tracked                                          ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║ Session  │ Model  │ Title                          │ In     │ Out    │ Cache   │ Cost║
╟──────────────────────────────────────────────────────────────────────────────────────╢
║ 20260115 │ sonnet │ ContextMap Analytics...        │    91k │   120k │   7.2M  │ $2.30║
║ 79ec9c50 │ sonnet │ Token Usage Dashboard          │    45k │    89k │   3.1M  │ $1.45║
╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Features

- **Accurate cost calculation** with all 4 token types:
  - `input_tokens` - Fresh input (full price)
  - `cache_creation_input_tokens` - Cache write (1.25x price)
  - `cache_read_input_tokens` - Cache read (90% cheaper!)
  - `output_tokens` - Model output
- **Per-model pricing** - Opus ($15/$75), Sonnet ($3/$15), Haiku ($0.80/$4)
- **Braille dot charts** - High-resolution visualization (2x4 dots per character)
- **Block bar sparklines** - Token history in the statusline
- **Color-coded display** - Cyan=input, Magenta=output, Green/Yellow/Red=context
- **Multiple time ranges** - 1h, 6h, 24h, 7d, 30d, all-time
- **Session tracking** - Costs and duration per session
- **SQLite storage** - Persistent history across sessions

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextMap/main/install.sh | bash
```

This will:
1. Download scripts to `~/.config/contextmap/`
2. Install the `/cmap` slash command
3. Configure Claude Code's statusline for real-time tracking
4. Import all your historical chat data

## Manual Install

```bash
# Create directories
mkdir -p ~/.config/contextmap ~/.claude/commands

# Download scripts
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextMap/main/statusline.sh \
  -o ~/.config/contextmap/statusline.sh
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextMap/main/cmap.sh \
  -o ~/.config/contextmap/cmap.sh
curl -fsSL https://raw.githubusercontent.com/KBLCode/ContextMap/main/cmap.md \
  -o ~/.claude/commands/cmap.md

# Make executable
chmod +x ~/.config/contextmap/*.sh

# Import historical data
~/.config/contextmap/cmap.sh --init
```

## Statusline Setup (Real-Time Tracking)

The statusline enables **real-time token tracking** on every Claude response. Without it, you can still use `/cmap --init` to import historical data, but you won't get live per-message tracking.

### Enable the Statusline

Add this to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.config/contextmap/statusline.sh"
  }
}
```

Or if you already have settings, add the `statusLine` key:

```json
{
  "existingKey": "existingValue",
  "statusLine": {
    "type": "command",
    "command": "~/.config/contextmap/statusline.sh"
  }
}
```

### What the Statusline Does

When enabled, Claude Code calls the statusline script after every response. The script:

1. **Displays live stats** in the Claude Code footer:
   ```
   Claude Sonnet 4 $0.79 51k↑ 42k↓
   ▁▁▁▅▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁1k↑ ▁▁▁▄▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▃▃▃▃▁▁▃▃▁▁800↓
   ████████████░░░░░░░░░░░░░░░░░░ 30% 61k/200k
   ```

2. **Records to database** - Every API call's tokens are saved to `tokens.db`

3. **Updates sparkline history** - Builds the visual history shown in the statusline

### Without Statusline

If you prefer not to use the statusline:
- `/cmap --init` still works - imports all historical data from `~/.claude/projects/`
- `/cmap` and `/cmap -c` still show your usage
- You just won't have real-time per-message granularity in the charts

## Usage

| Command | Description |
|---------|-------------|
| (automatic) | Statusline shows in Claude Code footer |
| `/cmap` | Full analytics dashboard with charts |
| `/cmap -c` | List all chats with tokens & cost |
| `/cmap -c 20` | Show last 20 chats |
| `/cmap --init` | Import/refresh historical data |
| `/cmap -h` | Show help |

## How It Works

### Token Extraction
ContextMap reads Claude Code's session files from `~/.claude/projects/` and extracts all 4 token types from the JSONL data. This gives accurate cost calculation since cache reads are 90% cheaper than regular input.

### Statusline (3 lines)
1. Model name, session cost, total IN/OUT
2. IN history sparkline + current, OUT history sparkline + current  
3. Context window bar with percentage

### Charts
Uses Unicode braille characters (U+2800-U+28FF):
- Each character = 2 columns x 4 rows = 8 dots
- Bars fill from bottom up for proper visualization
- Different colors for different time ranges

### Pricing (per million tokens)
| Model | Input | Cache Write | Cache Read | Output |
|-------|-------|-------------|------------|--------|
| Opus | $15 | $18.75 | $1.50 | $75 |
| Sonnet | $3 | $3.75 | $0.30 | $15 |
| Haiku | $0.80 | $1.00 | $0.08 | $4 |

## Files

```
~/.config/contextmap/
├── statusline.sh    # Statusline script (called by Claude Code)
├── cmap.sh          # Analytics dashboard
├── history.txt      # Recent IN/OUT values (last 50)
└── tokens.db        # SQLite database

~/.claude/commands/
└── cmap.md          # /cmap slash command definition
```

## Database Schema

```sql
-- Individual token records (from statusline)
CREATE TABLE tokens(
  id INTEGER PRIMARY KEY,
  ts INTEGER,           -- Unix timestamp
  session TEXT,         -- Session ID
  input INTEGER,        -- input_tokens
  output INTEGER,       -- output_tokens
  cache_read INTEGER,   -- cache_read_input_tokens
  cache_write INTEGER,  -- cache_creation_input_tokens
  ctx_pct INTEGER,      -- Context window percentage
  model TEXT            -- Model ID
);

-- Aggregated chat data (from --init backfill)
CREATE TABLE chats(
  session TEXT PRIMARY KEY,
  title TEXT,           -- Auto-generated summary
  model TEXT,
  ctx_size INTEGER,
  first_ts INTEGER,
  last_ts INTEGER,
  total_input INTEGER,
  total_output INTEGER,
  cache_read INTEGER,
  cache_write INTEGER
);
```

## Requirements

- `jq` - JSON parsing
- `sqlite3` - Database storage  
- `bc` - Cost calculations
- Bash 4+
- Terminal with Unicode support

## Uninstall

```bash
rm -rf ~/.config/contextmap
rm ~/.claude/commands/cmap.md
# Remove statusLine from ~/.claude/settings.json
```

## License

MIT
