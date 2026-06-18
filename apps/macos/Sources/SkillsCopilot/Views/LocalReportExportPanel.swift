import AppKit
import SwiftUI

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
        var parts = [store.agentFilter.title]
        if store.stateFilter != .all {
            parts.append(store.stateFilter.title)
        }
        let search = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty {
            parts.append(UIStrings.text("localReport.scope.search", "Search filter active"))
        }
        if includeSelectedSkill, let skill = store.selectedSkill {
            parts.append(skill.name)
        }
        return String(format: UIStrings.text("localReport.scope.agent", "Exports the current local audit scope: %@."), parts.joined(separator: " · "))
    }
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
                        Label(UIStrings.revealInFinder, systemImage: "finder")
                    }

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
