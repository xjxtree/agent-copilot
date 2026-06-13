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

if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
   let locked = session["CGSSessionScreenIsLocked"] as? Bool,
   locked {
    fputs("locked-session: macOS session is locked; refusing to create screenshot evidence.\n", stderr)
    exit(6)
}

guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    fputs("Unable to read window list.\n", stderr)
    exit(2)
}

func validateImage(_ image: CGImage, expectedWidth: Double, expectedHeight: Double) -> Bool {
    guard image.width > 0, image.height > 0 else {
        fputs("invalid-capture: image has zero dimensions.\n", stderr)
        return false
    }

    let minExpectedWidth = max(1.0, expectedWidth * 0.45)
    let minExpectedHeight = max(1.0, expectedHeight * 0.45)
    if Double(image.width) < minExpectedWidth || Double(image.height) < minExpectedHeight {
        fputs("invalid-capture: image dimensions are too small for the captured window.\n", stderr)
        return false
    }

    let sampleWidth = min(image.width, 96)
    let sampleHeight = min(image.height, 96)
    let bytesPerPixel = 4
    let bytesPerRow = sampleWidth * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)
    guard let context = CGContext(
        data: &pixels,
        width: sampleWidth,
        height: sampleHeight,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("invalid-capture: unable to create validation context.\n", stderr)
        return false
    }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

    var brightnessSum = 0.0
    var brightnessSquaredSum = 0.0
    var opaqueSamples = 0
    let sampleCount = sampleWidth * sampleHeight
    for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
        let alpha = Double(pixels[index + 3]) / 255.0
        if alpha > 0.08 {
            opaqueSamples += 1
        }
        let brightness = (0.2126 * Double(pixels[index]) + 0.7152 * Double(pixels[index + 1]) + 0.0722 * Double(pixels[index + 2])) / 255.0
        brightnessSum += brightness
        brightnessSquaredSum += brightness * brightness
    }

    let opaqueRatio = Double(opaqueSamples) / Double(sampleCount)
    let mean = brightnessSum / Double(sampleCount)
    let variance = max(0, brightnessSquaredSum / Double(sampleCount) - mean * mean)

    if opaqueRatio < 0.2 {
        fputs("invalid-capture: screenshot is mostly transparent.\n", stderr)
        return false
    }
    if mean < 0.025 {
        fputs("black-capture: screenshot is near black; refusing evidence.\n", stderr)
        return false
    }
    if variance < 0.000015 {
        fputs("flat-capture: screenshot has near-zero visual variance; refusing evidence.\n", stderr)
        return false
    }
    return true
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

    guard validateImage(image, expectedWidth: width, expectedHeight: height) else {
        exit(7)
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
