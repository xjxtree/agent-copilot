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

struct EmptyParams: Encodable {}

struct CleanupListQueueParams: Encodable {
    let agent: String?
    let limit: Int?
}

struct CrossAgentComparisonParams: Encodable {
    let agent: String?
    let instanceId: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case agent
        case instanceId = "instance_id"
        case limit
    }
}

struct LocalReportExportParams: Encodable {
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

struct GetSkillParams: Encodable {
    let instanceId: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
    }
}

struct ToggleSkillParams: Encodable {
    let instanceId: String
    let on: Bool

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case on
    }
}

struct ReadAgentConfigParams: Encodable {
    let agent: String
    let scope: String?
}

struct BatchToggleParams: Encodable {
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

struct ToolInstallPreviewParams: Encodable {
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

struct PrepareSkillAnalysisParams: Encodable {
    let instanceIDs: [String]
    let analysisKind: LLMSkillAnalysisKind

    enum CodingKeys: String, CodingKey {
        case instanceIDs = "instance_ids"
        case analysisKind = "analysis_kind"
    }
}

struct ScoreSkillQualityParams: Encodable {
    let instanceId: String
    let definitionId: String
    let agent: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
    }
}

struct TaskReadinessParams: Encodable {
    let task: String
    let agent: String?
    let candidateInstanceIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case candidateInstanceIDs = "candidate_instance_ids"
    }
}

struct TaskRoutingConfidenceParams: Encodable {
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

struct CrossAgentReadinessParams: Encodable {
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

struct TaskCockpitParams: Encodable {
    let task: String
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let candidateInstanceIDs: [String]?
    let limit: Int?
    let includeSessionReview: Bool
    let includeProviderObservability: Bool
    let includeRemediationContext: Bool
    let includeEvidence: Bool
    let appLanguage: String = UIStrings.currentLanguage.rawValue

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
        case candidateInstanceIDs = "candidate_instance_ids"
        case limit
        case includeSessionReview = "include_session_review"
        case includeProviderObservability = "include_provider_observability"
        case includeRemediationContext = "include_remediation_context"
        case includeEvidence = "include_evidence"
        case appLanguage = "app_language"
    }
}

struct TaskBenchmarkListParams: Encodable {
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case limit
    }
}

struct TaskBenchmarkSaveParams: Encodable {
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

struct TaskBenchmarkEvaluateParams: Encodable {
    let benchmarkIDs: [String]?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case benchmarkIDs = "benchmark_ids"
        case limit
    }
}

struct RoutingRegressionParams: Encodable {
    let benchmarkIDs: [String]?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case benchmarkIDs = "benchmark_ids"
        case limit
    }
}

struct RoutingAccuracyDashboardParams: Encodable {
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

struct StaleDriftDetectionParams: Encodable {
    let agent: String?
    let limit: Int?
    let includeReadinessImpact: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case limit
        case includeReadinessImpact = "include_readiness_impact"
    }
}

struct KnowledgeSearchParams: Encodable {
    let query: String
    let agent: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case query
        case agent
        case limit
    }
}

struct LocalSkillMapParams: Encodable {
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let limit: Int?
    let includeEdges: Bool
    let includeClusters: Bool
    let includeEvidence: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case selectedSkillID = "selected_skill_id"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillPath = "selected_skill_path"
        case limit
        case includeEdges = "include_edges"
        case includeClusters = "include_clusters"
        case includeEvidence = "include_evidence"
    }
}

struct SkillLifecycleTimelineParams: Encodable {
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let candidateInstanceIDs: [String]?
    let limit: Int?
    let includeSkillRows: Bool
    let includeAgentRows: Bool
    let includeEvidence: Bool
    let includeSafetyFlags: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case selectedSkillID = "selected_skill_id"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillPath = "selected_skill_path"
        case candidateInstanceIDs = "candidate_instance_ids"
        case limit
        case includeSkillRows = "include_skill_rows"
        case includeAgentRows = "include_agent_rows"
        case includeEvidence = "include_evidence"
        case includeSafetyFlags = "include_safety_flags"
    }
}

struct SimilarSkillGroupingParams: Encodable {
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

struct CapabilityTaxonomyParams: Encodable {
    let agent: String?
    let limit: Int?
    let includeSingleSkillDomains: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case limit
        case includeSingleSkillDomains = "include_single_skill_domains"
    }
}

struct WorkspaceReadinessParams: Encodable {
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

struct RemediationPlanParams: Encodable {
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

struct RemediationPreviewDraftsParams: Encodable {
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

struct RemediationImpactPreviewParams: Encodable {
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

struct RemediationBatchReviewParams: Encodable {
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

struct RemediationHistoryListParams: Encodable {
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
    }
}

struct RemediationHistoryRecordParams: Encodable {
    let task: String?
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let decision: String
    let status: String
    let sourceMethod: String
    let reviewArea: String
    let note: String
    let evidenceRefs: [String]
    let safetyFlags: [String]

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
        case decision
        case status
        case sourceMethod = "source_method"
        case reviewArea = "review_area"
        case note
        case evidenceRefs = "evidence_refs"
        case safetyFlags = "safety_flags"
    }
}

struct GuidedCleanupFlowParams: Encodable {
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
    let includeIssueGroups: Bool
    let includeSafeNextActions: Bool
    let includeRecordedSteps: Bool
    let includeEvidence: Bool
    let includeSafetyFlags: Bool
    let appLanguage: String = UIStrings.currentLanguage.rawValue

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
        case includeIssueGroups = "include_issue_groups"
        case includeSafeNextActions = "include_safe_next_actions"
        case includeRecordedSteps = "include_recorded_steps"
        case includeEvidence = "include_evidence"
        case includeSafetyFlags = "include_safety_flags"
        case appLanguage = "app_language"
    }
}

struct GuidedCleanupRecordStepParams: Encodable {
    let task: String?
    let agent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let stepID: String
    let stepTitle: String
    let stepKind: String
    let actionLabel: String
    let sourceMethod: String
    let note: String
    let evidenceRefs: [String]
    let safetyFlags: [String]

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
        case stepID = "step_id"
        case stepTitle = "step_title"
        case stepKind = "step_kind"
        case actionLabel = "action_label"
        case sourceMethod = "source_method"
        case note
        case evidenceRefs = "evidence_refs"
        case safetyFlags = "safety_flags"
    }
}

struct TaskBenchmarkDeleteParams: Encodable {
    let benchmarkId: String

    enum CodingKeys: String, CodingKey {
        case benchmarkId = "benchmark_id"
    }
}

struct AgentTraceImportParams: Encodable {
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

struct AgentTraceListParams: Encodable {
    let limit: Int?
}

struct AgentTraceDeleteParams: Encodable {
    let importID: String

    enum CodingKeys: String, CodingKey {
        case importID = "import_id"
    }
}

struct AgentSessionSkillReviewParams: Encodable {
    let transcriptText: String
    let task: String?
    let expectedSkillNames: [String]
    let candidateInstanceIDs: [String]?
    let agent: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?

    enum CodingKeys: String, CodingKey {
        case transcriptText = "transcript_text"
        case task
        case expectedSkillNames = "expected_skill_names"
        case candidateInstanceIDs = "candidate_instance_ids"
        case agent
        case selectedSkillID = "selected_skill_id"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillPath = "selected_skill_path"
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
    }
}

struct AgentSessionSkillReviewListParams: Encodable {
    let task: String?
    let agent: String?
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let selectedSkillPath: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case task
        case agent
        case selectedSkillID = "selected_skill_id"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillPath = "selected_skill_path"
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case workspace
        case limit
    }
}

struct AgentSessionSkillReviewDeleteParams: Encodable {
    let reviewID: String

    enum CodingKeys: String, CodingKey {
        case reviewID = "review_id"
    }
}

struct LocalSessionPreviewParams: Encodable {
    let authorizedRoots: [String]
    let autoDiscover: Bool?
    let agent: String?
    let scope: String?
    let search: String?
    let projectRoot: String?
    let currentCWD: String?
    let limit: Int?
    let maxFiles: Int?
    let maxExcerptChars: Int?

    enum CodingKeys: String, CodingKey {
        case authorizedRoots = "authorized_roots"
        case autoDiscover = "auto_discover"
        case agent
        case scope
        case search
        case projectRoot = "project_root"
        case currentCWD = "current_cwd"
        case limit
        case maxFiles = "max_files"
        case maxExcerptChars = "max_excerpt_chars"
    }
}

struct PrepareLLMActionParams: Encodable {
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

struct PreviewLLMPromptParams: Encodable {
    let action: String
    let requestKind: String
    let analysisKind: LLMSkillAnalysisKind?
    let scope: String?
    let instanceIDs: [String]?
    let instanceId: String?
    let definitionId: String?
    let agent: String?
    let agents: [String]?
    let taskText: String?
    let userIntent: String?
    let candidateInstanceIDs: [String]?
    let appLanguage: String = UIStrings.currentLanguage.rawValue

    enum CodingKeys: String, CodingKey {
        case action
        case requestKind = "request_kind"
        case analysisKind = "analysis_kind"
        case scope
        case instanceIDs = "instance_ids"
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
        case agents
        case taskText = "task_text"
        case userIntent = "user_intent"
        case candidateInstanceIDs = "candidate_instance_ids"
        case appLanguage = "app_language"
    }
}

struct ConfirmLLMPromptParams: Encodable {
    let previewID: String
    let confirmationID: String
    let request: PreviewLLMPromptParams
    let timeoutMS: Int

    enum CodingKeys: String, CodingKey {
        case previewID = "preview_id"
        case confirmationID = "confirmation_id"
        case request
        case timeoutMS = "timeout_ms"
    }
}

struct ListLLMPromptRunsParams: Encodable {
    let instanceId: String?
    let action: String?
    let requestKind: String?
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case action
        case requestKind = "request_kind"
        case limit
    }
}

struct ProviderObservabilityParams: Encodable {
    let windowDays: Int
    let limit: Int
    let includeHistory: Bool
    let includeBudgetHints: Bool
    let includeRetentionRecommendations: Bool
    let includeEvidence: Bool
    let appLanguage: String = UIStrings.currentLanguage.rawValue

    enum CodingKeys: String, CodingKey {
        case windowDays = "window_days"
        case limit
        case includeHistory = "include_history"
        case includeBudgetHints = "include_budget_hints"
        case includeRetentionRecommendations = "include_retention_recommendations"
        case includeEvidence = "include_evidence"
        case appLanguage = "app_language"
    }
}

struct ScriptExecutionParams: Encodable {
    let instanceId: String
    let definitionId: String
    let agent: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
    }
}

struct SnapshotParams: Encodable {
    let snapshotId: String

    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
    }
}

struct ListAgentConfigSnapshotsParams: Encodable {
    let agent: String
    let scope: String?
}

struct ListSkillEventsParams: Encodable {
    let instanceId: String
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case limit
    }
}

struct SetFindingTriageParams: Encodable {
    let triageKey: String
    let status: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case triageKey = "triage_key"
        case status
        case note
    }
}

struct ClearFindingTriageParams: Encodable {
    let triageKey: String

    enum CodingKeys: String, CodingKey {
        case triageKey = "triage_key"
    }
}

struct SetRuleSeverityOverrideParams: Encodable {
    let ruleId: String
    let severity: String

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case severity
    }
}

struct ClearRuleSeverityOverrideParams: Encodable {
    let ruleId: String

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
    }
}

struct SetRuleSuppressionParams: Encodable {
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

struct ClearRuleSuppressionParams: Encodable {
    let ruleId: String
    let scope: String
    let findingGroupId: String?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case scope
        case findingGroupId = "finding_group_id"
    }
}

struct SaveClaudeSettingsParams: Encodable {
    let content: String
}

struct SaveAIProviderProfileParams: Encodable {
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

struct TestAIProviderConnectionParams: Encodable {
    let profileID: String
    let confirmationID: String
    let timeoutMS: Int

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case confirmationID = "confirmation_id"
        case timeoutMS = "timeout_ms"
    }
}

struct ProjectContextParams: Encodable {
    let rootPath: String
    let currentCWD: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case rootPath = "root_path"
        case currentCWD = "current_cwd"
        case name
    }
}

final class ServiceClient {
    enum ClientError: LocalizedError {
        case missingBinary
        case invalidOutput(String)
        case service(ServiceErrorPayload)
        case processFailed(Int32, String)
        case processTimedOut

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
            case .processTimedOut:
                return UIStrings.text(
                    "service.error.sidecarTimedOut",
                    "Service call timed out before the sidecar returned a complete response."
                )
            }
        }
    }

    let processRunner: ServiceProcessRunning
    let serviceURLOverride: URL?

    init(
        processRunner: ServiceProcessRunning = StdioServiceProcessRunner(),
        serviceURL: URL? = nil
    ) {
        self.processRunner = processRunner
        serviceURLOverride = serviceURL ?? Self.configuredServiceURLFromEnvironment()
    }

    private static func configuredServiceURLFromEnvironment() -> URL? {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["SKILLS_COPILOT_SERVICE_PATH"],
           !override.isEmpty {
            let overrideURL = URL(fileURLWithPath: override)
            if FileManager.default.isExecutableFile(atPath: overrideURL.path) {
                return overrideURL
            }
        }
        #endif
        return nil
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


}
