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

## Profiles

```bash
echo default > ~/.claude/statusline-profile   # the 2-line bar above
echo max     > ~/.claude/statusline-profile   # everything, 4 lines
echo xhanAI  > ~/.claude/statusline-profile   # minimal, with a pet cat
```

The **max** profile:

```
⠃⠶⡄⢈⠃⠰ Session name in a gradient │ ◆ Opus 5.5 effort medium 🧠 │ Tue 21:53 v2.1.296
⏱ 12m11s │ ✦ claude 2m30s 20% busy │ $0.97 $4.75/h │ +120 −30
5h 48% ↻ 2h16m │ 7d 26% ↻ 6d10h │ ctx 8% 78k/1.0M │ ♨ cache 94% warm 58m
user@host ~/repos/x ⎇ main ●3 ↑1 │ cpu 4% ram 49% 38°C │ 🌦️ 13°C
```

- Session name, model, effort, thinking / fast mode, output style, ticking clock (the colon blinks), Claude Code version.
- Session time, Claude time and % of the session Claude was busy, cost and hourly burn rate, lines added/removed.
- 5h and 7d limits with reset countdowns, context % with tokens, prompt-cache hit rate and how long it stays warm.
- Past 90% of the 5h limit the rain turns red and a blinking `⚠ SLOW DOWN` appears.
- Git branch, dirty file count (or ✔), ahead/behind; CPU load, RAM, CPU temperature; weather from wttr.in (cached 30 min, fetched in the background).

The **xhanAI** profile:

```
⠃⠶⡄⢈⠃⠰ 12m11s ✦2m30s · $0.97·4.75/h · 5h 48% ↻2h09m · ctx 8%
(=^･ω･^=) ~/repos/x ⎇main●3 · opus5.5·med · 🌦️ 13°C · +42−7 v2.1.296
```

The cat reacts to the session: blinks every few seconds, sleeps `(=ᴗ_ᴗ=)zZ` once the prompt cache goes cold (you've been idle),
frets `(=･_･;=)` past 70% of the 5h limit or context, panics `(=ﾟДﾟ=)!` past 90%, and beams `(=^▽^=)♥` after 200+ changed lines.

## Rain style

```bash
echo dots    > ~/.claude/statusline-rain   # braille dots (default)
echo letters > ~/.claude/statusline-rain   # katakana, very trippy
```

## How it works

Claude Code pipes a JSON blob (cwd, model, context_window, cost, rate_limits) to the command on stdin; whatever it prints becomes the status bar. The animation is driven by the clock (`date +%s`), one frame per refresh.
