import Foundation

@MainActor
extension SkillStore {
    var isRefreshBusy: Bool {
        isLoading
            || isScanning
            || isWriting
            || isProjectUpdating
            || isSavingSettings
            || isSavingAIProvider
            || isTestingAIProvider
            || isApplyingBatchToggle
            || isExportingLocalReport
            || isTaskBenchmarkBusy
            || isLLMPromptBusy
    }

    private var isTaskBenchmarkBusy: Bool {
        isSavingTaskBenchmark
            || isEvaluatingTaskBenchmarks
            || isSavingRoutingBaseline
            || isDetectingRoutingRegression
            || isLoadingRoutingAccuracyDashboard
            || isDetectingStaleDrift
            || isSearchingKnowledge
            || isBuildingLocalSkillMap
            || isLoadingSkillLifecycleTimeline
            || isLoadingProviderObservability
            || isBuildingTaskCockpit
            || isGroupingSimilarSkills
            || isBuildingCapabilityTaxonomy
            || isCheckingWorkspaceReadiness
            || isPlanningRemediation
            || isPreviewingRemediationDrafts
            || isPreviewingRemediationImpact
            || isReviewingRemediationBatch
            || isLoadingRemediationHistory
            || isRecordingRemediationHistory
            || isPlanningGuidedCleanupFlow
            || isRecordingGuidedCleanupStep
            || isComparingCrossAgentReadiness
            || isLoadingTraceImports
            || isImportingTrace
            || isLoadingAgentSessionSkillReviews
            || isReviewingAgentSessionSkillUse
            || !deletingTaskBenchmarkIDs.isEmpty
            || !deletingTraceImportIDs.isEmpty
            || !deletingAgentSessionSkillReviewIDs.isEmpty
    }

    private var isLLMPromptBusy: Bool {
        !previewingLLMPromptKeys.isEmpty
            || !sendingLLMPromptKeys.isEmpty
            || !scoringSkillQualityIDs.isEmpty
            || !checkingTaskReadinessSkillIDs.isEmpty
            || !rankingRoutingSkillIDs.isEmpty
    }

    func toggleDisabledReason(for skill: SkillRecord) -> String? {
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
        guard isBatchToggleSelectionExplicit else { return filteredSkills }
        return filteredSkills.filter { batchToggleSelectedSkillIDs.contains($0.id) }
    }

    var batchToggleAllVisibleSkillsSelected: Bool {
        !filteredSkills.isEmpty && batchToggleSelectedSkills.count == filteredSkills.count
    }

    func isBatchToggleSkillSelected(_ skill: SkillRecord) -> Bool {
        guard isBatchToggleSelectionExplicit else { return true }
        return batchToggleSelectedSkillIDs.contains(skill.id)
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
}
