#!/bin/sh
# Sync flattened receipt samples into the app Resources folder for DEBUG bundle import.
#
# Source of truth (drop PDFs / images here):
#   <repo>/Scanned receips PDF format?/
#
# Destination (Xcode copies these into the app bundle):
#   <repo>/RatioVita/RatioVita/Resources/RVArchive2020__*
#
# Usage (from anywhere):
#   ./Scripts/sync_bundled_scanned_receipts.sh
#
set -euo pipefail
# Avoid Finder metadata / resource forks that break `codesign` on the app bundle.
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Scanned receips PDF format?"
DST="$ROOT/RatioVita/RatioVita/Resources"

if [ ! -d "$SRC" ]; then
  echo "error: missing scan folder: $SRC" >&2
  exit 1
fi

mkdir -p "$DST"

echo "Removing old RVArchive2020__* from Resources …"
find "$DST" -maxdepth 1 -type f -name 'RVArchive2020__*' -delete 2>/dev/null || true

# Flatten path for bundle filename: `/` → `__`, `?` → `_` (codesign rejects `?` in resource names).
flatten_relpath() {
  printf '%s' "$1" | sed -e 's|/|__|g' | tr '?' '_'
}

find "$SRC" -type f \( \
  -iname '*.pdf' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \
\) -print0 | while IFS= read -r -d '' f; do
  rel="${f#$SRC/}"
  safe="$(flatten_relpath "$rel")"
  cp "$f" "$DST/RVArchive2020__${safe}"
done

n="$(find "$DST" -maxdepth 1 -type f -name 'RVArchive2020__*' 2>/dev/null | wc -l | tr -d ' ')"
echo "Clearing extended attributes on synced files …"
find "$DST" -maxdepth 1 -type f -name 'RVArchive2020__*' -print0 | xargs -0 xattr -c 2>/dev/null || true
echo "Synced $n file(s) into $DST"
