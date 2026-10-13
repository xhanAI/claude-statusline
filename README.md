# claude-statusline

A colourful two-line status line for Claude Code.

```
⠰⡄⢈⠛⠰⡄ ⏱ 1h01m │ ✦ claude 2m05s │ 5h 62% ↻ 1h30m
user@host /path/to/dir │ ◆ Sonnet │ ctx 12%
```

- **Line 1:** matrix-rain animation, session time, Claude API time, 5h rate-limit usage and time until it resets.
- **Line 2:** user@host, directory, model, context usage.
- Percentages are green < 50%, yellow < 80%, red above. "claude" is Claude orange.
- The 5h number only appears when Claude Code reports rate limits (subscription plans).

## Install

Needs `jq`.

```bash
git clone <this repo> && cd claude-statusline && ./install.sh
```

This copies the script to `~/.claude/`, sets `statusLine` in `~/.claude/settings.json` (backup saved as `settings.json.bak`) with `refreshInterval: 1` so the animation ticks.

## Rain style

```bash
echo dots    > ~/.claude/statusline-rain   # braille dots (default)
echo letters > ~/.claude/statusline-rain   # katakana, very trippy
```

## How it works

Claude Code pipes a JSON blob (cwd, model, context_window, cost, rate_limits) to the command on stdin; whatever it prints becomes the status bar. The animation is driven by the clock (`date +%s`), one frame per refresh.
