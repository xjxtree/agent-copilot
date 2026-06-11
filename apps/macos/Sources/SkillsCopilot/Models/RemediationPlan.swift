import Foundation

struct RemediationPlanFilters: Decodable, Hashable {
    let taskText: String?
    let agent: String?
    let agents: [String]
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let includeGuidanceOnly: Bool

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
        case includeGuidanceOnly = "include_guidance_only"
        case includeGuidanceOnlyAlt = "includeGuidanceOnly"
    }

    init(
        taskText: String? = nil,
        agent: String? = nil,
        agents: [String] = [],
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        limit: Int? = nil,
        includeGuidanceOnly: Bool = true
    ) {
        self.taskText = taskText
        self.agent = agent
        self.agents = agents
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.limit = limit
        self.includeGuidanceOnly = includeGuidanceOnly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleRemediationStringArray(keys: [.agents, .agent])
        projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot)
            ?? container.decodeIfPresent(String.self, forKey: .projectRootAlt)
        currentCWD = try container.decodeIfPresent(String.self, forKey: .currentCWD)
            ?? container.decodeIfPresent(String.self, forKey: .currentCWDAlt)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
            ?? container.decodeIfPresent(String.self, forKey: .workspaceID)
        limit = try container.decodeFlexibleRemediationInt(keys: [.limit])
        includeGuidanceOnly = try container.decodeIfPresent(Bool.self, forKey: .includeGuidanceOnly)
            ?? container.decodeIfPresent(Bool.self, forKey: .includeGuidanceOnlyAlt)
            ?? true
    }
}

struct RemediationPlanSummary: Decodable, Hashable {
    let totalCount: Int
    let criticalCount: Int
    let highCount: Int
    let mediumCount: Int
    let lowCount: Int
    let quickWinCount: Int
    let blockerCount: Int
    let gapCount: Int
    let ambiguityCount: Int
    let driftCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case itemCount = "item_count"
        case items
        case criticalCount = "critical_count"
        case critical
        case highCount = "high_count"
        case high
        case mediumCount = "medium_count"
        case medium
        case lowCount = "low_count"
        case low
        case quickWinCount = "quick_win_count"
        case quickWins = "quick_wins"
        case blockerCount = "blocker_count"
        case blockers
        case gapCount = "gap_count"
        case gaps
        case ambiguityCount = "ambiguity_count"
        case ambiguity
        case driftCount = "drift_count"
        case staleDriftCount = "stale_drift_count"
        case drift
        case summary
        case message
        case text
    }

    init(
        totalCount: Int = 0,
        criticalCount: Int = 0,
        highCount: Int = 0,
        mediumCount: Int = 0,
        lowCount: Int = 0,
        quickWinCount: Int = 0,
        blockerCount: Int = 0,
        gapCount: Int = 0,
        ambiguityCount: Int = 0,
        driftCount: Int = 0,
        summaryText: String = ""
    ) {
        self.totalCount = totalCount
        self.criticalCount = criticalCount
        self.highCount = highCount
        self.mediumCount = mediumCount
        self.lowCount = lowCount
        self.quickWinCount = quickWinCount
        self.blockerCount = blockerCount
        self.gapCount = gapCount
        self.ambiguityCount = ambiguityCount
        self.driftCount = driftCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalCount: try container.decodeFlexibleRemediationInt(keys: [.totalCount, .itemCount, .items]) ?? 0,
            criticalCount: try container.decodeFlexibleRemediationInt(keys: [.criticalCount, .critical]) ?? 0,
            highCount: try container.decodeFlexibleRemediationInt(keys: [.highCount, .high]) ?? 0,
            mediumCount: try container.decodeFlexibleRemediationInt(keys: [.mediumCount, .medium]) ?? 0,
            lowCount: try container.decodeFlexibleRemediationInt(keys: [.lowCount, .low]) ?? 0,
            quickWinCount: try container.decodeFlexibleRemediationInt(keys: [.quickWinCount, .quickWins]) ?? 0,
            blockerCount: try container.decodeFlexibleRemediationInt(keys: [.blockerCount, .blockers]) ?? 0,
            gapCount: try container.decodeFlexibleRemediationInt(keys: [.gapCount, .gaps]) ?? 0,
            ambiguityCount: try container.decodeFlexibleRemediationInt(keys: [.ambiguityCount, .ambiguity]) ?? 0,
            driftCount: try container.decodeFlexibleRemediationInt(keys: [.driftCount, .staleDriftCount, .drift]) ?? 0,
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

struct RemediationPlanPriorityRow: Decodable, Hashable, Identifiable {
    let id: String
    let priority: String
    let title: String
    let count: Int
    let rationale: String
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case priority
        case level
        case severity
        case title
        case label
        case count
        case items
        case rationale
        case reason
        case summary
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            priority = value
            title = value
            count = 0
            rationale = ""
            evidenceRefs = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
            ?? container.decodeIfPresent(String.self, forKey: .level)
            ?? container.decodeIfPresent(String.self, forKey: .severity)
            ?? UIStrings.unknown
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? priority
        count = try container.decodeFlexibleRemediationInt(keys: [.count, .items]) ?? 0
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        evidenceRefs = try container.decodeFlexibleRemediationStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(priority)-\(title)"
    }
}

struct RemediationPlanItem: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let priority: String
    let category: String
    let status: String
    let agent: String?
    let capability: String?
    let skill: CapabilityTaxonomySkill?
    let rationale: String
    let suggestedAction: String
    let guidanceOnly: Bool
    let nextArea: String?
    let impact: String?
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case itemID = "item_id"
        case itemId = "itemId"
        case title
        case name
        case priority
        case severity
        case rank
        case category
        case kind
        case sourceKind = "source_kind"
        case status
        case state
        case agent
        case capability
        case capabilityName = "capability_name"
        case skill
        case representativeSkill = "representative_skill"
        case rationale
        case reason
        case summary
        case suggestedAction = "suggested_action"
        case suggestedActionAlt = "suggestedAction"
        case action
        case nextAction = "next_action"
        case guidanceOnly = "guidance_only"
        case guidanceOnlyAlt = "guidanceOnly"
        case readOnly = "read_only"
        case nextArea = "next_area"
        case nextAreaAlt = "nextArea"
        case targetArea = "target_area"
        case impact
        case expectedImpact = "expected_impact"
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case safetyFlags = "safety_flags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            priority = UIStrings.unknown
            category = UIStrings.unknown
            status = UIStrings.remediationPlanGuidanceOnly
            agent = nil
            capability = nil
            skill = nil
            rationale = value
            suggestedAction = value
            guidanceOnly = true
            nextArea = nil
            impact = nil
            gapNotes = []
            blockerNotes = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.remediationPlanItem
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
            ?? container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .rank)
            ?? UIStrings.unknown
        category = try container.decodeIfPresent(String.self, forKey: .category)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .sourceKind)
            ?? UIStrings.unknown
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? UIStrings.remediationPlanGuidanceOnly
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        capability = try container.decodeIfPresent(String.self, forKey: .capability)
            ?? container.decodeIfPresent(String.self, forKey: .capabilityName)
        skill = try container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .representativeSkill)
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        suggestedAction = try container.decodeIfPresent(String.self, forKey: .suggestedAction)
            ?? container.decodeIfPresent(String.self, forKey: .suggestedActionAlt)
            ?? container.decodeIfPresent(String.self, forKey: .action)
            ?? container.decodeIfPresent(String.self, forKey: .nextAction)
            ?? UIStrings.remediationPlanReviewGuidance
        guidanceOnly = try container.decodeIfPresent(Bool.self, forKey: .guidanceOnly)
            ?? container.decodeIfPresent(Bool.self, forKey: .guidanceOnlyAlt)
            ?? container.decodeIfPresent(Bool.self, forKey: .readOnly)
            ?? true
        nextArea = try container.decodeIfPresent(String.self, forKey: .nextArea)
            ?? container.decodeIfPresent(String.self, forKey: .nextAreaAlt)
            ?? container.decodeIfPresent(String.self, forKey: .targetArea)
        impact = try container.decodeIfPresent(String.self, forKey: .impact)
            ?? container.decodeIfPresent(String.self, forKey: .expectedImpact)
        gapNotes = try container.decodeFlexibleRemediationStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleRemediationStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceRefs = try container.decodeFlexibleRemediationStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleRemediationStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .itemID)
            ?? container.decodeIfPresent(String.self, forKey: .itemId)
            ?? "\(priority)-\(category)-\(title)"
    }
}

typealias RemediationPlanEvidenceReference = CrossAgentReadinessEvidenceReference
typealias RemediationPlanSafety = CrossAgentReadinessSafety

struct RemediationPlanResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: RemediationPlanFilters
    let summary: RemediationPlanSummary
    let priorityRows: [RemediationPlanPriorityRow]
    let items: [RemediationPlanItem]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [RemediationPlanEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: RemediationPlanSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case priorityRows = "priority_rows"
        case priorityRowsAlt = "priorityRows"
        case priorities
        case priority
        case items
        case planItems = "plan_items"
        case planItemsAlt = "planItems"
        case rows
        case recommendations
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
        filters: RemediationPlanFilters = RemediationPlanFilters(),
        summary: RemediationPlanSummary = RemediationPlanSummary(),
        priorityRows: [RemediationPlanPriorityRow] = [],
        items: [RemediationPlanItem] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [RemediationPlanEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: RemediationPlanSafety = RemediationPlanSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.priorityRows = priorityRows
        self.items = items
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
        filters = try container.decodeIfPresent(RemediationPlanFilters.self, forKey: .filters) ?? RemediationPlanFilters()
        priorityRows = try container.decodeIfPresent([RemediationPlanPriorityRow].self, forKey: .priorityRows)
            ?? container.decodeIfPresent([RemediationPlanPriorityRow].self, forKey: .priorityRowsAlt)
            ?? container.decodeIfPresent([RemediationPlanPriorityRow].self, forKey: .priorities)
            ?? container.decodeIfPresent([RemediationPlanPriorityRow].self, forKey: .priority)
            ?? []
        items = try container.decodeIfPresent([RemediationPlanItem].self, forKey: .items)
            ?? container.decodeIfPresent([RemediationPlanItem].self, forKey: .planItems)
            ?? container.decodeIfPresent([RemediationPlanItem].self, forKey: .planItemsAlt)
            ?? container.decodeIfPresent([RemediationPlanItem].self, forKey: .rows)
            ?? container.decodeIfPresent([RemediationPlanItem].self, forKey: .recommendations)
            ?? []
        summary = try container.decodeIfPresent(RemediationPlanSummary.self, forKey: .summary)
            ?? RemediationPlanSummary(totalCount: items.count)
        gapNotes = try container.decodeFlexibleRemediationStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleRemediationStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([RemediationPlanEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([RemediationPlanEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([RemediationPlanEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(RemediationPlanSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(RemediationPlanSafety.self, forKey: .safety)
            ?? RemediationPlanSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.remediationPlanUnavailable) -> RemediationPlanResult {
        RemediationPlanResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleRemediationInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([RemediationPlanItem].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([RemediationPlanPriorityRow].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleRemediationStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([RemediationPlanEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(RemediationPlanEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
            if let value = try? decodeIfPresent(CapabilityTaxonomySkill.self, forKey: key) {
                return [value.skillName]
            }
            if let values = try? decodeIfPresent([CapabilityTaxonomySkill].self, forKey: key) {
                return values.map(\.skillName)
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
}
