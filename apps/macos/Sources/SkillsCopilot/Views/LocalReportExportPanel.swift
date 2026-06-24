import AppKit
import SwiftUI

struct LocalReportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SkillStore
    let includeSelectedSkill: Bool

    init(includeSelectedSkill: Bool = false) {
        self.includeSelectedSkill = includeSelectedSkill
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Label(UIStrings.text("localReport.preview.title", "Usage Report Preview"), systemImage: "square.and.arrow.down")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(UIStrings.done) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            HStack(alignment: .top, spacing: 12) {
                ScrollView {
                    LocalReportExportPanel(includeSelectedSkill: includeSelectedSkill)
                }
                .frame(minWidth: 520, maxWidth: .infinity)

                LocalReportHistoryPanel(
                    records: store.localReportExportHistory,
                    selectedID: store.selectedLocalReportHistoryID,
                    onSelect: { record in
                        store.selectLocalReportHistoryRecord(record)
                    }
                )
                .frame(width: 250)
            }
        }
        .padding(16)
        .frame(minWidth: 820, idealWidth: 900, minHeight: 520, alignment: .topLeading)
    }
}

struct LocalReportExportPanel: View {
    @EnvironmentObject private var store: SkillStore
    let includeSelectedSkill: Bool

    init(includeSelectedSkill: Bool = true) {
        self.includeSelectedSkill = includeSelectedSkill
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(UIStrings.localReportTitle, systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                if let result = store.localReportExportResult, !result.isUnavailable {
                    Text(result.format.title)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Text(scopeSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(UIStrings.localReportBoundary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LocalReportPreviewScopeView(
                formatTitle: store.localReportFormat.title,
                scopeSummary: scopeSummary,
                includeSelectedSkill: includeSelectedSkill,
                selectedSkillName: store.selectedSkill?.name
            )

            HStack(alignment: .center, spacing: 10) {
                Picker(UIStrings.localReportFormat, selection: $store.localReportFormat) {
                    ForEach(LocalReportFormat.allCases) { format in
                        Label(format.title, systemImage: format.systemImage).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)

                Button {
                    Task { await store.exportLocalReport(includeSelectedSkill: includeSelectedSkill) }
                } label: {
                    Label(UIStrings.localReportExport, systemImage: "square.and.arrow.down")
                        .frame(minWidth: 110)
                }
                .disabled(store.isRefreshBusy)
            }

            if store.isExportingLocalReport {
                Label(UIStrings.localReportExporting, systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let result = store.localReportExportResult {
                LocalReportExportResultView(result: result)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var scopeSummary: String {
        store.localReportScopeSummary(includeSelectedSkill: includeSelectedSkill)
    }
}

private struct LocalReportHistoryPanel: View {
    let records: [LocalReportExportHistoryRecord]
    let selectedID: LocalReportExportHistoryRecord.ID?
    let onSelect: (LocalReportExportHistoryRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.text("localReport.history.title", "History"), systemImage: "clock.arrow.circlepath")
                .font(.headline)

            if records.isEmpty {
                Text(UIStrings.text("localReport.history.empty", "No exported reports yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(records) { record in
                            LocalReportHistoryRow(
                                record: record,
                                isSelected: record.id == selectedID,
                                onSelect: {
                                    onSelect(record)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .adaptiveMaterialSurface()
    }
}

private struct LocalReportHistoryRow: View {
    let record: LocalReportExportHistoryRecord
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: record.result.format.systemImage)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    Text(record.result.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                }

                Text(Self.dateFormatter.string(from: record.exportedAt))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    .lineLimit(1)

                Text(record.scopeSummary)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.76) : .secondary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(record.result.displayName)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct LocalReportExportResultView: View {
    let result: LocalReportExportResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(result.isUnavailable ? UIStrings.localReportUnavailableFallback : result.displayName, systemImage: result.isUnavailable ? "lock.fill" : "doc.text")
                .font(.callout.bold())
                .foregroundStyle(result.isUnavailable ? .secondary : .primary)
                .lineLimit(2)

            if !result.isUnavailable {
                PrivacyPathText(path: result.displayPath, font: .caption, lineLimit: 2)
            }

            Text(result.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !result.sections.isEmpty {
                Text("\(UIStrings.localReportSections): \(result.sectionSummary)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Label(result.redacted ? UIStrings.localReportRedacted : UIStrings.localReportNotRedactedWarning, systemImage: result.redacted ? "eye.slash" : "exclamationmark.triangle")
                .font(.caption.bold())
                .foregroundStyle(result.redacted ? Color.secondary : Color.orange)

            if let fileURL = resolvedFileURL {
                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(fileURL)
                    } label: {
                        Label(UIStrings.openFile, systemImage: "arrow.up.forward.app")
                    }

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    } label: {
                        Label(UIStrings.text("localReport.download", "Download"), systemImage: "arrow.down.circle")
                    }
                    .help(UIStrings.revealInFinder)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(fileURL.path, forType: .string)
                    } label: {
                        Label(UIStrings.copyPath, systemImage: "doc.on.doc")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private var resolvedFileURL: URL? {
        LocalReportFileResolver.fileURL(for: result.path)
    }
}

private struct LocalReportPreviewScopeView: View {
    let formatTitle: String
    let scopeSummary: String
    let includeSelectedSkill: Bool
    let selectedSkillName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(UIStrings.text("localReport.preview.contents", "Preview"), systemImage: "doc.richtext")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }

            Text(scopeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ReportPreviewPill(text: UIStrings.localReportSectionTitle("current_state"))
                ReportPreviewPill(text: UIStrings.localReportSectionTitle("installed_skills"))
                ReportPreviewPill(text: UIStrings.localReportSectionTitle("issues"))
                ReportPreviewPill(text: UIStrings.localReportSectionTitle("task_preflight"))
                if includeSelectedSkill, selectedSkillName?.isEmpty == false {
                    ReportPreviewPill(text: UIStrings.text("localReport.preview.selectedSkill", "Selected skill"))
                }
            }
            .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ReportPreviewPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}

private enum LocalReportFileResolver {
    static func fileURL(for redactedPath: String?) -> URL? {
        guard let redactedPath, !redactedPath.isEmpty else { return nil }
        if redactedPath.hasPrefix("<app-data-dir>/") {
            let relativePath = String(redactedPath.dropFirst("<app-data-dir>/".count))
            let appData = appDataURL
            let fileURL = appData
                .appendingPathComponent(relativePath)
                .standardizedFileURL
            guard fileURL.path.hasPrefix(appData.path + "/") else {
                return nil
            }
            return fileURL
        }
        if redactedPath.hasPrefix("/") {
            return guardedAppDataFileURL(URL(fileURLWithPath: redactedPath).standardizedFileURL, appData: appDataURL)
        }
        return nil
    }

    private static func guardedAppDataFileURL(_ fileURL: URL, appData: URL) -> URL? {
        guard fileURL.path.hasPrefix(appData.path + "/") else {
            return nil
        }
        return fileURL
    }

    private static var appDataURL: URL {
        let environment = ProcessInfo.processInfo.environment
        if let override = environment["SKILLS_COPILOT_APP_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("dev.agent-copilot.native", isDirectory: true)
            .standardizedFileURL
    }
}
