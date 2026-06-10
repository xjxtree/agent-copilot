import Foundation

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [SkillRecord] = []
    @Published private(set) var findings: [RuleFindingRecord] = []
    @Published private(set) var conflicts: [ConflictGroupRecord] = []
    @Published private(set) var healthSummary = SkillHealthSummary.empty
    @Published private(set) var agentConfigSnapshots: [ConfigSnapshotRecord] = []
    @Published private(set) var isLoadingAgentConfigSnapshots = false
    @Published private(set) var detailsByID: [SkillRecord.ID: SkillDetailRecord] = [:]
    @Published private(set) var skillEventsByID: [SkillRecord.ID: [SkillEventRecord]] = [:]
    @Published private(set) var loadingSkillEventIDs: Set<SkillRecord.ID> = []
    @Published private(set) var status: ServiceStatus?
    @Published private(set) var llmStatus = LLMStatus.disabledFallback()
    @Published private(set) var llmPrepareResults: [LLMAction: LLMPrepareResult] = [:]
    @Published private(set) var preparingLLMActions: Set<LLMAction> = []
    @Published private(set) var skillAnalysisPrepareResults: [String: LLMSkillAnalysisPrepareResult] = [:]
    @Published private(set) var preparingSkillAnalysisKeys: Set<String> = []
    @Published private(set) var scriptExecutionPreviews: [SkillRecord.ID: ScriptExecutionPreview] = [:]
    @Published private(set) var previewingScriptExecutionSkillIDs: Set<SkillRecord.ID> = []
    @Published private(set) var projectContextState: ProjectContextState?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var isScanning = false
    @Published private(set) var isWriting = false
    @Published private(set) var isProjectUpdating = false
    @Published private(set) var isLoadingSettings = false
    @Published private(set) var isSavingSettings = false
    @Published private(set) var lastMutationMessage: String?
    @Published private(set) var refreshStatusMessage = UIStrings.refreshIdle
    @Published private(set) var watcherStatusMessage = UIStrings.refreshWatcherManual
    @Published private(set) var refreshLogEntries: [RefreshLogEntry] = []
    @Published private(set) var canRetryLastRefresh = false
    @Published private(set) var claudeSettings: ConfigDocumentRecord?
    @Published private(set) var settingsMessage: String?
    @Published private(set) var settingsErrorMessage: String?
    @Published var selectedSkillID: SkillRecord.ID?
    @Published var selectedDetailSection: DetailSection = .overview
    @Published var searchText = "" {
        didSet { handleListCriteriaChanged() }
    }
    @Published var agentFilter: SkillAgentFilter = .claudeCode {
        didSet {
            handleListCriteriaChanged()
            Task { await loadAgentConfigSnapshots() }
        }
    }
    @Published var stateFilter: SkillStateFilter = .all {
        didSet { handleListCriteriaChanged() }
    }
    @Published var sortOrder: SkillSortOrder = .name {
        didSet { handleListCriteriaChanged() }
    }
    @Published var errorMessage: String?

    private let service: ServiceClient
    private var lastRefreshAction: RefreshAction = .reload
    private var llmPreparedSkillID: SkillRecord.ID?
    private var agentConfigSnapshotLoadGeneration = 0

    init(service: ServiceClient) {
        self.service = service
    }

    var isRefreshBusy: Bool {
        isLoading || isScanning || isWriting || isProjectUpdating || isSavingSettings
    }

    private func toggleDisabledReason(for skill: SkillRecord) -> String? {
        let catalogReason = DisplayText.toggleDisabledReason(for: skill, isWriting: isWriting)
        guard !isWriting,
              let capability = adapterCapabilities.first(where: { $0.agent == skill.agent }),
              !capability.configToggle.supported
        else {
            return catalogReason
        }
        return capability.configToggle.reason ?? catalogReason ?? UIStrings.readOnlyAdapterStatus(capability.displayName)
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

    var selectedFindings: [RuleFindingRecord] {
        guard let skill = selectedSkill else { return [] }
        return findings.filter { finding in
            finding.instanceId == skill.id
        }
    }

    func setFindingTriageStatus(_ status: FindingTriageStatus, for triageKeys: [String]) {
        let keys = Array(Set(triageKeys.filter { !$0.isEmpty })).sorted()
        guard !keys.isEmpty else { return }
        Task {
            await setFindingTriageStatus(status, triageKeys: keys)
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
        async let projectContextState = service.getProjectContext()
        async let agentConfigSnapshots = fetchAgentConfigSnapshots()
        let snapshot = try await appStateSnapshot
        self.status = snapshot.status
        self.llmStatus = try await llmStatus
        self.projectContextState = try await projectContextState
        self.skills = snapshot.skills
        self.findings = snapshot.findings
        self.conflicts = snapshot.conflicts
        self.healthSummary = snapshot.health
        self.agentConfigSnapshots = try await agentConfigSnapshots
        let currentSkillIDs = Set(snapshot.skills.map(\.id))
        scriptExecutionPreviews = scriptExecutionPreviews.filter { currentSkillIDs.contains($0.key) }
        skillEventsByID = skillEventsByID.filter { currentSkillIDs.contains($0.key) }
        skillAnalysisPrepareResults.removeAll()
        preparingSkillAnalysisKeys.removeAll()
        refreshWatcherMessage(from: self.status)
        normalizeSelectionToVisibleSkills()
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

    private func skillAnalysisKey(kind: LLMSkillAnalysisKind, scope: LLMSkillAnalysisRequestScope) -> String {
        "\(scope.key):\(kind.rawValue)"
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
        normalizeSelectionToVisibleSkills()
        guard previousID != selectedSkillID else { return }
        Task { @MainActor [weak self] in
            await self?.loadSelectedDetail()
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
        if isLoading || isScanning || isWriting || isSavingSettings {
            return false
        }
        if isProjectUpdating, !allowDuringProjectUpdate {
            return false
        }
        return true
    }

    private func beginRefresh(_ action: RefreshAction, message: String) {
        lastRefreshAction = action
        canRetryLastRefresh = false
        refreshStatusMessage = message
        appendRefreshLog(level: "info", message: message)
    }

    private func applyRefreshActivity(_ activity: RefreshActivity?) {
        if let activity {
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
