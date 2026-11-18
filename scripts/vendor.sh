#!/usr/bin/env bash
# Copy css/tokens.css (and optionally tokens.json) into a consumer repository.
#
#   scripts/vendor.sh <dest-dir> [--json] [--force]
#   scripts/vendor.sh <dest-dir> --check
#
#   docs UI   scripts/vendor.sh ../arcadedb-docs/src/css
#   Studio    scripts/vendor.sh ../arcadedb/studio/src/main/resources/static/css
#
# The copy is named arcadedb-tokens.css (and arcadedb-tokens.json) and starts with
# a header that records where it came from: this repository, the commit, and the
# SHA-256 of the file body. The header is how the script knows a copy has been
# edited by hand: if the body of an existing copy no longer matches the hash in
# its own header, the script refuses to overwrite it. Use --force to overwrite
# anyway, after you have moved the edit into this repository.
#
# --check changes nothing. It exits 1 if the copy in <dest-dir> is missing, was
# edited locally, or differs from the files in this checkout. A consumer can run
# it in CI against a checkout of this repository.
#
# Run it from a clean checkout of this repository: the commit it records must be
# the one the files came from. Needs bash, git and sha256sum (or shasum).
set -euo pipefail

usage() { echo "usage: vendor.sh <dest-dir> [--json] [--force | --check]" >&2; exit 2; }

dest=""; with_json=0; force=0; check=0
for arg in "$@"; do
  case "$arg" in
    --json) with_json=1 ;;
    --force) force=1 ;;
    --check) check=1 ;;
    -*) usage ;;
    *) [ -z "$dest" ] && dest=$arg || usage ;;
  esac
done
[ -n "$dest" ] || usage
[ "$force" = 1 ] && [ "$check" = 1 ] && usage

if command -v sha256sum >/dev/null 2>&1; then
  sha() { sha256sum | awk '{print $1}'; }
else
  sha() { shasum -a 256 | awk '{print $1}'; }
fi

# Resolve the destination against the caller's directory before changing into
# this repository, so a relative path does not land inside it.
if [ "$check" = 0 ]; then mkdir -p "$dest"; fi
[ -d "$dest" ] || { echo "no such directory: $dest" >&2; exit 1; }
dest=$(cd "$dest" && pwd)
cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain -- css/tokens.css tokens.json)" ]; then
  echo "css/tokens.css or tokens.json has uncommitted changes; commit first" >&2
  exit 1
fi
commit=$(git rev-parse HEAD)
repo_url="https://github.com/ArcadeData/design-system"

# body_of <file>: everything after the header, which ends at the first line that is exactly " */".
body_of() { awk 'f{print} !f && $0==" */"{f=1}' "$1"; }
# recorded_hash <file>: the "source-sha256" value from the header, or empty.
recorded_hash() { sed -n 's/^ \* source-sha256: \([0-9a-f]\{64\}\)$/\1/p' "$1" | head -1; }

status=0
vendor_css() {
  local src=css/tokens.css out="$dest/arcadedb-tokens.css" want have recorded
  want=$(sha < "$src")
  if [ -e "$out" ]; then
    recorded=$(recorded_hash "$out")
    have=$(body_of "$out" | sha)
    if [ -z "$recorded" ] || [ "$have" != "$recorded" ]; then
      if [ "$check" = 1 ]; then echo "x $out was edited here (or has no header)" >&2; status=1; return; fi
      if [ "$force" = 0 ]; then
        echo "refusing to overwrite $out: it was edited here (or has no vendor header)." >&2
        echo "Move the change into $repo_url, or run again with --force." >&2
        exit 1
      fi
    fi
  elif [ "$check" = 1 ]; then
    echo "x $out is missing" >&2; status=1; return
  fi
  if [ "$check" = 1 ]; then
    if [ "$recorded" != "$want" ]; then echo "x $out is out of date with this checkout" >&2; status=1
    else echo "ok $out matches this checkout"; fi
    return
  fi
  {
    echo "/*"
    echo " * Vendored copy. Do not edit here."
    echo " * source: $repo_url (css/tokens.css)"
    echo " * commit: $commit"
    echo " * source-sha256: $want"
    echo " * Change the tokens in the repository above, then run scripts/vendor.sh again."
    echo " * The script refuses to overwrite this file if its body no longer matches the hash."
    echo " */"
    cat "$src"
  } > "$out.new"
  mv "$out.new" "$out"
  echo "vendored css/tokens.css ($(git rev-parse --short HEAD)) into $out"
}

vendor_json() {
  local src=tokens.json out="$dest/arcadedb-tokens.json" meta="$dest/arcadedb-tokens.json.source" want have recorded
  want=$(sha < "$src")
  if [ -e "$out" ]; then
    recorded=$(sed -n 's/^source-sha256: //p' "$meta" 2>/dev/null | head -1)
    have=$(sha < "$out")
    if [ "$have" != "$recorded" ]; then
      if [ "$check" = 1 ]; then echo "x $out was edited here (or has no source file)" >&2; status=1; return; fi
      if [ "$force" = 0 ]; then
        echo "refusing to overwrite $out: it was edited here (or has no $meta)." >&2
        exit 1
      fi
    fi
  elif [ "$check" = 1 ]; then
    echo "x $out is missing" >&2; status=1; return
  fi
  if [ "$check" = 1 ]; then
    if [ "$recorded" != "$want" ]; then echo "x $out is out of date with this checkout" >&2; status=1
    else echo "ok $out matches this checkout"; fi
    return
  fi
  cp "$src" "$out.new" && mv "$out.new" "$out"
  { echo "Vendored copy of tokens.json. Do not edit it here."
    echo "source: $repo_url"
    echo "commit: $commit"
    echo "source-sha256: $want"; } > "$meta"
  echo "vendored tokens.json into $out"
}

vendor_css
if [ "$with_json" = 1 ] || { [ "$check" = 1 ] && [ -e "$dest/arcadedb-tokens.json" ]; }; then vendor_json; fi
exit "$status"
