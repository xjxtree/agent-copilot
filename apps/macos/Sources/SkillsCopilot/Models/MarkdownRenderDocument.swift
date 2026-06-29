import Foundation

enum MarkdownRenderBlock {
    case heading(level: Int, String)
    case paragraph(String)
    case bullet(String)
    case numbered(marker: String, String)
    case quote(String)
    case table([[String]])
    case rule
    case code(String)
}

struct MarkdownRenderDocument {
    let blocks: [MarkdownRenderBlock]
    let isTruncated: Bool

    init(text: String, maxBlocks: Int?) {
        let parsedBlocks = Self.parse(text: Self.renderableText(from: text))
        if let maxBlocks, parsedBlocks.count > maxBlocks {
            self.blocks = Array(parsedBlocks.prefix(maxBlocks))
            self.isTruncated = true
        } else {
            self.blocks = parsedBlocks
            self.isTruncated = false
        }
    }

    static func renderableText(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return text }
        let lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 3,
              let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              firstLine.hasPrefix("```"),
              lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```"
        else { return text }

        let language = firstLine
            .dropFirst(3)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let bodyLines = lines.dropFirst().dropLast()
        let body = bodyLines.joined(separator: "\n")
        let isMarkdownFence = ["markdown", "md", "gfm"].contains(language)
        let looksLikeMarkdown = body.contains("|")
            || body.contains("\n#")
            || body.contains("\n- ")
            || body.contains("\n* ")
            || body.hasPrefix("#")
            || body.hasPrefix("- ")
            || body.hasPrefix("* ")

        guard isMarkdownFence || (language.isEmpty && looksLikeMarkdown) else {
            return text
        }
        guard !bodyLines.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") }) else {
            return text
        }
        return body
    }

    private static func parse(text: String) -> [MarkdownRenderBlock] {
        let lines = normalizeMarkdownBlocks(in: text).components(separatedBy: "\n")
        var blocks: [MarkdownRenderBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var tableRows: [[String]] = []
        var isInCodeBlock = false

        func flushParagraph() {
            let paragraph = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph))
            }
            paragraphLines.removeAll()
        }

        func flushTable() {
            guard !tableRows.isEmpty else { return }
            blocks.append(.table(tableRows))
            tableRows.removeAll()
        }

        func flushCodeBlock() {
            blocks.append(.code(codeLines.joined(separator: "\n")))
            codeLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    flushCodeBlock()
                    isInCodeBlock = false
                } else {
                    flushParagraph()
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
                continue
            }

            guard !trimmed.isEmpty else {
                flushParagraph()
                flushTable()
                continue
            }

            if let tableRow = tableRow(from: trimmed) {
                flushParagraph()
                tableRows.append(tableRow)
            } else if isTableSeparator(trimmed) {
                continue
            } else if let heading = headingBlock(from: trimmed) {
                flushTable()
                flushParagraph()
                blocks.append(heading)
            } else if isRule(trimmed) {
                flushTable()
                flushParagraph()
                blocks.append(.rule)
            } else if let bullet = bulletBlock(from: trimmed) {
                flushTable()
                flushParagraph()
                blocks.append(bullet)
            } else if let numbered = numberedBlock(from: trimmed) {
                flushTable()
                flushParagraph()
                blocks.append(numbered)
            } else if let quote = quoteBlock(from: trimmed) {
                flushTable()
                flushParagraph()
                blocks.append(quote)
            } else {
                flushTable()
                paragraphLines.append(line)
            }
        }

        if isInCodeBlock {
            flushCodeBlock()
        }
        flushTable()
        flushParagraph()
        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }

    private static func normalizeMarkdownBlocks(in text: String) -> String {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        return normalized
            .components(separatedBy: "\n")
            .map { line in
                normalizeInlineMarkdownBreaks(in: line)
            }
            .joined(separator: "\n")
    }

    private static func normalizeInlineMarkdownBreaks(in text: String) -> String {
        if isStandaloneTableLine(text) {
            return text
        }
        var normalized = text
        for marker in [" --- ", " *** ", " ___ "] {
            normalized = normalized.replacingOccurrences(of: marker, with: "\n\(marker.trimmingCharacters(in: .whitespaces))\n")
        }

        let headingMarkers = [
            " ###### ",
            " ##### ",
            " #### ",
            " ### ",
            " ## ",
            " # "
        ]
        for marker in headingMarkers {
            normalized = normalized.replacingOccurrences(of: marker, with: "\n\(marker.trimmingCharacters(in: .whitespaces)) ")
        }

        normalized = normalized.replacingOccurrences(of: " - ", with: "\n- ")
        normalized = normalized.replacingOccurrences(of: " * ", with: "\n* ")
        normalized = normalized.replacingOccurrences(of: " + ", with: "\n+ ")
        for index in 1...20 {
            normalized = normalized.replacingOccurrences(of: " \(index). ", with: "\n\(index). ")
        }

        return normalized
            .components(separatedBy: "\n")
            .map { normalizeInlineTableRows(in: $0) }
            .joined(separator: "\n")
    }

    private static func normalizeInlineTableRows(in text: String) -> String {
        let pipeCount = text.filter { $0 == "|" }.count
        guard pipeCount >= 4 else { return text }

        var normalized = text
        normalized = normalized.replacingOccurrences(of: " | |", with: " |\n|")
        normalized = normalized.replacingOccurrences(of: "| |", with: "|\n|")

        let boundaryMarkers = [
            (" | ###### ", " |\n###### "),
            (" | ##### ", " |\n##### "),
            (" | #### ", " |\n#### "),
            (" | ### ", " |\n### "),
            (" | ## ", " |\n## "),
            (" | # ", " |\n# "),
            (" | - ", " |\n- "),
            (" | * ", " |\n* "),
            (" | + ", " |\n+ "),
        ]
        for (marker, replacement) in boundaryMarkers {
            normalized = normalized.replacingOccurrences(of: marker, with: replacement)
        }

        guard let firstPipe = normalized.firstIndex(of: "|") else {
            return normalized
        }
        let prefix = normalized[..<firstPipe].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else {
            return normalized
        }
        let tableStart = normalized[firstPipe...]
        guard tableStart.dropFirst().contains("|") else {
            return normalized
        }
        return "\(prefix)\n\(tableStart)"
    }

    private static func isStandaloneTableLine(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("|"),
              trimmed.hasSuffix("|"),
              trimmed.filter({ $0 == "|" }).count >= 3
        else { return false }
        return !trimmed.contains(" | |")
    }

    private static func headingBlock(from trimmed: String) -> MarkdownRenderBlock? {
        let hashes = trimmed.prefix { $0 == "#" }.count
        guard hashes > 0, hashes <= 6 else { return nil }
        let markerEnd = trimmed.index(trimmed.startIndex, offsetBy: hashes)
        guard markerEnd < trimmed.endIndex, trimmed[markerEnd] == " " else { return nil }
        let contentStart = trimmed.index(after: markerEnd)
        let content = String(trimmed[contentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return .heading(level: hashes, content)
    }

    private static func bulletBlock(from trimmed: String) -> MarkdownRenderBlock? {
        for marker in ["- ", "* ", "+ ", "• "] where trimmed.hasPrefix(marker) {
            let content = String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : .bullet(content)
        }
        return nil
    }

    private static func numberedBlock(from trimmed: String) -> MarkdownRenderBlock? {
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let number = String(trimmed[..<dotIndex])
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let contentStart = trimmed.index(after: dotIndex)
        guard contentStart < trimmed.endIndex, trimmed[contentStart] == " " else { return nil }
        let content = String(trimmed[trimmed.index(after: contentStart)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return .numbered(marker: "\(number).", content)
    }

    private static func quoteBlock(from trimmed: String) -> MarkdownRenderBlock? {
        guard trimmed.hasPrefix(">") else { return nil }
        let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return .quote(content)
    }

    private static func tableRow(from trimmed: String) -> [String]? {
        guard trimmed.contains("|"),
              !isTableSeparator(trimmed)
        else { return nil }
        let cells = trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard cells.count >= 2 else { return nil }
        return cells
    }

    private static func isTableSeparator(_ trimmed: String) -> Bool {
        guard trimmed.contains("|") else { return false }
        let stripped = trimmed
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty
    }

    private static func isRule(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let characters = Set(trimmed)
        return characters == ["-"] || characters == ["*"] || characters == ["_"]
    }
}
