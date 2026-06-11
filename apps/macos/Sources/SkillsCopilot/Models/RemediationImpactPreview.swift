import Foundation

struct RemediationImpactPreviewSummary: Decodable, Hashable {
    let totalCount: Int
    let taskImpactCount: Int
    let agentImpactCount: Int
    let skillImpactCount: Int
    let riskDeltaCount: Int
    let snapshotRollbackCount: Int
    let blockerCount: Int
    let gapCount: Int
    let noWriteCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case impactCount = "impact_count"
        case itemCount = "item_count"
        case items
        case taskImpactCount = "task_impact_count"
        case taskImpacts = "task_impacts"
        case agentImpactCount = "agent_impact_count"
        case agentImpacts = "agent_impacts"
        case skillImpactCount = "skill_impact_count"
        case skillImpacts = "skill_impacts"
        case riskDeltaCount = "risk_delta_count"
        case riskDeltas = "risk_deltas"
        case snapshotRollbackCount = "snapshot_rollback_count"
        case snapshotRollback = "snapshot_rollback"
        case blockerCount = "blocker_count"
        case blockers
        case gapCount = "gap_count"
        case gaps
        case noWriteCount = "no_write_count"
        case noWrite = "no_write"
        case readOnlyCount = "read_only_count"
        case summary
        case message
        case text
    }

    init(
        totalCount: Int = 0,
        taskImpactCount: Int = 0,
        agentImpactCount: Int = 0,
        skillImpactCount: Int = 0,
        riskDeltaCount: Int = 0,
        snapshotRollbackCount: Int = 0,
        blockerCount: Int = 0,
        gapCount: Int = 0,
        noWriteCount: Int = 0,
        summaryText: String = ""
    ) {
        self.totalCount = totalCount
        self.taskImpactCount = taskImpactCount
        self.agentImpactCount = agentImpactCount
        self.skillImpactCount = skillImpactCount
        self.riskDeltaCount = riskDeltaCount
        self.snapshotRollbackCount = snapshotRollbackCount
        self.blockerCount = blockerCount
        self.gapCount = gapCount
        self.noWriteCount = noWriteCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalCount: try container.decodeFlexibleImpactInt(keys: [.totalCount, .impactCount, .itemCount, .items]) ?? 0,
            taskImpactCount: try container.decodeFlexibleImpactInt(keys: [.taskImpactCount, .taskImpacts]) ?? 0,
            agentImpactCount: try container.decodeFlexibleImpactInt(keys: [.agentImpactCount, .agentImpacts]) ?? 0,
            skillImpactCount: try container.decodeFlexibleImpactInt(keys: [.skillImpactCount, .skillImpacts]) ?? 0,
            riskDeltaCount: try container.decodeFlexibleImpactInt(keys: [.riskDeltaCount, .riskDeltas]) ?? 0,
            snapshotRollbackCount: try container.decodeFlexibleImpactInt(keys: [.snapshotRollbackCount, .snapshotRollback]) ?? 0,
            blockerCount: try container.decodeFlexibleImpactInt(keys: [.blockerCount, .blockers]) ?? 0,
            gapCount: try container.decodeFlexibleImpactInt(keys: [.gapCount, .gaps]) ?? 0,
            noWriteCount: try container.decodeFlexibleImpactInt(keys: [.noWriteCount, .noWrite, .readOnlyCount]) ?? 0,
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

struct RemediationImpactRow: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let category: String
    let agent: String?
    let skill: CapabilityTaxonomySkill?
    let before: String?
    let after: String?
    let delta: String?
    let impact: String
    let rationale: String
    let severity: String
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case rowID = "row_id"
        case rowId = "rowId"
        case impactID = "impact_id"
        case impactId = "impactId"
        case title
        case name
        case label
        case category
        case kind
        case type
        case agent
        case skill
        case affectedSkill = "affected_skill"
        case affectedSkillAlt = "affectedSkill"
        case skillRef = "skill_ref"
        case before
        case current
        case baseline
        case after
        case proposed
        case target
        case delta
        case change
        case impact
        case expectedImpact = "expected_impact"
        case expectedImpactAlt = "expectedImpact"
        case summary
        case rationale
        case reason
        case severity
        case priority
        case state
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
            category = UIStrings.unknown
            agent = nil
            skill = nil
            before = nil
            after = nil
            delta = nil
            impact = value
            rationale = ""
            severity = UIStrings.unknown
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? UIStrings.impactPreviewImpact
        category = try container.decodeIfPresent(String.self, forKey: .category)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        skill = try container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkillAlt)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skillRef)
        before = try container.decodeIfPresent(String.self, forKey: .before)
            ?? container.decodeIfPresent(String.self, forKey: .current)
            ?? container.decodeIfPresent(String.self, forKey: .baseline)
        after = try container.decodeIfPresent(String.self, forKey: .after)
            ?? container.decodeIfPresent(String.self, forKey: .proposed)
            ?? container.decodeIfPresent(String.self, forKey: .target)
        delta = try container.decodeIfPresent(String.self, forKey: .delta)
            ?? container.decodeIfPresent(String.self, forKey: .change)
        impact = try container.decodeIfPresent(String.self, forKey: .impact)
            ?? container.decodeIfPresent(String.self, forKey: .expectedImpact)
            ?? container.decodeIfPresent(String.self, forKey: .expectedImpactAlt)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? ""
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .priority)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? UIStrings.unknown
        evidenceRefs = try container.decodeFlexibleImpactStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleImpactStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .rowID)
            ?? container.decodeIfPresent(String.self, forKey: .rowId)
            ?? container.decodeIfPresent(String.self, forKey: .impactID)
            ?? container.decodeIfPresent(String.self, forKey: .impactId)
            ?? "\(category)-\(title)"
    }
}

typealias RemediationImpactPreviewEvidenceReference = CrossAgentReadinessEvidenceReference
typealias RemediationImpactPreviewSafety = CrossAgentReadinessSafety

struct RemediationImpactPreviewResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: RemediationPlanFilters
    let summary: RemediationImpactPreviewSummary
    let impactRows: [RemediationImpactRow]
    let taskImpactRows: [RemediationImpactRow]
    let agentImpactRows: [RemediationImpactRow]
    let skillImpactRows: [RemediationImpactRow]
    let riskDeltaRows: [RemediationImpactRow]
    let snapshotRollbackRows: [RemediationImpactRow]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [RemediationImpactPreviewEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: RemediationImpactPreviewSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case impactRows = "impact_rows"
        case impactRowsAlt = "impactRows"
        case impacts
        case rows
        case items
        case taskImpactRows = "task_impact_rows"
        case taskImpactRowsAlt = "taskImpactRows"
        case taskImpacts = "task_impacts"
        case agentImpactRows = "agent_impact_rows"
        case agentImpactRowsAlt = "agentImpactRows"
        case agentImpacts = "agent_impacts"
        case skillImpactRows = "skill_impact_rows"
        case skillImpactRowsAlt = "skillImpactRows"
        case skillImpacts = "skill_impacts"
        case riskDeltaRows = "risk_delta_rows"
        case riskDeltaRowsAlt = "riskDeltaRows"
        case riskDeltas = "risk_deltas"
        case snapshotRollbackRows = "snapshot_rollback_rows"
        case snapshotRollbackRowsAlt = "snapshotRollbackRows"
        case snapshotRollback = "snapshot_rollback"
        case rollbackRows = "rollback_rows"
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
        summary: RemediationImpactPreviewSummary = RemediationImpactPreviewSummary(),
        impactRows: [RemediationImpactRow] = [],
        taskImpactRows: [RemediationImpactRow] = [],
        agentImpactRows: [RemediationImpactRow] = [],
        skillImpactRows: [RemediationImpactRow] = [],
        riskDeltaRows: [RemediationImpactRow] = [],
        snapshotRollbackRows: [RemediationImpactRow] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [RemediationImpactPreviewEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: RemediationImpactPreviewSafety = RemediationImpactPreviewSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.impactRows = impactRows
        self.taskImpactRows = taskImpactRows
        self.agentImpactRows = agentImpactRows
        self.skillImpactRows = skillImpactRows
        self.riskDeltaRows = riskDeltaRows
        self.snapshotRollbackRows = snapshotRollbackRows
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
        impactRows = try container.decodeImpactRows(keys: [.impactRows, .impactRowsAlt, .impacts, .rows, .items])
        taskImpactRows = try container.decodeImpactRows(keys: [.taskImpactRows, .taskImpactRowsAlt, .taskImpacts])
        agentImpactRows = try container.decodeImpactRows(keys: [.agentImpactRows, .agentImpactRowsAlt, .agentImpacts])
        skillImpactRows = try container.decodeImpactRows(keys: [.skillImpactRows, .skillImpactRowsAlt, .skillImpacts])
        riskDeltaRows = try container.decodeImpactRows(keys: [.riskDeltaRows, .riskDeltaRowsAlt, .riskDeltas])
        snapshotRollbackRows = try container.decodeImpactRows(keys: [.snapshotRollbackRows, .snapshotRollbackRowsAlt, .snapshotRollback, .rollbackRows])
        let inferredTotal = impactRows.count + taskImpactRows.count + agentImpactRows.count + skillImpactRows.count + riskDeltaRows.count + snapshotRollbackRows.count
        summary = try container.decodeIfPresent(RemediationImpactPreviewSummary.self, forKey: .summary)
            ?? RemediationImpactPreviewSummary(totalCount: inferredTotal)
        gapNotes = try container.decodeFlexibleImpactStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleImpactStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([RemediationImpactPreviewEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([RemediationImpactPreviewEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([RemediationImpactPreviewEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(RemediationImpactPreviewSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(RemediationImpactPreviewSafety.self, forKey: .safety)
            ?? RemediationImpactPreviewSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.impactPreviewUnavailable) -> RemediationImpactPreviewResult {
        RemediationImpactPreviewResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleImpactInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([RemediationImpactRow].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeImpactRows(keys: [Key]) throws -> [RemediationImpactRow] {
        for key in keys {
            if let values = try? decodeIfPresent([RemediationImpactRow].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(RemediationImpactRow.self, forKey: key) {
                return [value]
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                let data = try JSONEncoder().encode([value])
                return try JSONDecoder().decode([RemediationImpactRow].self, from: data)
            }
        }
        return []
    }

    func decodeFlexibleImpactStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([RemediationImpactPreviewEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(RemediationImpactPreviewEvidenceReference.self, forKey: key) {
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
}
