#!/usr/bin/env python3
"""make-gifs.py: render the README gallery GIFs from the real status line script.

Feeds statusline-command.sh fake input frame by frame (ART_T = the clock, ART_MOOD = the mood),
parses its ANSI output and draws it with Pillow. Runs with a throwaway HOME so it never touches
the real cost ledger or caches.  Usage: tools/make-gifs.py   (writes docs/*.gif)
"""
import os, re, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "statusline-command.sh")
OUT = os.path.join(REPO, "docs")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
FPS, SECONDS = 12, 3

# effect -> the mood it is shown in (the liveliest one that still reads as "the effect")
EFFECTS = {"lava": "calm", "rain": "calm", "acid": "calm", "tunnel": "calm", "aurora": "calm",
           "ember": "calm", "warp": "calm", "pulse": "working", "helix": "calm", "ripple": "calm",
           "ecg": "working", "hourglass": "calm", "life": "calm", "snake": "calm", "planet": "calm", "orbit": "calm", "smiley": "calm"}

INPUT = ('{"cwd":"%s/repos/active/claude-statusline","session_id":"gif","model":{"display_name":"Opus 5.5"},'
         '"effort":{"level":"medium"},"version":"2.1.300","cost":{"total_cost_usd":3.42,"total_duration_ms":2580000,'
         '"total_api_duration_ms":744000,"total_lines_added":152,"total_lines_removed":51},'
         '"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":%d}},"context_window":{"used_percentage":45}}')

SGR = re.compile(r"\x1b\[([0-9;]*)m")
BG0 = (13, 14, 22)


def cells(text):
    """ANSI text -> rows of (char, fg, bg, dim)."""
    rows = []
    for line in text.splitlines():
        fg, bg, dim, row, pos = (220, 220, 230), BG0, False, [], 0
        for m in SGR.finditer(line + "\x1b[m"):
            for ch in line[pos:m.start()]:
                row.append((ch, fg, bg, dim))
            pos = m.end()
            p = [int(x) for x in m.group(1).split(";") if x] or [0]
            i = 0
            while i < len(p):
                if p[i] == 0: fg, bg, dim = (220, 220, 230), BG0, False
                elif p[i] == 2: dim = True
                elif p[i] in (38, 48) and p[i + 1] == 2:
                    c = tuple(p[i + 2:i + 5]); i += 4
                    if p[i - 4] == 38: fg = c
                    else: bg = c
                i += 1
        rows.append(row)
    return rows


def draw(rows, cw, ch, font, ncols=None, pad=0):
    ncols = ncols or max(len(r) for r in rows)
    img = Image.new("RGB", (ncols * cw + 2 * pad, len(rows) * ch + 2 * pad), BG0)
    d = ImageDraw.Draw(img)
    for y, row in enumerate(rows):
        for x, (c, fg, bg, dim) in enumerate(row[:ncols]):
            X, Y = pad + x * cw, pad + y * ch
            if dim: fg = tuple(int(v * 0.6) for v in fg)
            if c == "▀":
                d.rectangle([X, Y, X + cw - 1, Y + ch // 2 - 1], fill=fg)
                d.rectangle([X, Y + ch // 2, X + cw - 1, Y + ch - 1], fill=bg)
            else:
                if bg != BG0: d.rectangle([X, Y, X + cw - 1, Y + ch - 1], fill=bg)
                if 0x2800 <= ord(c) <= 0x28FF:  # braille: draw the dots, most mono fonts lack them
                    bits, r = ord(c) - 0x2800, max(1, cw // 7)
                    for bit, (bx, by) in enumerate([(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)]):
                        if bits >> bit & 1:
                            cx, cy = X + cw * (0.3 + 0.4 * bx), Y + ch * (0.14 + 0.24 * by)
                            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fg)
                elif 0x1FB00 <= ord(c) <= 0x1FB3B or c in "▌▐█":  # sextants: 2x3 solid pixels
                    if c in "▌▐█": bits = {"▌": 21, "▐": 42, "█": 63}[c]
                    else: n = ord(c) - 0x1FB00 + 1; bits = n + (n >= 21) + (n + (n >= 21) >= 42)
                    for i in range(6):
                        x0, y0 = X + (i % 2) * cw // 2, Y + (i // 2) * ch // 3
                        d.rectangle([x0, y0, x0 + cw // 2 - 1, y0 + ch // 3 - 1], fill=fg if bits >> i & 1 else bg)
                elif c == "▄":
                    d.rectangle([X, Y + ch // 2, X + cw - 1, Y + ch - 1], fill=fg)
                elif c != " ": d.text((X + cw / 2, Y + ch / 2), c, font=font, fill=fg, anchor="mm")
    return img


def run(home, profile, fx, mood, t):
    env = dict(os.environ, HOME=home, STATUSLINE_PROFILE=profile, ART_FX=fx, ART_MOOD=mood, ART_T=f"{t:.3f}")
    inp = INPUT % (os.path.expanduser("~"), int(t) + 7560)
    out = subprocess.run(["bash", SCRIPT], input=inp, capture_output=True, text=True, env=env).stdout
    return out.replace(os.path.expanduser("~"), "~")  # the throwaway HOME hides the real one from the script


def save(frames, path):
    pal = [f.convert("P", palette=Image.ADAPTIVE, colors=64) for f in frames]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=1000 // FPS, loop=0, optimize=True, disposal=1)
    print(f"{os.path.relpath(path, REPO):24} {os.path.getsize(path) / 1024:6.1f} KB")


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as home:
        os.makedirs(f"{home}/.cache", exist_ok=True)
        with open(f"{home}/.cache/claude-statusline-weather", "w") as f:
            f.write("☀ +18°C")  # a fresh weather cache, so the script never goes to the network
        t0 = 1000.0
        times = [t0 + i / FPS for i in range(FPS * SECONDS)]

        # each effect alone, big pixels
        art_font = ImageFont.truetype(FONT, 26)
        only = sys.argv[1:]  # e.g. tools/make-gifs.py smiley  -> just that one
        for fx, mood in EFFECTS.items():
            if only and fx not in only: continue
            frames = [draw(cells(run(home, "xhanAI", fx, mood, t))[:3], 18, 36, art_font, ncols=8, pad=6) for t in times]
            save(frames, f"{OUT}/{fx}.gif")

        if only: return
        # the whole xhanAI bar, lava working
        bar_font = ImageFont.truetype(FONT, 15)
        frames = [draw(cells(run(home, "xhanAI", "lava", "working", t)), 9, 18, bar_font, pad=10) for t in times]
        save(frames, f"{OUT}/xhanai.gif")


if __name__ == "__main__":
    main()
