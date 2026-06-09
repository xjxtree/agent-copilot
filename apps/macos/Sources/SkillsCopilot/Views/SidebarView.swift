import AppKit
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        List(selection: $store.selectedSkillID) {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(UIStrings.enabledSummary(enabled: store.enabledCount, total: store.skills.count))
                        .font(.headline)
                    Text(UIStrings.visibleSummary(store.filteredSkills.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.status?.catalogPath ?? UIStrings.catalogNotLoaded)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    RefreshStatusView()
                }
                .padding(.vertical, 6)
            }

            Section(UIStrings.project) {
                ProjectContextControls()
            }

            Section(UIStrings.view) {
                Picker(UIStrings.agent, selection: $store.agentFilter) {
                    ForEach(SkillAgentFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker(UIStrings.state, selection: $store.stateFilter) {
                    ForEach(SkillStateFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker(UIStrings.sort, selection: $store.sortOrder) {
                    ForEach(SkillSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
            }

            if store.skills.isEmpty {
                Section(UIStrings.skills) {
                    SidebarEmptyMessage(message: store.isLoading ? UIStrings.loading : emptyCatalogMessage)
                }
            } else if store.filteredSkills.isEmpty {
                Section(UIStrings.skills) {
                    SidebarEmptyMessage(message: emptyFilteredMessage)
                }
            } else {
                ForEach(store.filteredSkillGroups) { group in
                    Section(group.title) {
                        ForEach(group.skills) { skill in
                            SkillRow(skill: skill)
                                .tag(skill.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(UIStrings.skills)
    }

    private var emptyCatalogMessage: String {
        if store.activeProjectContext == nil {
            return UIStrings.noProjectSkillsMessage
        }
        return UIStrings.noSkillsInCatalog
    }

    private var emptyFilteredMessage: String {
        if store.agentFilter == .codex, store.activeProjectContext == nil {
            return UIStrings.noCodexProjectMessage
        }
        if store.agentFilter == .codex {
            return UIStrings.noCodexSkillsMessage
        }
        return UIStrings.noSkillsMatchSearch
    }
}

private struct ProjectContextControls: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.activeProjectContext == nil ? UIStrings.projectGlobalRootsOnly : UIStrings.projectSelectedSource)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.activeProjectContext?.name ?? UIStrings.noProjectSelected)
                        .font(.headline)
                        .lineLimit(1)
                    Text(store.activeProjectContext?.rootPath ?? UIStrings.projectChoosePrompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: store.activeProjectContext == nil ? "folder.badge.questionmark" : "folder")
                    .foregroundColor(store.activeProjectContext == nil ? .secondary : .accentColor)
            }

            if let validationMessage = store.projectValidationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                Button {
                    chooseProject()
                } label: {
                    Label(UIStrings.chooseProject, systemImage: "folder.badge.plus")
                }
                .controlSize(.small)

                Button {
                    Task { await store.clearProject() }
                } label: {
                    Label(UIStrings.clearProject, systemImage: "xmark.circle")
                }
                .controlSize(.small)
                .disabled(store.activeProjectContext == nil)
            }

            HStack(spacing: 6) {
                Button {
                    revealActiveProject()
                } label: {
                    Label(UIStrings.revealInFinder, systemImage: "arrow.up.forward.app")
                }
                .controlSize(.small)
                .disabled(store.activeProjectContext == nil)

                Menu {
                    if store.recentProjectContexts.isEmpty {
                        Text(UIStrings.noRecentProjects)
                    } else {
                        ForEach(store.recentProjectContexts) { context in
                            Button {
                                Task {
                                    await store.setProject(
                                        rootPath: context.rootPath,
                                        currentCWD: context.currentCWD,
                                        name: context.name
                                    )
                                }
                            } label: {
                                Text(context.name)
                            }
                        }
                    }
                } label: {
                    Label(UIStrings.recentProjects, systemImage: "clock")
                }
                .controlSize(.small)
            }
        }
        .disabled(store.isRefreshBusy)
        .padding(.vertical, 4)
    }

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = UIStrings.chooseProject

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await store.setProject(
                    rootPath: url.path,
                    currentCWD: url.path,
                    name: url.lastPathComponent
                )
            }
        }
    }

    private func revealActiveProject() {
        guard let rootPath = store.activeProjectContext?.rootPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: rootPath)])
    }
}

private struct SidebarEmptyMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

private struct RefreshStatusView: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if store.isLoading || store.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: store.canRetryLastRefresh ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath.circle")
                        .foregroundStyle(store.canRetryLastRefresh ? .orange : .secondary)
                }
                Text(store.refreshStatusMessage)
                    .font(.caption)
                    .foregroundStyle(store.canRetryLastRefresh ? .orange : .secondary)
                    .lineLimit(3)
            }

            Label(store.watcherStatusMessage, systemImage: "dot.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if store.canRetryLastRefresh {
                Button {
                    Task { await store.retryLastRefresh() }
                } label: {
                    Label(UIStrings.retryRefresh, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }

            if !store.refreshLogEntries.isEmpty {
                DisclosureGroup(UIStrings.refreshLog) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(store.refreshLogEntries.enumerated()), id: \.offset) { _, entry in
                            Label(entry.message, systemImage: refreshLogIcon(entry.level))
                                .font(.caption2)
                                .foregroundStyle(refreshLogColor(entry.level))
                                .lineLimit(3)
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption)
            }
        }
        .padding(.top, 6)
    }
}

private func refreshLogIcon(_ level: String) -> String {
    switch level {
    case "error":
        return "exclamationmark.triangle.fill"
    case "warning":
        return "exclamationmark.triangle"
    default:
        return "checkmark.circle"
    }
}

private func refreshLogColor(_ level: String) -> Color {
    switch level {
    case "error":
        return .red
    case "warning":
        return .orange
    default:
        return .secondary
    }
}

private struct SkillRow: View {
    let skill: SkillRecord

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .lineLimit(1)
                Text("\(DisplayText.scope(skill.scope)) · \(DisplayText.isToolGlobal(skill) ? UIStrings.readOnlyPreview : DisplayText.state(skill.state, enabled: skill.enabled))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if DisplayText.isReadOnlyPreview(skill) {
                    Label(DisplayText.isToolGlobal(skill) ? UIStrings.readOnlyPreview : UIStrings.readOnly, systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            Image(systemName: DisplayText.stateSystemImage(skill.state, enabled: skill.enabled))
                .foregroundStyle(DisplayText.stateColor(skill.state, enabled: skill.enabled))
        }
    }
}
