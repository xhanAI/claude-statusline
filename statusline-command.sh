#!/usr/bin/env bash
# Claude Code status line.
#   profile: ~/.claude/statusline-profile  -> "default" (2 lines), "max" (everything, 4 lines) or "xhanAI" (minimal, 3 lines)
#   rain:    ~/.claude/statusline-rain     -> "dots" (default) or "letters"
#   art:     ~/.claude/statusline-art      -> xhanAI only: "lava" (default) or "rain"
input=$(cat)
# every field in one jq call (one fork instead of ~20)
eval "$(jq -r '@sh "
cwd=\(.cwd // "") model=\(.model.display_name // "") used=\(.context_window.used_percentage // "")
total=\(.cost.total_duration_ms // "") api=\(.cost.total_api_duration_ms // "") cost=\(.cost.total_cost_usd // "")
five=\(.rate_limits.five_hour.used_percentage // "") reset=\(.rate_limits.five_hour.resets_at // "")
wk=\(.rate_limits.seven_day.used_percentage // "") wkr=\(.rate_limits.seven_day.resets_at // "")
sid=\(.session_id // "") proj=\(.workspace.project_dir // "") transcript=\(.transcript_path // "")
name=\(.session_name // "") ver=\(.version // "") effort=\(.effort.level // "")
think=\(.thinking.enabled // "" | tostring) fast=\(.fast_mode // "" | tostring) style=\(.output_style.name // "")
added=\(.cost.total_lines_added // "") removed=\(.cost.total_lines_removed // "")
csize=\(.context_window.context_window_size // "") ctok=\(.context_window.total_input_tokens // "")
hit=\(.prompt_cache.hit_ratio // "") warm=\(.prompt_cache.warm | tostring) cexp=\(.prompt_cache.expires_at // "")
"' <<< "$input")"
profile=${STATUSLINE_PROFILE:-$(cat "$HOME/.claude/statusline-profile" 2>/dev/null)}
now=$(date +%s)

# cost ledger: one tiny file per session in ~/.claude/cost-ledger, holding
#   project_dir <TAB> banked <TAB> last
# written only when the session cost changes. if the cost ever drops (a resumed session
# that restarted its counter), the old amount is banked so nothing is lost.
# project total = sum over every session file of that project. `claude-cost` prints a report.
LEDGER="$HOME/.claude/cost-ledger"
proj=${proj:-$cwd}
if [ -n "$sid" ] && [ -n "$cost" ] && [ -n "$proj" ]; then
  lf="$LEDGER/$sid"; banked=0; last=0
  [ -f "$lf" ] && IFS=$'\t' read -r _ banked last < "$lf"
  if [ "$cost" != "$last" ]; then
    banked=$(awk -v b="$banked" -v l="$last" -v c="$cost" 'BEGIN{print (c+0 < l+0) ? b+l : b}')
    mkdir -p "$LEDGER"; printf '%s\t%s\t%s\n' "$proj" "$banked" "$cost" > "$lf.tmp" && mv "$lf.tmp" "$lf"
  fi
fi
project_total() { [ -d "$LEDGER" ] && cat "$LEDGER"/* 2>/dev/null | awk -F'\t' -v p="$proj" '$1==p{s+=$2+$3} END{printf "%.2f", s}'; }

R=$'\033[0m'; DIM=$'\033[2m'; B=$'\033[1m'
fg() { printf '\033[38;2;%s;%s;%sm' "$1" "$2" "$3"; }
SEP="${DIM}$(fg 110 110 140) │ ${R}"

fmt() { local s=$(( $1 / 1000 ))
  if [ "$s" -ge 86400 ]; then printf "%dd%02dh" $((s/86400)) $((s%86400/3600))
  elif [ "$s" -ge 3600 ]; then printf "%dh%02dm" $((s/3600)) $((s%3600/60))
  elif [ "$s" -ge 60 ]; then printf "%dm%02ds" $((s/60)) $((s%60))
  else printf "%ds" "$s"; fi; }
until_() { [ -n "$1" ] || return; local left=$(( ${1%.*} - now )); [ "$left" -gt 0 ] && fmt $((left * 1000)); }

# green -> yellow -> red by percentage
heat() { local p=${1%.*}
  if [ "$p" -lt 50 ]; then fg 80 220 140
  elif [ "$p" -lt 80 ]; then fg 250 200 70
  else fg 255 95 95; fi; }

# text painted with a left-to-right RGB gradient: grad "text" r1 g1 b1 r2 g2 b2
grad() { local t=$1 n=${#1} i d out=""
  d=$(( n > 1 ? n - 1 : 1 ))
  for ((i=0;i<n;i++)); do
    out+="$(fg $(( $2 + ($5 - $2) * i / d )) $(( $3 + ($6 - $3) * i / d )) $(( $4 + ($7 - $4) * i / d )))${t:i:1}"
  done; printf '%s%s' "$out" "$R"; }

# animation: tiny matrix rain, 6 columns of falling glyphs that fade as they drop
rain() {
  local style glyphs rows rows2 spin="" c head col g h t m
  style=$(cat "$HOME/.claude/statusline-rain" 2>/dev/null)
  glyphs=(ｱ ｲ ｳ ｴ ｵ ｶ ｷ ｸ ｹ ｺ ｻ ｼ ｽ ｾ ｿ ﾀ ﾁ ﾂ ﾃ ﾄ ﾅ ﾆ ﾇ ﾈ ﾉ ﾊ ﾋ ﾌ ﾍ ﾎ ﾏ ﾐ ﾑ ﾒ ﾓ ﾔ ﾕ ﾖ ﾗ ﾘ ﾙ ﾚ ﾛ ﾜ ﾝ 0 1 2 3 4 5 7 8 9)
  rows=(1 2 4 64); rows2=(8 16 32 128)   # braille dot bits per row: left / right column
  for c in 0 1 2 3 4 5; do
    head=$(( (now + c * 2) % 6 ))
    case $head in
      0) col="200 255 210" ;; 1) col="60 230 110" ;; 2) col="40 170 85" ;;
      3) col="25 120 60" ;;   4) col="18 80 42" ;;   *) col="12 50 28" ;;
    esac
    # max profile: the rain turns red when the 5h window is nearly spent
    if [ "$profile" = max ] && [ -n "$five" ] && [ "${five%.*}" -ge 90 ]; then
      col="$(( ${col%% *} + 55 )) 30 30"; [ "$head" -le 1 ] && col="255 70 70"
    fi
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
  printf '%s%s' "$spin" "$R"; }

# ------------------------------------------------------------------ default
render_default() {
  local line
  line="$(rain) "
  [ -n "$total" ] && line+="$(fg 130 180 255)⏱ ${B}$(fmt "${total%.*}")${R}"
  [ -n "$api" ] && line+="${SEP}$(fg 217 119 87)✦ claude ${B}$(fmt "${api%.*}")${R}"
  [ -n "$cost" ] && line+="${SEP}$(fg 240 200 90)\$${B}$(printf '%.2f' "$cost")${R}"
  if [ -n "$five" ]; then
    line+="${SEP}$(fg 160 160 190)5h ${R}$(heat "$five")${B}$(printf '%.0f' "$five")%${R}"
    [ -n "$(until_ "$reset")" ] && line+=" ${DIM}$(fg 160 160 190)↻ $(until_ "$reset")${R}"
  fi
  printf '%s\n' "$line"

  printf '%s%s@%s%s %s%s%s' "$(fg 120 230 150)" "$(whoami)" "$(hostname -s)" "$R" "$(fg 110 170 255)" "$cwd" "$R"
  [ -n "$model" ] && printf '%s%s◆ %s%s' "$SEP" "$(fg 255 170 100)" "$model" "$R"
  [ -n "$used" ] && printf '%sctx %s%.0f%%%s' "$SEP" "$(heat "$used")" "$used" "$R"
  printf '\n'
}

# ------------------------------------------------------------------ max
render_max() {
  local L
  local GR; GR=$(fg 160 160 190)

  # line 1, identity: rain, session name in a gradient, model, flags, ticking clock, version
  L="$(rain) $(grad "${name:-Claude Code}" 255 120 200 120 200 255)"
  [ -n "$model" ] && L+="${SEP}$(fg 255 170 100)◆ ${B}${model}${R}"
  [ -n "$effort" ] && L+=" ${GR}effort ${R}$(fg 200 150 255)${effort}${R}"
  [ "$think" = true ] && L+=" $(fg 120 220 255)🧠${R}"
  [ "$fast" = true ] && L+=" $(fg 255 220 80)⚡fast${R}"
  [ -n "$style" ] && [ "$style" != default ] && L+=" ${GR}style ${R}${style}"
  local colon=":"; [ $((now % 2)) -eq 1 ] && colon=" "
  L+="${SEP}$(fg 130 180 255)$(date +%a) $(date +%H)${colon}$(date +%M)${R}"
  [ -n "$ver" ] && L+=" ${DIM}${GR}v${ver}${R}"
  printf '%s\n' "$L"

  # line 2, time and money: session, claude time + how busy, cost + burn rate, lines changed
  L=""
  [ -n "$total" ] && L+="$(fg 130 180 255)⏱ ${B}$(fmt "${total%.*}")${R}"
  if [ -n "$api" ]; then
    L+="${L:+$SEP}$(fg 217 119 87)✦ claude ${B}$(fmt "${api%.*}")${R}"
    [ -n "$total" ] && [ "${total%.*}" -gt 0 ] && L+=" ${GR}$(( ${api%.*} * 100 / ${total%.*} ))% busy${R}"
  fi
  if [ -n "$cost" ]; then
    L+="${L:+$SEP}$(fg 240 200 90)\$${B}$(printf '%.2f' "$cost")${R}"
    [ -n "$total" ] && [ "${total%.*}" -gt 60000 ] && \
      L+=" ${GR}$(awk -v c="$cost" -v t="$total" 'BEGIN{printf "$%.2f/h", c/(t/3600000)}')${R}"
  fi
  [ -n "$added" ] && L+="${L:+$SEP}$(fg 80 220 140)+${added}${R} $(fg 255 95 95)−${removed:-0}${R}"
  [ -n "$L" ] && printf '%s\n' "$L"

  # line 3, limits: 5h (with a blinking warning past 90%), 7d, context + tokens, prompt cache
  L=""
  if [ -n "$five" ]; then
    L+="${GR}5h ${R}$(heat "$five")${B}$(printf '%.0f' "$five")%${R}"
    [ -n "$(until_ "$reset")" ] && L+=" ${DIM}${GR}↻ $(until_ "$reset")${R}"
    [ "${five%.*}" -ge 90 ] && [ $((now % 2)) -eq 0 ] && L+=" $(fg 255 70 70)${B}⚠ SLOW DOWN${R}"
  fi
  if [ -n "$wk" ]; then
    L+="${L:+$SEP}${GR}7d ${R}$(heat "$wk")${B}$(printf '%.0f' "$wk")%${R}"
    [ -n "$(until_ "$wkr")" ] && L+=" ${DIM}${GR}↻ $(until_ "$wkr")${R}"
  fi
  if [ -n "$used" ]; then
    L+="${L:+$SEP}${GR}ctx ${R}$(heat "$used")${B}$(printf '%.0f' "$used")%${R}"
    [ -n "$ctok" ] && [ -n "$csize" ] && L+=" ${GR}$(awk -v a="$ctok" -v b="$csize" \
      'function h(x){return x>=1e6?sprintf("%.1fM",x/1e6):sprintf("%dk",x/1e3)} BEGIN{printf "%s/%s", h(a), h(b)}')${R}"
  fi
  if [ -n "$hit" ]; then
    if [ "$warm" = true ]; then L+="${L:+$SEP}$(fg 255 150 90)♨ cache"; else L+="${L:+$SEP}$(fg 140 170 220)❄ cache"; fi
    L+=" $(awk -v h="$hit" 'BEGIN{printf "%.0f%%", h*100}')${R}"
    [ "$warm" = true ] && [ -n "$(until_ "$cexp")" ] && L+=" ${DIM}${GR}warm $(until_ "$cexp")${R}"
  fi
  [ -n "$L" ] && printf '%s\n' "$L"

  # line 4, place and machine: user@host, dir, git, cpu, ram, temp, weather
  L="$(fg 120 230 150)$(whoami)@$(hostname -s)${R} $(fg 110 170 255)${cwd/#$HOME/\~}${R}"
  local gs br dirty ab
  if [ -n "$cwd" ] && gs=$(timeout 0.3 git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null); then
    br=$(echo "$gs" | awk '/^# branch.head/{print $3}')
    ab=$(echo "$gs" | awk '/^# branch.ab/{a=$3; b=$4; sub(/\+/,"",a); sub(/-/,"",b); s=""; if(a>0) s=s"↑"a; if(b>0) s=s"↓"b; print s}')
    dirty=$(echo "$gs" | grep -vc '^#')
    L+=" $(fg 200 150 255)⎇ ${br}${R}"
    if [ "$dirty" -gt 0 ]; then L+=" $(fg 250 200 70)●${dirty}${R}"; else L+=" $(fg 80 220 140)✔${R}"; fi
    [ -n "$ab" ] && L+=" $(fg 120 220 255)${ab}${R}"
  fi
  local load cpu mem temp h
  read -r load _ < /proc/loadavg
  cpu=$(awk -v l="$load" -v c="$(nproc)" 'BEGIN{printf "%d", l*100/c}')
  mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d", (t-a)*100/t}' /proc/meminfo)
  L+="${SEP}${GR}cpu ${R}$(heat "$cpu")${cpu}%${R} ${GR}ram ${R}$(heat "$mem")${mem}%${R}"
  for h in /sys/class/hwmon/hwmon*; do
    case $(cat "$h/name" 2>/dev/null) in k10temp|coretemp|zenpower)
      temp=$(( $(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000 )); break ;; esac
  done
  [ -n "$temp" ] && [ "$temp" -gt 0 ] && L+=" $(heat $(( (temp - 30) * 2 )))${temp}°C${R}"
  # weather: cached for 30 min, refreshed in the background so the bar never waits on the network
  local wf="$HOME/.cache/claude-statusline-weather" w
  if [ ! -f "$wf" ] || [ $(( now - $(stat -c %Y "$wf") )) -gt 1800 ]; then
    mkdir -p "${wf%/*}"; touch "$wf"
    ( curl -s -m 5 'https://wttr.in/?format=%c%t' > "$wf.tmp" && mv "$wf.tmp" "$wf" ) >/dev/null 2>&1 &
  fi
  w=$(tr -d '\n+' < "$wf" 2>/dev/null)
  [ -n "$w" ] && [ ${#w} -lt 20 ] && L+="${SEP}${w}"
  printf '%s\n' "$L"
}

# ------------------------------------------------------------------ xhanAI
# matrix rain three rows tall: each column is 12 braille dots high, a head falls through it
# with a fading trail. prints row 0, 1 or 2.
rain2() {
  local row=$1 out="" c p side cell r d best col g bits
  local rl=(1 2 4 64) rr=(8 16 32 128)
  local glyphs=(ｱ ｲ ｳ ｴ ｵ ｶ ｷ ｸ ｹ ｺ ｻ ｼ ｽ ｾ ｿ ﾀ ﾁ ﾂ ﾃ ﾄ ﾅ ﾆ ﾇ ﾈ ﾉ ﾊ ﾋ ﾌ ﾍ ﾎ ﾏ ﾐ ﾑ ﾒ ﾓ ﾔ ﾕ ﾖ ﾗ ﾘ ﾙ ﾚ ﾛ ﾜ ﾝ 0 1 2 3 4 5 7 8 9)
  local style; style=$(cat "$HOME/.claude/statusline-rain" 2>/dev/null)
  for c in 0 1 2 3 4 5; do
    p=$(( (now * 2 + c * 5 + c * c) % 15 ))      # head position 0..14 (12+ = off screen)
    side=$(( (now / 5 + c) % 2 ))
    bits=0; best=9
    for r in 0 1 2 3; do
      cell=$(( row * 4 + r )); d=$(( p - cell ))  # distance behind the head
      if [ "$d" -ge 0 ] && [ "$d" -le 3 ]; then
        if [ "$side" -eq 0 ]; then bits=$(( bits | ${rl[$r]} )); else bits=$(( bits | ${rr[$r]} )); fi
        [ "$d" -lt "$best" ] && best=$d
      fi
    done
    case $best in
      0) col="210 255 220" ;; 1) col="80 240 130" ;; 2) col="40 180 90" ;; 3) col="25 120 60" ;; *) col="25 60 40" ;;
    esac
    if [ "$style" = letters ]; then
      if [ "$bits" -eq 0 ]; then g=" "; else g=${glyphs[$(( (now * 7 + c * 13 + row * 29) % ${#glyphs[@]} ))]}; fi
    else
      g=$(printf "\\U$(printf %08x $((0x2800 + bits)))")
    fi
    out+="$(fg $col)$g"
  done
  printf '%s%s' "$out" "$R"; }

# lava lamp, 8 cells wide and 3 rows tall. each cell is a half block "▀" with its own
# foreground (top pixel) and background (bottom pixel), so it is an 8x6 true-colour canvas.
# the plasma is a few overlapping sine waves; the mood picks the palette and the speed.
#   calm   orange lava, slow            working  hot yellow-white lava, fast (Claude is busy)
#   idle   deep blue with a moon        warn     dark red-orange (5h or ctx >= 70%)
#   alarm  red, pulsing (>= 90%)        clean    green flash right after the tree goes clean
#   fire   white-hot, fastest (burning more than $15/h while working)
lava() { # lava <time> <mood>  -> fills LAVA[0..2]
  mapfile -t LAVA < <(awk -v t="$1" -v mood="$2" '
    function clamp(x){ return x < 0 ? 0 : (x > 255 ? 255 : int(x)) }
    function mix(a, b, f){ return a + (b - a) * f }
    # three-stop gradient lo -> mid -> hi, v in 0..1
    function grad3(v, r0,g0,b0, r1,g1,b1, r2,g2,b2,   f) {
      if (v < 0.5) { f = v * 2; return clamp(mix(r0,r1,f)) ";" clamp(mix(g0,g1,f)) ";" clamp(mix(b0,b1,f)) }
      f = (v - 0.5) * 2;      return clamp(mix(r1,r2,f)) ";" clamp(mix(g1,g2,f)) ";" clamp(mix(b1,b2,f)) }
    function colour(v, x, y,   d1, d2, k) {
      if (mood == "idle") {
        if ((x " " y) in moon) return "235;225;170"             # crescent moon
        return grad3(v, 6,6,24, 30,25,90, 90,70,190) }
      if (mood == "clean")   return grad3(v, 0,25,10, 30,170,80, 190,255,200)
      if (mood == "warn")    return grad3(v, 35,0,15, 175,15,50, 255,95,80)
      if (mood == "alarm") { k = (int(t) % 2) ? 1 : 0.45
                             return grad3(v, 40*k,0,0, 200*k,10,10, 255*k,70*k,60*k) }
      if (mood == "working") return grad3(v, 70,5,0, 245,95,0, 255,235,140)
      if (mood == "fire")    return grad3(v, 120,10,0, 255,150,20, 255,255,240)
      return grad3(v, 25,0,0, 200,40,0, 255,170,40) }               # calm
    BEGIN {
      sp = (mood == "fire") ? 1.6 : (mood == "working") ? 1.1 : (mood == "idle") ? 0.15 : (mood == "alarm") ? 0.8 : 0.35
      T = t * sp
      split("6 0,5 0,4 1,4 2,5 3,6 3", m, ",")                # pixels of a "(" crescent, top right
      for (i in m) moon[m[i]] = 1
      for (row = 0; row < 3; row++) {
        line = ""
        for (x = 0; x < 8; x++) {
          for (k = 0; k < 2; k++) {
            y = row * 2 + k
            v = sin(x * 0.55 + T) + sin(y * 0.75 - T * 1.3) + sin((x + y) * 0.45 + T * 0.7) \
              + sin(sqrt((x - 3.5 - 2 * sin(T * 0.5))^2 + (y - 2.5 - 1.5 * cos(T * 0.4))^2) * 1.1 - T)
            v = 0.5 + v / 5                                        # -4..4 -> roughly 0..1, extra contrast
            v = v < 0 ? 0 : (v > 1 ? 1 : v)
            if (mood == "working" || mood == "fire") v = v ^ 0.8   # more of the hot end
            c[k] = colour(v, x, y)
          }
          line = line "\033[38;2;" c[0] "m\033[48;2;" c[1] "m▀"
        }
        print line "\033[0m"
      }
    }')
}

# what the lava should feel like right now
lava_mood() {
  [ -n "$LAVA_MOOD" ] && { echo "$LAVA_MOOD"; return; }          # forced, for the demo
  local f=${five%.*} c=${used%.*}; f=${f:-0}; c=${c:-0}
  if [ "$f" -ge 90 ] || [ "$c" -ge 90 ]; then echo alarm; return; fi
  [ -n "$clean_until" ] && [ "$now" -lt "$clean_until" ] && { echo clean; return; }
  local busy=0
  [ -n "$transcript" ] && [ -f "$transcript" ] && [ $(( now - $(stat -c %Y "$transcript") )) -le 4 ] && busy=1
  if [ "$busy" -eq 1 ]; then
    if [ -n "$cost" ] && [ -n "$total" ] && [ "${total%.*}" -gt 600000 ] && \
       awk -v c="$cost" -v t="$total" 'BEGIN{exit !(c/(t/3600000) > 15)}'; then echo fire; else echo working; fi
    return
  fi
  if [ "$f" -ge 70 ] || [ "$c" -ge 70 ]; then echo warn; return; fi
  [ "$warm" = false ] && { echo idle; return; }
  echo calm; }

render_xhanai() {
  local GR SP br dirty gs w e L art
  GR=$(fg 120 120 145); SP="   "
  art=$(cat "$HOME/.claude/statusline-art" 2>/dev/null)

  # git first: the lava flashes green when the tree goes from dirty to clean
  if [ -n "$cwd" ] && gs=$(timeout 0.3 git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null); then
    br=$(echo "$gs" | awk '/^# branch.head/{print $3}'); dirty=$(echo "$gs" | grep -vc '^#')
  fi
  local st="$HOME/.cache/claude-statusline/${sid:-none}" prev=""; clean_until=""
  [ -f "$st" ] && read -r prev clean_until < "$st"
  if [ -n "$dirty" ] && [ "$dirty" != "$prev" ]; then
    [ "${prev:-0}" -gt 0 ] && [ "$dirty" -eq 0 ] && clean_until=$(( now + 6 ))
    mkdir -p "${st%/*}"; echo "$dirty ${clean_until}" > "$st"
  fi

  local P0 P1 P2
  if [ "$art" = rain ]; then
    P0="$(rain2 0)"; P1="$(rain2 1)"; P2="$(rain2 2)"
  else
    lava "${LAVA_T:-$now}" "$(lava_mood)"; P0=${LAVA[0]}; P1=${LAVA[1]}; P2=${LAVA[2]}
  fi

  # line 1, where: dir + branch alone, so their changing length never shifts anything else
  L="$P0  $(fg 110 170 255)${B}${cwd/#$HOME/\~}${R}"
  if [ -n "$br" ]; then
    L+=" ${GR}on${R} $(fg 200 150 255)${br}${R}"
    [ "$dirty" -gt 0 ] && L+=" $(fg 250 200 70)●${dirty}${R}"
  fi
  printf '%s\n' "$L"

  # line 2, what: model, weather, version
  L="$P1 "
  if [ -n "$model" ]; then
    case $effort in medium) e=med ;; *) e=$effort ;; esac
    L+=" $(fg 255 170 100)${model,,}${R}${e:+ ${GR}${e}${R}}"
  fi
  local wf="$HOME/.cache/claude-statusline-weather"
  if [ ! -f "$wf" ] || [ $(( now - $(stat -c %Y "$wf") )) -gt 1800 ]; then
    mkdir -p "${wf%/*}"; touch "$wf"
    ( curl -s -m 5 'https://wttr.in/?format=%c%t' > "$wf.tmp" && mv "$wf.tmp" "$wf" ) >/dev/null 2>&1 &
  fi
  w=$(tr -d '\n+' < "$wf" 2>/dev/null | sed 's/  */ /g')
  [ -n "$w" ] && [ ${#w} -lt 20 ] && L+="${SP}${w}"
  [ -n "$ver" ] && L+="${SP}${GR}v${ver}${R}"
  printf '%s\n' "$L"

  # line 3, numbers: times, money, limit, context, diff
  L="$P2 "
  [ -n "$total" ] && L+=" $(fg 130 180 255)$(fmt "${total%.*}")${R}"
  [ -n "$api" ] && L+=" $(fg 217 119 87)✦ $(fmt "${api%.*}")${R}"
  if [ -n "$cost" ]; then
    L+="${SP}$(fg 240 200 90)\$$(printf '%.2f' "$cost")${R}"
    [ -n "$total" ] && [ "${total%.*}" -gt 60000 ] && \
      L+=" ${GR}$(awk -v c="$cost" -v t="$total" 'BEGIN{printf "%.2f/h", c/(t/3600000)}')${R}"
    # all-time cost of this project (every session started in it)
    local pt; pt=$(project_total)
    [ -n "$pt" ] && [ "$pt" != 0.00 ] && L+=" ${GR}Σ${R} $(fg 240 200 90)\$${pt}${R}"
  fi
  if [ -n "$five" ]; then
    L+="${SP}${GR}5h${R} $(heat "$five")$(printf '%.0f' "$five")%${R}"
    [ -n "$(until_ "$reset")" ] && L+=" ${GR}$(until_ "$reset")${R}"
  fi
  [ -n "$used" ] && L+="${SP}${GR}ctx${R} $(heat "$used")$(printf '%.0f' "$used")%${R}"
  [ -n "$added" ] && L+="${SP}$(fg 80 220 140)+${added}${R} $(fg 255 95 95)−${removed:-0}${R}"
  printf '%s\n' "$L"
}

case $profile in
  max) render_max ;;
  xhanAI|xhanai) render_xhanai ;;
  *) render_default ;;
esac
