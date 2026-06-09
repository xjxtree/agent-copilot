import AppKit
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        List(selection: $store.selectedSkillID) {
            Section {
                AgentWorkspaceHeader()
                    .padding(.vertical, 6)
            }

            Section {
                ProjectContextControls()
            }

            Section(UIStrings.text("nav.refine", "Refine")) {
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

            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(UIStrings.searchPrompt, text: $store.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
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
                Section(UIStrings.text("sidebar.currentAgentSkills", "\(store.agentFilter.title) Skills")) {
                    ForEach(store.filteredSkills) { skill in
                        SkillRow(skill: skill)
                            .tag(skill.id)
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

private struct AgentWorkspaceHeader: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: agentIcon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.agentFilter.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(UIStrings.text("sidebar.agentWorkspace", "Agent workspace"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker(UIStrings.agent, selection: $store.agentFilter) {
                ForEach(SkillAgentFilter.managementCases) { filter in
                    Text(shortTitle(for: filter)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                AgentStatTile(
                    value: "\(agentSkills.count)",
                    label: UIStrings.text("sidebar.stat.skills", "Skills"),
                    systemImage: "square.stack"
                )
                AgentStatTile(
                    value: "\(enabledAgentSkills.count)",
                    label: UIStrings.text("sidebar.stat.enabled", "Enabled"),
                    systemImage: "checkmark.circle"
                )
                AgentStatTile(
                    value: "\(agentFindingCount)",
                    label: UIStrings.findings,
                    systemImage: "exclamationmark.triangle"
                )
                AgentStatTile(
                    value: "\(agentConflictCount)",
                    label: UIStrings.conflicts,
                    systemImage: "rectangle.2.swap"
                )
            }

            HStack(spacing: 8) {
                Button {
                    Task { await store.scanAll() }
                } label: {
                    Label(UIStrings.text("action.scanSkills", "Scan Skills"), systemImage: "folder.badge.gearshape")
                }
                .controlSize(.small)
                .disabled(store.isRefreshBusy)
                .help(UIStrings.text("help.scan", "Scan supported agent roots and refresh the catalog."))

                Button {
                    Task { await store.reload() }
                } label: {
                    Label(UIStrings.text("action.reloadCatalog", "Reload Catalog"), systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(store.isRefreshBusy)
                .help(UIStrings.text("help.reload", "Reload the current catalog without scanning roots."))
            }

            AgentConfigHistoryDisclosure(
                snapshots: store.agentConfigSnapshots,
                isLoading: store.isLoadingAgentConfigSnapshots,
                isWriting: store.isWriting,
                onPreview: { snapshotID in
                    try await store.previewRollback(snapshotID: snapshotID)
                },
                onRollback: { snapshotID in
                    await store.rollbackSnapshot(snapshotID: snapshotID)
                }
            )

            RefreshStatusView()
        }
        .padding(12)
        .adaptiveMaterialSurface()
        .task {
            await store.loadAgentConfigSnapshots()
        }
    }

    private var agentSkills: [SkillRecord] {
        store.skills.filter { store.agentFilter.includes($0) }
    }

    private var enabledAgentSkills: [SkillRecord] {
        agentSkills.filter { DisplayText.statusKind($0.state, enabled: $0.enabled) == .enabled }
    }

    private var agentFindingCount: Int {
        let instanceIDs = Set(agentSkills.map(\.id))
        let definitionIDs = Set(agentSkills.map(\.definitionId))
        return store.findings.filter { finding in
            if let instanceID = finding.instanceId, instanceIDs.contains(instanceID) {
                return true
            }
            if let definitionID = finding.definitionId, definitionIDs.contains(definitionID) {
                return true
            }
            return false
        }.count
    }

    private var agentConflictCount: Int {
        let instanceIDs = Set(agentSkills.map(\.id))
        let definitionIDs = Set(agentSkills.map(\.definitionId))
        return store.conflicts.filter { conflict in
            definitionIDs.contains(conflict.definitionId) || conflict.instanceIds.contains { instanceIDs.contains($0) }
        }.count
    }

    private var agentIcon: String {
        switch store.agentFilter {
        case .claudeCode:
            return "sparkles"
        case .codex:
            return "chevron.left.forwardslash.chevron.right"
        case .opencode:
            return "curlybraces"
        case .all:
            return "square.grid.2x2"
        }
    }

    private func shortTitle(for filter: SkillAgentFilter) -> String {
        switch filter {
        case .claudeCode:
            return UIStrings.text("agent.short.claudeCode", "Claude")
        case .codex:
            return UIStrings.codex
        case .opencode:
            return UIStrings.opencode
        case .all:
            return UIStrings.text("filter.all", "All")
        }
    }
}

private struct AgentConfigHistoryDisclosure: View {
    let snapshots: [ConfigSnapshotRecord]
    let isLoading: Bool
    let isWriting: Bool
    let onPreview: (String) async throws -> SnapshotRollbackPreviewRecord
    let onRollback: (String) async -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    Label(UIStrings.loading, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                AgentConfigHistorySection(
                    snapshots: snapshots,
                    isWriting: isWriting,
                    onPreview: onPreview,
                    onRollback: onRollback
                )
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(UIStrings.agentConfigHistory)
                        .font(.subheadline.bold())
                    Text(UIStrings.agentConfigHistorySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct ProjectContextControls: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: store.activeProjectContext == nil ? "folder.badge.questionmark" : "folder")
                    .foregroundStyle(store.activeProjectContext == nil ? Color.secondary : Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(UIStrings.project)
                        .font(.subheadline.bold())
                    Text(store.activeProjectContext == nil ? UIStrings.projectGlobalRootsOnly : UIStrings.projectSelectedSource)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(store.activeProjectContext?.name ?? UIStrings.text("project.globalRoots", "Global roots"))
                    .font(.callout.bold())
                    .lineLimit(1)
                Text(store.activeProjectContext?.rootPath ?? UIStrings.text("project.chooseShortPrompt", "Choose a project to include project-scoped skills."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let validationMessage = store.projectValidationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                Button {
                    chooseProject()
                } label: {
                    Label(UIStrings.chooseProject, systemImage: "folder.badge.plus")
                }
                .controlSize(.small)

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

                Spacer()

                Menu {
                    Button {
                        revealActiveProject()
                    } label: {
                        Label(UIStrings.revealInFinder, systemImage: "arrow.up.forward.app")
                    }
                    .disabled(store.activeProjectContext == nil)

                    Button(role: .destructive) {
                        Task { await store.clearProject() }
                    } label: {
                        Label(UIStrings.clearProject, systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .controlSize(.small)
                .disabled(store.activeProjectContext == nil)
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

private struct AgentStatTile: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RefreshStatusView: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
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
                    .lineLimit(2)
            }

            if store.canRetryLastRefresh {
                Button {
                    Task { await store.retryLastRefresh() }
                } label: {
                    Label(UIStrings.retryRefresh, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }

            DisclosureGroup(UIStrings.text("refresh.details", "Refresh Details")) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(store.status?.catalogPath ?? UIStrings.catalogNotLoaded, systemImage: "shippingbox")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Label(store.watcherStatusMessage, systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if !store.refreshLogEntries.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(store.refreshLogEntries.enumerated()), id: \.offset) { _, entry in
                                Label(entry.message, systemImage: refreshLogIcon(entry.level))
                                    .font(.caption2)
                                    .foregroundStyle(refreshLogColor(entry.level))
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption)
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
                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: DisplayText.isReadOnlyPreview(skill) ? "lock.fill" : DisplayText.stateSystemImage(skill.state, enabled: skill.enabled))
                .foregroundStyle(DisplayText.isReadOnlyPreview(skill) ? .secondary : DisplayText.stateColor(skill.state, enabled: skill.enabled))
        }
    }

    private var secondaryText: String {
        if DisplayText.isToolGlobal(skill) {
            return "\(DisplayText.scope(skill.scope)) · \(UIStrings.readOnlyPreview)"
        }
        if DisplayText.isReadOnlyPreview(skill) {
            return "\(DisplayText.scope(skill.scope)) · \(UIStrings.readOnly)"
        }
        return "\(DisplayText.scope(skill.scope)) · \(DisplayText.state(skill.state, enabled: skill.enabled))"
    }
}
