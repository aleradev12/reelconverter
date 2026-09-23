#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:?Usage: scripts/export-repo.sh /path/to/reelconverter-main}"
if [[ -e "$TARGET" ]]; then
  echo "Refusing to overwrite existing path: $TARGET" >&2
  exit 1
fi
mkdir -p "$TARGET"
for item in Package.swift Sources Resources Assets scripts packaging .github .gitignore .gitattributes README.md LICENSE; do
  cp -R "$ROOT/$item" "$TARGET/$item"
done
git -C "$TARGET" init -b main
git -C "$TARGET" add .
git -C "$TARGET" commit -m "Initial ReelConverter app and release tooling"
printf 'Independent repository: %s\n' "$TARGET"
