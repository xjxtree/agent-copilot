import Foundation
import SwiftUI

struct TaskInputModel: Equatable {
    let rawText: String

    init(rawText: String) {
        self.rawText = rawText
    }

    var trimmedText: String {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !trimmedText.isEmpty
    }

    var submissionText: String? {
        canSubmit ? rawText : nil
    }

    var lineCount: Int {
        var count = 1
        var previousWasCarriageReturn = false

        for scalar in rawText.unicodeScalars {
            if scalar == "\r" {
                count += 1
                previousWasCarriageReturn = true
            } else if scalar == "\n" {
                if !previousWasCarriageReturn {
                    count += 1
                }
                previousWasCarriageReturn = false
            } else {
                previousWasCarriageReturn = false
            }
        }

        return max(1, count)
    }

    var isMultiline: Bool {
        lineCount > 1
    }
}

struct TaskInputTextEditor: View {
    @Binding var text: String
    let placeholder: String

    static let minHeight: CGFloat = 72
    static let idealHeight: CGFloat = 96
    static let maxHeight: CGFloat = 132

    private var inputModel: TaskInputModel {
        TaskInputModel(rawText: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.callout)
                .lineSpacing(2)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
                .frame(
                    minHeight: Self.minHeight,
                    idealHeight: Self.idealHeight,
                    maxHeight: Self.maxHeight
                )
                .accessibilityIdentifier(AppAccessibilityID.taskCockpitInput)
                .accessibilityLabel(placeholder)

            HStack(spacing: 6) {
                Label(statusText, systemImage: statusSystemImage)
                    .font(.caption)
                    .foregroundStyle(statusForegroundStyle)
                Spacer(minLength: 8)
                if inputModel.isMultiline {
                    Image(systemName: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Multiline task input")
                }
            }
            .frame(minHeight: 16, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AppAccessibilityID.taskCockpitInputStatus)
            .accessibilityLabel(statusText)
            .accessibilityValue(statusText)
        }
    }

    private var statusText: String {
        inputModel.canSubmit ? UIStrings.taskCockpitInputReady : UIStrings.taskCockpitTaskRequired
    }

    private var statusSystemImage: String {
        inputModel.canSubmit ? "checkmark.circle" : "exclamationmark.circle"
    }

    private var statusForegroundStyle: AnyShapeStyle {
        inputModel.canSubmit ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange)
    }

}
