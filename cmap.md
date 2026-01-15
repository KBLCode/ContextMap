---
description: "Token usage analytics dashboard with charts and chat history"
allowed-tools: ["Bash"]
argument-hint: "[-c [N]] [--init] [-h]"
---

Run the ContextViewer analytics dashboard:

```bash
~/.config/context-viewer/cmap.sh $ARGUMENTS
```

Display the output directly to the user.

## Commands

- `/cmap` - Main dashboard with usage charts
- `/cmap -c` - List all chats with tokens & cost (last 100)
- `/cmap -c 20` - Show last 20 chats
- `/cmap --init` - Import all historical chats from Claude Code
- `/cmap -h` - Show help

## Dashboard Features

- **Summary table** - messages, input/output tokens, costs by period
- **Braille charts** - 1h, 24h, 7d, 30d usage visualization
- **Cost by model** - Opus, Sonnet, Haiku breakdown with accurate cache pricing
- **Recent sessions** - last sessions with duration and cost

## Chat History (-c flag)

Shows all tracked chats with:
- Session ID
- Model (color-coded: red=opus, yellow=sonnet, cyan=haiku)
- Title (auto-generated summary)
- Input tokens, Output tokens, Cache tokens
- Cost (calculated with proper per-model cache pricing)

## Token Types

ContextViewer tracks all 4 token types for accurate cost calculation:
- `input_tokens` - Fresh input (full price)
- `cache_creation_input_tokens` - Cache write (1.25x price)
- `cache_read_input_tokens` - Cache read (90% cheaper!)
- `output_tokens` - Model output
