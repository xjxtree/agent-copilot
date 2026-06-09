#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="SkillsCopilot"
BUNDLE_ID="dev.skills-copilot.native"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(awk -F'"' '/^version = / {print $2; exit}' "$ROOT_DIR/crates/service/Cargo.toml")"
MACOS_DIR="$ROOT_DIR/apps/macos"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
SERVICE_BINARY="$APP_RESOURCES/skills-copilot-service"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$MACOS_DIR/Sources/SkillsCopilot/Resources/AppIcon.icns"
ICON_TARGET="$APP_RESOURCES/AppIcon.icns"
SWIFT_RESOURCES="$MACOS_DIR/Sources/SkillsCopilot/Resources"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cargo build -p skills-copilot-service
swift build --package-path "$MACOS_DIR"

SWIFT_BIN_DIR="$(swift build --package-path "$MACOS_DIR" --show-bin-path)"
RUST_SERVICE="$ROOT_DIR/target/debug/skills-copilot-service"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$SWIFT_BIN_DIR/$APP_NAME" "$APP_BINARY"
cp "$RUST_SERVICE" "$SERVICE_BINARY"
if [[ -d "$SWIFT_RESOURCES" ]]; then
  cp -R "$SWIFT_RESOURCES"/. "$APP_RESOURCES"/
fi
if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "missing native app icon: $ICON_SOURCE" >&2
  exit 1
fi
cp "$ICON_SOURCE" "$ICON_TARGET"
chmod +x "$APP_BINARY" "$SERVICE_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

LAUNCH_ENV_VARS=(
  SKILLS_COPILOT_HOME
  SKILLS_COPILOT_APP_DATA_DIR
  SKILLS_COPILOT_CLAUDE_EXTRA_ROOTS
  SKILLS_COPILOT_SERVICE_PATH
)

set_launch_env() {
  for name in "${LAUNCH_ENV_VARS[@]}"; do
    if [[ -n "${!name:-}" ]]; then
      /bin/launchctl setenv "$name" "${!name}"
    fi
  done
}

clear_launch_env() {
  for name in "${LAUNCH_ENV_VARS[@]}"; do
    /bin/launchctl unsetenv "$name" >/dev/null 2>&1 || true
  done
}

open_app() {
  trap clear_launch_env EXIT
  clear_launch_env
  set_launch_env
  /usr/bin/open -n "$APP_BUNDLE"
  sleep 1
  clear_launch_env
  trap - EXIT
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
