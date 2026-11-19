# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Contrast check for tokens.json.

    uv run scripts/contrast.py              print the table, exit 1 on any FAIL
    uv run scripts/contrast.py --self-test  prove the check fails on a bad pair

Every pair in tokens.json "pairs" is checked in both themes. The minimum is
4.5:1 for text and 3:1 for large text, control borders and the focus ring
(WCAG 2.2 AA, success criteria 1.4.3 and 1.4.11). Standard library only.

Rules that also fail the run:
  - a colour is not a six-digit hex value;
  - a pair names a token that does not exist;
  - a token with role text or ui is in no pair (a new token cannot skip the check);
  - a token with role background or fill is in no pair.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
THEMES = ("light", "dark")
MINIMUMS = (3.0, 4.5)


def channel(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hex_colour):
    r, g, b = (int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def ratio(a, b):
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def run(tokens):
    """Return (rows, problems). A row is (theme, fg, bg, fg_hex, bg_hex, ratio, minimum, ok)."""
    colors = tokens["color"]
    problems = []
    for name, tok in colors.items():
        for theme in THEMES:
            if not HEX.match(tok.get(theme, "")):
                problems.append(f"color.{name}.{theme} is not a #RRGGBB value: {tok.get(theme)!r}")
    seen_fg, seen_bg = set(), set()
    rows = []
    for pair in tokens["pairs"]:
        if pair["min"] not in MINIMUMS:
            problems.append(f"pair {pair['use']!r}: minimum {pair['min']} is not 4.5 (text) or 3 (large text, non-text)")
        for fg in pair["fg"]:
            for bg in pair["bg"]:
                missing = [n for n in (fg, bg) if n not in colors]
                if missing:
                    problems.append(f"pair {fg} on {bg}: unknown token {missing}")
                    continue
                seen_fg.add(fg)
                seen_bg.add(bg)
                for theme in THEMES:
                    a, b = colors[fg][theme], colors[bg][theme]
                    if not (HEX.match(a) and HEX.match(b)):
                        continue
                    r = ratio(a, b)
                    rows.append((theme, fg, bg, a.upper(), b.upper(), r, pair["min"], r >= pair["min"]))
    for name, tok in colors.items():
        role = tok.get("role")
        if role in ("text", "ui") and name not in seen_fg:
            problems.append(f"color.{name} has role {role} but is the foreground of no pair")
        if role in ("background", "fill") and name not in seen_bg:
            problems.append(f"color.{name} has role {role} but is the background of no pair")
        if role not in ("text", "ui", "background", "fill", "decoration"):
            problems.append(f"color.{name} has an unknown role {role!r}")
    return rows, problems


def table(rows):
    head = f"{'theme':5}  {'text or edge':17} {'on background':14} {'fg':7} {'bg':7} {'ratio':>7} {'min':>5}  result"
    out = [head, "-" * len(head)]
    for theme, fg, bg, a, b, r, minimum, ok in rows:
        out.append(f"{theme:5}  {fg:17} {bg:14} {a:7} {b:7} {r:5.2f}:1 {minimum:>3}:1  {'PASS' if ok else 'FAIL'}")
    return "\n".join(out)


def main(argv):
    tokens = json.loads((ROOT / "tokens.json").read_text())
    if "--self-test" in argv:
        bad = json.loads(json.dumps(tokens))
        bad["color"]["brand-text"]["light"] = "#00AEEE"  # the 2.53:1 blue the proposal started from
        rows, problems = run(bad)
        failed = [r for r in rows if not r[7]]
        if not failed:
            print("self-test: a failing pair was not caught")
            return 1
        orphan = json.loads(json.dumps(tokens))
        orphan["color"]["lonely"] = {"light": "#000000", "dark": "#FFFFFF", "role": "text", "description": "x"}
        _, problems = run(orphan)
        if not any("lonely" in p for p in problems):
            print("self-test: a token with no pair was not caught")
            return 1
        print(f"self-test ok: {len(failed)} failing rows and an unchecked token were caught")
        return 0
    rows, problems = run(tokens)
    print(table(rows))
    fails = [r for r in rows if not r[7]]
    for p in problems:
        print(f"PROBLEM: {p}")
    print(f"\n{len(rows)} pair checks in {len(THEMES)} themes: {len(rows) - len(fails)} pass, {len(fails)} fail, {len(problems)} problem(s)")
    return 1 if fails or problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
