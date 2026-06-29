import Foundation

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
