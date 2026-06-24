import AppKit
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: SkillStore
    @State private var isReportSheetPresented = false
    @State private var isPreflightSheetPresented = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    AgentWorkspaceHeader()
                        .padding(.vertical, 6)
                }

                Section {
                    ProjectContextControls()
                }

                Section(UIStrings.text("sidebar.primaryNavigation", "Navigate")) {
                    VStack(spacing: 8) {
                        SidebarNavigationCardButton(
                            title: SidebarContentMode.sessions.title,
                            subtitle: sessionButtonSubtitle,
                            systemImage: SidebarContentMode.sessions.systemImage,
                            count: String(store.localSessionPreviewResult.count),
                            metrics: sessionCardMetrics,
                            isSelected: isSessionCardSelected
                        ) {
                            selectSessions()
                        }

                        SidebarNavigationCardButton(
                            title: SidebarContentMode.skills.title,
                            subtitle: skillButtonSubtitle,
                            systemImage: SidebarContentMode.skills.systemImage,
                            count: String(agentSkillCount),
                            metrics: skillCardMetrics,
                            isSelected: isSkillCardSelected
                        ) {
                            selectSkills()
                        }

                        SidebarNavigationCardButton(
                            title: SidebarContentMode.config.title,
                            subtitle: AgentConfigDisplay.shortTargetPath(for: store.agentFilter, store: store),
                            systemImage: SidebarContentMode.config.systemImage,
                            count: configStatusText,
                            metrics: configCardMetrics,
                            isSelected: isConfigCardSelected
                        ) {
                            selectConfig()
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)
            .frame(maxHeight: .infinity)

            Divider()
                .opacity(0.35)

            SidebarFooterToolRow(
                onOpenReport: {
                    isReportSheetPresented = true
                },
                onOpenPreflight: {
                    isPreflightSheetPresented = true
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .navigationTitle(UIStrings.appTitle)
        .sheet(isPresented: $isReportSheetPresented) {
            LocalReportPreviewSheet(includeSelectedSkill: false)
                .environmentObject(store)
        }
        .sheet(isPresented: $isPreflightSheetPresented) {
            TaskPreflightPreviewSheet()
                .environmentObject(store)
        }
    }

    private var isSessionCardSelected: Bool {
        store.sidebarContentMode == .sessions
    }

    private var isSkillCardSelected: Bool {
        store.sidebarContentMode == .skills
    }

    private var isConfigCardSelected: Bool {
        store.sidebarContentMode == .config
    }

    private var agentSkills: [SkillRecord] {
        store.skills.filter { store.agentFilter.includes($0) }
    }

    private var configCapability: AdapterCapabilityRecord? {
        store.adapterCapabilities.first { $0.agent == store.agentFilter.rawValue }
    }

    private var agentSkillCount: Int {
        store.selectedAgentHealthSummary?.totalCount ?? agentSkills.count
    }

    private var agentEnabledCount: Int {
        store.selectedAgentHealthSummary?.enabledCount ?? agentSkills.filter(\.enabled).count
    }

    private var agentFindingCount: Int {
        store.selectedAgentHealthSummary?.findingCount ?? 0
    }

    private var agentConflictCount: Int {
        store.selectedAgentHealthSummary?.conflictCount ?? 0
    }

    private var sessionCardMetrics: [SidebarNavigationMetric] {
        [
            SidebarNavigationMetric(
                title: UIStrings.text("sidebar.sessions.userShort", "User"),
                value: String(store.localSessionPreviewResult.userMessageCount),
                tone: countTone(store.localSessionPreviewResult.userMessageCount, active: .info)
            ),
            SidebarNavigationMetric(
                title: UIStrings.text("sidebar.sessions.totalShort", "Msg"),
                value: String(store.localSessionPreviewResult.totalMessageCount),
                tone: countTone(store.localSessionPreviewResult.totalMessageCount, active: .info)
            ),
            SidebarNavigationMetric(
                title: UIStrings.text("sidebar.sessions.toolShort", "Tool"),
                value: String(store.localSessionPreviewResult.toolCallCount),
                tone: countTone(store.localSessionPreviewResult.toolCallCount, active: .warning)
            ),
            SidebarNavigationMetric(
                title: UIStrings.text("sidebar.sessions.skillShort", "Skill"),
                value: String(store.localSessionPreviewResult.skillCallCount),
                tone: countTone(store.localSessionPreviewResult.skillCallCount, active: .positive)
            )
        ]
    }

    private var skillCardMetrics: [SidebarNavigationMetric] {
        [
            SidebarNavigationMetric(
                title: UIStrings.text("agentCopilot.metric.enabled", "Enabled"),
                value: String(agentEnabledCount),
                tone: countTone(agentEnabledCount, active: .positive)
            ),
            SidebarNavigationMetric(
                title: UIStrings.text("agentCopilot.metric.findings", "Issues"),
                value: String(agentFindingCount),
                tone: agentFindingCount > 0 ? .warning : .positive
            ),
            SidebarNavigationMetric(
                title: UIStrings.text("agentCopilot.metric.conflicts", "Conflicts"),
                value: String(agentConflictCount),
                tone: agentConflictCount > 0 ? .danger : .positive
            )
        ]
    }

    private var configCardMetrics: [SidebarNavigationMetric] {
        [
            configSupportMetric(
                title: UIStrings.text("sidebar.config.scanShort", "Scan"),
                capabilities: [configCapability?.scan, configCapability?.projectScan]
            ),
            configSupportMetric(
                title: UIStrings.text("sidebar.config.toggleShort", "Toggle"),
                capabilities: [configCapability?.configToggle]
            ),
            configSupportMetric(
                title: UIStrings.text("sidebar.config.snapshotShort", "Snapshot"),
                capabilities: [configCapability?.configSnapshot]
            ),
            configSupportMetric(
                title: UIStrings.text("sidebar.config.writeShort", "Write"),
                capabilities: [configCapability?.writable]
            )
        ]
    }

    private func countTone(_ value: Int, active: SidebarNavigationMetricTone) -> SidebarNavigationMetricTone {
        value > 0 ? active : .muted
    }

    private func configSupportMetric(
        title: String,
        capabilities: [AdapterFeatureCapability?]
    ) -> SidebarNavigationMetric {
        let loadedCapabilities = capabilities.compactMap { $0 }
        guard !loadedCapabilities.isEmpty else {
            return SidebarNavigationMetric(title: title, value: "—", tone: .muted)
        }
        let supported = loadedCapabilities.filter(\.supported).count
        if supported == loadedCapabilities.count {
            return SidebarNavigationMetric(
                title: title,
                value: UIStrings.text("value.short.supported", "OK"),
                tone: .positive
            )
        }
        if supported > 0 {
            return SidebarNavigationMetric(
                title: title,
                value: UIStrings.text("value.short.partial", "Partial"),
                tone: .warning
            )
        }
        return SidebarNavigationMetric(
            title: title,
            value: UIStrings.text("value.short.notSupported", "No"),
            tone: .muted
        )
    }

    private var configStatusText: String? {
        configCapability?.status ?? UIStrings.notLoaded
    }

    private func selectSessions() {
        store.sidebarContentMode = .sessions
        if let session = store.selectedLocalSession ?? store.localSessionPreviewResult.sessionRows.first {
            store.selectLocalSession(session)
        } else {
            store.selectedSidebarSelection = nil
        }
        if !store.isPreviewingLocalSessions {
            Task { await store.refreshSelectedAgentLocalSessions() }
        }
    }

    private func selectSkills() {
        store.sidebarContentMode = .skills
        if let skill = store.selectedSkill {
            store.selectedSidebarSelection = .skill(skill.id)
        } else {
            store.selectedSidebarSelection = nil
        }
    }

    private func selectConfig() {
        store.sidebarContentMode = .config
        store.selectedSidebarSelection = .configOverview
    }

    private var sessionButtonSubtitle: String {
        if store.localSessionPreviewResult.count == 0 {
            return UIStrings.text("sidebar.mode.sessions.subtitle", "Local session analysis")
        }
        return UIStrings.text("sidebar.mode.sessions.loaded", "Local sessions")
    }

    private var skillButtonSubtitle: String {
        UIStrings.text("sidebar.mode.skills.subtitle", "Filter and manage skills")
    }
}

struct SecondarySidebarView: View {
    @EnvironmentObject private var store: SkillStore
    @State private var isBatchOperationPresented = false

    var body: some View {
        List(selection: $store.selectedSidebarSelection) {
            switch store.sidebarContentMode {
            case .sessions:
                SessionSidebarPanel()
            case .skills:
                SkillSidebarPanel(isBatchOperationPresented: $isBatchOperationPresented)
            case .config:
                ConfigSidebarPanel()
            }
        }
        .listStyle(.sidebar)
        .secondarySidebarPaneBackground()
        .navigationTitle("")
        .sheet(isPresented: $isBatchOperationPresented) {
            BatchSkillOperationSheet()
                .environmentObject(store)
        }
    }
}

private struct SecondarySidebarPaneBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                Rectangle()
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                            : AnyShapeStyle(.regularMaterial)
                    )
                    .ignoresSafeArea()
            }
    }
}

private extension View {
    func secondarySidebarPaneBackground() -> some View {
        modifier(SecondarySidebarPaneBackground())
    }
}

private struct SidebarNavigationMetric: Identifiable {
    let title: String
    let value: String
    var tone: SidebarNavigationMetricTone = .neutral

    var id: String { "\(title)-\(value)-\(tone)" }
}

private enum SidebarNavigationMetricTone: Hashable {
    case neutral
    case muted
    case info
    case positive
    case warning
    case danger

    var valueColor: Color {
        switch self {
        case .neutral:
            return .primary
        case .muted:
            return .secondary
        case .info:
            return .blue
        case .positive:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }

    var selectedValueColor: Color {
        switch self {
        case .neutral, .muted:
            return .white.opacity(0.9)
        case .info:
            return .cyan
        case .positive:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }
}

private struct SidebarFooterToolRow: View {
    @EnvironmentObject private var store: SkillStore
    let onOpenReport: () -> Void
    let onOpenPreflight: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SidebarFooterToolButton(
                title: UIStrings.text("sidebar.report.title", "Usage Report"),
                subtitle: UIStrings.text("sidebar.report.subtitle", "Local export"),
                systemImage: "square.and.arrow.down",
                accent: .green,
                badge: reportBadge,
                action: onOpenReport
            )

            SidebarFooterToolButton(
                title: UIStrings.taskCockpitTitle,
                subtitle: UIStrings.text("sidebar.preflight.subtitle", "Read-only task check"),
                systemImage: "checklist",
                accent: .accentColor,
                badge: UIStrings.text("sidebar.preflight.metric.readOnly", "Read-only"),
                action: onOpenPreflight
            )
        }
    }

    private var reportBadge: String {
        switch store.localReportFormat {
        case .markdown:
            return "MD"
        case .json:
            return "JSON"
        }
    }
}

private struct SidebarFooterToolButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let badge: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 7) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 22, height: 22)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Text(badge)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.10), in: Capsule())
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct SidebarNavigationCardButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let count: String?
    let metrics: [SidebarNavigationMetric]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 30, height: 30)
                        .background(iconBackground, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    if let count {
                        Text(count)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                if !metrics.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(metrics) { metric in
                            SidebarNavigationMetricPill(
                                metric: metric,
                                isSelected: isSelected
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor).opacity(0.72)
    }

    private var borderColor: Color {
        isSelected ? Color.accentColor.opacity(0.65) : Color.secondary.opacity(0.12)
    }

    private var iconBackground: Color {
        isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1)
    }

    private var iconColor: Color {
        isSelected ? .white : .accentColor
    }

    private var primaryTextColor: Color {
        isSelected ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isSelected ? Color.white.opacity(0.78) : .secondary
    }
}

private struct SidebarNavigationMetricPill: View {
    let metric: SidebarNavigationMetric
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text(metric.title)
                .foregroundStyle(labelColor)
                .lineLimit(1)
            Text(metric.value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            isSelected ? Color.white.opacity(0.16) : Color.secondary.opacity(0.08),
            in: Capsule()
        )
    }

    private var labelColor: Color {
        isSelected ? Color.white.opacity(0.72) : .secondary
    }

    private var valueColor: Color {
        isSelected ? metric.tone.selectedValueColor : metric.tone.valueColor
    }
}

private struct SessionSidebarPanel: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        Group {
            Section(UIStrings.text("sidebar.sessions.analysis", "Session Analysis")) {
                Label(UIStrings.text("sidebar.sessions.autoDiscovery", "Auto-discovered local sessions"), systemImage: "sparkle.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(UIStrings.text("sidebar.sessions.scope", "Scope"), selection: $store.localSessionScopeFilter) {
                    ForEach(LocalSessionScopeFilter.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)

                Button {
                    Task { await store.previewLocalSessions() }
                } label: {
                    Label(UIStrings.text("sidebar.sessions.preview", "Refresh Sessions"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isRefreshBusy || store.isPreviewingLocalSessions)

                if let message = sessionStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(UIStrings.text("sidebar.sessions.search", "Search sessions"), text: $store.localSessionSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
            }

            Section(UIStrings.text("sidebar.sessions.list", "Sessions")) {
                if store.localSessionPreviewResult.sessionRows.isEmpty {
                    SidebarEmptyMessage(message: UIStrings.text("sidebar.sessions.empty", "No local sessions found."))
                } else if store.filteredLocalSessionRows.isEmpty {
                    SidebarEmptyMessage(message: UIStrings.text("sidebar.sessions.noMatches", "No sessions match the current search."))
                } else {
                    ForEach(store.filteredLocalSessionRows) { session in
                        SessionSidebarRow(
                            session: session,
                            isSelected: store.selectedSidebarSelection == .session(session.id)
                        ) {
                            store.selectLocalSession(session)
                        }
                    }
                }
            }

            if !store.localSessionPreviewResult.skillUsageRows.isEmpty {
                Section(UIStrings.text("sidebar.sessions.topSkills", "Top skills from sessions")) {
                    ForEach(store.localSessionPreviewResult.skillUsageRows.prefix(3)) { row in
                        SidebarMetricRow(
                            title: row.skillName,
                            value: "\(row.callCount)",
                            systemImage: "square.stack.3d.up"
                        )
                    }
                }
            }
        }
    }

    private var sessionStatusMessage: String? {
        if store.isPreviewingLocalSessions {
            return UIStrings.loading
        }
        if let fallback = store.localSessionPreviewResult.fallbackReason, !fallback.isEmpty {
            return fallback
        }
        if store.localSessionPreviewResult.authorizationRequired {
            return UIStrings.text("sidebar.sessions.authorizationHint", "No supported local session store was found for the selected agent.")
        }
        return nil
    }

}

private struct SessionSidebarRow: View {
    let session: LocalSessionPreviewRow
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(2)
                    Text(sessionMetricSummary)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                        .lineLimit(1)
                    if let project = session.projectRoot, !project.isEmpty {
                        Text(project)
                            .font(.caption2)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.72) : Color.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7).fill(Color.accentColor)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.title)
    }

    private var sessionMetricSummary: String {
        "\(session.userMessageCount) \(UIStrings.text("sidebar.sessions.userShort", "user")) · \(session.toolCallCount) \(UIStrings.text("sidebar.sessions.toolShort", "tool")) · \(session.skillCallCount) \(UIStrings.text("sidebar.sessions.skillShort", "skill"))"
    }
}

private struct SidebarMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 17)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

private struct SkillSidebarPanel: View {
    @EnvironmentObject private var store: SkillStore
    @Binding var isBatchOperationPresented: Bool

    var body: some View {
        Section(UIStrings.text("nav.filter", "Filter")) {
            Picker(UIStrings.text("sidebar.skillFilter", "Filter"), selection: $store.stateFilter) {
                ForEach(SkillStateFilter.sidebarCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .controlSize(.small)

            Picker(UIStrings.text("sidebar.scopeFilter", "Scope"), selection: $store.skillScopeFilter) {
                ForEach(SkillScopeFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .controlSize(.small)

            Picker(UIStrings.sort, selection: $store.sortOrder) {
                ForEach(SkillSortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
            .controlSize(.small)

            Picker(UIStrings.text("sort.direction", "Direction"), selection: $store.sortDirection) {
                ForEach(SkillSortDirection.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .controlSize(.small)
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

    private var skillListSectionTitle: String {
        let count = store.filteredSkills.count
        if store.stateFilter == .all,
           store.skillScopeFilter == .all,
           store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return UIStrings.text("sidebar.currentAgentSkills", "\(store.agentFilter.title) Skills")
        }
        return UIStrings.text("sidebar.filteredAgentSkills", "\(store.agentFilter.title) Skills · \(count) shown")
    }

    private var skillListRefreshID: String {
        [
            store.agentFilter.rawValue,
            store.stateFilter.rawValue,
            store.skillScopeFilter.rawValue,
            store.sortOrder.rawValue,
            store.sortDirection.rawValue,
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

private struct ConfigSidebarPanel: View {
    @EnvironmentObject private var store: SkillStore

    private var capability: AdapterCapabilityRecord? {
        store.adapterCapabilities.first { $0.agent == store.agentFilter.rawValue }
    }

    private var selectedSnapshots: [ConfigSnapshotRecord] {
        store.agentConfigSnapshots
            .filter { snapshot in
                snapshot.agent == store.agentFilter.rawValue && store.configScopeFilter.includes(snapshot)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            Section {
                Button {
                    store.selectedSidebarSelection = .configOverview
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: SidebarContentMode.config.systemImage)
                            .foregroundStyle(store.selectedSidebarSelection == .configOverview ? .white.opacity(0.9) : .secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DisplayText.agent(store.agentFilter.rawValue))
                                .font(.caption.bold())
                                .foregroundStyle(store.selectedSidebarSelection == .configOverview ? .white : .primary)
                                .lineLimit(1)
                            Text(AgentConfigDisplay.shortTargetPath(for: store.agentFilter, store: store))
                                .font(.caption2)
                                .foregroundStyle(store.selectedSidebarSelection == .configOverview ? .white.opacity(0.8) : .secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Group {
                            if store.selectedSidebarSelection == .configOverview {
                                RoundedRectangle(cornerRadius: 7).fill(Color.accentColor)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tag(SidebarSelection.configOverview)
            }

            Section(UIStrings.text("sidebar.config.filters", "Config filters")) {
                Picker(UIStrings.scope, selection: $store.configScopeFilter) {
                    ForEach(AgentConfigScopeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .controlSize(.small)

                Button {
                    Task { await store.loadAgentConfigSnapshots(agent: store.agentFilter.rawValue) }
                } label: {
                    Label(UIStrings.reload, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isLoadingAgentConfigSnapshots || store.isWriting)
            }

            Section(UIStrings.text("sidebar.config.operations", "Supported operations")) {
                ConfigOperationRow(title: UIStrings.scan, capability: capability?.scan, systemImage: "magnifyingglass")
                ConfigOperationRow(title: UIStrings.projectScan, capability: capability?.projectScan, systemImage: "folder")
                ConfigOperationRow(title: UIStrings.configToggle, capability: capability?.configToggle, systemImage: "switch.2")
                ConfigOperationRow(title: UIStrings.configSnapshot, capability: capability?.configSnapshot, systemImage: "clock.arrow.circlepath")
                ConfigOperationRow(title: UIStrings.writableConfig, capability: capability?.writable, systemImage: "lock.open")
            }

            Section(UIStrings.agentConfigSettingsHistory) {
                if store.isLoadingAgentConfigSnapshots {
                    Label(UIStrings.loading, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if selectedSnapshots.isEmpty {
                    SidebarEmptyMessage(message: UIStrings.agentConfigHistoryEmpty(DisplayText.agent(store.agentFilter.rawValue)))
                } else {
                    ForEach(selectedSnapshots) { snapshot in
                        ConfigSnapshotSidebarRow(
                            item: AgentConfigTimelineItem(snapshot: snapshot),
                            isSelected: store.selectedSidebarSelection == .configSnapshot(snapshot.id)
                        ) {
                            store.selectConfigSnapshot(snapshot)
                        }
                    }
                }
            }
        }
        .task(id: store.agentFilter.rawValue) {
            await store.loadAgentConfigSnapshots(agent: store.agentFilter.rawValue)
            if store.agentFilter == .claudeCode, store.claudeSettings == nil {
                await store.loadClaudeSettings()
            }
        }
    }
}

private struct ConfigOperationRow: View {
    let title: String
    let capability: AdapterFeatureCapability?
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(AgentConfigDisplay.supportColor(capability))
                .frame(width: 17)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(capability?.status ?? UIStrings.notLoaded)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Image(systemName: AgentConfigDisplay.supportSymbol(capability))
                .foregroundStyle(AgentConfigDisplay.supportColor(capability))
        }
        .help(capability?.reason ?? capability?.status ?? "")
    }
}

private struct ConfigSnapshotSidebarRow: View {
    let item: AgentConfigTimelineItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.actionText)
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                    Text("\(item.timeText) · \(item.targetSummary)")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                        .lineLimit(1)
                        .help(item.targetSummary)
                }

                Spacer(minLength: 4)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7).fill(Color.accentColor)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.actionText)
    }
}

private struct AgentWorkspaceHeader: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        HStack(spacing: 8) {
            AgentIconBadge(filter: store.agentFilter)
                .fixedSize()

            VStack(alignment: .leading, spacing: 2) {
                Text(store.agentFilter.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                Text(UIStrings.text("sidebar.agentContext", "Agent"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 4)

            AgentSelectorMenu(width: 84)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text(UIStrings.agentConfigTimelineRollbackConfirm(
                AgentConfigDisplay.pathSummary(snapshotToRollback?.target ?? "")
            ))
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
                        .help(item.targetSummary)

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
