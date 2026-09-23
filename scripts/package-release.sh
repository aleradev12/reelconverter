#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.1}"
"$ROOT/scripts/build-app.sh" "$VERSION"
ARCH="$(uname -m)"
ARCHIVE="$ROOT/dist/ReelConverter-v$VERSION-macos-$ARCH.zip"
rm -f "$ARCHIVE"
cd "$ROOT/dist"
ditto -c -k --sequesterRsrc --keepParent ReelConverter.app "$ARCHIVE"
shasum -a 256 "$ARCHIVE"
printf 'Release archive: %s\n' "$ARCHIVE"
