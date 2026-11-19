# ArcadeData design system

The front-end values that ArcadeData's web pages share, kept in one place: colours for light and dark, the type scale, spacing, radii and the focus ring. Each front end copies the file in with a script. There is no package, no build step and no dependency for the consumer.

This repository holds values only. It has no components and no CSS framework. Each front end keeps its own markup and styles.

It follows the proposal in [ArcadeData/arcadedb discussion 11325](https://github.com/ArcadeData/arcadedb/discussions/11325).

## What is here

| Path | What it is |
|---|---|
| `tokens.json` | The source of every value, with a description, and the list of text and background pairs that the contrast check reads. |
| `css/tokens.css` | The same values as CSS custom properties, generated from `tokens.json`. Light, dark by system setting, and a `data-theme` override. |
| `scripts/tokens.py` | Writes `css/tokens.css` from `tokens.json`. With `--check` it fails if the CSS is out of date. |
| `scripts/contrast.py` | Prints every pair in both themes with its ratio and PASS or FAIL. Exits 1 on a failure. |
| `scripts/vendor.sh` | Copies the tokens into a consumer with a header that says where they came from. |
| `.github/workflows/check.yml` | Runs the checks above on every pull request and push to `main`. |

The scripts need only `uv` (they declare no dependencies) or, for `vendor.sh`, bash and git.

## Use the tokens in a front end

Copy the file in from a clean checkout of this repository:

```
scripts/vendor.sh ../arcadedb/studio/src/main/resources/static/css
```

This writes `arcadedb-tokens.css` into that directory, with a header that records the source repository, the commit and a SHA-256 of the file body. Add `--json` to copy `tokens.json` as well (with a small `.source` file beside it, because JSON has no comments).

Then link it before your own stylesheet and read the variables:

```html
<link rel="stylesheet" href="css/arcadedb-tokens.css">
```

```css
body { background: var(--adb-color-bg); color: var(--adb-color-text); }
a { color: var(--adb-color-link); }
.btn-primary { background: var(--adb-color-brand); color: var(--adb-color-on-brand); }
.tab-active { color: var(--adb-color-brand-text); border-bottom: 2px solid var(--adb-color-brand); }
:focus-visible { outline: var(--adb-focus-width) solid var(--adb-color-focus); outline-offset: var(--adb-focus-offset); }
```

The vendored copy must not be edited. If a copy was edited by hand, `vendor.sh` refuses to overwrite it, so a local change is never lost without notice. Move the change here, then run the script again. `--force` overwrites anyway.

`scripts/vendor.sh <dest> --check` changes nothing. It exits 1 if the copy is missing, was edited, or is older than this checkout, so a consumer can run it in CI.

### Light and dark

The system setting decides (`prefers-color-scheme`). To give the reader a switch, set `data-theme="light"` or `data-theme="dark"` on `<html>`. Remove the attribute to follow the system again. The docs site does this today.

## Names

Colours are `--adb-color-<name>`. Every colour has a light and a dark value. Everything else has one value.

| Name | Use |
|---|---|
| `bg`, `bg-subtle`, `bg-accent`, `surface`, `card` | Page and panel backgrounds. |
| `brand-tint` | A light wash of the brand blue for selected rows and callouts. |
| `border`, `border-subtle` | Decorative dividers and edges. No contrast minimum. |
| `border-strong` | Edges of form controls. 3:1 against the surface. |
| `text`, `text-muted` | Body and secondary text. |
| `brand`, `brand-hover` | The ArcadeDB blue for fills (buttons, active tabs, badges). Not for text on a light page. |
| `brand-border` | Border of a control in the brand blue. 3:1. |
| `brand-text`, `brand-text-hover` | The same blue as text and icons. Darker in the light theme so it passes 4.5:1. |
| `on-brand` | Text on a brand fill. Dark ink in both themes. |
| `link`, `link-hover` | Links in running text. |
| `focus` | Keyboard focus ring. 3:1. |
| `danger`, `success`, `warning` | Status text and icons. Use with words or an icon, not colour alone. |
| `code-bg`, `code-text`, `code-comment`, `inline-code-bg`, `inline-code-text` | Code blocks and inline code. |

The other names are `--adb-font-body`, `--adb-font-heading`, `--adb-font-code`, `--adb-size-xs` to `--adb-size-4xl`, `--adb-line-height-body`, `--adb-line-height-tight`, `--adb-space-1` to `--adb-space-16`, `--adb-radius-sm`, `--adb-radius-md`, `--adb-radius-lg`, `--adb-radius-pill`, `--adb-focus-width` and `--adb-focus-offset`. Each has a description in `tokens.json` and in a comment in `css/tokens.css`.

The brand blue is split in two on purpose. `#00AEEE` (dark theme `#29B6F6`) is Studio's blue, and it stays the colour of fills and borders. It cannot be text on white (2.53:1). `brand-text` is the same hue made darker, `#007099` on light pages (5.56:1 on white), and equals `brand` on dark pages.

The font stacks and the type, spacing and radius scales are a first proposal. The font stacks are the docs site's. The radii are the values the two sites use most (4, 6 and 8 px). The type and spacing steps are not measured from either site yet, so the first consumer pull request is the place to adjust them.

## Add or change a token

1. Edit `tokens.json`. A colour needs `light`, `dark` (both `#RRGGBB`), a `role` and a `description`. A role is one of `text`, `ui` (borders and the focus ring), `background`, `fill` or `decoration`.
2. If the colour is text, an icon, a control border or a background, add it to a pair in the `pairs` list. The check fails when a `text`, `ui`, `background` or `fill` token is in no pair, so a new colour cannot skip it.
3. Run `uv run scripts/tokens.py` to rewrite `css/tokens.css`, then `uv run scripts/contrast.py`.
4. Commit `tokens.json` and `css/tokens.css` together. Raise the `version` in `tokens.json` for a change a consumer would notice.

## The contrast rule

Every pair in `tokens.json` is checked in both themes by `uv run scripts/contrast.py`, which exits 1 if any pair is under its minimum. The minimums are the WCAG 2.2 AA ones:

- 4.5:1 for body text (success criterion 1.4.3).
- 3:1 for large text, and for control borders and the focus ring (1.4.3 and 1.4.11).

The script uses the standard WCAG relative luminance formula and only the Python standard library. `--self-test` shows that it fails on a known bad pair (the brand blue as text on white). The workflow in `.github/workflows/check.yml` runs both on every pull request.

The check covers the pairs listed in `tokens.json`. It does not cover a front end that uses a colour outside the tokens, which is why a consumer should map its colours onto these names.

## What changes on each front end when it adopts this

This list comes from the measurements in the discussion (Studio at `74536eb676`, docs site as served on 2026-11-18). It is the list to check before either follow-up pull request is merged. Ratios are WCAG contrast against the page background.

### Studio (`studio/src/main/resources/static/css/studio.css`)

Studio has 51 tokens of its own and shares no token name with the docs site.

| Where | Today | After |
|---|---|---|
| Text set in `--color-brand` (31 declarations), light theme | `#00AEEE`, 2.53:1 | `brand-text` `#007099`, 5.56:1 |
| `--color-brand-link` (1 use), light theme | `#02A3FF`, 2.73:1 | `brand-text` `#007099`, 5.56:1 |
| Text on a brand fill (buttons, active tabs, badges; 21 `color: #fff` declarations in the file, 8 `background: var(--color-brand)` rules) | white, 2.53:1 light and 2.30:1 dark | `on-brand` `#0B1D29`, 6.78:1 light and 7.46:1 dark |
| Brand fill, hover, border and tint, both themes | `#00AEEE`, `#0098D4`, `#0E76BC`, `#E8F4FD`; dark `#29B6F6`, `#4FC3F7`, `#29B6F6`, `#1A3A4A` | unchanged |
| Muted greys as text, light theme (`--text-faint`, `--text-lighter`, `--text-lightest`, `--text-placeholder`) | `#777` 4.48:1, `#888` 3.54:1, `#999` 2.85:1, `#BBB` 1.92:1 | `text-muted` `#4A5568`, 7.53:1 on white |
| Placeholder text, dark theme | `#475569`, 2.23:1 on the page | `text-muted` `#AEB8C6` |
| Dark page, card and sidebar | `#1A1D21`, `#22262B`, `#22262B` | `#0F1217`, `#1A1F27`, `#151920` |
| Body text, light and dark | `#333` and `#E2E8F0` | `#1A1D23` and `#E8ECF2` |
| Dark theme follows the system setting | no, manual switch only | yes, with the manual switch kept as an override |
| Body font | Poppins | Inter, if Studio uses `--adb-font-body` (it may keep its own) |

The Studio rows that are not about the brand blue exist because the shared neutrals are the docs site's, which the proposal said would be the first consumer. They can be changed in this repository before Studio adopts them.

### Docs site (`arcadedb.css`, 60 tokens)

The docs site's neutrals, link blue, status colours and code colours are the source of the shared values, so they do not change. What does:

| Where | Today | After |
|---|---|---|
| Token names | `--color-bg`, `--color-text-primary`, ... | `--adb-color-bg`, `--adb-color-text`, ... (a rename, or an alias layer in the docs CSS) |
| `--color-primary` (46 uses, plus `--color-primary-dark` 5 and `--color-on-primary` 4), light | `#0066CC` fills and text, white on top | `brand` `#00AEEE` for fills with `on-brand` text, `brand-text` `#007099` for text and borders |
| `--color-primary`, dark | `#5AAEFF` | `brand` `#29B6F6` and `brand-text` `#29B6F6` |
| Tokens the docs site has and this repository does not | hero gradients, `--c-purple`, `--c-lime`, `--c-pink-text`, `--c-teal-text` and similar accent colours, scrollbar | stay in the docs CSS for now |

The link blue (`#1565C0` light, `#6DB3FF` dark) and its hover colours are kept as they are. It is a different hue from the brand blue. Whether links should become the brand blue is a decision for the docs pull request.

## License

Apache-2.0. See `LICENSE`.
