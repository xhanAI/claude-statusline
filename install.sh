#!/usr/bin/env bash
# Installs the status line into ~/.claude and wires it into settings.json (other settings are kept).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dest="$HOME/.claude"
mkdir -p "$dest"
command -v jq >/dev/null || { echo "jq is required (sudo apt install jq)"; exit 1; }

cp "$here/statusline-command.sh" "$dest/statusline-command.sh"

mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/lava-demo"   # the old name of statusline-demo
for f in claude-cost statusline-demo; do   # skip when ~/.local/bin already links back here
  [ "$here/$f" -ef "$HOME/.local/bin/$f" ] || cp "$here/$f" "$HOME/.local/bin/"
done

settings="$dest/settings.json"
[ -f "$settings" ] || echo '{}' > "$settings"
cp "$settings" "$settings.bak"
# the status line, plus a SessionEnd hook that books each finished session into ~/.claude/cost-totals.tsv
# (any older copy of that hook is replaced, other hooks are kept)
jq --arg cmd "bash $dest/statusline-command.sh" --arg hook "bash $HOME/.local/bin/claude-cost --session-end" '
  .statusLine = {type: "command", command: $cmd, refreshInterval: 1}
  | .hooks.SessionEnd = ([.hooks.SessionEnd[]? | .hooks |= map(select(.command | test("claude-cost --session-end") | not)) | select(.hooks | length > 0)]
                         + [{hooks: [{type: "command", command: $hook}]}])' \
  "$settings.bak" > "$settings"

# costs: convert old per-directory ledgers to per-start-dir, then book everything so far
"$HOME/.local/bin/claude-cost" --migrate
"$HOME/.local/bin/claude-cost" --book-all
echo "Installed. Backup of your settings: $settings.bak"
echo "Restart Claude Code. Change the look any time: echo snake > $dest/statusline-profile"
