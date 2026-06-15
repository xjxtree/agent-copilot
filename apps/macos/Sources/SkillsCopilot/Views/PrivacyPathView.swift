import SwiftUI

struct PrivacyPathRow: View {
    let label: String
    let path: String
    @AppStorage(DisplayText.screenshotPrivacyModeStorageKey) private var privacyModeEnabled = true
    @State private var revealFullPath = false

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            PrivacyPathValue(path: path, privacyModeEnabled: privacyModeEnabled, revealFullPath: $revealFullPath)
        }
    }
}

struct PrivacyPathText: View {
    let path: String
    var font: Font = .caption
    var lineLimit: Int = 2
    @AppStorage(DisplayText.screenshotPrivacyModeStorageKey) private var privacyModeEnabled = true
    @State private var revealFullPath = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(DisplayText.privacyPath(path, privacyModeEnabled: privacyModeEnabled, revealFull: revealFullPath))
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .textSelection(.enabled)

            if shouldShowRevealControl {
                Button {
                    revealFullPath.toggle()
                } label: {
                    Image(systemName: revealFullPath ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(revealFullPath ? UIStrings.privacyHidePath : UIStrings.privacyRevealPath)
            }
        }
    }

    private var shouldShowRevealControl: Bool {
        DisplayText.isLikelyPath(path) && (privacyModeEnabled || DisplayText.privacyPath(path, privacyModeEnabled: false) != path)
    }
}

struct PrivacyEvidenceText: View {
    let value: String
    var font: Font = .caption
    var lineLimit: Int? = 2

    var body: some View {
        if DisplayText.isLikelyPath(value) {
            PrivacyPathText(path: value, font: font, lineLimit: lineLimit ?? 2)
        } else {
            Text(value)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .textSelection(.enabled)
        }
    }
}

struct PrivacyEvidenceLabel: View {
    let value: String
    let systemImage: String
    var font: Font = .caption
    var lineLimit: Int? = 2

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(font)
                .foregroundStyle(.secondary)
                .frame(width: 13, alignment: .center)
            PrivacyEvidenceText(value: value, font: font, lineLimit: lineLimit)
        }
    }
}

struct PrivacyPathLabel: View {
    let path: String
    let systemImage: String
    @AppStorage(DisplayText.screenshotPrivacyModeStorageKey) private var privacyModeEnabled = true

    var body: some View {
        Label(DisplayText.privacyPath(path, privacyModeEnabled: privacyModeEnabled), systemImage: systemImage)
    }
}

private struct PrivacyPathValue: View {
    let path: String
    let privacyModeEnabled: Bool
    @Binding var revealFullPath: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(DisplayText.privacyPath(path, privacyModeEnabled: privacyModeEnabled, revealFull: revealFullPath))
                .textSelection(.enabled)
                .lineLimit(3)

            if shouldShowRevealControl {
                Button {
                    revealFullPath.toggle()
                } label: {
                    Label(revealFullPath ? UIStrings.privacyHidePath : UIStrings.privacyRevealPath, systemImage: revealFullPath ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
            }

            if shouldShowRevealControl && privacyModeEnabled && !revealFullPath {
                Label(UIStrings.privacyScreenshotSafe, systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shouldShowRevealControl: Bool {
        DisplayText.isLikelyPath(path) && (privacyModeEnabled || DisplayText.privacyPath(path, privacyModeEnabled: false) != path)
    }
}
