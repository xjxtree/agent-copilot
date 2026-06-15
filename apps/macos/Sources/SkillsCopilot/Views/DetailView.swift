import AppKit
import SwiftUI

enum DetailSection: String, CaseIterable, Identifiable {
    case taskCockpit
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
        [.taskCockpit, .skillMap, .guidedCleanup, .observability, .analysis]
    }

    var title: String {
        switch self {
        case .taskCockpit:
            return UIStrings.taskCockpitTitle
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

                if store.selectedDetailSection == .taskCockpit {
                    DetailSectionSwitcher(selection: $store.selectedDetailSection)

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
                } else if store.selectedDetailSection == .guidedCleanup {
                    DetailSectionSwitcher(selection: $store.selectedDetailSection)

                    GuidedCleanupFlowPanel(
                        result: store.guidedCleanupFlowResult,
                        recordResult: store.guidedCleanupRecordResult,
                        isPlanning: store.isPlanningGuidedCleanupFlow,
                        isRecording: store.isRecordingGuidedCleanupStep,
                        onLoad: {
                            Task {
                                await store.planGuidedCleanupFlow()
                            }
                        },
                        onRecord: { step in
                            Task {
                                await store.recordGuidedCleanupStep(step)
                            }
                        },
                        onOpenSafeLink: { link, step in
                            Task {
                                await store.openGuidedCleanupSafeLink(link, step: step)
                            }
                        }
                    )
                } else if store.selectedDetailSection == .observability {
                    DetailSectionSwitcher(selection: $store.selectedDetailSection)

                    ProviderObservabilityPanel(
                        result: store.providerObservabilityResult,
                        isLoading: store.isLoadingProviderObservability,
                        onLoad: {
                            Task {
                                await store.loadProviderObservability()
                            }
                        }
                    )
                } else if let skill {
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
                    case .taskCockpit, .guidedCleanup, .observability:
                        EmptyView()
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
                    case .skillMap:
                        VStack(alignment: .leading, spacing: 16) {
                            LocalSkillMapPanel(
                                skill: skill,
                                result: store.localSkillMapResult,
                                isBuilding: store.isBuildingLocalSkillMap,
                                onBuild: {
                                    Task {
                                        await store.buildLocalSkillMap()
                                    }
                                }
                            )

                            SkillLifecycleTimelinePanel(
                                skill: skill,
                                result: store.skillLifecycleTimelineResult,
                                isLoading: store.isLoadingSkillLifecycleTimeline,
                                onLoad: {
                                    Task {
                                        await store.loadSkillLifecycleTimeline()
                                    }
                                }
                            )
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
                            taskCockpitText: $store.taskCockpitText,
                            taskCockpitInput: store.selectedTaskCockpitInput,
                            taskCockpitResult: store.taskCockpitResult,
                            isBuildingTaskCockpit: store.isBuildingTaskCockpit,
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
                            crossAgentReadinessText: $store.crossAgentReadinessText,
                            crossAgentReadinessInput: store.selectedCrossAgentReadinessInput,
                            crossAgentReadinessResult: store.crossAgentReadinessResult,
                            isComparingCrossAgentReadiness: store.isComparingCrossAgentReadiness,
                            routingAccuracyDashboard: store.routingAccuracyDashboard,
                            isLoadingRoutingAccuracyDashboard: store.isLoadingRoutingAccuracyDashboard,
                            staleDriftDetection: store.staleDriftDetection,
                            isDetectingStaleDrift: store.isDetectingStaleDrift,
                            knowledgeSearchText: $store.knowledgeSearchText,
                            knowledgeSearchResult: store.knowledgeSearchResult,
                            isSearchingKnowledge: store.isSearchingKnowledge,
                            localSkillMapResult: store.localSkillMapResult,
                            isBuildingLocalSkillMap: store.isBuildingLocalSkillMap,
                            skillLifecycleTimelineResult: store.skillLifecycleTimelineResult,
                            isLoadingSkillLifecycleTimeline: store.isLoadingSkillLifecycleTimeline,
                            providerObservabilityResult: store.providerObservabilityResult,
                            isLoadingProviderObservability: store.isLoadingProviderObservability,
                            similarSkillGroupingResult: store.similarSkillGroupingResult,
                            isGroupingSimilarSkills: store.isGroupingSimilarSkills,
                            capabilityTaxonomyResult: store.capabilityTaxonomyResult,
                            isBuildingCapabilityTaxonomy: store.isBuildingCapabilityTaxonomy,
                            workspaceReadinessResult: store.workspaceReadinessResult,
                            isCheckingWorkspaceReadiness: store.isCheckingWorkspaceReadiness,
                            remediationPlanResult: store.remediationPlanResult,
                            isPlanningRemediation: store.isPlanningRemediation,
                            remediationPreviewDraftsResult: store.remediationPreviewDraftsResult,
                            isPreviewingRemediationDrafts: store.isPreviewingRemediationDrafts,
                            remediationImpactPreviewResult: store.remediationImpactPreviewResult,
                            isPreviewingRemediationImpact: store.isPreviewingRemediationImpact,
                            remediationBatchReviewResult: store.remediationBatchReviewResult,
                            isReviewingRemediationBatch: store.isReviewingRemediationBatch,
                            remediationHistoryResult: store.remediationHistoryResult,
                            remediationHistoryRecordResult: store.remediationHistoryRecordResult,
                            isLoadingRemediationHistory: store.isLoadingRemediationHistory,
                            isRecordingRemediationHistory: store.isRecordingRemediationHistory,
                            guidedCleanupFlowResult: store.guidedCleanupFlowResult,
                            guidedCleanupRecordResult: store.guidedCleanupRecordResult,
                            isPlanningGuidedCleanupFlow: store.isPlanningGuidedCleanupFlow,
                            isRecordingGuidedCleanupStep: store.isRecordingGuidedCleanupStep,
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
                            onBuildTaskCockpit: {
                                Task {
                                    await store.buildTaskCockpit()
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
                            onCompareCrossAgentReadiness: {
                                Task {
                                    await store.compareCrossAgentReadiness()
                                }
                            },
                            onLoadRoutingAccuracyDashboard: {
                                Task {
                                    await store.loadRoutingAccuracyDashboard()
                                }
                            },
                            onDetectStaleDrift: {
                                Task {
                                    await store.detectStaleDrift()
                                }
                            },
                            onSearchKnowledge: {
                                Task {
                                    await store.searchKnowledge()
                                }
                            },
                            onBuildLocalSkillMap: {
                                Task {
                                    await store.buildLocalSkillMap()
                                }
                            },
                            onLoadSkillLifecycleTimeline: {
                                Task {
                                    await store.loadSkillLifecycleTimeline()
                                }
                            },
                            onLoadProviderObservability: {
                                Task {
                                    await store.loadProviderObservability()
                                }
                            },
                            onGroupSimilarSkills: {
                                Task {
                                    await store.groupSimilarSkills()
                                }
                            },
                            onBuildCapabilityTaxonomy: {
                                Task {
                                    await store.buildCapabilityTaxonomy()
                                }
                            },
                            onCheckWorkspaceReadiness: {
                                Task {
                                    await store.checkWorkspaceReadiness()
                                }
                            },
                            onPlanRemediation: {
                                Task {
                                    await store.planRemediation()
                                }
                            },
                            onPreviewRemediationDrafts: {
                                Task {
                                    await store.previewRemediationDrafts()
                                }
                            },
                            onPreviewRemediationImpact: {
                                Task {
                                    await store.previewRemediationImpact()
                                }
                            },
                            onReviewRemediationBatch: { options in
                                Task {
                                    await store.reviewRemediationBatch(options: options)
                                }
                            },
                            onLoadRemediationHistory: {
                                Task {
                                    await store.loadRemediationHistory()
                                }
                            },
                            onRecordRemediationHistory: {
                                Task {
                                    await store.recordRemediationHistory()
                                }
                            },
                            onPlanGuidedCleanupFlow: {
                                Task {
                                    await store.planGuidedCleanupFlow()
                                }
                            },
                            onRecordGuidedCleanupStep: { step in
                                Task {
                                    await store.recordGuidedCleanupStep(step)
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
                            agentSessionSkillReviewTranscript: $store.agentSessionSkillReviewTranscript,
                            agentSessionSkillReviewTask: $store.agentSessionSkillReviewTask,
                            agentSessionSkillReviewExpectedSkills: $store.agentSessionSkillReviewExpectedSkills,
                            agentSessionSkillReviewList: store.agentSessionSkillReviewList,
                            agentSessionSkillReviewResult: store.agentSessionSkillReviewResult,
                            agentSessionSkillReviewDeleteResult: store.agentSessionSkillReviewDeleteResult,
                            latestAgentSessionSkillReview: store.latestAgentSessionSkillReview,
                            isLoadingAgentSessionSkillReviews: store.isLoadingAgentSessionSkillReviews,
                            isReviewingAgentSessionSkillUse: store.isReviewingAgentSessionSkillUse,
                            isDeletingAgentSessionSkillReview: { record in store.isDeletingAgentSessionSkillReview(record) },
                            onLoadAgentSessionSkillReviews: {
                                Task {
                                    await store.loadAgentSessionSkillReviews()
                                }
                            },
                            onReviewAgentSessionSkillUse: {
                                Task {
                                    await store.reviewAgentSessionSkillUse()
                                }
                            },
                            onDeleteAgentSessionSkillReview: { record in
                                Task {
                                    await store.deleteAgentSessionSkillReview(record)
                                }
                            },
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
    @Binding var taskCockpitText: String
    let taskCockpitInput: String
    let taskCockpitResult: TaskCockpitResult?
    let isBuildingTaskCockpit: Bool
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
    @Binding var crossAgentReadinessText: String
    let crossAgentReadinessInput: String
    let crossAgentReadinessResult: CrossAgentReadinessResult?
    let isComparingCrossAgentReadiness: Bool
    let routingAccuracyDashboard: RoutingAccuracyDashboard?
    let isLoadingRoutingAccuracyDashboard: Bool
    let staleDriftDetection: StaleDriftDetectionResult?
    let isDetectingStaleDrift: Bool
    @Binding var knowledgeSearchText: String
    let knowledgeSearchResult: KnowledgeSearchResult?
    let isSearchingKnowledge: Bool
    let localSkillMapResult: LocalSkillMapResult?
    let isBuildingLocalSkillMap: Bool
    let skillLifecycleTimelineResult: SkillLifecycleTimelineResult?
    let isLoadingSkillLifecycleTimeline: Bool
    let providerObservabilityResult: ProviderObservabilityResult?
    let isLoadingProviderObservability: Bool
    let similarSkillGroupingResult: SimilarSkillGroupingResult?
    let isGroupingSimilarSkills: Bool
    let capabilityTaxonomyResult: CapabilityTaxonomyResult?
    let isBuildingCapabilityTaxonomy: Bool
    let workspaceReadinessResult: WorkspaceReadinessResult?
    let isCheckingWorkspaceReadiness: Bool
    let remediationPlanResult: RemediationPlanResult?
    let isPlanningRemediation: Bool
    let remediationPreviewDraftsResult: RemediationPreviewDraftsResult?
    let isPreviewingRemediationDrafts: Bool
    let remediationImpactPreviewResult: RemediationImpactPreviewResult?
    let isPreviewingRemediationImpact: Bool
    let remediationBatchReviewResult: RemediationBatchReviewResult?
    let isReviewingRemediationBatch: Bool
    let remediationHistoryResult: RemediationHistoryResult?
    let remediationHistoryRecordResult: RemediationHistoryRecordResult?
    let isLoadingRemediationHistory: Bool
    let isRecordingRemediationHistory: Bool
    let guidedCleanupFlowResult: GuidedCleanupFlowResult?
    let guidedCleanupRecordResult: GuidedCleanupRecordStepResult?
    let isPlanningGuidedCleanupFlow: Bool
    let isRecordingGuidedCleanupStep: Bool
    let onScoreQuality: () -> Void
    let onPreviewQualityPrompt: () -> Void
    let onSendQualityPrompt: () -> Void
    let onBuildTaskCockpit: () -> Void
    let onCheckTaskReadiness: () -> Void
    let onPreviewTaskReadinessPrompt: () -> Void
    let onSendTaskReadinessPrompt: () -> Void
    let onRankRoutingConfidence: () -> Void
    let onPreviewRoutingConfidencePrompt: () -> Void
    let onSendRoutingConfidencePrompt: () -> Void
    let onCompareCrossAgentReadiness: () -> Void
    let onLoadRoutingAccuracyDashboard: () -> Void
    let onDetectStaleDrift: () -> Void
    let onSearchKnowledge: () -> Void
    let onBuildLocalSkillMap: () -> Void
    let onLoadSkillLifecycleTimeline: () -> Void
    let onLoadProviderObservability: () -> Void
    let onGroupSimilarSkills: () -> Void
    let onBuildCapabilityTaxonomy: () -> Void
    let onCheckWorkspaceReadiness: () -> Void
    let onPlanRemediation: () -> Void
    let onPreviewRemediationDrafts: () -> Void
    let onPreviewRemediationImpact: () -> Void
    let onReviewRemediationBatch: (RemediationBatchReviewOptions) -> Void
    let onLoadRemediationHistory: () -> Void
    let onRecordRemediationHistory: () -> Void
    let onPlanGuidedCleanupFlow: () -> Void
    let onRecordGuidedCleanupStep: (GuidedCleanupFlowStep) -> Void
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
    @Binding var agentSessionSkillReviewTranscript: String
    @Binding var agentSessionSkillReviewTask: String
    @Binding var agentSessionSkillReviewExpectedSkills: String
    let agentSessionSkillReviewList: AgentSessionSkillReviewListResult
    let agentSessionSkillReviewResult: AgentSessionSkillReviewResult?
    let agentSessionSkillReviewDeleteResult: AgentSessionSkillReviewDeleteResult?
    let latestAgentSessionSkillReview: AgentSessionSkillReviewRecord?
    let isLoadingAgentSessionSkillReviews: Bool
    let isReviewingAgentSessionSkillUse: Bool
    let isDeletingAgentSessionSkillReview: (AgentSessionSkillReviewRecord) -> Bool
    let onLoadAgentSessionSkillReviews: () -> Void
    let onReviewAgentSessionSkillUse: () -> Void
    let onDeleteAgentSessionSkillReview: (AgentSessionSkillReviewRecord) -> Void
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
                Text(UIStrings.text("analysis.workbench.summary.compact", "Focused single-skill review: compare cross-agent overlap, score local quality, test task fit/routing, and review session skill use. Provider-backed explanations remain previewed, confirmed, copy-only, and persisted as local redacted run history."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label(UIStrings.text("analysis.crossAgentNote", "Cross-agent duplicates and source overlap live here as analysis insights; same-agent runtime/name collisions remain in Conflicts."), systemImage: "rectangle.3.group.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

            TaskRoutingAssessmentPanel(
                skill: skill,
                readinessText: $taskReadinessText,
                readinessResult: taskReadinessResult(skill),
                isCheckingReadiness: isCheckingTaskReadiness(skill),
                readinessPromptPreview: taskReadinessPromptPreview(skill),
                isPreviewingReadinessPrompt: isPreviewingTaskReadinessPrompt(skill),
                isSendingReadinessPrompt: isSendingTaskReadinessPrompt(skill),
                readinessPromptSendResult: taskReadinessPromptSendResult(skill),
                canSendReadinessPrompt: canSendTaskReadinessPrompt(skill),
                routingText: $routingConfidenceText,
                routingResult: routingConfidenceResult(skill),
                isRankingRouting: isRankingRoutingConfidence(skill),
                routingPromptPreview: routingConfidencePromptPreview(skill),
                isPreviewingRoutingPrompt: isPreviewingRoutingConfidencePrompt(skill),
                isSendingRoutingPrompt: isSendingRoutingConfidencePrompt(skill),
                routingPromptSendResult: routingConfidencePromptSendResult(skill),
                canSendRoutingPrompt: canSendRoutingConfidencePrompt(skill),
                onCheckReadiness: onCheckTaskReadiness,
                onPreviewReadinessPrompt: onPreviewTaskReadinessPrompt,
                onSendReadinessPrompt: onSendTaskReadinessPrompt,
                onRankRouting: onRankRoutingConfidence,
                onPreviewRoutingPrompt: onPreviewRoutingConfidencePrompt,
                onSendRoutingPrompt: onSendRoutingConfidencePrompt
            )

            RemediationPlanPanel(
                result: remediationPlanResult,
                isPlanning: isPlanningRemediation,
                onPlan: onPlanRemediation
            )

            RemediationPreviewDraftsPanel(
                result: remediationPreviewDraftsResult,
                isPreviewing: isPreviewingRemediationDrafts,
                onPreview: onPreviewRemediationDrafts
            )

            RemediationImpactPreviewPanel(
                result: remediationImpactPreviewResult,
                isPreviewing: isPreviewingRemediationImpact,
                onPreview: onPreviewRemediationImpact
            )

            RemediationBatchReviewPanel(
                result: remediationBatchReviewResult,
                isReviewing: isReviewingRemediationBatch,
                onReview: onReviewRemediationBatch
            )

            RemediationHistoryPanel(
                result: remediationHistoryResult,
                recordResult: remediationHistoryRecordResult,
                isLoading: isLoadingRemediationHistory,
                isRecording: isRecordingRemediationHistory,
                onLoad: onLoadRemediationHistory,
                onRecord: onRecordRemediationHistory
            )

            AgentSessionSkillReviewPanel(
                transcriptText: $agentSessionSkillReviewTranscript,
                taskText: $agentSessionSkillReviewTask,
                expectedSkills: $agentSessionSkillReviewExpectedSkills,
                listResult: agentSessionSkillReviewList,
                reviewResult: agentSessionSkillReviewResult,
                deleteResult: agentSessionSkillReviewDeleteResult,
                latestRecord: latestAgentSessionSkillReview,
                isLoading: isLoadingAgentSessionSkillReviews,
                isReviewing: isReviewingAgentSessionSkillUse,
                isDeleting: isDeletingAgentSessionSkillReview,
                onLoad: onLoadAgentSessionSkillReviews,
                onReview: onReviewAgentSessionSkillUse,
                onDelete: onDeleteAgentSessionSkillReview
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
                PrivacyPathText(path: member.displayPath, font: .caption, lineLimit: 1)
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

private struct TaskRoutingAssessmentPanel: View {
    let skill: SkillRecord
    @Binding var readinessText: String
    let readinessResult: TaskReadinessResult?
    let isCheckingReadiness: Bool
    let readinessPromptPreview: LLMPromptPreview?
    let isPreviewingReadinessPrompt: Bool
    let isSendingReadinessPrompt: Bool
    let readinessPromptSendResult: LLMPromptSendResult?
    let canSendReadinessPrompt: Bool
    @Binding var routingText: String
    let routingResult: SkillRoutingConfidenceResult?
    let isRankingRouting: Bool
    let routingPromptPreview: LLMPromptPreview?
    let isPreviewingRoutingPrompt: Bool
    let isSendingRoutingPrompt: Bool
    let routingPromptSendResult: LLMPromptSendResult?
    let canSendRoutingPrompt: Bool
    let onCheckReadiness: () -> Void
    let onPreviewReadinessPrompt: () -> Void
    let onSendReadinessPrompt: () -> Void
    let onRankRouting: () -> Void
    let onPreviewRoutingPrompt: () -> Void
    let onSendRoutingPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.text("analysis.taskRouting.title", "Task Fit & Routing"), systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.text("analysis.taskRouting.boundary", "Use one real task to check whether this skill is ready for the work and whether routing to it is confident. Local scoring stays deterministic; provider output is optional, confirmed, and copy-only."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 12) {
                Label(UIStrings.taskReadinessTitle, systemImage: "checklist.checked")
                    .font(.subheadline.bold())
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField(UIStrings.taskReadinessTaskPlaceholder, text: $readinessText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .labelsHidden()

                    Button {
                        onCheckReadiness()
                    } label: {
                        Label(UIStrings.taskReadinessCheckAction, systemImage: "checklist")
                    }
                    .disabled(isCheckingReadiness || readinessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help(UIStrings.taskReadinessBoundary)
                }

                if isCheckingReadiness {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let readinessResult {
                    TaskReadinessResultView(result: readinessResult)
                } else {
                    Label(UIStrings.taskReadinessTaskRequired, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                PromptPreviewControls(
                    preview: readinessPromptPreview,
                    sendResult: readinessPromptSendResult,
                    isPreviewing: isPreviewingReadinessPrompt,
                    isSending: isSendingReadinessPrompt,
                    canSend: canSendReadinessPrompt,
                    onPreview: onPreviewReadinessPrompt,
                    onSend: onSendReadinessPrompt
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Label(UIStrings.routingConfidenceTitle, systemImage: "arrow.up.arrow.down.square")
                    .font(.subheadline.bold())
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField(UIStrings.routingConfidenceTaskPlaceholder, text: $routingText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .labelsHidden()

                    Button {
                        onRankRouting()
                    } label: {
                        Label(UIStrings.routingConfidenceAction, systemImage: "arrow.up.arrow.down.square")
                    }
                    .disabled(isRankingRouting || routingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help(UIStrings.routingConfidenceBoundary)
                }

                if isRankingRouting {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let routingResult {
                    RoutingConfidenceResultView(result: routingResult)
                } else {
                    Label(UIStrings.routingConfidenceTaskRequired, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                PromptPreviewControls(
                    preview: routingPromptPreview,
                    sendResult: routingPromptSendResult,
                    isPreviewing: isPreviewingRoutingPrompt,
                    isSending: isSendingRoutingPrompt,
                    canSend: canSendRoutingPrompt,
                    onPreview: onPreviewRoutingPrompt,
                    onSend: onSendRoutingPrompt
                )
            }
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

private struct CrossAgentReadinessPanel: View {
    @Binding var taskText: String
    let currentTaskText: String
    let result: CrossAgentReadinessResult?
    let isComparing: Bool
    let onCompare: () -> Void

    private var effectiveTaskText: String {
        let trimmed = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? currentTaskText : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.crossAgentReadinessTitle, systemImage: "person.3.sequence")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.crossAgentReadinessBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(UIStrings.crossAgentReadinessTaskPlaceholder, text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .labelsHidden()

                Button {
                    onCompare()
                } label: {
                    Label(UIStrings.crossAgentReadinessCompareAction, systemImage: "arrow.left.arrow.right.square")
                }
                .disabled(isComparing || effectiveTaskText.isEmpty)
                .help(UIStrings.crossAgentReadinessBoundary)
            }

            if isComparing {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let result {
                CrossAgentReadinessResultView(result: result)
            } else {
                Label(UIStrings.crossAgentReadinessNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct CrossAgentReadinessResultView: View {
    let result: CrossAgentReadinessResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(
                    title: UIStrings.crossAgentReadinessAgents,
                    value: "\(result.summary.agentCount > 0 ? result.summary.agentCount : result.agentRows.count)",
                    systemImage: "person.3"
                )
                SummaryChip(
                    title: UIStrings.crossAgentReadinessCandidateCount,
                    value: "\(result.summary.candidateCount)",
                    systemImage: "rectangle.stack"
                )
                SummaryChip(
                    title: UIStrings.crossAgentReadinessReadinessScore,
                    value: CrossAgentReadinessSummary.scoreLabel(result.summary.averageReadinessScore),
                    systemImage: "gauge.medium"
                )
                SummaryChip(
                    title: UIStrings.crossAgentReadinessRoutingScore,
                    value: CrossAgentReadinessSummary.scoreLabel(result.summary.averageRoutingScore),
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
                SummaryChip(
                    title: UIStrings.taskReadinessGaps,
                    value: "\(result.summary.gapCount)",
                    systemImage: "puzzlepiece.extension"
                )
                SummaryChip(
                    title: UIStrings.taskReadinessBlockers,
                    value: "\(result.summary.blockerCount)",
                    systemImage: "exclamationmark.octagon"
                )
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.taskReadinessTask, value: result.taskText.isEmpty ? UIStrings.unknown : result.taskText)
                MetadataRow(label: UIStrings.crossAgentReadinessCandidateCount, value: "\(result.summary.candidateCount)")
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            CrossAgentReadinessRecommendationView(recommendation: result.recommendedAgent)
            CrossAgentReadinessAgentList(agents: result.agentRows)
            CrossAgentReadinessGapList(gaps: result.gapIssueRows)
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            CrossAgentReadinessSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct CrossAgentReadinessRecommendationView: View {
    let recommendation: CrossAgentReadinessRecommendedAgent?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.crossAgentReadinessRecommendedAgent)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if let recommendation {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Label(recommendation.displayName ?? DisplayText.agent(recommendation.agent), systemImage: "target")
                        .font(.callout.bold())
                    if let comparisonScore = recommendation.comparisonScore {
                        Text("\(comparisonScore)")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                    }
                    if let score = recommendation.score {
                        Text("\(score)")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                    }
                    if let routingScore = recommendation.routingScore {
                        Text("\(routingScore)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let band = recommendation.band, !band.isEmpty {
                        Text(band)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.55), in: Capsule())
                    }
                    if let skill = recommendation.skill {
                        Text(skill.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                if !recommendation.summary.isEmpty {
                    Text(recommendation.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text(UIStrings.crossAgentReadinessNoRecommendation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CrossAgentReadinessAgentList: View {
    let agents: [CrossAgentReadinessAgentRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.crossAgentReadinessAgents)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if agents.isEmpty {
                Text(UIStrings.crossAgentReadinessNoAgents)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(agents) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(rowTitle(row))
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                if let comparisonScore = row.comparisonScore {
                                    Text("\(comparisonScore)")
                                        .font(.caption.monospacedDigit().bold())
                                }
                                Text("\(row.readinessScore)")
                                    .font(.caption.monospacedDigit().bold())
                                Text(row.readinessBand)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }

                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.crossAgentReadinessComparisonScore, value: row.comparisonScore.map(String.init) ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.crossAgentReadinessRoutingScore, value: row.routingLabel)
                                MetadataRow(label: UIStrings.crossAgentReadinessBestSkill, value: row.bestCandidateSkill?.name ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.crossAgentReadinessCandidateCount, value: "\(row.candidateCount)")
                                MetadataRow(label: UIStrings.crossAgentReadinessEnabledState, value: row.enabledState ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.crossAgentReadinessScopeState, value: row.scopeState ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.crossAgentReadinessRiskState, value: row.riskState ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.taskReadinessBlockers, value: "\(row.blockerCount)")
                                MetadataRow(label: UIStrings.taskReadinessGaps, value: "\(row.gapCount)")
                            }

                            if let accuracy = row.accuracyContext, !accuracy.isEmpty {
                                Label(accuracy, systemImage: "target")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let regression = row.regressionContext, !regression.isEmpty {
                                Label(regression, systemImage: "chart.line.downtrend.xyaxis")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let benchmark = row.benchmarkContext, !benchmark.isEmpty {
                                Label(benchmark, systemImage: "checklist")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            RoutingInlineList(
                                title: UIStrings.crossAgentReadinessReasons,
                                empty: UIStrings.crossAgentReadinessNoReasons,
                                values: row.reasons,
                                systemImage: "checkmark.circle"
                            )
                            RoutingInlineList(
                                title: UIStrings.taskReadinessBlockers,
                                empty: UIStrings.taskReadinessNoBlockers,
                                values: row.blockerNotes,
                                systemImage: "exclamationmark.octagon"
                            )
                            RoutingInlineList(
                                title: UIStrings.taskReadinessGaps,
                                empty: UIStrings.taskReadinessNoGaps,
                                values: row.gapNotes,
                                systemImage: "puzzlepiece.extension"
                            )
                            RoutingInlineList(
                                title: UIStrings.crossAgentReadinessEvidence,
                                empty: UIStrings.crossAgentReadinessNoEvidence,
                                values: row.evidenceRefs,
                                systemImage: "checklist"
                            )
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func rowTitle(_ row: CrossAgentReadinessAgentRow) -> String {
        if let rank = row.rank {
            return "#\(rank) \(row.displayName ?? DisplayText.agent(row.agent))"
        }
        return row.displayName ?? DisplayText.agent(row.agent)
    }
}

private struct CrossAgentReadinessGapList: View {
    let gaps: [CrossAgentReadinessGapIssueRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.crossAgentReadinessGapsIssues)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if gaps.isEmpty {
                Text(UIStrings.crossAgentReadinessNoGapsIssues)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(gaps.prefix(6)) { gap in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(gap.title, systemImage: "puzzlepiece.extension")
                                .font(.callout)
                            Spacer()
                            if let severity = gap.severity, !severity.isEmpty {
                                Text(severity)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            if let agent = gap.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                            if let source = gap.source, !source.isEmpty {
                                Text(source)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        Text(gap.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if !gap.evidenceRefs.isEmpty {
                            Text(gap.evidenceRefs.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}

private struct CrossAgentReadinessEvidenceList: View {
    let evidence: [CrossAgentReadinessEvidenceReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.crossAgentReadinessEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.crossAgentReadinessNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(6)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        HStack(spacing: 8) {
                            if let agent = item.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                            if let source = item.source, !source.isEmpty {
                                Text(source)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct CrossAgentReadinessSafetyList: View {
    let safety: CrossAgentReadinessSafety

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.crossAgentReadinessSafetyFlags)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Label(
                safety.allReadOnlyFlagsClear ? UIStrings.routingAccuracySafetyClear : UIStrings.llmSkillAnalysisEnabledUnsafe,
                systemImage: safety.allReadOnlyFlagsClear ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SafetyPill(label: row.label, isBlocked: !row.isUnsafe)
                }
            }

            if !safety.notes.isEmpty {
                ForEach(safety.notes.prefix(4), id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rows: [(label: String, isUnsafe: Bool)] {
        [
            (UIStrings.skillQualityProviderNotSent, safety.providerRequestSent),
            (UIStrings.skillQualityWritesBlocked, safety.writeBackAllowed || safety.writeActionsAvailable),
            (UIStrings.skillQualityScriptsBlocked, safety.scriptExecutionAllowed || safety.executionActionsAvailable),
            (UIStrings.skillQualityMutationsBlocked, safety.configMutationAllowed || safety.snapshotCreated || safety.triageMutationAllowed),
            (UIStrings.skillQualityCredentialsBlocked, safety.credentialAccessed || safety.rawSecretReturned),
            (UIStrings.llmPromptRawPromptStored, safety.rawPromptPersisted),
            (UIStrings.llmPromptRawResponseStored, safety.rawResponsePersisted),
            (UIStrings.routingAccuracyRawTraceStored, safety.rawTracePersisted),
            (UIStrings.routingAccuracyCloudSync, safety.cloudSyncEnabled),
            (UIStrings.routingAccuracyTelemetry, safety.telemetryEnabled)
        ]
    }
}

private struct RoutingAccuracyDashboardPanel: View {
    let dashboard: RoutingAccuracyDashboard?
    let isLoading: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.routingAccuracyTitle, systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.routingAccuracyBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.routingAccuracyLoadAction, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)

                if isLoading {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let dashboard {
                RoutingAccuracyDashboardView(dashboard: dashboard)
            } else {
                Label(UIStrings.routingAccuracyNoDashboard, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RoutingAccuracyDashboardView: View {
    let dashboard: RoutingAccuracyDashboard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = dashboard.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(
                    title: UIStrings.routingAccuracyAccuracyRate,
                    value: dashboard.summary.accuracyRate.map(RoutingAccuracySummary.percentLabel)
                        ?? dashboard.summary.rateLabel(dashboard.summary.hitRate, count: dashboard.summary.hitCount),
                    systemImage: "target"
                )
                SummaryChip(
                    title: UIStrings.routingAccuracyWrongPickRate,
                    value: dashboard.summary.rateLabel(dashboard.summary.wrongPickRate, count: dashboard.summary.wrongPickCount),
                    systemImage: "xmark.octagon"
                )
                SummaryChip(
                    title: UIStrings.routingAccuracyImports,
                    value: RoutingAccuracySummary.countLabel(dashboard.summary.totalImports),
                    systemImage: "doc.text.magnifyingglass"
                )
                SummaryChip(
                    title: UIStrings.routingAccuracyKnownOutcomeRate,
                    value: dashboard.summary.knownOutcomeRate.map(RoutingAccuracySummary.percentLabel) ?? UIStrings.unknown,
                    systemImage: "checklist"
                )
                SummaryChip(
                    title: UIStrings.routingAccuracyRegressions,
                    value: RoutingAccuracySummary.countLabel(dashboard.summary.regressionCount),
                    systemImage: "chart.line.downtrend.xyaxis"
                )
                SummaryChip(
                    title: UIStrings.routingAccuracyAvgConfidence,
                    value: RoutingAccuracySummary.confidenceLabel(dashboard.summary.averageConfidence),
                    systemImage: "gauge.medium"
                )
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: dashboard.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: dashboard.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.routingAccuracyWindow, value: windowLabel)
                MetadataRow(label: UIStrings.routingAccuracyBenchmarks, value: RoutingAccuracySummary.countLabel(dashboard.summary.totalBenchmarks))
                MetadataRow(label: UIStrings.routingAccuracyBenchmarkMatched, value: RoutingAccuracySummary.countLabel(dashboard.summary.benchmarkMatchedCount))
                MetadataRow(label: UIStrings.routingAccuracyBenchmarkGaps, value: RoutingAccuracySummary.countLabel(dashboard.summary.benchmarkGapCount))
                MetadataRow(label: UIStrings.routingAccuracyMissingBenchmarks, value: RoutingAccuracySummary.countLabel(dashboard.summary.missingBenchmarkCount))
                MetadataRow(label: UIStrings.routingAccuracyGaps, value: RoutingAccuracySummary.countLabel(dashboard.summary.gapCount))
                MetadataRow(label: UIStrings.routingAccuracyBlockers, value: RoutingAccuracySummary.countLabel(dashboard.summary.blockerCount))
                if let promptRequest = dashboard.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !dashboard.summary.summaryText.isEmpty {
                Text(dashboard.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingAccuracyAgentList(agents: dashboard.agents)
            RoutingAccuracyHistoryList(history: dashboard.history)
            RoutingAccuracyGapList(gaps: dashboard.gaps)
            SkillQualityStringList(
                title: UIStrings.routingAccuracyBlockerNotes,
                empty: UIStrings.routingAccuracyNoBlockers,
                values: dashboard.blockerNotes,
                systemImage: "exclamationmark.octagon"
            )
            RoutingAccuracyEvidenceList(evidence: dashboard.recentEvidence)
            RoutingAccuracySafetyList(safety: dashboard.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var windowLabel: String {
        if let days = dashboard.filters.windowDays {
            return String(format: UIStrings.routingAccuracyDays, days)
        }
        return UIStrings.unknown
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct RoutingAccuracyAgentList: View {
    let agents: [RoutingAccuracyAgentRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.routingAccuracyAgents)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if agents.isEmpty {
                Text(UIStrings.routingAccuracyNoAgents)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(agents) { agent in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(DisplayText.agent(agent.agent))
                                .font(.callout.bold())
                                .frame(minWidth: 110, alignment: .leading)
                            Text(agent.hitRateLabel())
                                .font(.caption.monospacedDigit().bold())
                                .frame(width: 58, alignment: .trailing)
                            Text(agent.wrongPickRateLabel())
                                .font(.caption.monospacedDigit())
                                .frame(width: 58, alignment: .trailing)
                            Text(RoutingAccuracySummary.confidenceLabel(agent.averageConfidence))
                                .font(.caption.monospacedDigit())
                                .frame(width: 58, alignment: .trailing)
                            Text("\(agent.totalCount)")
                                .font(.caption.monospacedDigit())
                                .frame(width: 48, alignment: .trailing)
                            Spacer()
                            SafetyPill(
                                label: "\(UIStrings.routingAccuracyBenchmarkGaps) \(agent.benchmarkGapCount)",
                                isBlocked: agent.benchmarkGapCount == 0
                            )
                            SafetyPill(
                                label: "\(UIStrings.routingAccuracyRegressions) \(agent.regressionCount)",
                                isBlocked: agent.regressionCount == 0
                            )
                        }
                        .padding(.vertical, 7)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct RoutingAccuracyHistoryList: View {
    let history: [RoutingAccuracyHistoryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.routingAccuracyHistory)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if history.isEmpty {
                Text(UIStrings.routingAccuracyNoHistory)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(history.prefix(6)) { point in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(point.label)
                                .font(.caption.bold())
                                .lineLimit(1)
                            MetadataLine(label: UIStrings.routingAccuracyHitRate, value: point.hitRate.map(RoutingAccuracySummary.percentLabel) ?? UIStrings.unknown)
                            MetadataLine(label: UIStrings.routingAccuracyWrongPickRate, value: point.wrongPickRate.map(RoutingAccuracySummary.percentLabel) ?? UIStrings.unknown)
                            MetadataLine(label: UIStrings.routingAccuracyRegressions, value: "\(point.regressionCount)")
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

private struct RoutingAccuracyGapList: View {
    let gaps: [RoutingAccuracyGap]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.routingAccuracyGaps)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if gaps.isEmpty {
                Text(UIStrings.routingAccuracyNoGaps)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(gaps.prefix(6)) { gap in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(gap.title, systemImage: "puzzlepiece.extension")
                                .font(.callout)
                            Spacer()
                            if let count = gap.count {
                                Text("\(count)")
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(gap.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let severity = gap.severity, !severity.isEmpty {
                            Text(severity)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct RoutingAccuracyEvidenceList: View {
    let evidence: [RoutingAccuracyEvidenceRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.routingAccuracyRecentEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.routingAccuracyNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(6)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        HStack(spacing: 8) {
                            if let agent = item.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                            if let outcome = item.outcome, !outcome.isEmpty {
                                Text(outcome)
                            }
                            if let observedAt = item.observedAt {
                                Text(DisplayText.timestamp(observedAt))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let source = item.source, !source.isEmpty {
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if !item.evidenceRefs.isEmpty {
                            Text(item.evidenceRefs.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}

private struct RoutingAccuracySafetyList: View {
    let safety: RoutingAccuracySafety

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.routingAccuracySafetyFlags)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Label(
                safety.allReadOnlyFlagsClear ? UIStrings.routingAccuracySafetyClear : UIStrings.llmSkillAnalysisEnabledUnsafe,
                systemImage: safety.allReadOnlyFlagsClear ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SafetyPill(label: row.label, isBlocked: !row.isUnsafe)
                }
            }

            if !safety.notes.isEmpty {
                ForEach(safety.notes.prefix(4), id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rows: [(label: String, isUnsafe: Bool)] {
        [
            (UIStrings.skillQualityProviderNotSent, safety.providerRequestSent),
            (UIStrings.skillQualityWritesBlocked, safety.writeBackAllowed),
            (UIStrings.skillQualityScriptsBlocked, safety.scriptExecutionAllowed),
            (UIStrings.skillQualityMutationsBlocked, safety.configMutationAllowed || safety.snapshotCreated || safety.triageMutationAllowed),
            (UIStrings.skillQualityCredentialsBlocked, safety.credentialAccessed || safety.rawSecretReturned),
            (UIStrings.llmPromptRawPromptStored, safety.rawPromptPersisted),
            (UIStrings.llmPromptRawResponseStored, safety.rawResponsePersisted),
            (UIStrings.routingAccuracyRawTraceStored, safety.rawTracePersisted),
            (UIStrings.routingAccuracyCloudSync, safety.cloudSyncEnabled),
            (UIStrings.routingAccuracyTelemetry, safety.telemetryEnabled)
        ]
    }
}

private struct StaleDriftDetectionPanel: View {
    let result: StaleDriftDetectionResult?
    let isDetecting: Bool
    let onDetect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.staleDriftTitle, systemImage: "clock.badge.exclamationmark")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.staleDriftBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onDetect()
                } label: {
                    Label(UIStrings.staleDriftDetectAction, systemImage: "waveform.path.ecg.rectangle")
                }
                .disabled(isDetecting)

                if isDetecting {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let result {
                StaleDriftResultView(result: result)
            } else {
                Label(UIStrings.staleDriftNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct StaleDriftResultView: View {
    let result: StaleDriftDetectionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.staleDriftStale, value: "\(result.summary.staleCount)", systemImage: "clock")
                SummaryChip(title: UIStrings.staleDriftDrift, value: "\(result.summary.driftCount)", systemImage: "arrow.triangle.2.circlepath")
                SummaryChip(title: UIStrings.staleDriftCandidates, value: "\(candidateCount)", systemImage: "rectangle.stack")
                SummaryChip(title: UIStrings.staleDriftAffectedAgents, value: "\(result.summary.affectedAgentCount)", systemImage: "person.3")
                SummaryChip(title: UIStrings.staleDriftReadinessImpact, value: "\(readinessImpactCount)", systemImage: "gauge.medium.badge.exclamationmark")
                SummaryChip(title: UIStrings.staleDriftHighRisk, value: "\(result.summary.highRiskCount)", systemImage: "exclamationmark.triangle")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.staleDriftCandidates, value: "\(candidateCount)")
                MetadataRow(label: UIStrings.staleDriftReadinessImpact, value: "\(readinessImpactCount)")
                MetadataRow(label: UIStrings.crossAgentReadinessGapsIssues, value: "\(gapIssueCount)")
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            StaleDriftCandidateList(rows: result.staleDriftRows)
            StaleDriftImpactList(title: UIStrings.staleDriftReadinessImpact, empty: UIStrings.staleDriftNoReadinessImpact, rows: result.readinessImpactRows, systemImage: "gauge.medium.badge.exclamationmark")
            StaleDriftImpactList(title: UIStrings.crossAgentReadinessGapsIssues, empty: UIStrings.crossAgentReadinessNoGapsIssues, rows: result.gapIssueRows, systemImage: "puzzlepiece.extension")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var candidateCount: Int {
        result.summary.candidateCount > 0 ? result.summary.candidateCount : result.staleDriftRows.count
    }

    private var readinessImpactCount: Int {
        result.summary.readinessImpactCount > 0 ? result.summary.readinessImpactCount : result.readinessImpactRows.count
    }

    private var gapIssueCount: Int {
        result.summary.gapIssueCount > 0 ? result.summary.gapIssueCount : result.gapIssueRows.count
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct StaleDriftCandidateList: View {
    let rows: [StaleDriftRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.staleDriftCandidates)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.staleDriftNoCandidates)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(8)) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(row.title, systemImage: row.kind.localizedCaseInsensitiveContains("drift") ? "arrow.triangle.2.circlepath" : "clock")
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(row.kind)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                if let severity = row.severity, !severity.isEmpty {
                                    Text(severity)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.agent, value: row.agent.map(DisplayText.agent) ?? row.skill?.agent.map(DisplayText.agent) ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.crossAgentReadinessBestSkill, value: row.skill?.name ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.scope, value: row.skill?.scope ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.state, value: row.skill?.state ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.staleDriftLastSeen, value: row.lastSeen ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.routingAccuracyAvgConfidence, value: row.confidenceLabel)
                            }

                            Text(row.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            if let current = row.currentSignal, !current.isEmpty {
                                Label(current, systemImage: "waveform.path.ecg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let expected = row.expectedSignal, !expected.isEmpty {
                                Label(expected, systemImage: "scope")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            RoutingInlineList(title: UIStrings.staleDriftReasons, empty: UIStrings.staleDriftNoReasons, values: row.reasons, systemImage: "text.bubble")
                            RoutingInlineList(title: UIStrings.staleDriftSignals, empty: UIStrings.staleDriftNoSignals, values: row.signals, systemImage: "waveform.path.ecg")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
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

private struct StaleDriftImpactList: View {
    let title: String
    let empty: String
    let rows: [StaleDriftImpactRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(6)) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(row.title, systemImage: systemImage)
                                .font(.callout)
                            Spacer()
                            if let severity = row.severity, !severity.isEmpty {
                                Text(severity)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            if let agent = row.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                            if let skillName = row.skillName, !skillName.isEmpty {
                                Text(skillName)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if !row.evidenceRefs.isEmpty {
                            Text(row.evidenceRefs.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}

private struct StaleDriftSafetyList: View {
    let safety: StaleDriftSafety

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.staleDriftSafetyFlags)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Label(
                safety.allReadOnlyFlagsClear ? UIStrings.routingAccuracySafetyClear : UIStrings.llmSkillAnalysisEnabledUnsafe,
                systemImage: safety.allReadOnlyFlagsClear ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SafetyPill(label: row.label, isBlocked: !row.isUnsafe)
                }
            }

            if !safety.notes.isEmpty {
                ForEach(safety.notes.prefix(4), id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rows: [(label: String, isUnsafe: Bool)] {
        [
            (UIStrings.skillQualityProviderNotSent, safety.providerRequestSent),
            (UIStrings.skillQualityWritesBlocked, safety.writeBackAllowed || safety.writeActionsAvailable),
            (UIStrings.skillQualityScriptsBlocked, safety.scriptExecutionAllowed || safety.executionActionsAvailable),
            (UIStrings.skillQualityMutationsBlocked, safety.configMutationAllowed || safety.snapshotCreated || safety.triageMutationAllowed),
            (UIStrings.skillQualityCredentialsBlocked, safety.credentialAccessed || safety.rawSecretReturned),
            (UIStrings.llmPromptRawPromptStored, safety.rawPromptPersisted),
            (UIStrings.llmPromptRawResponseStored, safety.rawResponsePersisted),
            (UIStrings.routingAccuracyRawTraceStored, safety.rawTracePersisted),
            (UIStrings.routingAccuracyCloudSync, safety.cloudSyncEnabled),
            (UIStrings.routingAccuracyTelemetry, safety.telemetryEnabled)
        ]
    }
}

private struct SimilarSkillGroupingPanel: View {
    let result: SimilarSkillGroupingResult?
    let isGrouping: Bool
    let onGroup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.similarGroupingTitle, systemImage: "rectangle.3.group.bubble")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.similarGroupingBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onGroup()
                } label: {
                    Label(UIStrings.similarGroupingAction, systemImage: "rectangle.stack.badge.person.crop")
                }
                .disabled(isGrouping)

                if isGrouping {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                SimilarSkillGroupingResultView(result: result)
            } else {
                Label(UIStrings.similarGroupingNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SimilarSkillGroupingResultView: View {
    let result: SimilarSkillGroupingResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.similarGroupingGroups, value: "\(groupCount)", systemImage: "rectangle.stack")
                SummaryChip(title: UIStrings.similarGroupingMembers, value: "\(memberCount)", systemImage: "person.3")
                SummaryChip(title: UIStrings.similarGroupingDuplicate, value: "\(duplicateCount)", systemImage: "doc.on.doc")
                SummaryChip(title: UIStrings.similarGroupingConfusable, value: "\(confusableCount)", systemImage: "point.3.connected.trianglepath.dotted")
                SummaryChip(title: UIStrings.similarGroupingHighAmbiguity, value: "\(result.summary.highAmbiguityCount)", systemImage: "exclamationmark.triangle")
                SummaryChip(title: UIStrings.similarGroupingRoutingAmbiguity, value: "\(result.summary.routingAmbiguityCount)", systemImage: "arrow.triangle.branch")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: result.filters.agents.isEmpty ? (result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")) : result.filters.agents.map(DisplayText.agent).joined(separator: ", "))
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let minScore = result.filters.minScore {
                    MetadataRow(label: UIStrings.similarGroupingSimilar, value: RoutingAccuracySummary.confidenceLabel(minScore))
                }
                MetadataRow(label: UIStrings.text("filter.singletons", "Singletons"), value: result.filters.includeSingletons ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            SimilarSkillGroupList(groups: result.groups)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var groupCount: Int {
        result.summary.groupCount > 0 ? result.summary.groupCount : result.groups.count
    }

    private var memberCount: Int {
        result.summary.memberCount > 0 ? result.summary.memberCount : result.groups.reduce(0) { $0 + $1.members.count }
    }

    private var duplicateCount: Int {
        result.summary.duplicateCount > 0 ? result.summary.duplicateCount : result.groups.filter { $0.typeLabel == UIStrings.similarGroupingDuplicate }.count
    }

    private var confusableCount: Int {
        result.summary.confusableCount > 0 ? result.summary.confusableCount : result.groups.filter { $0.typeLabel == UIStrings.similarGroupingConfusable }.count
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct SimilarSkillGroupList: View {
    let groups: [SimilarSkillGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.similarGroupingGroups)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if groups.isEmpty {
                Text(UIStrings.similarGroupingNoGroups)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(groups.prefix(8)) { group in
                        SimilarSkillGroupCard(group: group)
                    }
                }
            }
        }
    }
}

private struct SimilarSkillGroupCard: View {
    let group: SimilarSkillGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(group.title, systemImage: iconName)
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text(group.displayRank)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                SimilarSkillPill(text: group.typeLabel, systemImage: iconName)
                if let score = group.similarityScore {
                    SimilarSkillPill(text: RoutingAccuracySummary.confidenceLabel(score), systemImage: "gauge.medium")
                }
                if let ambiguityRisk = group.ambiguityRisk, !ambiguityRisk.isEmpty {
                    SimilarSkillPill(text: ambiguityRisk, systemImage: "exclamationmark.triangle")
                }
            }

            if !group.summary.isEmpty {
                Text(group.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                if let coverage = group.coverageRedundancy, !coverage.isEmpty {
                    MetadataRow(label: UIStrings.similarGroupingCoverageRedundancy, value: coverage)
                }
                if let ambiguity = group.routingAmbiguity, !ambiguity.isEmpty {
                    MetadataRow(label: UIStrings.similarGroupingRoutingAmbiguity, value: ambiguity)
                }
            }

            RoutingInlineList(title: UIStrings.similarGroupingWhyGrouped, empty: UIStrings.routingConfidenceNoReasons, values: group.whyGrouped, systemImage: "text.bubble")
            KnowledgeTokenFlow(title: UIStrings.similarGroupingSharedTerms, values: group.sharedTerms)
            KnowledgeTokenFlow(title: UIStrings.knowledgeTools, values: group.sharedTools)
            KnowledgeTokenFlow(title: UIStrings.knowledgeRules, values: group.sharedRules)
            KnowledgeTokenFlow(title: UIStrings.knowledgeCapabilities, values: group.sharedCapabilities)
            KnowledgeTokenFlow(title: UIStrings.knowledgeRisks, values: group.sharedRisks)
            KnowledgeTokenFlow(title: UIStrings.similarGroupingSourceSignals, values: group.sourceSignals)
            SimilarSkillMemberList(members: group.members)
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: group.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: group.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch group.typeLabel {
        case UIStrings.similarGroupingDuplicate:
            return "doc.on.doc"
        case UIStrings.similarGroupingConfusable:
            return "point.3.connected.trianglepath.dotted"
        default:
            return "rectangle.3.group.bubble"
        }
    }
}

private struct SimilarSkillMemberList: View {
    let members: [SimilarSkillMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.similarGroupingMembers)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            if members.isEmpty {
                Text(UIStrings.knowledgeNoRows)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(members.prefix(6)) { member in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(member.skillName, systemImage: "doc.text")
                                .font(.caption.bold())
                                .lineLimit(1)
                            Spacer()
                            Text(member.agent.map(DisplayText.agent) ?? UIStrings.unknown)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }

                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                            MetadataRow(label: UIStrings.scope, value: member.scope ?? UIStrings.unknown)
                            MetadataRow(label: UIStrings.state, value: member.statusLabel)
                            if let definitionID = member.definitionID, !definitionID.isEmpty {
                                MetadataRow(label: UIStrings.definition, value: definitionID)
                            }
                            if let quality = qualityLabel(member), !quality.isEmpty {
                                MetadataRow(label: UIStrings.similarGroupingQuality, value: quality)
                            }
                            if let readiness = readinessLabel(member), !readiness.isEmpty {
                                MetadataRow(label: UIStrings.similarGroupingReadiness, value: readiness)
                            }
                            if let staleDrift = member.staleDriftState, !staleDrift.isEmpty {
                                MetadataRow(label: UIStrings.similarGroupingStaleDrift, value: staleDrift)
                            }
                            if let sourceKind = member.sourceKind, !sourceKind.isEmpty {
                                MetadataRow(label: UIStrings.provenanceKind, value: sourceKind)
                            }
                            if let sourceRoot = member.sourceRoot, !sourceRoot.isEmpty {
                                MetadataRow(label: UIStrings.provenanceRoot, value: sourceRoot)
                            }
                        }

                        if let sourcePath = member.sourcePath, !sourcePath.isEmpty {
                            PrivacyPathText(path: sourcePath, font: .caption2, lineLimit: 1)
                        }

                        RoutingInlineList(title: UIStrings.routingConfidenceMatchReasons, empty: UIStrings.routingConfidenceNoReasons, values: member.reasons, systemImage: "text.bubble")
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: member.evidenceRefs, systemImage: "checklist")
                        RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: member.safetyFlags, systemImage: "checkmark.shield")
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func qualityLabel(_ member: SimilarSkillMember) -> String? {
        scoreBandLabel(score: member.qualityScore, band: member.qualityBand)
    }

    private func readinessLabel(_ member: SimilarSkillMember) -> String? {
        scoreBandLabel(score: member.readinessScore, band: member.readinessBand)
    }

    private func scoreBandLabel(score: Double?, band: String?) -> String? {
        let pieces = [
            score.map(RoutingAccuracySummary.confidenceLabel),
            band
        ].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: " · ")
    }
}

private struct SimilarSkillPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.45), in: Capsule())
            .lineLimit(1)
    }
}

private struct CapabilityTaxonomyPanel: View {
    let result: CapabilityTaxonomyResult?
    let isBuilding: Bool
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.capabilityTaxonomyTitle, systemImage: "square.grid.3x3.topleft.filled")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.capabilityTaxonomyBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onBuild()
                } label: {
                    Label(UIStrings.capabilityTaxonomyAction, systemImage: "point.3.connected.trianglepath.dotted")
                }
                .disabled(isBuilding)

                if isBuilding {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                CapabilityTaxonomyResultView(result: result)
            } else {
                Label(UIStrings.capabilityTaxonomyNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct CapabilityTaxonomyResultView: View {
    let result: CapabilityTaxonomyResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.capabilityTaxonomyDomains, value: "\(domainCount)", systemImage: "square.grid.3x3")
                SummaryChip(title: UIStrings.knowledgeCapabilities, value: "\(capabilityCount)", systemImage: "tag")
                SummaryChip(title: UIStrings.similarGroupingMembers, value: "\(skillCount)", systemImage: "doc.text")
                SummaryChip(title: UIStrings.agent, value: "\(agentCount)", systemImage: "person.2")
                SummaryChip(title: UIStrings.knowledgeGapNotes, value: "\(gapCount)", systemImage: "puzzlepiece.extension")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "exclamationmark.octagon")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: result.filters.agents.isEmpty ? (result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")) : result.filters.agents.map(DisplayText.agent).joined(separator: ", "))
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                MetadataRow(label: UIStrings.knowledgeGapNotes, value: result.filters.includeGaps ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            CapabilityCoverageList(coverage: result.coverageByAgent)
            CapabilityDomainList(domains: result.domains)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var domainCount: Int {
        result.summary.domainCount > 0 ? result.summary.domainCount : result.domains.count
    }

    private var capabilityCount: Int {
        result.summary.capabilityCount > 0 ? result.summary.capabilityCount : result.domains.reduce(0) { $0 + $1.capabilityCount }
    }

    private var skillCount: Int {
        result.summary.skillCount > 0 ? result.summary.skillCount : result.domains.reduce(0) { $0 + $1.skillCount }
    }

    private var agentCount: Int {
        result.summary.agentCount > 0 ? result.summary.agentCount : Set(result.coverageByAgent.map(\.agent)).count
    }

    private var gapCount: Int {
        result.summary.gapCount > 0 ? result.summary.gapCount : result.gapNotes.count + result.domains.reduce(0) { $0 + $1.gapNotes.count }
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count + result.domains.reduce(0) { $0 + $1.blockerNotes.count }
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct CapabilityCoverageList: View {
    let coverage: [CapabilityTaxonomyCoverage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.capabilityTaxonomyAgentCoverage)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if coverage.isEmpty {
                Text(UIStrings.routingAccuracyNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(coverage.prefix(8)) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(DisplayText.agent(row.agent))
                                    .font(.caption.bold())
                                Spacer()
                                Text(row.coverageState)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                                MetadataRow(label: UIStrings.knowledgeCapabilities, value: "\(row.capabilityCount)")
                                MetadataRow(label: UIStrings.similarGroupingMembers, value: "\(row.skillCount)")
                            }
                            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: row.notes, systemImage: "puzzlepiece.extension")
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

private struct CapabilityDomainList: View {
    let domains: [CapabilityTaxonomyDomain]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.capabilityTaxonomyDomains)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if domains.isEmpty {
                Text(UIStrings.capabilityTaxonomyNoDomains)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(domains.prefix(8)) { domain in
                        CapabilityDomainCard(domain: domain)
                    }
                }
            }
        }
    }
}

private struct CapabilityDomainCard: View {
    let domain: CapabilityTaxonomyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(domain.name, systemImage: "square.grid.3x3.topleft.filled")
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text("\(domain.capabilityCount) / \(domain.skillCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            if !domain.summary.isEmpty {
                Text(domain.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            CapabilityCoverageList(coverage: domain.coverageByAgent)
            CapabilityList(capabilities: domain.capabilities)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: domain.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: domain.blockerNotes, systemImage: "exclamationmark.octagon")
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: domain.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: domain.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CapabilityList: View {
    let capabilities: [CapabilityTaxonomyCapability]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.knowledgeCapabilities)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            if capabilities.isEmpty {
                Text(UIStrings.knowledgeNoRows)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(capabilities.prefix(6)) { capability in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(capability.name, systemImage: "tag")
                            .font(.caption.bold())
                            .lineLimit(1)
                        if !capability.summary.isEmpty {
                            Text(capability.summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        KnowledgeTokenFlow(title: UIStrings.knowledgeKeywords, values: capability.keywords)
                        KnowledgeTokenFlow(title: UIStrings.knowledgeTools, values: capability.tools)
                        KnowledgeTokenFlow(title: UIStrings.knowledgeRules, values: capability.rules)
                        KnowledgeTokenFlow(title: UIStrings.knowledgeRisks, values: capability.riskTags)
                        CapabilitySkillList(skills: capability.representativeSkills)
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: capability.evidenceRefs, systemImage: "checklist")
                        RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: capability.safetyFlags, systemImage: "checkmark.shield")
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

private struct CapabilitySkillList: View {
    let skills: [CapabilityTaxonomySkill]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(UIStrings.capabilityTaxonomyRepresentativeSkills)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            if skills.isEmpty {
                Text(UIStrings.knowledgeNoRows)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(skills.prefix(5)) { skill in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(skill.skillName, systemImage: "doc.text")
                                .font(.caption2.bold())
                                .lineLimit(1)
                            Spacer()
                            Text(skill.agent.map(DisplayText.agent) ?? UIStrings.unknown)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                            MetadataRow(label: UIStrings.scope, value: skill.scope ?? UIStrings.unknown)
                            MetadataRow(label: UIStrings.state, value: skill.statusLabel)
                            if let qualityScore = skill.qualityScore {
                                MetadataRow(label: UIStrings.similarGroupingQuality, value: RoutingAccuracySummary.confidenceLabel(qualityScore))
                            }
                            if let readinessScore = skill.readinessScore {
                                MetadataRow(label: UIStrings.similarGroupingReadiness, value: RoutingAccuracySummary.confidenceLabel(readinessScore))
                            }
                        }
                        RoutingInlineList(title: UIStrings.routingConfidenceMatchReasons, empty: UIStrings.routingConfidenceNoReasons, values: skill.reasons, systemImage: "text.bubble")
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: skill.evidenceRefs, systemImage: "checklist")
                        RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: skill.safetyFlags, systemImage: "checkmark.shield")
                    }
                    .padding(6)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

private struct WorkspaceReadinessPanel: View {
    let result: WorkspaceReadinessResult?
    let isChecking: Bool
    let onCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.workspaceReadinessTitle, systemImage: "checklist.checked")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.workspaceReadinessBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onCheck()
                } label: {
                    Label(UIStrings.workspaceReadinessAction, systemImage: "checkmark.seal")
                }
                .disabled(isChecking)

                if isChecking {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                WorkspaceReadinessResultView(result: result)
            } else {
                Label(UIStrings.workspaceReadinessNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct WorkspaceReadinessResultView: View {
    let result: WorkspaceReadinessResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.workspaceReadinessOverall, value: result.summary.overallState, systemImage: "gauge.medium")
                SummaryChip(title: UIStrings.similarGroupingReadiness, value: scoreLabel, systemImage: "speedometer")
                SummaryChip(title: UIStrings.workspaceReadinessChecklist, value: "\(checklistCount)", systemImage: "checklist")
                SummaryChip(title: UIStrings.workspaceReadinessReady, value: "\(readyCount)", systemImage: "checkmark.circle")
                SummaryChip(title: UIStrings.workspaceReadinessPartial, value: "\(partialCount)", systemImage: "circle.lefthalf.filled")
                SummaryChip(title: UIStrings.workspaceReadinessBlocked, value: "\(blockedCount)", systemImage: "exclamationmark.octagon")
                SummaryChip(title: UIStrings.agent, value: "\(agentCount)", systemImage: "person.2")
                SummaryChip(title: UIStrings.knowledgeCapabilities, value: "\(capabilityCount)", systemImage: "tag")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if let projectRoot = result.filters.projectRoot, !projectRoot.isEmpty {
                    PrivacyPathRow(label: UIStrings.project, path: projectRoot)
                }
                if let workspace = result.filters.workspace, !workspace.isEmpty {
                    MetadataRow(label: UIStrings.workspaceReadinessTitle, value: workspace)
                }
                if let taskText = result.filters.taskText, !taskText.isEmpty {
                    MetadataRow(label: UIStrings.taskBenchmarkTaskPlaceholder, value: taskText)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            WorkspaceReadinessChecklistList(rows: result.checklistRows)
            WorkspaceReadinessAgentList(rows: result.agentRows)
            WorkspaceReadinessCapabilityList(rows: result.capabilityRows)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var scoreLabel: String {
        guard let score = result.summary.readinessScore else { return UIStrings.unknown }
        return "\(score)"
    }

    private var checklistCount: Int {
        result.summary.checklistCount > 0 ? result.summary.checklistCount : result.checklistRows.count
    }

    private var readyCount: Int {
        result.summary.readyCount > 0 ? result.summary.readyCount : result.checklistRows.filter { $0.status.localizedCaseInsensitiveContains("ready") }.count
    }

    private var partialCount: Int {
        result.summary.partialCount > 0 ? result.summary.partialCount : result.checklistRows.filter { $0.status.localizedCaseInsensitiveContains("partial") }.count
    }

    private var blockedCount: Int {
        result.summary.blockedCount > 0 ? result.summary.blockedCount : result.checklistRows.filter { $0.status.localizedCaseInsensitiveContains("block") }.count
    }

    private var agentCount: Int {
        result.summary.agentCount > 0 ? result.summary.agentCount : result.agentRows.count
    }

    private var capabilityCount: Int {
        result.summary.capabilityCount > 0 ? result.summary.capabilityCount : result.capabilityRows.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct WorkspaceReadinessChecklistList: View {
    let rows: [WorkspaceReadinessChecklistRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.workspaceReadinessChecklist)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.workspaceReadinessNoChecklist)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(8)) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(row.title, systemImage: "checklist")
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(row.status)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                                if let agent = row.agent, !agent.isEmpty {
                                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                                }
                                if let capability = row.capability, !capability.isEmpty {
                                    MetadataRow(label: UIStrings.capabilityTaxonomyCapability, value: capability)
                                }
                                if let severity = row.severity, !severity.isEmpty {
                                    MetadataRow(label: UIStrings.cleanupFilterPriority, value: severity)
                                }
                            }
                            if !row.summary.isEmpty {
                                Text(row.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            RoutingInlineList(title: UIStrings.workspaceReadinessRequired, empty: UIStrings.knowledgeNoRows, values: row.requiredSkills, systemImage: "target")
                            CapabilitySkillList(skills: row.matchedSkills)
                            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: row.gapNotes, systemImage: "puzzlepiece.extension")
                            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: row.blockerNotes, systemImage: "exclamationmark.octagon")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: row.safetyFlags, systemImage: "checkmark.shield")
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

private struct WorkspaceReadinessAgentList: View {
    let rows: [WorkspaceReadinessAgentRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.workspaceReadinessAgentRows)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.workspaceReadinessNoAgentRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(8)) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.displayName ?? DisplayText.agent(row.agent))
                                    .font(.caption.bold())
                                Spacer()
                                Text(agentScoreLabel(row))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                                MetadataRow(label: UIStrings.workspaceReadinessEnabled, value: "\(row.enabledSkillCount)")
                                MetadataRow(label: UIStrings.workspaceReadinessRequired, value: "\(row.requiredSkillCount)")
                                MetadataRow(label: UIStrings.workspaceReadinessMatched, value: "\(row.matchedSkillCount)")
                                MetadataRow(label: UIStrings.knowledgeGapNotes, value: "\(row.gapCount)")
                                MetadataRow(label: UIStrings.knowledgeBlockerNotes, value: "\(row.blockerCount)")
                            }
                            RoutingInlineList(title: UIStrings.staleDriftReasons, empty: UIStrings.staleDriftNoReasons, values: row.notes, systemImage: "text.bubble")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private func agentScoreLabel(_ row: WorkspaceReadinessAgentRow) -> String {
        if let readinessScore = row.readinessScore {
            return "\(readinessScore) · \(row.readinessState)"
        }
        return row.readinessState
    }
}

private struct WorkspaceReadinessCapabilityList: View {
    let rows: [WorkspaceReadinessCapabilityRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.workspaceReadinessCapabilityRows)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.workspaceReadinessNoCapabilityRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(8)) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(row.capability, systemImage: "tag")
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(capabilityScoreLabel(row))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Text(row.domain)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            CapabilityCoverageList(coverage: row.agentCoverage)
                            CapabilitySkillList(skills: row.representativeSkills)
                            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: row.gapNotes, systemImage: "puzzlepiece.extension")
                            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: row.blockerNotes, systemImage: "exclamationmark.octagon")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func capabilityScoreLabel(_ row: WorkspaceReadinessCapabilityRow) -> String {
        if let readinessScore = row.readinessScore {
            return "\(readinessScore) · \(row.readinessState)"
        }
        return row.readinessState
    }
}

private struct RemediationPlanPanel: View {
    let result: RemediationPlanResult?
    let isPlanning: Bool
    let onPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.remediationPlanTitle, systemImage: "wrench.and.screwdriver")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.remediationPlanBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onPlan()
                } label: {
                    Label(UIStrings.remediationPlanAction, systemImage: "list.bullet.clipboard")
                }
                .disabled(isPlanning)

                if isPlanning {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                RemediationPlanResultView(result: result)
            } else {
                Label(UIStrings.remediationPlanNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RemediationPlanResultView: View {
    let result: RemediationPlanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.remediationPlanItems, value: "\(itemCount)", systemImage: "list.bullet")
                SummaryChip(title: UIStrings.remediationPlanCritical, value: "\(criticalCount)", systemImage: "exclamationmark.octagon")
                SummaryChip(title: UIStrings.cleanupPriorityHigh, value: "\(highCount)", systemImage: "exclamationmark.triangle")
                SummaryChip(title: UIStrings.cleanupPriorityMedium, value: "\(mediumCount)", systemImage: "circle.lefthalf.filled")
                SummaryChip(title: UIStrings.remediationPlanQuickWins, value: "\(quickWinCount)", systemImage: "bolt")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "lock.trianglebadge.exclamationmark")
                SummaryChip(title: UIStrings.knowledgeGapNotes, value: "\(gapCount)", systemImage: "puzzlepiece.extension")
                SummaryChip(title: UIStrings.remediationPlanAmbiguity, value: "\(ambiguityCount)", systemImage: "arrow.triangle.branch")
                SummaryChip(title: UIStrings.remediationPlanDrift, value: "\(driftCount)", systemImage: "clock.arrow.circlepath")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if let projectRoot = result.filters.projectRoot, !projectRoot.isEmpty {
                    PrivacyPathRow(label: UIStrings.project, path: projectRoot)
                }
                if let workspace = result.filters.workspace, !workspace.isEmpty {
                    MetadataRow(label: UIStrings.workspaceReadinessTitle, value: workspace)
                }
                if let taskText = result.filters.taskText, !taskText.isEmpty {
                    MetadataRow(label: UIStrings.taskBenchmarkTaskPlaceholder, value: taskText)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                MetadataRow(label: UIStrings.remediationPlanGuidanceOnly, value: result.filters.includeGuidanceOnly ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RemediationPriorityList(rows: result.priorityRows)
            RemediationPlanItemList(items: result.items)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var itemCount: Int {
        result.summary.totalCount > 0 ? result.summary.totalCount : result.items.count
    }

    private var criticalCount: Int {
        result.summary.criticalCount > 0 ? result.summary.criticalCount : countItems(matching: "critical")
    }

    private var highCount: Int {
        result.summary.highCount > 0 ? result.summary.highCount : countItems(matching: "high")
    }

    private var mediumCount: Int {
        result.summary.mediumCount > 0 ? result.summary.mediumCount : countItems(matching: "medium")
    }

    private var quickWinCount: Int {
        result.summary.quickWinCount > 0 ? result.summary.quickWinCount : result.items.filter { item in
            item.category.localizedCaseInsensitiveContains("quick")
                || item.suggestedAction.localizedCaseInsensitiveContains("quick")
        }.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count + result.items.reduce(0) { $0 + $1.blockerNotes.count }
    }

    private var gapCount: Int {
        result.summary.gapCount > 0 ? result.summary.gapCount : result.gapNotes.count + result.items.reduce(0) { $0 + $1.gapNotes.count }
    }

    private var ambiguityCount: Int {
        result.summary.ambiguityCount > 0 ? result.summary.ambiguityCount : result.items.filter { item in
            item.category.localizedCaseInsensitiveContains("ambigu")
                || item.rationale.localizedCaseInsensitiveContains("ambigu")
        }.count
    }

    private var driftCount: Int {
        result.summary.driftCount > 0 ? result.summary.driftCount : result.items.filter { item in
            item.category.localizedCaseInsensitiveContains("drift")
                || item.category.localizedCaseInsensitiveContains("stale")
        }.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func countItems(matching priority: String) -> Int {
        result.items.filter { item in
            item.priority.localizedCaseInsensitiveContains(priority)
        }.count
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct RemediationPriorityList: View {
    let rows: [RemediationPlanPriorityRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.remediationPlanPriorities)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.remediationPlanNoPriorities)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(6)) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.title)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text("\(row.count)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            MetadataRow(label: UIStrings.cleanupFilterPriority, value: row.priority)
                            if !row.rationale.isEmpty {
                                Text(row.rationale)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

private struct RemediationPlanItemList: View {
    let items: [RemediationPlanItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.remediationPlanItems)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(UIStrings.remediationPlanNoItems)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(items.prefix(10)) { item in
                        RemediationPlanItemCard(item: item)
                    }
                }
            }
        }
    }
}

private struct RemediationPlanItemCard: View {
    let item: RemediationPlanItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(item.title, systemImage: iconName)
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text(item.priority)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.remediationPlanCategory, value: item.category)
                MetadataRow(label: UIStrings.state, value: item.status)
                MetadataRow(label: UIStrings.remediationPlanGuidanceOnly, value: item.guidanceOnly ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                if let agent = item.agent, !agent.isEmpty {
                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                }
                if let capability = item.capability, !capability.isEmpty {
                    MetadataRow(label: UIStrings.capabilityTaxonomyCapability, value: capability)
                }
                if let nextArea = item.nextArea, !nextArea.isEmpty {
                    MetadataRow(label: UIStrings.remediationPlanNextArea, value: nextArea)
                }
            }

            if let skill = item.skill {
                CapabilitySkillList(skills: [skill])
            }

            if !item.rationale.isEmpty {
                Text(item.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Label(item.suggestedAction, systemImage: "lightbulb")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let impact = item.impact, !impact.isEmpty {
                Label(impact, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: item.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: item.blockerNotes, systemImage: "exclamationmark.octagon")
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: item.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: item.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        if item.category.localizedCaseInsensitiveContains("drift") || item.category.localizedCaseInsensitiveContains("stale") {
            return "clock.arrow.circlepath"
        }
        if item.category.localizedCaseInsensitiveContains("ambigu") {
            return "arrow.triangle.branch"
        }
        if item.category.localizedCaseInsensitiveContains("block") {
            return "lock.trianglebadge.exclamationmark"
        }
        if item.category.localizedCaseInsensitiveContains("gap") {
            return "puzzlepiece.extension"
        }
        return "wrench.and.screwdriver"
    }
}

private struct RemediationPreviewDraftsPanel: View {
    let result: RemediationPreviewDraftsResult?
    let isPreviewing: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.fixPreviewTitle, systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                Spacer()
                Label(UIStrings.llmPromptCopyOnly, systemImage: "doc.on.doc")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.fixPreviewBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.fixPreviewAction, systemImage: "wand.and.stars")
                }
                .disabled(isPreviewing)

                if isPreviewing {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                RemediationPreviewDraftsResultView(result: result)
            } else {
                Label(UIStrings.fixPreviewNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.fixPreviewCopyOnlyBoundary, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RemediationPreviewDraftsResultView: View {
    let result: RemediationPreviewDraftsResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.fixPreviewDrafts, value: "\(draftCount)", systemImage: "doc.text")
                SummaryChip(title: UIStrings.fixPreviewFrontmatter, value: "\(frontmatterCount)", systemImage: "list.bullet.rectangle")
                SummaryChip(title: UIStrings.fixPreviewDescription, value: "\(descriptionCount)", systemImage: "text.alignleft")
                SummaryChip(title: UIStrings.fixPreviewPermissions, value: "\(permissionsCount)", systemImage: "lock.shield")
                SummaryChip(title: UIStrings.fixPreviewDependency, value: "\(dependencyCount)", systemImage: "shippingbox")
                SummaryChip(title: UIStrings.fixPreviewPolicy, value: "\(policyCount)", systemImage: "checkmark.shield")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "lock.trianglebadge.exclamationmark")
                SummaryChip(title: UIStrings.llmPromptCopyOnly, value: "\(copyOnlyCount)", systemImage: "doc.on.doc")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if let taskText = result.filters.taskText, !taskText.isEmpty {
                    MetadataRow(label: UIStrings.taskBenchmarkTaskPlaceholder, value: taskText)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RemediationPreviewDraftGroupList(groups: draftGroups)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var draftCount: Int {
        result.summary.totalCount > 0 ? result.summary.totalCount : result.draftItems.count
    }

    private var frontmatterCount: Int {
        result.summary.frontmatterCount > 0 ? result.summary.frontmatterCount : countDrafts(matching: "frontmatter")
    }

    private var descriptionCount: Int {
        result.summary.descriptionCount > 0 ? result.summary.descriptionCount : countDrafts(matching: "description")
    }

    private var permissionsCount: Int {
        result.summary.permissionsCount > 0 ? result.summary.permissionsCount : countDrafts(matching: "permission")
    }

    private var dependencyCount: Int {
        result.summary.dependencyCount > 0 ? result.summary.dependencyCount : countDrafts(matching: "depend")
    }

    private var policyCount: Int {
        result.summary.policyCount > 0 ? result.summary.policyCount : countDrafts(matching: "policy")
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count + result.draftItems.reduce(0) { $0 + $1.blockerNotes.count }
    }

    private var copyOnlyCount: Int {
        result.summary.copyOnlyCount > 0 ? result.summary.copyOnlyCount : result.draftItems.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private var draftGroups: [(type: String, items: [RemediationPreviewDraftItem])] {
        let grouped = Dictionary(grouping: result.draftItems, by: \.draftType)
        return grouped.keys.sorted { lhs, rhs in
            draftTypeSortIndex(lhs) < draftTypeSortIndex(rhs)
        }.map { type in
            (type: type, items: grouped[type] ?? [])
        }
    }

    private func countDrafts(matching draftType: String) -> Int {
        result.draftItems.filter { item in
            item.draftType.localizedCaseInsensitiveContains(draftType)
        }.count
    }

    private func draftTypeSortIndex(_ draftType: String) -> Int {
        let normalized = draftType.lowercased()
        if normalized.contains("frontmatter") { return 0 }
        if normalized.contains("description") { return 1 }
        if normalized.contains("permission") { return 2 }
        if normalized.contains("depend") { return 3 }
        if normalized.contains("policy") { return 4 }
        return 5
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct RemediationPreviewDraftGroupList: View {
    let groups: [(type: String, items: [RemediationPreviewDraftItem])]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.fixPreviewDrafts)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if groups.isEmpty {
                Text(UIStrings.fixPreviewNoDrafts)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups, id: \.type) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(draftTypeLabel(group.type))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(group.items.prefix(8)) { item in
                                RemediationPreviewDraftCard(item: item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func draftTypeLabel(_ draftType: String) -> String {
        let normalized = draftType.lowercased()
        if normalized.contains("frontmatter") { return UIStrings.fixPreviewFrontmatter }
        if normalized.contains("description") { return UIStrings.fixPreviewDescription }
        if normalized.contains("permission") { return UIStrings.fixPreviewPermissions }
        if normalized.contains("depend") { return UIStrings.fixPreviewDependency }
        if normalized.contains("policy") { return UIStrings.fixPreviewPolicy }
        return draftType.isEmpty ? UIStrings.unknown : draftType
    }
}

private struct RemediationPreviewDraftCard: View {
    let item: RemediationPreviewDraftItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(item.title, systemImage: iconName)
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                if let confidenceLabel {
                    Text(confidenceLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.fixPreviewDraftType, value: draftTypeLabel)
                if let agent = item.agent, !agent.isEmpty {
                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                }
                if let findingID = item.findingID, !findingID.isEmpty {
                    MetadataRow(label: UIStrings.fixPreviewFinding, value: findingID)
                }
                if let ruleID = item.ruleID, !ruleID.isEmpty {
                    MetadataRow(label: UIStrings.knowledgeRules, value: ruleID)
                }
            }

            if let skill = item.affectedSkill {
                CapabilitySkillList(skills: [skill])
            }

            if let currentText = item.currentText, !currentText.isEmpty {
                DraftSnippetBlock(title: UIStrings.fixPreviewCurrentSnippet, text: currentText, allowsCopy: false, copyLabel: item.copyLabel)
            }

            DraftSnippetBlock(title: UIStrings.fixPreviewProposedSnippet, text: item.proposedText, allowsCopy: true, copyLabel: item.copyLabel)

            if !item.editGuidance.isEmpty {
                Label(item.editGuidance, systemImage: "pencil.and.list.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !item.rationale.isEmpty {
                Text(item.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: item.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: item.blockerNotes, systemImage: "exclamationmark.octagon")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: item.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var confidenceLabel: String? {
        if let confidenceScore = item.confidenceScore, let band = item.confidenceBand, !band.isEmpty {
            return "\(confidenceScore) · \(band)"
        }
        if let confidenceScore = item.confidenceScore {
            return "\(confidenceScore)"
        }
        return item.confidenceBand?.isEmpty == false ? item.confidenceBand : nil
    }

    private var draftTypeLabel: String {
        let normalized = item.draftType.lowercased()
        if normalized.contains("frontmatter") { return UIStrings.fixPreviewFrontmatter }
        if normalized.contains("description") { return UIStrings.fixPreviewDescription }
        if normalized.contains("permission") { return UIStrings.fixPreviewPermissions }
        if normalized.contains("depend") { return UIStrings.fixPreviewDependency }
        if normalized.contains("policy") { return UIStrings.fixPreviewPolicy }
        return item.draftType
    }

    private var iconName: String {
        let normalized = item.draftType.lowercased()
        if normalized.contains("frontmatter") { return "list.bullet.rectangle" }
        if normalized.contains("description") { return "text.alignleft" }
        if normalized.contains("permission") { return "lock.shield" }
        if normalized.contains("depend") { return "shippingbox" }
        if normalized.contains("policy") { return "checkmark.shield" }
        return "doc.text.magnifyingglass"
    }
}

private struct DraftSnippetBlock: View {
    let title: String
    let text: String
    let allowsCopy: Bool
    let copyLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: "doc.text")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if allowsCopy && !text.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Label(copyLabel.isEmpty ? UIStrings.fixPreviewCopyDraft : copyLabel, systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Text(text.isEmpty ? UIStrings.emptyPlaceholder : text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct RemediationImpactPreviewPanel: View {
    let result: RemediationImpactPreviewResult?
    let isPreviewing: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.impactPreviewTitle, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.impactPreviewBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.impactPreviewAction, systemImage: "scope")
                }
                .disabled(isPreviewing)

                if isPreviewing {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                RemediationImpactPreviewResultView(result: result)
            } else {
                Label(UIStrings.impactPreviewNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.impactPreviewNoWriteBoundary, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RemediationImpactPreviewResultView: View {
    let result: RemediationImpactPreviewResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.impactPreviewImpacts, value: "\(impactCount)", systemImage: "scope")
                SummaryChip(title: UIStrings.impactPreviewTaskImpacts, value: "\(taskImpactCount)", systemImage: "checklist")
                SummaryChip(title: UIStrings.impactPreviewAgentImpacts, value: "\(agentImpactCount)", systemImage: "person.2")
                SummaryChip(title: UIStrings.impactPreviewSkillImpacts, value: "\(skillImpactCount)", systemImage: "wrench.and.screwdriver")
                SummaryChip(title: UIStrings.impactPreviewRiskDeltas, value: "\(riskDeltaCount)", systemImage: "arrow.up.arrow.down")
                SummaryChip(title: UIStrings.impactPreviewSnapshotRollback, value: "\(snapshotRollbackCount)", systemImage: "arrow.uturn.backward.circle")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "lock.trianglebadge.exclamationmark")
                SummaryChip(title: UIStrings.impactPreviewNoWrite, value: "\(noWriteCount)", systemImage: "lock.shield")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if let projectRoot = result.filters.projectRoot, !projectRoot.isEmpty {
                    PrivacyPathRow(label: UIStrings.project, path: projectRoot)
                }
                if let workspace = result.filters.workspace, !workspace.isEmpty {
                    MetadataRow(label: UIStrings.workspaceReadinessTitle, value: workspace)
                }
                if let taskText = result.filters.taskText, !taskText.isEmpty {
                    MetadataRow(label: UIStrings.taskBenchmarkTaskPlaceholder, value: taskText)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RemediationImpactRowGroupList(title: UIStrings.impactPreviewImpacts, rows: result.impactRows, empty: UIStrings.impactPreviewNoImpacts, systemImage: "scope")
            RemediationImpactRowGroupList(title: UIStrings.impactPreviewTaskImpacts, rows: result.taskImpactRows, empty: UIStrings.impactPreviewNoTaskImpacts, systemImage: "checklist")
            RemediationImpactRowGroupList(title: UIStrings.impactPreviewAgentImpacts, rows: result.agentImpactRows, empty: UIStrings.impactPreviewNoAgentImpacts, systemImage: "person.2")
            RemediationImpactRowGroupList(title: UIStrings.impactPreviewSkillImpacts, rows: result.skillImpactRows, empty: UIStrings.impactPreviewNoSkillImpacts, systemImage: "wrench.and.screwdriver")
            RemediationImpactRowGroupList(title: UIStrings.impactPreviewRiskDeltas, rows: result.riskDeltaRows, empty: UIStrings.impactPreviewNoRiskDeltas, systemImage: "arrow.up.arrow.down")
            RemediationImpactRowGroupList(title: UIStrings.impactPreviewSnapshotRollback, rows: result.snapshotRollbackRows, empty: UIStrings.impactPreviewNoSnapshotRollback, systemImage: "arrow.uturn.backward.circle")
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var allRows: [RemediationImpactRow] {
        result.impactRows + result.taskImpactRows + result.agentImpactRows + result.skillImpactRows + result.riskDeltaRows + result.snapshotRollbackRows
    }

    private var impactCount: Int {
        result.summary.totalCount > 0 ? result.summary.totalCount : allRows.count
    }

    private var taskImpactCount: Int {
        result.summary.taskImpactCount > 0 ? result.summary.taskImpactCount : result.taskImpactRows.count
    }

    private var agentImpactCount: Int {
        result.summary.agentImpactCount > 0 ? result.summary.agentImpactCount : result.agentImpactRows.count
    }

    private var skillImpactCount: Int {
        result.summary.skillImpactCount > 0 ? result.summary.skillImpactCount : result.skillImpactRows.count
    }

    private var riskDeltaCount: Int {
        result.summary.riskDeltaCount > 0 ? result.summary.riskDeltaCount : result.riskDeltaRows.count
    }

    private var snapshotRollbackCount: Int {
        result.summary.snapshotRollbackCount > 0 ? result.summary.snapshotRollbackCount : result.snapshotRollbackRows.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count
    }

    private var noWriteCount: Int {
        result.summary.noWriteCount > 0 ? result.summary.noWriteCount : result.safetyFlags.notes.filter { note in
            note.localizedCaseInsensitiveContains("write") || note.localizedCaseInsensitiveContains("read")
        }.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct RemediationImpactRowGroupList: View {
    let title: String
    let rows: [RemediationImpactRow]
    let empty: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(8)) { row in
                        RemediationImpactRowCard(row: row, fallbackIcon: systemImage)
                    }
                }
            }
        }
    }
}

private struct RemediationImpactRowCard: View {
    let row: RemediationImpactRow
    let fallbackIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(row.title, systemImage: iconName)
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text(row.severity)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.remediationPlanCategory, value: row.category)
                if let agent = row.agent, !agent.isEmpty {
                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                }
                if let before = row.before, !before.isEmpty {
                    MetadataRow(label: UIStrings.impactPreviewBefore, value: before)
                }
                if let after = row.after, !after.isEmpty {
                    MetadataRow(label: UIStrings.impactPreviewAfter, value: after)
                }
                if let delta = row.delta, !delta.isEmpty {
                    MetadataRow(label: UIStrings.impactPreviewDelta, value: delta)
                }
            }

            if let skill = row.skill {
                CapabilitySkillList(skills: [skill])
            }

            if !row.impact.isEmpty {
                Label(row.impact, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.rationale.isEmpty {
                Text(row.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: row.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        let normalized = row.category.lowercased()
        if normalized.contains("risk") { return "arrow.up.arrow.down" }
        if normalized.contains("snapshot") || normalized.contains("rollback") { return "arrow.uturn.backward.circle" }
        if normalized.contains("agent") { return "person.2" }
        if normalized.contains("skill") { return "wrench.and.screwdriver" }
        if normalized.contains("task") { return "checklist" }
        return fallbackIcon
    }
}

private struct RemediationBatchReviewPanel: View {
    let result: RemediationBatchReviewResult?
    let isReviewing: Bool
    let onReview: (RemediationBatchReviewOptions) -> Void
    @State private var options = RemediationBatchReviewOptions()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.remediationBatchReviewTitle, systemImage: "rectangle.stack.badge.checkmark")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.remediationBatchReviewBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            RemediationBatchReviewControls(options: $options)

            HStack(spacing: 8) {
                Button {
                    onReview(options)
                } label: {
                    Label(UIStrings.remediationBatchReviewAction, systemImage: "rectangle.stack.badge.checkmark")
                }
                .disabled(isReviewing || options.dimensions.isEmpty)

                if isReviewing {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                RemediationBatchReviewResultView(result: result)
            } else {
                Label(UIStrings.remediationBatchReviewNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.remediationBatchReviewNoWriteBoundary, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RemediationBatchReviewControls: View {
    @Binding var options: RemediationBatchReviewOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(UIStrings.remediationBatchReviewControls, systemImage: "slider.horizontal.3")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], alignment: .leading, spacing: 6) {
                Toggle(UIStrings.remediationBatchReviewControlTask, isOn: $options.includeTask)
                Toggle(UIStrings.remediationBatchReviewControlRisk, isOn: $options.includeRisk)
                Toggle(UIStrings.remediationBatchReviewControlRule, isOn: $options.includeRule)
                Toggle(UIStrings.remediationBatchReviewControlAgent, isOn: $options.includeAgent)
                Toggle(UIStrings.remediationBatchReviewControlWorkspace, isOn: $options.includeWorkspace)
                Toggle(UIStrings.remediationBatchReviewControlBlocked, isOn: $options.includeBlocked)
            }
            .toggleStyle(.checkbox)
            .font(.callout)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct RemediationBatchReviewResultView: View {
    let result: RemediationBatchReviewResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.remediationBatchReviewItems, value: "\(itemCount)", systemImage: "checklist")
                SummaryChip(title: UIStrings.remediationBatchReviewGroups, value: "\(groupCount)", systemImage: "rectangle.stack")
                SummaryChip(title: UIStrings.remediationBatchReviewTaskRows, value: "\(taskCount)", systemImage: "text.badge.checkmark")
                SummaryChip(title: UIStrings.remediationBatchReviewRiskRows, value: "\(riskCount)", systemImage: "exclamationmark.triangle")
                SummaryChip(title: UIStrings.remediationBatchReviewRuleRows, value: "\(ruleCount)", systemImage: "ruler")
                SummaryChip(title: UIStrings.remediationBatchReviewAgentRows, value: "\(agentCount)", systemImage: "person.2")
                SummaryChip(title: UIStrings.remediationBatchReviewWorkspaceRows, value: "\(workspaceCount)", systemImage: "folder")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "lock.trianglebadge.exclamationmark")
                SummaryChip(title: UIStrings.remediationBatchReviewSafeNextSteps, value: "\(safeNextStepCount)", systemImage: "arrow.right.circle")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if !result.filters.dimensions.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewDimensions, value: result.filters.dimensions.joined(separator: ", "))
                }
                if !result.filters.riskLevels.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRiskLevels, value: result.filters.riskLevels.joined(separator: ", "))
                }
                if !result.filters.ruleIDs.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRuleIDs, value: result.filters.ruleIDs.joined(separator: ", "))
                }
                if let projectRoot = result.filters.projectRoot, !projectRoot.isEmpty {
                    PrivacyPathRow(label: UIStrings.project, path: projectRoot)
                }
                if let workspace = result.filters.workspace, !workspace.isEmpty {
                    MetadataRow(label: UIStrings.workspaceReadinessTitle, value: workspace)
                }
                if let taskText = result.filters.taskText, !taskText.isEmpty {
                    MetadataRow(label: UIStrings.taskBenchmarkTaskPlaceholder, value: taskText)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                MetadataRow(label: UIStrings.remediationBatchReviewControlBlocked, value: result.filters.includeBlocked ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.remediationBatchReviewSafeNextSteps, empty: UIStrings.remediationBatchReviewSafeNextStepFallback, values: result.safeNextStepLabels, systemImage: "arrow.right.circle")
            RemediationBatchReviewGroupList(groups: result.groups)
            RemediationBatchReviewItemList(title: UIStrings.remediationBatchReviewItems, items: result.items, empty: UIStrings.remediationBatchReviewNoItems)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var allItems: [RemediationBatchReviewItem] {
        result.items + result.groups.flatMap(\.items)
    }

    private var itemCount: Int {
        result.summary.totalCount > 0 ? result.summary.totalCount : allItems.count
    }

    private var groupCount: Int {
        result.summary.groupCount > 0 ? result.summary.groupCount : result.groups.count
    }

    private var taskCount: Int {
        result.summary.taskCount > 0 ? result.summary.taskCount : countItems(matching: "task")
    }

    private var riskCount: Int {
        result.summary.riskCount > 0 ? result.summary.riskCount : countItems(matching: "risk")
    }

    private var ruleCount: Int {
        result.summary.ruleCount > 0 ? result.summary.ruleCount : allItems.filter { item in
            !(item.ruleID ?? "").isEmpty || item.category.localizedCaseInsensitiveContains("rule")
        }.count
    }

    private var agentCount: Int {
        result.summary.agentCount > 0 ? result.summary.agentCount : allItems.filter { item in
            !(item.agent ?? "").isEmpty || item.category.localizedCaseInsensitiveContains("agent")
        }.count
    }

    private var workspaceCount: Int {
        result.summary.workspaceCount > 0 ? result.summary.workspaceCount : allItems.filter { item in
            !(item.workspace ?? "").isEmpty || item.category.localizedCaseInsensitiveContains("workspace")
        }.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count + allItems.reduce(0) { $0 + $1.blockerNotes.count }
    }

    private var safeNextStepCount: Int {
        result.summary.safeNextStepCount > 0 ? result.summary.safeNextStepCount : result.safeNextStepLabels.count + allItems.filter { !$0.safeNextStepLabel.isEmpty }.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func countItems(matching value: String) -> Int {
        allItems.filter { item in
            item.category.localizedCaseInsensitiveContains(value)
                || (item.reviewArea ?? "").localizedCaseInsensitiveContains(value)
        }.count
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct RemediationBatchReviewGroupList: View {
    let groups: [RemediationBatchReviewGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.remediationBatchReviewGroups)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if groups.isEmpty {
                Text(UIStrings.remediationBatchReviewNoGroups)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(groups.prefix(8)) { group in
                        RemediationBatchReviewGroupCard(group: group)
                    }
                }
            }
        }
    }
}

private struct RemediationBatchReviewGroupCard: View {
    let group: RemediationBatchReviewGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(group.title, systemImage: iconName)
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text(group.priority)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.remediationPlanCategory, value: group.category)
                MetadataRow(label: UIStrings.remediationBatchReviewItems, value: "\(group.items.count)")
            }

            if !group.summary.isEmpty {
                Text(group.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.remediationBatchReviewSafeNextSteps, empty: UIStrings.remediationBatchReviewSafeNextStepFallback, values: group.safeNextStepLabels, systemImage: "arrow.right.circle")
            RemediationBatchReviewItemList(title: UIStrings.remediationBatchReviewItems, items: group.items, empty: UIStrings.remediationBatchReviewNoItems)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: group.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: group.blockerNotes, systemImage: "exclamationmark.octagon")
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: group.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: group.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        batchReviewIcon(for: group.category)
    }
}

private struct RemediationBatchReviewItemList: View {
    let title: String
    let items: [RemediationBatchReviewItem]
    let empty: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(items.prefix(10)) { item in
                        RemediationBatchReviewItemCard(item: item)
                    }
                }
            }
        }
    }
}

private struct RemediationBatchReviewItemCard: View {
    let item: RemediationBatchReviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(item.title, systemImage: batchReviewIcon(for: item.category))
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text(item.priority)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.remediationPlanCategory, value: item.category)
                MetadataRow(label: UIStrings.state, value: item.status)
                if let reviewArea = item.reviewArea, !reviewArea.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewReviewArea, value: reviewArea)
                }
                if let agent = item.agent, !agent.isEmpty {
                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                }
                if let workspace = item.workspace, !workspace.isEmpty {
                    MetadataRow(label: UIStrings.workspaceReadinessTitle, value: workspace)
                }
                if let ruleID = item.ruleID, !ruleID.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRuleIDs, value: ruleID)
                }
                if let riskLevel = item.riskLevel, !riskLevel.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRiskLevels, value: riskLevel)
                }
            }

            if let skill = item.skill {
                CapabilitySkillList(skills: [skill])
            }

            if let taskText = item.taskText, !taskText.isEmpty {
                Label(taskText, systemImage: "text.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !item.rationale.isEmpty {
                Text(item.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Label(item.safeNextStepLabel, systemImage: "arrow.right.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: item.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: item.blockerNotes, systemImage: "exclamationmark.octagon")
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: item.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: item.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private func batchReviewIcon(for category: String) -> String {
    let normalized = category.lowercased()
    if normalized.contains("risk") { return "exclamationmark.triangle" }
    if normalized.contains("rule") { return "ruler" }
    if normalized.contains("agent") { return "person.2" }
    if normalized.contains("workspace") { return "folder" }
    if normalized.contains("task") { return "text.badge.checkmark" }
    if normalized.contains("block") { return "lock.trianglebadge.exclamationmark" }
    return "checklist"
}

private struct RemediationHistoryPanel: View {
    let result: RemediationHistoryResult?
    let recordResult: RemediationHistoryRecordResult?
    let isLoading: Bool
    let isRecording: Bool
    let onLoad: () -> Void
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.remediationHistoryTitle, systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Label(UIStrings.remediationHistoryRecorded, systemImage: "archivebox")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.remediationHistoryBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.remediationHistoryLoadAction, systemImage: "clock.arrow.circlepath")
                }
                .disabled(isLoading || isRecording)

                Button {
                    onRecord()
                } label: {
                    Label(UIStrings.remediationHistoryRecordAction, systemImage: "archivebox")
                }
                .disabled(isLoading || isRecording)

                if isLoading || isRecording {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let recordResult {
                RemediationHistoryRecordResultView(result: recordResult)
            }

            if let result {
                RemediationHistoryResultView(result: result)
            } else {
                Label(UIStrings.remediationHistoryNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.remediationHistoryNoWriteBoundary, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct RemediationHistoryRecordResultView: View {
    let result: RemediationHistoryRecordResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.remediationHistoryRecordResult, systemImage: result.recorded ? "checkmark.seal" : "info.circle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(result.recorded ? UIStrings.remediationHistoryStatusRecorded : UIStrings.routingAccuracyUnavailableShort)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !result.message.isEmpty {
                Text(result.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let record = result.record {
                RemediationHistoryRecordCard(record: record)
            } else if !result.records.isEmpty {
                RemediationHistoryRecordList(records: result.records, title: UIStrings.remediationHistoryRecords)
            }

            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct RemediationHistoryResultView: View {
    let result: RemediationHistoryResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.remediationHistoryRecords, value: "\(recordCount)", systemImage: "archivebox")
                SummaryChip(title: UIStrings.remediationHistoryRecorded, value: "\(recordedCount)", systemImage: "checkmark.seal")
                SummaryChip(title: UIStrings.remediationHistoryRecurrence, value: "\(recurrenceCount)", systemImage: "arrow.triangle.2.circlepath")
                SummaryChip(title: UIStrings.remediationHistoryReopened, value: "\(reopenedCount)", systemImage: "arrow.uturn.backward.circle")
                SummaryChip(title: UIStrings.remediationHistoryReadinessImprovement, value: "\(readinessImprovementCount)", systemImage: "chart.line.uptrend.xyaxis")
                SummaryChip(title: UIStrings.remediationHistoryDecisions, value: "\(decisionCount)", systemImage: "checklist.checked")
                SummaryChip(title: UIStrings.remediationHistoryStatuses, value: "\(statusCount)", systemImage: "tag")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "lock.trianglebadge.exclamationmark")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if !result.filters.ruleIDs.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRuleIDs, value: result.filters.ruleIDs.joined(separator: ", "))
                }
                if !result.filters.riskLevels.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRiskLevels, value: result.filters.riskLevels.joined(separator: ", "))
                }
                if !result.filters.decisions.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistoryDecisions, value: result.filters.decisions.joined(separator: ", "))
                }
                if !result.filters.statuses.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistoryStatuses, value: result.filters.statuses.joined(separator: ", "))
                }
                if let projectRoot = result.filters.projectRoot, !projectRoot.isEmpty {
                    PrivacyPathRow(label: UIStrings.project, path: projectRoot)
                }
                if let workspace = result.filters.workspace, !workspace.isEmpty {
                    MetadataRow(label: UIStrings.workspaceReadinessTitle, value: workspace)
                }
                if let taskText = result.filters.taskText, !taskText.isEmpty {
                    MetadataRow(label: UIStrings.taskBenchmarkTaskPlaceholder, value: taskText)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.remediationHistoryDecisions, empty: UIStrings.routingAccuracyNoGaps, values: result.decisions, systemImage: "checklist.checked")
            RoutingInlineList(title: UIStrings.remediationHistoryStatuses, empty: UIStrings.routingAccuracyNoGaps, values: result.statuses, systemImage: "tag")
            RemediationHistoryRecordList(records: result.records, title: UIStrings.remediationHistoryRecords)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var recordCount: Int {
        result.summary.totalCount > 0 ? result.summary.totalCount : result.records.count
    }

    private var recordedCount: Int {
        result.summary.recordedCount > 0 ? result.summary.recordedCount : result.records.filter { $0.status.localizedCaseInsensitiveContains("record") }.count
    }

    private var recurrenceCount: Int {
        result.summary.recurrenceCount > 0 ? result.summary.recurrenceCount : result.records.reduce(0) { $0 + $1.recurrenceCount }
    }

    private var reopenedCount: Int {
        result.summary.reopenedCount > 0 ? result.summary.reopenedCount : result.records.reduce(0) { $0 + $1.reopenedCount }
    }

    private var readinessImprovementCount: Int {
        result.summary.readinessImprovementCount > 0 ? result.summary.readinessImprovementCount : result.records.filter { record in
            !(record.readinessImprovement ?? "").isEmpty
        }.count
    }

    private var decisionCount: Int {
        result.summary.decisionCount > 0 ? result.summary.decisionCount : Set(result.records.map(\.decision)).count
    }

    private var statusCount: Int {
        result.summary.statusCount > 0 ? result.summary.statusCount : Set(result.records.map(\.status)).count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count + result.records.reduce(0) { $0 + $1.blockerNotes.count }
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct RemediationHistoryRecordList: View {
    let records: [RemediationHistoryRecord]
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if records.isEmpty {
                Text(UIStrings.remediationHistoryNoRecords)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(records.prefix(10)) { record in
                        RemediationHistoryRecordCard(record: record)
                    }
                }
            }
        }
    }
}

private struct RemediationHistoryRecordCard: View {
    let record: RemediationHistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(record.title, systemImage: historyIcon(for: record.category))
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text(record.status)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.remediationPlanCategory, value: record.category)
                MetadataRow(label: UIStrings.remediationHistoryDecision, value: record.decision)
                MetadataRow(label: UIStrings.state, value: record.status)
                if let reviewArea = record.reviewArea, !reviewArea.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewReviewArea, value: reviewArea)
                }
                if let sourceMethod = record.sourceMethod, !sourceMethod.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistorySourceMethod, value: sourceMethod)
                }
                if let agent = record.agent, !agent.isEmpty {
                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                }
                if let workspace = record.workspace, !workspace.isEmpty {
                    MetadataRow(label: UIStrings.workspaceReadinessTitle, value: workspace)
                }
                if let ruleID = record.ruleID, !ruleID.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRuleIDs, value: ruleID)
                }
                if let riskLevel = record.riskLevel, !riskLevel.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewRiskLevels, value: riskLevel)
                }
                if let recordedAt = record.recordedAt, !recordedAt.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistoryRecordedAt, value: recordedAt)
                }
                if let updatedAt = record.updatedAt, !updatedAt.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistoryUpdatedAt, value: updatedAt)
                }
                if record.recurrenceCount > 0 {
                    MetadataRow(label: UIStrings.remediationHistoryRecurrence, value: "\(record.recurrenceCount)")
                }
                if record.reopenedCount > 0 {
                    MetadataRow(label: UIStrings.remediationHistoryReopened, value: "\(record.reopenedCount)")
                }
                if let readinessImprovement = record.readinessImprovement, !readinessImprovement.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistoryReadinessImprovement, value: readinessImprovement)
                }
            }

            if let skill = record.skill {
                CapabilitySkillList(skills: [skill])
            }

            if let taskText = record.taskText, !taskText.isEmpty {
                Label(taskText, systemImage: "text.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !record.rationale.isEmpty {
                Text(record.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !record.note.isEmpty {
                Label(record.note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: record.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: record.blockerNotes, systemImage: "exclamationmark.octagon")
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: record.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: record.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func historyIcon(for category: String) -> String {
        let normalized = category.lowercased()
        if normalized.contains("reopen") { return "arrow.uturn.backward.circle" }
        if normalized.contains("readiness") { return "chart.line.uptrend.xyaxis" }
        if normalized.contains("risk") { return "exclamationmark.triangle" }
        if normalized.contains("rule") { return "ruler" }
        if normalized.contains("agent") { return "person.2" }
        if normalized.contains("workspace") { return "folder" }
        if normalized.contains("task") { return "text.badge.checkmark" }
        return "archivebox"
    }
}

private struct KnowledgeSearchPanel: View {
    @Binding var query: String
    let result: KnowledgeSearchResult?
    let isSearching: Bool
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.knowledgeTitle, systemImage: "books.vertical")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.knowledgeBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                TextField(UIStrings.knowledgeQueryPlaceholder, text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onSearch)
                Button {
                    onSearch()
                } label: {
                    Label(UIStrings.knowledgeSearchAction, systemImage: "magnifyingglass")
                }
                .disabled(isSearching)
            }

            if isSearching {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let result {
                KnowledgeSearchResultView(result: result)
            } else {
                Label(UIStrings.knowledgeNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct KnowledgeSearchResultView: View {
    let result: KnowledgeSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.knowledgeMatches, value: "\(resultCount)", systemImage: "magnifyingglass")
                SummaryChip(title: UIStrings.agent, value: "\(agentCount)", systemImage: "person.3")
                SummaryChip(title: UIStrings.knowledgeFacets, value: "\(result.facetRows.count)", systemImage: "tag")
                SummaryChip(title: UIStrings.knowledgeGapNotes, value: "\(gapCount)", systemImage: "puzzlepiece.extension")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "exclamationmark.octagon")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.knowledgeQuery, value: result.filters.query.isEmpty ? UIStrings.unknown : result.filters.query)
                MetadataRow(label: UIStrings.agent, value: result.filters.agents.isEmpty ? (result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")) : result.filters.agents.map(DisplayText.agent).joined(separator: ", "))
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            KnowledgeRowsList(rows: result.knowledgeRows)
            KnowledgeFacetList(facets: result.facetRows)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var resultCount: Int {
        result.summary.resultCount > 0 ? result.summary.resultCount : result.knowledgeRows.count
    }

    private var agentCount: Int {
        result.summary.agentCount > 0 ? result.summary.agentCount : Set(result.knowledgeRows.compactMap(\.agent)).count
    }

    private var gapCount: Int {
        result.summary.gapCount > 0 ? result.summary.gapCount : result.gapNotes.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count
    }

    private func promptRequestLabel(_ promptRequest: RoutingAccuracyPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct KnowledgeRowsList: View {
    let rows: [KnowledgeSearchRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.knowledgeRows)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.knowledgeNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(10)) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(row.skillName, systemImage: "doc.text.magnifyingglass")
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(row.displayRank)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }

                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.agent, value: row.agent.map(DisplayText.agent) ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.scope, value: row.scope ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.state, value: row.statusLabel)
                                if let definitionID = row.definitionID, !definitionID.isEmpty {
                                    MetadataRow(label: UIStrings.definition, value: definitionID)
                                }
                            }

                            if !row.purpose.isEmpty {
                                Text(row.purpose)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            KnowledgeTokenFlow(title: UIStrings.knowledgeMatchedFields, values: row.matchedFields)
                            RoutingInlineList(title: UIStrings.routingConfidenceMatchReasons, empty: UIStrings.routingConfidenceNoReasons, values: row.matchReasons, systemImage: "text.bubble")
                            KnowledgeTokenFlow(title: UIStrings.knowledgeKeywords, values: row.keywords)
                            KnowledgeTokenFlow(title: UIStrings.knowledgeTools, values: row.tools)
                            KnowledgeTokenFlow(title: UIStrings.knowledgeRules, values: row.rules)
                            KnowledgeTokenFlow(title: UIStrings.knowledgeCapabilities, values: row.capabilityTags)
                            KnowledgeTokenFlow(title: UIStrings.knowledgeRisks, values: row.riskTags)
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: row.safetyFlags, systemImage: "checkmark.shield")
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

private struct KnowledgeTokenFlow: View {
    let title: String
    let values: [String]

    var body: some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(values.prefix(10), id: \.self) { value in
                        Text(value)
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary.opacity(0.45), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct KnowledgeFacetList: View {
    let facets: [KnowledgeFacetRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.knowledgeFacets)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if facets.isEmpty {
                Text(UIStrings.knowledgeNoFacets)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(facets.prefix(12)) { facet in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(facet.value)
                                    .font(.caption.bold())
                                Text(facet.facet)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(facet.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

private struct LocalSkillMapPanel: View {
    let skill: SkillRecord
    let result: LocalSkillMapResult?
    let isBuilding: Bool
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.localSkillMapTitle, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.localSkillMapBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onBuild()
                } label: {
                    Label(UIStrings.localSkillMapAction, systemImage: "map")
                }
                .disabled(isBuilding)
                .help(UIStrings.localSkillMapBoundary)

                if isBuilding {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            LocalSkillMapSelectedContext(skill: skill, selectedSkill: result?.selectedSkill)

            if let result {
                LocalSkillMapResultView(result: result)
            } else {
                Label(UIStrings.localSkillMapNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SkillLifecycleTimelinePanel: View {
    let skill: SkillRecord
    let result: SkillLifecycleTimelineResult?
    let isLoading: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.skillLifecycleTimelineTitle, systemImage: "timeline.selection")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.skillLifecycleTimelineBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.skillLifecycleTimelineAction, systemImage: "clock.arrow.circlepath")
                }
                .disabled(isLoading)
                .help(UIStrings.skillLifecycleTimelineBoundary)

                if isLoading {
                    Label(UIStrings.loading, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            LocalSkillMapSelectedContext(skill: skill, selectedSkill: nil)

            if let result {
                SkillLifecycleTimelineResultView(result: result)
            } else {
                Label(UIStrings.skillLifecycleTimelineNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SkillLifecycleTimelineResultView: View {
    let result: SkillLifecycleTimelineResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.skillLifecycleTimelineEvents, value: "\(eventCount)", systemImage: "timeline.selection")
                SummaryChip(title: UIStrings.skillLifecycleTimelineSkillRows, value: "\(skillCount)", systemImage: "target")
                SummaryChip(title: UIStrings.skillLifecycleTimelineAgentRows, value: "\(agentCount)", systemImage: "person.3")
                SummaryChip(title: UIStrings.skillLifecycleTimelineEventTypes, value: "\(eventTypeCount)", systemImage: "tag")
                SummaryChip(title: UIStrings.skillLifecycleTimelineStages, value: "\(stageCount)", systemImage: "flag")
                SummaryChip(title: UIStrings.knowledgeGapNotes, value: "\(gapCount)", systemImage: "puzzlepiece.extension")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "exclamationmark.octagon")
                SummaryChip(title: UIStrings.crossAgentReadinessEvidence, value: "\(evidenceCount)", systemImage: "checklist")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if let selectedSkillID = result.filters.selectedSkillID, !selectedSkillID.isEmpty {
                    MetadataRow(label: UIStrings.localSkillMapSelectedContext, value: result.filters.selectedSkillName ?? selectedSkillID)
                }
                if let projectRoot = result.filters.projectRoot, !projectRoot.isEmpty {
                    PrivacyPathRow(label: UIStrings.text("projectContext.root", "Project root"), path: projectRoot)
                }
                if let currentCWD = result.filters.currentCWD, !currentCWD.isEmpty {
                    MetadataRow(label: UIStrings.text("projectContext.currentCWD", "Current CWD"), value: currentCWD)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let firstEventAt = result.summary.firstEventAt, !firstEventAt.isEmpty {
                    MetadataRow(label: UIStrings.text("skillLifecycleTimeline.firstEvent", "First event"), value: firstEventAt)
                }
                if let latestEventAt = result.summary.latestEventAt, !latestEventAt.isEmpty {
                    MetadataRow(label: UIStrings.text("skillLifecycleTimeline.latestEvent", "Latest event"), value: latestEventAt)
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            SkillLifecycleTimelineRowList(
                title: UIStrings.skillLifecycleTimelineEvents,
                rows: result.timelineRows,
                systemImage: "timeline.selection"
            )
            SkillLifecycleTimelineRowList(
                title: UIStrings.skillLifecycleTimelineSkillRows,
                rows: result.skillRows,
                systemImage: "target"
            )
            SkillLifecycleTimelineRowList(
                title: UIStrings.skillLifecycleTimelineAgentRows,
                rows: result.agentRows,
                systemImage: "person.3"
            )
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            ProviderObservabilityEvidenceList(evidence: result.evidenceReferences)
            ProviderObservabilitySafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var eventCount: Int {
        result.summary.eventCount > 0 ? result.summary.eventCount : result.timelineRows.count
    }

    private var skillCount: Int {
        result.summary.skillCount > 0 ? result.summary.skillCount : result.skillRows.count
    }

    private var agentCount: Int {
        result.summary.agentCount > 0 ? result.summary.agentCount : result.agentRows.count
    }

    private var eventTypeCount: Int {
        if result.summary.eventTypeCount > 0 {
            return result.summary.eventTypeCount
        }
        return Set(result.timelineRows.map(\.eventType)).count
    }

    private var stageCount: Int {
        if result.summary.stageCount > 0 {
            return result.summary.stageCount
        }
        return Set(result.timelineRows.map(\.lifecycleStage)).count
    }

    private var gapCount: Int {
        result.summary.gapCount > 0 ? result.summary.gapCount : result.gapNotes.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count
    }

    private var evidenceCount: Int {
        result.summary.evidenceCount > 0 ? result.summary.evidenceCount : result.evidenceReferences.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func promptRequestLabel(_ promptRequest: SkillLifecycleTimelinePromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        let redaction = promptRequest.redacted ? UIStrings.aiProviderAuditRedaction : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy) · \(redaction)"
    }
}

private struct SkillLifecycleTimelineRowList: View {
    let title: String
    let rows: [SkillLifecycleTimelineRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.skillLifecycleTimelineNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(10)) { row in
                        SkillLifecycleTimelineRowItem(row: row, systemImage: systemImage)
                    }
                }
            }
        }
    }
}

private struct SkillLifecycleTimelineRowItem: View {
    let row: SkillLifecycleTimelineRow
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(row.title, systemImage: iconName)
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                if let status = row.displayStatus, !status.isEmpty {
                    Text(status)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                if let occurredAt = row.occurredAt, !occurredAt.isEmpty {
                    MetadataRow(label: UIStrings.skillLifecycleTimelineOccurredAt, value: occurredAt)
                }
                MetadataRow(label: UIStrings.skillLifecycleTimelineEventType, value: row.eventType)
                MetadataRow(label: UIStrings.skillLifecycleTimelineLifecycleStage, value: row.lifecycleStage)
                if let agent = row.agent, !agent.isEmpty {
                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                }
                if let skillName = row.skillName, !skillName.isEmpty {
                    MetadataRow(label: UIStrings.text("metadata.name", "Name"), value: skillName)
                }
                if let definitionID = row.definitionID, !definitionID.isEmpty {
                    MetadataRow(label: UIStrings.definition, value: definitionID)
                }
                if let instanceID = row.instanceID, !instanceID.isEmpty {
                    MetadataRow(label: UIStrings.text("metadata.instance", "Instance"), value: instanceID)
                }
                if let source = row.source, !source.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistorySourceMethod, value: source)
                }
                if let count = row.count {
                    MetadataRow(label: UIStrings.providerObservabilityCalls, value: "\(count)")
                }
            }

            if !row.summary.isEmpty {
                Text(row.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: row.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        let normalized = "\(row.eventType) \(row.lifecycleStage)".lowercased()
        if normalized.contains("block") || normalized.contains("risk") || normalized.contains("finding") {
            return "exclamationmark.triangle"
        }
        if normalized.contains("route") || normalized.contains("task") || normalized.contains("session") {
            return "point.topleft.down.curvedto.point.bottomright.up"
        }
        if normalized.contains("remediation") || normalized.contains("fix") || normalized.contains("cleanup") {
            return "wand.and.sparkles"
        }
        if normalized.contains("provider") || normalized.contains("prompt") {
            return "waveform.path.ecg.rectangle"
        }
        if normalized.contains("agent") {
            return "person.3"
        }
        if normalized.contains("skill") {
            return "target"
        }
        return systemImage
    }
}

private struct GuidedCleanupFlowPanel: View {
    let result: GuidedCleanupFlowResult?
    let recordResult: GuidedCleanupRecordStepResult?
    let isPlanning: Bool
    let isRecording: Bool
    let onLoad: () -> Void
    let onRecord: (GuidedCleanupFlowStep) -> Void
    let onOpenSafeLink: (GuidedCleanupSafeActionDeepLink, GuidedCleanupFlowStep?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.guidedCleanupFlowTitle, systemImage: "sparkles.square.filled.on.square")
                    .font(.headline)
                Spacer()
                Label(UIStrings.guidedCleanupFlowAppLocalOnly, systemImage: "archivebox")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.guidedCleanupFlowBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.guidedCleanupFlowAction, systemImage: "list.clipboard")
                }
                .disabled(isPlanning || isRecording)

                if let step = result?.recommendedStep, result?.isUnavailable != true {
                    Button {
                        onRecord(step)
                    } label: {
                        Label(UIStrings.guidedCleanupFlowRecordAction, systemImage: "archivebox")
                    }
                    .disabled(isPlanning || isRecording)
                    .help(UIStrings.guidedCleanupFlowRecordGuidance)
                }

                if isPlanning || isRecording {
                    Label(UIStrings.llmPreparing, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let recordResult {
                GuidedCleanupRecordResultView(result: recordResult)
            }

            if let result {
                GuidedCleanupFlowResultView(result: result, onOpenSafeLink: onOpenSafeLink)
            } else {
                Label(UIStrings.guidedCleanupFlowNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.guidedCleanupFlowNoWriteBoundary, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct GuidedCleanupFlowResultView: View {
    let result: GuidedCleanupFlowResult
    let onOpenSafeLink: (GuidedCleanupSafeActionDeepLink, GuidedCleanupFlowStep?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.guidedCleanupFlowSteps, value: "\(stepCount)", systemImage: "list.clipboard")
                SummaryChip(title: UIStrings.guidedCleanupFlowIssueGroups, value: "\(issueGroupCount)", systemImage: "exclamationmark.triangle")
                SummaryChip(title: UIStrings.guidedCleanupFlowSafeActions, value: "\(safeActionCount)", systemImage: "arrow.right.circle")
                SummaryChip(title: UIStrings.guidedCleanupFlowRecordedSteps, value: "\(recordedStepCount)", systemImage: "archivebox")
                SummaryChip(title: UIStrings.guidedCleanupFlowRecommended, value: "\(recommendedStepCount)", systemImage: "star")
                SummaryChip(title: UIStrings.knowledgeGapNotes, value: "\(gapCount)", systemImage: "puzzlepiece.extension")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "lock.trianglebadge.exclamationmark")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if let selectedSkillID = result.filters.selectedSkillID, !selectedSkillID.isEmpty {
                    MetadataRow(label: UIStrings.localSkillMapSelectedContext, value: result.filters.selectedSkillName ?? selectedSkillID)
                }
                if let taskText = result.filters.taskText, !taskText.isEmpty {
                    MetadataRow(label: UIStrings.taskBenchmarkTaskPlaceholder, value: taskText)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                MetadataRow(label: UIStrings.guidedCleanupFlowIssueGroups, value: result.filters.includeIssueGroups ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                MetadataRow(label: UIStrings.guidedCleanupFlowSafeActions, value: result.filters.includeSafeNextActions ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                MetadataRow(label: UIStrings.guidedCleanupFlowRecordedSteps, value: result.filters.includeRecordedSteps ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            GuidedCleanupStepList(steps: result.flowSteps, onOpenSafeLink: onOpenSafeLink)
            GuidedCleanupIssueGroupList(groups: result.issueGroups)
            GuidedCleanupSafeActionList(actions: result.safeNextActions, onOpenSafeLink: onOpenSafeLink)
            GuidedCleanupRecordedStepList(records: result.recordedSteps)
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            ProviderObservabilityEvidenceList(evidence: result.evidenceReferences)
            ProviderObservabilitySafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var stepCount: Int {
        result.summary.stepCount > 0 ? result.summary.stepCount : result.flowSteps.count
    }

    private var issueGroupCount: Int {
        result.summary.issueGroupCount > 0 ? result.summary.issueGroupCount : result.issueGroups.count
    }

    private var safeActionCount: Int {
        result.summary.safeActionCount > 0 ? result.summary.safeActionCount : result.safeNextActions.count
    }

    private var recordedStepCount: Int {
        result.summary.recordedStepCount > 0 ? result.summary.recordedStepCount : result.recordedSteps.count
    }

    private var recommendedStepCount: Int {
        result.summary.recommendedStepCount > 0 ? result.summary.recommendedStepCount : result.flowSteps.filter(\.recommended).count
    }

    private var gapCount: Int {
        result.summary.gapCount > 0 ? result.summary.gapCount : result.gapNotes.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerNotes.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func promptRequestLabel(_ promptRequest: GuidedCleanupFlowPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        let redaction = promptRequest.redacted ? UIStrings.aiProviderAuditRedaction : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy) · \(redaction)"
    }
}

private struct GuidedCleanupRecordResultView: View {
    let result: GuidedCleanupRecordStepResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.guidedCleanupFlowRecordResult, systemImage: result.recorded ? "checkmark.seal" : "info.circle")
                    .font(.callout.bold())
                Spacer()
                Text(result.recorded ? UIStrings.remediationHistoryStatusRecorded : UIStrings.routingAccuracyUnavailableShort)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            if !result.message.isEmpty {
                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.guidedCleanupFlowAppLocalOnly, value: result.appLocalOnly ? UIStrings.stateEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                MetadataRow(label: UIStrings.guidedCleanupFlowMetadataRedacted, value: result.metadataRedacted ? UIStrings.stateEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
            }

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let record = result.record {
                GuidedCleanupRecordedStepCard(record: record)
            }
            GuidedCleanupRecordedStepList(records: result.records, title: UIStrings.guidedCleanupFlowRecordedSteps)
            ProviderObservabilityEvidenceList(evidence: result.evidenceReferences)
            ProviderObservabilitySafetyList(safety: result.safetyFlags)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct GuidedCleanupStepList: View {
    let steps: [GuidedCleanupFlowStep]
    let onOpenSafeLink: (GuidedCleanupSafeActionDeepLink, GuidedCleanupFlowStep?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.guidedCleanupFlowSteps)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if steps.isEmpty {
                Text(UIStrings.guidedCleanupFlowNoSteps)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(steps.prefix(10)) { step in
                        GuidedCleanupStepCard(step: step, onOpenSafeLink: onOpenSafeLink)
                    }
                }
            }
        }
    }
}

private struct GuidedCleanupStepCard: View {
    let step: GuidedCleanupFlowStep
    let onOpenSafeLink: (GuidedCleanupSafeActionDeepLink, GuidedCleanupFlowStep?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(step.title, systemImage: guidedCleanupIcon(for: step.kind))
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                if step.recommended {
                    Text(UIStrings.guidedCleanupFlowRecommended)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.remediationPlanCategory, value: step.kind)
                MetadataRow(label: UIStrings.state, value: step.status)
                MetadataRow(label: UIStrings.cleanupFilterPriority, value: step.priority)
                MetadataRow(label: UIStrings.guidedCleanupFlowAppLocalOnly, value: step.appLocalRecordOnly ? UIStrings.stateEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                if let order = step.order {
                    MetadataRow(label: UIStrings.text("guidedCleanup.order", "Order"), value: "\(order)")
                }
                if let reviewArea = step.reviewArea, !reviewArea.isEmpty {
                    MetadataRow(label: UIStrings.remediationBatchReviewReviewArea, value: reviewArea)
                }
                if let agent = step.agent, !agent.isEmpty {
                    MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                }
            }

            if let skill = step.skill {
                CapabilitySkillList(skills: [skill])
            }

            if !step.rationale.isEmpty {
                Text(step.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !step.detail.isEmpty {
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Label(step.actionLabel, systemImage: "arrow.right.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            GuidedCleanupSafeLinkButton(link: step.safeActionDeepLink) {
                onOpenSafeLink(step.safeActionDeepLink, step)
            }

            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: step.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: step.blockerNotes, systemImage: "exclamationmark.octagon")
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: step.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: step.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct GuidedCleanupIssueGroupList: View {
    let groups: [GuidedCleanupIssueGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.guidedCleanupFlowIssueGroups)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if groups.isEmpty {
                Text(UIStrings.guidedCleanupFlowNoIssueGroups)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(groups.prefix(8)) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(group.title, systemImage: guidedCleanupIcon(for: group.category))
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(group.severity)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.remediationPlanCategory, value: group.category)
                                MetadataRow(label: UIStrings.state, value: group.status)
                                MetadataRow(label: UIStrings.providerObservabilityCalls, value: "\(group.count)")
                            }
                            if !group.summary.isEmpty {
                                Text(group.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            RoutingInlineList(title: UIStrings.guidedCleanupFlowIssueGroups, empty: UIStrings.guidedCleanupFlowNoIssueGroups, values: group.issueRefs, systemImage: "exclamationmark.triangle")
                            RoutingInlineList(title: UIStrings.guidedCleanupFlowSafeActions, empty: UIStrings.guidedCleanupFlowNoSafeActions, values: group.safeNextActionIDs, systemImage: "arrow.right.circle")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: group.evidenceRefs, systemImage: "checklist")
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

private struct GuidedCleanupSafeActionList: View {
    let actions: [GuidedCleanupSafeAction]
    let onOpenSafeLink: (GuidedCleanupSafeActionDeepLink, GuidedCleanupFlowStep?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.guidedCleanupFlowSafeActions)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if actions.isEmpty {
                Text(UIStrings.guidedCleanupFlowNoSafeActions)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(actions.prefix(8)) { action in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(action.title, systemImage: guidedCleanupIcon(for: action.kind))
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(action.kind)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                if let reviewArea = action.reviewArea, !reviewArea.isEmpty {
                                    MetadataRow(label: UIStrings.remediationBatchReviewReviewArea, value: reviewArea)
                                }
                                if let entryMethod = action.entryMethod, !entryMethod.isEmpty {
                                    MetadataRow(label: UIStrings.text("guidedCleanup.safeAction.entryMethod", "Entry method"), value: entryMethod)
                                }
                                MetadataRow(label: UIStrings.text("guidedCleanup.safeAction.previewRequired", "Preview required"), value: action.requiresPreview ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                                MetadataRow(label: UIStrings.text("guidedCleanup.safeAction.confirmationRequired", "Confirmation required"), value: action.requiresConfirmation ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                                MetadataRow(label: UIStrings.llmPromptCopyOnly, value: action.copyOnly ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                                MetadataRow(label: UIStrings.guidedCleanupFlowExistingSafeEntry, value: action.requiresExistingSafeEntry ? UIStrings.stateEnabled : UIStrings.stateDisabled)
                                MetadataRow(label: UIStrings.guidedCleanupFlowAppLocalOnly, value: action.appLocalOnly ? UIStrings.stateEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                                MetadataRow(label: UIStrings.guidedCleanupFlowCanApplyFix, value: action.canApplyFix ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.stateDisabled)
                            }
                            if !action.description.isEmpty {
                                Text(action.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            GuidedCleanupSafeLinkButton(link: action.deepLink) {
                                onOpenSafeLink(action.deepLink, nil)
                            }
                            RoutingInlineList(title: UIStrings.guidedCleanupFlowSteps, empty: UIStrings.guidedCleanupFlowNoSteps, values: action.relatedStepIDs, systemImage: "list.clipboard")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: action.evidenceRefs, systemImage: "checklist")
                            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: action.safetyFlags, systemImage: "checkmark.shield")
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

private struct GuidedCleanupSafeLinkButton: View {
    let link: GuidedCleanupSafeActionDeepLink
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    onOpen()
                } label: {
                    Label(link.label.isEmpty ? UIStrings.text("guidedCleanup.safeLink.open", "Open safe entry") : link.label, systemImage: "arrowshape.turn.up.right")
                }
                .buttonStyle(.bordered)
                .disabled(link.canApply)
                .help(link.canApply ? UIStrings.text("guidedCleanup.safeLink.applyBlocked", "Guided cleanup links cannot apply changes.") : UIStrings.text("guidedCleanup.safeLink.help", "Open an existing safe preview or read-only review entry."))

                Label(UIStrings.guidedCleanupFlowPreviewOnly, systemImage: "eye")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                if link.requiresConfirmation {
                    Label(UIStrings.scriptExecutionConfirmationRequired, systemImage: "checkmark.shield")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                if link.copyOnly {
                    Label(UIStrings.llmPromptCopyOnly, systemImage: "doc.on.doc")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                MetadataRow(label: UIStrings.text("guidedCleanup.safeLink.target", "Safe link target"), value: link.target)
                MetadataRow(label: UIStrings.text("guidedCleanup.safeLink.trigger", "Safe link trigger"), value: link.trigger)
                if let method = link.method, !method.isEmpty {
                    MetadataRow(label: UIStrings.text("guidedCleanup.safeAction.entryMethod", "Entry method"), value: method)
                }
                if let detailSection = link.detailSection, !detailSection.isEmpty {
                    MetadataRow(label: UIStrings.detailSection, value: detailSection)
                }
                MetadataRow(label: UIStrings.guidedCleanupFlowCanApplyFix, value: link.canApply ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.stateDisabled)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct GuidedCleanupRecordedStepList: View {
    let records: [GuidedCleanupRecordedStep]
    var title: String = UIStrings.guidedCleanupFlowRecordedSteps

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if records.isEmpty {
                Text(UIStrings.guidedCleanupFlowNoRecordedSteps)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(records.prefix(8)) { record in
                        GuidedCleanupRecordedStepCard(record: record)
                    }
                }
            }
        }
    }
}

private struct GuidedCleanupRecordedStepCard: View {
    let record: GuidedCleanupRecordedStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(record.title, systemImage: "archivebox")
                    .font(.callout.bold())
                    .lineLimit(1)
                Spacer()
                Text(record.status)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                if let stepID = record.stepID, !stepID.isEmpty {
                    MetadataRow(label: UIStrings.guidedCleanupFlowStep, value: stepID)
                }
                if let decision = record.decision, !decision.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistoryDecision, value: decision)
                }
                if let sourceMethod = record.sourceMethod, !sourceMethod.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistorySourceMethod, value: sourceMethod)
                }
                if let recordedAt = record.recordedAt, !recordedAt.isEmpty {
                    MetadataRow(label: UIStrings.remediationHistoryRecordedAt, value: recordedAt)
                }
                MetadataRow(label: UIStrings.guidedCleanupFlowMetadataRedacted, value: record.redacted ? UIStrings.stateEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                MetadataRow(label: UIStrings.guidedCleanupFlowAppLocalOnly, value: record.appLocalOnly ? UIStrings.stateEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
            }
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: record.evidenceRefs, systemImage: "checklist")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: record.safetyFlags, systemImage: "checkmark.shield")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private func guidedCleanupIcon(for kind: String) -> String {
    let normalized = kind.lowercased()
    if normalized.contains("risk") || normalized.contains("finding") || normalized.contains("issue") {
        return "exclamationmark.triangle"
    }
    if normalized.contains("history") || normalized.contains("record") {
        return "archivebox"
    }
    if normalized.contains("batch") || normalized.contains("review") {
        return "rectangle.stack.badge.checkmark"
    }
    if normalized.contains("impact") {
        return "scope"
    }
    if normalized.contains("draft") || normalized.contains("fix") {
        return "doc.text.magnifyingglass"
    }
    if normalized.contains("plan") || normalized.contains("remediation") {
        return "wrench.and.screwdriver"
    }
    if normalized.contains("safe") {
        return "checkmark.shield"
    }
    return "list.clipboard"
}

private struct ProviderObservabilityPanel: View {
    let result: ProviderObservabilityResult?
    let isLoading: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.providerObservabilityTitle, systemImage: "waveform.path.ecg.rectangle")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.providerObservabilityBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.providerObservabilityAction, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
                .help(UIStrings.providerObservabilityBoundary)

                if isLoading {
                    Label(UIStrings.loading, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                ProviderObservabilityResultView(result: result)
            } else {
                Label(UIStrings.providerObservabilityNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct ProviderObservabilityResultView: View {
    let result: ProviderObservabilityResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.providerObservabilityCalls, value: "\(callCount)", systemImage: "network")
                SummaryChip(title: UIStrings.providerObservabilitySuccesses, value: "\(successCount)", systemImage: "checkmark.circle")
                SummaryChip(title: UIStrings.providerObservabilityFailures, value: "\(failureCount)", systemImage: "xmark.octagon")
                SummaryChip(title: UIStrings.providerObservabilityBlocked, value: "\(blockedCount)", systemImage: "nosign")
                SummaryChip(title: UIStrings.providerObservabilityEstimatedTokens, value: "\(estimatedTotalTokens)", systemImage: "sum")
                SummaryChip(title: UIStrings.providerObservabilityEstimatedCost, value: costLabel(result.summary.estimatedCostUSD), systemImage: "dollarsign.circle")
                SummaryChip(title: UIStrings.providerObservabilityDuration, value: durationLabel(result.summary.totalDurationMS), systemImage: "timer")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.providerObservabilityAppLocalOnly, value: result.appLocalOnly ? UIStrings.llmEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                MetadataRow(label: UIStrings.providerObservabilityMetadataRedacted, value: result.metadataRedacted ? UIStrings.llmEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                MetadataRow(label: UIStrings.providerObservabilityAverageDuration, value: durationLabel(result.summary.averageDurationMS))
                if let windowDays = result.filters.windowDays {
                    MetadataRow(label: UIStrings.text("routingAccuracy.window", "Window"), value: "\(windowDays)d")
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            ProviderObservabilityDimensionList(title: UIStrings.providerObservabilityProviders, rows: result.providerRows, systemImage: "person.crop.circle.badge.checkmark")
            ProviderObservabilityDimensionList(title: UIStrings.providerObservabilityModels, rows: result.modelRows, systemImage: "cpu")
            ProviderObservabilityDimensionList(title: UIStrings.providerObservabilityDestinations, rows: result.destinationRows, systemImage: "network")
            ProviderObservabilityCallList(rows: result.callRows)
            ProviderObservabilityIssueList(title: UIStrings.providerObservabilityStatusRows, rows: result.statusRows, systemImage: "list.bullet.rectangle")
            ProviderObservabilityIssueList(title: UIStrings.providerObservabilityErrorRows, rows: result.errorRows, systemImage: "exclamationmark.triangle")
            ProviderObservabilityHintList(title: UIStrings.providerObservabilityBudgetHints, rows: result.budgetHints, systemImage: "gauge.with.dots.needle.67percent")
            ProviderObservabilityHintList(title: UIStrings.providerObservabilityUsageHints, rows: result.usageHints, systemImage: "chart.bar.xaxis")
            ProviderObservabilityHintList(title: UIStrings.providerObservabilityRetention, rows: result.retentionRows + result.cleanupRecommendationRows, systemImage: "archivebox")
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            ProviderObservabilityEvidenceList(evidence: result.evidenceReferences)
            ProviderObservabilitySafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var callCount: Int {
        result.summary.callCount > 0 ? result.summary.callCount : result.callRows.count
    }

    private var successCount: Int {
        result.summary.successCount > 0 ? result.summary.successCount : result.callRows.filter { !$0.statusIsProblem }.count
    }

    private var failureCount: Int {
        result.summary.failureCount > 0 ? result.summary.failureCount : result.callRows.filter(\.statusIsProblem).count
    }

    private var blockedCount: Int {
        result.summary.blockedCount
    }

    private var estimatedTotalTokens: Int {
        result.summary.estimatedTotalTokens > 0 ? result.summary.estimatedTotalTokens : result.callRows.reduce(0) { $0 + $1.totalTokens }
    }

    private func promptRequestLabel(_ promptRequest: ProviderObservabilityPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        let redaction = promptRequest.redacted ? UIStrings.aiProviderAuditRedaction : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy) · \(redaction)"
    }
}

private struct ProviderObservabilityDimensionList: View {
    let title: String
    let rows: [ProviderObservabilityDimensionRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(6)) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(row.label, systemImage: systemImage)
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(row.status)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.providerObservabilityCalls, value: "\(row.callCount)")
                                MetadataRow(label: UIStrings.providerObservabilitySuccesses, value: "\(row.successCount)")
                                MetadataRow(label: UIStrings.providerObservabilityFailures, value: "\(row.failureCount)")
                                MetadataRow(label: UIStrings.providerObservabilityBlocked, value: "\(row.blockedCount)")
                                MetadataRow(label: UIStrings.providerObservabilityEstimatedTokens, value: "\(row.estimatedTokens)")
                                MetadataRow(label: UIStrings.providerObservabilityEstimatedCost, value: costLabel(row.estimatedCostUSD))
                                MetadataRow(label: UIStrings.providerObservabilityAverageDuration, value: durationLabel(row.averageDurationMS))
                            }
                            RoutingInlineList(title: UIStrings.text("notes", "Notes"), empty: UIStrings.providerObservabilityNoRows, values: row.notes, systemImage: "info.circle")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
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

private struct ProviderObservabilityCallList: View {
    let rows: [ProviderObservabilityCallRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.providerObservabilityRecentCalls)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoCalls)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(callTitle(row), systemImage: row.statusIsProblem ? "exclamationmark.triangle" : "checkmark.circle")
                                .font(.callout.bold())
                                .foregroundStyle(row.statusIsProblem ? .orange : .primary)
                            Spacer()
                            Text(row.status)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                            MetadataRow(label: UIStrings.llmProvider, value: row.provider)
                            MetadataRow(label: UIStrings.llmModel, value: row.model)
                            MetadataRow(label: UIStrings.llmPromptDestination, value: row.destinationHost)
                            MetadataRow(label: UIStrings.providerObservabilityDuration, value: durationLabel(row.durationMS))
                            MetadataRow(label: UIStrings.providerObservabilityEstimatedTokens, value: UIStrings.llmTokenSummary(input: row.inputTokens, output: row.outputTokens, total: row.totalTokens))
                            MetadataRow(label: UIStrings.providerObservabilityEstimatedCost, value: costLabel(row.estimatedCostUSD))
                            MetadataRow(label: UIStrings.llmPromptCopyOnly, value: row.copyOnly ? UIStrings.llmEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                            MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: row.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                        }
                        if let error = errorText(row), !error.isEmpty {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .textSelection(.enabled)
                        }
                        if !row.detail.isEmpty {
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                        RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: row.safetyFlags, systemImage: "checkmark.shield")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func callTitle(_ row: ProviderObservabilityCallRow) -> String {
        let action = row.requestKind == UIStrings.unknown ? row.action : row.requestKind
        return action.isEmpty ? row.id : action
    }

    private func errorText(_ row: ProviderObservabilityCallRow) -> String? {
        if let code = row.errorCode, let message = row.errorMessage, !message.isEmpty {
            return "\(code): \(message)"
        }
        return row.errorMessage ?? row.errorCode
    }
}

private struct ProviderObservabilityIssueList: View {
    let title: String
    let rows: [ProviderObservabilityIssueRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(row.title, systemImage: systemImage)
                                .font(.callout.bold())
                            Spacer()
                            Text(row.severity)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                            MetadataRow(label: UIStrings.aiProviderTestResult, value: row.status)
                            MetadataRow(label: UIStrings.providerObservabilityCalls, value: "\(row.count)")
                            if let provider = row.provider, !provider.isEmpty {
                                MetadataRow(label: UIStrings.llmProvider, value: provider)
                            }
                            if let model = row.model, !model.isEmpty {
                                MetadataRow(label: UIStrings.llmModel, value: model)
                            }
                            if let destinationHost = row.destinationHost, !destinationHost.isEmpty {
                                MetadataRow(label: UIStrings.llmPromptDestination, value: destinationHost)
                            }
                        }
                        if !row.detail.isEmpty {
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct ProviderObservabilityHintList: View {
    let title: String
    let rows: [ProviderObservabilityHintRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(row.title, systemImage: systemImage)
                                .font(.callout.bold())
                            Spacer()
                            Text(row.severity)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                            if let value = row.value, !value.isEmpty {
                                MetadataRow(label: UIStrings.text("value", "Value"), value: value)
                            }
                            if let threshold = row.threshold, !threshold.isEmpty {
                                MetadataRow(label: UIStrings.text("providerObservability.threshold", "Threshold"), value: threshold)
                            }
                        }
                        if !row.detail.isEmpty {
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        if let recommendation = row.recommendation, !recommendation.isEmpty {
                            Label(recommendation, systemImage: "arrow.right.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct ProviderObservabilityEvidenceList: View {
    let evidence: [ProviderObservabilityEvidenceReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.crossAgentReadinessEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.crossAgentReadinessNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(8)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        HStack(spacing: 8) {
                            if let source = item.source, !source.isEmpty {
                                Text(source)
                            }
                            if let agent = item.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ProviderObservabilitySafetyList: View {
    let safety: ProviderObservabilitySafety

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.knowledgeSafetyFlags)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Label(
                safety.allReadOnlyFlagsClear ? UIStrings.routingAccuracySafetyClear : UIStrings.llmSkillAnalysisEnabledUnsafe,
                systemImage: safety.allReadOnlyFlagsClear ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SafetyPill(label: row.label, isBlocked: !row.isUnsafe)
                }
            }

            if !safety.notes.isEmpty {
                ForEach(safety.notes.prefix(4), id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rows: [(label: String, isUnsafe: Bool)] {
        [
            (UIStrings.skillQualityProviderNotSent, safety.providerRequestSent),
            (UIStrings.skillQualityWritesBlocked, safety.writeBackAllowed || safety.writeActionsAvailable),
            (UIStrings.skillQualityScriptsBlocked, safety.scriptExecutionAllowed || safety.executionActionsAvailable),
            (UIStrings.skillQualityMutationsBlocked, safety.configMutationAllowed || safety.snapshotCreated || safety.triageMutationAllowed),
            (UIStrings.skillQualityCredentialsBlocked, safety.credentialAccessed || safety.rawSecretReturned),
            (UIStrings.llmPromptRawPromptStored, safety.rawPromptPersisted),
            (UIStrings.llmPromptRawResponseStored, safety.rawResponsePersisted),
            (UIStrings.routingAccuracyRawTraceStored, safety.rawTracePersisted),
            (UIStrings.routingAccuracyCloudSync, safety.cloudSyncEnabled),
            (UIStrings.routingAccuracyTelemetry, safety.telemetryEnabled)
        ]
    }
}

private func durationLabel(_ durationMS: Int?) -> String {
    guard let durationMS, durationMS > 0 else { return UIStrings.unknown }
    if durationMS >= 1_000 {
        let seconds = Double(durationMS) / 1_000.0
        return "\(seconds.formatted(.number.precision(.fractionLength(1))))s"
    }
    return "\(durationMS) ms"
}

private func costLabel(_ cost: Double?) -> String {
    guard let cost else { return UIStrings.unknown }
    return UIStrings.llmEstimatedCost(cost)
}

private struct LocalSkillMapSelectedContext: View {
    let skill: SkillRecord
    let selectedSkill: CapabilityTaxonomySkill?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.localSkillMapSelectedContext)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                SummaryChip(title: UIStrings.text("metadata.name", "Name"), value: selectedSkill?.skillName ?? skill.name, systemImage: "target")
                SummaryChip(title: UIStrings.agent, value: DisplayText.agent(selectedSkill?.agent ?? skill.agent), systemImage: "person.crop.circle")
                SummaryChip(title: UIStrings.scope, value: selectedSkill?.scope ?? DisplayText.scope(for: skill), systemImage: "folder")
                SummaryChip(title: UIStrings.definition, value: selectedSkill?.definitionID ?? skill.definitionId, systemImage: "number")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct LocalSkillMapResultView: View {
    let result: LocalSkillMapResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.localSkillMapNodes, value: "\(nodeCount)", systemImage: "circle.grid.cross")
                SummaryChip(title: UIStrings.localSkillMapEdges, value: "\(edgeCount)", systemImage: "arrow.triangle.branch")
                SummaryChip(title: UIStrings.localSkillMapClusters, value: "\(clusterCount)", systemImage: "square.grid.3x3")
                SummaryChip(title: UIStrings.agent, value: "\(agentCount)", systemImage: "person.3")
                SummaryChip(title: UIStrings.knowledgeGapNotes, value: "\(gapCount)", systemImage: "puzzlepiece.extension")
                SummaryChip(title: UIStrings.knowledgeBlockerNotes, value: "\(blockerCount)", systemImage: "exclamationmark.octagon")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.agent, value: agentFilterLabel)
                if let selectedSkillID = result.filters.selectedSkillID, !selectedSkillID.isEmpty {
                    MetadataRow(label: UIStrings.localSkillMapSelectedContext, value: result.filters.selectedSkillName ?? selectedSkillID)
                } else if let selectedSkillContext = result.summary.selectedSkillContext, !selectedSkillContext.isEmpty {
                    MetadataRow(label: UIStrings.localSkillMapSelectedContext, value: selectedSkillContext)
                }
                if let projectRoot = result.filters.projectRoot, !projectRoot.isEmpty {
                    PrivacyPathRow(label: UIStrings.text("projectContext.root", "Project root"), path: projectRoot)
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LocalSkillMapNodeList(nodes: result.nodes)
            LocalSkillMapEdgeList(edges: result.edges)
            LocalSkillMapClusterList(clusters: result.clusters)
            LocalSkillMapIssueList(title: UIStrings.knowledgeGapNotes, rows: result.gapRows, empty: UIStrings.routingAccuracyNoGaps, systemImage: "puzzlepiece.extension")
            LocalSkillMapIssueList(title: UIStrings.knowledgeBlockerNotes, rows: result.blockerRows, empty: UIStrings.routingAccuracyNoBlockers, systemImage: "exclamationmark.octagon")
            CrossAgentReadinessEvidenceList(evidence: result.evidenceReferences)
            StaleDriftSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var nodeCount: Int {
        result.summary.nodeCount > 0 ? result.summary.nodeCount : result.nodes.count
    }

    private var edgeCount: Int {
        result.summary.edgeCount > 0 ? result.summary.edgeCount : result.edges.count
    }

    private var clusterCount: Int {
        result.summary.clusterCount > 0 ? result.summary.clusterCount : result.clusters.count
    }

    private var agentCount: Int {
        result.summary.agentCount > 0 ? result.summary.agentCount : Set(result.nodes.compactMap(\.agent)).count
    }

    private var gapCount: Int {
        result.summary.gapCount > 0 ? result.summary.gapCount : result.gapRows.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerRows.count
    }

    private var agentFilterLabel: String {
        if !result.filters.agents.isEmpty {
            return result.filters.agents.map(DisplayText.agent).joined(separator: ", ")
        }
        return result.filters.agent.map(DisplayText.agent) ?? UIStrings.text("health.allAgents", "All Agents")
    }

    private func promptRequestLabel(_ promptRequest: LocalSkillMapPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct LocalSkillMapNodeList: View {
    let nodes: [LocalSkillMapNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.localSkillMapNodes)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if nodes.isEmpty {
                Text(UIStrings.localSkillMapNoNodes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(nodes.prefix(8)) { node in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(node.label, systemImage: iconName(for: node.kind))
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(node.kind)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }

                            if !node.summary.isEmpty {
                                Text(node.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.agent, value: node.agent.map(DisplayText.agent) ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.scope, value: node.scope ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.state, value: node.statusLabel)
                                if let riskLevel = node.riskLevel, !riskLevel.isEmpty {
                                    MetadataRow(label: UIStrings.text("quality.riskLevel", "Risk level"), value: riskLevel)
                                }
                                if let domain = node.domain, !domain.isEmpty {
                                    MetadataRow(label: UIStrings.capabilityTaxonomyDomain, value: domain)
                                }
                                if let weight = node.weight {
                                    MetadataRow(label: UIStrings.localSkillMapStrength, value: RoutingAccuracySummary.confidenceLabel(weight))
                                }
                            }

                            KnowledgeTokenFlow(title: UIStrings.text("knowledge.tags", "Tags"), values: node.tags)
                            RoutingInlineList(title: UIStrings.routingConfidenceMatchReasons, empty: UIStrings.routingConfidenceNoReasons, values: node.reasons, systemImage: "text.bubble")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: node.evidenceRefs, systemImage: "checklist")
                            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: node.safetyFlags, systemImage: "checkmark.shield")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func iconName(for kind: String) -> String {
        let value = kind.lowercased()
        if value.contains("domain") { return "square.grid.3x3.topleft.filled" }
        if value.contains("agent") { return "person.crop.circle" }
        if value.contains("capability") { return "tag" }
        return "doc.text"
    }
}

private struct LocalSkillMapEdgeList: View {
    let edges: [LocalSkillMapEdge]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.localSkillMapEdges)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if edges.isEmpty {
                Text(UIStrings.localSkillMapNoEdges)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(edges.prefix(8)) { edge in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(edge.label, systemImage: "arrow.triangle.branch")
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(edge.relation)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }

                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.localSkillMapRelation, value: relationText(edge))
                                if let strength = edge.strength {
                                    MetadataRow(label: UIStrings.localSkillMapStrength, value: RoutingAccuracySummary.confidenceLabel(strength))
                                }
                                if let direction = edge.direction, !direction.isEmpty {
                                    MetadataRow(label: UIStrings.text("localSkillMap.direction", "Direction"), value: direction)
                                }
                            }

                            RoutingInlineList(title: UIStrings.routingConfidenceMatchReasons, empty: UIStrings.routingConfidenceNoReasons, values: edge.reasons, systemImage: "text.bubble")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: edge.evidenceRefs, systemImage: "checklist")
                            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: edge.safetyFlags, systemImage: "checkmark.shield")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func relationText(_ edge: LocalSkillMapEdge) -> String {
        let endpoints = [edge.sourceID, edge.targetID].compactMap { $0 }.joined(separator: " -> ")
        return endpoints.isEmpty ? edge.relation : "\(endpoints) · \(edge.relation)"
    }
}

private struct LocalSkillMapClusterList: View {
    let clusters: [LocalSkillMapCluster]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.localSkillMapClusters)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if clusters.isEmpty {
                Text(UIStrings.localSkillMapNoClusters)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(clusters.prefix(6)) { cluster in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(cluster.title, systemImage: "square.grid.3x3")
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(cluster.kind)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }

                            if !cluster.summary.isEmpty {
                                Text(cluster.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            KnowledgeTokenFlow(title: UIStrings.localSkillMapNodeIDs, values: cluster.nodeIDs)
                            KnowledgeTokenFlow(title: UIStrings.agent, values: cluster.agents.map(DisplayText.agent))
                            KnowledgeTokenFlow(title: UIStrings.knowledgeCapabilities, values: cluster.capabilities)
                            CapabilitySkillList(skills: cluster.representativeSkills)
                            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: cluster.gapNotes, systemImage: "puzzlepiece.extension")
                            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: cluster.blockerNotes, systemImage: "exclamationmark.octagon")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: cluster.evidenceRefs, systemImage: "checklist")
                            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: cluster.safetyFlags, systemImage: "checkmark.shield")
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

private struct LocalSkillMapIssueList: View {
    let title: String
    let rows: [LocalSkillMapIssueRow]
    let empty: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(row.title, systemImage: systemImage)
                            .font(.callout)
                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                            if let severity = row.severity, !severity.isEmpty {
                                MetadataRow(label: UIStrings.findingSeverityFilter, value: severity)
                            }
                            if let agent = row.agent, !agent.isEmpty {
                                MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                            }
                            if let source = row.source, !source.isEmpty {
                                PrivacyPathRow(label: UIStrings.source, path: source)
                            }
                        }
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
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

private struct AgentSessionSkillReviewPanel: View {
    @Binding var transcriptText: String
    @Binding var taskText: String
    @Binding var expectedSkills: String
    let listResult: AgentSessionSkillReviewListResult
    let reviewResult: AgentSessionSkillReviewResult?
    let deleteResult: AgentSessionSkillReviewDeleteResult?
    let latestRecord: AgentSessionSkillReviewRecord?
    let isLoading: Bool
    let isReviewing: Bool
    let isDeleting: (AgentSessionSkillReviewRecord) -> Bool
    let onLoad: () -> Void
    let onReview: () -> Void
    let onDelete: (AgentSessionSkillReviewRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.agentSessionReviewTitle, systemImage: "person.crop.rectangle.stack")
                    .font(.headline)
                Spacer()
                Label(UIStrings.agentSessionReviewAppLocal, systemImage: "archivebox")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.agentSessionReviewBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Label(UIStrings.agentSessionReviewNoWriteBoundary, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                TextField(UIStrings.agentSessionReviewTaskPlaceholder, text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                TextField(UIStrings.agentSessionReviewExpectedPlaceholder, text: $expectedSkills, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...2)
                ZStack(alignment: .topLeading) {
                    if transcriptText.isEmpty {
                        Text(UIStrings.agentSessionReviewTranscriptPlaceholder)
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $transcriptText)
                        .font(.system(.callout, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 84, maxHeight: 126)
                        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack(spacing: 8) {
                Button {
                    onReview()
                } label: {
                    Label(UIStrings.agentSessionReviewAction, systemImage: "checkmark.bubble")
                }
                .disabled(isReviewing || transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.agentSessionReviewLoadAction, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || isReviewing)

                Spacer()
            }

            if isLoading || isReviewing {
                Label(UIStrings.llmPreparing, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let reason = reviewResult?.fallbackReason, !reason.isEmpty {
                Label(reason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let latestRecord {
                VStack(alignment: .leading, spacing: 8) {
                    Text(UIStrings.agentSessionReviewLatest)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    AgentSessionSkillReviewRecordView(record: latestRecord, compact: false)
                }
            } else if listResult.reviews.isEmpty {
                Label(UIStrings.agentSessionReviewNoReviews, systemImage: "clock.badge.questionmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            AgentSessionSkillReviewListView(
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

private struct AgentSessionSkillReviewListView: View {
    let result: AgentSessionSkillReviewListResult
    let deleteResult: AgentSessionSkillReviewDeleteResult?
    let isDeleting: (AgentSessionSkillReviewRecord) -> Bool
    let onDelete: (AgentSessionSkillReviewRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(UIStrings.agentSessionReviewReviews)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(result.reviews.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if result.reviews.isEmpty {
                Text(UIStrings.agentSessionReviewNoReviews)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(result.reviews.prefix(10)) { record in
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
                                .help(UIStrings.agentSessionReviewDeleteAction)
                            }
                            AgentSessionSkillReviewRecordView(record: record, compact: true)
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
                    .textSelection(.enabled)
            }
        }
    }
}

private struct AgentSessionSkillReviewRecordView: View {
    let record: AgentSessionSkillReviewRecord
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
                    SummaryChip(title: UIStrings.agentSessionReviewDetectedSkills, value: "\(record.detectedSkills.count)", systemImage: "wrench.and.screwdriver")
                    SummaryChip(title: UIStrings.agentSessionReviewInterference, value: "\(record.interference.count)", systemImage: "exclamationmark.triangle")
                    SummaryChip(title: UIStrings.agentSessionReviewSafeNextSteps, value: "\(record.safeNextSteps.count)", systemImage: "arrow.right.circle")
                    SummaryChip(title: UIStrings.knowledgeSafetyFlags, value: "\(record.safetyFlags.count + record.safety.notes.count)", systemImage: "checkmark.shield")
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    MetadataRow(label: UIStrings.agentSessionReviewOutcome, value: record.outcome.isEmpty ? UIStrings.unknown : record.outcome)
                    if let agent = record.agent, !agent.isEmpty {
                        MetadataRow(label: UIStrings.agent, value: DisplayText.agent(agent))
                    }
                    if let createdAt = record.createdAt, !createdAt.isEmpty {
                        MetadataRow(label: UIStrings.remediationHistoryRecordedAt, value: createdAt)
                    }
                    MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: record.safety.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                    MetadataRow(label: UIStrings.skillQualityWritesBlocked, value: readOnlyValue(!record.safety.writeBackAllowed && !record.safety.writeActionsAvailable))
                    MetadataRow(label: UIStrings.skillQualityScriptsBlocked, value: readOnlyValue(!record.safety.scriptExecutionAllowed && !record.safety.executionActionsAvailable))
                    MetadataRow(label: UIStrings.skillQualityMutationsBlocked, value: readOnlyValue(!record.safety.configMutationAllowed && !record.safety.snapshotCreated && !record.safety.triageMutationAllowed))
                    MetadataRow(label: UIStrings.skillQualityCredentialsBlocked, value: readOnlyValue(!record.safety.credentialAccessed && !record.safety.rawSecretReturned))
                }
            }

            if !record.summary.isEmpty {
                Text(record.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 3 : nil)
                    .textSelection(.enabled)
            }

            AgentSessionSkillRefList(title: UIStrings.agentSessionReviewDetectedSkills, skills: record.detectedSkills)
            AgentSessionSkillRefList(title: UIStrings.agentSessionReviewExpectedSkills, skills: record.expectedSkills)
            AgentSessionInterferenceList(items: record.interference, compact: compact)
            RoutingInlineList(title: UIStrings.agentSessionReviewSafeNextSteps, empty: UIStrings.agentSessionReviewNoSafeNextSteps, values: record.safeNextSteps, systemImage: "arrow.right.circle")

            if !compact || !record.redactedExcerpt.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(UIStrings.agentSessionReviewRedactedExcerpt)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(record.redactedExcerpt.isEmpty ? UIStrings.agentSessionReviewNoExcerpt : record.redactedExcerpt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(record.redactedExcerpt.isEmpty ? .secondary : .primary)
                        .lineLimit(compact ? 3 : nil)
                        .textSelection(.enabled)
                }
            }

            RoutingInlineList(title: UIStrings.agentSessionReviewReasons, empty: UIStrings.agentSessionReviewNoReasons, values: record.reasons, systemImage: "text.bubble")
            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: record.safetyFlags, systemImage: "lock.shield")
            CrossAgentReadinessEvidenceList(evidence: record.evidenceReferences)
            if !compact {
                CrossAgentReadinessSafetyList(safety: record.safety)
            }
        }
        .padding(compact ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(compact ? Color.clear : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private var outcomeTint: Color {
        switch record.outcome.lowercased() {
        case "hit", "matched", "expected_match", "expected-match", "correct":
            return .green
        case "miss", "wrong_pick", "wrong-pick", "interference":
            return .red
        case "ambiguous", "partial":
            return .orange
        default:
            return .secondary
        }
    }

    private func readOnlyValue(_ isBlocked: Bool) -> String {
        isBlocked ? UIStrings.llmSkillAnalysisBlocked : UIStrings.llmSkillAnalysisEnabledUnsafe
    }
}

private struct AgentSessionSkillRefList: View {
    let title: String
    let skills: [TaskBenchmarkSkillRef]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if skills.isEmpty {
                Text(UIStrings.agentSessionReviewNoSkills)
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

private struct AgentSessionInterferenceList: View {
    let items: [AgentSessionInterferenceSignal]
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.agentSessionReviewInterference)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(UIStrings.agentSessionReviewNoInterference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items.prefix(compact ? 2 : 6)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(item.title, systemImage: "exclamationmark.triangle")
                                .font(.caption.bold())
                                .lineLimit(1)
                            Spacer()
                            Text(item.severity)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        if let agent = item.agent, !agent.isEmpty {
                            Text(DisplayText.agent(agent))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let skill = item.skill {
                            Text(skillLabel(skill))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 2 : nil)
                            .textSelection(.enabled)
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: item.evidenceRefs, systemImage: "checklist")
                    }
                    .padding(compact ? 0 : 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(compact ? Color.clear : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
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
        LongTextReviewBlock(
            title: title,
            text: text,
            emptyText: UIStrings.llmSkillAnalysisNoDraft,
            systemImage: "doc.on.doc"
        )
    }
}

private enum LongTextRenderMode {
    case plain
    case markdown
}

private struct LongTextReviewBlock: View {
    let title: String
    let text: String
    let emptyText: String
    let systemImage: String
    var renderMode: LongTextRenderMode = .plain
    @State private var isShowingDetails = false

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayText: String {
        hasText ? text : emptyText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if hasText {
                    Button {
                        isShowingDetails = true
                    } label: {
                        Label(UIStrings.llmPromptViewDetails, systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Button {
                        copyToPasteboard(displayText)
                    } label: {
                        Label(UIStrings.llmPromptCopyFullText, systemImage: "doc.on.doc")
                    }
                }
            }
            RenderedLongText(
                text: displayText,
                renderMode: renderMode,
                isEmpty: !hasText,
                lineLimit: hasText ? 5 : nil
            )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
        .sheet(isPresented: $isShowingDetails) {
            LongTextDetailSheet(title: title, text: displayText, renderMode: renderMode)
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct LongTextDetailSheet: View {
    let title: String
    let text: String
    let renderMode: LongTextRenderMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label(UIStrings.llmPromptCopyFullText, systemImage: "doc.on.doc")
                }
                Button(UIStrings.llmPromptCloseDetails) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                RenderedLongText(
                    text: text,
                    renderMode: renderMode,
                    isEmpty: false,
                    lineLimit: nil
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .frame(minWidth: 680, minHeight: 460)
    }
}

private struct RenderedLongText: View {
    let text: String
    let renderMode: LongTextRenderMode
    let isEmpty: Bool
    let lineLimit: Int?

    var body: some View {
        Group {
            if renderMode == .markdown {
                RenderedMarkdownDocument(
                    text: text,
                    isEmpty: isEmpty,
                    maxBlocks: lineLimit
                )
            } else {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(lineLimit)
            }
        }
        .foregroundStyle(isEmpty ? .secondary : .primary)
        .textSelection(.enabled)
    }
}

private struct RenderedMarkdownDocument: View {
    let text: String
    let isEmpty: Bool
    let maxBlocks: Int?

    private var document: MarkdownRenderDocument {
        MarkdownRenderDocument(text: text, maxBlocks: maxBlocks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
            if document.isTruncated {
                Text("...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(isEmpty ? .secondary : .primary)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownRenderBlock) -> some View {
        switch block {
        case let .heading(level, value):
            MarkdownInlineText(value, font: level <= 2 ? .headline : .subheadline.bold())
        case let .paragraph(value):
            MarkdownInlineText(value, font: .callout)
        case let .bullet(value):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•")
                    .font(.callout.bold())
                MarkdownInlineText(value, font: .callout)
            }
        case let .numbered(marker, value):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(marker)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                MarkdownInlineText(value, font: .callout)
            }
        case .rule:
            Divider()
        case let .code(value):
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
        }
    }
}

private struct MarkdownInlineText: View {
    let value: String
    let font: Font

    init(_ value: String, font: Font) {
        self.value = value
        self.font = font
    }

    var body: some View {
        if let attributed = try? AttributedString(markdown: value) {
            Text(attributed)
                .font(font)
        } else {
            Text(value)
                .font(font)
        }
    }
}

private enum MarkdownRenderBlock {
    case heading(level: Int, String)
    case paragraph(String)
    case bullet(String)
    case numbered(marker: String, String)
    case rule
    case code(String)
}

private struct MarkdownRenderDocument {
    let blocks: [MarkdownRenderBlock]
    let isTruncated: Bool

    init(text: String, maxBlocks: Int?) {
        let parsedBlocks = Self.parse(text: text)
        if let maxBlocks, parsedBlocks.count > maxBlocks {
            self.blocks = Array(parsedBlocks.prefix(maxBlocks))
            self.isTruncated = true
        } else {
            self.blocks = parsedBlocks
            self.isTruncated = false
        }
    }

    private static func parse(text: String) -> [MarkdownRenderBlock] {
        let lines = normalizeMarkdownBlocks(in: text).components(separatedBy: "\n")
        var blocks: [MarkdownRenderBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            let paragraph = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph))
            }
            paragraphLines.removeAll()
        }

        func flushCodeBlock() {
            blocks.append(.code(codeLines.joined(separator: "\n")))
            codeLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    flushCodeBlock()
                    isInCodeBlock = false
                } else {
                    flushParagraph()
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
                continue
            }

            guard !trimmed.isEmpty else {
                flushParagraph()
                continue
            }

            if let heading = headingBlock(from: trimmed) {
                flushParagraph()
                blocks.append(heading)
            } else if isRule(trimmed) {
                flushParagraph()
                blocks.append(.rule)
            } else if let bullet = bulletBlock(from: trimmed) {
                flushParagraph()
                blocks.append(bullet)
            } else if let numbered = numberedBlock(from: trimmed) {
                flushParagraph()
                blocks.append(numbered)
            } else {
                paragraphLines.append(line)
            }
        }

        if isInCodeBlock {
            flushCodeBlock()
        }
        flushParagraph()
        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }

    private static func normalizeMarkdownBlocks(in text: String) -> String {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")

        for marker in [" --- ", " *** ", " ___ "] {
            normalized = normalized.replacingOccurrences(of: marker, with: "\n\(marker.trimmingCharacters(in: .whitespaces))\n")
        }

        let headingMarkers = [
            " ###### ",
            " ##### ",
            " #### ",
            " ### ",
            " ## ",
            " # "
        ]
        for marker in headingMarkers {
            normalized = normalized.replacingOccurrences(of: marker, with: "\n\(marker.trimmingCharacters(in: .whitespaces)) ")
        }

        normalized = normalized.replacingOccurrences(of: " - ", with: "\n- ")
        normalized = normalized.replacingOccurrences(of: " * ", with: "\n* ")
        normalized = normalized.replacingOccurrences(of: " + ", with: "\n+ ")

        return normalized
    }

    private static func headingBlock(from trimmed: String) -> MarkdownRenderBlock? {
        let hashes = trimmed.prefix { $0 == "#" }.count
        guard hashes > 0, hashes <= 6 else { return nil }
        let markerEnd = trimmed.index(trimmed.startIndex, offsetBy: hashes)
        guard markerEnd < trimmed.endIndex, trimmed[markerEnd] == " " else { return nil }
        let contentStart = trimmed.index(after: markerEnd)
        let content = String(trimmed[contentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return .heading(level: hashes, content)
    }

    private static func bulletBlock(from trimmed: String) -> MarkdownRenderBlock? {
        for marker in ["- ", "* ", "+ ", "• "] where trimmed.hasPrefix(marker) {
            let content = String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : .bullet(content)
        }
        return nil
    }

    private static func numberedBlock(from trimmed: String) -> MarkdownRenderBlock? {
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let number = String(trimmed[..<dotIndex])
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let contentStart = trimmed.index(after: dotIndex)
        guard contentStart < trimmed.endIndex, trimmed[contentStart] == " " else { return nil }
        let content = String(trimmed[trimmed.index(after: contentStart)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return .numbered(marker: "\(number).", content)
    }

    private static func isRule(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let characters = Set(trimmed)
        return characters == ["-"] || characters == ["*"] || characters == ["_"]
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
                Label(UIStrings.llmPromptHistoryNote, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LongTextReviewBlock(
                    title: UIStrings.llmPromptOutput,
                    text: output,
                    emptyText: UIStrings.llmSkillAnalysisNoDraft,
                    systemImage: "doc.on.doc",
                    renderMode: .markdown
                )
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
                PrivacyPathRow(label: UIStrings.source, path: skill.displayPath)
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
                PrivacyPathRow(label: UIStrings.source, path: preview.sourcePath)
                MetadataRow(label: UIStrings.toolGlobalTargetAgent, value: preview.target.title)
                if let targetPath = preview.targetPath {
                    PrivacyPathRow(label: UIStrings.target, path: targetPath)
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
