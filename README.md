# ContextViewer

Real-time token usage visualization for OpenCode and Claude Code.

```
╭─ tokens ─────────────────────────────────────────────────────╮
│ ⣀⣤⣶⣿⣶⣤⣀⣀⣤⣶⣿⣿⣿⣶⣤⣀⣀⣤⣶⣿⣶⣤⣀⣀⣤⣶⣿⣿⣿⣿⣶⣤⣀  IN 2.4k  │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ ⠉⠛⠿⣿⠿⠛⠉⠉⠛⠉⠉⠉⠉⠉⠛⠉⠉⠛⠿⣿⠿⠛⠉⠉⠉⠉⠉⠉⠉⠉⠛⠉⠉  OUT 892  │
│ ──────────────────────────────────────────────────────────── │
│ ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣤⣤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀ 82% +1.5k $0 │
╰──────────────────────────────────────────────────────────────╯
```

## Features

- DNA helix-style visualization of input vs output tokens
- Braille characters for high-density display
- Real-time updates during streaming
- Context window usage bar (resets on compaction)
- `/cmap` command for 24-hour historical view
- Works with both OpenCode and Claude Code

## Installation

### OpenCode

```bash
# Copy the plugin folder
cp -r packages/opencode/plugin ~/.config/opencode/plugins/context-viewer
```

### Claude Code

```bash
# Copy to your project
cp -r packages/claude-code/context-viewer .claude-plugin/

# Or install globally
cp -r packages/claude-code/context-viewer ~/.claude/context-viewer
```

## Usage

### Real-time Widget
The token widget displays automatically during conversations.

### `/cmap` Command
View 24-hour token usage history:
```
/cmap        # Show last 24 hours
/cmap 12     # Show last 12 hours
```

## How It Works

- **Top line**: Input tokens (peaks pointing up)
- **Center line**: Baseline separator
- **Bottom line**: Output tokens (peaks pointing down)
- **Context bar**: Shows context window usage (resets on compaction)

## Project Structure

```
ContextViewer/
├── core/                    # Shared library (bundled into packages)
├── packages/
│   ├── opencode/           # OpenCode plugin
│   └── claude-code/        # Claude Code plugin
└── docs/                   # Documentation
```

## Development

```bash
# Install dependencies
bun install

# Build all packages
./scripts/build.sh

# Build specific package
cd packages/opencode && bun run build
```

## License

MIT
