import AppKit
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: SkillStore
    @State private var isBatchOperationPresented = false

    var body: some View {
        List(selection: $store.selectedSidebarSelection) {
            Section {
                AgentWorkspaceHeader()
                    .padding(.vertical, 6)
                    .tag(SidebarSelection.agentWorkspace)
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
                Section {
                    ForEach(store.filteredSkills) { skill in
                        SkillRow(skill: skill)
                            .tag(SidebarSelection.skill(skill.id))
                    }
                } header: {
                    SkillListSectionHeader(
                        title: skillListSectionTitle,
                        visibleCount: store.filteredSkills.count,
                        isBatchDisabled: store.filteredSkills.isEmpty || store.isRefreshBusy,
                        action: {
                            store.resetBatchToggleSelectionToVisibleSkills()
                            isBatchOperationPresented = true
                        }
                    )
                }
                .id(skillListRefreshID)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(UIStrings.skills)
        .sheet(isPresented: $isBatchOperationPresented) {
            BatchSkillOperationSheet()
                .environmentObject(store)
        }
    }

    private var skillListSectionTitle: String {
        let count = store.filteredSkills.count
        if store.stateFilter == .all, store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return UIStrings.text("sidebar.currentAgentSkills", "\(store.agentFilter.title) Skills")
        }
        return UIStrings.text("sidebar.filteredAgentSkills", "\(store.agentFilter.title) Skills · \(count) shown")
    }

    private var skillListRefreshID: String {
        [
            store.agentFilter.rawValue,
            store.stateFilter.rawValue,
            store.sortOrder.rawValue,
            store.searchText,
            String(store.filteredSkills.count)
        ].joined(separator: "|")
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
        if store.agentFilter == .openclaw {
            return UIStrings.noOpenClawWorkspaceSkillsMessage
        }
        return UIStrings.noSkillsMatchSearch
    }

}

private struct SkillListSectionHeader: View {
    let title: String
    let visibleCount: Int
    let isBatchDisabled: Bool
    let action: () -> Void

    private static let trailingControlInset: CGFloat = 14

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(UIStrings.batchToggleSelectedCount(visibleCount))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                ViewThatFits(in: .horizontal) {
                    Label(UIStrings.batchToggleOpen, systemImage: "checklist.checked")
                    Image(systemName: "checklist.checked")
                }
                .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isBatchDisabled)
            .help(UIStrings.batchToggleOpenHelp)
        }
        .textCase(nil)
        .padding(.trailing, Self.trailingControlInset)
        .padding(.top, 7)
        .padding(.bottom, 5)
    }
}

private struct AgentWorkspaceHeader: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        HStack(spacing: 10) {
            AgentIconBadge(filter: store.agentFilter)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.agentFilter.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(UIStrings.text("sidebar.agentWorkspace", "Agent workspace"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            AgentSelectorMenu(width: 84)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct AgentSelectorMenu: View {
    @EnvironmentObject private var store: SkillStore
    let width: CGFloat

    var body: some View {
        Picker(UIStrings.agent, selection: $store.agentFilter) {
            ForEach(SkillAgentFilter.managementCases) { filter in
                Label(shortTitle(for: filter), systemImage: systemImage(for: filter))
                    .tag(filter)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: width, alignment: .trailing)
        .help("\(UIStrings.text("help.agentSelector", "Select the agent workspace.")) \(store.agentFilter.title)")
        .accessibilityLabel(UIStrings.agent)
        .accessibilityValue(store.agentFilter.title)
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

    private func systemImage(for filter: SkillAgentFilter) -> String {
        switch filter {
        case .claudeCode:
            return "sparkle"
        case .codex:
            return "terminal"
        case .opencode:
            return "curlybraces"
        case .pi:
            return "pi"
        case .hermes:
            return "bolt"
        case .openclaw:
            return "shippingbox"
        case .all:
            return "square.grid.2x2"
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

    private var brokenMissingCount: Int {
        if let agentSummary {
            return agentSummary.brokenCount + agentSummary.missingCount
        }
        return summary.brokenCount + summary.missingCount
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

    private var findingsTitle: String {
        let base = UIStrings.text("health.findingIssueGroups", "Issues")
        guard riskCount > 0 else { return base }
        return "\(base) · \(riskCount) \(UIStrings.text("health.riskSuffix", "risk"))"
    }

    private var integrityCount: Int {
        conflictCount + brokenMissingCount
    }

    private var integrityTitle: String {
        if conflictCount > 0 && brokenMissingCount > 0 {
            return UIStrings.text("health.integrityMixed", "Integrity issues")
        }
        if conflictCount > 0 {
            return UIStrings.text("health.sameAgentConflicts", "Same-agent conflicts")
        }
        if brokenMissingCount > 0 {
            return UIStrings.text("health.brokenMissing", "Broken / missing")
        }
        return UIStrings.text("health.integrityClean", "Integrity checks")
    }

    private var integrityActionTitle: String {
        if conflictCount > 0 {
            return UIStrings.text("health.openConflicts", "Open")
        }
        return UIStrings.text("health.filter.brokenMissing", "Filter")
    }

    private var integrityFilter: SkillStateFilter {
        conflictCount > 0 ? .withConflicts : .brokenOrMissing
    }

    private var analysisSummaryText: String {
        UIStrings.text("health.analysisInline", "\(analysisCount) cross-agent analysis groups available in Analysis.")
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
                    title: findingsTitle,
                    value: findingCount,
                    systemImage: "exclamationmark.triangle",
                    tint: findingCount > 0 || riskCount > 0 ? .orange : .secondary,
                    actionTitle: UIStrings.text("health.openFindings", "Open"),
                    isActionEnabled: findingCount > 0,
                    onTap: { onFilter(.withFindings) }
                )
                HealthActionRow(
                    title: integrityTitle,
                    value: integrityCount,
                    systemImage: "wrench.and.screwdriver",
                    tint: integrityCount > 0 ? .red : .secondary,
                    actionTitle: integrityActionTitle,
                    isActionEnabled: integrityCount > 0,
                    onTap: { onFilter(integrityFilter) }
                )
            }

            if analysisCount > 0 {
                Text(analysisSummaryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.top, -2)
            }

            Text(UIStrings.text("health.scopeHint", "\(title) · \(totalCount) skills"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                    .lineLimit(1)
        }
        .padding(10)
        .background(healthColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusTitle: String {
        if summary.totalCount == 0 || totalCount == 0 {
            return UIStrings.text("health.status.noData", "No data")
        }
        if integrityCount > 0 {
            return UIStrings.text("health.status.attention", "Attention")
        }
        if findingCount > 0 || riskCount > 0 || analysisCount > 0 {
            return UIStrings.text("health.status.review", "Review")
        }
        return UIStrings.text("health.status.clean", "Clean")
    }

    private var summaryText: String {
        if summary.totalCount == 0 || totalCount == 0 {
            return UIStrings.text("health.empty", "Run Scan to build a skill health summary.")
        }
        if conflictCount > 0 {
            return UIStrings.text("health.summary.conflicts", "\(conflictCount) same-agent runtime/name conflicts need review.")
        }
        if brokenMissingCount > 0 {
            return UIStrings.text("health.summary.brokenMissing", "\(brokenMissingCount) broken or missing records need cleanup.")
        }
        if findingCount > 0 && riskCount > 0 {
            return UIStrings.text("health.summary.findingsWithRisk", "\(findingCount) finding groups include \(riskCount) risk signals.")
        }
        if findingCount > 0 {
            return UIStrings.text("health.summary.findings", "\(findingCount) finding issue groups need review.")
        }
        if riskCount > 0 {
            return UIStrings.text("health.summary.risk", "\(riskCount) risk signals; use Risk to inspect findings.")
        }
        if analysisCount > 0 {
            return UIStrings.text("health.summary.analysis", "\(analysisCount) cross-agent analysis groups available; open Analysis to inspect duplicate names or source overlap.")
        }
        return UIStrings.text("health.summary.clean", "No same-agent conflicts or broken records.")
    }

    private var healthColor: Color {
        if integrityCount > 0 {
            return .red
        }
        if findingCount > 0 || riskCount > 0 || analysisCount > 0 {
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

private struct ProjectContextControls: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: store.activeProjectContext == nil ? "folder.badge.questionmark" : "folder")
                    .foregroundStyle(store.activeProjectContext == nil ? Color.secondary : Color.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(UIStrings.project)
                        .font(.subheadline.bold())
                    Text(store.activeProjectContext == nil ? UIStrings.projectGlobalRootsOnly : UIStrings.projectSelectedSource)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                projectSelectionMenu
                projectActionsMenu
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(store.activeProjectContext?.name ?? UIStrings.text("project.globalRoots", "Global roots"))
                    .font(.callout.bold())
                    .lineLimit(1)
                if let rootPath = store.activeProjectContext?.rootPath {
                    PrivacyPathText(path: rootPath, font: .caption, lineLimit: 2)
                } else {
                    Text(UIStrings.text("project.chooseShortPrompt", "Choose a project to include project-scoped skills."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let validationMessage = store.projectValidationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            if store.agentFilter == .openclaw {
                Label(UIStrings.openClawWorkspaceBoundary, systemImage: "folder.badge.questionmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .disabled(store.isRefreshBusy)
        .padding(.vertical, 4)
    }

    private var projectSelectionMenu: some View {
        Menu {
            Button {
                chooseProject()
            } label: {
                Label(UIStrings.chooseProject, systemImage: "folder.badge.plus")
            }

            Divider()

            if store.recentProjectContexts.isEmpty {
                Text(UIStrings.noRecentProjects)
            } else {
                Section(UIStrings.recentProjects) {
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
            }
        } label: {
            Label(UIStrings.text("project.chooseMenu", "Choose"), systemImage: "folder.badge.plus")
                .lineLimit(1)
                .frame(width: 92)
        }
        .controlSize(.small)
        .help(UIStrings.projectChoosePrompt)
    }

    private var projectActionsMenu: some View {
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
                .frame(width: 28)
        }
        .controlSize(.small)
        .disabled(store.activeProjectContext == nil)
        .help(UIStrings.text("project.moreActions", "Project actions"))
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
            return "\(DisplayText.scope(for: skill)) · \(UIStrings.readOnlyPreview)"
        }
        if skill.agent == "hermes", DisplayText.isReadOnlyPreview(skill) {
            return "\(DisplayText.scope(for: skill)) · \(skill.provenance.label)"
        }
        if DisplayText.isReadOnlyPreview(skill) {
            return "\(DisplayText.scope(for: skill)) · \(UIStrings.readOnly)"
        }
        return "\(DisplayText.scope(for: skill)) · \(DisplayText.state(skill.state, enabled: skill.enabled))"
    }
}
