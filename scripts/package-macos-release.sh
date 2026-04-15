#!/bin/zsh

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <version> <arm64-binary> <x64-binary> <output-dir>"
  exit 1
fi

VERSION="$1"
ARM64_BINARY="$2"
X64_BINARY="$3"
OUTPUT_DIR="$4"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$OUTPUT_DIR/universal"

UNIVERSAL_BINARY="$OUTPUT_DIR/universal/claudebar"
APP_NAME="claudeBar.app"
ZIP_PATH="$OUTPUT_DIR/claudeBar-${VERSION}-macos-universal.zip"
PKG_PATH="$OUTPUT_DIR/claudeBar-${VERSION}-installer.pkg"

lipo -create -output "$UNIVERSAL_BINARY" "$ARM64_BINARY" "$X64_BINARY"

"$REPO_ROOT/scripts/build-app-bundle.sh" "$UNIVERSAL_BINARY" "$OUTPUT_DIR" "$VERSION" "$APP_NAME"

ditto -c -k --sequesterRsrc --keepParent "$OUTPUT_DIR/$APP_NAME" "$ZIP_PATH"

pkgbuild \
  --identifier "com.germancontreras.claudebar" \
  --version "$VERSION" \
  --install-location /Applications \
  --component "$OUTPUT_DIR/$APP_NAME" \
  "$PKG_PATH"

echo "Created universal archive at $ZIP_PATH"
echo "Created installer package at $PKG_PATH"
