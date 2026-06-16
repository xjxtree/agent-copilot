import Foundation

extension ServiceClient {
    func planRemediation(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        limit: Int? = 20,
        includeGuidanceOnly: Bool = true
    ) async throws -> RemediationPlanResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = RemediationPlanParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            limit: limit,
            includeGuidanceOnly: includeGuidanceOnly
        )
        do {
            return try await call(method: "remediation.plan", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func previewRemediationDrafts(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        limit: Int? = 20,
        draftTypes: [String] = ["frontmatter", "description", "permissions", "dependency", "policy"],
        includeBlocked: Bool = true
    ) async throws -> RemediationPreviewDraftsResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = RemediationPreviewDraftsParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            limit: limit,
            draftTypes: draftTypes,
            includeBlocked: includeBlocked
        )
        do {
            return try await call(method: "remediation.previewDrafts", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func previewRemediationImpact(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        action: String = "review",
        limit: Int? = 20,
        includeTaskImpacts: Bool = true,
        includeAgentImpacts: Bool = true,
        includeSkillImpacts: Bool = true,
        includeRiskDeltas: Bool = true,
        includeSnapshotRollback: Bool = true,
        includeBlocked: Bool = true
    ) async throws -> RemediationImpactPreviewResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = RemediationImpactPreviewParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            action: normalizedAction.isEmpty ? "review" : normalizedAction,
            limit: limit,
            includeTaskImpacts: includeTaskImpacts,
            includeAgentImpacts: includeAgentImpacts,
            includeSkillImpacts: includeSkillImpacts,
            includeRiskDeltas: includeRiskDeltas,
            includeSnapshotRollback: includeSnapshotRollback,
            includeBlocked: includeBlocked
        )
        do {
            return try await call(method: "remediation.previewImpact", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func batchReviewRemediation(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        limit: Int? = 30,
        options: RemediationBatchReviewOptions = RemediationBatchReviewOptions()
    ) async throws -> RemediationBatchReviewResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = RemediationBatchReviewParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            limit: limit,
            reviewDimensions: options.dimensions,
            includeTask: options.includeTask,
            includeRisk: options.includeRisk,
            includeRule: options.includeRule,
            includeAgent: options.includeAgent,
            includeWorkspace: options.includeWorkspace,
            includeBlocked: options.includeBlocked
        )
        do {
            return try await call(method: "remediation.batchReview", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func listRemediationHistory(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        limit: Int? = 30
    ) async throws -> RemediationHistoryResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = RemediationHistoryListParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            limit: limit
        )
        do {
            return try await call(method: "remediation.listHistory", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func recordRemediationHistory(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        decision: String = "reviewed",
        status: String = "recorded",
        sourceMethod: String = "analysis.remediationHistory.ui",
        reviewArea: String = "Remediation History",
        note: String = UIStrings.remediationHistoryRecordDefaultNote,
        evidenceRefs: [String] = [],
        safetyFlags: [String] = ["local audit only", "no write", "provider not sent"]
    ) async throws -> RemediationHistoryRecordResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = RemediationHistoryRecordParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            decision: decision,
            status: status,
            sourceMethod: sourceMethod,
            reviewArea: reviewArea,
            note: note,
            evidenceRefs: evidenceRefs,
            safetyFlags: safetyFlags
        )
        do {
            return try await call(method: "remediation.recordHistory", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func planGuidedCleanupFlow(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        limit: Int? = 12,
        includeIssueGroups: Bool = true,
        includeSafeNextActions: Bool = true,
        includeRecordedSteps: Bool = true,
        includeEvidence: Bool = true,
        includeSafetyFlags: Bool = true
    ) async throws -> GuidedCleanupFlowResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = GuidedCleanupFlowParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            limit: limit,
            includeIssueGroups: includeIssueGroups,
            includeSafeNextActions: includeSafeNextActions,
            includeRecordedSteps: includeRecordedSteps,
            includeEvidence: includeEvidence,
            includeSafetyFlags: includeSafetyFlags
        )
        do {
            return try await call(method: "cleanup.planGuidedFlow", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func recordGuidedCleanupStep(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        step: GuidedCleanupFlowStep,
        sourceMethod: String = "analysis.guidedCleanupFlow.ui",
        note: String = UIStrings.guidedCleanupFlowRecordDefaultNote,
        evidenceRefs: [String] = [],
        safetyFlags: [String] = ["app-local metadata only", "no write", "provider not sent"]
    ) async throws -> GuidedCleanupRecordStepResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = GuidedCleanupRecordStepParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            stepID: step.id,
            stepTitle: step.title,
            stepKind: step.kind,
            actionLabel: step.actionLabel,
            sourceMethod: sourceMethod,
            note: note,
            evidenceRefs: evidenceRefs,
            safetyFlags: safetyFlags
        )
        do {
            return try await call(method: "cleanup.recordGuidedStep", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }
}
