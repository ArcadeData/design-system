#!/usr/bin/env bash
# Smoke test for scripts/vendor.sh. Run from a clean checkout (the script itself requires it).
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

scripts/vendor.sh "$tmp/out" --json >/dev/null
head -4 "$tmp/out/arcadedb-tokens.css" | grep -q 'Vendored copy' || fail "no header"
grep -q "^ \* commit: $(git rev-parse HEAD)$" "$tmp/out/arcadedb-tokens.css" || fail "header has the wrong commit"
scripts/vendor.sh "$tmp/out" --json >/dev/null || fail "a clean second run must succeed"
scripts/vendor.sh "$tmp/out" --check >/dev/null || fail "--check on a fresh copy must pass"

# A hand edit of the CSS must stop the next vendor run, and --check must report it.
echo ".local-edit { color: red; }" >> "$tmp/out/arcadedb-tokens.css"
if scripts/vendor.sh "$tmp/out" >/dev/null 2>&1; then fail "overwrote a locally edited CSS copy"; fi
if scripts/vendor.sh "$tmp/out" --check >/dev/null 2>&1; then fail "--check passed on an edited copy"; fi
scripts/vendor.sh "$tmp/out" --force >/dev/null || fail "--force must overwrite"
scripts/vendor.sh "$tmp/out" --check >/dev/null || fail "--check after --force must pass"

# Same for the JSON copy.
echo " " >> "$tmp/out/arcadedb-tokens.json"
if scripts/vendor.sh "$tmp/out" --json >/dev/null 2>&1; then fail "overwrote a locally edited JSON copy"; fi

# A file with no header is treated as edited.
printf 'a { color: red; }\n' > "$tmp/plain.css"; mkdir "$tmp/plain"; cp "$tmp/plain.css" "$tmp/plain/arcadedb-tokens.css"
if scripts/vendor.sh "$tmp/plain" >/dev/null 2>&1; then fail "overwrote a file with no header"; fi
echo "vendor.sh: all checks passed"
