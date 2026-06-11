import Foundation

struct ServiceErrorPayload: Codable, Error {
    let code: String
    let message: String
}

struct AppVersion: Codable, Hashable {
    let protocolVersion: Int
    let version: String

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case version
    }
}

struct AppStateSnapshot: Codable, Hashable {
    let status: ServiceStatus
    let skills: [SkillRecord]
    let findings: [RuleFindingRecord]
    let conflicts: [ConflictGroupRecord]
    let health: SkillHealthSummary
    let snapshots: [ConfigSnapshotRecord]

    enum CodingKeys: String, CodingKey {
        case status
        case skills
        case findings
        case conflicts
        case health
        case snapshots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(ServiceStatus.self, forKey: .status)
        skills = try container.decode([SkillRecord].self, forKey: .skills)
        findings = try container.decode([RuleFindingRecord].self, forKey: .findings)
        conflicts = try container.decode([ConflictGroupRecord].self, forKey: .conflicts)
        health = try container.decodeIfPresent(SkillHealthSummary.self, forKey: .health) ?? .empty
        snapshots = try container.decodeIfPresent([ConfigSnapshotRecord].self, forKey: .snapshots) ?? []
    }
}

private struct ServiceRequest<Params: Encodable>: Encodable {
    let id: String
    let method: String
    let params: Params
}

private struct EmptyParams: Encodable {}

private struct CleanupListQueueParams: Encodable {
    let agent: String?
    let limit: Int?
}

private struct CrossAgentComparisonParams: Encodable {
    let agent: String?
    let instanceId: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case agent
        case instanceId = "instance_id"
        case limit
    }
}

private struct LocalReportExportParams: Encodable {
    let formats: [LocalReportFormat]
    let agent: String?
    let instanceId: String?
    let stateFilter: String?
    let search: String?

    enum CodingKeys: String, CodingKey {
        case formats
        case agent
        case instanceId = "instance_id"
        case stateFilter = "state_filter"
        case search
    }
}

private struct GetSkillParams: Encodable {
    let instanceId: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
    }
}

private struct ToggleSkillParams: Encodable {
    let instanceId: String
    let on: Bool

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case on
    }
}

private struct BatchToggleParams: Encodable {
    let instanceIDs: [String]
    let targetEnabled: Bool
    let action: String
    let previewToken: String?
    let confirmed: Bool?

    enum CodingKeys: String, CodingKey {
        case instanceIDs = "instance_ids"
        case targetEnabled = "target_enabled"
        case action
        case previewToken = "preview_token"
        case confirmed
    }
}

private struct ToolInstallPreviewParams: Encodable {
    let instanceId: String
    let targetAgent: String
    let targetScope: String
    let confirmed: Bool

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case targetAgent = "target_agent"
        case targetScope = "target_scope"
        case confirmed
    }
}

private struct PrepareSkillAnalysisParams: Encodable {
    let instanceIDs: [String]
    let analysisKind: LLMSkillAnalysisKind

    enum CodingKeys: String, CodingKey {
        case instanceIDs = "instance_ids"
        case analysisKind = "analysis_kind"
    }
}

private struct ScoreSkillQualityParams: Encodable {
    let instanceId: String
    let definitionId: String
    let agent: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
    }
}

private struct TaskReadinessParams: Encodable {
    let task: String
    let agent: String?
    let candidateInstanceIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case candidateInstanceIDs = "candidate_instance_ids"
    }
}

private struct TaskRoutingConfidenceParams: Encodable {
    let task: String
    let agent: String?
    let candidateInstanceIDs: [String]?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case candidateInstanceIDs = "candidate_instance_ids"
        case limit
    }
}

private struct CrossAgentReadinessParams: Encodable {
    let task: String
    let agents: [String]?
    let limitPerAgent: Int?
    let includeRoutingAccuracy: Bool
    let includeBenchmarks: Bool

    enum CodingKeys: String, CodingKey {
        case task
        case agents
        case limitPerAgent = "limit_per_agent"
        case includeRoutingAccuracy = "include_routing_accuracy"
        case includeBenchmarks = "include_benchmarks"
    }
}

private struct TaskBenchmarkListParams: Encodable {
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case limit
    }
}

private struct TaskBenchmarkSaveParams: Encodable {
    let task: String
    let title: String?
    let expectedSkillRefs: [String]
    let expectedSkillNames: [String]
    let acceptableAgents: [String]
    let acceptableScopes: [String]
    let successCriteria: [String]

    enum CodingKeys: String, CodingKey {
        case task
        case title
        case expectedSkillRefs = "expected_skill_refs"
        case expectedSkillNames = "expected_skill_names"
        case acceptableAgents = "acceptable_agents"
        case acceptableScopes = "acceptable_scopes"
        case successCriteria = "success_criteria"
    }
}

private struct TaskBenchmarkEvaluateParams: Encodable {
    let benchmarkIDs: [String]?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case benchmarkIDs = "benchmark_ids"
        case limit
    }
}

private struct RoutingRegressionParams: Encodable {
    let benchmarkIDs: [String]?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case benchmarkIDs = "benchmark_ids"
        case limit
    }
}

private struct RoutingAccuracyDashboardParams: Encodable {
    let agent: String?
    let windowDays: Int?
    let limit: Int?
    let includeHistory: Bool
    let includeRecentEvidence: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case windowDays = "window_days"
        case limit
        case includeHistory = "include_history"
        case includeRecentEvidence = "include_recent_evidence"
    }
}

private struct StaleDriftDetectionParams: Encodable {
    let agent: String?
    let limit: Int?
    let includeReadinessImpact: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case limit
        case includeReadinessImpact = "include_readiness_impact"
    }
}

private struct KnowledgeSearchParams: Encodable {
    let query: String
    let agent: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case query
        case agent
        case limit
    }
}

private struct SimilarSkillGroupingParams: Encodable {
    let agent: String?
    let limit: Int?
    let minScore: Double?
    let includeSingletons: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case limit
        case minScore = "min_score"
        case includeSingletons = "include_singletons"
    }
}

private struct CapabilityTaxonomyParams: Encodable {
    let agent: String?
    let limit: Int?
    let includeSingleSkillDomains: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case limit
        case includeSingleSkillDomains = "include_single_skill_domains"
    }
}

private struct WorkspaceReadinessParams: Encodable {
    let task: String?
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let includeChecklist: Bool
    let includeCapabilities: Bool

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case limit
        case includeChecklist = "include_checklist"
        case includeCapabilities = "include_capabilities"
    }
}

private struct RemediationPlanParams: Encodable {
    let task: String?
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let includeGuidanceOnly: Bool

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case limit
        case includeGuidanceOnly = "include_guidance_only"
    }
}

private struct RemediationPreviewDraftsParams: Encodable {
    let task: String?
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let draftTypes: [String]
    let includeBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case limit
        case draftTypes = "draft_types"
        case includeBlocked = "include_blocked"
    }
}

private struct RemediationImpactPreviewParams: Encodable {
    let task: String?
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let action: String
    let limit: Int?
    let includeTaskImpacts: Bool
    let includeAgentImpacts: Bool
    let includeSkillImpacts: Bool
    let includeRiskDeltas: Bool
    let includeSnapshotRollback: Bool
    let includeBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case selectedSkillID = "selected_skill_id"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillPath = "selected_skill_path"
        case action
        case limit
        case includeTaskImpacts = "include_task_impacts"
        case includeAgentImpacts = "include_agent_impacts"
        case includeSkillImpacts = "include_skill_impacts"
        case includeRiskDeltas = "include_risk_deltas"
        case includeSnapshotRollback = "include_snapshot_rollback"
        case includeBlocked = "include_blocked"
    }
}

private struct RemediationBatchReviewParams: Encodable {
    let task: String?
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let limit: Int?
    let reviewDimensions: [String]
    let includeTask: Bool
    let includeRisk: Bool
    let includeRule: Bool
    let includeAgent: Bool
    let includeWorkspace: Bool
    let includeBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case selectedSkillID = "selected_skill_id"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillPath = "selected_skill_path"
        case limit
        case reviewDimensions = "review_dimensions"
        case includeTask = "include_task"
        case includeRisk = "include_risk"
        case includeRule = "include_rule"
        case includeAgent = "include_agent"
        case includeWorkspace = "include_workspace"
        case includeBlocked = "include_blocked"
    }
}

private struct TaskBenchmarkDeleteParams: Encodable {
    let benchmarkId: String

    enum CodingKeys: String, CodingKey {
        case benchmarkId = "benchmark_id"
    }
}

private struct AgentTraceImportParams: Encodable {
    let traceText: String
    let title: String?
    let task: String?
    let expectedSkillNames: [String]
    let candidateInstanceIDs: [String]?
    let agent: String?

    enum CodingKeys: String, CodingKey {
        case traceText = "trace_text"
        case title
        case task
        case expectedSkillNames = "expected_skill_names"
        case candidateInstanceIDs = "candidate_instance_ids"
        case agent
    }
}

private struct AgentTraceListParams: Encodable {
    let limit: Int?
}

private struct AgentTraceDeleteParams: Encodable {
    let importID: String

    enum CodingKeys: String, CodingKey {
        case importID = "import_id"
    }
}

private struct PrepareLLMActionParams: Encodable {
    let action: LLMAction
    let instanceId: String
    let definitionId: String
    let agent: String

    enum CodingKeys: String, CodingKey {
        case action = "kind"
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
    }
}

private struct PreviewLLMPromptParams: Encodable {
    let action: String
    let requestKind: String
    let analysisKind: LLMSkillAnalysisKind?
    let scope: String?
    let instanceIDs: [String]?
    let instanceId: String?
    let definitionId: String?
    let agent: String?
    let taskText: String?
    let userIntent: String?
    let candidateInstanceIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case action
        case requestKind = "request_kind"
        case analysisKind = "analysis_kind"
        case scope
        case instanceIDs = "instance_ids"
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
        case taskText = "task_text"
        case userIntent = "user_intent"
        case candidateInstanceIDs = "candidate_instance_ids"
    }
}

private struct ConfirmLLMPromptParams: Encodable {
    let previewID: String
    let confirmationID: String
    let request: PreviewLLMPromptParams

    enum CodingKeys: String, CodingKey {
        case previewID = "preview_id"
        case confirmationID = "confirmation_id"
        case request
    }
}

private struct ScriptExecutionParams: Encodable {
    let instanceId: String
    let definitionId: String
    let agent: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
    }
}

private struct SnapshotParams: Encodable {
    let snapshotId: String

    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
    }
}

private struct ListAgentConfigSnapshotsParams: Encodable {
    let agent: String
    let scope: String?
}

private struct ListSkillEventsParams: Encodable {
    let instanceId: String
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case limit
    }
}

private struct SetFindingTriageParams: Encodable {
    let triageKey: String
    let status: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case triageKey = "triage_key"
        case status
        case note
    }
}

private struct ClearFindingTriageParams: Encodable {
    let triageKey: String

    enum CodingKeys: String, CodingKey {
        case triageKey = "triage_key"
    }
}

private struct SetRuleSeverityOverrideParams: Encodable {
    let ruleId: String
    let severity: String

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case severity
    }
}

private struct ClearRuleSeverityOverrideParams: Encodable {
    let ruleId: String

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
    }
}

private struct SetRuleSuppressionParams: Encodable {
    let ruleId: String
    let scope: String
    let findingGroupId: String?
    let suppressed: Bool
    let note: String?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case scope
        case findingGroupId = "finding_group_id"
        case suppressed
        case note
    }
}

private struct ClearRuleSuppressionParams: Encodable {
    let ruleId: String
    let scope: String
    let findingGroupId: String?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case scope
        case findingGroupId = "finding_group_id"
    }
}

private struct SaveClaudeSettingsParams: Encodable {
    let content: String
}

private struct SaveAIProviderProfileParams: Encodable {
    let id: String
    let displayName: String
    let providerType: String
    let baseURL: String
    let model: String
    let enabled: Bool
    let apiVersion: String?
    let apiKey: String?
    let singleRequestTokenLimit: Int?
    let monthlyBudgetUSD: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case providerType = "provider_type"
        case baseURL = "base_url"
        case model
        case enabled
        case apiVersion = "api_version"
        case apiKey = "api_key"
        case singleRequestTokenLimit = "single_request_token_limit"
        case monthlyBudgetUSD = "monthly_budget_usd"
    }
}

private struct TestAIProviderConnectionParams: Encodable {
    let profileID: String
    let confirmationID: String
    let timeoutMS: Int

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case confirmationID = "confirmation_id"
        case timeoutMS = "timeout_ms"
    }
}

private struct ProjectContextParams: Encodable {
    let rootPath: String
    let currentCWD: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case rootPath = "root_path"
        case currentCWD = "current_cwd"
        case name
    }
}

private struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
    let id: String?
    let ok: Bool
    let result: ResultPayload?
    let error: ServiceErrorPayload?
}

final class ServiceClient {
    enum ClientError: LocalizedError {
        case missingBinary
        case invalidOutput(String)
        case service(ServiceErrorPayload)
        case processFailed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .missingBinary:
                return "skills-copilot-service was not found in the app bundle."
            case .invalidOutput(let output):
                return "Invalid service output: \(output)"
            case .service(let error):
                return "\(error.code): \(error.message)"
            case .processFailed(let status, let stderr):
                return "Service exited with \(status): \(stderr)"
            }
        }
    }

    func status() async throws -> ServiceStatus {
        try await call(method: "service.status", params: EmptyParams())
    }

    func listAdapterCapabilities() async throws -> [AdapterCapabilityRecord] {
        try await call(method: "adapter.listCapabilities", params: EmptyParams())
    }

    func appVersion() async throws -> AppVersion {
        try await call(method: "app.version", params: EmptyParams())
    }

    func appStateSnapshot() async throws -> AppStateSnapshot {
        try await call(method: "app.stateSnapshot", params: EmptyParams())
    }

    func listCleanupQueue(agent: String? = nil, limit: Int? = nil) async throws -> CleanupQueueResult {
        do {
            return try await call(
                method: "cleanup.listQueue",
                params: CleanupListQueueParams(agent: agent, limit: limit)
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .emptyFallback(reason: UIStrings.cleanupUnavailableFallback)
        }
    }

    func listCrossAgentComparisons(agent: String? = nil, instanceID: String? = nil, limit: Int? = nil) async throws -> CrossAgentComparisonResult {
        let params = CrossAgentComparisonParams(agent: agent, instanceId: instanceID, limit: limit)
        do {
            return try await call(method: "comparison.listCrossAgent", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return try await call(method: "analysis.listComparisons", params: params)
        }
    }

    func exportLocalReport(
        format: LocalReportFormat,
        agent: String? = nil,
        instanceID: String? = nil,
        stateFilter: String? = nil,
        search: String? = nil
    ) async throws -> LocalReportExportResult {
        do {
            return try await call(
                method: "report.exportLocal",
                params: LocalReportExportParams(
                    formats: [format],
                    agent: agent,
                    instanceId: instanceID,
                    stateFilter: stateFilter,
                    search: search
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(format: format)
        }
    }

    func listSkills() async throws -> [SkillRecord] {
        try await call(method: "catalog.listSkills", params: EmptyParams())
    }

    func llmStatus() async throws -> LLMStatus {
        do {
            return try await call(method: "llm.status", params: EmptyParams())
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .disabledFallback()
        }
    }

    func aiProviderStatus() async throws -> AIProviderStatus {
        do {
            return try await call(method: "llm.listProviderProfiles", params: EmptyParams())
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func saveAIProviderSettings(draft: AIProviderSettingsDraft) async throws -> AIProviderStatus {
        let params = SaveAIProviderProfileParams(
            id: draft.kind.rawValue,
            displayName: draft.kind.title,
            providerType: draft.kind.rawValue,
            baseURL: draft.trimmedEndpoint,
            model: draft.trimmedModel,
            enabled: true,
            apiVersion: draft.trimmedAPIVersion,
            apiKey: draft.trimmedAPIKey,
            singleRequestTokenLimit: draft.parsedSingleRequestTokenLimit,
            monthlyBudgetUSD: draft.parsedMonthlyBudgetUSD
        )
        do {
            let _: AIProviderSaveResult = try await call(method: "llm.saveProviderProfile", params: params)
            return try await aiProviderStatus()
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func testAIProviderConnection(draft: AIProviderSettingsDraft) async throws -> AIProviderTestResult {
        let params = TestAIProviderConnectionParams(
            profileID: draft.kind.rawValue,
            confirmationID: "settings-test-\(UUID().uuidString)",
            timeoutMS: 4_000
        )
        do {
            return try await call(method: "llm.testProviderConnection", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func prepareLLMAction(action: LLMAction, skill: SkillRecord) async throws -> LLMPrepareResult {
        do {
            return try await call(
                method: "llm.prepareAction",
                params: PrepareLLMActionParams(
                    action: action,
                    instanceId: skill.id,
                    definitionId: skill.definitionId,
                    agent: skill.agent
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .disabledFallback(action: action)
        }
    }

    func prepareSkillAnalysis(instanceIDs: [String], kind: LLMSkillAnalysisKind) async throws -> LLMSkillAnalysisPrepareResult {
        do {
            return try await call(
                method: "llm.prepareSkillAnalysis",
                params: PrepareSkillAnalysisParams(instanceIDs: instanceIDs, analysisKind: kind)
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(kind: kind)
        }
    }

    func scoreSkillQuality(skill: SkillRecord) async throws -> SkillQualityScoreResult {
        let params = ScoreSkillQualityParams(
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent
        )
        do {
            return try await call(method: "analysis.scoreSkillQuality", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(skillID: skill.id)
        }
    }

    func checkTaskReadiness(taskText: String, skill: SkillRecord) async throws -> TaskReadinessResult {
        let params = TaskReadinessParams(
            task: taskText,
            agent: skill.agent,
            candidateInstanceIDs: [skill.id]
        )
        do {
            return try await call(method: "task.checkReadiness", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(taskText: taskText)
        }
    }

    func rankSkillRoutes(taskText: String, skill: SkillRecord, limit: Int = 6) async throws -> SkillRoutingConfidenceResult {
        let params = TaskRoutingConfidenceParams(
            task: taskText,
            agent: skill.agent,
            candidateInstanceIDs: [skill.id],
            limit: limit
        )
        do {
            return try await call(method: "task.rankSkillRoutes", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(taskText: taskText)
        }
    }

    func compareAgentReadiness(
        taskText: String,
        agents: [String]? = nil,
        limitPerAgent: Int = 3,
        includeRoutingAccuracy: Bool = true,
        includeBenchmarks: Bool = true
    ) async throws -> CrossAgentReadinessResult {
        let params = CrossAgentReadinessParams(
            task: taskText,
            agents: agents,
            limitPerAgent: limitPerAgent,
            includeRoutingAccuracy: includeRoutingAccuracy,
            includeBenchmarks: includeBenchmarks
        )
        do {
            return try await call(method: "task.compareAgentReadiness", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(taskText: taskText)
        }
    }

    func listTaskBenchmarks(skill: SkillRecord?) async throws -> TaskBenchmarkListResult {
        let params = TaskBenchmarkListParams(limit: nil)
        do {
            return try await call(method: "task.listBenchmarks", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func saveTaskBenchmark(taskText: String, skill: SkillRecord) async throws -> TaskBenchmarkSaveResult {
        let params = TaskBenchmarkSaveParams(
            task: taskText,
            title: nil,
            expectedSkillRefs: [skill.id, skill.definitionId],
            expectedSkillNames: [skill.name],
            acceptableAgents: [skill.agent],
            acceptableScopes: [skill.scope],
            successCriteria: [UIStrings.taskBenchmarkSuccessCriterion]
        )
        do {
            return try await call(method: "task.saveBenchmark", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func evaluateTaskBenchmarks(skill: SkillRecord?, benchmarkIDs: [String]? = nil, limit: Int = 6) async throws -> TaskBenchmarkEvaluationResult {
        let params = TaskBenchmarkEvaluateParams(
            benchmarkIDs: benchmarkIDs,
            limit: limit
        )
        do {
            return try await call(method: "task.evaluateBenchmarks", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func saveRoutingBaseline(skill: SkillRecord?, benchmarkIDs: [String]? = nil, limit: Int = 20) async throws -> RoutingRegressionBaselineResult {
        let params = RoutingRegressionParams(
            benchmarkIDs: benchmarkIDs,
            limit: limit
        )
        do {
            return try await call(method: "task.saveRoutingBaseline", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func detectRoutingRegression(skill: SkillRecord?, benchmarkIDs: [String]? = nil, limit: Int = 20) async throws -> RoutingRegressionDetectionResult {
        let params = RoutingRegressionParams(
            benchmarkIDs: benchmarkIDs,
            limit: limit
        )
        do {
            return try await call(method: "task.detectRoutingRegression", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func routingAccuracyDashboard(
        agent: String? = nil,
        windowDays: Int? = 30,
        limit: Int? = 20,
        includeHistory: Bool = true,
        includeRecentEvidence: Bool = true
    ) async throws -> RoutingAccuracyDashboard {
        let params = RoutingAccuracyDashboardParams(
            agent: agent,
            windowDays: windowDays,
            limit: limit,
            includeHistory: includeHistory,
            includeRecentEvidence: includeRecentEvidence
        )
        do {
            return try await call(method: "routing.accuracyDashboard", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func detectStaleDrift(
        agent: String? = nil,
        limit: Int? = 40,
        includeReadinessImpact: Bool = true
    ) async throws -> StaleDriftDetectionResult {
        let params = StaleDriftDetectionParams(
            agent: agent,
            limit: limit,
            includeReadinessImpact: includeReadinessImpact
        )
        do {
            return try await call(method: "analysis.detectStaleDrift", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func searchKnowledge(query: String, agent: String? = nil, limit: Int? = 20) async throws -> KnowledgeSearchResult {
        let params = KnowledgeSearchParams(query: query, agent: agent, limit: limit)
        do {
            return try await call(method: "knowledge.search", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func groupSimilarSkills(
        agent: String? = nil,
        limit: Int? = 20,
        minScore: Double? = 0.62,
        includeSingletons: Bool = false
    ) async throws -> SimilarSkillGroupingResult {
        let params = SimilarSkillGroupingParams(
            agent: agent,
            limit: limit,
            minScore: minScore,
            includeSingletons: includeSingletons
        )
        do {
            return try await call(method: "knowledge.groupSimilarSkills", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func buildCapabilityTaxonomy(
        agent: String? = nil,
        limit: Int? = 20,
        includeSingleSkillDomains: Bool = true
    ) async throws -> CapabilityTaxonomyResult {
        let params = CapabilityTaxonomyParams(
            agent: agent,
            limit: limit,
            includeSingleSkillDomains: includeSingleSkillDomains
        )
        do {
            return try await call(method: "knowledge.buildCapabilityTaxonomy", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func checkWorkspaceReadiness(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        limit: Int? = 40,
        includeChecklist: Bool = true,
        includeCapabilities: Bool = true
    ) async throws -> WorkspaceReadinessResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = WorkspaceReadinessParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            limit: limit,
            includeChecklist: includeChecklist,
            includeCapabilities: includeCapabilities
        )
        do {
            return try await call(method: "workspace.checkReadiness", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

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

    func deleteTaskBenchmark(benchmarkID: String) async throws -> TaskBenchmarkDeleteResult {
        do {
            return try await call(method: "task.deleteBenchmark", params: TaskBenchmarkDeleteParams(benchmarkId: benchmarkID))
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func importLocalTrace(
        traceText: String,
        title: String?,
        taskText: String?,
        expectedSkillNames: [String],
        skill: SkillRecord?
    ) async throws -> AgentTraceImportResult {
        let params = AgentTraceImportParams(
            traceText: traceText,
            title: title,
            task: taskText,
            expectedSkillNames: expectedSkillNames,
            candidateInstanceIDs: skill.map { [$0.id] },
            agent: skill?.agent
        )
        do {
            return try await call(method: "trace.importLocal", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func listTraceImports(limit: Int = 20) async throws -> AgentTraceImportListResult {
        do {
            return try await call(method: "trace.listImports", params: AgentTraceListParams(limit: limit))
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func deleteTraceImport(importID: String) async throws -> AgentTraceImportDeleteResult {
        do {
            return try await call(method: "trace.deleteImport", params: AgentTraceDeleteParams(importID: importID))
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func previewPromptForLLMAction(action: LLMAction, skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: action.rawValue,
            requestKind: "action",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: nil,
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.llmSkillAnalysisUnavailable)
        }
    }

    func previewPromptForSkillAnalysis(
        instanceIDs: [String],
        kind: LLMSkillAnalysisKind,
        scope: LLMSkillAnalysisRequestScope
    ) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "skill_analysis",
            requestKind: "skill_analysis",
            analysisKind: kind,
            scope: scope.key,
            instanceIDs: instanceIDs,
            instanceId: nil,
            definitionId: nil,
            agent: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.llmSkillAnalysisUnavailable)
        }
    }

    func previewPromptForSkillQuality(skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "quality_score",
            requestKind: "quality_score",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.skillQualityPromptUnavailable)
        }
    }

    func previewPromptForTaskReadiness(taskText: String, skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "task_readiness",
            requestKind: "task_readiness",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.taskReadinessPromptUnavailable)
        }
    }

    func previewPromptForRoutingConfidence(taskText: String, skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "routing_confidence",
            requestKind: "routing_confidence",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.routingConfidencePromptUnavailable)
        }
    }

    func confirmPromptAndSendForLLMAction(previewID: String, action: LLMAction, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: action.rawValue,
            requestKind: "action",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: nil,
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForSkillAnalysis(
        previewID: String,
        instanceIDs: [String],
        kind: LLMSkillAnalysisKind,
        scope: LLMSkillAnalysisRequestScope
    ) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "skill_analysis",
            requestKind: "skill_analysis",
            analysisKind: kind,
            scope: scope.key,
            instanceIDs: instanceIDs,
            instanceId: nil,
            definitionId: nil,
            agent: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForSkillQuality(previewID: String, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "quality_score",
            requestKind: "quality_score",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForTaskReadiness(previewID: String, taskText: String, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "task_readiness",
            requestKind: "task_readiness",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForRoutingConfidence(previewID: String, taskText: String, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "routing_confidence",
            requestKind: "routing_confidence",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    private func confirmPromptAndSend(previewID: String, request: PreviewLLMPromptParams) async throws -> LLMPromptSendResult {
        let params = ConfirmLLMPromptParams(
            previewID: previewID,
            confirmationID: "prompt-confirm-\(UUID().uuidString)",
            request: request
        )
        do {
            return try await call(method: "llm.confirmPromptAndSend", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(previewID: previewID, reason: UIStrings.llmSkillAnalysisUnavailable)
        }
    }

    func previewScriptExecution(skill: SkillRecord) async throws -> ScriptExecutionPreview {
        do {
            return try await call(
                method: "script.previewExecution",
                params: ScriptExecutionParams(
                    instanceId: skill.id,
                    definitionId: skill.definitionId,
                    agent: skill.agent
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(skill: skill)
        }
    }

    func scriptExecutionAuditStatus(skill: SkillRecord) async throws -> ScriptExecutionPreview {
        do {
            return try await call(
                method: "script.auditStatus",
                params: ScriptExecutionParams(
                    instanceId: skill.id,
                    definitionId: skill.definitionId,
                    agent: skill.agent
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(skill: skill)
        }
    }

    func scanAll() async throws -> ScanResult {
        try await call(method: "catalog.scanAll", params: EmptyParams())
    }

    func scanClaude() async throws -> ScanResult {
        try await call(method: "catalog.scanClaude", params: EmptyParams())
    }

    func getProjectContext() async throws -> ProjectContextState {
        do {
            return try await call(method: "project.getContext", params: EmptyParams())
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return ProjectContextState(active: nil, recent: [])
        }
    }

    func setProjectContext(rootPath: String, currentCWD: String?, name: String?) async throws -> ProjectContextState {
        try await call(
            method: "project.setContext",
            params: ProjectContextParams(rootPath: rootPath, currentCWD: currentCWD, name: name)
        )
    }

    func clearProjectContext() async throws -> ProjectContextState {
        try await call(method: "project.clearContext", params: EmptyParams())
    }

    func validateProjectContext(rootPath: String, currentCWD: String?, name: String?) async throws -> ProjectContext {
        try await call(
            method: "project.validateContext",
            params: ProjectContextParams(rootPath: rootPath, currentCWD: currentCWD, name: name)
        )
    }

    func getSkill(instanceID: String) async throws -> SkillDetailRecord {
        try await call(
            method: "catalog.getSkill",
            params: GetSkillParams(instanceId: instanceID)
        )
    }

    func listFindings() async throws -> [RuleFindingRecord] {
        try await call(method: "catalog.listFindings", params: EmptyParams())
    }

    func listFindingTriage() async throws -> [FindingTriageRecord] {
        try await call(method: "catalog.listFindingTriage", params: EmptyParams())
    }

    func setFindingTriage(triageKey: String, status: FindingTriageStatus, note: String? = nil) async throws -> FindingTriageRecord {
        try await call(
            method: "catalog.setFindingTriage",
            params: SetFindingTriageParams(triageKey: triageKey, status: status.rawValue, note: note)
        )
    }

    func clearFindingTriage(triageKey: String) async throws -> Bool {
        try await call(
            method: "catalog.clearFindingTriage",
            params: ClearFindingTriageParams(triageKey: triageKey)
        )
    }

    func listRuleTuning() async throws -> [RuleTuningRecord] {
        do {
            let list: RuleTuningList = try await call(method: "rules.listTuning", params: EmptyParams())
            return list.records
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return []
        }
    }

    func setSeverityOverride(ruleId: String, severity: String) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.setSeverityOverride",
            params: SetRuleSeverityOverrideParams(ruleId: ruleId, severity: severity)
        )
        return result.record
    }

    func clearSeverityOverride(ruleId: String) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.clearSeverityOverride",
            params: ClearRuleSeverityOverrideParams(ruleId: ruleId)
        )
        return result.record
    }

    func setSuppression(ruleId: String, scope: RuleTuningScope, findingGroupId: String?, note: String? = nil) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.setSuppression",
            params: SetRuleSuppressionParams(
                ruleId: ruleId,
                scope: scope.rawValue,
                findingGroupId: scope == .findingGroup ? findingGroupId : nil,
                suppressed: true,
                note: note
            )
        )
        return result.record
    }

    func clearSuppression(ruleId: String, scope: RuleTuningScope, findingGroupId: String?) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.clearSuppression",
            params: ClearRuleSuppressionParams(
                ruleId: ruleId,
                scope: scope.rawValue,
                findingGroupId: scope == .findingGroup ? findingGroupId : nil
            )
        )
        return result.record
    }

    func listConflicts() async throws -> [ConflictGroupRecord] {
        try await call(method: "catalog.listConflicts", params: EmptyParams())
    }

    func listSnapshots() async throws -> [ConfigSnapshotRecord] {
        try await call(method: "snapshot.list", params: EmptyParams())
    }

    func listAgentConfigSnapshots(agent: String, scope: String? = nil) async throws -> [ConfigSnapshotRecord] {
        try await call(
            method: "snapshot.listAgentConfig",
            params: ListAgentConfigSnapshotsParams(agent: agent, scope: scope)
        )
    }

    func listSkillEvents(instanceID: String, limit: Int? = nil) async throws -> [SkillEventRecord] {
        try await call(
            method: "skill.listEvents",
            params: ListSkillEventsParams(instanceId: instanceID, limit: limit)
        )
    }

    func toggleSkill(instanceID: String, on: Bool) async throws -> SkillRecord {
        try await call(
            method: "config.toggleSkill",
            params: ToggleSkillParams(instanceId: instanceID, on: on)
        )
    }

    func previewBatchSkillToggles(instanceIDs: [String], on: Bool) async throws -> BatchTogglePreview {
        let params = BatchToggleParams(
            instanceIDs: instanceIDs,
            targetEnabled: on,
            action: BatchToggleAction.from(targetEnabled: on).rawValue,
            previewToken: nil,
            confirmed: false
        )
        do {
            return try await call(method: "batch.previewSkillToggles", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return try await call(method: "batch.previewToggle", params: params)
        }
    }

    func applyBatchSkillToggles(preview: BatchTogglePreview) async throws -> BatchToggleApplyResult {
        let params = BatchToggleParams(
            instanceIDs: preview.affectedSkills.map(\.instanceID),
            targetEnabled: preview.targetEnabled,
            action: preview.action.rawValue,
            previewToken: preview.id,
            confirmed: true
        )
        do {
            return try await call(method: "batch.applySkillToggles", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return try await call(method: "batch.applyToggle", params: params)
        }
    }

    func previewToolInstall(skill: SkillRecord, target: ToolInstallTarget) async throws -> ToolGlobalInstallPreview {
        try await installToolSkill(skill: skill, target: target, confirmed: false)
    }

    func confirmToolInstall(skill: SkillRecord, target: ToolInstallTarget) async throws -> ToolGlobalInstallPreview {
        try await installToolSkill(skill: skill, target: target, confirmed: true)
    }

    private func installToolSkill(skill: SkillRecord, target: ToolInstallTarget, confirmed: Bool) async throws -> ToolGlobalInstallPreview {
        do {
            return try await call(
                method: "skill.install",
                params: ToolInstallPreviewParams(
                    instanceId: skill.id,
                    targetAgent: target.rawValue,
                    targetScope: "agent-global",
                    confirmed: confirmed
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            if confirmed {
                throw ClientError.service(error)
            }
            return try await legacyPreviewToolInstall(skill: skill, target: target)
        }
    }

    private func legacyPreviewToolInstall(skill: SkillRecord, target: ToolInstallTarget) async throws -> ToolGlobalInstallPreview {
        do {
            return try await call(
                method: "tool.previewInstall",
                params: ToolInstallPreviewParams(
                    instanceId: skill.id,
                    targetAgent: target.rawValue,
                    targetScope: "agent-global",
                    confirmed: false
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .localPreview(skill: skill, target: target)
        }
    }

    func readClaudeSettings() async throws -> ConfigDocumentRecord {
        try await call(method: "config.readClaudeSettings", params: EmptyParams())
    }

    func saveClaudeSettings(content: String) async throws -> ConfigDocumentRecord {
        try await call(
            method: "config.saveClaudeSettings",
            params: SaveClaudeSettingsParams(content: content)
        )
    }

    func previewSnapshotRollback(snapshotID: String) async throws -> SnapshotRollbackPreviewRecord {
        try await call(
            method: "snapshot.previewRollback",
            params: SnapshotParams(snapshotId: snapshotID)
        )
    }

    func rollbackSnapshot(snapshotID: String) async throws -> Int {
        try await call(
            method: "snapshot.rollback",
            params: SnapshotParams(snapshotId: snapshotID)
        )
    }

    private func call<ResultPayload: Decodable, Params: Encodable>(
        method: String,
        params: Params
    ) async throws -> ResultPayload {
        let request = ServiceRequest(
            id: UUID().uuidString,
            method: method,
            params: params
        )
        let input = try JSONEncoder().encode(request)
        let output = try await runService(input: input)
        let envelope = try JSONDecoder().decode(ServiceEnvelope<ResultPayload>.self, from: output)
        if envelope.ok, let result = envelope.result {
            return result
        }
        if let error = envelope.error {
            throw ClientError.service(error)
        }
        throw ClientError.invalidOutput(String(data: output, encoding: .utf8) ?? "<binary>")
    }

    private func runService(input: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = try self.resolveServiceURL()

            let stdin = Pipe()
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            stdin.fileHandleForWriting.write(input)
            try stdin.fileHandleForWriting.close()

            let output = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let message = String(data: errorOutput, encoding: .utf8) ?? ""
                throw ClientError.processFailed(process.terminationStatus, message)
            }
            return output
        }.value
    }

    private func resolveServiceURL() throws -> URL {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["SKILLS_COPILOT_SERVICE_PATH"],
           !override.isEmpty {
            let overrideURL = URL(fileURLWithPath: override)
            if FileManager.default.isExecutableFile(atPath: overrideURL.path) {
                return overrideURL
            }
        }
        #endif
        if let url = Bundle.main.url(forResource: "skills-copilot-service", withExtension: nil) {
            return url
        }
        throw ClientError.missingBinary
    }
}
