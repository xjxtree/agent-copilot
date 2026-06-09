import Foundation

struct SkillRecord: Codable, Identifiable, Hashable {
    let id: String
    let agent: String
    let scope: String
    let path: String
    let displayPath: String
    let definitionId: String
    let name: String
    let state: String
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case agent
        case scope
        case path
        case displayPath = "display_path"
        case definitionId = "definition_id"
        case name
        case state
        case enabled
    }
}

struct SkillDetailRecord: Codable, Identifiable, Hashable {
    let id: String
    let agent: String
    let scope: String
    let path: String
    let displayPath: String
    let definitionId: String
    let name: String
    let description: String
    let state: String
    let enabled: Bool
    let frontmatterRaw: String
    let body: String
    let permissions: JSONValue
    let fingerprint: String

    enum CodingKeys: String, CodingKey {
        case id
        case agent
        case scope
        case path
        case displayPath = "display_path"
        case definitionId = "definition_id"
        case name
        case description
        case state
        case enabled
        case frontmatterRaw = "frontmatter_raw"
        case body
        case permissions
        case fingerprint
    }
}

enum LLMAction: String, Codable, CaseIterable, Identifiable, Hashable {
    case analyze
    case recommend
    case explainConflict = "explain_conflict"
    case draftFrontmatter = "draft_frontmatter"

    var id: String { rawValue }
}

struct LLMStatus: Codable, Hashable {
    let enabled: Bool
    let provider: String?
    let model: String?
    let disabledReason: String?
    let supportedActions: [LLMAction]

    enum CodingKeys: String, CodingKey {
        case enabled
        case provider
        case model
        case disabledReason = "disabled_reason"
        case reason
        case supportedActions = "supported_actions"
    }

    init(
        enabled: Bool,
        provider: String?,
        model: String?,
        disabledReason: String?,
        supportedActions: [LLMAction]
    ) {
        self.enabled = enabled
        self.provider = provider
        self.model = model
        self.disabledReason = disabledReason
        self.supportedActions = supportedActions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        disabledReason = try container.decodeIfPresent(String.self, forKey: .disabledReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
        supportedActions = try container.decodeIfPresent([LLMAction].self, forKey: .supportedActions)
            ?? LLMAction.allCases
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(disabledReason, forKey: .disabledReason)
        try container.encode(supportedActions, forKey: .supportedActions)
    }

    static func disabledFallback(reason: String = UIStrings.llmDisabledFallback) -> LLMStatus {
        LLMStatus(
            enabled: false,
            provider: nil,
            model: nil,
            disabledReason: reason,
            supportedActions: LLMAction.allCases
        )
    }
}

struct LLMTokenCostEstimate: Codable, Hashable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let estimatedCostUSD: Double?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case estimatedCostUSD = "estimated_cost_usd"
    }
}

struct LLMPrepareResult: Codable, Identifiable, Hashable {
    let action: LLMAction
    let enabled: Bool
    let disabledReason: String?
    let provider: String?
    let model: String?
    let estimate: LLMTokenCostEstimate?
    let confirmationRequired: Bool

    var id: LLMAction { action }

    enum CodingKeys: String, CodingKey {
        case action
        case enabled
        case allowed
        case disabledReason = "disabled_reason"
        case provider
        case model
        case estimate
        case estimatedInputTokens = "estimated_input_tokens"
        case estimatedOutputTokens = "estimated_output_tokens"
        case estimatedTotalTokens = "estimated_total_tokens"
        case estimatedCostUSD = "estimated_cost_usd"
        case confirmationRequired = "confirmation_required"
        case requiresConfirmation = "requires_confirmation"
    }

    init(
        action: LLMAction,
        enabled: Bool,
        disabledReason: String?,
        provider: String?,
        model: String?,
        estimate: LLMTokenCostEstimate?,
        confirmationRequired: Bool
    ) {
        self.action = action
        self.enabled = enabled
        self.disabledReason = disabledReason
        self.provider = provider
        self.model = model
        self.estimate = estimate
        self.confirmationRequired = confirmationRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(LLMAction.self, forKey: .action)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .allowed)
            ?? false
        disabledReason = try container.decodeIfPresent(String.self, forKey: .disabledReason)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        model = try container.decodeIfPresent(String.self, forKey: .model)

        if let nestedEstimate = try container.decodeIfPresent(LLMTokenCostEstimate.self, forKey: .estimate) {
            estimate = nestedEstimate
        } else if
            let input = try container.decodeIfPresent(Int.self, forKey: .estimatedInputTokens),
            let output = try container.decodeIfPresent(Int.self, forKey: .estimatedOutputTokens),
            let total = try container.decodeIfPresent(Int.self, forKey: .estimatedTotalTokens)
        {
            estimate = LLMTokenCostEstimate(
                inputTokens: input,
                outputTokens: output,
                totalTokens: total,
                estimatedCostUSD: try container.decodeIfPresent(Double.self, forKey: .estimatedCostUSD)
            )
        } else {
            estimate = nil
        }

        confirmationRequired = try container.decodeIfPresent(Bool.self, forKey: .confirmationRequired)
            ?? container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation)
            ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(disabledReason, forKey: .disabledReason)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(estimate, forKey: .estimate)
        try container.encode(confirmationRequired, forKey: .confirmationRequired)
    }

    static func disabledFallback(action: LLMAction, reason: String = UIStrings.llmDisabledFallback) -> LLMPrepareResult {
        LLMPrepareResult(
            action: action,
            enabled: false,
            disabledReason: reason,
            provider: nil,
            model: nil,
            estimate: nil,
            confirmationRequired: true
        )
    }
}

struct RuleFindingRecord: Codable, Identifiable, Hashable {
    let id: String
    let instanceId: String?
    let definitionId: String?
    let ruleId: String
    let severity: String
    let message: String
    let suggestion: String?
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case ruleId = "rule_id"
        case severity
        case message
        case suggestion
        case createdAt = "created_at"
    }
}

struct ConflictGroupRecord: Codable, Identifiable, Hashable {
    let id: String
    let definitionId: String
    let reason: String
    let winnerId: String?
    let instanceIds: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case definitionId = "definition_id"
        case reason
        case winnerId = "winner_id"
        case instanceIds = "instance_ids"
    }
}

struct SkillHealthSummary: Codable, Hashable {
    let totalCount: Int
    let enabledCount: Int
    let disabledCount: Int
    let brokenCount: Int
    let missingCount: Int
    let malformedCount: Int
    let findingCount: Int
    let conflictCount: Int
    let riskyScriptCount: Int
    let riskyPermissionCount: Int
    let findingsBySeverity: HealthSeverityCounts
    let analysisGroups: HealthAnalysisGroupCounts
    let agentSummaries: [AgentSkillHealthSummary]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case enabledCount = "enabled_count"
        case disabledCount = "disabled_count"
        case brokenCount = "broken_count"
        case missingCount = "missing_count"
        case malformedCount = "malformed_count"
        case findingCount = "finding_count"
        case conflictCount = "conflict_count"
        case riskyScriptCount = "risky_script_count"
        case riskyPermissionCount = "risky_permission_count"
        case findingsBySeverity = "findings_by_severity"
        case analysisGroups = "analysis_groups"
        case agentSummaries = "agent_summaries"
    }

    var riskCount: Int {
        riskyScriptCount + riskyPermissionCount
    }

    var needsTriageCount: Int {
        findingsBySeverity.errorCount
            + findingsBySeverity.warningCount
            + conflictCount
            + malformedCount
            + riskCount
    }

    static let empty = SkillHealthSummary(
        totalCount: 0,
        enabledCount: 0,
        disabledCount: 0,
        brokenCount: 0,
        missingCount: 0,
        malformedCount: 0,
        findingCount: 0,
        conflictCount: 0,
        riskyScriptCount: 0,
        riskyPermissionCount: 0,
        findingsBySeverity: .empty,
        analysisGroups: .empty,
        agentSummaries: []
    )
}

struct HealthSeverityCounts: Codable, Hashable {
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int

    enum CodingKeys: String, CodingKey {
        case errorCount = "error_count"
        case warningCount = "warning_count"
        case infoCount = "info_count"
    }

    static let empty = HealthSeverityCounts(errorCount: 0, warningCount: 0, infoCount: 0)
}

struct HealthAnalysisGroupCounts: Codable, Hashable {
    let totalCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let duplicateNameCount: Int
    let canonicalNameCount: Int
    let pathOverlapCount: Int
    let enabledMismatchCount: Int
    let malformedCount: Int
    let precedenceCount: Int

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case errorCount = "error_count"
        case warningCount = "warning_count"
        case infoCount = "info_count"
        case duplicateNameCount = "duplicate_name_count"
        case canonicalNameCount = "canonical_name_count"
        case pathOverlapCount = "path_overlap_count"
        case enabledMismatchCount = "enabled_mismatch_count"
        case malformedCount = "malformed_count"
        case precedenceCount = "precedence_count"
    }

    static let empty = HealthAnalysisGroupCounts(
        totalCount: 0,
        errorCount: 0,
        warningCount: 0,
        infoCount: 0,
        duplicateNameCount: 0,
        canonicalNameCount: 0,
        pathOverlapCount: 0,
        enabledMismatchCount: 0,
        malformedCount: 0,
        precedenceCount: 0
    )
}

struct AgentSkillHealthSummary: Codable, Identifiable, Hashable {
    let agent: String
    let totalCount: Int
    let enabledCount: Int
    let disabledCount: Int
    let brokenCount: Int
    let missingCount: Int
    let malformedCount: Int
    let findingCount: Int
    let conflictCount: Int
    let riskyScriptCount: Int
    let riskyPermissionCount: Int
    let analysisGroupCount: Int

    var id: String { agent }

    enum CodingKeys: String, CodingKey {
        case agent
        case totalCount = "total_count"
        case enabledCount = "enabled_count"
        case disabledCount = "disabled_count"
        case brokenCount = "broken_count"
        case missingCount = "missing_count"
        case malformedCount = "malformed_count"
        case findingCount = "finding_count"
        case conflictCount = "conflict_count"
        case riskyScriptCount = "risky_script_count"
        case riskyPermissionCount = "risky_permission_count"
        case analysisGroupCount = "analysis_group_count"
    }

    var riskCount: Int {
        riskyScriptCount + riskyPermissionCount
    }
}

struct ConfigSnapshotRecord: Codable, Identifiable, Hashable {
    let id: String
    let agent: String
    let scope: String
    let target: String
    let content: String
    let reason: String
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case agent
        case scope
        case target
        case content
        case reason
        case createdAt = "created_at"
    }
}

struct SkillEventRecord: Codable, Identifiable, Hashable {
    let id: Int64
    let instanceId: String
    let kind: String
    let payload: JSONValue
    let occurredAt: Int64

    var isToggleActivity: Bool {
        let normalized = kind.lowercased()
        return normalized.contains("toggle")
            || normalized.contains("enable")
            || normalized.contains("disable")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case instanceId = "instance_id"
        case kind
        case payload
        case occurredAt = "occurred_at"
    }
}

struct AdapterCapabilityRecord: Codable, Identifiable, Hashable {
    let agent: String
    let displayName: String
    let status: String
    let scan: AdapterFeatureCapability
    let projectScan: AdapterFeatureCapability
    let configToggle: AdapterFeatureCapability
    let configSnapshot: AdapterFeatureCapability
    let install: AdapterFeatureCapability
    let writable: AdapterFeatureCapability
    let blockers: [String]

    var id: String { agent }

    enum CodingKeys: String, CodingKey {
        case agent
        case displayName = "display_name"
        case status
        case scan
        case projectScan = "project_scan"
        case configToggle = "config_toggle"
        case configSnapshot = "config_snapshot"
        case install
        case writable
        case blockers
    }
}

struct AdapterFeatureCapability: Codable, Hashable {
    let supported: Bool
    let status: String
    let reason: String?
}

struct ScanResult: Codable, Hashable {
    let scannedCount: Int
    let skills: [SkillRecord]
    let activity: RefreshActivity?

    enum CodingKeys: String, CodingKey {
        case scannedCount = "scanned_count"
        case skills
        case activity
    }
}

struct RefreshActivity: Codable, Hashable {
    let operation: String
    let status: String
    let startedAt: Int64
    let finishedAt: Int64
    let scannedCount: Int
    let skillCount: Int
    let findingCount: Int
    let conflictCount: Int
    let snapshotCount: Int
    let roots: [String]
    let logEntries: [RefreshLogEntry]
    let recoveryActions: [String]

    enum CodingKeys: String, CodingKey {
        case operation
        case status
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case scannedCount = "scanned_count"
        case skillCount = "skill_count"
        case findingCount = "finding_count"
        case conflictCount = "conflict_count"
        case snapshotCount = "snapshot_count"
        case roots
        case logEntries = "log_entries"
        case recoveryActions = "recovery_actions"
    }
}

struct RefreshLogEntry: Codable, Hashable, Identifiable {
    let level: String
    let message: String

    var id: String { "\(level):\(message)" }
}

struct SnapshotRollbackPreviewRecord: Codable, Identifiable, Hashable {
    let snapshot: ConfigSnapshotRecord
    let currentContent: String
    let currentReadError: String?
    let changed: Bool

    var id: String { snapshot.id }

    enum CodingKeys: String, CodingKey {
        case snapshot
        case currentContent = "current_content"
        case currentReadError = "current_read_error"
        case changed
    }
}

struct ConfigDocumentRecord: Codable, Hashable {
    let agent: String
    let scope: String
    let target: String
    let format: String
    let content: String
    let exists: Bool
}

struct ServiceStatus: Codable, Hashable {
    let protocolVersion: Int
    let version: String
    let appDataDir: String
    let catalogPath: String
    let userHome: String
    let supportedMethods: [String]
    let refresh: RefreshStatus?
    let adapterCapabilities: [AdapterCapabilityRecord]?

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case version
        case appDataDir = "app_data_dir"
        case catalogPath = "catalog_path"
        case userHome = "user_home"
        case supportedMethods = "supported_methods"
        case refresh
        case adapterCapabilities = "adapter_capabilities"
    }
}

struct RefreshStatus: Codable, Hashable {
    let scanProgress: String
    let watcherState: String
    let watcherDetail: String
    let recoveryActions: [String]

    enum CodingKeys: String, CodingKey {
        case scanProgress = "scan_progress"
        case watcherState = "watcher_state"
        case watcherDetail = "watcher_detail"
        case recoveryActions = "recovery_actions"
    }
}

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
