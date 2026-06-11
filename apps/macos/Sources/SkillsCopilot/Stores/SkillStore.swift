import Foundation

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [SkillRecord] = []
    @Published private(set) var findings: [RuleFindingRecord] = []
    @Published private(set) var ruleTuning: [RuleTuningRecord] = []
    @Published private(set) var conflicts: [ConflictGroupRecord] = []
    @Published private(set) var cleanupQueue = CleanupQueueResult.emptyFallback()
    @Published private(set) var isLoadingCleanupQueue = false
    @Published private(set) var crossAgentComparisons = CrossAgentComparisonResult.emptyFallback()
    @Published private(set) var isLoadingCrossAgentComparisons = false
    @Published private(set) var localReportExportResult: LocalReportExportResult?
    @Published private(set) var isExportingLocalReport = false
    @Published private(set) var healthSummary = SkillHealthSummary.empty
    @Published private(set) var agentConfigSnapshots: [ConfigSnapshotRecord] = []
    @Published private(set) var isLoadingAgentConfigSnapshots = false
    @Published private(set) var detailsByID: [SkillRecord.ID: SkillDetailRecord] = [:]
    @Published private(set) var skillEventsByID: [SkillRecord.ID: [SkillEventRecord]] = [:]
    @Published private(set) var loadingSkillEventIDs: Set<SkillRecord.ID> = []
    @Published private(set) var status: ServiceStatus?
    @Published private(set) var llmStatus = LLMStatus.disabledFallback()
    @Published private(set) var aiProviderStatus = AIProviderStatus.unavailable()
    @Published private(set) var aiProviderTestResult: AIProviderTestResult?
    @Published private(set) var llmPrepareResults: [LLMAction: LLMPrepareResult] = [:]
    @Published private(set) var preparingLLMActions: Set<LLMAction> = []
    @Published private(set) var skillAnalysisPrepareResults: [String: LLMSkillAnalysisPrepareResult] = [:]
    @Published private(set) var preparingSkillAnalysisKeys: Set<String> = []
    @Published private(set) var skillQualityScores: [SkillRecord.ID: SkillQualityScoreResult] = [:]
    @Published private(set) var scoringSkillQualityIDs: Set<SkillRecord.ID> = []
    @Published private(set) var taskReadinessResult: TaskReadinessResult?
    @Published private(set) var checkingTaskReadinessSkillIDs: Set<SkillRecord.ID> = []
    @Published private(set) var routingConfidenceResult: SkillRoutingConfidenceResult?
    @Published private(set) var rankingRoutingSkillIDs: Set<SkillRecord.ID> = []
    @Published private(set) var taskBenchmarkList = TaskBenchmarkListResult(benchmarks: [])
    @Published private(set) var taskBenchmarkEvaluation: TaskBenchmarkEvaluationResult?
    @Published private(set) var taskBenchmarkDeleteResult: TaskBenchmarkDeleteResult?
    @Published private(set) var routingRegressionBaseline: RoutingRegressionBaselineResult?
    @Published private(set) var routingRegressionDetection: RoutingRegressionDetectionResult?
    @Published private(set) var routingAccuracyDashboard: RoutingAccuracyDashboard?
    @Published private(set) var traceImportList = AgentTraceImportListResult(imports: [])
    @Published private(set) var traceImportResult: AgentTraceImportResult?
    @Published private(set) var traceImportDeleteResult: AgentTraceImportDeleteResult?
    @Published private(set) var isLoadingTaskBenchmarks = false
    @Published private(set) var isSavingTaskBenchmark = false
    @Published private(set) var isEvaluatingTaskBenchmarks = false
    @Published private(set) var isSavingRoutingBaseline = false
    @Published private(set) var isDetectingRoutingRegression = false
    @Published private(set) var isLoadingRoutingAccuracyDashboard = false
    @Published private(set) var isLoadingTraceImports = false
    @Published private(set) var isImportingTrace = false
    @Published private(set) var deletingTaskBenchmarkIDs: Set<String> = []
    @Published private(set) var deletingTraceImportIDs: Set<String> = []
    @Published private(set) var llmPromptPreviews: [String: LLMPromptPreview] = [:]
    @Published private(set) var previewingLLMPromptKeys: Set<String> = []
    @Published private(set) var sendingLLMPromptKeys: Set<String> = []
    @Published private(set) var llmPromptSendResults: [String: LLMPromptSendResult] = [:]
    @Published private(set) var scriptExecutionPreviews: [SkillRecord.ID: ScriptExecutionPreview] = [:]
    @Published private(set) var previewingScriptExecutionSkillIDs: Set<SkillRecord.ID> = []
    @Published private(set) var batchTogglePreview: BatchTogglePreview?
    @Published private(set) var isPreviewingBatchToggle = false
    @Published private(set) var isApplyingBatchToggle = false
    @Published private(set) var projectContextState: ProjectContextState?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var isScanning = false
    @Published private(set) var isWriting = false
    @Published private(set) var isProjectUpdating = false
    @Published private(set) var isLoadingSettings = false
    @Published private(set) var isSavingSettings = false
    @Published private(set) var isLoadingAIProvider = false
    @Published private(set) var isSavingAIProvider = false
    @Published private(set) var isTestingAIProvider = false
    @Published private(set) var lastMutationMessage: String?
    @Published private(set) var refreshStatusMessage = UIStrings.refreshIdle
    @Published private(set) var watcherStatusMessage = UIStrings.refreshWatcherManual
    @Published private(set) var refreshLogEntries: [RefreshLogEntry] = []
    @Published private(set) var lastScanActivity: RefreshActivity?
    @Published private(set) var canRetryLastRefresh = false
    @Published private(set) var claudeSettings: ConfigDocumentRecord?
    @Published private(set) var settingsMessage: String?
    @Published private(set) var settingsErrorMessage: String?
    @Published private(set) var aiProviderMessage: String?
    @Published private(set) var aiProviderErrorMessage: String?
    @Published var selectedSkillID: SkillRecord.ID?
    @Published var selectedDetailSection: DetailSection = .overview
    @Published var searchText = "" {
        didSet { handleListCriteriaChanged() }
    }
    @Published var agentFilter: SkillAgentFilter = .claudeCode {
        didSet {
            handleListCriteriaChanged()
            routingAccuracyDashboard = nil
            Task { await loadAgentConfigSnapshots() }
            Task { await loadCleanupQueue() }
            Task { await loadCrossAgentComparisons() }
        }
    }
    @Published var stateFilter: SkillStateFilter = .all {
        didSet { handleListCriteriaChanged() }
    }
    @Published var cleanupKindFilter: CleanupQueueKindFilter = .all
    @Published var cleanupPriorityFilter: CleanupQueuePriorityFilter = .all
    @Published var batchToggleAction: BatchToggleAction = .disable {
        didSet { batchTogglePreview = nil }
    }
    @Published var localReportFormat: LocalReportFormat = .markdown
    @Published var sortOrder: SkillSortOrder = .name {
        didSet { handleListCriteriaChanged() }
    }
    @Published var taskReadinessText = "" {
        didSet {
            if oldValue != taskReadinessText {
                taskReadinessResult = nil
            }
        }
    }
    @Published var routingConfidenceText = "" {
        didSet {
            if oldValue != routingConfidenceText {
                routingConfidenceResult = nil
            }
        }
    }
    @Published var taskBenchmarkText = ""
    @Published var traceImportText = ""
    @Published var traceImportTitle = ""
    @Published var traceImportTask = ""
    @Published var traceImportExpectedSkills = ""
    @Published var errorMessage: String?

    private let service: ServiceClient
    private var lastRefreshAction: RefreshAction = .reload
    private var llmPreparedSkillID: SkillRecord.ID?
    private var taskReadinessCheckedSkillID: SkillRecord.ID?
    private var routingConfidenceRankedSkillID: SkillRecord.ID?
    private var agentConfigSnapshotLoadGeneration = 0

    init(service: ServiceClient) {
        self.service = service
    }

    var isRefreshBusy: Bool {
        isLoading || isScanning || isWriting || isProjectUpdating || isSavingSettings || isSavingAIProvider || isTestingAIProvider || isApplyingBatchToggle || isExportingLocalReport || isTaskBenchmarkBusy || isLLMPromptBusy
    }

    private var isTaskBenchmarkBusy: Bool {
        isSavingTaskBenchmark || isEvaluatingTaskBenchmarks || isSavingRoutingBaseline || isDetectingRoutingRegression || isLoadingRoutingAccuracyDashboard || isLoadingTraceImports || isImportingTrace || !deletingTaskBenchmarkIDs.isEmpty || !deletingTraceImportIDs.isEmpty
    }

    private var isLLMPromptBusy: Bool {
        !previewingLLMPromptKeys.isEmpty
            || !sendingLLMPromptKeys.isEmpty
            || !scoringSkillQualityIDs.isEmpty
            || !checkingTaskReadinessSkillIDs.isEmpty
            || !rankingRoutingSkillIDs.isEmpty
    }

    private func toggleDisabledReason(for skill: SkillRecord) -> String? {
        if let catalogReason = DisplayText.catalogToggleDisabledReason(for: skill, isWriting: isWriting) {
            return catalogReason
        }
        guard !isWriting else {
            return UIStrings.toggleUnavailableBusy
        }
        guard let capability = adapterCapabilities.first(where: { $0.agent == skill.agent }) else {
            return DisplayText.isReadOnlyAdapter(skill.agent) ? UIStrings.toggleUnavailableReadOnlyAdapter(DisplayText.agent(skill.agent)) : nil
        }
        guard !capability.configToggle.supported else { return nil }
        return capability.configToggle.reason ?? UIStrings.readOnlyAdapterStatus(capability.displayName)
    }

    var selectedSkill: SkillRecord? {
        let visibleSkills = filteredSkills
        if let selectedSkillID {
            return visibleSkills.first { $0.id == selectedSkillID } ?? visibleSkills.first
        }
        return visibleSkills.first
    }

    var selectedSkillDetail: SkillDetailRecord? {
        guard let id = selectedSkill?.id else { return nil }
        return detailsByID[id]
    }

    var enabledCount: Int {
        skills.filter { DisplayText.statusKind($0.state, enabled: $0.enabled) == .enabled }.count
    }

    var activeProjectContext: ProjectContext? {
        projectContextState?.active
    }

    var recentProjectContexts: [ProjectContext] {
        projectContextState?.recent ?? []
    }

    var adapterCapabilities: [AdapterCapabilityRecord] {
        status?.adapterCapabilities ?? []
    }

    var selectedAdapterCapability: AdapterCapabilityRecord? {
        adapterCapabilities.first { $0.agent == agentFilter.rawValue }
    }

    var selectedAgentRefreshSummary: AgentRefreshSummary? {
        lastScanActivity?.agentSummaries?.first { $0.agent == agentFilter.rawValue }
    }

    var selectedAgentHealthSummary: AgentSkillHealthSummary? {
        healthSummary.agentSummaries.first { $0.agent == agentFilter.rawValue }
    }

    var selectedAgentConfigTimelineAgent: String? {
        switch agentFilter {
        case .all:
            return nil
        default:
            return agentFilter.rawValue
        }
    }

    var projectValidationMessage: String? {
        guard let message = activeProjectContext?.validationError, !message.isEmpty else {
            return nil
        }
        return message
    }

    var filteredSkills: [SkillRecord] {
        SkillListModel.filteredAndSorted(
            skills: skills,
            findings: findings,
            conflicts: conflicts,
            searchText: searchText,
            agentFilter: agentFilter,
            stateFilter: stateFilter,
            sortOrder: sortOrder
        )
    }

    var filteredSkillGroups: [SkillAgentGroup] {
        SkillListModel.groupedByAgent(filteredSkills)
    }

    var batchToggleSelectedSkills: [SkillRecord] {
        filteredSkills
    }

    var canApplyBatchTogglePreview: Bool {
        guard let preview = batchTogglePreview else { return false }
        return !isRefreshBusy && preview.applySupported && preview.hasWritableChanges
    }

    var filteredCleanupQueueItems: [CleanupQueueItem] {
        CleanupQueueModel.filtered(
            items: cleanupQueue.items,
            kindFilter: cleanupKindFilter,
            priorityFilter: cleanupPriorityFilter,
            agentFilter: agentFilter
        )
    }

    var selectedFindings: [RuleFindingRecord] {
        guard let skill = selectedSkill else { return [] }
        return findings.filter { finding in
            finding.instanceId == skill.id
        }
    }

    var selectedCrossAgentComparisonGroup: CrossAgentComparisonGroup? {
        guard let skill = selectedSkill else { return nil }
        return crossAgentComparisons.group(for: skill)
    }

    func ruleTuningRecord(ruleId: String, findingGroupID: String? = nil) -> RuleTuningRecord? {
        RuleTuningModel.record(in: ruleTuning, ruleId: ruleId, findingGroupId: findingGroupID)
    }

    func setFindingTriageStatus(_ status: FindingTriageStatus, for triageKeys: [String]) {
        let keys = Array(Set(triageKeys.filter { !$0.isEmpty })).sorted()
        guard !keys.isEmpty else { return }
        Task {
            await setFindingTriageStatus(status, triageKeys: keys)
        }
    }

    func setRuleSeverityOverride(_ severity: String, for ruleId: String) {
        Task {
            await setRuleSeverityOverride(severity, ruleId: ruleId)
        }
    }

    func clearRuleSeverityOverride(for ruleId: String) {
        Task {
            await clearRuleSeverityOverride(ruleId: ruleId)
        }
    }

    func setRuleSuppression(ruleId: String, findingGroupID: String?, scope: RuleTuningScope) {
        Task {
            await setRuleSuppression(ruleId: ruleId, findingGroupID: findingGroupID, scope: scope)
        }
    }

    func clearRuleSuppression(ruleId: String, findingGroupID: String?, scope: RuleTuningScope) {
        Task {
            await clearRuleSuppression(ruleId: ruleId, findingGroupID: findingGroupID, scope: scope)
        }
    }

    func openCleanupQueueItem(_ item: CleanupQueueItem) {
        if let skillID = item.skillID, skills.contains(where: { $0.id == skillID }) {
            selectedSkillID = skillID
        }
        switch item.kind {
        case .finding, .integrity:
            selectedDetailSection = .findings
        case .conflict:
            selectedDetailSection = .conflicts
        case .analysis:
            selectedDetailSection = .analysis
        case .unknown:
            selectedDetailSection = .overview
        }
    }

    var selectedConflicts: [ConflictGroupRecord] {
        guard let skill = selectedSkill else { return [] }
        let sameAgentSkillIDs = Set(skills.filter { $0.agent == skill.agent }.map(\.id))
        return conflicts.filter { conflict in
            conflict.instanceIds.contains(skill.id)
                && conflict.instanceIds.filter { sameAgentSkillIDs.contains($0) }.count > 1
        }
    }

    var sameAgentRuntimeConflictCount: Int {
        SkillListModel.sameAgentConflictGroupCount(skills: skills, conflicts: conflicts)
    }

    var selectedSkillEvents: [SkillEventRecord] {
        guard let id = selectedSkill?.id else { return [] }
        return (skillEventsByID[id] ?? []).filter(\.isToggleActivity)
    }

    var isLoadingSelectedSkillEvents: Bool {
        guard let id = selectedSkill?.id else { return false }
        return loadingSkillEventIDs.contains(id)
    }

    func llmPrepareResult(for action: LLMAction) -> LLMPrepareResult? {
        guard llmPreparedSkillID == selectedSkillID else { return nil }
        return llmPrepareResults[action]
    }

    func isPreparingLLMAction(_ action: LLMAction) -> Bool {
        preparingLLMActions.contains(action)
    }

    func skillAnalysisPrepareResult(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> LLMSkillAnalysisPrepareResult? {
        skillAnalysisPrepareResults[skillAnalysisKey(kind: kind, scope: scope)]
    }

    func isPreparingSkillAnalysis(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> Bool {
        preparingSkillAnalysisKeys.contains(skillAnalysisKey(kind: kind, scope: scope))
    }

    func llmPromptPreview(for action: LLMAction) -> LLMPromptPreview? {
        guard let skill = selectedSkill else { return nil }
        return llmPromptPreviews[llmPromptActionKey(action: action, skillID: skill.id)]
    }

    func isPreviewingLLMPrompt(for action: LLMAction) -> Bool {
        guard let skill = selectedSkill else { return false }
        return previewingLLMPromptKeys.contains(llmPromptActionKey(action: action, skillID: skill.id))
    }

    func isSendingLLMPrompt(for action: LLMAction) -> Bool {
        guard let skill = selectedSkill else { return false }
        return sendingLLMPromptKeys.contains(llmPromptActionKey(action: action, skillID: skill.id))
    }

    func llmPromptSendResult(for action: LLMAction) -> LLMPromptSendResult? {
        guard let skill = selectedSkill else { return nil }
        return llmPromptSendResults[llmPromptActionKey(action: action, skillID: skill.id)]
    }

    func canSendLLMPrompt(for action: LLMAction) -> Bool {
        guard let preview = llmPromptPreview(for: action) else { return false }
        return canSendLLMPrompt(preview)
    }

    func skillAnalysisPromptPreview(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> LLMPromptPreview? {
        let instanceIDs = skillAnalysisInstanceIDs(scope: scope)
        guard !instanceIDs.isEmpty else { return nil }
        return llmPromptPreviews[skillAnalysisPromptKey(kind: kind, scope: scope, instanceIDs: instanceIDs)]
    }

    func isPreviewingSkillAnalysisPrompt(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> Bool {
        let instanceIDs = skillAnalysisInstanceIDs(scope: scope)
        guard !instanceIDs.isEmpty else { return false }
        return previewingLLMPromptKeys.contains(skillAnalysisPromptKey(kind: kind, scope: scope, instanceIDs: instanceIDs))
    }

    func isSendingSkillAnalysisPrompt(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> Bool {
        let instanceIDs = skillAnalysisInstanceIDs(scope: scope)
        guard !instanceIDs.isEmpty else { return false }
        return sendingLLMPromptKeys.contains(skillAnalysisPromptKey(kind: kind, scope: scope, instanceIDs: instanceIDs))
    }

    func skillAnalysisPromptSendResult(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> LLMPromptSendResult? {
        let instanceIDs = skillAnalysisInstanceIDs(scope: scope)
        guard !instanceIDs.isEmpty else { return nil }
        return llmPromptSendResults[skillAnalysisPromptKey(kind: kind, scope: scope, instanceIDs: instanceIDs)]
    }

    func canSendSkillAnalysisPrompt(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> Bool {
        guard let preview = skillAnalysisPromptPreview(kind: kind, scope: scope) else { return false }
        return canSendLLMPrompt(preview)
    }

    func skillQualityScore(for skill: SkillRecord) -> SkillQualityScoreResult? {
        skillQualityScores[skill.id]
    }

    func isScoringSkillQuality(for skill: SkillRecord) -> Bool {
        scoringSkillQualityIDs.contains(skill.id)
    }

    func skillQualityPromptPreview(for skill: SkillRecord) -> LLMPromptPreview? {
        llmPromptPreviews[skillQualityPromptKey(skillID: skill.id)]
    }

    func isPreviewingSkillQualityPrompt(for skill: SkillRecord) -> Bool {
        previewingLLMPromptKeys.contains(skillQualityPromptKey(skillID: skill.id))
    }

    func isSendingSkillQualityPrompt(for skill: SkillRecord) -> Bool {
        sendingLLMPromptKeys.contains(skillQualityPromptKey(skillID: skill.id))
    }

    func skillQualityPromptSendResult(for skill: SkillRecord) -> LLMPromptSendResult? {
        llmPromptSendResults[skillQualityPromptKey(skillID: skill.id)]
    }

    func canSendSkillQualityPrompt(for skill: SkillRecord) -> Bool {
        guard let preview = skillQualityPromptPreview(for: skill) else { return false }
        return canSendLLMPrompt(preview)
    }

    func taskReadiness(for skill: SkillRecord) -> TaskReadinessResult? {
        guard taskReadinessCheckedSkillID == skill.id else { return nil }
        return taskReadinessResult
    }

    func isCheckingTaskReadiness(for skill: SkillRecord) -> Bool {
        checkingTaskReadinessSkillIDs.contains(skill.id)
    }

    func taskReadinessPromptPreview(for skill: SkillRecord) -> LLMPromptPreview? {
        let taskText = normalizedTaskReadinessText
        guard !taskText.isEmpty else { return nil }
        return llmPromptPreviews[taskReadinessPromptKey(skillID: skill.id, taskText: taskText)]
    }

    func isPreviewingTaskReadinessPrompt(for skill: SkillRecord) -> Bool {
        let taskText = normalizedTaskReadinessText
        guard !taskText.isEmpty else { return false }
        return previewingLLMPromptKeys.contains(taskReadinessPromptKey(skillID: skill.id, taskText: taskText))
    }

    func isSendingTaskReadinessPrompt(for skill: SkillRecord) -> Bool {
        let taskText = normalizedTaskReadinessText
        guard !taskText.isEmpty else { return false }
        return sendingLLMPromptKeys.contains(taskReadinessPromptKey(skillID: skill.id, taskText: taskText))
    }

    func taskReadinessPromptSendResult(for skill: SkillRecord) -> LLMPromptSendResult? {
        let taskText = normalizedTaskReadinessText
        guard !taskText.isEmpty else { return nil }
        return llmPromptSendResults[taskReadinessPromptKey(skillID: skill.id, taskText: taskText)]
    }

    func canSendTaskReadinessPrompt(for skill: SkillRecord) -> Bool {
        guard let preview = taskReadinessPromptPreview(for: skill) else { return false }
        return canSendLLMPrompt(preview)
    }

    func routingConfidence(for skill: SkillRecord) -> SkillRoutingConfidenceResult? {
        guard routingConfidenceRankedSkillID == skill.id else { return nil }
        return routingConfidenceResult
    }

    func isRankingRoutingConfidence(for skill: SkillRecord) -> Bool {
        rankingRoutingSkillIDs.contains(skill.id)
    }

    func routingConfidencePromptPreview(for skill: SkillRecord) -> LLMPromptPreview? {
        let taskText = normalizedRoutingConfidenceText
        guard !taskText.isEmpty else { return nil }
        return llmPromptPreviews[routingConfidencePromptKey(skillID: skill.id, taskText: taskText)]
    }

    func isPreviewingRoutingConfidencePrompt(for skill: SkillRecord) -> Bool {
        let taskText = normalizedRoutingConfidenceText
        guard !taskText.isEmpty else { return false }
        return previewingLLMPromptKeys.contains(routingConfidencePromptKey(skillID: skill.id, taskText: taskText))
    }

    func isSendingRoutingConfidencePrompt(for skill: SkillRecord) -> Bool {
        let taskText = normalizedRoutingConfidenceText
        guard !taskText.isEmpty else { return false }
        return sendingLLMPromptKeys.contains(routingConfidencePromptKey(skillID: skill.id, taskText: taskText))
    }

    func routingConfidencePromptSendResult(for skill: SkillRecord) -> LLMPromptSendResult? {
        let taskText = normalizedRoutingConfidenceText
        guard !taskText.isEmpty else { return nil }
        return llmPromptSendResults[routingConfidencePromptKey(skillID: skill.id, taskText: taskText)]
    }

    func canSendRoutingConfidencePrompt(for skill: SkillRecord) -> Bool {
        guard let preview = routingConfidencePromptPreview(for: skill) else { return false }
        return canSendLLMPrompt(preview)
    }

    var selectedTaskBenchmarkInput: String {
        let trimmedBenchmark = normalizedTaskBenchmarkText
        if !trimmedBenchmark.isEmpty {
            return trimmedBenchmark
        }
        let trimmedRouting = normalizedRoutingConfidenceText
        if !trimmedRouting.isEmpty {
            return trimmedRouting
        }
        return normalizedTaskReadinessText
    }

    func isDeletingTaskBenchmark(_ benchmark: TaskBenchmarkRecord) -> Bool {
        deletingTaskBenchmarkIDs.contains(benchmark.id)
    }

    var latestTraceImportRecord: AgentTraceImportRecord? {
        traceImportResult?.record ?? traceImportList.imports.first
    }

    func isDeletingTraceImport(_ record: AgentTraceImportRecord) -> Bool {
        deletingTraceImportIDs.contains(record.id)
    }

    func scriptExecutionPreview(for skill: SkillRecord) -> ScriptExecutionPreview? {
        scriptExecutionPreviews[skill.id]
    }

    func isPreviewingScriptExecution(for skill: SkillRecord) -> Bool {
        previewingScriptExecutionSkillIDs.contains(skill.id)
    }

    func reload() async {
        guard !isRefreshBusy else { return }
        isLoading = true
        errorMessage = nil
        beginRefresh(.reload, message: UIStrings.refreshReloading)
        defer { isLoading = false }

        do {
            try await refreshCollections()
            await loadCleanupQueue()
            await loadCrossAgentComparisons()
            refreshStatusMessage = UIStrings.refreshReloaded(skills.count, findings.count, sameAgentRuntimeConflictCount)
            appendRefreshLog(level: "info", message: refreshStatusMessage)
            canRetryLastRefresh = false
            await loadSelectedDetail()
        } catch {
            handleRefreshFailure(error, action: .reload)
        }
    }

    func scanAll() async {
        await scanAll(allowDuringProjectUpdate: false)
    }

    private func scanAll(allowDuringProjectUpdate: Bool) async {
        guard canStartScan(allowDuringProjectUpdate: allowDuringProjectUpdate) else { return }
        isScanning = true
        errorMessage = nil
        lastMutationMessage = nil
        beginRefresh(.scan, message: UIStrings.refreshScanning)
        defer { isScanning = false }

        do {
            let result = try await service.scanAll()
            detailsByID.removeAll()
            try await refreshCollections()
            await loadCleanupQueue()
            await loadCrossAgentComparisons()
            lastMutationMessage = UIStrings.scannedSkills(result.scannedCount)
            applyRefreshActivity(result.activity)
            await loadSelectedDetail()
        } catch {
            handleRefreshFailure(error, action: .scan)
        }
    }

    func setProject(rootPath: String, currentCWD: String? = nil, name: String? = nil) async {
        guard !isRefreshBusy else { return }
        isProjectUpdating = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isProjectUpdating = false }

        do {
            let resolvedName = name ?? URL(fileURLWithPath: rootPath).lastPathComponent
            let state = try await service.setProjectContext(
                rootPath: rootPath,
                currentCWD: currentCWD ?? rootPath,
                name: resolvedName.isEmpty ? nil : resolvedName
            )
            projectContextState = state
            detailsByID.removeAll()

            if let validationMessage = projectValidationMessage {
                errorMessage = UIStrings.projectValidationFailed(validationMessage)
                refreshStatusMessage = UIStrings.projectScanSkippedValidation
                appendRefreshLog(level: "error", message: refreshStatusMessage)
                return
            }

            await scanAll(allowDuringProjectUpdate: true)
            if errorMessage == nil {
                lastMutationMessage = UIStrings.projectSelectedAndScanned(activeProjectContext?.name ?? resolvedName)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearProject() async {
        guard !isRefreshBusy else { return }
        isProjectUpdating = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isProjectUpdating = false }

        do {
            projectContextState = try await service.clearProjectContext()
            detailsByID.removeAll()
            await scanAll(allowDuringProjectUpdate: true)
            if errorMessage == nil {
                lastMutationMessage = UIStrings.projectClearedAndScanned
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retryLastRefresh() async {
        switch lastRefreshAction {
        case .reload:
            await reload()
        case .scan:
            await scanAll()
        }
    }

    func toggleSelectedSkill(on: Bool) async {
        guard !isLoading, !isScanning, !isProjectUpdating, !isSavingSettings else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }
        guard let skill = selectedSkill else { return }
        if let disabledReason = toggleDisabledReason(for: skill) {
            errorMessage = disabledReason
            lastMutationMessage = nil
            return
        }

        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            _ = try await service.toggleSkill(instanceID: skill.id, on: on)
            detailsByID.removeValue(forKey: skill.id)
            skillEventsByID.removeValue(forKey: skill.id)
            try await refreshCollections()
            lastMutationMessage = UIStrings.toggledSkill(on: on, name: skill.name, agent: skill.agent)
            recordLocalRefresh(message: UIStrings.refreshAfterWrite)
            await loadSelectedDetail()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previewVisibleBatchToggle() async {
        let selectedSkills = batchToggleSelectedSkills
        guard !selectedSkills.isEmpty else {
            batchTogglePreview = nil
            return
        }
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            return
        }

        isPreviewingBatchToggle = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isPreviewingBatchToggle = false }

        do {
            batchTogglePreview = try await service.previewBatchSkillToggles(
                instanceIDs: selectedSkills.map(\.id),
                on: batchToggleAction.targetEnabled
            )
        } catch ServiceClient.ClientError.service(let error) where error.code == "unknown_method" {
            batchTogglePreview = localBatchTogglePreview(selectedSkills: selectedSkills, reason: UIStrings.batchToggleServicePreviewUnavailable)
        } catch {
            errorMessage = error.localizedDescription
            batchTogglePreview = nil
        }
    }

    func applyVisibleBatchTogglePreview(confirmingPreviewID: String? = nil) async {
        guard let preview = batchTogglePreview else { return }
        if let confirmingPreviewID, confirmingPreviewID != preview.id {
            errorMessage = UIStrings.batchTogglePreviewChanged
            lastMutationMessage = nil
            return
        }
        guard preview.applySupported else {
            errorMessage = UIStrings.batchToggleApplyUnavailable
            lastMutationMessage = nil
            return
        }
        guard preview.hasWritableChanges else {
            errorMessage = UIStrings.batchToggleNoWritableChanges
            lastMutationMessage = nil
            return
        }
        guard !isLoading, !isScanning, !isProjectUpdating, !isSavingSettings, !isWriting else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }

        isApplyingBatchToggle = true
        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer {
            isWriting = false
            isApplyingBatchToggle = false
        }

        do {
            let result = try await service.applyBatchSkillToggles(preview: preview)
            for item in preview.affectedSkills {
                detailsByID.removeValue(forKey: item.instanceID)
                skillEventsByID.removeValue(forKey: item.instanceID)
            }
            try await refreshCollections()
            await loadCleanupQueue()
            await loadCrossAgentComparisons()
            lastMutationMessage = UIStrings.batchToggleApplied(
                action: preview.action.title,
                count: result.updatedCount == 0 ? preview.writableCount : result.updatedCount
            )
            recordLocalRefresh(message: UIStrings.refreshAfterWrite)
            batchTogglePreview = nil
            await loadSelectedDetail()
        } catch {
            errorMessage = error.localizedDescription
            lastMutationMessage = nil
        }
    }

    func exportLocalReport() async {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }

        isExportingLocalReport = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isExportingLocalReport = false }

        let agent = agentFilter == .all ? nil : agentFilter.rawValue
        let state = stateFilter == .all ? nil : stateFilter.rawValue
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await service.exportLocalReport(
                format: localReportFormat,
                agent: agent,
                instanceID: selectedSkill?.id,
                stateFilter: state,
                search: trimmedSearch.isEmpty ? nil : trimmedSearch
            )
            localReportExportResult = result
            if result.isUnavailable {
                lastMutationMessage = nil
            } else {
                lastMutationMessage = UIStrings.localReportExported(result.displayName)
            }
        } catch {
            localReportExportResult = .unavailable(reason: UIStrings.localReportUnavailableFallback, format: localReportFormat)
            errorMessage = error.localizedDescription
            lastMutationMessage = nil
        }
    }

    func previewToolInstall(skill: SkillRecord, target: ToolInstallTarget) async -> ToolGlobalInstallPreview? {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            return nil
        }
        errorMessage = nil
        do {
            return try await service.previewToolInstall(skill: skill, target: target)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func confirmToolInstall(skill: SkillRecord, target: ToolInstallTarget) async -> ToolGlobalInstallPreview? {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            return nil
        }
        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            let result = try await service.confirmToolInstall(skill: skill, target: target)
            detailsByID.removeAll()
            try await refreshCollections()
            lastMutationMessage = UIStrings.toolGlobalInstalled(skill.name, target.title)
            recordLocalRefresh(message: UIStrings.refreshAfterWrite)
            await loadSelectedDetail()
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func setFindingTriageStatus(_ status: FindingTriageStatus, triageKeys: [String]) async {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }

        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            for triageKey in triageKeys {
                if status == .open {
                    _ = try await service.clearFindingTriage(triageKey: triageKey)
                    applyFindingTriage(status: .open, triageKeys: [triageKey], note: nil, updatedAt: nil)
                } else {
                    let record = try await service.setFindingTriage(triageKey: triageKey, status: status)
                    applyFindingTriage(record)
                }
            }
            lastMutationMessage = status == .open
                ? UIStrings.findingTriageReopened
                : UIStrings.findingTriageUpdated(status.title)
        } catch {
            errorMessage = error.localizedDescription
            lastMutationMessage = nil
        }
    }

    private func applyFindingTriage(_ record: FindingTriageRecord) {
        applyFindingTriage(
            status: record.triageStatus,
            triageKeys: [record.triageKey],
            note: record.note,
            updatedAt: record.updatedAt
        )
    }

    private func applyFindingTriage(status: FindingTriageStatus, triageKeys: [String], note: String?, updatedAt: Int64?) {
        let keys = Set(triageKeys)
        findings = findings.map { finding in
            guard keys.contains(finding.triageKey) else { return finding }
            return finding.withTriage(status: status, note: note, updatedAt: updatedAt)
        }
    }

    private func setRuleSeverityOverride(_ severity: String, ruleId: String) async {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }

        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            _ = try await service.setSeverityOverride(ruleId: ruleId, severity: severity)
            ruleTuning = try await service.listRuleTuning()
            lastMutationMessage = UIStrings.ruleTuningSeverityUpdated(FindingDisplayModel.severityTitle(severity))
        } catch {
            errorMessage = error.localizedDescription
            lastMutationMessage = nil
        }
    }

    private func clearRuleSeverityOverride(ruleId: String) async {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }

        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            _ = try await service.clearSeverityOverride(ruleId: ruleId)
            ruleTuning = try await service.listRuleTuning()
            lastMutationMessage = UIStrings.ruleTuningSeverityCleared
        } catch {
            errorMessage = error.localizedDescription
            lastMutationMessage = nil
        }
    }

    private func setRuleSuppression(ruleId: String, findingGroupID: String?, scope: RuleTuningScope) async {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }

        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            _ = try await service.setSuppression(ruleId: ruleId, scope: scope, findingGroupId: findingGroupID)
            ruleTuning = try await service.listRuleTuning()
            lastMutationMessage = UIStrings.ruleTuningSuppressionUpdated
        } catch {
            errorMessage = error.localizedDescription
            lastMutationMessage = nil
        }
    }

    private func clearRuleSuppression(ruleId: String, findingGroupID: String?, scope: RuleTuningScope) async {
        guard !isRefreshBusy else {
            errorMessage = UIStrings.operationUnavailableBusy
            lastMutationMessage = nil
            return
        }

        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            _ = try await service.clearSuppression(ruleId: ruleId, scope: scope, findingGroupId: findingGroupID)
            ruleTuning = try await service.listRuleTuning()
            lastMutationMessage = UIStrings.ruleTuningSuppressionCleared
        } catch {
            errorMessage = error.localizedDescription
            lastMutationMessage = nil
        }
    }

    func prepareAnalyzeLLM() async {
        await prepareLLMAction(.analyze)
    }

    func prepareRecommendLLM() async {
        await prepareLLMAction(.recommend)
    }

    func prepareExplainConflictLLM() async {
        await prepareLLMAction(.explainConflict)
    }

    func prepareDraftFrontmatterLLM() async {
        await prepareLLMAction(.draftFrontmatter)
    }

    func prepareSelectedSkillAnalysis(kind: LLMSkillAnalysisKind) async {
        guard let skill = selectedSkill else { return }
        await prepareSkillAnalysis(kind: kind, scope: .selected, instanceIDs: [skill.id])
    }

    func prepareVisibleSkillAnalysis(kind: LLMSkillAnalysisKind) async {
        let instanceIDs = filteredSkills.map(\.id)
        guard !instanceIDs.isEmpty else { return }
        await prepareSkillAnalysis(kind: kind, scope: .visible, instanceIDs: instanceIDs)
    }

    func previewPromptForSelectedLLMAction(_ action: LLMAction) async {
        guard let skill = selectedSkill else { return }
        let key = llmPromptActionKey(action: action, skillID: skill.id)
        guard !isRefreshBusy else {
            llmPromptPreviews[key] = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        previewingLLMPromptKeys.insert(key)
        llmPromptSendResults.removeValue(forKey: key)
        defer { previewingLLMPromptKeys.remove(key) }

        do {
            llmPromptPreviews[key] = try await service.previewPromptForLLMAction(action: action, skill: skill)
        } catch {
            llmPromptPreviews[key] = .unavailable(reason: error.localizedDescription)
        }
    }

    func confirmPromptForSelectedLLMAction(_ action: LLMAction) async {
        guard let skill = selectedSkill else { return }
        let key = llmPromptActionKey(action: action, skillID: skill.id)
        await confirmLLMPrompt(key: key) { previewID in
            try await service.confirmPromptAndSendForLLMAction(
                previewID: previewID,
                action: action,
                skill: skill
            )
        }
    }

    func previewPromptForSkillAnalysis(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) async {
        let instanceIDs = skillAnalysisInstanceIDs(scope: scope)
        guard !instanceIDs.isEmpty else { return }
        let key = skillAnalysisPromptKey(kind: kind, scope: scope, instanceIDs: instanceIDs)
        guard !isRefreshBusy else {
            llmPromptPreviews[key] = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        previewingLLMPromptKeys.insert(key)
        llmPromptSendResults.removeValue(forKey: key)
        defer { previewingLLMPromptKeys.remove(key) }

        do {
            llmPromptPreviews[key] = try await service.previewPromptForSkillAnalysis(
                instanceIDs: instanceIDs,
                kind: kind,
                scope: scope
            )
        } catch {
            llmPromptPreviews[key] = .unavailable(reason: error.localizedDescription)
        }
    }

    func confirmPromptForSkillAnalysis(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) async {
        let instanceIDs = skillAnalysisInstanceIDs(scope: scope)
        guard !instanceIDs.isEmpty else { return }
        let key = skillAnalysisPromptKey(kind: kind, scope: scope, instanceIDs: instanceIDs)
        await confirmLLMPrompt(key: key) { previewID in
            try await service.confirmPromptAndSendForSkillAnalysis(
                previewID: previewID,
                instanceIDs: instanceIDs,
                kind: kind,
                scope: scope
            )
        }
    }

    func scoreSelectedSkillQuality() async {
        guard let skill = selectedSkill else { return }
        await scoreSkillQuality(for: skill)
    }

    func previewPromptForSelectedSkillQuality() async {
        guard let skill = selectedSkill else { return }
        let key = skillQualityPromptKey(skillID: skill.id)
        guard !isRefreshBusy else {
            llmPromptPreviews[key] = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        previewingLLMPromptKeys.insert(key)
        llmPromptSendResults.removeValue(forKey: key)
        defer { previewingLLMPromptKeys.remove(key) }

        do {
            llmPromptPreviews[key] = try await service.previewPromptForSkillQuality(skill: skill)
        } catch {
            llmPromptPreviews[key] = .unavailable(reason: error.localizedDescription)
        }
    }

    func confirmPromptForSelectedSkillQuality() async {
        guard let skill = selectedSkill else { return }
        let key = skillQualityPromptKey(skillID: skill.id)
        await confirmLLMPrompt(key: key) { previewID in
            try await service.confirmPromptAndSendForSkillQuality(previewID: previewID, skill: skill)
        }
    }

    func checkSelectedTaskReadiness() async {
        guard let skill = selectedSkill else { return }
        let taskText = normalizedTaskReadinessText
        guard !taskText.isEmpty else {
            taskReadinessResult = .unavailable(taskText: "", reason: UIStrings.taskReadinessTaskRequired)
            taskReadinessCheckedSkillID = skill.id
            return
        }
        guard !isRefreshBusy else {
            taskReadinessResult = .unavailable(taskText: taskText, reason: UIStrings.operationUnavailableBusy)
            taskReadinessCheckedSkillID = skill.id
            return
        }

        checkingTaskReadinessSkillIDs.insert(skill.id)
        defer { checkingTaskReadinessSkillIDs.remove(skill.id) }

        do {
            taskReadinessResult = try await service.checkTaskReadiness(taskText: taskText, skill: skill)
            taskReadinessCheckedSkillID = skill.id
        } catch {
            taskReadinessResult = .unavailable(taskText: taskText, reason: error.localizedDescription)
            taskReadinessCheckedSkillID = skill.id
        }
    }

    func previewPromptForSelectedTaskReadiness() async {
        guard let skill = selectedSkill else { return }
        let taskText = normalizedTaskReadinessText
        guard !taskText.isEmpty else {
            taskReadinessResult = .unavailable(taskText: "", reason: UIStrings.taskReadinessTaskRequired)
            taskReadinessCheckedSkillID = skill.id
            return
        }
        let key = taskReadinessPromptKey(skillID: skill.id, taskText: taskText)
        guard !isRefreshBusy else {
            llmPromptPreviews[key] = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        previewingLLMPromptKeys.insert(key)
        llmPromptSendResults.removeValue(forKey: key)
        defer { previewingLLMPromptKeys.remove(key) }

        do {
            llmPromptPreviews[key] = try await service.previewPromptForTaskReadiness(taskText: taskText, skill: skill)
        } catch {
            llmPromptPreviews[key] = .unavailable(reason: error.localizedDescription)
        }
    }

    func confirmPromptForSelectedTaskReadiness() async {
        guard let skill = selectedSkill else { return }
        let taskText = normalizedTaskReadinessText
        guard !taskText.isEmpty else { return }
        let key = taskReadinessPromptKey(skillID: skill.id, taskText: taskText)
        await confirmLLMPrompt(key: key) { previewID in
            try await service.confirmPromptAndSendForTaskReadiness(
                previewID: previewID,
                taskText: taskText,
                skill: skill
            )
        }
    }

    func rankSelectedSkillRoutes() async {
        guard let skill = selectedSkill else { return }
        let taskText = normalizedRoutingConfidenceText
        guard !taskText.isEmpty else {
            routingConfidenceResult = .unavailable(taskText: "", reason: UIStrings.routingConfidenceTaskRequired)
            routingConfidenceRankedSkillID = skill.id
            return
        }
        guard !isRefreshBusy else {
            routingConfidenceResult = .unavailable(taskText: taskText, reason: UIStrings.operationUnavailableBusy)
            routingConfidenceRankedSkillID = skill.id
            return
        }

        rankingRoutingSkillIDs.insert(skill.id)
        defer { rankingRoutingSkillIDs.remove(skill.id) }

        do {
            routingConfidenceResult = try await service.rankSkillRoutes(taskText: taskText, skill: skill)
            routingConfidenceRankedSkillID = skill.id
        } catch {
            routingConfidenceResult = .unavailable(taskText: taskText, reason: error.localizedDescription)
            routingConfidenceRankedSkillID = skill.id
        }
    }

    func previewPromptForSelectedRoutingConfidence() async {
        guard let skill = selectedSkill else { return }
        let taskText = normalizedRoutingConfidenceText
        guard !taskText.isEmpty else {
            routingConfidenceResult = .unavailable(taskText: "", reason: UIStrings.routingConfidenceTaskRequired)
            routingConfidenceRankedSkillID = skill.id
            return
        }
        let key = routingConfidencePromptKey(skillID: skill.id, taskText: taskText)
        guard !isRefreshBusy else {
            llmPromptPreviews[key] = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        previewingLLMPromptKeys.insert(key)
        llmPromptSendResults.removeValue(forKey: key)
        defer { previewingLLMPromptKeys.remove(key) }

        do {
            llmPromptPreviews[key] = try await service.previewPromptForRoutingConfidence(taskText: taskText, skill: skill)
        } catch {
            llmPromptPreviews[key] = .unavailable(reason: error.localizedDescription)
        }
    }

    func confirmPromptForSelectedRoutingConfidence() async {
        guard let skill = selectedSkill else { return }
        let taskText = normalizedRoutingConfidenceText
        guard !taskText.isEmpty else { return }
        let key = routingConfidencePromptKey(skillID: skill.id, taskText: taskText)
        await confirmLLMPrompt(key: key) { previewID in
            try await service.confirmPromptAndSendForRoutingConfidence(
                previewID: previewID,
                taskText: taskText,
                skill: skill
            )
        }
    }

    func loadTaskBenchmarks() async {
        guard !isLoadingTaskBenchmarks else { return }
        isLoadingTaskBenchmarks = true
        defer { isLoadingTaskBenchmarks = false }

        do {
            taskBenchmarkList = try await service.listTaskBenchmarks(skill: selectedSkill)
        } catch {
            taskBenchmarkList = .unavailable(reason: error.localizedDescription)
        }
    }

    func saveSelectedTaskBenchmark() async {
        guard let skill = selectedSkill else { return }
        let taskText = selectedTaskBenchmarkInput
        guard !taskText.isEmpty else {
            taskBenchmarkEvaluation = .unavailable(reason: UIStrings.taskBenchmarkTaskRequired)
            return
        }
        guard !isRefreshBusy else {
            taskBenchmarkEvaluation = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        isSavingTaskBenchmark = true
        defer { isSavingTaskBenchmark = false }

        do {
            let result = try await service.saveTaskBenchmark(taskText: taskText, skill: skill)
            if let benchmark = result.benchmark {
                upsertTaskBenchmark(benchmark)
                taskBenchmarkDeleteResult = nil
                routingRegressionBaseline = nil
                routingRegressionDetection = nil
            } else if let reason = result.fallbackReason {
                taskBenchmarkList = .unavailable(reason: reason)
            }
        } catch {
            taskBenchmarkList = .unavailable(reason: error.localizedDescription)
        }
    }

    func evaluateTaskBenchmarks() async {
        guard !isRefreshBusy else {
            taskBenchmarkEvaluation = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        isEvaluatingTaskBenchmarks = true
        defer { isEvaluatingTaskBenchmarks = false }

        do {
            taskBenchmarkEvaluation = try await service.evaluateTaskBenchmarks(
                skill: selectedSkill,
                benchmarkIDs: taskBenchmarkList.benchmarks.isEmpty ? nil : taskBenchmarkList.benchmarks.map(\.id)
            )
        } catch {
            taskBenchmarkEvaluation = .unavailable(reason: error.localizedDescription)
        }
    }

    func saveRoutingBaseline() async {
        guard !isRefreshBusy else {
            routingRegressionBaseline = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        isSavingRoutingBaseline = true
        defer { isSavingRoutingBaseline = false }

        do {
            routingRegressionBaseline = try await service.saveRoutingBaseline(
                skill: selectedSkill,
                benchmarkIDs: taskBenchmarkList.benchmarks.isEmpty ? nil : taskBenchmarkList.benchmarks.map(\.id)
            )
            routingRegressionDetection = nil
        } catch {
            routingRegressionBaseline = .unavailable(reason: error.localizedDescription)
        }
    }

    func detectRoutingRegression() async {
        guard !isRefreshBusy else {
            routingRegressionDetection = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        isDetectingRoutingRegression = true
        defer { isDetectingRoutingRegression = false }

        do {
            routingRegressionDetection = try await service.detectRoutingRegression(
                skill: selectedSkill,
                benchmarkIDs: taskBenchmarkList.benchmarks.isEmpty ? nil : taskBenchmarkList.benchmarks.map(\.id)
            )
        } catch {
            routingRegressionDetection = .unavailable(reason: error.localizedDescription)
        }
    }

    func loadRoutingAccuracyDashboard() async {
        guard !isLoadingRoutingAccuracyDashboard else { return }
        guard !isRefreshBusy else {
            routingAccuracyDashboard = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        isLoadingRoutingAccuracyDashboard = true
        defer { isLoadingRoutingAccuracyDashboard = false }

        let agent = agentFilter == .all ? nil : agentFilter.rawValue
        do {
            routingAccuracyDashboard = try await service.routingAccuracyDashboard(
                agent: agent,
                windowDays: 30,
                limit: 20,
                includeHistory: true,
                includeRecentEvidence: true
            )
        } catch {
            routingAccuracyDashboard = .unavailable(reason: error.localizedDescription)
        }
    }

    func loadTraceImports() async {
        guard !isLoadingTraceImports else { return }
        isLoadingTraceImports = true
        defer { isLoadingTraceImports = false }

        do {
            traceImportList = try await service.listTraceImports()
        } catch {
            traceImportList = .unavailable(reason: error.localizedDescription)
        }
    }

    func importLocalTrace() async {
        let traceText = normalizedTraceImportText
        guard !traceText.isEmpty else {
            traceImportResult = .unavailable(reason: UIStrings.traceImportInputRequired)
            return
        }
        guard !isRefreshBusy else {
            traceImportResult = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        isImportingTrace = true
        defer { isImportingTrace = false }

        do {
            let result = try await service.importLocalTrace(
                traceText: traceText,
                title: normalizedOptional(traceImportTitle),
                taskText: normalizedOptional(traceImportTask),
                expectedSkillNames: normalizedTraceExpectedSkillNames,
                skill: selectedSkill
            )
            traceImportResult = result
            if let record = result.record {
                upsertTraceImport(record)
                traceImportDeleteResult = nil
                traceImportText = ""
            } else if let reason = result.fallbackReason {
                traceImportList = .unavailable(reason: reason)
            }
        } catch {
            traceImportResult = .unavailable(reason: error.localizedDescription)
        }
    }

    func deleteTraceImport(_ record: AgentTraceImportRecord) async {
        guard !isRefreshBusy else {
            traceImportDeleteResult = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        deletingTraceImportIDs.insert(record.id)
        defer { deletingTraceImportIDs.remove(record.id) }

        do {
            let result = try await service.deleteTraceImport(importID: record.id)
            traceImportDeleteResult = result
            guard result.deleted else { return }
            traceImportList = AgentTraceImportListResult(
                imports: traceImportList.imports.filter { $0.id != record.id },
                fallbackReason: traceImportList.fallbackReason
            )
            if traceImportResult?.record?.id == record.id {
                traceImportResult = nil
            }
        } catch {
            traceImportDeleteResult = .unavailable(reason: error.localizedDescription)
        }
    }

    func deleteTaskBenchmark(_ benchmark: TaskBenchmarkRecord) async {
        guard !isRefreshBusy else {
            taskBenchmarkDeleteResult = .unavailable(reason: UIStrings.operationUnavailableBusy)
            return
        }

        deletingTaskBenchmarkIDs.insert(benchmark.id)
        defer { deletingTaskBenchmarkIDs.remove(benchmark.id) }

        do {
            let result = try await service.deleteTaskBenchmark(benchmarkID: benchmark.id)
            taskBenchmarkDeleteResult = result
            guard result.deleted else { return }
            taskBenchmarkList = TaskBenchmarkListResult(
                benchmarks: taskBenchmarkList.benchmarks.filter { $0.id != benchmark.id },
                fallbackReason: taskBenchmarkList.fallbackReason
            )
            taskBenchmarkEvaluation = nil
            routingRegressionBaseline = nil
            routingRegressionDetection = nil
        } catch {
            taskBenchmarkDeleteResult = .unavailable(reason: error.localizedDescription)
        }
    }

    func previewScriptExecutionSafety(for skill: SkillRecord) async {
        guard !isRefreshBusy else {
            scriptExecutionPreviews[skill.id] = .unavailable(skill: skill, reason: UIStrings.operationUnavailableBusy)
            return
        }

        previewingScriptExecutionSkillIDs.insert(skill.id)
        defer { previewingScriptExecutionSkillIDs.remove(skill.id) }

        do {
            scriptExecutionPreviews[skill.id] = try await service.previewScriptExecution(skill: skill)
        } catch {
            scriptExecutionPreviews[skill.id] = .unavailable(skill: skill, reason: error.localizedDescription)
        }
    }

    func previewRollback(snapshotID: String) async throws -> SnapshotRollbackPreviewRecord {
        errorMessage = nil
        guard agentConfigSnapshots.contains(where: { $0.id == snapshotID }) else {
            let message = "Snapshot is not in the selected agent config timeline."
            errorMessage = message
            throw ServiceClient.ClientError.invalidOutput(message)
        }
        do {
            return try await service.previewSnapshotRollback(snapshotID: snapshotID)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func rollbackSnapshot(snapshotID: String) async {
        guard !isRefreshBusy else { return }
        guard agentConfigSnapshots.contains(where: { $0.id == snapshotID }) else {
            errorMessage = "Snapshot is not in the selected agent config timeline."
            lastMutationMessage = nil
            return
        }
        isWriting = true
        errorMessage = nil
        lastMutationMessage = nil
        defer { isWriting = false }

        do {
            let scannedCount = try await service.rollbackSnapshot(snapshotID: snapshotID)
            detailsByID.removeAll()
            try await refreshCollections()
            lastMutationMessage = UIStrings.rollbackRescanned(scannedCount)
            recordLocalRefresh(message: UIStrings.refreshAfterRollback(scannedCount))
            await loadSelectedDetail()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadClaudeSettings() async {
        isLoadingSettings = true
        settingsErrorMessage = nil
        defer { isLoadingSettings = false }

        do {
            claudeSettings = try await service.readClaudeSettings()
        } catch {
            settingsErrorMessage = error.localizedDescription
        }
    }

    func loadAIProviderStatus() async {
        isLoadingAIProvider = true
        aiProviderErrorMessage = nil
        defer { isLoadingAIProvider = false }

        do {
            aiProviderStatus = try await service.aiProviderStatus()
            aiProviderTestResult = aiProviderStatus.lastTest
        } catch {
            aiProviderStatus = .unavailable(reason: error.localizedDescription)
            aiProviderErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func saveAIProviderSettings(draft: AIProviderSettingsDraft) async -> Bool {
        guard !isRefreshBusy else {
            aiProviderErrorMessage = UIStrings.operationUnavailableBusy
            return false
        }
        if let validationMessage = draft.validationMessage {
            aiProviderErrorMessage = validationMessage
            return false
        }

        isSavingAIProvider = true
        aiProviderErrorMessage = nil
        aiProviderMessage = nil
        defer { isSavingAIProvider = false }

        do {
            aiProviderStatus = try await service.saveAIProviderSettings(draft: draft)
            aiProviderTestResult = aiProviderStatus.lastTest
            aiProviderMessage = UIStrings.aiProviderSaved
            return true
        } catch ServiceClient.ClientError.service(let error) where error.code == "unknown_method" {
            aiProviderErrorMessage = UIStrings.aiProviderUnavailable
            return false
        } catch {
            aiProviderErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func testAIProviderConnection(draft: AIProviderSettingsDraft) async -> AIProviderTestResult? {
        guard !isRefreshBusy else {
            aiProviderErrorMessage = UIStrings.operationUnavailableBusy
            return nil
        }
        if let validationMessage = draft.validationMessage {
            aiProviderErrorMessage = validationMessage
            return nil
        }

        isTestingAIProvider = true
        aiProviderErrorMessage = nil
        aiProviderMessage = nil
        defer { isTestingAIProvider = false }

        do {
            let result = try await service.testAIProviderConnection(draft: draft)
            aiProviderTestResult = result
            aiProviderMessage = result.success ? UIStrings.aiProviderTestSucceeded : nil
            if !result.success {
                aiProviderErrorMessage = result.message
            }
            return result
        } catch {
            let result = AIProviderTestResult.unavailable(reason: error.localizedDescription)
            aiProviderTestResult = result
            aiProviderErrorMessage = result.message
            return result
        }
    }

    @discardableResult
    func saveClaudeSettings(content: String) async -> Bool {
        guard !isRefreshBusy else {
            settingsErrorMessage = UIStrings.operationUnavailableBusy
            return false
        }
        isSavingSettings = true
        settingsErrorMessage = nil
        settingsMessage = nil
        defer { isSavingSettings = false }

        do {
            claudeSettings = try await service.saveClaudeSettings(content: content)
            detailsByID.removeAll()
            try await refreshCollections()
            settingsMessage = UIStrings.savedSettings
            lastMutationMessage = settingsMessage
            recordLocalRefresh(message: UIStrings.refreshAfterSettingsSave)
            await loadSelectedDetail()
            return true
        } catch {
            settingsErrorMessage = error.localizedDescription
            return false
        }
    }

    func loadSelectedDetail() async {
        normalizeSelectionToVisibleSkills()
        guard let id = selectedSkill?.id else { return }
        if detailsByID[id] != nil {
            await loadSkillEventsIfNeeded(instanceID: id)
            return
        }

        isLoadingDetail = true
        errorMessage = nil
        defer { isLoadingDetail = false }

        do {
            detailsByID[id] = try await service.getSkill(instanceID: id)
            await loadSkillEventsIfNeeded(instanceID: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCleanupQueue() async {
        guard !isLoadingCleanupQueue else { return }
        isLoadingCleanupQueue = true
        defer { isLoadingCleanupQueue = false }

        do {
            let agent = agentFilter == .all ? nil : agentFilter.rawValue
            cleanupQueue = try await service.listCleanupQueue(agent: agent, limit: 100)
        } catch {
            cleanupQueue = .emptyFallback(reason: UIStrings.cleanupUnavailableFallback)
        }
    }

    func loadCrossAgentComparisons() async {
        guard !isLoadingCrossAgentComparisons else { return }
        isLoadingCrossAgentComparisons = true
        defer { isLoadingCrossAgentComparisons = false }

        let agent = agentFilter == .all ? nil : agentFilter.rawValue
        do {
            crossAgentComparisons = try await service.listCrossAgentComparisons(
                agent: agent,
                instanceID: selectedSkill?.id,
                limit: 100
            )
        } catch {
            crossAgentComparisons = CrossAgentComparisonResult.local(
                skills: skills,
                findings: findings,
                capabilities: adapterCapabilities,
                agentFilter: agentFilter,
                reason: UIStrings.crossAgentComparisonLocalFallback
            )
        }
    }

    func loadAgentConfigSnapshots() async {
        agentConfigSnapshotLoadGeneration += 1
        let generation = agentConfigSnapshotLoadGeneration
        isLoadingAgentConfigSnapshots = true

        do {
            let records = try await fetchAgentConfigSnapshots()
            guard generation == agentConfigSnapshotLoadGeneration else { return }
            agentConfigSnapshots = records
        } catch {
            guard generation == agentConfigSnapshotLoadGeneration else { return }
            errorMessage = error.localizedDescription
        }

        if generation == agentConfigSnapshotLoadGeneration {
            isLoadingAgentConfigSnapshots = false
        }
    }

    private func refreshCollections() async throws {
        async let appStateSnapshot = service.appStateSnapshot()
        async let llmStatus = service.llmStatus()
        async let aiProviderStatus = fetchAIProviderStatus()
        async let projectContextState = service.getProjectContext()
        async let agentConfigSnapshots = fetchAgentConfigSnapshots()
        async let ruleTuning = service.listRuleTuning()
        let snapshot = try await appStateSnapshot
        self.status = snapshot.status
        self.llmStatus = try await llmStatus
        self.aiProviderStatus = await aiProviderStatus
        self.aiProviderTestResult = self.aiProviderStatus.lastTest ?? aiProviderTestResult
        self.projectContextState = try await projectContextState
        self.skills = snapshot.skills
        self.findings = snapshot.findings
        self.ruleTuning = try await ruleTuning
        self.conflicts = snapshot.conflicts
        self.healthSummary = snapshot.health
        self.agentConfigSnapshots = try await agentConfigSnapshots
        let currentSkillIDs = Set(snapshot.skills.map(\.id))
        scriptExecutionPreviews = scriptExecutionPreviews.filter { currentSkillIDs.contains($0.key) }
        skillQualityScores = skillQualityScores.filter { currentSkillIDs.contains($0.key) }
        scoringSkillQualityIDs = scoringSkillQualityIDs.filter { currentSkillIDs.contains($0) }
        if let checkedSkillID = taskReadinessCheckedSkillID, !currentSkillIDs.contains(checkedSkillID) {
            taskReadinessResult = nil
            taskReadinessCheckedSkillID = nil
        }
        checkingTaskReadinessSkillIDs = checkingTaskReadinessSkillIDs.filter { currentSkillIDs.contains($0) }
        if let rankedSkillID = routingConfidenceRankedSkillID, !currentSkillIDs.contains(rankedSkillID) {
            routingConfidenceResult = nil
            routingConfidenceRankedSkillID = nil
        }
        rankingRoutingSkillIDs = rankingRoutingSkillIDs.filter { currentSkillIDs.contains($0) }
        deletingTaskBenchmarkIDs.removeAll()
        if taskBenchmarkList.isUnavailable {
            taskBenchmarkEvaluation = nil
            routingRegressionBaseline = nil
            routingRegressionDetection = nil
        }
        skillEventsByID = skillEventsByID.filter { currentSkillIDs.contains($0.key) }
        skillAnalysisPrepareResults.removeAll()
        preparingSkillAnalysisKeys.removeAll()
        batchTogglePreview = nil
        refreshWatcherMessage(from: self.status)
        normalizeSelectionToVisibleSkills()
        crossAgentComparisons = CrossAgentComparisonResult.local(
            skills: skills,
            findings: findings,
            capabilities: adapterCapabilities,
            agentFilter: agentFilter,
            reason: UIStrings.crossAgentComparisonLocalFallback
        )
    }

    private func fetchAIProviderStatus() async -> AIProviderStatus {
        do {
            return try await service.aiProviderStatus()
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    private func fetchAgentConfigSnapshots() async throws -> [ConfigSnapshotRecord] {
        guard let agent = selectedAgentConfigTimelineAgent else {
            return []
        }
        let records = try await service.listAgentConfigSnapshots(agent: agent, scope: nil)
        return records
            .filter { $0.agent == agent }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func loadSkillEventsIfNeeded(instanceID: SkillRecord.ID, force: Bool = false) async {
        if !force, skillEventsByID[instanceID] != nil {
            return
        }
        guard !loadingSkillEventIDs.contains(instanceID) else { return }
        loadingSkillEventIDs.insert(instanceID)
        defer { loadingSkillEventIDs.remove(instanceID) }

        do {
            skillEventsByID[instanceID] = try await service.listSkillEvents(instanceID: instanceID, limit: 12)
        } catch {
            skillEventsByID[instanceID] = []
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareSkillAnalysis(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope, instanceIDs: [String]) async {
        let key = skillAnalysisKey(kind: kind, scope: scope)
        guard !isRefreshBusy else {
            skillAnalysisPrepareResults[key] = .unavailable(kind: kind, reason: UIStrings.operationUnavailableBusy)
            return
        }

        preparingSkillAnalysisKeys.insert(key)
        defer { preparingSkillAnalysisKeys.remove(key) }

        do {
            skillAnalysisPrepareResults[key] = try await service.prepareSkillAnalysis(instanceIDs: instanceIDs, kind: kind)
        } catch {
            skillAnalysisPrepareResults[key] = .unavailable(kind: kind, reason: error.localizedDescription)
        }
    }

    private func scoreSkillQuality(for skill: SkillRecord) async {
        guard !isRefreshBusy else {
            skillQualityScores[skill.id] = .unavailable(skillID: skill.id, reason: UIStrings.operationUnavailableBusy)
            return
        }

        scoringSkillQualityIDs.insert(skill.id)
        defer { scoringSkillQualityIDs.remove(skill.id) }

        do {
            skillQualityScores[skill.id] = try await service.scoreSkillQuality(skill: skill)
        } catch {
            skillQualityScores[skill.id] = .unavailable(skillID: skill.id, reason: error.localizedDescription)
        }
    }

    private func skillAnalysisKey(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> String {
        "\(scope.key):\(kind.rawValue)"
    }

    private func skillAnalysisInstanceIDs(scope: LLMSkillAnalysisRequestScope) -> [String] {
        switch scope.key {
        case LLMSkillAnalysisRequestScope.visible.key:
            return filteredSkills.map(\.id)
        default:
            return selectedSkill.map { [$0.id] } ?? []
        }
    }

    private func llmPromptActionKey(action: LLMAction, skillID: SkillRecord.ID) -> String {
        "action:\(skillID):\(action.rawValue)"
    }

    private func skillAnalysisPromptKey(
        kind: LLMSkillAnalysisKind,
        scope: LLMSkillAnalysisRequestScope,
        instanceIDs: [String]
    ) -> String {
        "skill-analysis:\(scope.key):\(kind.rawValue):\(instanceIDs.joined(separator: ","))"
    }

    private func skillQualityPromptKey(skillID: SkillRecord.ID) -> String {
        "quality-score:\(skillID)"
    }

    private var normalizedTaskReadinessText: String {
        taskReadinessText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func taskReadinessPromptKey(skillID: SkillRecord.ID, taskText: String) -> String {
        "task-readiness:\(skillID):\(taskText)"
    }

    private var normalizedRoutingConfidenceText: String {
        routingConfidenceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func routingConfidencePromptKey(skillID: SkillRecord.ID, taskText: String) -> String {
        "routing-confidence:\(skillID):\(taskText)"
    }

    private var normalizedTaskBenchmarkText: String {
        taskBenchmarkText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTraceImportText: String {
        traceImportText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTraceExpectedSkillNames: [String] {
        traceImportExpectedSkills
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func upsertTaskBenchmark(_ benchmark: TaskBenchmarkRecord) {
        var benchmarks = taskBenchmarkList.benchmarks.filter { $0.id != benchmark.id }
        benchmarks.insert(benchmark, at: 0)
        taskBenchmarkList = TaskBenchmarkListResult(benchmarks: benchmarks, fallbackReason: nil)
    }

    private func upsertTraceImport(_ record: AgentTraceImportRecord) {
        var imports = traceImportList.imports.filter { $0.id != record.id }
        imports.insert(record, at: 0)
        traceImportList = AgentTraceImportListResult(imports: imports, fallbackReason: nil)
    }

    private func canSendLLMPrompt(_ preview: LLMPromptPreview) -> Bool {
        aiProviderStatus.serviceAvailable
            && aiProviderStatus.configured
            && aiProviderStatus.activeProfile != nil
            && preview.enabled
            && !preview.previewID.isEmpty
            && preview.confirmationRequired
            && !preview.rawPromptPersisted
            && !preview.rawResponsePersisted
    }

    private func confirmLLMPrompt(
        key: String,
        send: (String) async throws -> LLMPromptSendResult
    ) async {
        guard let preview = llmPromptPreviews[key] else { return }
        guard canSendLLMPrompt(preview) else {
            llmPromptSendResults[key] = .unavailable(
                previewID: preview.previewID,
                reason: aiProviderStatus.configured ? UIStrings.llmPromptPreviewRequired : UIStrings.llmPromptProviderRequired
            )
            return
        }
        guard !isRefreshBusy else {
            llmPromptSendResults[key] = .unavailable(previewID: preview.previewID, reason: UIStrings.operationUnavailableBusy)
            return
        }

        sendingLLMPromptKeys.insert(key)
        defer { sendingLLMPromptKeys.remove(key) }

        do {
            llmPromptSendResults[key] = try await send(preview.previewID)
        } catch {
            llmPromptSendResults[key] = .unavailable(previewID: preview.previewID, reason: error.localizedDescription)
        }
    }

    private func prepareLLMAction(_ action: LLMAction) async {
        guard !isRefreshBusy else {
            llmPreparedSkillID = selectedSkillID
            llmPrepareResults[action] = .disabledFallback(action: action, reason: UIStrings.operationUnavailableBusy)
            return
        }
        guard let skill = selectedSkill else { return }
        if llmPreparedSkillID != skill.id {
            llmPrepareResults.removeAll()
            llmPreparedSkillID = skill.id
        }

        preparingLLMActions.insert(action)
        defer { preparingLLMActions.remove(action) }

        do {
            llmPrepareResults[action] = try await service.prepareLLMAction(action: action, skill: skill)
        } catch {
            llmPrepareResults[action] = .disabledFallback(action: action, reason: error.localizedDescription)
        }
    }

    private func handleListCriteriaChanged() {
        let previousID = selectedSkillID
        batchTogglePreview = nil
        normalizeSelectionToVisibleSkills()
        guard previousID != selectedSkillID else { return }
        taskReadinessResult = nil
        taskReadinessCheckedSkillID = nil
        routingConfidenceResult = nil
        routingConfidenceRankedSkillID = nil
        taskBenchmarkEvaluation = nil
        taskBenchmarkDeleteResult = nil
        routingRegressionBaseline = nil
        routingRegressionDetection = nil
        Task { @MainActor [weak self] in
            await self?.loadSelectedDetail()
            await self?.loadCrossAgentComparisons()
        }
    }

    private func normalizeSelectionToVisibleSkills() {
        let visibleSkills = filteredSkills
        if let selectedSkillID, visibleSkills.contains(where: { $0.id == selectedSkillID }) {
            return
        }
        selectedSkillID = visibleSkills.first?.id
    }

    private func canStartScan(allowDuringProjectUpdate: Bool) -> Bool {
        if isLoading || isScanning || isWriting || isSavingSettings || isApplyingBatchToggle {
            return false
        }
        if isProjectUpdating, !allowDuringProjectUpdate {
            return false
        }
        return true
    }

    private func localBatchTogglePreview(selectedSkills: [SkillRecord], reason: String) -> BatchTogglePreview {
        var affected: [BatchToggleSkillItem] = []
        var skipped: [BatchToggleSkillItem] = []
        for skill in selectedSkills {
            if let skipReason = batchToggleSkipReason(for: skill) {
                skipped.append(BatchToggleSkillItem(skill: skill, targetEnabled: batchToggleAction.targetEnabled, reason: skipReason))
            } else if DisplayText.statusKind(skill.state, enabled: skill.enabled) == (batchToggleAction.targetEnabled ? .enabled : .disabled) {
                skipped.append(BatchToggleSkillItem(skill: skill, targetEnabled: batchToggleAction.targetEnabled, reason: UIStrings.batchToggleAlreadyInTargetState(batchToggleAction.title.lowercased())))
            } else {
                affected.append(BatchToggleSkillItem(skill: skill, targetEnabled: batchToggleAction.targetEnabled))
            }
        }
        return .local(
            action: batchToggleAction,
            selectedSkills: selectedSkills,
            affectedSkills: affected,
            skippedItems: skipped,
            reason: reason
        )
    }

    private func batchToggleSkipReason(for skill: SkillRecord) -> String? {
        if let catalogReason = DisplayText.catalogToggleDisabledReason(for: skill, isWriting: false) {
            return catalogReason
        }
        guard let capability = adapterCapabilities.first(where: { $0.agent == skill.agent }) else {
            return UIStrings.batchToggleCapabilityMissing(DisplayText.agent(skill.agent))
        }
        if !capability.configToggle.supported {
            return capability.configToggle.reason ?? UIStrings.readOnlyAdapterStatus(capability.displayName)
        }
        if !capability.writable.supported {
            return capability.writable.reason ?? UIStrings.batchToggleWritableMissing(capability.displayName)
        }
        return nil
    }

    private func beginRefresh(_ action: RefreshAction, message: String) {
        lastRefreshAction = action
        canRetryLastRefresh = false
        refreshStatusMessage = message
        appendRefreshLog(level: "info", message: message)
    }

    private func applyRefreshActivity(_ activity: RefreshActivity?) {
        if let activity {
            lastScanActivity = activity
            refreshStatusMessage = UIStrings.refreshScanComplete(
                activity.scannedCount,
                activity.skillCount,
                activity.findingCount,
                sameAgentRuntimeConflictCount
            )
            refreshLogEntries = activity.logEntries + refreshLogEntries
            trimRefreshLog()
        } else {
            refreshStatusMessage = UIStrings.refreshScanComplete(
                skills.count,
                skills.count,
                findings.count,
                sameAgentRuntimeConflictCount
            )
            appendRefreshLog(level: "info", message: refreshStatusMessage)
        }
        canRetryLastRefresh = false
    }

    private func recordLocalRefresh(message: String) {
        refreshStatusMessage = message
        appendRefreshLog(level: "info", message: message)
        canRetryLastRefresh = false
    }

    private func handleRefreshFailure(_ error: Error, action: RefreshAction) {
        let message = UIStrings.refreshFailed(error.localizedDescription)
        errorMessage = message
        refreshStatusMessage = message
        appendRefreshLog(level: "error", message: message)
        lastRefreshAction = action
        canRetryLastRefresh = true
    }

    private func refreshWatcherMessage(from status: ServiceStatus?) {
        guard let refresh = status?.refresh else {
            watcherStatusMessage = UIStrings.refreshWatcherManual
            return
        }
        watcherStatusMessage = refresh.watcherDetail
    }

    private func appendRefreshLog(level: String, message: String) {
        refreshLogEntries.insert(RefreshLogEntry(level: level, message: message), at: 0)
        trimRefreshLog()
    }

    private func trimRefreshLog() {
        if refreshLogEntries.count > 6 {
            refreshLogEntries = Array(refreshLogEntries.prefix(6))
        }
    }

}

private enum RefreshAction {
    case reload
    case scan
}
