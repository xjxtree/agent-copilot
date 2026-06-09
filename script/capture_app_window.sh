#!/usr/bin/env bash
set -euo pipefail

APP_OWNER="${1:-SkillsCopilot}"
OUTPUT_PATH="${2:-docs/ui-artifacts/native-macos-shell/completed.png}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ABS="$OUTPUT_PATH"

if [[ "$OUTPUT_ABS" != /* ]]; then
  OUTPUT_ABS="$ROOT_DIR/$OUTPUT_PATH"
fi

mkdir -p "$(dirname "$OUTPUT_ABS")"

swift -Xfrontend -disable-availability-checking -e '
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments.dropFirst()
let owner = args.first ?? "SkillsCopilot"
let outputPath = args.dropFirst().first ?? "completed.png"

guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    fputs("Unable to read window list.\n", stderr)
    exit(2)
}

for window in windows {
    guard (window[kCGWindowOwnerName as String] as? String) == owner else { continue }
    guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
    guard let id = window[kCGWindowNumber as String] as? UInt32 else { continue }
    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width > 0,
          height > 0 else {
        continue
    }

    guard let image = CGWindowListCreateImage(
        .null,
        .optionIncludingWindow,
        CGWindowID(id),
        [.boundsIgnoreFraming, .bestResolution]
    ) else {
        fputs("Unable to create image for \(owner) window \(id).\n", stderr)
        exit(3)
    }

    let url = URL(fileURLWithPath: outputPath) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(
        url,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fputs("Unable to create image destination: \(outputPath)\n", stderr)
        exit(4)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fputs("Unable to finalize image: \(outputPath)\n", stderr)
        exit(5)
    }
    print("Captured \(owner) window \(id) (\(Int(width))x\(Int(height))) -> \(outputPath)")
    exit(0)
}

fputs("No visible \(owner) app window found.\n", stderr)
exit(1)
' "$APP_OWNER" "$OUTPUT_ABS"

file "$OUTPUT_ABS"
