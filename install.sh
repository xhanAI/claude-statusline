#!/usr/bin/env bash
# Installs the status line into ~/.claude and wires it into settings.json (other settings are kept).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dest="$HOME/.claude"
mkdir -p "$dest"
command -v jq >/dev/null || { echo "jq is required (sudo apt install jq)"; exit 1; }

cp "$here/statusline-command.sh" "$dest/statusline-command.sh"
[ -f "$dest/statusline-rain" ] || echo dots > "$dest/statusline-rain"

mkdir -p "$HOME/.local/bin"; cp "$here/claude-cost" "$here/lava-demo" "$HOME/.local/bin/"

settings="$dest/settings.json"
[ -f "$settings" ] || echo '{}' > "$settings"
cp "$settings" "$settings.bak"
jq --arg cmd "bash $dest/statusline-command.sh" \
  '.statusLine = {type: "command", command: $cmd, refreshInterval: 1}' \
  "$settings.bak" > "$settings"
echo "Installed. Backup of your settings: $settings.bak"
echo "Rain style: echo letters|dots > $dest/statusline-rain"
