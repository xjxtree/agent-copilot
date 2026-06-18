import SwiftUI

struct AgentWorkspacePanel: View {
    var body: some View {
        AgentProfilePanel()
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
            }

            Text(UIStrings.text("agentCopilot.agentProfile.summary", "A focused read-only profile for the selected agent's catalog coverage, capability status, scan state, and MCP context."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            AgentProfileSummaryCard(agent: store.agentFilter, metrics: [
                AgentProfileMetric(title: UIStrings.skills, value: "\(agentSkillCount)", systemImage: "square.stack.3d.up"),
                AgentProfileMetric(title: UIStrings.text("agentCopilot.metric.enabled", "Enabled"), value: "\(agentEnabledCount)", systemImage: "checkmark.circle"),
                AgentProfileMetric(title: UIStrings.text("agentCopilot.metric.findings", "Issues"), value: "\(agentFindingCount)", systemImage: "exclamationmark.triangle"),
                AgentProfileMetric(title: UIStrings.text("agentCopilot.metric.risk", "Risk"), value: "\(agentRiskCount)", systemImage: "shield.lefthalf.filled"),
                AgentProfileMetric(title: UIStrings.text("agentCopilot.metric.conflicts", "Conflicts"), value: "\(agentConflictCount)", systemImage: "rectangle.2.swap")
            ])

            if let capability = store.selectedAdapterCapability {
                AgentCapabilitySummaryCard(capability: capability)
            }

            TaskCockpitPanel(
                taskText: $store.taskCockpitText,
                currentTaskText: store.selectedTaskCockpitInput,
                result: store.taskCockpitResult,
                isBuilding: store.isBuildingTaskCockpit,
                operationState: store.taskCockpitOperationState,
                onBuild: {
                    Task {
                        await store.buildTaskCockpit()
                    }
                },
                onCancel: {
                    store.cancelTaskCockpitBuild()
                }
            )

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

            LocalReportExportPanel(includeSelectedSkill: false)
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

private struct AgentProfileMetric: Identifiable {
    let title: String
    let value: String
    let systemImage: String

    var id: String { title }
}

private struct AgentProfileSummaryCard: View {
    let agent: SkillAgentFilter
    let metrics: [AgentProfileMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                AgentProfileIconBadge(filter: agent)
                Text(agent.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }

            AgentProfileMetricGrid(metrics: metrics)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct AgentProfileIconBadge: View {
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

private struct AgentProfileMetricGrid: View {
    let metrics: [AgentProfileMetric]

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(metrics) { metric in
                AgentProfileMetricCard(metric: metric)
            }
        }
    }
}

private struct AgentProfileMetricCard: View {
    let metric: AgentProfileMetric

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: metric.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(metric.value)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
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
                Label(UIStrings.text("mcpServerPreview.title", "MCP Sources"), systemImage: "server.rack")
                    .font(.callout.bold())
                Spacer()
                Text(UIStrings.text("mcpServerPreview.mode", "Explicit authorization"))
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.text("mcpServerPreview.boundary", "Preview is default-off: enter authorized MCP JSON config files explicitly. The preview reads redacted MCP server metadata only and never returns env values or raw config content."))
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
                    Label(UIStrings.text("mcpServerPreview.action", "Preview MCP Sources"), systemImage: "eye")
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

            DetailMetricGrid(minColumnWidth: 150, spacing: 8) {
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
