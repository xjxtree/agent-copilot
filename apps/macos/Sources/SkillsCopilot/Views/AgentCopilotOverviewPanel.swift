import SwiftUI

struct AgentCopilotOverviewPanel: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(UIStrings.text("agentCopilot.overview.title", "Agent Copilot Overview"), systemImage: "rectangle.3.group")
                    .font(.title3.bold())
                Spacer()
                Text(UIStrings.text("agentCopilot.overview.mode", "Read-only awareness"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }

            Text(UIStrings.text("agentCopilot.overview.summary", "A decision-first view of the local agent lineup, derived from catalog, health, cleanup, provider, and task evidence. Actions here only navigate to existing evidence surfaces."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.text("agentCopilot.metric.agents", "Agents"), value: "\(agentSnapshots.count)", systemImage: "person.2")
                SummaryChip(title: UIStrings.skills, value: "\(store.healthSummary.totalCount)", systemImage: "square.stack.3d.up")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.enabled", "Enabled"), value: "\(store.healthSummary.enabledCount)", systemImage: "checkmark.circle")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.findings", "Finding groups"), value: "\(store.healthSummary.findingCount)", systemImage: "exclamationmark.triangle")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.conflicts", "Conflicts"), value: "\(store.sameAgentRuntimeConflictCount)", systemImage: "rectangle.2.swap")
                SummaryChip(title: UIStrings.cleanupQueue, value: "\(store.cleanupQueue.items.count)", systemImage: "tray.full")
            }

            AgentDecisionCardStack(
                decisions: decisions,
                onOpen: openDecision(_:)
            )

            VStack(alignment: .leading, spacing: 10) {
                Label(UIStrings.text("agentCopilot.lineup.title", "Agent Lineup"), systemImage: "person.crop.rectangle.stack")
                    .font(.headline)

                ForEach(agentSnapshots) { snapshot in
                    AgentLineupRow(snapshot: snapshot) {
                        store.agentFilter = snapshot.filter
                        store.selectedDetailSection = .agentProfile
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
        }
    }

    private var agentSnapshots: [AgentLineupSnapshot] {
        SkillAgentFilter.managementCases.map { filter in
            let health = store.healthSummary.agentSummaries.first { $0.agent == filter.rawValue }
            let capability = store.adapterCapabilities.first { $0.agent == filter.rawValue }
            let refresh = store.lastScanActivity?.agentSummaries?.first { $0.agent == filter.rawValue }
            let skills = store.skills.filter { filter.includes($0) }
            return AgentLineupSnapshot(
                filter: filter,
                skillCount: health?.totalCount ?? skills.count,
                enabledCount: health?.enabledCount ?? skills.filter { $0.enabled }.count,
                findingCount: health?.findingCount ?? 0,
                conflictCount: health?.conflictCount ?? 0,
                riskCount: health?.riskCount ?? 0,
                capabilityStatus: capability?.status ?? UIStrings.text("agentCopilot.status.unknown", "unknown"),
                scanStatus: refresh?.status,
                blockers: capability?.blockers ?? []
            )
        }
    }

    private var decisions: [AgentDecisionItem] {
        var items: [AgentDecisionItem] = []

        if store.healthSummary.needsTriageCount > 0 {
            items.append(AgentDecisionItem(
                id: "risk",
                title: UIStrings.text("agentCopilot.decision.risk.title", "Review the highest-risk evidence"),
                detail: String(
                    format: UIStrings.text("agentCopilot.decision.risk.detail", "%d health signals need review across findings, conflicts, malformed entries, or risk tags."),
                    store.healthSummary.needsTriageCount
                ),
                status: UIStrings.text("agentCopilot.status.review", "Review"),
                systemImage: "exclamationmark.triangle",
                priority: .critical,
                impactScore: store.healthSummary.needsTriageCount,
                evidenceRefs: AgentCopilotDecisionModel.refs(
                    "health.needs_triage:\(store.healthSummary.needsTriageCount)",
                    "finding_groups:\(store.healthSummary.findingCount)",
                    "same_agent_conflicts:\(store.sameAgentRuntimeConflictCount)"
                ),
                target: .review
            ))
        }

        if store.cleanupQueue.items.isEmpty {
            items.append(AgentDecisionItem(
                id: "cleanup-empty",
                title: UIStrings.text("agentCopilot.decision.cleanupEmpty.title", "Cleanup pressure is currently low"),
                detail: UIStrings.text("agentCopilot.decision.cleanupEmpty.detail", "No cleanup queue items are loaded for the current catalog snapshot."),
                status: UIStrings.text("agentCopilot.status.watch", "Watch"),
                systemImage: "checkmark.seal",
                priority: .watch,
                impactScore: store.healthSummary.totalCount,
                evidenceRefs: AgentCopilotDecisionModel.refs(
                    "cleanup.queue.items:0",
                    "catalog.skills:\(store.healthSummary.totalCount)"
                ),
                target: .guidedCleanup
            ))
        } else {
            items.append(AgentDecisionItem(
                id: "cleanup",
                title: UIStrings.text("agentCopilot.decision.cleanup.title", "Inspect cleanup candidates"),
                detail: String(
                    format: UIStrings.text("agentCopilot.decision.cleanup.detail", "%d cleanup queue items can be reviewed through read-only guidance before any explicit safe action."),
                    store.cleanupQueue.items.count
                ),
                status: UIStrings.text("agentCopilot.status.queue", "Queue"),
                systemImage: "tray.full",
                priority: .high,
                impactScore: store.cleanupQueue.items.count,
                evidenceRefs: AgentCopilotDecisionModel.refs(
                    "cleanup.queue.items:\(store.cleanupQueue.items.count)",
                    "cleanup.findings:\(store.cleanupQueue.summary.findingCount)",
                    "cleanup.conflicts:\(store.cleanupQueue.summary.conflictCount)"
                ),
                target: .guidedCleanup
            ))
        }

        if let recommendedAgent = store.taskCockpitResult?.summary.recommendedAgent, !recommendedAgent.isEmpty {
            items.append(AgentDecisionItem(
                id: "task-route",
                title: UIStrings.text("agentCopilot.decision.taskRoute.title", "Latest task route has a leading agent"),
                detail: String(
                    format: UIStrings.text("agentCopilot.decision.taskRoute.detail", "Task Cockpit currently recommends %@ from local routing evidence."),
                    DisplayText.agent(recommendedAgent)
                ),
                status: UIStrings.text("agentCopilot.status.route", "Route"),
                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                priority: .high,
                impactScore: (store.taskCockpitResult?.summary.routingScore ?? 0) + (store.taskCockpitResult?.summary.readinessScore ?? 0),
                evidenceRefs: AgentCopilotDecisionModel.refs(
                    "task.recommended_agent:\(DisplayText.agent(recommendedAgent))",
                    store.taskCockpitResult?.summary.recommendedSkillName.map { "task.recommended_skill:\($0)" },
                    store.taskCockpitResult.map { "task.evidence_refs:\($0.summary.evidenceCount)" },
                    store.taskCockpitResult.map { "task.blockers:\($0.summary.blockerCount)" }
                ),
                target: .taskCockpit
            ))
        } else {
            items.append(AgentDecisionItem(
                id: "task-build",
                title: UIStrings.text("agentCopilot.decision.taskBuild.title", "Build a task route when you have a concrete job"),
                detail: UIStrings.text("agentCopilot.decision.taskBuild.detail", "Task Cockpit compares readiness, routing, session review, provider context, gaps, and blockers without sending a provider request."),
                status: UIStrings.text("agentCopilot.status.ready", "Ready"),
                systemImage: "rectangle.grid.2x2",
                priority: .medium,
                impactScore: store.healthSummary.enabledCount,
                evidenceRefs: AgentCopilotDecisionModel.refs(
                    "task.cockpit.ready:true",
                    "catalog.enabled_skills:\(store.healthSummary.enabledCount)"
                ),
                target: .taskCockpit
            ))
        }

        if let providerSummary = store.providerObservabilityResult?.summary, providerSummary.callCount > 0 {
            items.append(AgentDecisionItem(
                id: "provider",
                title: UIStrings.text("agentCopilot.decision.provider.title", "Provider activity is available for review"),
                detail: String(
                    format: UIStrings.text("agentCopilot.decision.provider.detail", "%d redacted prompt/provider metadata rows are available in Provider Observability."),
                    providerSummary.callCount
                ),
                status: UIStrings.text("agentCopilot.status.observe", "Observe"),
                systemImage: "waveform.path.ecg.rectangle",
                priority: providerSummary.failureCount > 0 || providerSummary.errorCount > 0 ? .high : .medium,
                impactScore: providerSummary.failureCount + providerSummary.errorCount + providerSummary.blockedCount,
                evidenceRefs: AgentCopilotDecisionModel.refs(
                    "provider.calls:\(providerSummary.callCount)",
                    "provider.failures:\(providerSummary.failureCount)",
                    "provider.errors:\(providerSummary.errorCount)"
                ),
                target: .providerObservability
            ))
        }

        return AgentCopilotDecisionModel.sorted(items)
    }

    private func openDecision(_ item: AgentDecisionItem) {
        switch item.target {
        case .taskCockpit:
            store.selectedDetailSection = .taskCockpit
        case .review:
            store.selectedDetailSection = .analysis
        case .guidedCleanup:
            store.selectedDetailSection = .guidedCleanup
        case .providerObservability:
            store.selectedDetailSection = .observability
        }
    }
}

struct AgentProfilePanel: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(UIStrings.text("agentCopilot.agentProfile.title", "Agent Profile"), systemImage: "person.crop.rectangle.stack")
                    .font(.title3.bold())
                Spacer()
                Picker(UIStrings.agent, selection: $store.agentFilter) {
                    ForEach(SkillAgentFilter.managementCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .labelsHidden()
                .frame(width: 190)
            }

            Text(UIStrings.text("agentCopilot.agentProfile.summary", "A focused read-only profile for the selected agent's catalog coverage, capability status, scan state, and nearby evidence surfaces."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.agent, value: store.agentFilter.title, systemImage: "person.crop.circle")
                SummaryChip(title: UIStrings.skills, value: "\(agentSkillCount)", systemImage: "square.stack.3d.up")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.enabled", "Enabled"), value: "\(agentEnabledCount)", systemImage: "checkmark.circle")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.findings", "Finding groups"), value: "\(agentFindingCount)", systemImage: "exclamationmark.triangle")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.conflicts", "Conflicts"), value: "\(agentConflictCount)", systemImage: "rectangle.2.swap")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.risk", "Risk"), value: "\(agentRiskCount)", systemImage: "shield.lefthalf.filled")
            }

            if let capability = store.selectedAdapterCapability {
                AgentCapabilitySummaryCard(capability: capability)
            }

            if let summary = store.selectedAgentRefreshSummary {
                AgentScanSummaryCard(summary: summary)
            }

            McpServerPreviewPanel(
                paths: $store.mcpServerPreviewPaths,
                result: store.mcpServerPreviewResult,
                isPreviewing: store.isPreviewingMcpServers
            ) {
                Task { await store.previewMcpServers() }
            }

            AgentProfileNavigationGrid { section in
                store.selectedDetailSection = section
            }
        }
    }

    private var agentSkills: [SkillRecord] {
        store.skills.filter { store.agentFilter.includes($0) }
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

    private var agentRiskCount: Int {
        store.selectedAgentHealthSummary?.riskCount ?? 0
    }
}

private struct McpServerPreviewPanel: View {
    @Binding var paths: String
    let result: McpServerPreviewResult
    let isPreviewing: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.text("mcpServerPreview.title", "MCP Server Sources"), systemImage: "server.rack")
                    .font(.callout.bold())
                Spacer()
                Text(UIStrings.text("mcpServerPreview.mode", "Explicit authorization"))
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.text("mcpServerPreview.boundary", "Preview is default-off: enter authorized MCP JSON config files explicitly. The preview reads redacted server metadata only and never returns env values or raw config content."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(UIStrings.text("mcpServerPreview.placeholder", "One authorized MCP config file per line"), text: $paths, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.text("mcpServerPreview.action", "Preview MCP Servers"), systemImage: "eye")
                }
                .disabled(isPreviewing)

                if isPreviewing {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if result.authorizationRequired {
                Label(UIStrings.text("mcpServerPreview.authorizationRequired", "No MCP config file is authorized, so no default agent or desktop config location was scanned."), systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(result.gapNotes.prefix(2), id: \.self) { note in
                PrivacyEvidenceText(value: note, font: .caption, lineLimit: 2)
            }

            ForEach(result.blockerNotes.prefix(2), id: \.self) { note in
                PrivacyEvidenceText(value: note, font: .caption, lineLimit: 2)
            }

            if !result.authorizedPaths.isEmpty {
                DenseDisclosureList(result.authorizedPaths.map(pathLabel), visibleLimit: 3, spacing: 4) { path in
                    PrivacyEvidenceText(value: path, font: .caption2, lineLimit: 1)
                }
            }

            if result.serverRows.isEmpty {
                Text(result.fallbackReason ?? UIStrings.text("mcpServerPreview.noRows", "No redacted MCP server previews are loaded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(result.serverRows.prefix(6)) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(row.name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(row.transport)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            PrivacyEvidenceText(value: row.sourcePath, font: .caption2, lineLimit: 1)
                            if let command = row.command, !command.isEmpty {
                                PrivacyEvidenceText(value: command, font: .caption2, lineLimit: 1)
                            }
                            Text(String(format: UIStrings.text("mcpServerPreview.counts", "Args: %d · Env keys: %d"), row.argsCount, row.envKeyCount))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private func pathLabel(_ path: McpServerPreviewPath) -> String {
        if let blocker = path.blocker, !blocker.isEmpty {
            return "\(path.path) · \(path.status) · \(blocker)"
        }
        return "\(path.path) · \(path.status) · \(path.serverCount)"
    }
}

private struct AgentLineupSnapshot: Identifiable, Hashable {
    let filter: SkillAgentFilter
    let skillCount: Int
    let enabledCount: Int
    let findingCount: Int
    let conflictCount: Int
    let riskCount: Int
    let capabilityStatus: String
    let scanStatus: String?
    let blockers: [String]

    var id: String { filter.rawValue }
}

private struct AgentDecisionCardStack: View {
    let decisions: [AgentDecisionItem]
    let onOpen: (AgentDecisionItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.text("agentCopilot.decisions.title", "Decision Queue"), systemImage: "sparkles")
                .font(.headline)

            ForEach(decisions) { item in
                AgentDecisionRow(item: item) {
                    onOpen(item)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct AgentDecisionRow: View {
    let item: AgentDecisionItem
    let action: () -> Void

    private var tint: Color {
        switch item.target {
        case .taskCockpit:
            return .accentColor
        case .review:
            return .orange
        case .guidedCleanup:
            return item.priority == .watch ? .green : .blue
        case .providerObservability:
            return .teal
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    Text(item.status)
                        .font(.caption2.bold())
                        .foregroundStyle(tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.12), in: Capsule())
                }

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                if item.hasEvidence {
                    DenseDisclosureList(item.evidenceRefs, visibleLimit: 3, spacing: 4) { evidenceRef in
                        PrivacyEvidenceText(value: evidenceRef, font: .caption2, lineLimit: 1)
                    }
                } else {
                    Text(UIStrings.text("agentCopilot.decision.noEvidence", "Evidence insufficient"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                action()
            } label: {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(.borderless)
            .help(UIStrings.text("agentCopilot.openEvidence", "Open evidence surface"))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AgentLineupRow: View {
    let snapshot: AgentLineupSnapshot
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.filter.title)
                    .font(.callout.weight(.semibold))
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 8) {
                AgentLineupMetric(title: UIStrings.skills, value: snapshot.skillCount)
                AgentLineupMetric(title: UIStrings.text("agentCopilot.metric.enabled", "Enabled"), value: snapshot.enabledCount)
                AgentLineupMetric(title: UIStrings.text("agentCopilot.metric.findings", "Findings"), value: snapshot.findingCount)
                AgentLineupMetric(title: UIStrings.text("agentCopilot.metric.conflicts", "Conflicts"), value: snapshot.conflictCount)
            }

            Button {
                action()
            } label: {
                Image(systemName: "person.crop.rectangle")
            }
            .buttonStyle(.borderless)
            .help(UIStrings.text("agentCopilot.openAgentProfile", "Open agent profile"))
        }
        .padding(10)
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusText: String {
        let scan = snapshot.scanStatus.map { "\(UIStrings.text("agentCopilot.scan", "scan")): \($0)" }
        let blocker = snapshot.blockers.first.map { "\(UIStrings.text("agentCopilot.blocker", "blocker")): \($0)" }
        return [snapshot.capabilityStatus, scan, blocker].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct AgentLineupMetric: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(value)")
                .font(.caption.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 54, alignment: .trailing)
    }
}

private struct AgentCapabilitySummaryCard: View {
    let capability: AdapterCapabilityRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(UIStrings.text("agentCopilot.capability.title", "Capability"), systemImage: "switch.2")
                    .font(.headline)
                Spacer()
                Text(capability.status)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                CapabilityPill(title: UIStrings.scan, capability: capability.scan)
                CapabilityPill(title: UIStrings.text("agentCopilot.projectScan", "Project Scan"), capability: capability.projectScan)
                CapabilityPill(title: UIStrings.text("agentCopilot.toggle", "Toggle"), capability: capability.configToggle)
                CapabilityPill(title: UIStrings.text("agentCopilot.install", "Install"), capability: capability.install)
                CapabilityPill(title: UIStrings.text("agentCopilot.writable", "Writable"), capability: capability.writable)
            }

            if !capability.blockers.isEmpty {
                Text(capability.blockers.prefix(3).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct CapabilityPill: View {
    let title: String
    let capability: AdapterFeatureCapability

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Label(capability.supported ? UIStrings.text("agentCopilot.supported", "Supported") : UIStrings.text("agentCopilot.blocked", "Blocked"), systemImage: capability.supported ? "checkmark.circle.fill" : "lock.fill")
                .font(.caption.bold())
                .foregroundStyle(capability.supported ? Color.green : Color.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .help(capability.reason ?? capability.status)
    }
}

private struct AgentScanSummaryCard: View {
    let summary: AgentRefreshSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(UIStrings.text("agentCopilot.scanSummary.title", "Latest Scan"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                Spacer()
                Text(summary.status)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                SummaryChip(title: UIStrings.text("agentCopilot.metric.scanned", "Scanned"), value: "\(summary.scannedCount)", systemImage: "magnifyingglass")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.catalog", "Catalog"), value: "\(summary.catalogCount)", systemImage: "tray.full")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.broken", "Broken"), value: "\(summary.brokenCount)", systemImage: "exclamationmark.octagon")
                SummaryChip(title: UIStrings.text("agentCopilot.metric.roots", "Roots"), value: "\(summary.rootsConsidered.count)", systemImage: "externaldrive")
            }

            if !summary.recoveryActions.isEmpty {
                Text(summary.recoveryActions.prefix(3).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct AgentProfileNavigationGrid: View {
    let open: (DetailSection) -> Void

    private let sections: [DetailSection] = [.taskCockpit, .skillMap, .guidedCleanup, .observability, .analysis, .validationWorkbench]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.text("agentCopilot.evidenceSurfaces", "Evidence Surfaces"), systemImage: "arrowshape.turn.up.right")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(sections) { section in
                    Button {
                        open(section)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(section.title)
                                    .font(.callout.weight(.semibold))
                                Text(section.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        } icon: {
                            Image(systemName: section.systemImage)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}
