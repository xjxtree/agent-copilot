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
        if let capability = store.selectedAdapterCapability, !capability.scan.supported {
            return capability.scan.reason ?? UIStrings.adapterNotImplementedMessage(DisplayText.agent(capability.agent))
        }
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
                AgentIconBadge(filter: store.agentFilter)

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
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let capability = store.selectedAdapterCapability {
                AdapterCapabilityCard(capability: capability)
            }

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

            SkillHealthDashboardCard(
                summary: store.healthSummary,
                agentSummary: store.selectedAgentHealthSummary,
                onFilter: { filter in
                    store.stateFilter = filter
                }
            )

            VStack(spacing: 8) {
                Button {
                    Task { await store.scanAll() }
                } label: {
                    Label(UIStrings.text("action.scanSkills", "Scan Skills"), systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .disabled(store.isRefreshBusy)
                .help(UIStrings.text("help.scan", "Scan supported agent roots and refresh the catalog."))

                Button {
                    Task { await store.reload() }
                } label: {
                    Label(UIStrings.text("action.reloadCatalog", "Reload Catalog"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
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
        store.selectedAgentHealthSummary?.findingCount ?? 0
    }

    private var agentConflictCount: Int {
        store.selectedAgentHealthSummary?.conflictCount ?? 0
    }

    private func shortTitle(for filter: SkillAgentFilter) -> String {
        switch filter {
        case .claudeCode:
            return UIStrings.text("agent.short.claudeCode", "Claude")
        case .codex:
            return UIStrings.codex
        case .opencode:
            return UIStrings.opencode
        case .pi:
            return UIStrings.pi
        case .hermes:
            return UIStrings.hermes
        case .openclaw:
            return UIStrings.openclaw
        case .all:
            return UIStrings.text("filter.all", "All")
        }
    }
}

private struct SkillHealthDashboardCard: View {
    let summary: SkillHealthSummary
    let agentSummary: AgentSkillHealthSummary?
    let onFilter: (SkillStateFilter) -> Void

    private var title: String {
        agentSummary.map { DisplayText.agent($0.agent) } ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private var malformedCount: Int {
        agentSummary?.malformedCount ?? summary.malformedCount
    }

    private var findingCount: Int {
        agentSummary?.findingCount ?? summary.findingCount
    }

    private var conflictCount: Int {
        agentSummary?.conflictCount ?? summary.conflictCount
    }

    private var riskCount: Int {
        agentSummary?.riskCount ?? summary.riskCount
    }

    private var analysisCount: Int {
        agentSummary?.analysisGroupCount ?? summary.analysisGroups.totalCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Label(UIStrings.text("health.title", "Health"), systemImage: "stethoscope")
                    .font(.caption.bold())
                    .foregroundStyle(healthColor)
                Spacer()
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(spacing: 7) {
                HealthSummaryRow(
                    title: UIStrings.text("health.riskSignals", "Risk signals"),
                    value: riskCount,
                    systemImage: "lock.trianglebadge.exclamationmark",
                    tint: riskCount > 0 ? .orange : .secondary
                )
                HealthSummaryRow(
                    title: UIStrings.text("health.brokenMissing", "Broken / missing"),
                    value: malformedCount,
                    systemImage: "wrench.and.screwdriver",
                    tint: malformedCount > 0 ? .red : .secondary
                )
                HealthSummaryRow(
                    title: UIStrings.text("health.analysisGroups", "Analysis groups"),
                    value: analysisCount,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: analysisCount > 0 ? .blue : .secondary
                )
            }

            HStack(spacing: 8) {
                HealthFilterButton(title: UIStrings.text("health.filter.triage", "Triage"), systemImage: "line.3.horizontal.decrease.circle", showTitle: true, onTap: { onFilter(.needsTriage) })
                HealthFilterButton(title: UIStrings.text("health.filter.risk", "Risk"), systemImage: "lock.trianglebadge.exclamationmark", showTitle: true, onTap: { onFilter(.risky) })
                if findingCount > 0 {
                    HealthFilterButton(title: UIStrings.findings, systemImage: "exclamationmark.triangle", showTitle: false, onTap: { onFilter(.withFindings) })
                }
                if conflictCount > 0 {
                    HealthFilterButton(title: UIStrings.conflicts, systemImage: "rectangle.2.swap", showTitle: false, onTap: { onFilter(.withConflicts) })
                }
            }

            Text(summaryText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(healthColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var summaryText: String {
        if summary.totalCount == 0 {
            return UIStrings.text("health.empty", "Run Scan to build a skill health summary.")
        }
        if conflictCount > 0 {
            return UIStrings.text("health.summary.conflicts", "\(conflictCount) same-agent conflicts need review.")
        }
        if riskCount > 0 {
            return UIStrings.text("health.summary.risk", "\(riskCount) risk signals; use Triage to inspect findings.")
        }
        if malformedCount > 0 {
            return UIStrings.text("health.summary.malformed", "\(malformedCount) broken or missing records need cleanup.")
        }
        return UIStrings.text("health.summary.clean", "No same-agent conflicts or broken records.")
    }

    private var healthColor: Color {
        if malformedCount > 0 {
            return .red
        }
        if findingCount > 0 || conflictCount > 0 || riskCount > 0 {
            return .orange
        }
        return .green
    }
}

private struct HealthSummaryRow: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("\(value)")
                .font(.caption.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct HealthFilterButton: View {
    let title: String
    let systemImage: String
    let showTitle: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if showTitle {
                Label(title, systemImage: systemImage)
            } else {
                Label(title, systemImage: systemImage)
                    .labelStyle(.iconOnly)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
    }
}

private struct AdapterCapabilityCard: View {
    let capability: AdapterCapabilityRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Label(UIStrings.adapterCapabilities, systemImage: statusIcon)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                Spacer()
                Text(statusTitle)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 6) {
                CapabilityPill(title: UIStrings.adapterScan, feature: capability.scan)
                CapabilityPill(title: UIStrings.adapterToggle, feature: capability.configToggle)
                CapabilityPill(title: UIStrings.adapterInstall, feature: capability.install)
            }

            if let primaryBlocker = capability.blockers.first {
                Text(primaryBlocker)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(statusColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusTitle: String {
        capability.status.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private var statusIcon: String {
        switch capability.status {
        case "verified":
            return "checkmark.seal.fill"
        case "read-only":
            return "lock.fill"
        case "planned":
            return "calendar.badge.clock"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch capability.status {
        case "verified":
            return .green
        case "read-only", "planned":
            return .orange
        default:
            return .red
        }
    }
}

private struct CapabilityPill: View {
    let title: String
    let feature: AdapterFeatureCapability

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: feature.supported ? "checkmark.circle.fill" : "lock.fill")
            Text(title)
                .lineLimit(1)
        }
        .font(.caption2.bold())
        .foregroundStyle(feature.supported ? .green : .secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.32), in: Capsule())
        .help(feature.reason ?? feature.status)
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

private struct AgentIconBadge: View {
    let filter: SkillAgentFilter

    var body: some View {
        ZStack {
            if let image = AgentIconProvider.image(for: filter) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .accessibilityLabel(DisplayText.agent(filter.rawValue))
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(DisplayText.agent(filter.rawValue))
            }
        }
        .frame(width: 28, height: 28)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var fallbackSystemImage: String {
        switch filter {
        case .claudeCode:
            return "sparkles"
        case .codex:
            return "chevron.left.forwardslash.chevron.right"
        case .opencode:
            return "curlybraces"
        case .pi:
            return "p.circle"
        case .hermes:
            return "h.circle"
        case .openclaw:
            return "pawprint"
        case .all:
            return "square.grid.2x2"
        }
    }
}

private enum AgentIconProvider {
    static func image(for filter: SkillAgentFilter) -> NSImage? {
        for candidate in candidates(for: filter) {
            if let image = load(candidate: candidate) {
                image.size = NSSize(width: 32, height: 32)
                return image
            }
        }
        return nil
    }

    private static func candidates(for filter: SkillAgentFilter) -> [AgentIconCandidate] {
        switch filter {
        case .claudeCode:
            return [
                .appBundle("/Applications/Claude.app"),
                .resource("/Applications/Claude.app/Contents/Resources/electron.icns"),
                .fileIcon("/opt/homebrew/bin/claude")
            ]
        case .codex:
            return [
                .appBundle("/Applications/Codex.app"),
                .resource("/Applications/Codex.app/Contents/Resources/icon.icns"),
                .resource("/Applications/Codex.app/Contents/Resources/app.icns"),
                .resource("/Applications/Codex.app/Contents/Resources/default_app/icon.png"),
                .fileIcon("/opt/homebrew/bin/codex")
            ]
        case .opencode:
            return [
                .appBundle("/Applications/OpenCode.app"),
                .appBundle("/Applications/opencode.app"),
                .resource("/Applications/OpenCode.app/Contents/Resources/icon.icns"),
                .fileIcon("/opt/homebrew/bin/opencode")
            ]
        case .pi:
            return [
                .bundledResource("PiBadge.svg"),
                .appBundle("/Applications/Pi.app"),
                .appBundle("/Applications/Pi Coding Agent.app"),
                .resource("/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/assets/icon.png"),
                .resource("/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/resources/icon.png"),
                .resource("/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/icon.png"),
                .fileIcon("/opt/homebrew/bin/pi")
            ]
        case .hermes:
            return [
                .bundledResource("HermesIcon.png")
            ]
        case .openclaw:
            return [
                .bundledResource("OpenClawIcon.svg")
            ]
        case .all:
            return []
        }
    }

    private static func load(candidate: AgentIconCandidate) -> NSImage? {
        switch candidate.kind {
        case .bundledResource:
            guard let url = Bundle.module.url(forResource: candidate.path, withExtension: nil) else {
                return nil
            }
            return NSImage(contentsOf: url)
        case .appBundle, .fileIcon:
            guard FileManager.default.fileExists(atPath: candidate.path) else {
                return nil
            }
            return NSWorkspace.shared.icon(forFile: candidate.path)
        case .resource:
            guard FileManager.default.fileExists(atPath: candidate.path) else {
                return nil
            }
            return NSImage(contentsOfFile: candidate.path)
        }
    }
}

private struct AgentIconCandidate {
    enum Kind {
        case appBundle
        case fileIcon
        case bundledResource
        case resource
    }

    let kind: Kind
    let path: String

    static func appBundle(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .appBundle, path: path)
    }

    static func fileIcon(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .fileIcon, path: path)
    }

    static func bundledResource(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .bundledResource, path: path)
    }

    static func resource(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .resource, path: path)
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
