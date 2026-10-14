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
jq --arg cmd "bash $dest/statusline-command.sh" \
  '.statusLine = {type: "command", command: $cmd, refreshInterval: 1}' \
  "$settings.bak" > "$settings"
echo "Installed. Backup of your settings: $settings.bak"
echo "Restart Claude Code. Change the look any time: echo snake > $dest/statusline-profile"
