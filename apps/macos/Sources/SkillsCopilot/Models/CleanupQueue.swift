import Foundation

enum CleanupQueueKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case finding
    case integrity
    case conflict
    case analysis
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finding: return UIStrings.cleanupKindFinding
        case .integrity: return UIStrings.cleanupKindIntegrity
        case .conflict: return UIStrings.cleanupKindConflict
        case .analysis: return UIStrings.cleanupKindAnalysis
        case .unknown: return UIStrings.unknown
        }
    }

    var systemImage: String {
        switch self {
        case .finding: return "exclamationmark.triangle"
        case .integrity: return "checklist.unchecked"
        case .conflict: return "arrow.triangle.2.circlepath"
        case .analysis: return "sparkle.magnifyingglass"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum CleanupQueuePriority: String, CaseIterable, Codable, Identifiable, Hashable {
    case critical
    case high
    case medium
    case low
    case info
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .critical: return UIStrings.cleanupPriorityCritical
        case .high: return UIStrings.cleanupPriorityHigh
        case .medium: return UIStrings.cleanupPriorityMedium
        case .low: return UIStrings.cleanupPriorityLow
        case .info: return UIStrings.cleanupPriorityInfo
        case .unknown: return UIStrings.unknown
        }
    }

    var rank: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .info: return 4
        case .unknown: return 5
        }
    }
}

enum CleanupQueueKindFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case finding
    case integrity
    case conflict
    case analysis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return UIStrings.cleanupFilterAllKinds
        case .finding: return CleanupQueueKind.finding.title
        case .integrity: return CleanupQueueKind.integrity.title
        case .conflict: return CleanupQueueKind.conflict.title
        case .analysis: return CleanupQueueKind.analysis.title
        }
    }

    func includes(_ kind: CleanupQueueKind) -> Bool {
        switch self {
        case .all: return true
        case .finding: return kind == .finding
        case .integrity: return kind == .integrity
        case .conflict: return kind == .conflict
        case .analysis: return kind == .analysis
        }
    }
}

enum CleanupQueuePriorityFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case criticalHigh
    case medium
    case lowInfo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return UIStrings.cleanupFilterAllPriorities
        case .criticalHigh: return UIStrings.cleanupFilterCriticalHigh
        case .medium: return CleanupQueuePriority.medium.title
        case .lowInfo: return UIStrings.cleanupFilterLowInfo
        }
    }

    func includes(_ priority: CleanupQueuePriority) -> Bool {
        switch self {
        case .all: return true
        case .criticalHigh: return priority == .critical || priority == .high
        case .medium: return priority == .medium
        case .lowInfo: return priority == .low || priority == .info || priority == .unknown
        }
    }
}

struct CleanupQueueSummary: Decodable, Hashable {
    let total: Int
    let findingCount: Int
    let integrityCount: Int
    let conflictCount: Int
    let analysisCount: Int
    let readOnly: Bool
    let unavailableReason: String?

    static let empty = CleanupQueueSummary(total: 0, findingCount: 0, integrityCount: 0, conflictCount: 0, analysisCount: 0, readOnly: true, unavailableReason: nil)

    enum CodingKeys: String, CodingKey {
        case total
        case totalCount = "total_count"
        case findingCount = "finding_count"
        case integrityCount = "integrity_count"
        case conflictCount = "conflict_count"
        case analysisCount = "analysis_count"
        case countsByKind = "counts_by_kind"
        case readOnly = "read_only"
        case unavailableReason = "unavailable_reason"
    }

    init(total: Int, findingCount: Int, integrityCount: Int, conflictCount: Int, analysisCount: Int, readOnly: Bool, unavailableReason: String?) {
        self.total = total
        self.findingCount = findingCount
        self.integrityCount = integrityCount
        self.conflictCount = conflictCount
        self.analysisCount = analysisCount
        self.readOnly = readOnly
        self.unavailableReason = unavailableReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let counts = try container.decodeIfPresent([String: Int].self, forKey: .countsByKind) ?? [:]
        total = try container.decodeIfPresent(Int.self, forKey: .total)
            ?? container.decodeIfPresent(Int.self, forKey: .totalCount)
            ?? counts.values.reduce(0, +)
        findingCount = try container.decodeIfPresent(Int.self, forKey: .findingCount) ?? counts["finding"] ?? 0
        integrityCount = try container.decodeIfPresent(Int.self, forKey: .integrityCount) ?? counts["integrity"] ?? 0
        conflictCount = try container.decodeIfPresent(Int.self, forKey: .conflictCount) ?? counts["conflict"] ?? 0
        analysisCount = try container.decodeIfPresent(Int.self, forKey: .analysisCount) ?? counts["analysis"] ?? 0
        readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly) ?? true
        unavailableReason = try container.decodeIfPresent(String.self, forKey: .unavailableReason)
    }
}

struct CleanupQueueItem: Decodable, Identifiable, Hashable {
    let id: String
    let kind: CleanupQueueKind
    let priority: CleanupQueuePriority
    let agent: String?
    let skillID: String?
    let skillName: String?
    let skillScope: String?
    let title: String
    let detail: String
    let nextActionLabel: String
    let readOnly: Bool
    let scriptExecutionBlocked: Bool
    let aiProviderCallBlocked: Bool
    let credentialStorageBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case priority
        case severity
        case agent
        case skillID = "skill_id"
        case skillName = "skill_name"
        case skillScope = "skill_scope"
        case scope
        case title
        case detail
        case recommendedNextActionLabel = "recommended_next_action_label"
        case nextActionLabel = "next_action_label"
        case nextAction = "next_action"
        case readOnly = "read_only"
        case writesAllowed = "writes_allowed"
        case providerRequestSent = "provider_request_sent"
        case scriptExecutionBlocked = "script_execution_blocked"
        case aiProviderCallBlocked = "ai_provider_call_blocked"
        case credentialStorageBlocked = "credential_storage_blocked"
    }

    init(id: String, kind: CleanupQueueKind, priority: CleanupQueuePriority, agent: String?, skillID: String?, skillName: String?, skillScope: String?, title: String, detail: String, nextActionLabel: String, readOnly: Bool = true, scriptExecutionBlocked: Bool = true, aiProviderCallBlocked: Bool = true, credentialStorageBlocked: Bool = true) {
        self.id = id
        self.kind = kind
        self.priority = priority
        self.agent = agent
        self.skillID = skillID
        self.skillName = skillName
        self.skillScope = skillScope
        self.title = title
        self.detail = detail
        self.nextActionLabel = nextActionLabel
        self.readOnly = readOnly
        self.scriptExecutionBlocked = scriptExecutionBlocked
        self.aiProviderCallBlocked = aiProviderCallBlocked
        self.credentialStorageBlocked = credentialStorageBlocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = Self.decodeKind(try container.decodeIfPresent(String.self, forKey: .kind))
        priority = Self.decodePriority(try container.decodeIfPresent(String.self, forKey: .priority) ?? container.decodeIfPresent(String.self, forKey: .severity))
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        skillID = try container.decodeIfPresent(String.self, forKey: .skillID)
        skillName = try container.decodeIfPresent(String.self, forKey: .skillName)
        skillScope = try container.decodeIfPresent(String.self, forKey: .skillScope) ?? container.decodeIfPresent(String.self, forKey: .scope)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? UIStrings.cleanupUntitledItem
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        nextActionLabel = try container.decodeIfPresent(String.self, forKey: .recommendedNextActionLabel)
            ?? container.decodeIfPresent(String.self, forKey: .nextActionLabel)
            ?? container.decodeIfPresent(String.self, forKey: .nextAction)
            ?? UIStrings.cleanupDefaultNextAction
        readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly) ?? true
        let writesAllowed = try container.decodeIfPresent(Bool.self, forKey: .writesAllowed) ?? false
        let providerRequestSent = try container.decodeIfPresent(Bool.self, forKey: .providerRequestSent) ?? false
        scriptExecutionBlocked = try container.decodeIfPresent(Bool.self, forKey: .scriptExecutionBlocked) ?? !writesAllowed
        aiProviderCallBlocked = try container.decodeIfPresent(Bool.self, forKey: .aiProviderCallBlocked) ?? !providerRequestSent
        credentialStorageBlocked = try container.decodeIfPresent(Bool.self, forKey: .credentialStorageBlocked) ?? true
    }

    private static func decodeKind(_ value: String?) -> CleanupQueueKind {
        switch normalize(value) {
        case "finding", "findings": return .finding
        case "integrity", "health": return .integrity
        case "conflict", "conflicts": return .conflict
        case "analysis", "insight", "insights": return .analysis
        default: return .unknown
        }
    }

    private static func decodePriority(_ value: String?) -> CleanupQueuePriority {
        switch normalize(value) {
        case "critical", "error", "blocker": return .critical
        case "high": return .high
        case "medium", "warning": return .medium
        case "low": return .low
        case "info", "informational": return .info
        default: return .unknown
        }
    }

    private static func normalize(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "_", with: "-")
    }
}

struct CleanupQueueResult: Decodable, Hashable {
    let summary: CleanupQueueSummary
    let items: [CleanupQueueItem]
    let readOnly: Bool
    let fallbackReason: String?

    static func emptyFallback(reason: String? = nil) -> CleanupQueueResult {
        CleanupQueueResult(
            summary: CleanupQueueSummary(total: 0, findingCount: 0, integrityCount: 0, conflictCount: 0, analysisCount: 0, readOnly: true, unavailableReason: reason),
            items: [],
            readOnly: true,
            fallbackReason: reason
        )
    }

    enum CodingKeys: String, CodingKey {
        case summary
        case items
        case queue
        case readOnly = "read_only"
        case fallbackReason = "fallback_reason"
    }

    init(summary: CleanupQueueSummary, items: [CleanupQueueItem], readOnly: Bool, fallbackReason: String?) {
        self.summary = summary
        self.items = items
        self.readOnly = readOnly
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedItems = try container.decodeIfPresent([CleanupQueueItem].self, forKey: .items) ?? container.decodeIfPresent([CleanupQueueItem].self, forKey: .queue) ?? []
        items = decodedItems.sorted {
            if $0.priority.rank != $1.priority.rank {
                return $0.priority.rank < $1.priority.rank
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        summary = try container.decodeIfPresent(CleanupQueueSummary.self, forKey: .summary) ?? CleanupQueueSummary(
            total: decodedItems.count,
            findingCount: decodedItems.filter { $0.kind == .finding }.count,
            integrityCount: decodedItems.filter { $0.kind == .integrity }.count,
            conflictCount: decodedItems.filter { $0.kind == .conflict }.count,
            analysisCount: decodedItems.filter { $0.kind == .analysis }.count,
            readOnly: true,
            unavailableReason: nil
        )
        readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly) ?? true
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason) ?? summary.unavailableReason
    }
}

enum CleanupQueueModel {
    static func filtered(items: [CleanupQueueItem], kindFilter: CleanupQueueKindFilter, priorityFilter: CleanupQueuePriorityFilter, agentFilter: SkillAgentFilter) -> [CleanupQueueItem] {
        items.filter { item in
            kindFilter.includes(item.kind) && priorityFilter.includes(item.priority) && includes(agent: item.agent, filter: agentFilter)
        }
    }

    private static func includes(agent: String?, filter: SkillAgentFilter) -> Bool {
        guard filter != .all else { return true }
        return agent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == filter.rawValue
    }
}
