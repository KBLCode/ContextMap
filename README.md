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
- Context window usage bar
- Works with both OpenCode and Claude Code

## Installation

### OpenCode

```bash
# Copy plugin to OpenCode plugins directory
cp -r dist/opencode ~/.config/opencode/plugins/context-viewer
```

### Claude Code

```bash
# Copy plugin to Claude Code plugins directory
cp -r dist/claude-code ~/.claude-plugin/context-viewer
```

## How It Works

- **Top line**: Input tokens (peaks pointing up)
- **Center line**: Baseline separator
- **Bottom line**: Output tokens (peaks pointing down)
- **Context bar**: Shows how much of the context window is used

## Development

```bash
# Install dependencies
bun install

# Build
bun run build

# Test
bun test
```

## License

MIT
