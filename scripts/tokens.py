# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate css/tokens.css from tokens.json, or check that it is up to date.

    uv run scripts/tokens.py            write css/tokens.css
    uv run scripts/tokens.py --check    exit 1 if css/tokens.css differs from tokens.json

tokens.json is the source. The two dark blocks (system preference, and an
explicit data-theme="dark") come from the same list, so they cannot differ.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "css" / "tokens.css"


def generate(tokens):
    p = tokens["prefix"]
    colors, static = tokens["color"], tokens["static"]
    out = [
        "/*",
        " * ArcadeData design tokens. GENERATED from tokens.json by scripts/tokens.py.",
        " * Edit tokens.json, run `uv run scripts/tokens.py`, commit both.",
        " *",
        f" * Names: --{p}-color-<name> (light and dark), then --{p}-font-*, --{p}-size-*,",
        f" * --{p}-line-height-*, --{p}-space-*, --{p}-radius-*, --{p}-focus-* (one value).",
        " *",
        " * Theme: the system setting decides. Set data-theme=\"light\" or data-theme=\"dark\"",
        " * on <html> to override it.",
        " *",
        " * Every text and background pair is checked in both themes by",
        " * scripts/contrast.py: 4.5:1 for text, 3:1 for large text, control borders",
        " * and the focus ring (WCAG 2.2 AA).",
        " */",
        "",
        ":root {",
    ]
    for name, tok in colors.items():
        out.append(f"  --{p}-color-{name}: {tok['light'].upper()}; /* {tok['description']} */")
    out.append("  color-scheme: light;")
    out.append("")
    for name, tok in static.items():
        out.append(f"  --{p}-{name}: {tok['value']}; /* {tok['description']} */")
    out += ["}", ""]
    dark = [f"--{p}-color-{name}: {tok['dark'].upper()};" for name, tok in colors.items()]
    out.append("@media (prefers-color-scheme: dark) {")
    out.append("  :root:not([data-theme=\"light\"]) {")
    out += [f"    {d}" for d in dark]
    out += ["    color-scheme: dark;", "  }", "}", ""]
    out.append(":root[data-theme=\"dark\"] {")
    out += [f"  {d}" for d in dark]
    out += ["  color-scheme: dark;", "}", ""]
    return "\n".join(out)


def main(argv):
    tokens = json.loads((ROOT / "tokens.json").read_text())
    want = generate(tokens)
    if "--check" in argv:
        have = OUT.read_text() if OUT.exists() else ""
        if have != want:
            print("css/tokens.css is out of date with tokens.json. Run: uv run scripts/tokens.py")
            return 1
        print("css/tokens.css matches tokens.json")
        return 0
    OUT.write_text(want)
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
