#!/usr/bin/env bash
input=$(cat)
j() { echo "$input" | jq -r "$1 // empty"; }
cwd=$(j .cwd); model=$(j .model.display_name); used=$(j .context_window.used_percentage)
total=$(j .cost.total_duration_ms); api=$(j .cost.total_api_duration_ms)
five=$(j .rate_limits.five_hour.used_percentage); reset=$(j .rate_limits.five_hour.resets_at)

R=$'\033[0m'; DIM=$'\033[2m'; B=$'\033[1m'
fg() { printf '\033[38;2;%s;%s;%sm' "$1" "$2" "$3"; }
SEP="${DIM}$(fg 110 110 140) │ ${R}"

fmt() { local s=$(( $1 / 1000 ))
  if [ "$s" -ge 3600 ]; then printf "%dh%02dm" $((s/3600)) $((s%3600/60))
  elif [ "$s" -ge 60 ]; then printf "%dm%02ds" $((s/60)) $((s%60))
  else printf "%ds" "$s"; fi; }

# green -> yellow -> red by percentage
heat() { local p=${1%.*}
  if [ "$p" -lt 50 ]; then fg 80 220 140
  elif [ "$p" -lt 80 ]; then fg 250 200 70
  else fg 255 95 95; fi; }

# bar: filled blocks in heat colour, empty dim
bar() { local p=${1%.*} w=${2:-10} f i out=""
  f=$(( (p * w + 50) / 100 )); [ "$f" -gt "$w" ] && f=$w
  if [ "$3" = neutral ]; then out+=$(fg 130 180 255); else out+=$(heat "$p"); fi; for ((i=0;i<f;i++)); do out+="█"; done
  out+="$(fg 70 70 90)"; for ((i=f;i<w;i++)); do out+="░"; done
  printf '%s%s' "$out" "$R"; }

# animation: tiny matrix rain. style from ~/.claude/statusline-rain: "dots" (default) or "letters"
style=$(cat "$HOME/.claude/statusline-rain" 2>/dev/null)
glyphs=(ｱ ｲ ｳ ｴ ｵ ｶ ｷ ｸ ｹ ｺ ｻ ｼ ｽ ｾ ｿ ﾀ ﾁ ﾂ ﾃ ﾄ ﾅ ﾆ ﾇ ﾈ ﾉ ﾊ ﾋ ﾌ ﾍ ﾎ ﾏ ﾐ ﾑ ﾒ ﾓ ﾔ ﾕ ﾖ ﾗ ﾘ ﾙ ﾚ ﾛ ﾜ ﾝ 0 1 2 3 4 5 7 8 9)
rows=(1 2 4 64); rows2=(8 16 32 128)   # braille dot bits per row: left / right column
now=$(date +%s)
spin=""
for c in 0 1 2 3 4 5; do
  head=$(( (now + c * 2) % 6 ))      # each column has its own falling head
  case $head in
    0) col="200 255 210" ;;
    1) col="60 230 110" ;;
    2) col="40 170 85" ;;
    3) col="25 120 60" ;;
    4) col="18 80 42" ;;
    *) col="12 50 28" ;;
  esac
  if [ "$style" = letters ]; then
    g=${glyphs[$(( (now * 7 + c * 13 + c * c * 5) % ${#glyphs[@]} ))]}
    [ "$head" -ge 5 ] && g="·"
  else
    h=$(( (now + c) % 4 )); t=$(( (h + 3) % 4 ))        # falling dot + trail above it
    if [ $(( (now / 2 + c) % 2 )) -eq 0 ]; then m=$(( ${rows[$h]} | ${rows[$t]} )); else m=$(( ${rows2[$h]} | ${rows2[$t]} )); fi
    [ $(( (now + c * 3) % 5 )) -eq 0 ] && m=$(( ${rows[$h]} | ${rows2[$t]} | ${rows[$t]} | ${rows2[$h]} ))
    g=$(printf "\\U$(printf %08x $((0x2800 + m)))")
  fi
  spin+="$(fg $col)$g"
done
spin+="$R"

# ---- line 1 ----
line="$spin "
[ -n "$total" ] && line+="$(fg 130 180 255)⏱ ${B}$(fmt "${total%.*}")${R}"
[ -n "$api" ] && line+="${SEP}$(fg 217 119 87)✦ claude ${B}$(fmt "${api%.*}")${R}"
if [ -n "$five" ]; then
  line+="${SEP}$(fg 160 160 190)5h ${R}$(heat "$five")${B}$(printf '%.0f' "$five")%${R}"
  if [ -n "$reset" ]; then
    left=$(( ${reset%.*} - $(date +%s) ))
    [ "$left" -gt 0 ] && line+=" ${DIM}$(fg 160 160 190)↻ $(fmt $((left*1000)))${R}"
  fi
fi
printf '%s\n' "$line"

# ---- line 2 ----
printf '%s%s@%s%s %s%s%s' "$(fg 120 230 150)" "$(whoami)" "$(hostname -s)" "$R" "$(fg 110 170 255)" "$cwd" "$R"
[ -n "$model" ] && printf '%s%s◆ %s%s' "$SEP" "$(fg 255 170 100)" "$model" "$R"
[ -n "$used" ] && printf '%sctx %s%.0f%%%s' "$SEP" "$(heat "$used")" "$used" "$R"
printf '\n'
