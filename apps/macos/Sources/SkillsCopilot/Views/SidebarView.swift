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

            SkillHealthDashboardCard(
                summary: store.healthSummary,
                agentSummary: store.selectedAgentHealthSummary,
                totalCount: agentSkills.count,
                enabledCount: enabledAgentSkills.count,
                disabledCount: disabledAgentSkills.count,
                findingDisplayCount: agentFindingCount,
                conflictDisplayCount: agentConflictCount,
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

            AgentConfigTimelinePanel(
                model: AgentConfigTimelineModel.make(
                    snapshots: store.agentConfigSnapshots,
                    agentFilter: store.agentFilter
                ),
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

    private var disabledAgentSkills: [SkillRecord] {
        agentSkills.filter { DisplayText.statusKind($0.state, enabled: $0.enabled) == .disabled }
    }

    private var agentFindingCount: Int {
        let agentSkillIDs = Set(agentSkills.map(\.id))
        return FindingDisplayModel.issueGroups(
            findings: store.findings.filter { finding in
                guard let instanceId = finding.instanceId else { return false }
                return agentSkillIDs.contains(instanceId)
            },
            severityFilter: FindingDisplayModel.allFilterValue,
            ruleFilter: FindingDisplayModel.allFilterValue
        ).count
    }

    private var agentConflictCount: Int {
        let agentSkillIDs = Set(agentSkills.map(\.id))
        return store.conflicts.filter { conflict in
            conflict.instanceIds.filter { agentSkillIDs.contains($0) }.count > 1
        }.count
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
    let totalCount: Int
    let enabledCount: Int
    let disabledCount: Int
    let findingDisplayCount: Int
    let conflictDisplayCount: Int
    let onFilter: (SkillStateFilter) -> Void

    private var title: String {
        agentSummary.map { DisplayText.agent($0.agent) } ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private var malformedCount: Int {
        agentSummary?.malformedCount ?? summary.malformedCount
    }

    private var findingCount: Int {
        findingDisplayCount
    }

    private var conflictCount: Int {
        conflictDisplayCount
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
                Text(statusTitle)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(healthColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(healthColor.opacity(0.12), in: Capsule())
                    .help(title)
            }

            Text(summaryText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                HealthCountChip(
                    title: UIStrings.text("sidebar.stat.enabled", "Enabled"),
                    value: enabledCount,
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
                HealthCountChip(
                    title: UIStrings.text("filter.disabled", "Disabled"),
                    value: disabledCount,
                    systemImage: "pause.circle.fill",
                    tint: disabledCount > 0 ? .orange : .secondary
                )
            }

            VStack(spacing: 7) {
                HealthActionRow(
                    title: UIStrings.text("health.findingIssueGroups", "Finding groups"),
                    value: findingCount,
                    systemImage: "exclamationmark.triangle",
                    tint: findingCount > 0 ? .orange : .secondary,
                    actionTitle: UIStrings.text("health.openFindings", "Open"),
                    isActionEnabled: findingCount > 0,
                    onTap: { onFilter(.withFindings) }
                )
                HealthActionRow(
                    title: UIStrings.text("health.sameAgentConflicts", "Same-agent conflicts"),
                    value: conflictCount,
                    systemImage: "rectangle.2.swap",
                    tint: conflictCount > 0 ? .red : .secondary,
                    actionTitle: UIStrings.text("health.openConflicts", "Open"),
                    isActionEnabled: conflictCount > 0,
                    onTap: { onFilter(.withConflicts) }
                )
                HealthActionRow(
                    title: UIStrings.text("health.brokenMissing", "Broken / missing"),
                    value: malformedCount,
                    systemImage: "wrench.and.screwdriver",
                    tint: malformedCount > 0 ? .red : .secondary,
                    actionTitle: UIStrings.text("health.filter.triage", "Triage"),
                    isActionEnabled: malformedCount > 0,
                    onTap: { onFilter(.needsTriage) }
                )
                HealthActionRow(
                    title: UIStrings.text("health.riskAnalysis", "Risk / analysis"),
                    value: riskAnalysisCount,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: riskAnalysisCount > 0 ? .blue : .secondary,
                    actionTitle: UIStrings.text("health.filter.risk", "Risk"),
                    isActionEnabled: riskCount > 0,
                    onTap: { onFilter(.risky) }
                )
            }

            Text(UIStrings.text("health.scopeHint", "\(title) · \(totalCount) skills"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                    .lineLimit(1)
        }
        .padding(10)
        .background(healthColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var riskAnalysisCount: Int {
        riskCount + analysisCount
    }

    private var statusTitle: String {
        if summary.totalCount == 0 || totalCount == 0 {
            return UIStrings.text("health.status.noData", "No data")
        }
        if malformedCount > 0 || conflictCount > 0 {
            return UIStrings.text("health.status.attention", "Attention")
        }
        if findingCount > 0 || riskCount > 0 {
            return UIStrings.text("health.status.review", "Review")
        }
        return UIStrings.text("health.status.clean", "Clean")
    }

    private var summaryText: String {
        if summary.totalCount == 0 || totalCount == 0 {
            return UIStrings.text("health.empty", "Run Scan to build a skill health summary.")
        }
        if conflictCount > 0 {
            return UIStrings.text("health.summary.conflicts", "\(conflictCount) same-agent conflicts need review.")
        }
        if findingCount > 0 {
            return UIStrings.text("health.summary.findings", "\(findingCount) finding issue groups need review.")
        }
        if malformedCount > 0 {
            return UIStrings.text("health.summary.malformed", "\(malformedCount) broken or missing records need cleanup.")
        }
        if riskCount > 0 {
            return UIStrings.text("health.summary.risk", "\(riskCount) risk signals; use Risk to inspect findings.")
        }
        return UIStrings.text("health.summary.clean", "No same-agent conflicts or broken records.")
    }

    private var healthColor: Color {
        if malformedCount > 0 || conflictCount > 0 {
            return .red
        }
        if findingCount > 0 || riskCount > 0 {
            return .orange
        }
        return .green
    }
}

private struct HealthCountChip: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text("\(value)")
                .fontWeight(.bold)
                .monospacedDigit()
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: Capsule())
        .help(title)
    }
}

private struct HealthActionRow: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color
    let actionTitle: String
    let isActionEnabled: Bool
    let onTap: () -> Void

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
            Button(actionTitle, action: onTap)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(!isActionEnabled)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
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
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(statusColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusTitle: String {
        switch capability.status {
        case "verified":
            return UIStrings.text("adapter.status.verified", "Verified")
        case "read-only":
            return UIStrings.text("adapter.status.readOnly", "Read-only")
        case "planned":
            return UIStrings.text("adapter.status.planned", "Planned")
        default:
            return UIStrings.text("adapter.status.blocked", "Blocked")
        }
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
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: featureIcon)
                Text(title)
                    .lineLimit(1)
            }
            Text(featureTitle)
                .lineLimit(1)
        }
        .font(.caption2.bold())
        .foregroundStyle(featureColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(featureColor.opacity(feature.supported ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 8))
        .help(feature.reason ?? feature.status)
    }

    private var featureTitle: String {
        if feature.supported {
            return UIStrings.text("adapter.feature.verified", "Verified")
        }
        switch feature.status {
        case "read-only":
            return UIStrings.text("adapter.feature.readOnly", "Read-only")
        case "planned":
            return UIStrings.text("adapter.feature.planned", "Planned")
        default:
            return UIStrings.text("adapter.feature.blocked", "Blocked")
        }
    }

    private var featureIcon: String {
        if feature.supported {
            return "checkmark.circle.fill"
        }
        if feature.status == "read-only" {
            return "lock.fill"
        }
        return "exclamationmark.triangle.fill"
    }

    private var featureColor: Color {
        if feature.supported {
            return .green
        }
        if feature.status == "read-only" || feature.status == "planned" {
            return .orange
        }
        return .red
    }
}

private struct AgentConfigTimelinePanel: View {
    let model: AgentConfigTimelineModel
    let isLoading: Bool
    let isWriting: Bool
    let onPreview: (String) async throws -> SnapshotRollbackPreviewRecord
    let onRollback: (String) async -> Void

    @State private var isExpanded = false
    @State private var preview: SnapshotRollbackPreviewRecord?
    @State private var previewError: String?
    @State private var snapshotToRollback: ConfigSnapshotRecord?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    Label(UIStrings.loading, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let previewError {
                    Label(previewError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                Text(UIStrings.agentConfigTimelineBoundary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                if !model.isSpecificAgent {
                    SidebarEmptyMessage(message: UIStrings.agentConfigTimelineSelectAgent)
                } else if model.items.isEmpty, !isLoading {
                    SidebarEmptyMessage(message: UIStrings.noSnapshotsMessage)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.items) { item in
                            AgentConfigTimelineRow(
                                item: item,
                                isWriting: isWriting,
                                onPreview: {
                                    loadPreview(item.id)
                                },
                                onRollback: {
                                    snapshotToRollback = item.snapshot
                                }
                            )
                        }

                        if model.hiddenCount > 0 {
                            Text(UIStrings.agentConfigTimelineMore(model.hiddenCount))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 2)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(UIStrings.agentConfigTimeline)
                        .font(.subheadline.bold())
                    Text(model.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .sheet(item: $preview) { preview in
            SnapshotPreviewSheet(preview: preview)
        }
        .confirmationDialog(
            UIStrings.rollbackSnapshotQuestion,
            isPresented: Binding(
                get: { snapshotToRollback != nil },
                set: { isPresented in
                    if !isPresented {
                        snapshotToRollback = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(UIStrings.rollback, role: .destructive) {
                if let snapshotID = snapshotToRollback?.id {
                    Task { await onRollback(snapshotID) }
                }
                snapshotToRollback = nil
            }
            Button(UIStrings.cancel, role: .cancel) {
                snapshotToRollback = nil
            }
        } message: {
            Text(UIStrings.agentConfigTimelineRollbackConfirm(snapshotToRollback?.target ?? ""))
        }
    }

    private func loadPreview(_ snapshotID: String) {
        previewError = nil
        Task {
            do {
                preview = try await onPreview(snapshotID)
            } catch {
                previewError = error.localizedDescription
            }
        }
    }
}

private struct AgentConfigTimelineRow: View {
    let item: AgentConfigTimelineItem
    let isWriting: Bool
    let onPreview: () -> Void
    let onRollback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 1, height: 32)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.actionText)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.timeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(item.targetSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(item.snapshot.target)

                    HStack(spacing: 6) {
                        TimelinePill(title: item.scopeText, systemImage: "folder")
                        TimelinePill(title: item.statusText, systemImage: "checkmark.seal")
                    }

                    Text(item.capturedText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.previewDiff, systemImage: "doc.text.magnifyingglass")
                }
                .controlSize(.small)
                .disabled(isWriting)

                Button(role: .destructive) {
                    onRollback()
                } label: {
                    Label(UIStrings.rollback, systemImage: "arrow.uturn.backward")
                }
                .controlSize(.small)
                .disabled(isWriting)
            }
            .buttonStyle(.borderless)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct TimelinePill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.32), in: Capsule())
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
