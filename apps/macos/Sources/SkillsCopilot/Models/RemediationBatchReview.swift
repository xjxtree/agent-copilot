import Foundation

struct RemediationBatchReviewOptions: Equatable {
    var includeTask: Bool = true
    var includeRisk: Bool = true
    var includeRule: Bool = true
    var includeAgent: Bool = true
    var includeWorkspace: Bool = true
    var includeBlocked: Bool = true

    var dimensions: [String] {
        var values: [String] = []
        if includeTask { values.append("task") }
        if includeRisk { values.append("risk") }
        if includeRule { values.append("rule") }
        if includeAgent { values.append("agent") }
        if includeWorkspace { values.append("workspace") }
        return values
    }
}

struct RemediationBatchReviewFilters: Decodable, Hashable {
    let taskText: String?
    let agent: String?
    let agents: [String]
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let dimensions: [String]
    let riskLevels: [String]
    let ruleIDs: [String]
    let includeBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case agent
        case agents
        case projectRoot = "project_root"
        case projectRootAlt = "projectRoot"
        case currentCWD = "current_cwd"
        case currentCWDAlt = "currentCWD"
        case workspace
        case workspaceID = "workspace_id"
        case limit
        case dimensions
        case reviewDimensions = "review_dimensions"
        case reviewDimensionsAlt = "reviewDimensions"
        case riskLevels = "risk_levels"
        case riskLevelsAlt = "riskLevels"
        case risks
        case ruleIDs = "rule_ids"
        case ruleIDsAlt = "ruleIds"
        case rules
        case includeBlocked = "include_blocked"
        case includeBlockedAlt = "includeBlocked"
    }

    init(
        taskText: String? = nil,
        agent: String? = nil,
        agents: [String] = [],
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        limit: Int? = nil,
        dimensions: [String] = [],
        riskLevels: [String] = [],
        ruleIDs: [String] = [],
        includeBlocked: Bool = true
    ) {
        self.taskText = taskText
        self.agent = agent
        self.agents = agents
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.limit = limit
        self.dimensions = dimensions
        self.riskLevels = riskLevels
        self.ruleIDs = ruleIDs
        self.includeBlocked = includeBlocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleBatchReviewStringArray(keys: [.agents, .agent])
        projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot)
            ?? container.decodeIfPresent(String.self, forKey: .projectRootAlt)
        currentCWD = try container.decodeIfPresent(String.self, forKey: .currentCWD)
            ?? container.decodeIfPresent(String.self, forKey: .currentCWDAlt)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
            ?? container.decodeIfPresent(String.self, forKey: .workspaceID)
        limit = try container.decodeFlexibleBatchReviewInt(keys: [.limit])
        dimensions = try container.decodeFlexibleBatchReviewStringArray(keys: [.dimensions, .reviewDimensions, .reviewDimensionsAlt])
        riskLevels = try container.decodeFlexibleBatchReviewStringArray(keys: [.riskLevels, .riskLevelsAlt, .risks])
        ruleIDs = try container.decodeFlexibleBatchReviewStringArray(keys: [.ruleIDs, .ruleIDsAlt, .rules])
        includeBlocked = try container.decodeIfPresent(Bool.self, forKey: .includeBlocked)
            ?? container.decodeIfPresent(Bool.self, forKey: .includeBlockedAlt)
            ?? true
    }
}

struct RemediationBatchReviewSummary: Decodable, Hashable {
    let totalCount: Int
    let groupCount: Int
    let taskCount: Int
    let riskCount: Int
    let ruleCount: Int
    let agentCount: Int
    let workspaceCount: Int
    let blockerCount: Int
    let gapCount: Int
    let safeNextStepCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case itemCount = "item_count"
        case items
        case groupCount = "group_count"
        case groups
        case taskCount = "task_count"
        case tasks
        case riskCount = "risk_count"
        case risks
        case ruleCount = "rule_count"
        case rules
        case agentCount = "agent_count"
        case agents
        case workspaceCount = "workspace_count"
        case workspaces
        case blockerCount = "blocker_count"
        case blockers
        case gapCount = "gap_count"
        case gaps
        case safeNextStepCount = "safe_next_step_count"
        case safeNextSteps = "safe_next_steps"
        case summary
        case message
        case text
    }

    init(
        totalCount: Int = 0,
        groupCount: Int = 0,
        taskCount: Int = 0,
        riskCount: Int = 0,
        ruleCount: Int = 0,
        agentCount: Int = 0,
        workspaceCount: Int = 0,
        blockerCount: Int = 0,
        gapCount: Int = 0,
        safeNextStepCount: Int = 0,
        summaryText: String = ""
    ) {
        self.totalCount = totalCount
        self.groupCount = groupCount
        self.taskCount = taskCount
        self.riskCount = riskCount
        self.ruleCount = ruleCount
        self.agentCount = agentCount
        self.workspaceCount = workspaceCount
        self.blockerCount = blockerCount
        self.gapCount = gapCount
        self.safeNextStepCount = safeNextStepCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalCount: try container.decodeFlexibleBatchReviewInt(keys: [.totalCount, .itemCount, .items]) ?? 0,
            groupCount: try container.decodeFlexibleBatchReviewInt(keys: [.groupCount, .groups]) ?? 0,
            taskCount: try container.decodeFlexibleBatchReviewInt(keys: [.taskCount, .tasks]) ?? 0,
            riskCount: try container.decodeFlexibleBatchReviewInt(keys: [.riskCount, .risks]) ?? 0,
            ruleCount: try container.decodeFlexibleBatchReviewInt(keys: [.ruleCount, .rules]) ?? 0,
            agentCount: try container.decodeFlexibleBatchReviewInt(keys: [.agentCount, .agents]) ?? 0,
            workspaceCount: try container.decodeFlexibleBatchReviewInt(keys: [.workspaceCount, .workspaces]) ?? 0,
            blockerCount: try container.decodeFlexibleBatchReviewInt(keys: [.blockerCount, .blockers]) ?? 0,
            gapCount: try container.decodeFlexibleBatchReviewInt(keys: [.gapCount, .gaps]) ?? 0,
            safeNextStepCount: try container.decodeFlexibleBatchReviewInt(keys: [.safeNextStepCount, .safeNextSteps]) ?? 0,
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

struct RemediationBatchReviewItem: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let category: String
    let priority: String
    let status: String
    let agent: String?
    let workspace: String?
    let ruleID: String?
    let riskLevel: String?
    let taskText: String?
    let skill: CapabilityTaxonomySkill?
    let rationale: String
    let safeNextStepLabel: String
    let reviewArea: String?
    let evidenceRefs: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case itemID = "item_id"
        case itemId = "itemId"
        case reviewID = "review_id"
        case reviewId = "reviewId"
        case title
        case name
        case label
        case category
        case kind
        case type
        case priority
        case severity
        case status
        case state
        case agent
        case workspace
        case ruleID = "rule_id"
        case ruleIDAlt = "ruleId"
        case rule
        case riskLevel = "risk_level"
        case riskLevelAlt = "riskLevel"
        case risk
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case skill
        case affectedSkill = "affected_skill"
        case affectedSkillAlt = "affectedSkill"
        case rationale
        case reason
        case summary
        case safeNextStepLabel = "safe_next_step_label"
        case safeNextStepLabelAlt = "safeNextStepLabel"
        case nextStepLabel = "next_step_label"
        case nextStepLabelAlt = "nextStepLabel"
        case suggestedAction = "suggested_action"
        case action
        case reviewArea = "review_area"
        case reviewAreaAlt = "reviewArea"
        case nextArea = "next_area"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case safetyFlags = "safety_flags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            category = UIStrings.unknown
            priority = UIStrings.unknown
            status = UIStrings.remediationBatchReviewPreviewOnly
            agent = nil
            workspace = nil
            ruleID = nil
            riskLevel = nil
            taskText = nil
            skill = nil
            rationale = value
            safeNextStepLabel = UIStrings.remediationBatchReviewSafeNextStepFallback
            reviewArea = nil
            evidenceRefs = []
            gapNotes = []
            blockerNotes = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? UIStrings.remediationBatchReviewItem
        category = try container.decodeIfPresent(String.self, forKey: .category)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? UIStrings.unknown
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
            ?? container.decodeIfPresent(String.self, forKey: .severity)
            ?? UIStrings.unknown
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? UIStrings.remediationBatchReviewPreviewOnly
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
        ruleID = try container.decodeIfPresent(String.self, forKey: .ruleID)
            ?? container.decodeIfPresent(String.self, forKey: .ruleIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .rule)
        riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel)
            ?? container.decodeIfPresent(String.self, forKey: .riskLevelAlt)
            ?? container.decodeIfPresent(String.self, forKey: .risk)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        skill = try container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkillAlt)
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        safeNextStepLabel = try container.decodeIfPresent(String.self, forKey: .safeNextStepLabel)
            ?? container.decodeIfPresent(String.self, forKey: .safeNextStepLabelAlt)
            ?? container.decodeIfPresent(String.self, forKey: .nextStepLabel)
            ?? container.decodeIfPresent(String.self, forKey: .nextStepLabelAlt)
            ?? container.decodeIfPresent(String.self, forKey: .suggestedAction)
            ?? container.decodeIfPresent(String.self, forKey: .action)
            ?? UIStrings.remediationBatchReviewSafeNextStepFallback
        reviewArea = try container.decodeIfPresent(String.self, forKey: .reviewArea)
            ?? container.decodeIfPresent(String.self, forKey: .reviewAreaAlt)
            ?? container.decodeIfPresent(String.self, forKey: .nextArea)
        evidenceRefs = try container.decodeFlexibleBatchReviewStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        gapNotes = try container.decodeFlexibleBatchReviewStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleBatchReviewStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        safetyFlags = try container.decodeFlexibleBatchReviewStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .itemID)
            ?? container.decodeIfPresent(String.self, forKey: .itemId)
            ?? container.decodeIfPresent(String.self, forKey: .reviewID)
            ?? container.decodeIfPresent(String.self, forKey: .reviewId)
            ?? "\(category)-\(title)"
    }
}

struct RemediationBatchReviewGroup: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let category: String
    let priority: String
    let summary: String
    let safeNextStepLabels: [String]
    let items: [RemediationBatchReviewItem]
    let evidenceRefs: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case groupId = "groupId"
        case title
        case name
        case label
        case category
        case kind
        case type
        case priority
        case severity
        case summary
        case rationale
        case safeNextStepLabels = "safe_next_step_labels"
        case safeNextStepLabelsAlt = "safeNextStepLabels"
        case nextStepLabels = "next_step_labels"
        case nextSteps = "safe_next_steps"
        case items
        case reviewItems = "review_items"
        case reviewItemsAlt = "reviewItems"
        case rows
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case safetyFlags = "safety_flags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            category = UIStrings.unknown
            priority = UIStrings.unknown
            summary = value
            safeNextStepLabels = []
            items = []
            evidenceRefs = []
            gapNotes = []
            blockerNotes = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? UIStrings.remediationBatchReviewGroup
        category = try container.decodeIfPresent(String.self, forKey: .category)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? UIStrings.unknown
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
            ?? container.decodeIfPresent(String.self, forKey: .severity)
            ?? UIStrings.unknown
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? ""
        safeNextStepLabels = try container.decodeFlexibleBatchReviewStringArray(keys: [.safeNextStepLabels, .safeNextStepLabelsAlt, .nextStepLabels, .nextSteps])
        items = try container.decodeBatchReviewItems(keys: [.items, .reviewItems, .reviewItemsAlt, .rows])
        evidenceRefs = try container.decodeFlexibleBatchReviewStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        gapNotes = try container.decodeFlexibleBatchReviewStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleBatchReviewStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        safetyFlags = try container.decodeFlexibleBatchReviewStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .groupID)
            ?? container.decodeIfPresent(String.self, forKey: .groupId)
            ?? "\(category)-\(title)"
    }
}

typealias RemediationBatchReviewEvidenceReference = CrossAgentReadinessEvidenceReference
typealias RemediationBatchReviewSafety = CrossAgentReadinessSafety

struct RemediationBatchReviewResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: RemediationBatchReviewFilters
    let summary: RemediationBatchReviewSummary
    let groups: [RemediationBatchReviewGroup]
    let items: [RemediationBatchReviewItem]
    let safeNextStepLabels: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [RemediationBatchReviewEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: RemediationBatchReviewSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case groups
        case reviewGroups = "review_groups"
        case reviewGroupsAlt = "reviewGroups"
        case groupRows = "group_rows"
        case items
        case reviewItems = "review_items"
        case reviewItemsAlt = "reviewItems"
        case rows
        case safeNextStepLabels = "safe_next_step_labels"
        case safeNextStepLabelsAlt = "safeNextStepLabels"
        case safeNextSteps = "safe_next_steps"
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case evidenceReferences = "evidence_references"
        case evidenceReferencesAlt = "evidenceReferences"
        case evidence
        case promptRequest = "prompt_request"
        case promptRequestAlt = "promptRequest"
        case safetyFlags = "safety_flags"
        case safety
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(
        generatedBy: String = "local",
        catalogAvailable: Bool = false,
        filters: RemediationBatchReviewFilters = RemediationBatchReviewFilters(),
        summary: RemediationBatchReviewSummary = RemediationBatchReviewSummary(),
        groups: [RemediationBatchReviewGroup] = [],
        items: [RemediationBatchReviewItem] = [],
        safeNextStepLabels: [String] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [RemediationBatchReviewEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: RemediationBatchReviewSafety = RemediationBatchReviewSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.groups = groups
        self.items = items
        self.safeNextStepLabels = safeNextStepLabels
        self.gapNotes = gapNotes
        self.blockerNotes = blockerNotes
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedBy = try container.decodeIfPresent(String.self, forKey: .generatedBy)
            ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
            ?? "local"
        catalogAvailable = try container.decodeIfPresent(Bool.self, forKey: .catalogAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .catalogAvailableAlt)
            ?? true
        filters = try container.decodeIfPresent(RemediationBatchReviewFilters.self, forKey: .filters) ?? RemediationBatchReviewFilters()
        groups = try container.decodeBatchReviewGroups(keys: [.groups, .reviewGroups, .reviewGroupsAlt, .groupRows])
        items = try container.decodeBatchReviewItems(keys: [.items, .reviewItems, .reviewItemsAlt, .rows])
        let inferredTotal = items.count + groups.reduce(0) { $0 + $1.items.count }
        summary = try container.decodeIfPresent(RemediationBatchReviewSummary.self, forKey: .summary)
            ?? RemediationBatchReviewSummary(totalCount: inferredTotal, groupCount: groups.count)
        safeNextStepLabels = try container.decodeFlexibleBatchReviewStringArray(keys: [.safeNextStepLabels, .safeNextStepLabelsAlt, .safeNextSteps])
        gapNotes = try container.decodeFlexibleBatchReviewStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleBatchReviewStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([RemediationBatchReviewEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([RemediationBatchReviewEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([RemediationBatchReviewEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(RemediationBatchReviewSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(RemediationBatchReviewSafety.self, forKey: .safety)
            ?? RemediationBatchReviewSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.remediationBatchReviewUnavailable) -> RemediationBatchReviewResult {
        RemediationBatchReviewResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBatchReviewInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let int = Int(trimmed) {
                    return int
                }
                if let double = Double(trimmed.replacingOccurrences(of: "%", with: "")) {
                    return Int(double.rounded())
                }
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([RemediationBatchReviewItem].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([RemediationBatchReviewGroup].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleBatchReviewStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([RemediationBatchReviewEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(RemediationBatchReviewEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return [value ? UIStrings.stateEnabled : UIStrings.stateDisabled]
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return ["\(value)"]
            }
        }
        return []
    }

    func decodeBatchReviewGroups(keys: [Key]) throws -> [RemediationBatchReviewGroup] {
        for key in keys {
            if let values = try? decodeIfPresent([RemediationBatchReviewGroup].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(RemediationBatchReviewGroup.self, forKey: key) {
                return [value]
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                let data = try JSONEncoder().encode([value])
                return try JSONDecoder().decode([RemediationBatchReviewGroup].self, from: data)
            }
        }
        return []
    }

    func decodeBatchReviewItems(keys: [Key]) throws -> [RemediationBatchReviewItem] {
        for key in keys {
            if let values = try? decodeIfPresent([RemediationBatchReviewItem].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(RemediationBatchReviewItem.self, forKey: key) {
                return [value]
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                let data = try JSONEncoder().encode([value])
                return try JSONDecoder().decode([RemediationBatchReviewItem].self, from: data)
            }
        }
        return []
    }
}
