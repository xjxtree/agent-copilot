#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SVG="$ROOT_DIR/apps/macos/Sources/SkillsCopilot/Resources/AppIcon.svg"
TARGET_ICNS="$ROOT_DIR/apps/macos/Sources/SkillsCopilot/Resources/AppIcon.icns"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-copilot-icon.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_SVG" ]]; then
  echo "missing app icon source: $SOURCE_SVG" >&2
  exit 1
fi

command -v qlmanage >/dev/null || {
  echo "qlmanage is required to render $SOURCE_SVG" >&2
  exit 1
}
command -v sips >/dev/null || {
  echo "sips is required to resize icon rasters" >&2
  exit 1
}
command -v iconutil >/dev/null || {
  echo "iconutil is required to create $TARGET_ICNS" >&2
  exit 1
}

qlmanage -t -s 1024 -o "$TMP_DIR" "$SOURCE_SVG" >/dev/null
BASE_PNG="$TMP_DIR/$(basename "$SOURCE_SVG").png"
if [[ ! -f "$BASE_PNG" ]]; then
  echo "icon render failed: $BASE_PNG was not created" >&2
  exit 1
fi

ICONSET="$TMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

make_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET/$name" >/dev/null
}

make_icon 16 "icon_16x16.png"
make_icon 32 "icon_16x16@2x.png"
make_icon 32 "icon_32x32.png"
make_icon 64 "icon_32x32@2x.png"
make_icon 128 "icon_128x128.png"
make_icon 256 "icon_128x128@2x.png"
make_icon 256 "icon_256x256.png"
make_icon 512 "icon_256x256@2x.png"
make_icon 512 "icon_512x512.png"
make_icon 1024 "icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$TARGET_ICNS"
file "$TARGET_ICNS"
