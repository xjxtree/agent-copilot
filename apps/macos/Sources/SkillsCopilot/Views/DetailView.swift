import AppKit
import SwiftUI

enum DetailSection: String, CaseIterable, Identifiable {
    case overview
    case cleanup
    case findings
    case conflicts
    case history
    case analysis

    var id: String { rawValue }

    static var visibleCases: [DetailSection] {
        Self.allCases
    }

    var title: String {
        switch self {
        case .overview:
            return UIStrings.overview
        case .cleanup:
            return UIStrings.cleanupQueue
        case .findings:
            return UIStrings.findings
        case .conflicts:
            return UIStrings.text("detail.conflicts.sameAgentTab", "Same-agent Conflicts")
        case .history:
            return UIStrings.text("detail.history", "History")
        case .analysis:
            return UIStrings.text("detail.analysis", "Analysis")
        }
    }
}

struct DetailView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let skill: SkillRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let error = store.errorMessage {
                    ErrorBanner(message: error)
                }

                if let message = store.lastMutationMessage {
                    SuccessBanner(message: message)
                }

                if let skill {
                    let selectedFindingGroups = FindingDisplayModel.issueGroups(
                        findings: store.selectedFindings,
                        severityFilter: FindingDisplayModel.allFilterValue,
                        ruleFilter: FindingDisplayModel.allFilterValue
                    )
                    HeaderView(
                        skill: skill,
                        detail: store.selectedSkillDetail,
                        findingCount: selectedFindingGroups.count,
                        conflictCount: store.selectedConflicts.count,
                        isWriting: store.isWriting,
                        llmStatus: store.llmStatus,
                        adapterCapability: store.adapterCapabilities.first { $0.agent == skill.agent },
                        onSelectSection: { section in
                            store.selectedDetailSection = section
                        },
                        onToggle: { on in
                            Task { await store.toggleSelectedSkill(on: on) }
                        }
                    )

                    DetailSectionSwitcher(selection: $store.selectedDetailSection)

                    switch store.selectedDetailSection {
                    case .overview:
                        VStack(alignment: .leading, spacing: 16) {
                            SkillSummaryCard(
                                skill: skill,
                                detail: store.selectedSkillDetail,
                                scriptPreview: store.scriptExecutionPreview(for: skill),
                                isLoading: store.isLoadingDetail
                            )

                            DisclosureGroup {
                            SkillDetailCard(
                                skill: skill,
                                detail: store.selectedSkillDetail,
                                adapterCapability: store.adapterCapabilities.first { $0.agent == skill.agent },
                                isLoading: store.isLoadingDetail
                            )
                            .padding(.top, 12)
                            } label: {
                                Label(UIStrings.text("detail.rawDetails", "Raw Catalog Details"), systemImage: "doc.text.magnifyingglass")
                                    .font(.headline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .adaptiveMaterialSurface()

                            if DisplayText.isToolGlobal(skill) {
                                ToolGlobalPreviewCard(skill: skill)
                            }
                        }
                    case .cleanup:
                        CleanupQueueSection(
                            result: store.cleanupQueue,
                            items: store.filteredCleanupQueueItems,
                            kindFilter: $store.cleanupKindFilter,
                            priorityFilter: $store.cleanupPriorityFilter,
                            agentTitle: store.agentFilter.title,
                            isLoading: store.isLoadingCleanupQueue,
                            onOpen: { item in
                                store.openCleanupQueueItem(item)
                            }
                        )
                    case .findings:
                        FindingsSection(skill: skill, findings: store.selectedFindings)
                    case .conflicts:
                        ConflictsSection(
                            conflicts: store.selectedConflicts,
                            selectedSkillID: skill.id,
                            currentAgentSkillIDs: Set(store.skills.filter { $0.agent == skill.agent }.map(\.id))
                        )
                    case .history:
                        HistorySection(
                            events: store.selectedSkillEvents,
                            isLoading: store.isLoadingSelectedSkillEvents
                        )
                    case .analysis:
                        AnalysisSection(
                            skill: skill,
                            comparisonResult: store.crossAgentComparisons,
                            selectedComparisonGroup: store.selectedCrossAgentComparisonGroup,
                            isLoadingComparisons: store.isLoadingCrossAgentComparisons,
                            agentTitle: store.agentFilter.title,
                            llmStatus: store.llmStatus,
                            qualityScore: { skill in store.skillQualityScore(for: skill) },
                            isScoringQuality: { skill in store.isScoringSkillQuality(for: skill) },
                            qualityPromptPreview: { skill in store.skillQualityPromptPreview(for: skill) },
                            isPreviewingQualityPrompt: { skill in store.isPreviewingSkillQualityPrompt(for: skill) },
                            isSendingQualityPrompt: { skill in store.isSendingSkillQualityPrompt(for: skill) },
                            qualityPromptSendResult: { skill in store.skillQualityPromptSendResult(for: skill) },
                            canSendQualityPrompt: { skill in store.canSendSkillQualityPrompt(for: skill) },
                            taskReadinessText: $store.taskReadinessText,
                            taskReadinessResult: { skill in store.taskReadiness(for: skill) },
                            isCheckingTaskReadiness: { skill in store.isCheckingTaskReadiness(for: skill) },
                            taskReadinessPromptPreview: { skill in store.taskReadinessPromptPreview(for: skill) },
                            isPreviewingTaskReadinessPrompt: { skill in store.isPreviewingTaskReadinessPrompt(for: skill) },
                            isSendingTaskReadinessPrompt: { skill in store.isSendingTaskReadinessPrompt(for: skill) },
                            taskReadinessPromptSendResult: { skill in store.taskReadinessPromptSendResult(for: skill) },
                            canSendTaskReadinessPrompt: { skill in store.canSendTaskReadinessPrompt(for: skill) },
                            routingConfidenceText: $store.routingConfidenceText,
                            routingConfidenceResult: { skill in store.routingConfidence(for: skill) },
                            isRankingRoutingConfidence: { skill in store.isRankingRoutingConfidence(for: skill) },
                            routingConfidencePromptPreview: { skill in store.routingConfidencePromptPreview(for: skill) },
                            isPreviewingRoutingConfidencePrompt: { skill in store.isPreviewingRoutingConfidencePrompt(for: skill) },
                            isSendingRoutingConfidencePrompt: { skill in store.isSendingRoutingConfidencePrompt(for: skill) },
                            routingConfidencePromptSendResult: { skill in store.routingConfidencePromptSendResult(for: skill) },
                            canSendRoutingConfidencePrompt: { skill in store.canSendRoutingConfidencePrompt(for: skill) },
                            onScoreQuality: {
                                Task {
                                    await store.scoreSelectedSkillQuality()
                                }
                            },
                            onPreviewQualityPrompt: {
                                Task {
                                    await store.previewPromptForSelectedSkillQuality()
                                }
                            },
                            onSendQualityPrompt: {
                                Task {
                                    await store.confirmPromptForSelectedSkillQuality()
                                }
                            },
                            onCheckTaskReadiness: {
                                Task {
                                    await store.checkSelectedTaskReadiness()
                                }
                            },
                            onPreviewTaskReadinessPrompt: {
                                Task {
                                    await store.previewPromptForSelectedTaskReadiness()
                                }
                            },
                            onSendTaskReadinessPrompt: {
                                Task {
                                    await store.confirmPromptForSelectedTaskReadiness()
                                }
                            },
                            onRankRoutingConfidence: {
                                Task {
                                    await store.rankSelectedSkillRoutes()
                                }
                            },
                            onPreviewRoutingConfidencePrompt: {
                                Task {
                                    await store.previewPromptForSelectedRoutingConfidence()
                                }
                            },
                            onSendRoutingConfidencePrompt: {
                                Task {
                                    await store.confirmPromptForSelectedRoutingConfidence()
                                }
                            },
                            taskBenchmarkText: $store.taskBenchmarkText,
                            taskBenchmarkInput: store.selectedTaskBenchmarkInput,
                            taskBenchmarkList: store.taskBenchmarkList,
                            taskBenchmarkEvaluation: store.taskBenchmarkEvaluation,
                            taskBenchmarkDeleteResult: store.taskBenchmarkDeleteResult,
                            routingRegressionBaseline: store.routingRegressionBaseline,
                            routingRegressionDetection: store.routingRegressionDetection,
                            isLoadingTaskBenchmarks: store.isLoadingTaskBenchmarks,
                            isSavingTaskBenchmark: store.isSavingTaskBenchmark,
                            isEvaluatingTaskBenchmarks: store.isEvaluatingTaskBenchmarks,
                            isSavingRoutingBaseline: store.isSavingRoutingBaseline,
                            isDetectingRoutingRegression: store.isDetectingRoutingRegression,
                            isDeletingTaskBenchmark: { benchmark in store.isDeletingTaskBenchmark(benchmark) },
                            onLoadTaskBenchmarks: {
                                Task {
                                    await store.loadTaskBenchmarks()
                                }
                            },
                            onSaveTaskBenchmark: {
                                Task {
                                    await store.saveSelectedTaskBenchmark()
                                }
                            },
                            onEvaluateTaskBenchmarks: {
                                Task {
                                    await store.evaluateTaskBenchmarks()
                                }
                            },
                            onSaveRoutingBaseline: {
                                Task {
                                    await store.saveRoutingBaseline()
                                }
                            },
                            onDetectRoutingRegression: {
                                Task {
                                    await store.detectRoutingRegression()
                                }
                            },
                            onDeleteTaskBenchmark: { benchmark in
                                Task {
                                    await store.deleteTaskBenchmark(benchmark)
                                }
                            },
                            traceImportText: $store.traceImportText,
                            traceImportTitle: $store.traceImportTitle,
                            traceImportTask: $store.traceImportTask,
                            traceImportExpectedSkills: $store.traceImportExpectedSkills,
                            traceImportList: store.traceImportList,
                            traceImportResult: store.traceImportResult,
                            traceImportDeleteResult: store.traceImportDeleteResult,
                            latestTraceImportRecord: store.latestTraceImportRecord,
                            isLoadingTraceImports: store.isLoadingTraceImports,
                            isImportingTrace: store.isImportingTrace,
                            isDeletingTraceImport: { record in store.isDeletingTraceImport(record) },
                            onLoadTraceImports: {
                                Task {
                                    await store.loadTraceImports()
                                }
                            },
                            onImportTrace: {
                                Task {
                                    await store.importLocalTrace()
                                }
                            },
                            onDeleteTraceImport: { record in
                                Task {
                                    await store.deleteTraceImport(record)
                                }
                            },
                            isPreparing: { action in store.isPreparingLLMAction(action) },
                            result: { action in store.llmPrepareResult(for: action) },
                            promptPreview: { action in store.llmPromptPreview(for: action) },
                            isPreviewingPrompt: { action in store.isPreviewingLLMPrompt(for: action) },
                            isSendingPrompt: { action in store.isSendingLLMPrompt(for: action) },
                            promptSendResult: { action in store.llmPromptSendResult(for: action) },
                            canSendPrompt: { action in store.canSendLLMPrompt(for: action) },
                            skillAnalysisResult: { kind, scope in store.skillAnalysisPrepareResult(kind: kind, scope: scope) },
                            isPreparingSkillAnalysis: { kind, scope in store.isPreparingSkillAnalysis(kind: kind, scope: scope) },
                            skillAnalysisPromptPreview: { kind, scope in store.skillAnalysisPromptPreview(kind: kind, scope: scope) },
                            isPreviewingSkillAnalysisPrompt: { kind, scope in store.isPreviewingSkillAnalysisPrompt(kind: kind, scope: scope) },
                            isSendingSkillAnalysisPrompt: { kind, scope in store.isSendingSkillAnalysisPrompt(kind: kind, scope: scope) },
                            skillAnalysisPromptSendResult: { kind, scope in store.skillAnalysisPromptSendResult(kind: kind, scope: scope) },
                            canSendSkillAnalysisPrompt: { kind, scope in store.canSendSkillAnalysisPrompt(kind: kind, scope: scope) },
                            onPrepareSkillAnalysis: { kind, scope in
                                Task {
                                    switch scope.key {
                                    case LLMSkillAnalysisRequestScope.visible.key:
                                        await store.prepareVisibleSkillAnalysis(kind: kind)
                                    default:
                                        await store.prepareSelectedSkillAnalysis(kind: kind)
                                    }
                                }
                            },
                            onPreviewSkillAnalysisPrompt: { kind, scope in
                                Task {
                                    await store.previewPromptForSkillAnalysis(kind: kind, scope: scope)
                                }
                            },
                            onSendSkillAnalysisPrompt: { kind, scope in
                                Task {
                                    await store.confirmPromptForSkillAnalysis(kind: kind, scope: scope)
                                }
                            },
                            onPrepare: { action in
                                Task {
                                    switch action {
                                    case .analyze:
                                        await store.prepareAnalyzeLLM()
                                    case .recommend:
                                        await store.prepareRecommendLLM()
                                    case .explainConflict:
                                        await store.prepareExplainConflictLLM()
                                    case .draftFrontmatter:
                                        await store.prepareDraftFrontmatterLLM()
                                    }
                                }
                            },
                            onPreviewPrompt: { action in
                                Task {
                                    await store.previewPromptForSelectedLLMAction(action)
                                }
                            },
                            onSendPrompt: { action in
                                Task {
                                    await store.confirmPromptForSelectedLLMAction(action)
                                }
                            },
                            scriptPreview: store.scriptExecutionPreview(for: skill),
                            isPreviewingScript: store.isPreviewingScriptExecution(for: skill),
                            onPreviewScript: {
                                Task {
                                    await store.previewScriptExecutionSafety(for: skill)
                                }
                            }
                        )
                    }
                } else {
                    EmptyDetailView()
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(UIStrings.appWindowTitle)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }
}

private struct SkillSummaryCard: View {
    let skill: SkillRecord
    let detail: SkillDetailRecord?
    let scriptPreview: ScriptExecutionPreview?
    let isLoading: Bool

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
                SummaryChip(title: UIStrings.source, value: skill.displayPath, systemImage: "doc")
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

private struct CleanupQueueSection: View {
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

private struct SafetyPill: View {
    let label: String
    let isBlocked: Bool

    var body: some View {
        Label(label, systemImage: isBlocked ? "lock" : "exclamationmark.triangle")
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.35), in: Capsule())
            .foregroundStyle(.secondary)
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

private struct DetailSectionSwitcher: View {
    @Binding var selection: DetailSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.detailSection)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Picker(UIStrings.detailSection, selection: $selection) {
                ForEach(DetailSection.visibleCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 560, alignment: .leading)

            Text(UIStrings.text("detail.sectionScopeHint", "Conflicts are current-agent runtime/name collisions. Cross-agent duplicate names and source overlap are Analysis insights."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SummaryChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum SkillProvenanceDisplay {
    static func rootClass(for skill: SkillRecord) -> String {
        switch skill.provenance.rootKind {
        case .toolGlobal:
            return UIStrings.provenanceToolGlobalRoot
        case .native:
            if isNativeOpencodeRoot(skill) {
                return UIStrings.provenanceNativeOpencodeRoot
            }
            return "\(DisplayText.agent(skill.agent)) \(UIStrings.provenanceNativeRoot)"
        case .compatibility:
            if isClaudeCompatibilityRoot(skill) {
                return UIStrings.provenanceClaudeCompatibilityRoot
            }
            if isAgentsCompatibilityRoot(skill) {
                return UIStrings.provenanceAgentsCompatibilityRoot
            }
            return skill.provenance.label
        case .external:
            if skill.agent == "hermes" {
                return UIStrings.provenanceHermesExternalRoot
            }
            return UIStrings.provenanceExternalRoot
        case .readOnly:
            if skill.agent == "hermes" {
                return UIStrings.provenanceHermesHomeProfileRoot
            }
            if skill.agent == "openclaw" {
                if skill.provenance.scopeKind == .project {
                    return UIStrings.provenanceOpenClawWorkspaceRoot
                }
                return UIStrings.provenanceOpenClawReadOnlyRoot
            }
            return "\(DisplayText.agent(skill.agent)) \(UIStrings.provenanceReadOnlyRoot)"
        case .unknown:
            return UIStrings.provenanceUnclassifiedRoot
        }
    }

    static func kind(for skill: SkillRecord) -> String {
        switch skill.provenance.rootKind {
        case .toolGlobal:
            return UIStrings.provenanceToolGlobalKind
        case .native:
            return UIStrings.provenanceNativeKind
        case .compatibility:
            return UIStrings.provenanceCompatibilityKind
        case .external:
            return UIStrings.provenanceExternalKind
        case .readOnly:
            return UIStrings.provenanceReadOnlyKind
        case .unknown:
            return UIStrings.provenanceInferredKind
        }
    }

    private static func isClaudeCompatibilityRoot(_ skill: SkillRecord) -> Bool {
        pathText(for: skill).contains(".claude/skills")
    }

    private static func isAgentsCompatibilityRoot(_ skill: SkillRecord) -> Bool {
        pathText(for: skill).contains(".agents/skills")
    }

    private static func isNativeOpencodeRoot(_ skill: SkillRecord) -> Bool {
        let path = pathText(for: skill)
        return path.contains(".config/opencode/skills") || path.contains(".opencode/skills")
    }

    private static func pathText(for skill: SkillRecord) -> String {
        "\(skill.path)\n\(skill.displayPath)".lowercased()
    }
}

private struct AnalysisSection: View {
    let skill: SkillRecord
    let comparisonResult: CrossAgentComparisonResult
    let selectedComparisonGroup: CrossAgentComparisonGroup?
    let isLoadingComparisons: Bool
    let agentTitle: String
    let llmStatus: LLMStatus
    let qualityScore: (SkillRecord) -> SkillQualityScoreResult?
    let isScoringQuality: (SkillRecord) -> Bool
    let qualityPromptPreview: (SkillRecord) -> LLMPromptPreview?
    let isPreviewingQualityPrompt: (SkillRecord) -> Bool
    let isSendingQualityPrompt: (SkillRecord) -> Bool
    let qualityPromptSendResult: (SkillRecord) -> LLMPromptSendResult?
    let canSendQualityPrompt: (SkillRecord) -> Bool
    @Binding var taskReadinessText: String
    let taskReadinessResult: (SkillRecord) -> TaskReadinessResult?
    let isCheckingTaskReadiness: (SkillRecord) -> Bool
    let taskReadinessPromptPreview: (SkillRecord) -> LLMPromptPreview?
    let isPreviewingTaskReadinessPrompt: (SkillRecord) -> Bool
    let isSendingTaskReadinessPrompt: (SkillRecord) -> Bool
    let taskReadinessPromptSendResult: (SkillRecord) -> LLMPromptSendResult?
    let canSendTaskReadinessPrompt: (SkillRecord) -> Bool
    @Binding var routingConfidenceText: String
    let routingConfidenceResult: (SkillRecord) -> SkillRoutingConfidenceResult?
    let isRankingRoutingConfidence: (SkillRecord) -> Bool
    let routingConfidencePromptPreview: (SkillRecord) -> LLMPromptPreview?
    let isPreviewingRoutingConfidencePrompt: (SkillRecord) -> Bool
    let isSendingRoutingConfidencePrompt: (SkillRecord) -> Bool
    let routingConfidencePromptSendResult: (SkillRecord) -> LLMPromptSendResult?
    let canSendRoutingConfidencePrompt: (SkillRecord) -> Bool
    let onScoreQuality: () -> Void
    let onPreviewQualityPrompt: () -> Void
    let onSendQualityPrompt: () -> Void
    let onCheckTaskReadiness: () -> Void
    let onPreviewTaskReadinessPrompt: () -> Void
    let onSendTaskReadinessPrompt: () -> Void
    let onRankRoutingConfidence: () -> Void
    let onPreviewRoutingConfidencePrompt: () -> Void
    let onSendRoutingConfidencePrompt: () -> Void
    @Binding var taskBenchmarkText: String
    let taskBenchmarkInput: String
    let taskBenchmarkList: TaskBenchmarkListResult
    let taskBenchmarkEvaluation: TaskBenchmarkEvaluationResult?
    let taskBenchmarkDeleteResult: TaskBenchmarkDeleteResult?
    let routingRegressionBaseline: RoutingRegressionBaselineResult?
    let routingRegressionDetection: RoutingRegressionDetectionResult?
    let isLoadingTaskBenchmarks: Bool
    let isSavingTaskBenchmark: Bool
    let isEvaluatingTaskBenchmarks: Bool
    let isSavingRoutingBaseline: Bool
    let isDetectingRoutingRegression: Bool
    let isDeletingTaskBenchmark: (TaskBenchmarkRecord) -> Bool
    let onLoadTaskBenchmarks: () -> Void
    let onSaveTaskBenchmark: () -> Void
    let onEvaluateTaskBenchmarks: () -> Void
    let onSaveRoutingBaseline: () -> Void
    let onDetectRoutingRegression: () -> Void
    let onDeleteTaskBenchmark: (TaskBenchmarkRecord) -> Void
    @Binding var traceImportText: String
    @Binding var traceImportTitle: String
    @Binding var traceImportTask: String
    @Binding var traceImportExpectedSkills: String
    let traceImportList: AgentTraceImportListResult
    let traceImportResult: AgentTraceImportResult?
    let traceImportDeleteResult: AgentTraceImportDeleteResult?
    let latestTraceImportRecord: AgentTraceImportRecord?
    let isLoadingTraceImports: Bool
    let isImportingTrace: Bool
    let isDeletingTraceImport: (AgentTraceImportRecord) -> Bool
    let onLoadTraceImports: () -> Void
    let onImportTrace: () -> Void
    let onDeleteTraceImport: (AgentTraceImportRecord) -> Void
    let isPreparing: (LLMAction) -> Bool
    let result: (LLMAction) -> LLMPrepareResult?
    let promptPreview: (LLMAction) -> LLMPromptPreview?
    let isPreviewingPrompt: (LLMAction) -> Bool
    let isSendingPrompt: (LLMAction) -> Bool
    let promptSendResult: (LLMAction) -> LLMPromptSendResult?
    let canSendPrompt: (LLMAction) -> Bool
    let skillAnalysisResult: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMSkillAnalysisPrepareResult?
    let isPreparingSkillAnalysis: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let skillAnalysisPromptPreview: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMPromptPreview?
    let isPreviewingSkillAnalysisPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let isSendingSkillAnalysisPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let skillAnalysisPromptSendResult: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMPromptSendResult?
    let canSendSkillAnalysisPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let onPrepareSkillAnalysis: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void
    let onPreviewSkillAnalysisPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void
    let onSendSkillAnalysisPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void
    let onPrepare: (LLMAction) -> Void
    let onPreviewPrompt: (LLMAction) -> Void
    let onSendPrompt: (LLMAction) -> Void
    let scriptPreview: ScriptExecutionPreview?
    let isPreviewingScript: Bool
    let onPreviewScript: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label(UIStrings.text("analysis.workbench", "Read-only Analysis / Insights workbench"), systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                Text(UIStrings.text("analysis.workbench.summary", "Use offline/AI-assisted review to understand purpose, risk, findings, and cross-agent duplicate/source-overlap insights. This panel does not write config, modify skills, or execute scripts."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label(UIStrings.text("analysis.crossAgentNote", "Cross-agent duplicates and source overlap live here as analysis insights; same-agent runtime/name collisions remain in Conflicts."), systemImage: "rectangle.3.group.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            CrossAgentComparisonPanel(
                skill: skill,
                result: comparisonResult,
                selectedGroup: selectedComparisonGroup,
                isLoading: isLoadingComparisons,
                agentTitle: agentTitle
            )

            SkillQualityScorePanel(
                skill: skill,
                result: qualityScore(skill),
                isScoring: isScoringQuality(skill),
                promptPreview: qualityPromptPreview(skill),
                isPreviewingPrompt: isPreviewingQualityPrompt(skill),
                isSendingPrompt: isSendingQualityPrompt(skill),
                promptSendResult: qualityPromptSendResult(skill),
                canSendPrompt: canSendQualityPrompt(skill),
                onScore: onScoreQuality,
                onPreviewPrompt: onPreviewQualityPrompt,
                onSendPrompt: onSendQualityPrompt
            )

            TaskReadinessPanel(
                skill: skill,
                taskText: $taskReadinessText,
                result: taskReadinessResult(skill),
                isChecking: isCheckingTaskReadiness(skill),
                promptPreview: taskReadinessPromptPreview(skill),
                isPreviewingPrompt: isPreviewingTaskReadinessPrompt(skill),
                isSendingPrompt: isSendingTaskReadinessPrompt(skill),
                promptSendResult: taskReadinessPromptSendResult(skill),
                canSendPrompt: canSendTaskReadinessPrompt(skill),
                onCheck: onCheckTaskReadiness,
                onPreviewPrompt: onPreviewTaskReadinessPrompt,
                onSendPrompt: onSendTaskReadinessPrompt
            )

            RoutingConfidencePanel(
                skill: skill,
                taskText: $routingConfidenceText,
                result: routingConfidenceResult(skill),
                isRanking: isRankingRoutingConfidence(skill),
                promptPreview: routingConfidencePromptPreview(skill),
                isPreviewingPrompt: isPreviewingRoutingConfidencePrompt(skill),
                isSendingPrompt: isSendingRoutingConfidencePrompt(skill),
                promptSendResult: routingConfidencePromptSendResult(skill),
                canSendPrompt: canSendRoutingConfidencePrompt(skill),
                onRank: onRankRoutingConfidence,
                onPreviewPrompt: onPreviewRoutingConfidencePrompt,
                onSendPrompt: onSendRoutingConfidencePrompt
            )

            TaskBenchmarkPanel(
                skill: skill,
                taskText: $taskBenchmarkText,
                currentTaskText: taskBenchmarkInput,
                listResult: taskBenchmarkList,
                evaluation: taskBenchmarkEvaluation,
                deleteResult: taskBenchmarkDeleteResult,
                routingRegressionBaseline: routingRegressionBaseline,
                routingRegressionDetection: routingRegressionDetection,
                isLoading: isLoadingTaskBenchmarks,
                isSaving: isSavingTaskBenchmark,
                isEvaluating: isEvaluatingTaskBenchmarks,
                isSavingRoutingBaseline: isSavingRoutingBaseline,
                isDetectingRoutingRegression: isDetectingRoutingRegression,
                isDeleting: isDeletingTaskBenchmark,
                onLoad: onLoadTaskBenchmarks,
                onSave: onSaveTaskBenchmark,
                onEvaluate: onEvaluateTaskBenchmarks,
                onSaveRoutingBaseline: onSaveRoutingBaseline,
                onDetectRoutingRegression: onDetectRoutingRegression,
                onDelete: onDeleteTaskBenchmark
            )

            AgentTraceImportPanel(
                traceText: $traceImportText,
                title: $traceImportTitle,
                taskText: $traceImportTask,
                expectedSkills: $traceImportExpectedSkills,
                listResult: traceImportList,
                importResult: traceImportResult,
                deleteResult: traceImportDeleteResult,
                latestRecord: latestTraceImportRecord,
                isLoading: isLoadingTraceImports,
                isImporting: isImportingTrace,
                isDeleting: isDeletingTraceImport,
                onLoad: onLoadTraceImports,
                onImport: onImportTrace,
                onDelete: onDeleteTraceImport
            )

            SkillAnalysisPreparePanel(
                result: skillAnalysisResult,
                isPreparing: isPreparingSkillAnalysis,
                promptPreview: skillAnalysisPromptPreview,
                isPreviewingPrompt: isPreviewingSkillAnalysisPrompt,
                isSendingPrompt: isSendingSkillAnalysisPrompt,
                promptSendResult: skillAnalysisPromptSendResult,
                canSendPrompt: canSendSkillAnalysisPrompt,
                onPreviewPrompt: onPreviewSkillAnalysisPrompt,
                onSendPrompt: onSendSkillAnalysisPrompt,
                onPrepare: onPrepareSkillAnalysis
            )

            LLMAssistPanel(
                status: llmStatus,
                isPreparing: isPreparing,
                result: result,
                promptPreview: promptPreview,
                isPreviewingPrompt: isPreviewingPrompt,
                isSendingPrompt: isSendingPrompt,
                promptSendResult: promptSendResult,
                canSendPrompt: canSendPrompt,
                onPreviewPrompt: onPreviewPrompt,
                onSendPrompt: onSendPrompt,
                onPrepare: onPrepare
            )

            ScriptExecutionSafetyCard(
                skill: skill,
                preview: scriptPreview,
                isPreviewing: isPreviewingScript,
                onPreview: onPreviewScript
            )
        }
    }

}


private struct CrossAgentComparisonPanel: View {
    let skill: SkillRecord
    let result: CrossAgentComparisonResult
    let selectedGroup: CrossAgentComparisonGroup?
    let isLoading: Bool
    let agentTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.crossAgentComparisonTitle, systemImage: "rectangle.3.group")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.crossAgentComparisonBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.crossAgentComparisonGroups, value: "\(result.summary.totalCount)", systemImage: "rectangle.stack")
                SummaryChip(title: UIStrings.crossAgentComparisonAgents, value: "\(result.summary.agentCount)", systemImage: "person.3")
                SummaryChip(title: UIStrings.crossAgentComparisonRiskGroups, value: "\(result.summary.riskCount)", systemImage: "exclamationmark.triangle")
                SummaryChip(title: UIStrings.crossAgentComparisonWritableMismatch, value: "\(result.summary.writableMismatchCount)", systemImage: "lock.trianglebadge.exclamationmark")
            }

            if isLoading {
                Label(UIStrings.loading, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.crossAgentComparisonFilterContext(agentTitle))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let selectedGroup {
                CrossAgentComparisonGroupCard(group: selectedGroup, selectedSkillID: skill.id)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label(UIStrings.crossAgentComparisonNoSelectedGroup, systemImage: "checkmark.seal")
                        .font(.subheadline.bold())
                    Text(UIStrings.crossAgentComparisonNoSelectedGroupMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct CrossAgentComparisonGroupCard: View {
    let group: CrossAgentComparisonGroup
    let selectedSkillID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.subheadline.bold())
                    Text("\(group.matchKind) · \(group.members.count) \(UIStrings.skills.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(group.riskLevel.capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(riskTint.opacity(0.16), in: Capsule())
                    .foregroundStyle(riskTint)
            }

            if !group.differences.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(UIStrings.crossAgentComparisonDifferences)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(group.differences, id: \.self) { difference in
                        Label(difference, systemImage: "arrow.left.arrow.right")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(group.members) { member in
                    CrossAgentComparisonMemberRow(
                        member: member,
                        isSelected: member.instanceID == selectedSkillID
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var riskTint: Color {
        switch group.riskLevel.lowercased() {
        case "critical", "high", "error":
            return .red
        case "warning", "medium":
            return .orange
        default:
            return .secondary
        }
    }
}

private struct CrossAgentComparisonMemberRow: View {
    let member: CrossAgentComparisonMember
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(DisplayText.agent(member.agent), systemImage: isSelected ? "target" : "person.crop.circle")
                    .font(.callout.bold())
                Text(DisplayText.state(member.state, enabled: member.enabled))
                    .font(.caption.bold())
                    .foregroundStyle(DisplayText.stateColor(member.state, enabled: member.enabled))
                Spacer()
                SafetyPill(
                    label: member.writableCapability ? UIStrings.crossAgentComparisonWritable : UIStrings.readOnly,
                    isBlocked: !member.writableCapability
                )
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                MetadataRow(label: UIStrings.scope, value: DisplayText.scope(member.scope, agent: member.agent))
                MetadataRow(label: UIStrings.provenanceRoot, value: member.sourceRoot)
                MetadataRow(label: UIStrings.findings, value: "\(member.findingCount)")
                MetadataRow(label: UIStrings.definition, value: member.definitionID.nonEmpty ?? UIStrings.emptyPlaceholder)
            }

            if let reason = member.writableReason, !reason.isEmpty {
                Label(reason, systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !member.displayPath.isEmpty {
                Text(member.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if !member.differences.isEmpty {
                Text(member.differences.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SkillQualityScorePanel: View {
    let skill: SkillRecord
    let result: SkillQualityScoreResult?
    let isScoring: Bool
    let promptPreview: LLMPromptPreview?
    let isPreviewingPrompt: Bool
    let isSendingPrompt: Bool
    let promptSendResult: LLMPromptSendResult?
    let canSendPrompt: Bool
    let onScore: () -> Void
    let onPreviewPrompt: () -> Void
    let onSendPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.skillQualityTitle, systemImage: "gauge.medium")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.skillQualityBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onScore()
                } label: {
                    Label(UIStrings.skillQualityScoreAction, systemImage: "gauge.medium")
                }
                .disabled(isScoring)
                .help(UIStrings.skillQualityBoundary)

                if isScoring {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                SkillQualityScoreResultView(result: result)
            } else {
                Label(UIStrings.text("quality.empty.prompt", "Run Score Quality to evaluate this skill from local catalog evidence."), systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            PromptPreviewControls(
                preview: promptPreview,
                sendResult: promptSendResult,
                isPreviewing: isPreviewingPrompt,
                isSending: isSendingPrompt,
                canSend: canSendPrompt,
                onPreview: onPreviewPrompt,
                onSend: onSendPrompt
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SkillQualityScoreResultView: View {
    let result: SkillQualityScoreResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.score)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(UIStrings.skillQualityScore)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.displayBand)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(scoreTint.opacity(0.16), in: Capsule())
                        .foregroundStyle(scoreTint)
                    if !result.summary.isEmpty {
                        Text(result.summary)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                        Label(fallbackReason, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.skillQualityBand, value: result.displayBand)
                MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: result.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!result.safety.writeBackAllowed && !result.safety.writeActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!result.safety.scriptExecutionAllowed && !result.safety.executionActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!result.safety.configMutationAllowed && !result.safety.snapshotCreated && !result.safety.triageMutationAllowed))
                MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!result.safety.credentialAccessed && !result.safety.rawSecretReturned))
            }

            SkillQualityComponentList(components: result.components)
            SkillQualityEvidenceList(evidence: result.evidence)
            SkillQualityStringList(title: UIStrings.skillQualityRiskNotes, empty: UIStrings.skillQualityNoRisks, values: result.riskNotes, systemImage: "exclamationmark.triangle")
            SkillQualityStringList(title: UIStrings.skillQualitySuggestions, empty: UIStrings.skillQualityNoSuggestions, values: result.suggestedImprovements, systemImage: "wand.and.stars")

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var scoreTint: Color {
        switch result.score {
        case 85...100:
            return .green
        case 65..<85:
            return .blue
        case 45..<65:
            return .orange
        default:
            return .red
        }
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct SkillQualityComponentList: View {
    let components: [SkillQualityComponent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.skillQualityComponents)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if components.isEmpty {
                Text(UIStrings.skillQualityNoComponents)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(components) { component in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(component.label)
                                    .font(.caption.bold())
                                Spacer()
                                Text(componentScore(component))
                                    .font(.caption.monospacedDigit().bold())
                            }
                            if let status = component.status, !status.isEmpty {
                                Text(status)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !component.summary.isEmpty {
                                Text(component.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func componentScore(_ component: SkillQualityComponent) -> String {
        if let maxScore = component.maxScore {
            return "\(component.score)/\(maxScore)"
        }
        return "\(component.score)"
    }
}

private struct SkillQualityEvidenceList: View {
    let evidence: [SkillQualityEvidenceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.skillQualityEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.skillQualityNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(6)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let source = item.source, !source.isEmpty {
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct SkillQualityStringList: View {
    let title: String
    let empty: String
    let values: [String]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if values.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(values, id: \.self) { value in
                    Label(value, systemImage: systemImage)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct TaskReadinessPanel: View {
    let skill: SkillRecord
    @Binding var taskText: String
    let result: TaskReadinessResult?
    let isChecking: Bool
    let promptPreview: LLMPromptPreview?
    let isPreviewingPrompt: Bool
    let isSendingPrompt: Bool
    let promptSendResult: LLMPromptSendResult?
    let canSendPrompt: Bool
    let onCheck: () -> Void
    let onPreviewPrompt: () -> Void
    let onSendPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.taskReadinessTitle, systemImage: "checklist.checked")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.taskReadinessBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(UIStrings.taskReadinessTaskPlaceholder, text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .labelsHidden()

                Button {
                    onCheck()
                } label: {
                    Label(UIStrings.taskReadinessCheckAction, systemImage: "checklist")
                }
                .disabled(isChecking || taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(UIStrings.taskReadinessBoundary)
            }

            if isChecking {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let result {
                TaskReadinessResultView(result: result)
            } else {
                Label(UIStrings.taskReadinessTaskRequired, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            PromptPreviewControls(
                preview: promptPreview,
                sendResult: promptSendResult,
                isPreviewing: isPreviewingPrompt,
                isSending: isSendingPrompt,
                canSend: canSendPrompt,
                onPreview: onPreviewPrompt,
                onSend: onSendPrompt
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct TaskReadinessResultView: View {
    let result: TaskReadinessResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.score)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(UIStrings.taskReadinessScore)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.band)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(scoreTint.opacity(0.16), in: Capsule())
                        .foregroundStyle(scoreTint)
                    if !result.summary.isEmpty {
                        Text(result.summary)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                        Label(fallbackReason, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.taskReadinessBand, value: result.band)
                MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: result.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!result.safety.writeBackAllowed && !result.safety.writeActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!result.safety.scriptExecutionAllowed && !result.safety.executionActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!result.safety.configMutationAllowed && !result.safety.snapshotCreated && !result.safety.triageMutationAllowed))
                MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!result.safety.credentialAccessed && !result.safety.rawSecretReturned))
            }

            TaskReadinessCandidateList(candidates: result.candidateSkills)
            SkillQualityStringList(title: UIStrings.taskReadinessGaps, empty: UIStrings.taskReadinessNoGaps, values: result.gaps, systemImage: "puzzlepiece.extension")
            SkillQualityStringList(title: UIStrings.taskReadinessBlockers, empty: UIStrings.taskReadinessNoBlockers, values: result.blockers, systemImage: "exclamationmark.octagon")
            SkillQualityStringList(title: UIStrings.taskReadinessRiskNotes, empty: UIStrings.taskReadinessNoRisks, values: result.riskNotes, systemImage: "exclamationmark.triangle")
            TaskReadinessEvidenceList(evidence: result.evidence)

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var scoreTint: Color {
        switch result.score {
        case 85...100:
            return .green
        case 65..<85:
            return .blue
        case 40..<65:
            return .orange
        default:
            return .red
        }
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct TaskReadinessCandidateList: View {
    let candidates: [TaskReadinessCandidateSkill]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.taskReadinessCandidates)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if candidates.isEmpty {
                Text(UIStrings.taskReadinessNoCandidates)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(candidates) { candidate in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(candidate.name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text(candidateScore(candidate))
                                    .font(.caption.monospacedDigit().bold())
                            }
                            Text(DisplayText.agent(candidate.agent))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let readiness = candidate.readiness, !readiness.isEmpty {
                                Text(readiness)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !candidate.rationale.isEmpty {
                                Text(candidate.rationale)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func candidateScore(_ candidate: TaskReadinessCandidateSkill) -> String {
        candidate.score.map(String.init) ?? UIStrings.unknown
    }
}

private struct TaskReadinessEvidenceList: View {
    let evidence: [TaskReadinessEvidenceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.taskReadinessEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.taskReadinessNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(6)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let source = item.source, !source.isEmpty {
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct RoutingConfidencePanel: View {
    let skill: SkillRecord
    @Binding var taskText: String
    let result: SkillRoutingConfidenceResult?
    let isRanking: Bool
    let promptPreview: LLMPromptPreview?
    let isPreviewingPrompt: Bool
    let isSendingPrompt: Bool
    let promptSendResult: LLMPromptSendResult?
    let canSendPrompt: Bool
    let onRank: () -> Void
    let onPreviewPrompt: () -> Void
    let onSendPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.routingConfidenceTitle, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.routingConfidenceBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(UIStrings.routingConfidenceTaskPlaceholder, text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .labelsHidden()

                Button {
                    onRank()
                } label: {
                    Label(UIStrings.routingConfidenceAction, systemImage: "arrow.up.arrow.down.square")
                }
                .disabled(isRanking || taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(UIStrings.routingConfidenceBoundary)
            }

            if isRanking {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let result {
                RoutingConfidenceResultView(result: result)
            } else {
                Label(UIStrings.routingConfidenceTaskRequired, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            PromptPreviewControls(
                preview: promptPreview,
                sendResult: promptSendResult,
                isPreviewing: isPreviewingPrompt,
                isSending: isSendingPrompt,
                canSend: canSendPrompt,
                onPreview: onPreviewPrompt,
                onSend: onSendPrompt
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RoutingConfidenceResultView: View {
    let result: SkillRoutingConfidenceResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.score)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(UIStrings.routingConfidenceScore)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.band)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(scoreTint.opacity(0.16), in: Capsule())
                        .foregroundStyle(scoreTint)
                    if !result.summary.isEmpty {
                        Text(result.summary)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                        Label(fallbackReason, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingConfidenceBand, value: result.band)
                MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: result.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!result.safety.writeBackAllowed && !result.safety.writeActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!result.safety.scriptExecutionAllowed && !result.safety.executionActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!result.safety.configMutationAllowed && !result.safety.snapshotCreated && !result.safety.triageMutationAllowed))
                MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!result.safety.credentialAccessed && !result.safety.rawSecretReturned))
            }

            RoutingRouteList(routes: result.routes)
            SkillQualityStringList(title: UIStrings.routingConfidenceAmbiguity, empty: UIStrings.routingConfidenceNoAmbiguity, values: result.ambiguityWarnings, systemImage: "exclamationmark.triangle")
            SkillQualityStringList(title: UIStrings.routingConfidenceWrongPick, empty: UIStrings.routingConfidenceNoWrongPick, values: result.wrongPickRisks, systemImage: "xmark.octagon")
            RoutingEvidenceList(evidence: result.evidence)

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var scoreTint: Color {
        switch result.score {
        case 85...100:
            return .green
        case 65..<85:
            return .blue
        case 40..<65:
            return .orange
        default:
            return .red
        }
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct RoutingRouteList: View {
    let routes: [SkillRouteCandidate]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.routingConfidenceRoutes)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if routes.isEmpty {
                Text(UIStrings.routingConfidenceNoRoutes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("#\(index + 1) \(route.name)")
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("\(route.confidenceScore)")
                                    .font(.caption.monospacedDigit().bold())
                            }
                            HStack(spacing: 6) {
                                Text(DisplayText.agent(route.agent))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(route.band)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary.opacity(0.55), in: Capsule())
                            }
                            if !route.summary.isEmpty {
                                Text(route.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                            RoutingInlineList(title: UIStrings.routingConfidenceMatchReasons, empty: UIStrings.routingConfidenceNoReasons, values: route.matchReasons, systemImage: "checkmark.circle")
                            RoutingInlineList(title: UIStrings.routingConfidenceAmbiguity, empty: UIStrings.routingConfidenceNoAmbiguity, values: route.ambiguityWarnings, systemImage: "exclamationmark.triangle")
                            RoutingInlineList(title: UIStrings.routingConfidenceWrongPick, empty: UIStrings.routingConfidenceNoWrongPick, values: route.wrongPickRisks, systemImage: "xmark.octagon")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

private struct RoutingInlineList: View {
    let title: String
    let empty: String
    let values: [String]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            if values.isEmpty {
                Text(empty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(values.prefix(3), id: \.self) { value in
                    Label(value, systemImage: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct RoutingEvidenceList: View {
    let evidence: [TaskReadinessEvidenceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.routingConfidenceEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.routingConfidenceNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(6)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let source = item.source, !source.isEmpty {
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct TaskBenchmarkPanel: View {
    let skill: SkillRecord
    @Binding var taskText: String
    let currentTaskText: String
    let listResult: TaskBenchmarkListResult
    let evaluation: TaskBenchmarkEvaluationResult?
    let deleteResult: TaskBenchmarkDeleteResult?
    let routingRegressionBaseline: RoutingRegressionBaselineResult?
    let routingRegressionDetection: RoutingRegressionDetectionResult?
    let isLoading: Bool
    let isSaving: Bool
    let isEvaluating: Bool
    let isSavingRoutingBaseline: Bool
    let isDetectingRoutingRegression: Bool
    let isDeleting: (TaskBenchmarkRecord) -> Bool
    let onLoad: () -> Void
    let onSave: () -> Void
    let onEvaluate: () -> Void
    let onSaveRoutingBaseline: () -> Void
    let onDetectRoutingRegression: () -> Void
    let onDelete: (TaskBenchmarkRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.taskBenchmarkTitle, systemImage: "checklist.unchecked")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.taskBenchmarkBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 8) {
                TextField(UIStrings.taskBenchmarkTaskPlaceholder, text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .labelsHidden()
                HStack(spacing: 8) {
                    Button {
                        onSave()
                    } label: {
                        Label(UIStrings.taskBenchmarkSaveAction, systemImage: "plus.square.on.square")
                    }
                    .disabled(isSaving || currentTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help(UIStrings.taskBenchmarkExpectedCurrentSkill(skill.name, DisplayText.agent(skill.agent)))

                    Button {
                        onLoad()
                    } label: {
                        Label(UIStrings.taskBenchmarkLoadAction, systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)

                    Button {
                        onEvaluate()
                    } label: {
                        Label(UIStrings.taskBenchmarkEvaluateAction, systemImage: "chart.bar.xaxis")
                    }
                    .disabled(isEvaluating)
                    Spacer()
                }
            }

            Label(UIStrings.taskBenchmarkExpectedCurrentSkill(skill.name, DisplayText.agent(skill.agent)), systemImage: "target")
                .font(.callout)
                .foregroundStyle(.secondary)

            if isLoading || isSaving || isEvaluating {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TaskBenchmarkListView(
                result: listResult,
                deleteResult: deleteResult,
                isDeleting: isDeleting,
                onDelete: onDelete
            )

            if let evaluation {
                TaskBenchmarkEvaluationView(result: evaluation)
            }

            RoutingRegressionPanel(
                baseline: routingRegressionBaseline,
                detection: routingRegressionDetection,
                isSavingBaseline: isSavingRoutingBaseline,
                isDetecting: isDetectingRoutingRegression,
                onSaveBaseline: onSaveRoutingBaseline,
                onDetect: onDetectRoutingRegression
            )

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RoutingRegressionPanel: View {
    let baseline: RoutingRegressionBaselineResult?
    let detection: RoutingRegressionDetectionResult?
    let isSavingBaseline: Bool
    let isDetecting: Bool
    let onSaveBaseline: () -> Void
    let onDetect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.routingRegressionTitle, systemImage: "chart.line.downtrend.xyaxis")
                    .font(.subheadline.bold())
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.routingRegressionBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onSaveBaseline()
                } label: {
                    Label(UIStrings.routingRegressionSaveBaselineAction, systemImage: "tray.and.arrow.down")
                }
                .disabled(isSavingBaseline)

                Button {
                    onDetect()
                } label: {
                    Label(UIStrings.routingRegressionDetectAction, systemImage: "waveform.path.ecg")
                }
                .disabled(isDetecting)
                Spacer()
            }

            if isSavingBaseline || isDetecting {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let baseline {
                RoutingRegressionBaselineView(result: baseline)
            } else {
                Label(UIStrings.routingRegressionNoBaseline, systemImage: "clock.badge.questionmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let detection {
                RoutingRegressionDetectionView(result: detection)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct RoutingRegressionBaselineView: View {
    let result: RoutingRegressionBaselineResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(UIStrings.routingRegressionBaselineStatus)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if let baselineID = result.baselineID, !baselineID.isEmpty {
                    Text(baselineID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.taskBenchmarkEvaluated, value: "\(result.benchmarkCount)")
                if let averageScore = result.averageScore {
                    MetadataRow(label: UIStrings.taskBenchmarkAverageScore, value: "\(averageScore)")
                }
                if let matchedCount = result.matchedCount {
                    MetadataRow(label: UIStrings.taskBenchmarkMatched, value: "\(matchedCount)")
                }
                if let acceptableCount = result.acceptableCount {
                    MetadataRow(label: UIStrings.taskBenchmarkAcceptableMatched, value: "\(acceptableCount)")
                }
                MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: result.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!result.safety.writeBackAllowed && !result.safety.writeActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!result.safety.scriptExecutionAllowed && !result.safety.executionActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!result.safety.configMutationAllowed && !result.safety.snapshotCreated && !result.safety.triageMutationAllowed))
                MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!result.safety.credentialAccessed && !result.safety.rawSecretReturned))
            }

            if !result.summary.isEmpty {
                Text(result.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct RoutingRegressionDetectionView: View {
    let result: RoutingRegressionDetectionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.regressionCount)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(UIStrings.routingRegressionCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.routingRegressionDetectionTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                        Label(fallbackReason, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.taskBenchmarkEvaluated, value: "\(result.benchmarkCount)")
                MetadataRow(label: UIStrings.routingRegressionImproved, value: "\(result.improvedCount)")
                MetadataRow(label: UIStrings.routingRegressionUnchanged, value: "\(result.unchangedCount)")
                MetadataRow(label: UIStrings.routingRegressionAverageScoreDelta, value: signed(result.averageScoreDelta))
                MetadataRow(label: UIStrings.routingRegressionMatchChanges, value: "\(result.matchStatusChangedCount)")
                MetadataRow(label: UIStrings.routingRegressionTopRouteChanges, value: "\(result.topRouteChangedCount)")
                MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: result.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!result.safety.writeBackAllowed && !result.safety.writeActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!result.safety.scriptExecutionAllowed && !result.safety.executionActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!result.safety.configMutationAllowed && !result.safety.snapshotCreated && !result.safety.triageMutationAllowed))
                MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!result.safety.credentialAccessed && !result.safety.rawSecretReturned))
            }

            RoutingRegressionItemList(items: result.regressions)
            SkillQualityStringList(title: UIStrings.routingRegressionNewBlockers, empty: UIStrings.routingRegressionNoNewBlockers, values: result.newBlockers, systemImage: "exclamationmark.octagon")
            SkillQualityStringList(title: UIStrings.routingRegressionNewGaps, empty: UIStrings.routingRegressionNoNewGaps, values: result.newGaps, systemImage: "puzzlepiece.extension")
            RoutingEvidenceList(evidence: result.evidence)
        }
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct RoutingRegressionItemList: View {
    let items: [RoutingRegressionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.routingRegressionItems)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(UIStrings.routingRegressionNoItems)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.taskText.isEmpty ? UIStrings.unknown : item.taskText)
                                    .font(.caption.bold())
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                                Spacer()
                                Text(signed(item.scoreDelta))
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(item.scoreDelta < 0 ? Color.red : Color.green)
                            }
                            HStack(spacing: 6) {
                                Text(item.regressionType)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.16), in: Capsule())
                                    .foregroundStyle(.orange)
                                if item.topRouteChanged {
                                    Label(UIStrings.routingRegressionTopRouteChanged, systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !item.previousMatchStatus.isEmpty || !item.currentMatchStatus.isEmpty {
                                Text("\(UIStrings.routingRegressionMatchStatus): \(item.previousMatchStatus.isEmpty ? UIStrings.unknown : item.previousMatchStatus) -> \(item.currentMatchStatus.isEmpty ? UIStrings.unknown : item.currentMatchStatus)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let previous = item.previousTopRoute ?? item.currentTopRoute {
                                let previousName = item.previousTopRoute.map { "\($0.name) (\(DisplayText.agent($0.agent)))" } ?? UIStrings.unknown
                                let currentName = item.currentTopRoute.map { "\($0.name) (\(DisplayText.agent($0.agent)))" } ?? "\(previous.name) (\(DisplayText.agent(previous.agent)))"
                                Text("\(UIStrings.routingRegressionTopRouteChange): \(previousName) -> \(currentName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            RoutingInlineList(title: UIStrings.routingRegressionNewBlockers, empty: UIStrings.routingRegressionNoNewBlockers, values: item.newBlockers, systemImage: "exclamationmark.octagon")
                            RoutingInlineList(title: UIStrings.routingRegressionNewGaps, empty: UIStrings.routingRegressionNoNewGaps, values: item.newGaps, systemImage: "puzzlepiece.extension")
                            RoutingInlineList(title: UIStrings.taskBenchmarkSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: item.safetyFlags, systemImage: "lock.shield")
                            RoutingEvidenceList(evidence: item.evidence)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

private struct TaskBenchmarkListView: View {
    let result: TaskBenchmarkListResult
    let deleteResult: TaskBenchmarkDeleteResult?
    let isDeleting: (TaskBenchmarkRecord) -> Bool
    let onDelete: (TaskBenchmarkRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(UIStrings.taskBenchmarkListTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(result.benchmarks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if result.benchmarks.isEmpty {
                Text(UIStrings.taskBenchmarkNoBenchmarks)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(result.benchmarks) { benchmark in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(benchmark.taskText.isEmpty ? UIStrings.unknown : benchmark.taskText)
                                    .font(.caption.bold())
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                                Spacer()
                                Button {
                                    onDelete(benchmark)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .disabled(isDeleting(benchmark))
                                .help(UIStrings.taskBenchmarkDeleteAction)
                            }
                            if let expected = benchmark.expectedSkill {
                                Text("\(UIStrings.taskBenchmarkExpected): \(expected.name) (\(DisplayText.agent(expected.agent)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            if !benchmark.acceptableSkills.isEmpty {
                                Text("\(UIStrings.taskBenchmarkAcceptable): \(benchmark.acceptableSkills.map(\.name).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if let deleteResult, let reason = deleteResult.fallbackReason, !reason.isEmpty {
                Label(reason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TaskBenchmarkEvaluationView: View {
    let result: TaskBenchmarkEvaluationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.averageScore)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(UIStrings.taskBenchmarkAverageScore)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.taskBenchmarkEvaluationTitle)
                        .font(.subheadline.bold())
                    if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                        Label(fallbackReason, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.taskBenchmarkEvaluated, value: "\(result.evaluatedCount)")
                MetadataRow(label: UIStrings.taskBenchmarkMatched, value: "\(result.matchedCount)")
                MetadataRow(label: UIStrings.taskBenchmarkAcceptableMatched, value: "\(result.acceptableCount)")
                MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: result.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!result.safety.writeBackAllowed && !result.safety.writeActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!result.safety.scriptExecutionAllowed && !result.safety.executionActionsAvailable))
                MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!result.safety.configMutationAllowed && !result.safety.snapshotCreated && !result.safety.triageMutationAllowed))
                MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!result.safety.credentialAccessed && !result.safety.rawSecretReturned))
            }

            TaskBenchmarkEvaluationList(evaluations: result.evaluations)
            SkillQualityStringList(title: UIStrings.taskBenchmarkBlockers, empty: UIStrings.taskBenchmarkNoBlockers, values: result.blockers, systemImage: "exclamationmark.octagon")
            SkillQualityStringList(title: UIStrings.taskBenchmarkGaps, empty: UIStrings.taskBenchmarkNoGaps, values: result.gaps, systemImage: "puzzlepiece.extension")
            RoutingEvidenceList(evidence: result.evidence)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct TaskBenchmarkEvaluationList: View {
    let evaluations: [TaskBenchmarkEvaluationItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.taskBenchmarkPerBenchmark)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evaluations.isEmpty {
                Text(UIStrings.taskBenchmarkNoEvaluations)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(evaluations) { item in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.taskText.isEmpty ? UIStrings.unknown : item.taskText)
                                    .font(.caption.bold())
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                                Spacer()
                                Text("\(item.score)")
                                    .font(.caption.monospacedDigit().bold())
                            }
                            HStack(spacing: 6) {
                                Text(item.matchStatus)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(scoreTint(item.score).opacity(0.16), in: Capsule())
                                    .foregroundStyle(scoreTint(item.score))
                                Text(item.band)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let topRoute = item.topRoute {
                                Text("\(UIStrings.taskBenchmarkTopRoute): \(topRoute.name) (\(DisplayText.agent(topRoute.agent)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            HStack(spacing: 8) {
                                Label(item.expectedCovered ? UIStrings.taskBenchmarkExpectedCovered : UIStrings.taskBenchmarkExpectedMissed, systemImage: item.expectedCovered ? "checkmark.circle" : "xmark.circle")
                                Label(item.acceptableCovered ? UIStrings.taskBenchmarkAcceptableCovered : UIStrings.taskBenchmarkAcceptableMissed, systemImage: item.acceptableCovered ? "checkmark.circle" : "xmark.circle")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            RoutingInlineList(title: UIStrings.taskBenchmarkBlockers, empty: UIStrings.taskBenchmarkNoBlockers, values: item.blockers, systemImage: "exclamationmark.octagon")
                            RoutingInlineList(title: UIStrings.taskBenchmarkGaps, empty: UIStrings.taskBenchmarkNoGaps, values: item.gaps, systemImage: "puzzlepiece.extension")
                            RoutingInlineList(title: UIStrings.taskBenchmarkSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: item.safetyFlags, systemImage: "lock.shield")
                            RoutingEvidenceList(evidence: item.evidence)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func scoreTint(_ score: Int) -> Color {
        switch score {
        case 85...100:
            return .green
        case 65..<85:
            return .blue
        case 40..<65:
            return .orange
        default:
            return .red
        }
    }
}

private struct AgentTraceImportPanel: View {
    @Binding var traceText: String
    @Binding var title: String
    @Binding var taskText: String
    @Binding var expectedSkills: String
    let listResult: AgentTraceImportListResult
    let importResult: AgentTraceImportResult?
    let deleteResult: AgentTraceImportDeleteResult?
    let latestRecord: AgentTraceImportRecord?
    let isLoading: Bool
    let isImporting: Bool
    let isDeleting: (AgentTraceImportRecord) -> Bool
    let onLoad: () -> Void
    let onImport: () -> Void
    let onDelete: (AgentTraceImportRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.traceImportTitle, systemImage: "tray.and.arrow.down.fill")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.traceImportBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Label(UIStrings.traceImportProviderBoundary, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                TextField(UIStrings.traceImportTitlePlaceholder, text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField(UIStrings.traceImportTaskPlaceholder, text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                TextField(UIStrings.traceImportExpectedPlaceholder, text: $expectedSkills, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...2)
                ZStack(alignment: .topLeading) {
                    if traceText.isEmpty {
                        Text(UIStrings.traceImportTextPlaceholder)
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $traceText)
                        .font(.system(.callout, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 82, maxHeight: 120)
                        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack(spacing: 8) {
                Button {
                    onImport()
                } label: {
                    Label(UIStrings.traceImportImportAction, systemImage: "square.and.arrow.down")
                }
                .disabled(isImporting || traceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.traceImportLoadAction, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)

                Spacer()
            }

            if isLoading || isImporting {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let reason = importResult?.fallbackReason, !reason.isEmpty {
                Label(reason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let latestRecord {
                VStack(alignment: .leading, spacing: 8) {
                    Text(UIStrings.traceImportLatest)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    AgentTraceImportRecordView(record: latestRecord, compact: false)
                }
            } else if listResult.imports.isEmpty {
                Label(UIStrings.traceImportNoImports, systemImage: "clock.badge.questionmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            AgentTraceImportListView(
                result: listResult,
                deleteResult: deleteResult,
                isDeleting: isDeleting,
                onDelete: onDelete
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct AgentTraceImportListView: View {
    let result: AgentTraceImportListResult
    let deleteResult: AgentTraceImportDeleteResult?
    let isDeleting: (AgentTraceImportRecord) -> Bool
    let onDelete: (AgentTraceImportRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(UIStrings.traceImportImports)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(result.imports.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if result.imports.isEmpty {
                Text(UIStrings.traceImportNoImports)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(result.imports) { record in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(record.title.isEmpty ? (record.taskText.isEmpty ? record.id : record.taskText) : record.title)
                                    .font(.caption.bold())
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                                Spacer()
                                Button {
                                    onDelete(record)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .disabled(isDeleting(record))
                                .help(UIStrings.traceImportDeleteAction)
                            }
                            AgentTraceImportRecordView(record: record, compact: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if let deleteResult, let reason = deleteResult.fallbackReason, !reason.isEmpty {
                Label(reason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AgentTraceImportRecordView: View {
    let record: AgentTraceImportRecord
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(record.outcome.isEmpty ? UIStrings.unknown : record.outcome)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(outcomeTint.opacity(0.16), in: Capsule())
                    .foregroundStyle(outcomeTint)
                if !record.taskText.isEmpty {
                    Text(record.taskText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 1 : 2)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            if !compact {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    MetadataRow(label: UIStrings.traceImportOutcome, value: record.outcome.isEmpty ? UIStrings.unknown : record.outcome)
                    MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: record.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                    MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!record.safety.writeBackAllowed && !record.safety.writeActionsAvailable))
                    MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!record.safety.scriptExecutionAllowed && !record.safety.executionActionsAvailable))
                    MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!record.safety.configMutationAllowed && !record.safety.snapshotCreated && !record.safety.triageMutationAllowed))
                    MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!record.safety.credentialAccessed && !record.safety.rawSecretReturned))
                }
            }

            AgentTraceSkillList(title: UIStrings.traceImportDetectedSkills, skills: record.detectedSkills)
            AgentTraceSkillList(title: UIStrings.traceImportExpectedSkills, skills: record.expectedSkills)

            if !compact || !record.redactedExcerpt.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(UIStrings.traceImportRedactedExcerpt)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(record.redactedExcerpt.isEmpty ? UIStrings.traceImportNoExcerpt : record.redactedExcerpt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(record.redactedExcerpt.isEmpty ? .secondary : .primary)
                        .lineLimit(compact ? 3 : nil)
                        .textSelection(.enabled)
                }
            }

            AgentTraceRedactionView(redaction: record.redaction)
            RoutingInlineList(title: UIStrings.traceImportReasons, empty: UIStrings.traceImportNoReasons, values: record.reasons, systemImage: "text.bubble")
            RoutingInlineList(title: UIStrings.taskBenchmarkSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: record.safetyFlags, systemImage: "lock.shield")
            RoutingEvidenceList(evidence: record.evidence)
        }
        .padding(compact ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(compact ? Color.clear : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private var outcomeTint: Color {
        switch record.outcome.lowercased() {
        case "hit", "matched", "expected_match":
            return .green
        case "miss", "wrong_pick", "wrong-pick":
            return .red
        case "ambiguous":
            return .orange
        default:
            return .secondary
        }
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct AgentTraceSkillList: View {
    let title: String
    let skills: [TaskBenchmarkSkillRef]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if skills.isEmpty {
                Text(UIStrings.traceImportNoSkills)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(skills.map(skillLabel).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }

    private func skillLabel(_ skill: TaskBenchmarkSkillRef) -> String {
        if skill.agent == UIStrings.unknown || skill.agent.isEmpty {
            return skill.name
        }
        return "\(skill.name) (\(DisplayText.agent(skill.agent)))"
    }
}

private struct AgentTraceRedactionView: View {
    let redaction: AgentTraceRedactionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(UIStrings.traceImportRedactionSummary)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(redaction.summary.isEmpty ? redaction.status : "\(redaction.status): \(redaction.summary)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if !redaction.redactedFields.isEmpty {
                Text(redaction.redactedFields.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !redaction.placeholders.isEmpty {
                Text(redaction.placeholders.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            ForEach(redaction.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct SkillAnalysisPreparePanel: View {
    let result: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMSkillAnalysisPrepareResult?
    let isPreparing: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let promptPreview: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMPromptPreview?
    let isPreviewingPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let isSendingPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let promptSendResult: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> LLMPromptSendResult?
    let canSendPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Bool
    let onPreviewPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void
    let onSendPrompt: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void
    let onPrepare: (LLMSkillAnalysisKind, LLMSkillAnalysisRequestScope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.llmSkillAnalysis, systemImage: "sparkles.square.filled.on.square")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmSkillAnalysisSafetyTitle, systemImage: "checkmark.shield")
                .font(.subheadline.bold())
            Text(UIStrings.llmSkillAnalysisSafetyCopy)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(LLMSkillAnalysisKind.allCases) { kind in
                    Button {
                        onPrepare(kind, .selected)
                    } label: {
                        Label("\(UIStrings.llmSkillAnalysisPrepareSelected) \(kind.title)", systemImage: kind.systemImage)
                    }
                    .disabled(isPreparing(kind, .selected))
                    .help(UIStrings.llmSkillAnalysisSafetyCopy)
                }
            }

            HStack(spacing: 8) {
                Button {
                    onPrepare(.overview, .visible)
                } label: {
                    Label(UIStrings.llmSkillAnalysisPrepareVisible, systemImage: "rectangle.grid.2x2")
                }
                .disabled(isPreparing(.overview, .visible))
                .help(UIStrings.llmSkillAnalysisSafetyCopy)
            }

            ForEach(LLMSkillAnalysisKind.allCases) { kind in
                if isPreparing(kind, .selected) {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                } else if let result = result(kind, .selected) {
                    SkillAnalysisPrepareResultView(
                        result: result,
                        scope: .selected,
                        promptPreview: promptPreview(kind, .selected),
                        isPreviewingPrompt: isPreviewingPrompt(kind, .selected),
                        isSendingPrompt: isSendingPrompt(kind, .selected),
                        promptSendResult: promptSendResult(kind, .selected),
                        canSendPrompt: canSendPrompt(kind, .selected),
                        onPreviewPrompt: { onPreviewPrompt(kind, .selected) },
                        onSendPrompt: { onSendPrompt(kind, .selected) }
                    )
                }
            }

            if isPreparing(.overview, .visible) {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            } else if let result = result(.overview, .visible) {
                SkillAnalysisPrepareResultView(
                    result: result,
                    scope: .visible,
                    promptPreview: promptPreview(.overview, .visible),
                    isPreviewingPrompt: isPreviewingPrompt(.overview, .visible),
                    isSendingPrompt: isSendingPrompt(.overview, .visible),
                    promptSendResult: promptSendResult(.overview, .visible),
                    canSendPrompt: canSendPrompt(.overview, .visible),
                    onPreviewPrompt: { onPreviewPrompt(.overview, .visible) },
                    onSendPrompt: { onSendPrompt(.overview, .visible) }
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SkillAnalysisPrepareResultView: View {
    let result: LLMSkillAnalysisPrepareResult
    let scope: LLMSkillAnalysisRequestScope
    let promptPreview: LLMPromptPreview?
    let isPreviewingPrompt: Bool
    let isSendingPrompt: Bool
    let promptSendResult: LLMPromptSendResult?
    let canSendPrompt: Bool
    let onPreviewPrompt: () -> Void
    let onSendPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(scope.title) · \(result.analysisKind.title)", systemImage: result.enabled ? "doc.text.magnifyingglass" : "nosign")
                .font(.subheadline.bold())
                .foregroundStyle(result.enabled ? .primary : .secondary)

            if let reason = result.disabledReason, !reason.isEmpty {
                Text(reason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.skills, value: String(result.selectedSkillCount))
                MetadataRow(label: UIStrings.llmSkillAnalysisExcludedMissing, value: "\(result.excludedCount) / \(result.missingCount)")
                MetadataRow(label: UIStrings.llmSkillAnalysisWriteBack, value: safetyValue(result.safety.writeBackEnabled, safeText: UIStrings.llmSkillAnalysisBlocked))
                MetadataRow(label: UIStrings.llmSkillAnalysisScriptExecution, value: safetyValue(result.safety.scriptExecutionEnabled, safeText: UIStrings.llmSkillAnalysisBlocked))
                MetadataRow(label: UIStrings.llmSkillAnalysisCredentialStorage, value: safetyValue(result.safety.credentialStorageEnabled, safeText: UIStrings.llmSkillAnalysisBlocked))
                MetadataRow(label: UIStrings.llmSkillAnalysisConfirmation, value: result.safety.confirmationRequired ? UIStrings.llmSkillAnalysisRequired : UIStrings.unknown)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(UIStrings.llmSkillAnalysisIncludedSkills)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(includedSkillsText)
                    .font(.callout)
                    .foregroundStyle(result.includedSkills.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
            }

            DraftTextBlock(title: UIStrings.llmSkillAnalysisSummaryDraft, text: result.summaryDraft)
            DraftTextBlock(title: UIStrings.llmSkillAnalysisPromptDraft, text: result.promptDraft)

            PromptPreviewControls(
                preview: promptPreview,
                sendResult: promptSendResult,
                isPreviewing: isPreviewingPrompt,
                isSending: isSendingPrompt,
                canSend: canSendPrompt,
                onPreview: onPreviewPrompt,
                onSend: onSendPrompt
            )

            Label(UIStrings.llmSkillAnalysisSafetyCopy, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var includedSkillsText: String {
        guard !result.includedSkills.isEmpty else { return UIStrings.llmSkillAnalysisNoIncludedSkills }
        return result.includedSkills.map { skill in
            "\(skill.name) (\(DisplayText.agent(skill.agent)))"
        }.joined(separator: ", ")
    }

    private func safetyValue(_ isEnabled: Bool, safeText: String) -> String {
        isEnabled ? UIStrings.llmSkillAnalysisEnabledUnsafe : safeText
    }
}

private struct DraftTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "doc.on.doc")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? UIStrings.llmSkillAnalysisNoDraft : text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private extension LLMSkillAnalysisKind {
    var title: String {
        switch self {
        case .overview:
            return UIStrings.text("llm.skillAnalysis.kind.overview", "Overview")
        case .risk:
            return UIStrings.text("llm.skillAnalysis.kind.risk", "Risk")
        case .cleanup:
            return UIStrings.text("llm.skillAnalysis.kind.cleanup", "Cleanup")
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "text.magnifyingglass"
        case .risk:
            return "shield.lefthalf.filled"
        case .cleanup:
            return "sparkles"
        }
    }
}

private struct LLMAssistPanel: View {
    let status: LLMStatus
    let isPreparing: (LLMAction) -> Bool
    let result: (LLMAction) -> LLMPrepareResult?
    let promptPreview: (LLMAction) -> LLMPromptPreview?
    let isPreviewingPrompt: (LLMAction) -> Bool
    let isSendingPrompt: (LLMAction) -> Bool
    let promptSendResult: (LLMAction) -> LLMPromptSendResult?
    let canSendPrompt: (LLMAction) -> Bool
    let onPreviewPrompt: (LLMAction) -> Void
    let onSendPrompt: (LLMAction) -> Void
    let onPrepare: (LLMAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.llmAssist, systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Label(
                    status.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled,
                    systemImage: status.enabled ? "checkmark.circle" : "nosign"
                )
                .font(.caption.bold())
                .foregroundStyle(status.enabled ? .green : .secondary)
            }

            if let disabledReason = status.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if status.enabled {
                Text(UIStrings.llmPreparePrompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(LLMAction.allCases) { action in
                    Button {
                        onPrepare(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .disabled(isPreparing(action))
                    .help(status.enabled ? action.title : UIStrings.llmReviewNoActions)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(LLMAction.allCases) { action in
                    if isPreparing(action) {
                        Label(UIStrings.llmPreparing, systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    } else if let result = result(action) {
                        LLMPrepareResultView(
                            result: result,
                            promptPreview: promptPreview(action),
                            isPreviewingPrompt: isPreviewingPrompt(action),
                            isSendingPrompt: isSendingPrompt(action),
                            promptSendResult: promptSendResult(action),
                            canSendPrompt: canSendPrompt(action),
                            onPreviewPrompt: { onPreviewPrompt(action) },
                            onSendPrompt: { onSendPrompt(action) }
                        )
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct LLMPrepareResultView: View {
    let result: LLMPrepareResult
    let promptPreview: LLMPromptPreview?
    let isPreviewingPrompt: Bool
    let isSendingPrompt: Bool
    let promptSendResult: LLMPromptSendResult?
    let canSendPrompt: Bool
    let onPreviewPrompt: () -> Void
    let onSendPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(result.action.title, systemImage: result.enabled ? "checkmark.circle" : "nosign")
                .font(.subheadline.bold())
                .foregroundStyle(result.enabled ? .primary : .secondary)

            if let disabledReason = result.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                if let provider = result.provider, !provider.isEmpty {
                    MetadataRow(label: UIStrings.llmProvider, value: provider)
                }
                if let model = result.model, !model.isEmpty {
                    MetadataRow(label: UIStrings.llmModel, value: model)
                }
                if let estimate = result.estimate {
                    MetadataRow(
                        label: UIStrings.llmTokens,
                        value: UIStrings.llmTokenSummary(
                            input: estimate.inputTokens,
                            output: estimate.outputTokens,
                            total: estimate.totalTokens
                        )
                    )
                    if let cost = estimate.estimatedCostUSD {
                        MetadataRow(label: UIStrings.llmCost, value: UIStrings.llmEstimatedCost(cost))
                    }
                }
            }

            if let reviewPreview = result.reviewPreview {
                LLMReviewPreviewView(preview: reviewPreview)
            }

            if result.confirmationRequired {
                Label(UIStrings.llmConfirmationRequired, systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if result.action == .draftFrontmatter {
                Label(UIStrings.llmDraftCopyRequired, systemImage: "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            PromptPreviewControls(
                preview: promptPreview,
                sendResult: promptSendResult,
                isPreviewing: isPreviewingPrompt,
                isSending: isSendingPrompt,
                canSend: canSendPrompt,
                onPreview: onPreviewPrompt,
                onSend: onSendPrompt
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct PromptPreviewControls: View {
    let preview: LLMPromptPreview?
    let sendResult: LLMPromptSendResult?
    let isPreviewing: Bool
    let isSending: Bool
    let canSend: Bool
    let onPreview: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.llmPromptPreviewAction, systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isPreviewing || isSending)

                Button {
                    onSend()
                } label: {
                    Label(UIStrings.llmPromptConfirmSend, systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend || isPreviewing || isSending)
                .help(canSend ? UIStrings.llmPromptConfirmSend : UIStrings.llmPromptProviderRequired)
            }

            if isPreviewing {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }

            if let preview {
                LLMPromptPreviewCard(preview: preview)
            } else {
                Label(UIStrings.llmPromptPreviewRequired, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if isSending {
                Label(UIStrings.llmPromptSending, systemImage: "network")
                    .foregroundStyle(.secondary)
            }

            if let sendResult {
                LLMPromptSendResultView(result: sendResult)
            }
        }
    }
}

private struct LLMPromptPreviewCard: View {
    let preview: LLMPromptPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.llmPromptPreviewTitle, systemImage: preview.enabled ? "eye" : "nosign")
                .font(.caption.bold())
                .foregroundStyle(preview.enabled ? Color.secondary : Color.orange)

            if let disabledReason = preview.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.llmPromptScope, value: preview.promptScope)
                MetadataRow(label: UIStrings.llmProvider, value: preview.provider ?? UIStrings.unknown)
                MetadataRow(label: UIStrings.llmModel, value: preview.model ?? UIStrings.unknown)
                MetadataRow(label: UIStrings.llmPromptDestination, value: preview.destinationHost ?? UIStrings.unknown)
                if let estimate = preview.estimate {
                    MetadataRow(
                        label: UIStrings.llmTokens,
                        value: UIStrings.llmTokenSummary(
                            input: estimate.inputTokens,
                            output: estimate.outputTokens,
                            total: estimate.totalTokens
                        )
                    )
                    if let cost = estimate.estimatedCostUSD {
                        MetadataRow(label: UIStrings.llmCost, value: UIStrings.llmEstimatedCost(cost))
                    }
                }
                MetadataRow(label: UIStrings.llmSkillAnalysisConfirmation, value: preview.confirmationRequired ? UIStrings.llmSkillAnalysisRequired : UIStrings.unknown)
                MetadataRow(label: UIStrings.llmPromptRawPromptStored, value: preview.rawPromptPersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptRawResponseStored, value: preview.rawResponsePersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptCopyOnly, value: preview.draftCopyOnly ? UIStrings.llmEnabled : UIStrings.llmDisabled)
            }

            PromptFieldList(title: UIStrings.llmPromptIncludedFields, fields: preview.includedFields)
            PromptFieldList(title: UIStrings.llmPromptExcludedFields, fields: preview.excludedFields)
            RedactionSummaryView(redaction: preview.redaction)

            if let promptText = preview.promptPreview, !promptText.isEmpty {
                DraftTextBlock(title: UIStrings.llmPromptRedactedPrompt, text: promptText)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct PromptFieldList: View {
    let title: String
    let fields: [LLMPromptField]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if fields.isEmpty {
                Text(UIStrings.llmPromptNoFields)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fields) { field in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Label(field.label, systemImage: "checklist")
                            .font(.callout)
                        if let reason = field.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct RedactionSummaryView: View {
    let redaction: LLMPromptRedactionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(UIStrings.llmReviewRedaction)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(redaction.summary.isEmpty ? redaction.status : "\(redaction.status): \(redaction.summary)")
                .font(.callout)
                .foregroundStyle(.secondary)
            if !redaction.redactedFields.isEmpty {
                Text(redaction.redactedFields.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !redaction.placeholders.isEmpty {
                Text(redaction.placeholders.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            ForEach(redaction.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct LLMPromptSendResultView: View {
    let result: LLMPromptSendResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(result.success ? .green : .orange)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.aiProviderTestResult, value: result.status)
                MetadataRow(label: UIStrings.llmPromptRawPromptStored, value: result.rawPromptPersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptRawResponseStored, value: result.rawResponsePersisted ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmPromptCopyOnly, value: result.draftCopyOnly ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                MetadataRow(label: UIStrings.llmSkillAnalysisWriteBack, value: result.writeBackAllowed ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmSkillAnalysisBlocked)
                MetadataRow(label: UIStrings.llmSkillAnalysisScriptExecution, value: result.scriptExecutionAllowed ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmSkillAnalysisBlocked)
                if let audit = result.audit {
                    MetadataRow(label: UIStrings.aiProviderAuditMetadata, value: audit.auditID ?? UIStrings.unknown)
                    MetadataRow(label: UIStrings.aiProviderAuditRedaction, value: audit.redactionApplied ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                }
            }

            if let output = result.outputText, !output.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(UIStrings.llmPromptOutput, systemImage: "doc.on.doc")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(output, forType: .string)
                        } label: {
                            Label(UIStrings.llmPromptCopyOutput, systemImage: "doc.on.doc")
                        }
                    }
                    Text(output)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct LLMReviewPreviewView: View {
    let preview: LLMReviewPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.llmReviewPreview, systemImage: "eye")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            MetadataRow(label: UIStrings.llmReviewPurpose, value: preview.purpose)
            MetadataRow(label: UIStrings.llmReviewRisk, value: "\(preview.risk.level): \(preview.risk.summary)")
            MetadataRow(label: UIStrings.llmReviewCrossAgentFit, value: preview.crossAgentFit.summary)
            MetadataRow(label: UIStrings.llmReviewRedaction, value: redactionSummary)

            VStack(alignment: .leading, spacing: 5) {
                Text(UIStrings.llmReviewSignals)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.risk.signals.isEmpty {
                    Text(UIStrings.llmReviewNoSignals)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.risk.signals, id: \.self) { signal in
                        Label(signal, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(UIStrings.llmReviewFindings)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.findingExplanations.isEmpty {
                    Text(UIStrings.llmReviewNoFindings)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.findingExplanations) { finding in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(finding.severity) · \(finding.ruleID)")
                                .font(.callout.bold())
                            Text(finding.explanation)
                                .foregroundStyle(.secondary)
                            if let nextStep = finding.suggestedNextStep, !nextStep.isEmpty {
                                Text(nextStep)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var redactionSummary: String {
        "body=\(preview.redaction.skillBodyReturned ? "returned" : "hidden"), paths=\(preview.redaction.pathsReturned ? "returned" : "hidden"), credentials=\(preview.redaction.credentialsReturned ? "returned" : "hidden")"
    }
}

private extension LLMAction {
    var title: String {
        switch self {
        case .analyze:
            return UIStrings.llmAnalyze
        case .recommend:
            return UIStrings.llmRecommend
        case .explainConflict:
            return UIStrings.llmExplainConflict
        case .draftFrontmatter:
            return UIStrings.llmDraftFrontmatter
        }
    }

    var systemImage: String {
        switch self {
        case .analyze:
            return "text.magnifyingglass"
        case .recommend:
            return "wand.and.stars"
        case .explainConflict:
            return "exclamationmark.bubble"
        case .draftFrontmatter:
            return "doc.badge.plus"
        }
    }
}

private struct ScriptExecutionSafetyCard: View {
    let skill: SkillRecord
    let preview: ScriptExecutionPreview?
    let isPreviewing: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.scriptExecutionSafety, systemImage: "lock.shield")
                    .font(.headline)
                Spacer()
                Label(UIStrings.scriptExecutionPreviewOnly, systemImage: "eye")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(preview?.summary ?? UIStrings.scriptExecutionPreviewSummary)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.previewGate, systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isPreviewing)
                .help(UIStrings.scriptExecutionBlockedNote)

                Button {
                } label: {
                    Label(UIStrings.executionBlocked, systemImage: "nosign")
                }
                .disabled(true)
                .help(UIStrings.scriptExecutionBlockedNote)
            }

            if isPreviewing {
                Label(UIStrings.loading, systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }

            if let preview {
                ScriptExecutionPreviewView(preview: preview)
            } else {
                Label(UIStrings.scriptExecutionBlockedNote, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct ScriptExecutionPreviewView: View {
    let preview: ScriptExecutionPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(statusTitle, systemImage: statusImage)
                .font(.subheadline.bold())
                .foregroundStyle(preview.executionAllowed ? .orange : .secondary)

            if let reason = preview.disabledReason, !reason.isEmpty {
                Text(reason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.scriptExecutionAuditStatus, value: UIStrings.scriptExecutionAuditStatusTitle(preview.auditStatus))
                MetadataRow(label: UIStrings.scriptExecutionAuditID, value: preview.auditID?.nonEmpty ?? UIStrings.scriptExecutionNoAudit)
                MetadataRow(label: UIStrings.scriptExecutionCWD, value: preview.scope.cwd?.nonEmpty ?? UIStrings.permissionUndeclared)
                MetadataRow(label: UIStrings.scriptExecutionNetwork, value: preview.scope.network?.nonEmpty ?? UIStrings.permissionUndeclared)
                MetadataRow(label: UIStrings.scriptExecutionEnv, value: formattedEnv)
                MetadataRow(label: UIStrings.scriptExecutionFiles, value: formattedFiles)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(UIStrings.scriptExecutionCommand, systemImage: "terminal")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(commandPreview)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(UIStrings.scriptExecutionRisks, systemImage: "exclamationmark.triangle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.risks.isEmpty {
                    Text(UIStrings.scriptExecutionNoRisks)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.risks, id: \.self) { risk in
                        Label(risk, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if preview.confirmationRequired {
                Label(UIStrings.scriptExecutionConfirmationRequired, systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.scriptExecutionBlockedNote, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var statusTitle: String {
        preview.executionAllowed ? UIStrings.executionBlocked : UIStrings.scriptExecutionPreviewOnly
    }

    private var statusImage: String {
        preview.executionAllowed ? "exclamationmark.triangle" : "nosign"
    }

    private var commandPreview: String {
        let command = preview.commandPreview
            .map { part in part.replacingOccurrences(of: "\n", with: "\\n") }
            .joined(separator: " ")
        return command.isEmpty ? UIStrings.scriptExecutionNoCommand : command
    }

    private var formattedEnv: String {
        guard !preview.scope.env.isEmpty else {
            return UIStrings.scriptExecutionEnvEmpty
        }
        return preview.scope.env.keys.sorted().map { key in
            "\(key)=\(preview.scope.env[key] ?? "")"
        }.joined(separator: ", ")
    }

    private var formattedFiles: String {
        preview.scope.files.isEmpty ? UIStrings.scriptExecutionFilesEmpty : preview.scope.files.joined(separator: ", ")
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension JSONValue {
    func boolValue(forAnyKey keys: [String]) -> Bool? {
        guard case .object(let object) = self else { return nil }
        for key in keys {
            if let payloadValue = object[key], case .bool(let value) = payloadValue {
                return value
            }
        }
        return nil
    }

    var compactDisplayString: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let object):
            return object.keys.sorted().map { key in
                "\(key)=\(object[key]?.compactDisplayString ?? "")"
            }.joined(separator: ", ")
        case .array(let values):
            return values.map(\.compactDisplayString).joined(separator: ", ")
        case .null:
            return ""
        }
    }
}

private struct HeaderView: View {
    let skill: SkillRecord
    let detail: SkillDetailRecord?
    let findingCount: Int
    let conflictCount: Int
    let isWriting: Bool
    let llmStatus: LLMStatus
    let adapterCapability: AdapterCapabilityRecord?
    let onSelectSection: (DetailSection) -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        let disabledReason = toggleDisabledReason
        let isEffectivelyEnabled = DisplayText.statusKind(skill.state, enabled: skill.enabled) == .enabled

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(skill.name)
                        .font(.largeTitle.bold())
                    Text(skill.definitionId)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Label(
                        DisplayText.isToolGlobal(skill) ? UIStrings.readOnlyPreview : DisplayText.state(skill.state, enabled: skill.enabled),
                        systemImage: DisplayText.isToolGlobal(skill) ? "eye" : DisplayText.stateSystemImage(skill.state, enabled: skill.enabled)
                    )
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(DisplayText.isToolGlobal(skill) ? .secondary : DisplayText.stateColor(skill.state, enabled: skill.enabled))

                    if showsReadOnlyPreviewBadge {
                        Label(DisplayText.isToolGlobal(skill) ? UIStrings.readOnlyPreview : UIStrings.readOnly, systemImage: "lock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .help(disabledReason ?? UIStrings.readOnly)
                    }

                    if isPiGuardedToggleAvailable {
                        Label(UIStrings.piGuardedToggle, systemImage: "shield.lefthalf.filled")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .help(UIStrings.piGuardedToggleBoundary)
                    }

                    Button {
                        onToggle(!isEffectivelyEnabled)
                    } label: {
                    Label(
                        isEffectivelyEnabled ? UIStrings.disable : UIStrings.enable,
                        systemImage: isEffectivelyEnabled ? "pause.circle" : "play.circle"
                    )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(disabledReason != nil)
                    .help(disabledReason ?? "")
                    .accessibilityHint(disabledReason ?? "")
                }
            }

            if let disabledReason {
                Label(disabledReason, systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if isPiGuardedToggleAvailable {
                Label(UIStrings.piGuardedToggleBoundary, systemImage: "shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.agent, value: DisplayText.agent(skill.agent), systemImage: "person.crop.circle")
                SummaryChip(title: UIStrings.scope, value: DisplayText.scope(for: skill), systemImage: "folder")
                SummaryChip(title: UIStrings.state, value: DisplayText.state(skill.state, enabled: skill.enabled), systemImage: DisplayText.stateSystemImage(skill.state, enabled: skill.enabled))
                CountBadge(
                    label: UIStrings.text("detail.issueGroups", "Issue groups"),
                    value: findingCount,
                    systemImage: "exclamationmark.triangle",
                    tint: .orange,
                    action: { onSelectSection(.findings) }
                )
                CountBadge(
                    label: UIStrings.text("detail.sameAgentConflicts", "Same-agent conflicts"),
                    value: conflictCount,
                    systemImage: "rectangle.2.swap",
                    tint: .red,
                    action: { onSelectSection(.conflicts) }
                )
                SummaryChip(title: UIStrings.text("detail.riskAnalysis", "Risk / analysis"), value: riskAnalysisStatus, systemImage: riskAnalysisImage)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var toggleDisabledReason: String? {
        if let catalogReason = DisplayText.catalogToggleDisabledReason(for: skill, isWriting: isWriting) {
            return catalogReason
        }
        guard !isWriting else {
            return UIStrings.toggleUnavailableBusy
        }
        guard let adapterCapability else {
            return DisplayText.isReadOnlyAdapter(skill.agent) ? UIStrings.toggleUnavailableReadOnlyAdapter(DisplayText.agent(skill.agent)) : nil
        }
        guard !adapterCapability.configToggle.supported else { return nil }
            if skill.agent == "openclaw" {
                return UIStrings.openClawToggleBlocked
            }
            return adapterCapability.configToggle.reason ?? UIStrings.readOnlyAdapterStatus(adapterCapability.displayName)
    }

    private var isPiGuardedToggleAvailable: Bool {
        skill.agent == "pi" && adapterCapability?.configToggle.supported == true
    }

    private var showsReadOnlyPreviewBadge: Bool {
        DisplayText.isReadOnlyPreview(skill) && !isPiGuardedToggleAvailable
    }

    private var riskAnalysisStatus: String {
        if findingCount > 0 || conflictCount > 0 {
            return UIStrings.text("detail.reviewQueued", "Review queued")
        }
        if permissionRiskCount > 0 {
            return UIStrings.text("detail.riskDeclared", "Risk declared")
        }
        return llmStatus.enabled ? UIStrings.text("detail.aiReady", "AI ready") : UIStrings.text("detail.offlineReady", "Offline ready")
    }

    private var riskAnalysisImage: String {
        if findingCount > 0 || conflictCount > 0 || permissionRiskCount > 0 {
            return "exclamationmark.triangle"
        }
        return llmStatus.enabled ? "sparkles" : "checkmark.seal"
    }

    private var permissionRiskCount: Int {
        guard let detail, case .object(let object) = detail.permissions else {
            return 0
        }
        var count = 0
        if case .bool(true)? = object["exec"] {
            count += 1
        }
        if case .string(let network)? = object["network"], network == "full" {
            count += 1
        }
        return count
    }
}

private struct RecentActivityCard: View {
    let events: [SkillEventRecord]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.recentActivity, systemImage: "clock.badge")
                    .font(.headline)
                Spacer()
                if isLoading {
                    Label(UIStrings.loadingRecentActivity, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if events.isEmpty {
                Text(isLoading ? UIStrings.loadingRecentActivity : UIStrings.noRecentActivity)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { event in
                        SkillActivityRow(event: event)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct HistorySection: View {
    let events: [SkillEventRecord]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label(UIStrings.text("history.activity", "Configuration activity"), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Text(UIStrings.text("history.activity.summary", "History shows lightweight enable, disable, and config-action events that the service already records. Skill-content snapshots are intentionally not shown here."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            RecentActivityCard(events: events, isLoading: isLoading)
        }
    }
}

private struct SkillActivityRow: View {
    let event: SkillEventRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "switch.2")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(activityTitle)
                    .font(.subheadline.bold())
                Text(DisplayText.timestamp(event.occurredAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let payloadSummary {
                    Text(payloadSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var activityTitle: String {
        if let enabled = event.payload.boolValue(forAnyKey: ["on", "enabled"]) {
            return UIStrings.activityToggleState(enabled: enabled)
        }
        return event.kind
    }

    private var payloadSummary: String? {
        let summary = event.payload.compactDisplayString
        return summary.isEmpty ? nil : "\(UIStrings.activityPayload): \(summary)"
    }
}

private struct CountBadge: View {
    let label: String
    let value: Int
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(value > 0 ? tint : .secondary)
                Text("\(value)")
                    .font(.headline)
                    .foregroundStyle(value > 0 ? .primary : .secondary)
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .adaptiveMaterialSurface()
        }
        .buttonStyle(.plain)
        .help(UIStrings.text("detail.countBadge.help", "Show \(label)"))
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(UIStrings.noSkillSelected)
                .font(.title2.bold())
            Text(UIStrings.noSkillSelectedMessage)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SkillDetailCard: View {
    let skill: SkillRecord
    let detail: SkillDetailRecord?
    let adapterCapability: AdapterCapabilityRecord?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                MetadataRow(label: UIStrings.agent, value: DisplayText.agent(skill.agent))
                MetadataRow(label: UIStrings.scope, value: DisplayText.scope(for: skill))
                MetadataRow(label: UIStrings.provenanceRoot, value: SkillProvenanceDisplay.rootClass(for: skill))
                MetadataRow(label: UIStrings.provenanceKind, value: SkillProvenanceDisplay.kind(for: skill))
                MetadataRow(label: UIStrings.definition, value: skill.definitionId)
                MetadataRow(label: UIStrings.catalogID, value: skill.id)
                MetadataRow(label: UIStrings.source, value: skill.displayPath)
                if DisplayText.isToolGlobal(skill) {
                    MetadataRow(label: UIStrings.access, value: UIStrings.toolGlobalAccessStatus(DisplayText.agent(skill.agent)))
                }
                if DisplayText.isReadOnlyAdapter(skill.agent) {
                    MetadataRow(label: UIStrings.access, value: adapterAccessStatus)
                }
                if let detail {
                    MetadataRow(label: UIStrings.fingerprint, value: detail.fingerprint)
                    MetadataRow(label: UIStrings.description, value: detail.description.isEmpty ? UIStrings.noDescription : detail.description)
                }
            }

            if isLoading {
                ProgressView(UIStrings.loadingSkillDetail)
            }

            if let detail {
                PermissionSummaryCard(summary: PermissionDisplayModel.summary(for: detail.permissions))

                if !detail.frontmatterRaw.isEmpty {
                    TextBlock(title: UIStrings.frontmatter, content: detail.frontmatterRaw)
                }
                if !detail.body.isEmpty {
                    TextBlock(title: UIStrings.body, content: detail.body)
                }
            }

            Text(UIStrings.connectedProtocolNote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveMaterialSurface()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var adapterAccessStatus: String {
        if skill.agent == "pi" && adapterCapability?.configToggle.supported == true {
            return UIStrings.piGuardedToggleBoundary
        }
        if skill.agent == "hermes" {
            if skill.provenance.rootKind == .external || skill.provenance.scopeKind == .external {
                return UIStrings.hermesExternalAccess
            }
            return UIStrings.hermesHomeProfileAccess
        }
        if skill.agent == "openclaw" {
            return UIStrings.openClawReadOnlyAccess
        }
        return UIStrings.readOnlyAdapterStatus(DisplayText.agent(skill.agent))
    }
}

private struct ToolGlobalPreviewCard: View {
    @EnvironmentObject private var store: SkillStore
    let skill: SkillRecord
    @State private var target: ToolInstallTarget = .claudeCode
    @State private var preview: ToolGlobalInstallPreview?
    @State private var isPreviewing = false
    @State private var isConfirming = false

    var body: some View {
        let targets = ToolInstallTarget.supportedTargets(from: store.adapterCapabilities)
        let selectedTarget = targets.contains(target) ? target : (targets.first ?? target)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.toolGlobalPreviewTitle, systemImage: "shippingbox")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.toolGlobalPreviewNote)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Picker(UIStrings.toolGlobalTargetAgent, selection: $target) {
                    ForEach(targets) { target in
                        Text(target.title).tag(target)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Button {
                    Task {
                        isPreviewing = true
                        defer { isPreviewing = false }
                        preview = await store.previewToolInstall(skill: skill, target: selectedTarget)
                    }
                } label: {
                    Label(UIStrings.installToAgent, systemImage: "square.and.arrow.down")
                }
                .disabled(store.isRefreshBusy || isPreviewing || targets.isEmpty)
                .help(UIStrings.toolGlobalInstallConfirmation(skill.name, selectedTarget.title))
            }
        }
        .onAppear {
            if let first = targets.first, !targets.contains(target) {
                target = first
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
        .sheet(item: $preview) { preview in
            ToolGlobalInstallPreviewSheet(
                preview: preview,
                isConfirming: isConfirming,
                onConfirm: {
                    Task {
                        isConfirming = true
                        defer { isConfirming = false }
                        if let result = await store.confirmToolInstall(skill: skill, target: preview.target) {
                            self.preview = result
                        }
                    }
                }
            )
        }
    }
}

private struct ToolGlobalInstallPreviewSheet: View {
    let preview: ToolGlobalInstallPreview
    let isConfirming: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.toolGlobalInstallPreviewTitle)
                        .font(.title2.bold())
                    Text(preview.summary)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(UIStrings.done) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                MetadataRow(label: UIStrings.source, value: preview.sourcePath)
                MetadataRow(label: UIStrings.toolGlobalTargetAgent, value: preview.target.title)
                if let targetPath = preview.targetPath {
                    MetadataRow(label: UIStrings.target, value: targetPath)
                }
            }

            Label(preview.confirmationMessage, systemImage: "checkmark.shield")
                .foregroundStyle(.secondary)

            if !preview.risks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(preview.risks, id: \.self) { risk in
                        Label(risk, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Label(UIStrings.toolGlobalInstallReady, systemImage: "checkmark.shield")
                .foregroundStyle(preview.wrote ? .green : .secondary)

            HStack {
                Spacer()
                Button(UIStrings.cancel) {
                    dismiss()
                }
                Button(preview.wrote ? UIStrings.done : UIStrings.confirmInstall) {
                    if preview.wrote {
                        dismiss()
                    } else {
                        onConfirm()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .disabled((!preview.writeBackEnabled && !preview.wrote) || isConfirming)
                    .help(UIStrings.toolGlobalInstallReady)
            }
        }
        .padding(24)
        .frame(width: 720, height: 420)
    }
}

struct FindingSeverityGroup: Identifiable, Equatable {
    let severityKey: String
    let issues: [FindingIssueGroup]

    var id: String { severityKey }

    var title: String {
        FindingDisplayModel.severityTitle(severityKey)
    }
}

struct FindingIssueGroup: Identifiable, Equatable {
    let severityKey: String
    let ruleId: String
    let message: String
    let remediation: String
    let findings: [RuleFindingRecord]

    var id: String {
        [severityKey, ruleId, message, remediation].joined(separator: "\u{1F}")
    }

    var representative: RuleFindingRecord {
        findings[0]
    }

    var impactedInstanceCount: Int {
        let ids = Set(findings.compactMap(\.instanceId))
        return max(ids.count, findings.isEmpty ? 0 : 1)
    }

    var entryCount: Int {
        findings.count
    }

    var explanation: FindingExplanation {
        FindingExplanation(
            ruleId: ruleId,
            severity: severityKey,
            trigger: message,
            remediation: remediation,
            affectedInstanceCount: impactedInstanceCount,
            scanEntryCount: entryCount,
            ruleSource: FindingRuleSource.classify(ruleId: ruleId),
            ruleCategory: FindingRuleCategory.classify(ruleId: ruleId),
            isRiskCategoryFinding: FindingExplainabilityModel.isRiskCategoryRuleID(ruleId)
        )
    }

    var triageKeys: [String] {
        Array(Set(findings.map(\.triageKey).filter { !$0.isEmpty })).sorted()
    }

    var triageStatus: FindingTriageStatus {
        FindingTriageModel.groupStatus(for: findings.map(\.triageState))
    }

    func matchesTriageFilter(_ filter: FindingTriageFilter) -> Bool {
        findings.map(\.triageState).contains { filter.includes($0) }
    }

    var ruleSource: String {
        FindingDisplayModel.ruleSourceTitle(for: explanation.ruleSource)
    }

    var catalogTarget: String {
        FindingDisplayModel.catalogTargetSummary(for: representative)
    }

    var isRiskRelated: Bool {
        explanation.isRiskCategoryFinding
    }
}

private struct FindingIssueKey: Hashable {
    let severityKey: String
    let ruleId: String
    let message: String
    let remediation: String
}

enum FindingDisplayModel {
    static let allFilterValue = "__all__"

    static func severityOptions(for findings: [RuleFindingRecord]) -> [String] {
        sortedSeverities(Set(findings.map { severityKey($0.severity) }))
    }

    static func ruleIDOptions(for findings: [RuleFindingRecord]) -> [String] {
        Array(Set(findings.map(\.ruleId)))
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
    }

    static func filtered(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [RuleFindingRecord] {
        findings.filter { finding in
            let matchesSeverity = severityFilter == allFilterValue || severityKey(finding.severity) == severityFilter
            let matchesRule = ruleFilter == allFilterValue || finding.ruleId == ruleFilter
            return matchesSeverity && matchesRule
        }
    }

    static func grouped(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [FindingSeverityGroup] {
        let visibleIssues = issueGroups(
            findings: findings,
            severityFilter: severityFilter,
            ruleFilter: ruleFilter
        )
        let grouped = Dictionary(grouping: visibleIssues, by: \.severityKey)

        return sortedSeverities(Set(grouped.keys)).map { severityKey in
            FindingSeverityGroup(
                severityKey: severityKey,
                issues: grouped[severityKey] ?? []
            )
        }
    }

    static func issueGroups(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [FindingIssueGroup] {
        let visibleFindings = filtered(findings: findings, severityFilter: severityFilter, ruleFilter: ruleFilter)
        let grouped = Dictionary(grouping: visibleFindings) { finding in
            FindingIssueKey(
                severityKey: severityKey(finding.severity),
                ruleId: normalizedText(finding.ruleId),
                message: normalizedText(finding.message),
                remediation: normalizedText(remediationText(for: finding))
            )
        }
        return grouped.map { key, findings in
            FindingIssueGroup(
                severityKey: key.severityKey,
                ruleId: key.ruleId,
                message: key.message,
                remediation: key.remediation,
                findings: sortedFindings(findings)
            )
        }
        .sorted(by: compareIssueGroups)
    }

    static func remediationText(for finding: RuleFindingRecord) -> String {
        if let suggestion = finding.suggestion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !suggestion.isEmpty {
            return suggestion
        }

        switch finding.ruleId {
        case "frontmatter.required-fields":
            return UIStrings.remediationFrontmatterRequired
        case "frontmatter.tools-not-empty":
            return UIStrings.remediationToolsNotEmpty
        case "path.exists":
            return UIStrings.remediationPathExists
        case "fingerprint.changed":
            return UIStrings.remediationFingerprintChanged
        case "permissions.network-declared":
            return UIStrings.remediationNetworkDeclared
        case "permissions.exec-needs-human":
            return UIStrings.remediationExecNeedsHuman
        case "dependency.unknown":
            return UIStrings.remediationDependencyUnknown
        default:
            return UIStrings.findingRemediationFallback(finding.ruleId)
        }
    }

    static func ruleSource(for ruleId: String) -> FindingRuleSource {
        FindingRuleSource.classify(ruleId: ruleId)
    }

    static func ruleCategory(for ruleId: String) -> FindingRuleCategory {
        FindingRuleCategory.classify(ruleId: ruleId)
    }

    static func isRiskCategoryRuleID(_ ruleId: String) -> Bool {
        FindingExplainabilityModel.isRiskCategoryRuleID(ruleId)
    }

    static func ruleSourceTitle(for source: FindingRuleSource) -> String {
        switch source {
        case .frontmatter:
            return UIStrings.findingSourceFrontmatter
        case .permissions:
            return UIStrings.findingSourcePermission
        case .script:
            return UIStrings.findingSourceScript
        case .dependency:
            return UIStrings.findingSourceDependency
        case .path:
            return UIStrings.findingSourcePath
        case .fingerprint:
            return UIStrings.findingSourceFingerprint
        case .name, .body, .custom:
            return UIStrings.findingSourceCatalog
        }
    }

    static func catalogTargetSummary(for finding: RuleFindingRecord) -> String {
        let definition = normalizedOptional(finding.definitionId)
        let instance = normalizedOptional(finding.instanceId)

        switch (definition, instance) {
        case (.some(let definition), .some(let instance)):
            return UIStrings.findingCatalogTarget(definition: definition, instance: instance)
        case (.some(let definition), .none):
            return UIStrings.findingCatalogDefinition(definition)
        case (.none, .some(let instance)):
            return UIStrings.findingCatalogInstance(instance)
        case (.none, .none):
            return UIStrings.findingNoCatalogTarget
        }
    }

    static func severityTitle(_ severityKey: String) -> String {
        if severityKey == "unknown" {
            return UIStrings.unknown.uppercased()
        }
        return severityKey.uppercased()
    }

    static func severityKey(_ severity: String) -> String {
        let normalized = severity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? "unknown" : normalized
    }

    private static func sortedSeverities(_ severities: Set<String>) -> [String] {
        severities.sorted { lhs, rhs in
            let lhsRank = severityRank(lhs)
            let rhsRank = severityRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private static func sortedFindings(_ findings: [RuleFindingRecord]) -> [RuleFindingRecord] {
        findings.sorted { lhs, rhs in
            if lhs.ruleId != rhs.ruleId {
                return lhs.ruleId.localizedStandardCompare(rhs.ruleId) == .orderedAscending
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private static func compareIssueGroups(_ lhs: FindingIssueGroup, _ rhs: FindingIssueGroup) -> Bool {
        let lhsRank = severityRank(lhs.severityKey)
        let rhsRank = severityRank(rhs.severityKey)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        if lhs.ruleId != rhs.ruleId {
            return lhs.ruleId.localizedStandardCompare(rhs.ruleId) == .orderedAscending
        }
        let lhsCreatedAt = lhs.representative.createdAt
        let rhsCreatedAt = rhs.representative.createdAt
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt > rhsCreatedAt
        }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }

    private static func normalizedText(_ text: String) -> String {
        let collapsed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? UIStrings.emptyPlaceholder : collapsed
    }

    private static func normalizedOptional(_ text: String?) -> String? {
        guard let text else {
            return nil
        }
        let normalized = normalizedText(text)
        return normalized == UIStrings.emptyPlaceholder ? nil : normalized
    }

    private static func severityRank(_ severityKey: String) -> Int {
        switch severityKey {
        case "critical":
            return 0
        case "error":
            return 1
        case "warning", "warn":
            return 2
        case "info", "notice":
            return 3
        default:
            return 10
        }
    }
}

struct PermissionSummaryRow: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String { label }
}

struct PermissionSummary: Equatable {
    let rows: [PermissionSummaryRow]
    let note: String
    let rawText: String
}

enum PermissionDisplayModel {
    static func summary(for permissions: JSONValue) -> PermissionSummary {
        let rawText = rawDescription(permissions)

        guard case .object(let object) = permissions, !object.isEmpty else {
            return PermissionSummary(
                rows: [
                    PermissionSummaryRow(label: UIStrings.permissions, value: UIStrings.permissionUndeclared)
                ],
                note: UIStrings.permissionUndeclaredNote,
                rawText: rawText
            )
        }

        return PermissionSummary(
            rows: [
                PermissionSummaryRow(label: UIStrings.permissionTools, value: stringArrayValue(object["tools"])),
                PermissionSummaryRow(label: UIStrings.permissionFiles, value: stringArrayValue(object["files"])),
                PermissionSummaryRow(label: UIStrings.permissionNetwork, value: networkValue(object["network"])),
                PermissionSummaryRow(label: UIStrings.permissionExec, value: boolValue(object["exec"], trueText: UIStrings.permissionRequested, falseText: UIStrings.permissionNotRequested)),
                PermissionSummaryRow(label: UIStrings.permissionHumanReview, value: boolValue(object["requires_human"], trueText: UIStrings.permissionRequired, falseText: UIStrings.permissionNotDeclaredRequired)),
            ],
            note: UIStrings.permissionDeclarationNote,
            rawText: rawText
        )
    }

    private static func stringArrayValue(_ value: JSONValue?) -> String {
        guard let value else {
            return UIStrings.permissionUndeclared
        }
        guard case .array(let items) = value else {
            return UIStrings.permissionUnknownPayload
        }

        let strings = items.compactMap { item -> String? in
            guard case .string(let text) = item else {
                return nil
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        if strings.count != items.count {
            return UIStrings.permissionUnknownPayload
        }
        return strings.isEmpty ? UIStrings.permissionNoneDeclared : strings.joined(separator: ", ")
    }

    private static func networkValue(_ value: JSONValue?) -> String {
        guard let value else {
            return UIStrings.permissionUndeclared
        }
        guard case .string(let text) = value else {
            return UIStrings.permissionUnknownPayload
        }

        switch text {
        case "none":
            return UIStrings.permissionNoneDeclared
        case "read-only":
            return UIStrings.permissionNetworkReadOnly
        case "full":
            return UIStrings.permissionNetworkFull
        default:
            return UIStrings.permissionUnknownValue(text)
        }
    }

    private static func boolValue(_ value: JSONValue?, trueText: String, falseText: String) -> String {
        guard let value else {
            return UIStrings.permissionUndeclared
        }
        guard case .bool(let bool) = value else {
            return UIStrings.permissionUnknownPayload
        }
        return bool ? trueText : falseText
    }

    private static func rawDescription(_ value: JSONValue) -> String {
        switch value {
        case .string(let text):
            return "\"\(escaped(text))\""
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .object(let object):
            let fields = object.keys.sorted().map { key in
                "\"\(escaped(key))\": \(rawDescription(object[key] ?? .null))"
            }
            return "{\(fields.joined(separator: ", "))}"
        case .array(let values):
            return "[\(values.map(rawDescription).joined(separator: ", "))]"
        case .null:
            return "null"
        }
    }

    private static func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

private struct FindingsSection: View {
    @EnvironmentObject private var store: SkillStore
    let skill: SkillRecord
    let findings: [RuleFindingRecord]
    @State private var severityFilter = FindingDisplayModel.allFilterValue
    @State private var ruleFilter = FindingDisplayModel.allFilterValue
    @State private var triageFilter: FindingTriageFilter = .active

    private var severityOptions: [String] {
        FindingDisplayModel.severityOptions(for: findings)
    }

    private var ruleIDOptions: [String] {
        FindingDisplayModel.ruleIDOptions(for: findings)
    }

    private var visibleGroups: [FindingSeverityGroup] {
        FindingDisplayModel.grouped(
            findings: findings,
            severityFilter: severityFilter,
            ruleFilter: ruleFilter
        ).compactMap { group in
            let visibleIssues = group.issues.filter { issue in
                issue.matchesTriageFilter(triageFilter)
            }
            guard !visibleIssues.isEmpty else { return nil }
            return FindingSeverityGroup(severityKey: group.severityKey, issues: visibleIssues)
        }
    }

    private var visibleIssueCount: Int {
        visibleGroups.reduce(0) { $0 + $1.issues.count }
    }

    private var visibleEntryCount: Int {
        visibleGroups.reduce(0) { total, severityGroup in
            total + severityGroup.issues.reduce(0) { $0 + $1.entryCount }
        }
    }

    private var allIssueGroups: [FindingIssueGroup] {
        FindingDisplayModel.issueGroups(
            findings: findings,
            severityFilter: FindingDisplayModel.allFilterValue,
            ruleFilter: FindingDisplayModel.allFilterValue
        )
    }

    private var totalIssueCount: Int {
        allIssueGroups.count
    }

    private var visibleImpactedCount: Int {
        let ids = Set(visibleGroups.flatMap { group in
            group.issues.flatMap { issue in
                issue.findings.compactMap(\.instanceId)
            }
        })
        return max(ids.count, visibleEntryCount == 0 ? 0 : 1)
    }

    private var triageCounts: FindingTriageCounts {
        FindingTriageModel.counts(for: allIssueGroups.map(\.triageStatus))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if findings.isEmpty {
                EmptyState(
                    title: UIStrings.noFindings,
                    systemImage: "checkmark.seal",
                    message: UIStrings.noFindingsForSkillMessage(DisplayText.agent(skill.agent))
                )
            } else {
                FindingTriageNotice()

                FindingsSummaryStrip(
                    visibleIssueCount: visibleIssueCount,
                    totalIssueCount: totalIssueCount,
                    visibleEntryCount: visibleEntryCount,
                    visibleImpactedCount: visibleImpactedCount,
                    triageCounts: triageCounts
                )

                findingFilters

                if visibleGroups.isEmpty {
                    EmptyState(
                        title: UIStrings.noMatchingFindings,
                        systemImage: "line.3.horizontal.decrease.circle",
                        message: UIStrings.noMatchingFindingsMessage
                    )
                } else {
                    ForEach(visibleGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            FindingSeverityHeader(group: group)

                            ForEach(group.issues) { issue in
                                FindingIssueCard(
                                    issue: issue,
                                    severityTitle: group.title,
                                    triageStatus: issue.triageStatus,
                                    ruleTuning: store.ruleTuningRecord(ruleId: issue.ruleId),
                                    groupTuning: store.ruleTuningRecord(ruleId: issue.ruleId, findingGroupID: issue.id),
                                    isUpdatingRuleTuning: store.isWriting,
                                    onSetTriageStatus: { status in
                                        store.setFindingTriageStatus(status, for: issue.triageKeys)
                                    },
                                    onSetSeverityOverride: { severity in
                                        store.setRuleSeverityOverride(severity, for: issue.ruleId)
                                    },
                                    onClearSeverityOverride: {
                                        store.clearRuleSeverityOverride(for: issue.ruleId)
                                    },
                                    onSetSuppression: { scope in
                                        store.setRuleSuppression(ruleId: issue.ruleId, findingGroupID: issue.id, scope: scope)
                                    },
                                    onClearSuppression: { scope in
                                        store.clearRuleSuppression(ruleId: issue.ruleId, findingGroupID: issue.id, scope: scope)
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .onChange(of: findings) { _ in
            clampFilters()
        }
    }

    private var findingFilters: some View {
        HStack(spacing: 10) {
            Picker(UIStrings.findingTriageFilter, selection: $triageFilter) {
                ForEach(FindingTriageFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .help(UIStrings.findingTriageFilter)

            Picker(UIStrings.findingSeverityFilter, selection: $severityFilter) {
                Text(UIStrings.allSeverities).tag(FindingDisplayModel.allFilterValue)
                ForEach(severityOptions, id: \.self) { severity in
                    Text(FindingDisplayModel.severityTitle(severity)).tag(severity)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170)
            .help(UIStrings.findingSeverityFilter)

            Picker(UIStrings.findingRuleFilter, selection: $ruleFilter) {
                Text(UIStrings.allRuleIDs).tag(FindingDisplayModel.allFilterValue)
                ForEach(ruleIDOptions, id: \.self) { ruleID in
                    Text(ruleID).tag(ruleID)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 260)
            .help(UIStrings.findingRuleFilter)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(UIStrings.visibleFindingGroupsSummary(visibleIssueCount, totalIssueCount, visibleEntryCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(UIStrings.findingScopeSummary(skill.name, DisplayText.agent(skill.agent)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clampFilters() {
        if severityFilter != FindingDisplayModel.allFilterValue && !severityOptions.contains(severityFilter) {
            severityFilter = FindingDisplayModel.allFilterValue
        }
        if ruleFilter != FindingDisplayModel.allFilterValue && !ruleIDOptions.contains(ruleFilter) {
            ruleFilter = FindingDisplayModel.allFilterValue
        }
    }
}

private struct FindingTriageNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(UIStrings.findingTriageNoticeTitle, systemImage: "tray.full")
                .font(.headline)
            Text(UIStrings.findingTriageNoticeBody)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct FindingsSummaryStrip: View {
    let visibleIssueCount: Int
    let totalIssueCount: Int
    let visibleEntryCount: Int
    let visibleImpactedCount: Int
    let triageCounts: FindingTriageCounts

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], alignment: .leading, spacing: 10) {
            SummaryChip(title: UIStrings.text("findings.summary.issueGroups", "Issue groups"), value: "\(visibleIssueCount) / \(totalIssueCount)", systemImage: "rectangle.stack.badge.exclamationmark")
            SummaryChip(title: UIStrings.text("findings.summary.impacted", "Impacted"), value: "\(visibleImpactedCount)", systemImage: "target")
            SummaryChip(title: UIStrings.text("findings.summary.entries", "Scan entries"), value: "\(visibleEntryCount)", systemImage: "list.bullet.rectangle")
            SummaryChip(title: UIStrings.findingTriageFilter, value: "\(UIStrings.findingTriageOpen) \(triageCounts.open) · \(UIStrings.findingTriageNeedsFollowUp) \(triageCounts.needsFollowUp)", systemImage: "tray.full")
            SummaryChip(title: UIStrings.findingRemediation, value: UIStrings.text("findings.summary.remediation", "Grouped below"), systemImage: "wrench.and.screwdriver")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct FindingIssueCard: View {
    let issue: FindingIssueGroup
    let severityTitle: String
    let triageStatus: FindingTriageStatus
    let ruleTuning: RuleTuningRecord?
    let groupTuning: RuleTuningRecord?
    let isUpdatingRuleTuning: Bool
    let onSetTriageStatus: (FindingTriageStatus) -> Void
    let onSetSeverityOverride: (String) -> Void
    let onClearSeverityOverride: () -> Void
    let onSetSuppression: (RuleTuningScope) -> Void
    let onClearSuppression: (RuleTuningScope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(UIStrings.findingTrigger, systemImage: "exclamationmark.bubble")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if issue.isRiskRelated {
                    Label(UIStrings.findingRiskRelated, systemImage: "shield.lefthalf.filled")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.14), in: Capsule())
                        .help(UIStrings.findingRiskRelatedHelp)
                }
                Label(triageStatus.title, systemImage: triageStatus.systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(triageStatus.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(triageStatus.tint.opacity(0.14), in: Capsule())
                Text(severityTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.35), in: Capsule())
            }

            Text(issue.message)
                .font(.headline)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 8) {
                Label(UIStrings.findingExplanation, systemImage: "list.bullet.clipboard")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
                    FindingExplanationField(title: UIStrings.findingRuleID, value: issue.ruleId, systemImage: "number")
                    FindingExplanationField(title: UIStrings.findingRuleSource, value: issue.ruleSource, systemImage: "scope")
                    FindingExplanationField(title: UIStrings.findingCatalogTarget, value: issue.catalogTarget, systemImage: "shippingbox")
                    FindingExplanationField(title: UIStrings.findingImpact, value: UIStrings.findingIssueImpact(issue.impactedInstanceCount, issue.entryCount), systemImage: "target")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Label(UIStrings.findingRemediation, systemImage: "wrench.and.screwdriver")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Text(issue.remediation)
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))

            RuleTuningActionPanel(
                issue: issue,
                ruleTuning: ruleTuning,
                groupTuning: groupTuning,
                isUpdating: isUpdatingRuleTuning,
                onSetSeverityOverride: onSetSeverityOverride,
                onClearSeverityOverride: onClearSeverityOverride,
                onSetSuppression: onSetSuppression,
                onClearSuppression: onClearSuppression
            )

            FindingTriageActionBar(status: triageStatus, onSet: onSetTriageStatus)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RuleTuningActionPanel: View {
    let issue: FindingIssueGroup
    let ruleTuning: RuleTuningRecord?
    let groupTuning: RuleTuningRecord?
    let isUpdating: Bool
    let onSetSeverityOverride: (String) -> Void
    let onClearSeverityOverride: () -> Void
    let onSetSuppression: (RuleTuningScope) -> Void
    let onClearSuppression: (RuleTuningScope) -> Void

    private var effectiveSeverity: String {
        groupTuning?.effectiveSeverity ?? ruleTuning?.effectiveSeverity ?? issue.severityKey
    }

    private var ruleSuppressed: Bool {
        ruleTuning?.suppressed == true
    }

    private var groupSuppressed: Bool {
        groupTuning?.suppressed == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(UIStrings.ruleTuningTitle, systemImage: "slider.horizontal.3")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                RuleTuningStateChip(
                    title: UIStrings.ruleTuningEffectiveState,
                    value: FindingDisplayModel.severityTitle(effectiveSeverity),
                    systemImage: "gauge.with.dots.needle.67percent"
                )
                if ruleTuning?.severityOverride != nil {
                    RuleTuningStateChip(
                        title: UIStrings.ruleTuningSeverityOverride,
                        value: FindingDisplayModel.severityTitle(ruleTuning?.severityOverride ?? effectiveSeverity),
                        systemImage: "arrow.up.arrow.down.circle"
                    )
                }
                if ruleSuppressed || groupSuppressed {
                    RuleTuningStateChip(
                        title: groupSuppressed ? UIStrings.ruleTuningFindingGroup : UIStrings.ruleTuningRuleWide,
                        value: UIStrings.ruleTuningSuppressed,
                        systemImage: "eye.slash"
                    )
                }
            }

            Text(UIStrings.ruleTuningBoundary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Menu(UIStrings.ruleTuningSeverityOverride) {
                    ForEach(RuleTuningModel.overrideSeverities, id: \.self) { severity in
                        Button(UIStrings.ruleTuningSetSeverity(FindingDisplayModel.severityTitle(severity))) {
                            onSetSeverityOverride(severity)
                        }
                    }
                    if ruleTuning?.severityOverride != nil {
                        Divider()
                        Button(UIStrings.ruleTuningClearSeverity) {
                            onClearSeverityOverride()
                        }
                    }
                }

                Button(groupSuppressed ? UIStrings.ruleTuningUnsuppressGroup : UIStrings.ruleTuningSuppressGroup) {
                    groupSuppressed ? onClearSuppression(.findingGroup) : onSetSuppression(.findingGroup)
                }

                Button(ruleSuppressed ? UIStrings.ruleTuningUnsuppressRule : UIStrings.ruleTuningSuppressRule) {
                    ruleSuppressed ? onClearSuppression(.rule) : onSetSuppression(.rule)
                }

                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isUpdating)
            .help(UIStrings.ruleTuningBoundary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RuleTuningStateChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            Text("\(title): \(value)")
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption2.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.35), in: Capsule())
    }
}

private struct FindingTriageActionBar: View {
    let status: FindingTriageStatus
    let onSet: (FindingTriageStatus) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label(UIStrings.findingTriageFilter, systemImage: "tray.full")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if status != .reviewed {
                Button(UIStrings.findingTriageActionReviewed) {
                    onSet(.reviewed)
                }
            }

            if status != .needsFollowUp {
                Button(UIStrings.findingTriageActionFollowUp) {
                    onSet(.needsFollowUp)
                }
            }

            if status != .ignored {
                Button(UIStrings.findingTriageActionIgnored) {
                    onSet(.ignored)
                }
            }

            if status != .open {
                Button(UIStrings.findingTriageActionReopen) {
                    onSet(.open)
                }
            }

            Spacer(minLength: 0)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private extension FindingTriageStatus {
    var tint: Color {
        switch self {
        case .open:
            return .blue
        case .reviewed:
            return .green
        case .ignored:
            return .secondary
        case .needsFollowUp:
            return .orange
        }
    }
}

private struct FindingExplanationField: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct FindingSeverityHeader: View {
    let group: FindingSeverityGroup

    var body: some View {
        HStack(spacing: 8) {
            Label(group.title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            Text(UIStrings.findingSeverityGroupCount(group.issues.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private var systemImage: String {
        switch group.severityKey {
        case "critical", "error":
            return "xmark.octagon"
        case "warning", "warn":
            return "exclamationmark.triangle"
        case "info", "notice":
            return "info.circle"
        default:
            return "questionmark.circle"
        }
    }

    private var tint: Color {
        switch group.severityKey {
        case "critical", "error":
            return .red
        case "warning", "warn":
            return .orange
        case "info", "notice":
            return .blue
        default:
            return .secondary
        }
    }
}

private struct PermissionSummaryCard: View {
    let summary: PermissionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.permissions, systemImage: "hand.raised")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                ForEach(summary.rows) { row in
                    MetadataRow(label: row.label, value: row.value)
                }
            }

            Text(summary.note)
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(UIStrings.permissionRaw)
                    .font(.subheadline.bold())
                Text(summary.rawText)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct ConflictsSection: View {
    let conflicts: [ConflictGroupRecord]
    let selectedSkillID: String
    let currentAgentSkillIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label(UIStrings.text("conflicts.sameAgentWorkbench", "Current-agent conflict workbench"), systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.headline)
                Text(UIStrings.text("conflicts.sameAgentExplanation", "Conflicts only include current-agent runtime/name collisions. Cross-agent duplicate names and source overlap are analysis insights, so they are reviewed from the Analysis tab instead of inflating conflict counts."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            if conflicts.isEmpty {
                EmptyState(title: UIStrings.noConflicts, systemImage: "checkmark.circle", message: UIStrings.noConflictsMessage)
            } else {
                ForEach(conflicts) { conflict in
                    let currentAgentInstanceIDs = conflict.instanceIds.filter { currentAgentSkillIDs.contains($0) }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(conflict.reason)
                                .font(.headline)
                            Spacer()
                            Text(UIStrings.text("conflicts.currentAgentOnlyBadge", "current agent only"))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.35), in: Capsule())
                        }
                        MetadataLine(label: UIStrings.definition, value: conflict.definitionId)
                        MetadataLine(label: UIStrings.winner, value: conflict.winnerId ?? UIStrings.none)
                        Text(UIStrings.instances)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(currentAgentInstanceIDs, id: \.self) { instanceID in
                            Label(
                                instanceID == selectedSkillID ? "\(instanceID) · selected" : instanceID,
                                systemImage: instanceID == selectedSkillID ? "target" : "circle"
                            )
                            .font(.caption)
                            .textSelection(.enabled)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .adaptiveMaterialSurface()
                }
            }
        }
    }
}

struct AgentConfigHistorySection: View {
    let snapshots: [ConfigSnapshotRecord]
    let isWriting: Bool
    let onPreview: (String) async throws -> SnapshotRollbackPreviewRecord
    let onRollback: (String) async -> Void
    @State private var preview: SnapshotRollbackPreviewRecord?
    @State private var previewError: String?
    @State private var snapshotToRollback: ConfigSnapshotRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let previewError {
                ErrorBanner(message: previewError)
            }

            if snapshots.isEmpty {
                EmptyState(title: UIStrings.noSnapshots, systemImage: "clock.badge.questionmark", message: UIStrings.noSnapshotsMessage)
            } else {
                ForEach(snapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(snapshot.reason)
                                        .font(.headline)
                                    Text(DisplayText.timestamp(snapshot.createdAt))
                                        .foregroundStyle(.secondary)
                                }
                                MetadataLine(label: UIStrings.target, value: snapshot.target)
                                MetadataLine(label: UIStrings.scope, value: DisplayText.scope(snapshot.scope))
                                Text(UIStrings.charactersCaptured(snapshot.content.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    loadPreview(snapshot.id)
                                } label: {
                                    Label(UIStrings.preview, systemImage: "eye")
                                }
                                .disabled(isWriting)

                                Button(role: .destructive) {
                                    snapshotToRollback = snapshot
                                } label: {
                                    Label(UIStrings.rollback, systemImage: "arrow.uturn.backward")
                                }
                                .disabled(isWriting)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .adaptiveMaterialSurface()
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
            Text(snapshotToRollback?.target ?? "")
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

struct SnapshotPreviewSheet: View {
    let preview: SnapshotRollbackPreviewRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.snapshotPreview)
                        .font(.title2.bold())
                    Text(preview.snapshot.target)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button(UIStrings.done) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Label(
                preview.changed ? UIStrings.currentDiffersFromSnapshot : UIStrings.currentMatchesSnapshot,
                systemImage: preview.changed ? "exclamationmark.triangle" : "checkmark.circle"
            )
            .foregroundStyle(preview.changed ? .orange : .green)

            if let readError = preview.currentReadError {
                ErrorBanner(message: readError)
            }

            HStack(alignment: .top, spacing: 14) {
                SnapshotTextPane(title: UIStrings.current, content: preview.currentContent.isEmpty ? UIStrings.emptyPlaceholder : preview.currentContent)
                SnapshotTextPane(title: UIStrings.snapshot, content: preview.snapshot.content.isEmpty ? UIStrings.emptyPlaceholder : preview.snapshot.content)
            }
            .frame(minHeight: 420)
        }
        .padding(24)
        .frame(width: 980, height: 680)
    }
}

private struct SnapshotTextPane: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ScrollView([.vertical, .horizontal]) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct TextBlock: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

private struct MetadataLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

private struct EmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: 900, minHeight: 220)
        .adaptiveMaterialSurface()
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
    }
}

private struct SuccessBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
    }
}
