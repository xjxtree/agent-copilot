#!/usr/bin/env bash
set -euo pipefail

APP_TARGET="${1:-AgentCopilot}"
OUTPUT_PATH="${2:-docs/ui-artifacts/native-macos-shell/completed.png}"
TARGET_PID="${SKILLS_COPILOT_TARGET_PID:-${3:-}}"
TARGET_WINDOW_ID="${SKILLS_COPILOT_TARGET_WINDOW_ID:-${4:-}}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_APP_BUNDLE="$ROOT_DIR/dist/AgentCopilot.app"
TARGET_BUNDLE_PATH="${SKILLS_COPILOT_APP:-}"
APP_OWNER="$APP_TARGET"
OUTPUT_ABS="$OUTPUT_PATH"

if [[ "$APP_TARGET" == *.app ]]; then
  TARGET_BUNDLE_PATH="$APP_TARGET"
  APP_OWNER="$(basename "$APP_TARGET" .app)"
fi

if [[ -z "$TARGET_BUNDLE_PATH" && -d "$DEFAULT_APP_BUNDLE" ]]; then
  TARGET_BUNDLE_PATH="$DEFAULT_APP_BUNDLE"
fi

if [[ -n "$TARGET_BUNDLE_PATH" && "$TARGET_BUNDLE_PATH" != /* ]]; then
  TARGET_BUNDLE_PATH="$ROOT_DIR/$TARGET_BUNDLE_PATH"
fi

if [[ -n "$TARGET_BUNDLE_PATH" && -d "$TARGET_BUNDLE_PATH" ]]; then
  TARGET_BUNDLE_PATH="$(cd "$TARGET_BUNDLE_PATH" && pwd -P)"
fi

if [[ "$OUTPUT_ABS" != /* ]]; then
  OUTPUT_ABS="$ROOT_DIR/$OUTPUT_PATH"
fi

mkdir -p "$(dirname "$OUTPUT_ABS")"

swift -Xfrontend -disable-availability-checking -e '
import AppKit
import CoreGraphics
import Foundation
import ImageIO

let args = Array(CommandLine.arguments.dropFirst())
let owner = args.indices.contains(0) && !args[0].isEmpty ? args[0] : "AgentCopilot"
let outputPath = args.indices.contains(1) && !args[1].isEmpty ? args[1] : "completed.png"
let targetPid = args.indices.contains(2) && !args[2].isEmpty ? Int32(args[2]) : nil
let targetBundlePath = args.indices.contains(3) && !args[3].isEmpty
    ? URL(fileURLWithPath: args[3]).resolvingSymlinksInPath().standardizedFileURL.path
    : nil
let targetWindowId = args.indices.contains(4) && !args[4].isEmpty ? UInt32(args[4]) : nil

if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
   let locked = session["CGSSessionScreenIsLocked"] as? Bool,
   locked {
    fputs("locked-session: macOS session is locked; refusing to create screenshot evidence.\n", stderr)
    exit(6)
}

guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    fputs("tool-layer-unknown: unable to read window list.\n", stderr)
    exit(2)
}

struct WindowCandidate {
    let id: UInt32
    let pid: pid_t
    let ownerName: String
    let width: Double
    let height: Double
    let bundlePath: String?
}

func runningBundlePath(pid: pid_t) -> String? {
    NSRunningApplication(processIdentifier: pid)?
        .bundleURL?
        .resolvingSymlinksInPath()
        .standardizedFileURL
        .path
}

func describe(_ candidate: WindowCandidate) -> String {
    let bundle = candidate.bundlePath ?? "<unknown-bundle>"
    return "window=\(candidate.id) pid=\(candidate.pid) bundle=\(bundle)"
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
        fputs("transparent-capture: screenshot is mostly transparent.\n", stderr)
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

func captureWindowWithScreencapture(windowId: UInt32, outputPath: String) -> Bool {
    let captureTool = "/usr/sbin/screencapture"
    guard FileManager.default.isExecutableFile(atPath: captureTool) else {
        fputs("tool-layer-unknown: screencapture is not executable at \(captureTool).\n", stderr)
        exit(2)
    }

    try? FileManager.default.removeItem(atPath: outputPath)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: captureTool)
    process.arguments = ["-l", String(windowId), "-o", "-x", outputPath]
    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        fputs("tool-layer-unknown: unable to launch screencapture: \(error).\n", stderr)
        exit(2)
    }
    process.waitUntilExit()

    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrText = String(data: stderrData, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard process.terminationStatus == 0 else {
        let detail = stderrText.isEmpty ? "" : ": \(stderrText)"
        fputs("screen-recording-permission: screencapture -l failed for window \(windowId) with status \(process.terminationStatus)\(detail).\n", stderr)
        return false
    }

    guard FileManager.default.fileExists(atPath: outputPath) else {
        fputs("invalid-capture: screencapture did not create output: \(outputPath)\n", stderr)
        return false
    }
    return true
}

let candidates: [WindowCandidate] = windows.compactMap { window in
    guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
    guard let id = window[kCGWindowNumber as String] as? UInt32 else { return nil }
    guard let pidValue = window[kCGWindowOwnerPID as String] as? Int32 else { return nil }
    guard let ownerName = window[kCGWindowOwnerName as String] as? String else { return nil }
    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width > 0,
          height > 0 else {
        return nil
    }

    let pid = pid_t(pidValue)
    let bundlePath = runningBundlePath(pid: pid)
    let ownerMatches = ownerName == owner
    let pidMatches = targetPid.map { pid == pid_t($0) } ?? false
    let bundleMatches = targetBundlePath.map { bundlePath == $0 } ?? false
    let windowMatches = targetWindowId.map { id == $0 } ?? false
    guard ownerMatches || pidMatches || bundleMatches || windowMatches else { return nil }

    return WindowCandidate(
        id: id,
        pid: pid,
        ownerName: ownerName,
        width: width,
        height: height,
        bundlePath: bundlePath
    )
}

let ownerWindows = candidates.filter { $0.ownerName == owner }
let staleWindows = ownerWindows.filter { candidate in
    guard let targetBundlePath else { return false }
    guard let bundlePath = candidate.bundlePath else { return true }
    return bundlePath != targetBundlePath
}

let matches: [WindowCandidate]
if let targetWindowId {
    matches = candidates.filter { $0.id == targetWindowId }
} else if let targetPid {
    matches = candidates.filter { $0.pid == pid_t(targetPid) }
} else if let targetBundlePath {
    matches = ownerWindows.filter { $0.bundlePath == targetBundlePath }
} else {
    matches = ownerWindows
}

if matches.isEmpty {
    if !staleWindows.isEmpty {
        let examples = staleWindows.prefix(3).map(describe).joined(separator: "; ")
        fputs("stale-bundle: visible \(owner) windows are running from different bundle path than target \(targetBundlePath ?? "<unset>"): \(examples)\n", stderr)
        exit(8)
    }
    let target = targetWindowId.map { "window \($0)" } ??
        targetPid.map { "pid \($0)" } ??
        targetBundlePath.map { "bundle \($0)" } ??
        owner
    fputs("window-not-found: No visible \(owner) app window found for \(target).\n", stderr)
    exit(1)
}

if matches.count > 1 {
    let examples = matches.prefix(5).map(describe).joined(separator: "; ")
    fputs("window-not-found: multiple visible \(owner) windows create window ambiguity: \(examples)\n", stderr)
    exit(1)
}

if !staleWindows.isEmpty && targetPid == nil && targetWindowId == nil {
    let examples = staleWindows.prefix(3).map(describe).joined(separator: "; ")
    fputs("stale-bundle: visible \(owner) windows include stale same-bundle instances while no exact PID/window was provided: \(examples)\n", stderr)
    exit(8)
}

let target = matches[0]

guard captureWindowWithScreencapture(windowId: target.id, outputPath: outputPath) else {
    exit(3)
}

let url = URL(fileURLWithPath: outputPath) as CFURL
guard let source = CGImageSourceCreateWithURL(url, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("invalid-capture: unable to read captured image: \(outputPath)\n", stderr)
    exit(4)
}

guard validateImage(image, expectedWidth: target.width, expectedHeight: target.height) else {
    exit(7)
}
print("Captured \(owner) window \(target.id) pid \(target.pid) via screencapture -l (\(Int(target.width))x\(Int(target.height))) -> \(outputPath)")
exit(0)
' "$APP_OWNER" "$OUTPUT_ABS" "$TARGET_PID" "$TARGET_BUNDLE_PATH" "$TARGET_WINDOW_ID"

file "$OUTPUT_ABS"
