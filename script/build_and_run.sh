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
LAUNCHED_PID=""

canonical_app_bundle() {
  if [[ -d "$APP_BUNDLE" ]]; then
    (cd "$APP_BUNDLE" && pwd -P)
  else
    printf '%s\n' "$APP_BUNDLE"
  fi
}

list_running_app_instances() {
  swift -Xfrontend -disable-availability-checking -e '
import AppKit
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
let bundleId = args.indices.contains(0) ? args[0] : ""
let appName = args.indices.contains(1) ? args[1] : ""

for app in NSWorkspace.shared.runningApplications {
    let identifierMatches = app.bundleIdentifier == bundleId
    let nameMatches = app.localizedName == appName
    guard identifierMatches || nameMatches else { continue }
    let bundlePath = app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path ?? ""
    print("\(app.processIdentifier)\t\(bundlePath)")
}
' "$BUNDLE_ID" "$APP_NAME"
}

wait_for_no_running_app_instances() {
  local quiet="${1:-}"
  local deadline=$((SECONDS + 5))
  while (( SECONDS < deadline )); do
    if [[ -z "$(list_running_app_instances || true)" ]]; then
      return 0
    fi
    sleep 0.25
  done
  if [[ "$quiet" != "--quiet" ]]; then
    echo "stale-bundle: timed out waiting for existing $APP_NAME instances to exit" >&2
  fi
  return 1
}

terminate_existing_app_instances() {
  local rows
  rows="$(list_running_app_instances || true)"
  if [[ -z "$rows" ]]; then
    return 0
  fi
  local target_bundle
  target_bundle="$(canonical_app_bundle)"
  while IFS=$'\t' read -r pid bundle_path; do
    [[ -z "$pid" ]] && continue
    if [[ -n "$bundle_path" && "$bundle_path" != "$target_bundle" ]]; then
      echo "Stopping stale same-bundle $APP_NAME pid $pid from $bundle_path (target $target_bundle)." >&2
    fi
    kill "$pid" >/dev/null 2>&1 || true
  done <<<"$rows"
  if ! wait_for_no_running_app_instances --quiet; then
    rows="$(list_running_app_instances || true)"
    while IFS=$'\t' read -r pid _bundle_path; do
      [[ -n "$pid" ]] && kill -9 "$pid" >/dev/null 2>&1 || true
    done <<<"$rows"
    wait_for_no_running_app_instances
  fi
}

wait_for_current_bundle_process() {
  local deadline=$((SECONDS + 10))
  local target_bundle
  target_bundle="$(canonical_app_bundle)"
  while (( SECONDS < deadline )); do
    local rows exact_pids
    rows="$(list_running_app_instances || true)"
    exact_pids=""
    if [[ -n "$rows" ]]; then
      while IFS=$'\t' read -r pid bundle_path; do
        [[ -z "$pid" ]] && continue
        [[ "$bundle_path" == "$target_bundle" ]] && exact_pids+="${pid}"$'\n'
      done <<<"$rows"
    fi
    local exact_count
    exact_count="$(printf '%s' "$exact_pids" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [[ "$exact_count" == "1" ]]; then
      printf '%s\n' "$exact_pids" | sed '/^$/d' | head -n 1
      return 0
    fi
    if [[ "$exact_count" != "0" ]]; then
      echo "activation-failed: duplicate current bundle processes for $target_bundle: $(printf '%s' "$exact_pids" | tr '\n' ' ')" >&2
      return 1
    fi
    sleep 0.25
  done
  local rows stale_rows
  rows="$(list_running_app_instances || true)"
  stale_rows=""
  if [[ -n "$rows" ]]; then
    while IFS=$'\t' read -r pid bundle_path; do
      [[ -z "$pid" ]] && continue
      [[ "$bundle_path" != "$target_bundle" ]] && stale_rows+="${pid} ${bundle_path}"$'\n'
    done <<<"$rows"
  fi
  if [[ -n "$stale_rows" ]]; then
    echo "stale-bundle: running $APP_NAME instances are from different bundle path than target $target_bundle: $(printf '%s' "$stale_rows" | tr '\n' '; ')" >&2
  else
    echo "activation-failed: timed out waiting for $APP_NAME to launch from $target_bundle" >&2
  fi
  return 1
}

activate_current_app() {
  local pid="$1"
  swift -Xfrontend -disable-availability-checking -e '
import AppKit
import Foundation

let rawPid = CommandLine.arguments.dropFirst().first ?? ""
guard let pid = Int32(rawPid),
      let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
    fputs("activation-failed: unable to resolve running app pid \(rawPid).\n", stderr)
    exit(2)
}

let activated = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
if !activated {
    fputs("activation-failed: failed to activate \(app.localizedName ?? "target app") pid \(pid).\n", stderr)
    exit(3)
}
' "$pid"
}

wait_for_visible_window() {
  local pid="$1"
  local deadline=$((SECONDS + 10))
  local output status
  while (( SECONDS < deadline )); do
    if output="$(swift -Xfrontend -disable-availability-checking -e '
import AppKit
import CoreGraphics
import Foundation

let rawPid = CommandLine.arguments.dropFirst().first ?? ""
guard let expectedPid = Int32(rawPid) else {
    fputs("window-not-found: invalid app pid \(rawPid).\n", stderr)
    exit(2)
}

if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
   let locked = session["CGSSessionScreenIsLocked"] as? Bool,
   locked {
    fputs("locked-session: macOS session is locked; refusing UI evidence.\n", stderr)
    exit(6)
}

guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    fputs("tool-layer-unknown: unable to read window list.\n", stderr)
    exit(3)
}

let matches = windows.compactMap { window -> UInt32? in
    guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
    guard let pid = window[kCGWindowOwnerPID as String] as? Int32, pid == expectedPid else { return nil }
    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width > 0,
          height > 0 else {
        return nil
    }
    return window[kCGWindowNumber as String] as? UInt32
}

if matches.isEmpty {
    fputs("window-not-found: No visible SkillsCopilot app window found for pid \(expectedPid).\n", stderr)
    exit(1)
}
if matches.count > 1 {
    let ids = matches.map(String.init).joined(separator: ",")
    fputs("window-not-found: multiple visible SkillsCopilot windows create window ambiguity for pid \(expectedPid): \(ids)\n", stderr)
    exit(1)
}
print(matches[0])
' "$pid" 2>&1)"; then
      status=0
      printf '%s\n' "$output"
      return 0
    else
      status=$?
    fi
    if [[ "$output" == locked-session:* || "$output" == tool-layer-unknown:* || "$output" == *"multiple visible"* ]]; then
      echo "$output" >&2
      return "$status"
    fi
    sleep 0.25
  done
  echo "${output:-window-not-found: timed out waiting for visible $APP_NAME window for pid $pid}" >&2
  return 1
}

terminate_existing_app_instances

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
  LAUNCHED_PID="$(wait_for_current_bundle_process)"
  activate_current_app "$LAUNCHED_PID"
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
    wait_for_visible_window "$LAUNCHED_PID" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
