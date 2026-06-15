import SwiftUI

enum DetailSection: String, CaseIterable, Identifiable {
    case taskCockpit
    case validationWorkbench
    case overview
    case skillMap
    case cleanup
    case guidedCleanup
    case observability
    case findings
    case conflicts
    case history
    case analysis

    var id: String { rawValue }

    static var visibleCases: [DetailSection] {
        Self.allCases
    }

    static var primaryWorkCases: [DetailSection] {
        [.taskCockpit, .validationWorkbench, .skillMap, .guidedCleanup, .observability, .analysis]
    }

    var title: String {
        switch self {
        case .taskCockpit:
            return UIStrings.taskCockpitTitle
        case .validationWorkbench:
            return UIStrings.validationWorkbenchTitle
        case .overview:
            return UIStrings.overview
        case .skillMap:
            return UIStrings.text("detail.skillMap", "Skill Map")
        case .cleanup:
            return UIStrings.cleanupQueue
        case .guidedCleanup:
            return UIStrings.guidedCleanupFlowTitle
        case .observability:
            return UIStrings.providerObservabilityTitle
        case .findings:
            return UIStrings.findings
        case .conflicts:
            return UIStrings.text("detail.conflicts.sameAgentTab", "Same-agent Conflicts")
        case .history:
            return UIStrings.text("detail.history", "History")
        case .analysis:
            return UIStrings.text("detail.analysisReview", "Review")
        }
    }

    var systemImage: String {
        switch self {
        case .taskCockpit:
            return "rectangle.grid.2x2"
        case .validationWorkbench:
            return "checklist"
        case .overview:
            return "stethoscope"
        case .skillMap:
            return "point.3.connected.trianglepath.dotted"
        case .cleanup:
            return "tray.full"
        case .guidedCleanup:
            return "sparkles.square.filled.on.square"
        case .observability:
            return "waveform.path.ecg.rectangle"
        case .findings:
            return "exclamationmark.triangle"
        case .conflicts:
            return "rectangle.2.swap"
        case .history:
            return "clock.arrow.circlepath"
        case .analysis:
            return "doc.text.magnifyingglass"
        }
    }

    var summary: String {
        switch self {
        case .taskCockpit:
            return UIStrings.text("detail.section.taskCockpit.summary", "Start from the current task and review readiness, routes, agents, skills, session context, provider context, gaps, blockers, and evidence in one read-only cockpit.")
        case .validationWorkbench:
            return UIStrings.text("detail.section.validationWorkbench.summary", "Inspect real-local validation evidence standards, canonical blockers, and next-action guidance before UI closeout.")
        case .overview:
            return UIStrings.text("detail.section.overview.summary", "Inspect the selected skill metadata, permissions, provenance, and raw catalog details.")
        case .skillMap:
            return UIStrings.text("detail.section.skillMap.summary", "Review the local skill map and lifecycle timeline derived from existing catalog, task, risk, provenance, and history evidence.")
        case .cleanup:
            return UIStrings.text("detail.section.cleanup.summary", "Review the read-only Cleanup Queue for open findings, integrity issues, conflicts, and analysis insights.")
        case .guidedCleanup:
            return UIStrings.text("detail.section.guidedCleanup.summary", "Plan guided cleanup steps and record app-local redacted step metadata without applying fixes or changing agent config.")
        case .observability:
            return UIStrings.text("detail.section.observability.summary", "Inspect redacted app-local provider call and prompt-run metadata without sending provider requests.")
        case .findings:
            return UIStrings.text("detail.section.findings.summary", "Explain selected-skill finding groups with rules, affected instances, remediation text, and evidence.")
        case .conflicts:
            return UIStrings.text("detail.section.conflicts.summary", "Review current-agent runtime/name collisions only; cross-agent duplicate and source-overlap evidence stays in Review.")
        case .history:
            return UIStrings.text("detail.section.history.summary", "Review selected-skill toggle and config history.")
        case .analysis:
            return UIStrings.text("detail.section.analysis.summary", "Use focused review panels for cross-agent comparison, quality, task fit, routing, and session skill-use review.")
        }
    }
}

struct SkillSummaryCard: View {
    let skill: SkillRecord
    let detail: SkillDetailRecord?
    let scriptPreview: ScriptExecutionPreview?
    let isLoading: Bool
    @AppStorage(DisplayText.screenshotPrivacyModeStorageKey) private var screenshotPrivacyModeEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.text("detail.diagnosticOverview", "Diagnostic Overview"), systemImage: "stethoscope")
                    .font(.headline)
                Spacer()
                if isLoading {
                    Label(UIStrings.loadingSkillDetail, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(summaryText)
                .font(.callout)
                .foregroundStyle(summaryText == UIStrings.noDescription ? .secondary : .primary)
                .lineLimit(nil)
                .textSelection(.enabled)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.agent, value: DisplayText.agent(skill.agent), systemImage: "person.crop.circle")
                SummaryChip(title: UIStrings.scope, value: DisplayText.scope(for: skill), systemImage: "folder")
                SummaryChip(title: UIStrings.provenanceRoot, value: SkillProvenanceDisplay.rootClass(for: skill), systemImage: "externaldrive")
                SummaryChip(title: UIStrings.provenanceKind, value: SkillProvenanceDisplay.kind(for: skill), systemImage: "tag")
                SummaryChip(title: UIStrings.definition, value: skill.definitionId, systemImage: "number")
                SummaryChip(title: UIStrings.source, value: DisplayText.privacyPath(skill.displayPath, privacyModeEnabled: screenshotPrivacyModeEnabled), systemImage: "doc")
            }

            OverviewRiskPanel(
                permissionSummary: PermissionDisplayModel.summary(for: detail?.permissions ?? .null),
                scriptPreview: scriptPreview
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var summaryText: String {
        guard let description = detail?.description.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty else {
            return UIStrings.noDescription
        }
        return description
    }
}

struct CleanupQueueSection: View {
    let result: CleanupQueueResult
    let items: [CleanupQueueItem]
    @Binding var kindFilter: CleanupQueueKindFilter
    @Binding var priorityFilter: CleanupQueuePriorityFilter
    let agentTitle: String
    let isLoading: Bool
    let onOpen: (CleanupQueueItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label(UIStrings.cleanupQueue, systemImage: "tray.full")
                        .font(.headline)
                    Spacer()
                    if isLoading {
                        Label(UIStrings.loading, systemImage: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(UIStrings.cleanupQueueReadOnlyBoundary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                    SummaryChip(title: UIStrings.text("cleanup.summary.total", "Open queue"), value: "\(result.summary.total)", systemImage: "number")
                    SummaryChip(title: CleanupQueueKind.finding.title, value: "\(result.summary.findingCount)", systemImage: CleanupQueueKind.finding.systemImage)
                    SummaryChip(title: CleanupQueueKind.integrity.title, value: "\(result.summary.integrityCount)", systemImage: CleanupQueueKind.integrity.systemImage)
                    SummaryChip(title: CleanupQueueKind.conflict.title, value: "\(result.summary.conflictCount)", systemImage: CleanupQueueKind.conflict.systemImage)
                    SummaryChip(title: CleanupQueueKind.analysis.title, value: "\(result.summary.analysisCount)", systemImage: CleanupQueueKind.analysis.systemImage)
                }

                HStack {
                    Picker(UIStrings.cleanupFilterKind, selection: $kindFilter) {
                        ForEach(CleanupQueueKindFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker(UIStrings.cleanupFilterPriority, selection: $priorityFilter) {
                        ForEach(CleanupQueuePriorityFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    Text(UIStrings.cleanupAgentFilterNote(agentTitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            if let fallbackReason = result.fallbackReason ?? result.summary.unavailableReason {
                CleanupNoticeCard(message: fallbackReason)
            }

            if items.isEmpty {
                CleanupEmptyCard(
                    title: UIStrings.cleanupEmptyTitle,
                    message: result.summary.total == 0 ? UIStrings.cleanupEmptyMessage : UIStrings.cleanupNoFilteredItems
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        CleanupQueueItemCard(item: item, onOpen: { onOpen(item) })
                    }
                }
            }
        }
    }
}

private struct CleanupQueueItemCard: View {
    let item: CleanupQueueItem
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.kind.systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.priority.title)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(priorityTint.opacity(0.16), in: Capsule())
                            .foregroundStyle(priorityTint)
                    }

                    Text(affectedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !item.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(item.detail)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }

                Spacer()
            }

            HStack(alignment: .center, spacing: 10) {
                Label(item.kind.title, systemImage: item.kind.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SafetyPill(label: UIStrings.readOnlyPreview, isBlocked: item.readOnly)
                SafetyPill(label: UIStrings.executionBlocked, isBlocked: item.scriptExecutionBlocked)
                SafetyPill(label: UIStrings.cleanupAIBlocked, isBlocked: item.aiProviderCallBlocked)
                SafetyPill(label: UIStrings.cleanupCredentialsBlocked, isBlocked: item.credentialStorageBlocked)

                Spacer()

                Button(item.nextActionLabel) {
                    onOpen()
                }
                .controlSize(.small)
                .help(UIStrings.cleanupOpenExistingDetailHelp)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var affectedLabel: String {
        let values = [
            item.skillName?.trimmingCharacters(in: .whitespacesAndNewlines),
            item.agent.map(DisplayText.agent),
            item.skillScope.map(DisplayText.scope),
        ]
        let label = values.compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
        return label.isEmpty ? UIStrings.unknown : label
    }

    private var priorityTint: Color {
        switch item.priority {
        case .critical, .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        case .info, .unknown:
            return .secondary
        }
    }
}

private struct CleanupNoticeCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
    }
}

private struct CleanupEmptyCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "checkmark.seal")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct OverviewRiskPanel: View {
    let permissionSummary: PermissionSummary
    let scriptPreview: ScriptExecutionPreview?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.text("detail.permissionScriptRisk", "Permissions & script risk"), systemImage: "shield.lefthalf.filled")
                    .font(.subheadline.bold())
                Spacer()
                Label(scriptState, systemImage: scriptPreview == nil ? "nosign" : "checkmark.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(permissionSummary.rows.prefix(5)) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(row.value)
                            .font(.caption.bold())
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Text(permissionSummary.note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    private var scriptState: String {
        if let preview = scriptPreview {
            return preview.executionAllowed ? UIStrings.executionBlocked : UIStrings.scriptExecutionPreviewOnly
        }
        return UIStrings.scriptExecutionPreviewOnly
    }
}

struct DetailSectionSwitcher: View {
    @Binding var selection: DetailSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(UIStrings.detailSection, systemImage: selection.systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Picker(UIStrings.detailSection, selection: $selection) {
                    ForEach(DetailSection.visibleCases) { item in
                        Label(item.title, systemImage: item.systemImage).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 240, alignment: .leading)

                Spacer()
            }

            Text(selection.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}
