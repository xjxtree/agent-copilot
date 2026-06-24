import AppKit
import SwiftUI

struct SkillAnalysisPreparePanel: View {
    let result: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMSkillAnalysisPrepareResult?
    let isPreparing: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let promptPreview: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMPromptPreview?
    let isPreviewingPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let isSendingPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let promptSendResult: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMPromptSendResult?
    let canSendPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let onPreviewPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void
    let onSendPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void
    let onPrepare: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.llmSkillAnalysis, systemImage: "sparkles.square.filled.on.square")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmSkillAnalysisSafetyTitle, systemImage: "checkmark.shield")
                .font(.subheadline.bold())
            Text(UIStrings.llmSkillAnalysisSafetyCopy)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(LLMSkillAnalysisKind.allCases) { kind in
                    Button {
                        onPrepare(kind, .selected)
                    } label: {
                        Label("\(UIStrings.llmSkillAnalysisPrepareSelected) \(kind.title)", systemImage: kind.systemImage)
                    }
                    .disabled(isPreparing(kind, .selected))
                    .help(UIStrings.llmSkillAnalysisSafetyCopy)
                }
            }

            HStack(spacing: 8) {
                Button {
                    onPrepare(.overview, .visible)
                } label: {
                    Label(UIStrings.llmSkillAnalysisPrepareVisible, systemImage: "rectangle.grid.2x2")
                }
                .disabled(isPreparing(.overview, .visible))
                .help(UIStrings.llmSkillAnalysisSafetyCopy)
            }

            ForEach(LLMSkillAnalysisKind.allCases) { kind in
                if isPreparing(kind, .selected) {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                } else if let result = result(kind, .selected) {
                    SkillAnalysisPrepareResultView(
                        result: result,
                        scope: .selected,
                        promptPreview: promptPreview(kind, .selected),
                        isPreviewingPrompt: isPreviewingPrompt(kind, .selected),
                        isSendingPrompt: isSendingPrompt(kind, .selected),
                        promptSendResult: promptSendResult(kind, .selected),
                        canSendPrompt: canSendPrompt(kind, .selected),
                        onPreviewPrompt: { onPreviewPrompt(kind, .selected) },
                        onSendPrompt: { onSendPrompt(kind, .selected) }
                    )
                }
            }

            if isPreparing(.overview, .visible) {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            } else if let result = result(.overview, .visible) {
                SkillAnalysisPrepareResultView(
                    result: result,
                    scope: .visible,
                    promptPreview: promptPreview(.overview, .visible),
                    isPreviewingPrompt: isPreviewingPrompt(.overview, .visible),
                    isSendingPrompt: isSendingPrompt(.overview, .visible),
                    promptSendResult: promptSendResult(.overview, .visible),
                    canSendPrompt: canSendPrompt(.overview, .visible),
                    onPreviewPrompt: { onPreviewPrompt(.overview, .visible) },
                    onSendPrompt: { onSendPrompt(.overview, .visible) }
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

struct SkillAnalysisPrepareResultView: View {
    let result: LLMSkillAnalysisPrepareResult
    let scope: LLMSkillAnalysisRequestScope
    let promptPreview: LLMPromptPreview?
    let isPreviewingPrompt: Bool
    let isSendingPrompt: Bool
    let promptSendResult: LLMPromptSendResult?
    let canSendPrompt: Bool
    let onPreviewPrompt: () -> Void
    let onSendPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(scope.title) · \(result.analysisKind.title)", systemImage: result.enabled ? "doc.text.magnifyingglass" : "nosign")
                .font(.subheadline.bold())
                .foregroundStyle(result.enabled ? .primary : .secondary)

            if let reason = result.disabledReason, !reason.isEmpty {
                Text(reason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.skills, value: String(result.selectedSkillCount))
                MetadataRow(label: UIStrings.llmSkillAnalysisExcludedMissing, value: "\(result.excludedCount) / \(result.missingCount)")
                MetadataRow(label: UIStrings.llmSkillAnalysisWriteBack, value: safetyValue(result.safety.writeBackEnabled, safeText: UIStrings.llmSkillAnalysisBlocked))
                MetadataRow(label: UIStrings.llmSkillAnalysisScriptExecution, value: safetyValue(result.safety.scriptExecutionEnabled, safeText: UIStrings.llmSkillAnalysisBlocked))
                MetadataRow(label: UIStrings.llmSkillAnalysisCredentialStorage, value: safetyValue(result.safety.credentialStorageEnabled, safeText: UIStrings.llmSkillAnalysisBlocked))
                MetadataRow(label: UIStrings.llmSkillAnalysisConfirmation, value: result.safety.confirmationRequired ? UIStrings.llmSkillAnalysisRequired : UIStrings.unknown)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(UIStrings.llmSkillAnalysisIncludedSkills)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(includedSkillsText)
                    .font(.callout)
                    .foregroundStyle(result.includedSkills.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
            }

            DraftTextBlock(title: UIStrings.llmSkillAnalysisSummaryDraft, text: result.summaryDraft)
            DraftTextBlock(title: UIStrings.llmSkillAnalysisPromptDraft, text: result.promptDraft)

            PromptPreviewControls(
                preview: promptPreview,
                sendResult: promptSendResult,
                isPreviewing: isPreviewingPrompt,
                isSending: isSendingPrompt,
                canSend: canSendPrompt,
                onPreview: onPreviewPrompt,
                onSend: onSendPrompt
            )

            Label(UIStrings.llmSkillAnalysisSafetyCopy, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var includedSkillsText: String {
        guard !result.includedSkills.isEmpty else { return UIStrings.llmSkillAnalysisNoIncludedSkills }
        return result.includedSkills.map { skill in
            "\(skill.name) (\(DisplayText.agent(skill.agent)))"
        }.joined(separator: ", ")
    }

    private func safetyValue(_ isEnabled: Bool, safeText: String) -> String {
        isEnabled ? UIStrings.llmSkillAnalysisEnabledUnsafe : safeText
    }
}

struct DraftTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        LongTextReviewBlock(
            title: title,
            text: text,
            emptyText: UIStrings.llmSkillAnalysisNoDraft,
            systemImage: "doc.on.doc"
        )
    }
}

enum LongTextRenderMode {
    case plain
    case markdown
}

struct LongTextReviewBlock: View {
    let title: String
    let text: String
    let emptyText: String
    let systemImage: String
    var renderMode: LongTextRenderMode = .markdown
    @State private var isShowingDetails = false

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayText: String {
        hasText ? text : emptyText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if hasText {
                    Button {
                        isShowingDetails = true
                    } label: {
                        Label(UIStrings.llmPromptViewDetails, systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Button {
                        copyToPasteboard(displayText)
                    } label: {
                        Label(UIStrings.llmPromptCopyFullText, systemImage: "doc.on.doc")
                    }
                }
            }
            RenderedLongText(
                text: displayText,
                renderMode: renderMode,
                isEmpty: !hasText,
                lineLimit: hasText ? 5 : nil
            )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
        .sheet(isPresented: $isShowingDetails) {
            LongTextDetailSheet(title: title, text: displayText, renderMode: renderMode)
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct LongTextDetailSheet: View {
    let title: String
    let text: String
    let renderMode: LongTextRenderMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label(UIStrings.llmPromptCopyFullText, systemImage: "doc.on.doc")
                }
                Button(UIStrings.llmPromptCloseDetails) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                RenderedLongText(
                    text: text,
                    renderMode: renderMode,
                    isEmpty: false,
                    lineLimit: nil
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .frame(minWidth: 680, minHeight: 460)
    }
}

struct RenderedLongText: View {
    let text: String
    let renderMode: LongTextRenderMode
    let isEmpty: Bool
    let lineLimit: Int?

    var body: some View {
        Group {
            if renderMode == .markdown {
                RenderedMarkdownDocument(
                    text: text,
                    isEmpty: isEmpty,
                    maxBlocks: lineLimit
                )
            } else {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(lineLimit)
            }
        }
        .foregroundStyle(isEmpty ? .secondary : .primary)
        .textSelection(.enabled)
    }
}

struct RenderedMarkdownDocument: View {
    let text: String
    let isEmpty: Bool
    let maxBlocks: Int?

    private var document: MarkdownRenderDocument {
        MarkdownRenderDocument(text: text, maxBlocks: maxBlocks)
    }

    private var compactTableRowLimit: Int? {
        maxBlocks == nil ? nil : 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
            if document.isTruncated {
                Text("...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(isEmpty ? .secondary : .primary)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownRenderBlock) -> some View {
        switch block {
        case let .heading(level, value):
            MarkdownInlineText(value, font: level <= 2 ? .headline : .subheadline.bold())
        case let .paragraph(value):
            MarkdownInlineText(value, font: .callout)
        case let .bullet(value):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•")
                    .font(.callout.bold())
                MarkdownInlineText(value, font: .callout)
            }
        case let .numbered(marker, value):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(marker)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                MarkdownInlineText(value, font: .callout)
            }
        case let .quote(value):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 3)
                MarkdownInlineText(value, font: .callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        case let .table(rows):
            if maxBlocks == nil {
                MarkdownTableView(rows: rows, maxRows: compactTableRowLimit)
            } else {
                MarkdownTableSummaryView(rows: rows)
            }
        case .rule:
            Divider()
        case let .code(value):
            MarkdownCodeBlockView(
                value: value,
                wrapsLines: maxBlocks != nil,
                lineLimit: maxBlocks == nil ? nil : 8
            )
        }
    }
}

struct MarkdownCodeBlockView: View {
    let value: String
    var wrapsLines = false
    var lineLimit: Int? = nil

    var body: some View {
        if wrapsLines {
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
        } else {
            ScrollView(.horizontal) {
                Text(value)
                    .font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(8)
            }
            .scrollIndicators(.automatic)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
        }
    }
}

struct MarkdownInlineText: View {
    let value: String
    let font: Font

    init(_ value: String, font: Font) {
        self.value = value
        self.font = font
    }

    var body: some View {
        if let attributed = try? AttributedString(markdown: value) {
            Text(attributed)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(value)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MarkdownTableDisplayModel {
    static let minimumColumnWidth: CGFloat = 120
    static let maximumColumnWidth: CGFloat = 280
    private static let approximateCharacterWidth: CGFloat = 7
    private static let horizontalPadding: CGFloat = 28

    let rows: [[String]]
    let maxVisibleRows: Int?

    var nonEmptyRows: [[String]] {
        rows.filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    var displayRows: [[String]] {
        guard let maxVisibleRows, nonEmptyRows.count > maxVisibleRows else {
            return nonEmptyRows
        }
        return Array(nonEmptyRows.prefix(maxVisibleRows))
    }

    var usesCardLayout: Bool {
        columnCount > 3 || (columnCount > 2 && containsLongBodyCell)
    }

    var headerRow: [String] {
        normalizedRow(nonEmptyRows.first ?? [])
    }

    var displayCardRows: [[String]] {
        let bodyRows = cardBodyRows
        guard let maxVisibleRows else {
            return bodyRows
        }
        let visibleBodyCount = max(1, maxVisibleRows - 1)
        return Array(bodyRows.prefix(visibleBodyCount))
    }

    var hiddenRowCount: Int {
        if usesCardLayout {
            return max(0, cardBodyRows.count - displayCardRows.count)
        }
        return max(0, nonEmptyRows.count - displayRows.count)
    }

    var bodyRowCount: Int {
        cardBodyRows.count
    }

    var columnCount: Int {
        max(nonEmptyRows.map(\.count).max() ?? 0, 1)
    }

    func normalizedRow(_ row: [String]) -> [String] {
        guard row.count < columnCount else { return row }
        return row + Array(repeating: "", count: columnCount - row.count)
    }

    func columnWidth(at columnIndex: Int) -> CGFloat {
        let maxWeight = nonEmptyRows
            .compactMap { row -> String? in
                guard columnIndex < row.count else { return nil }
                return row[columnIndex]
            }
            .map(Self.displayWeight)
            .max() ?? 0
        let clampedWeight = min(max(maxWeight, 12), 36)
        let estimatedWidth = CGFloat(clampedWeight) * Self.approximateCharacterWidth + Self.horizontalPadding
        return min(Self.maximumColumnWidth, max(Self.minimumColumnWidth, estimatedWidth))
    }

    func totalWidth(horizontalSpacing: CGFloat = 10) -> CGFloat {
        let columnsWidth = (0..<columnCount).reduce(CGFloat.zero) { partial, index in
            partial + columnWidth(at: index)
        }
        let spacingWidth = max(CGFloat(columnCount - 1), 0) * horizontalSpacing
        return columnsWidth + spacingWidth
    }

    private var cardBodyRows: [[String]] {
        let rows = nonEmptyRows
        guard rows.count > 1 else {
            return rows
        }
        return Array(rows.dropFirst())
    }

    private var containsLongBodyCell: Bool {
        cardBodyRows
            .flatMap { $0 }
            .contains { Self.displayWeight($0) > 48 }
    }

    private static func displayWeight(_ text: String) -> Int {
        text.reduce(0) { partial, character in
            let isASCII = character.unicodeScalars.allSatisfy { scalar in
                scalar.value < 128
            }
            return partial + (isASCII ? 1 : 2)
        }
    }
}

struct MarkdownTableView: View {
    let model: MarkdownTableDisplayModel

    init(rows: [[String]], maxRows: Int? = nil) {
        self.model = MarkdownTableDisplayModel(rows: rows, maxVisibleRows: maxRows)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.usesCardLayout {
                MarkdownTableCardList(model: model)
                    .padding(8)
            } else {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                        ForEach(Array(model.displayRows.enumerated()), id: \.offset) { rowIndex, row in
                            GridRow {
                                ForEach(Array(model.normalizedRow(row).enumerated()), id: \.offset) { columnIndex, value in
                                    MarkdownInlineText(
                                        value.isEmpty ? " " : value,
                                        font: rowIndex == 0 ? .caption.bold() : .caption
                                    )
                                    .frame(width: model.columnWidth(at: columnIndex), alignment: .leading)
                                    .padding(.vertical, 3)
                                }
                            }
                            if rowIndex == 0 && model.displayRows.count > 1 {
                                Divider()
                                    .gridCellColumns(model.columnCount)
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(8)
                }
                .scrollIndicators(.automatic)
            }

            if model.hiddenRowCount > 0 {
                Text(UIStrings.markdownTableHiddenRows(model.hiddenRowCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct MarkdownTableSummaryView: View {
    let model: MarkdownTableDisplayModel

    init(rows: [[String]]) {
        self.model = MarkdownTableDisplayModel(rows: rows, maxVisibleRows: nil)
    }

    var body: some View {
        Label(
            UIStrings.markdownTablePreviewSummary,
            systemImage: "tablecells"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct MarkdownTableCardList: View {
    let model: MarkdownTableDisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(model.displayCardRows.enumerated()), id: \.offset) { _, row in
                MarkdownTableCard(row: model.normalizedRow(row), headers: model.headerRow)
            }
        }
    }
}

struct MarkdownTableCard: View {
    let row: [String]
    let headers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !titleText.isEmpty {
                MarkdownInlineText(titleText, font: .caption.bold())
            }

            ForEach(fieldRows, id: \.index) { field in
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.label)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    MarkdownInlineText(field.value, font: .caption)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
    }

    private var titleText: String {
        row.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var fieldRows: [MarkdownTableCardField] {
        row.enumerated().compactMap { index, value in
            guard index > 0 else { return nil }
            let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanValue.isEmpty else { return nil }
            return MarkdownTableCardField(
                index: index,
                label: headerLabel(at: index),
                value: cleanValue
            )
        }
    }

    private func headerLabel(at index: Int) -> String {
        guard index < headers.count else {
            return "#\(index + 1)"
        }
        let cleanHeader = headers[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanHeader.isEmpty ? "#\(index + 1)" : cleanHeader
    }
}

struct MarkdownTableCardField {
    let index: Int
    let label: String
    let value: String
}

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

extension LLMSkillAnalysisKind {
    var title: String {
        switch self {
        case .overview:
            return UIStrings.text("llm.skillAnalysis.kind.overview", "Overview")
        case .risk:
            return UIStrings.text("llm.skillAnalysis.kind.risk", "Risk")
        case .cleanup:
            return UIStrings.text("llm.skillAnalysis.kind.cleanup", "Cleanup")
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "text.magnifyingglass"
        case .risk:
            return "shield.lefthalf.filled"
        case .cleanup:
            return "sparkles"
        }
    }
}

struct LLMAssistPanel: View {
    let status: LLMStatus
    let isPreparing: (LLMAction) -> Bool
    let result: (LLMAction) -> LLMPrepareResult?
    let promptPreview: (LLMAction) -> LLMPromptPreview?
    let isPreviewingPrompt: (LLMAction) -> Bool
    let isSendingPrompt: (LLMAction) -> Bool
    let promptSendResult: (LLMAction) -> LLMPromptSendResult?
    let canSendPrompt: (LLMAction) -> Bool
    let onPreviewPrompt: (LLMAction) -> Void
    let onSendPrompt: (LLMAction) -> Void
    let onPrepare: (LLMAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.llmAssist, systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Label(
                    status.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled,
                    systemImage: status.enabled ? "checkmark.circle" : "nosign"
                )
                .font(.caption.bold())
                .foregroundStyle(status.enabled ? .green : .secondary)
            }

            if let disabledReason = status.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if status.enabled {
                Text(UIStrings.llmPreparePrompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(LLMAction.allCases) { action in
                    Button {
                        onPrepare(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .disabled(isPreparing(action))
                    .help(status.enabled ? action.title : UIStrings.llmReviewNoActions)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(LLMAction.allCases) { action in
                    if isPreparing(action) {
                        Label(UIStrings.llmPreparing, systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    } else if let result = result(action) {
                        LLMPrepareResultView(
                            result: result,
                            promptPreview: promptPreview(action),
                            isPreviewingPrompt: isPreviewingPrompt(action),
                            isSendingPrompt: isSendingPrompt(action),
                            promptSendResult: promptSendResult(action),
                            canSendPrompt: canSendPrompt(action),
                            onPreviewPrompt: { onPreviewPrompt(action) },
                            onSendPrompt: { onSendPrompt(action) }
                        )
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

struct LLMPrepareResultView: View {
    let result: LLMPrepareResult
    let promptPreview: LLMPromptPreview?
    let isPreviewingPrompt: Bool
    let isSendingPrompt: Bool
    let promptSendResult: LLMPromptSendResult?
    let canSendPrompt: Bool
    let onPreviewPrompt: () -> Void
    let onSendPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(result.action.title, systemImage: result.enabled ? "checkmark.circle" : "nosign")
                .font(.subheadline.bold())
                .foregroundStyle(result.enabled ? .primary : .secondary)

            if let disabledReason = result.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                if let provider = result.provider, !provider.isEmpty {
                    MetadataRow(label: UIStrings.llmProvider, value: provider)
                }
                if let model = result.model, !model.isEmpty {
                    MetadataRow(label: UIStrings.llmModel, value: model)
                }
                if let estimate = result.estimate {
                    MetadataRow(
                        label: UIStrings.llmTokens,
                        value: UIStrings.llmTokenSummary(
                            input: estimate.inputTokens,
                            output: estimate.outputTokens,
                            total: estimate.totalTokens
                        )
                    )
                    if let cost = estimate.estimatedCostUSD {
                        MetadataRow(label: UIStrings.llmCost, value: UIStrings.llmEstimatedCost(cost))
                    }
                }
            }

            if let reviewPreview = result.reviewPreview {
                LLMReviewPreviewView(preview: reviewPreview)
            }

            if result.confirmationRequired {
                Label(UIStrings.llmConfirmationRequired, systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if result.action == .draftFrontmatter {
                Label(UIStrings.llmDraftCopyRequired, systemImage: "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            PromptPreviewControls(
                preview: promptPreview,
                sendResult: promptSendResult,
                isPreviewing: isPreviewingPrompt,
                isSending: isSendingPrompt,
                canSend: canSendPrompt,
                onPreview: onPreviewPrompt,
                onSend: onSendPrompt
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct PromptPreviewControls: View {
    let preview: LLMPromptPreview?
    let sendResult: LLMPromptSendResult?
    let isPreviewing: Bool
    let isSending: Bool
    let canSend: Bool
    let onPreview: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.llmPromptPreviewAction, systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isPreviewing || isSending)

                Button {
                    onSend()
                } label: {
                    Label(UIStrings.llmPromptConfirmSend, systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend || isPreviewing || isSending)
                .help(canSend ? UIStrings.llmPromptConfirmSend : UIStrings.llmPromptProviderRequired)
            }

            if isPreviewing {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }

            if let preview {
                LLMPromptPreviewCard(preview: preview)
            } else {
                Label(UIStrings.llmPromptPreviewRequired, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if isSending {
                Label(UIStrings.llmPromptSending, systemImage: "network")
                    .foregroundStyle(.secondary)
            }

            if let sendResult {
                if let preview, sendResult.previewID == preview.previewID {
                    LLMPromptSendResultView(result: sendResult)
                } else {
                    LLMPromptSendResultView(result: sendResult, isHistorical: true)
                }
            }
        }
    }
}

struct LLMPromptPreviewCard: View {
    let preview: LLMPromptPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.llmPromptPreviewTitle, systemImage: preview.enabled ? "eye" : "nosign")
                .font(.caption.bold())
                .foregroundStyle(preview.enabled ? Color.secondary : Color.orange)

            if let disabledReason = preview.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.llmPromptScope, value: preview.promptScope)
                MetadataRow(label: UIStrings.llmProvider, value: preview.provider ?? UIStrings.unknown)
                MetadataRow(label: UIStrings.llmModel, value: preview.model ?? UIStrings.unknown)
                MetadataRow(label: UIStrings.llmPromptDestination, value: preview.destinationHost ?? UIStrings.unknown)
                if let estimate = preview.estimate {
                    MetadataRow(
                        label: UIStrings.llmTokens,
                        value: UIStrings.llmTokenSummary(
                            input: estimate.inputTokens,
                            output: estimate.outputTokens,
                            total: estimate.totalTokens
                        )
                    )
                    if let cost = estimate.estimatedCostUSD {
                        MetadataRow(label: UIStrings.llmCost, value: UIStrings.llmEstimatedCost(cost))
                    }
                }
                MetadataRow(label: UIStrings.llmSkillAnalysisConfirmation, value: preview.confirmationRequired ? UIStrings.llmSkillAnalysisRequired : UIStrings.unknown)
                MetadataRow(label: UIStrings.llmPromptRawPromptStored, value: preview.rawPromptPersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptRawResponseStored, value: preview.rawResponsePersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptCopyOnly, value: preview.draftCopyOnly ? UIStrings.llmEnabled : UIStrings.llmDisabled)
            }

            PromptFieldList(title: UIStrings.llmPromptIncludedFields, fields: preview.includedFields)
            PromptFieldList(title: UIStrings.llmPromptExcludedFields, fields: preview.excludedFields)
            RedactionSummaryView(redaction: preview.redaction)

            if let promptText = preview.promptPreview, !promptText.isEmpty {
                DraftTextBlock(title: UIStrings.llmPromptRedactedPrompt, text: promptText)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct PromptFieldList: View {
    let title: String
    let fields: [LLMPromptField]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if fields.isEmpty {
                Text(UIStrings.llmPromptNoFields)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fields) { field in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Label(field.label, systemImage: "checklist")
                            .font(.callout)
                        if let reason = field.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct RedactionSummaryView: View {
    let redaction: LLMPromptRedactionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(UIStrings.llmReviewRedaction)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(redaction.summary.isEmpty ? redaction.status : "\(redaction.status): \(redaction.summary)")
                .font(.callout)
                .foregroundStyle(.secondary)
            if !redaction.redactedFields.isEmpty {
                Text(redaction.redactedFields.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !redaction.placeholders.isEmpty {
                Text(redaction.placeholders.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            ForEach(redaction.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct LLMPromptSendResultView: View {
    let result: LLMPromptSendResult
    var isHistorical = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isHistorical {
                Label(UIStrings.llmPromptHistoricalResponse, systemImage: "clock.arrow.circlepath")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(resultTint)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.aiProviderTestResult, value: result.status)
                MetadataRow(label: UIStrings.llmPromptRawPromptStored, value: result.rawPromptPersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptRawResponseStored, value: result.rawResponsePersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptCopyOnly, value: result.draftCopyOnly ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmSkillAnalysisWriteBack, value: result.writeBackAllowed ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmSkillAnalysisBlocked)
                MetadataRow(label: UIStrings.llmSkillAnalysisScriptExecution, value: result.scriptExecutionAllowed ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmSkillAnalysisBlocked)
                if let audit = result.audit {
                    MetadataRow(label: UIStrings.aiProviderAuditMetadata, value: audit.auditID ?? UIStrings.unknown)
                    MetadataRow(label: UIStrings.aiProviderAuditRedaction, value: audit.redactionApplied ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                }
            }

            if let output = result.outputText, !output.isEmpty {
                Label(UIStrings.llmPromptHistoryNote, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LongTextReviewBlock(
                    title: UIStrings.llmPromptOutput,
                    text: output,
                    emptyText: UIStrings.llmSkillAnalysisNoDraft,
                    systemImage: "doc.on.doc",
                    renderMode: .markdown
                )
            } else if result.success {
                Label(UIStrings.llmPromptNoOutput, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var resultTint: Color {
        if isHistorical {
            return .secondary
        }
        return result.success ? .green : .orange
    }
}

struct LLMReviewPreviewView: View {
    let preview: LLMReviewPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.llmReviewPreview, systemImage: "eye")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            MetadataRow(label: UIStrings.llmReviewPurpose, value: preview.purpose)
            MetadataRow(label: UIStrings.llmReviewRisk, value: "\(preview.risk.level): \(preview.risk.summary)")
            MetadataRow(label: UIStrings.llmReviewCrossAgentFit, value: preview.crossAgentFit.summary)
            MetadataRow(label: UIStrings.llmReviewRedaction, value: redactionSummary)

            VStack(alignment: .leading, spacing: 5) {
                Text(UIStrings.llmReviewSignals)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.risk.signals.isEmpty {
                    Text(UIStrings.llmReviewNoSignals)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.risk.signals, id: \.self) { signal in
                        Label(signal, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(UIStrings.llmReviewFindings)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.findingExplanations.isEmpty {
                    Text(UIStrings.llmReviewNoFindings)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.findingExplanations) { finding in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(finding.severity) · \(finding.ruleID)")
                                .font(.callout.bold())
                            Text(finding.explanation)
                                .foregroundStyle(.secondary)
                            if let nextStep = finding.suggestedNextStep, !nextStep.isEmpty {
                                Text(nextStep)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var redactionSummary: String {
        "body=\(preview.redaction.skillBodyReturned ? "returned" : "hidden"), paths=\(preview.redaction.pathsReturned ? "returned" : "hidden"), credentials=\(preview.redaction.credentialsReturned ? "returned" : "hidden")"
    }
}

extension LLMAction {
    var title: String {
        switch self {
        case .analyze:
            return UIStrings.llmAnalyze
        case .recommend:
            return UIStrings.llmRecommend
        case .explainConflict:
            return UIStrings.llmExplainConflict
        case .draftFrontmatter:
            return UIStrings.llmDraftFrontmatter
        }
    }

    var systemImage: String {
        switch self {
        case .analyze:
            return "text.magnifyingglass"
        case .recommend:
            return "wand.and.stars"
        case .explainConflict:
            return "exclamationmark.bubble"
        case .draftFrontmatter:
            return "doc.badge.plus"
        }
    }
}

struct ScriptExecutionSafetyCard: View {
    let skill: SkillRecord
    let preview: ScriptExecutionPreview?
    let isPreviewing: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.scriptExecutionSafety, systemImage: "lock.shield")
                    .font(.headline)
                Spacer()
                Label(UIStrings.scriptExecutionPreviewOnly, systemImage: "eye")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(preview?.summary ?? UIStrings.scriptExecutionPreviewSummary)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.previewGate, systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isPreviewing)
                .help(UIStrings.scriptExecutionBlockedNote)

                Button {
                } label: {
                    Label(UIStrings.executionBlocked, systemImage: "nosign")
                }
                .disabled(true)
                .help(UIStrings.scriptExecutionBlockedNote)
            }

            if isPreviewing {
                Label(UIStrings.loading, systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }

            if let preview {
                ScriptExecutionPreviewView(preview: preview)
            } else {
                Label(UIStrings.scriptExecutionBlockedNote, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

struct ScriptExecutionPreviewView: View {
    let preview: ScriptExecutionPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(statusTitle, systemImage: statusImage)
                .font(.subheadline.bold())
                .foregroundStyle(preview.executionAllowed ? .orange : .secondary)

            if let reason = preview.disabledReason, !reason.isEmpty {
                Text(reason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.scriptExecutionAuditStatus, value: UIStrings.scriptExecutionAuditStatusTitle(preview.auditStatus))
                MetadataRow(label: UIStrings.scriptExecutionAuditID, value: preview.auditID?.nonEmpty ?? UIStrings.scriptExecutionNoAudit)
                MetadataRow(label: UIStrings.scriptExecutionCWD, value: preview.scope.cwd?.nonEmpty ?? UIStrings.permissionUndeclared)
                MetadataRow(label: UIStrings.scriptExecutionNetwork, value: preview.scope.network?.nonEmpty ?? UIStrings.permissionUndeclared)
                MetadataRow(label: UIStrings.scriptExecutionEnv, value: formattedEnv)
                MetadataRow(label: UIStrings.scriptExecutionFiles, value: formattedFiles)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(UIStrings.scriptExecutionCommand, systemImage: "terminal")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(commandPreview)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(UIStrings.scriptExecutionRisks, systemImage: "exclamationmark.triangle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.risks.isEmpty {
                    Text(UIStrings.scriptExecutionNoRisks)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.risks, id: \.self) { risk in
                        Label(risk, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if preview.confirmationRequired {
                Label(UIStrings.scriptExecutionConfirmationRequired, systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.scriptExecutionBlockedNote, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var statusTitle: String {
        preview.executionAllowed ? UIStrings.executionBlocked : UIStrings.scriptExecutionPreviewOnly
    }

    private var statusImage: String {
        preview.executionAllowed ? "exclamationmark.triangle" : "nosign"
    }

    private var commandPreview: String {
        let command = preview.commandPreview
            .map { part in part.replacingOccurrences(of: "\n", with: "\\n") }
            .joined(separator: " ")
        return command.isEmpty ? UIStrings.scriptExecutionNoCommand : command
    }

    private var formattedEnv: String {
        guard !preview.scope.env.isEmpty else {
            return UIStrings.scriptExecutionEnvEmpty
        }
        return preview.scope.env.keys.sorted().map { key in
            "\(key)=\(preview.scope.env[key] ?? "")"
        }.joined(separator: ", ")
    }

    private var formattedFiles: String {
        preview.scope.files.isEmpty ? UIStrings.scriptExecutionFilesEmpty : preview.scope.files.joined(separator: ", ")
    }
}

extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

extension JSONValue {
    func boolValue(forAnyKey keys: [String]) -> Bool? {
        guard case .object(let object) = self else { return nil }
        for key in keys {
            if let payloadValue = object[key], case .bool(let value) = payloadValue {
                return value
            }
        }
        return nil
    }

    var compactDisplayString: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let object):
            return object.keys.sorted().map { key in
                "\(key)=\(object[key]?.compactDisplayString ?? "")"
            }.joined(separator: ", ")
        case .array(let values):
            return values.map(\.compactDisplayString).joined(separator: ", ")
        case .null:
            return ""
        }
    }
}
