---
description: "Token usage analytics - beautiful braille charts showing 1h, 24h, 7d, 30d usage patterns"
allowed-tools: ["Bash"]
---

Run the ContextViewer analytics dashboard:

```bash
~/.config/context-viewer/cmap.sh
```

Display the output directly to the user. This shows:

- **Summary table** with messages, input/output tokens, and costs
- **1-hour chart** (1-minute intervals) - high-resolution braille visualization
- **24-hour chart** (15-minute intervals) - daily activity patterns
- **7-day chart** (2-hour intervals) - weekly trends with day labels
- **30-day chart** (6-hour intervals) - monthly overview
- **Models breakdown** - usage by model (24h)
- **Recent sessions** - last 5 sessions with duration and cost
- **Insights** - average tokens per message, input/output ratio

All charts use Unicode braille characters for beautiful high-resolution visualization.
