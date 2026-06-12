import Foundation

typealias SkillLifecycleTimelineEvidenceReference = ProviderObservabilityEvidenceReference
typealias SkillLifecycleTimelinePromptRequest = ProviderObservabilityPromptRequest
typealias SkillLifecycleTimelineSafety = ProviderObservabilitySafety

struct SkillLifecycleTimelineFilters: Decodable, Hashable {
    let agent: String?
    let agents: [String]
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let includeSkillRows: Bool
    let includeAgentRows: Bool
    let includeEvidence: Bool
    let includeSafetyFlags: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case agents
        case selectedSkillID = "selected_skill_id"
        case selectedSkillIDAlt = "selectedSkillID"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillNameAlt = "selectedSkillName"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillAgentAlt = "selectedSkillAgent"
        case projectRoot = "project_root"
        case projectRootAlt = "projectRoot"
        case currentCWD = "current_cwd"
        case currentCWDAlt = "currentCWD"
        case workspace
        case workspaceID = "workspace_id"
        case limit
        case includeSkillRows = "include_skill_rows"
        case includeSkillRowsAlt = "includeSkillRows"
        case includeAgentRows = "include_agent_rows"
        case includeAgentRowsAlt = "includeAgentRows"
        case includeEvidence = "include_evidence"
        case includeEvidenceAlt = "includeEvidence"
        case includeSafetyFlags = "include_safety_flags"
        case includeSafetyFlagsAlt = "includeSafetyFlags"
    }

    init(
        agent: String? = nil,
        agents: [String] = [],
        selectedSkillID: String? = nil,
        selectedSkillName: String? = nil,
        selectedSkillAgent: String? = nil,
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        limit: Int? = nil,
        includeSkillRows: Bool = true,
        includeAgentRows: Bool = true,
        includeEvidence: Bool = true,
        includeSafetyFlags: Bool = true
    ) {
        self.agent = agent
        self.agents = agents
        self.selectedSkillID = selectedSkillID
        self.selectedSkillName = selectedSkillName
        self.selectedSkillAgent = selectedSkillAgent
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.limit = limit
        self.includeSkillRows = includeSkillRows
        self.includeAgentRows = includeAgentRows
        self.includeEvidence = includeEvidence
        self.includeSafetyFlags = includeSafetyFlags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeFlexibleLifecycleString(keys: [.agent])
        agents = try container.decodeFlexibleLifecycleStringArray(keys: [.agents, .agent])
        selectedSkillID = try container.decodeFlexibleLifecycleString(keys: [.selectedSkillID, .selectedSkillIDAlt])
        selectedSkillName = try container.decodeFlexibleLifecycleString(keys: [.selectedSkillName, .selectedSkillNameAlt])
        selectedSkillAgent = try container.decodeFlexibleLifecycleString(keys: [.selectedSkillAgent, .selectedSkillAgentAlt])
        projectRoot = try container.decodeFlexibleLifecycleString(keys: [.projectRoot, .projectRootAlt])
        currentCWD = try container.decodeFlexibleLifecycleString(keys: [.currentCWD, .currentCWDAlt])
        workspace = try container.decodeFlexibleLifecycleString(keys: [.workspace, .workspaceID])
        limit = try container.decodeFlexibleLifecycleInt(keys: [.limit])
        includeSkillRows = try container.decodeFlexibleLifecycleBool(keys: [.includeSkillRows, .includeSkillRowsAlt]) ?? true
        includeAgentRows = try container.decodeFlexibleLifecycleBool(keys: [.includeAgentRows, .includeAgentRowsAlt]) ?? true
        includeEvidence = try container.decodeFlexibleLifecycleBool(keys: [.includeEvidence, .includeEvidenceAlt]) ?? true
        includeSafetyFlags = try container.decodeFlexibleLifecycleBool(keys: [.includeSafetyFlags, .includeSafetyFlagsAlt]) ?? true
    }
}

struct SkillLifecycleTimelineSummary: Decodable, Hashable {
    let eventCount: Int
    let skillCount: Int
    let agentCount: Int
    let eventTypeCount: Int
    let stageCount: Int
    let gapCount: Int
    let blockerCount: Int
    let evidenceCount: Int
    let safetyFlagCount: Int
    let firstEventAt: String?
    let latestEventAt: String?
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case eventCount = "event_count"
        case eventCountAlt = "eventCount"
        case timelineCount = "timeline_count"
        case timelineRows = "timeline_rows"
        case events
        case rows
        case totalCount = "total_count"
        case total
        case skillCount = "skill_count"
        case skillCountAlt = "skillCount"
        case skillRows = "skill_rows"
        case skills
        case agentCount = "agent_count"
        case agentCountAlt = "agentCount"
        case agentRows = "agent_rows"
        case agents
        case eventTypeCount = "event_type_count"
        case eventTypeCountAlt = "eventTypeCount"
        case eventTypes = "event_types"
        case stageCount = "stage_count"
        case stageCountAlt = "stageCount"
        case lifecycleStageCount = "lifecycle_stage_count"
        case lifecycleStageCountAlt = "lifecycleStageCount"
        case stages
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case evidenceCount = "evidence_count"
        case evidence
        case evidenceReferences = "evidence_references"
        case safetyFlagCount = "safety_flag_count"
        case safetyFlags = "safety_flags"
        case firstEventAt = "first_event_at"
        case firstEventAtAlt = "firstEventAt"
        case latestEventAt = "latest_event_at"
        case latestEventAtAlt = "latestEventAt"
        case lastEventAt = "last_event_at"
        case lastEventAtAlt = "lastEventAt"
        case summary
        case message
        case text
    }

    init(
        eventCount: Int = 0,
        skillCount: Int = 0,
        agentCount: Int = 0,
        eventTypeCount: Int = 0,
        stageCount: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        evidenceCount: Int = 0,
        safetyFlagCount: Int = 0,
        firstEventAt: String? = nil,
        latestEventAt: String? = nil,
        summaryText: String = ""
    ) {
        self.eventCount = eventCount
        self.skillCount = skillCount
        self.agentCount = agentCount
        self.eventTypeCount = eventTypeCount
        self.stageCount = stageCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.evidenceCount = evidenceCount
        self.safetyFlagCount = safetyFlagCount
        self.firstEventAt = firstEventAt
        self.latestEventAt = latestEventAt
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            eventCount: try container.decodeFlexibleLifecycleInt(keys: [.eventCount, .eventCountAlt, .timelineCount, .timelineRows, .events, .rows, .totalCount, .total]) ?? 0,
            skillCount: try container.decodeFlexibleLifecycleInt(keys: [.skillCount, .skillCountAlt, .skillRows, .skills]) ?? 0,
            agentCount: try container.decodeFlexibleLifecycleInt(keys: [.agentCount, .agentCountAlt, .agentRows, .agents]) ?? 0,
            eventTypeCount: try container.decodeFlexibleLifecycleInt(keys: [.eventTypeCount, .eventTypeCountAlt, .eventTypes]) ?? 0,
            stageCount: try container.decodeFlexibleLifecycleInt(keys: [.stageCount, .stageCountAlt, .lifecycleStageCount, .lifecycleStageCountAlt, .stages]) ?? 0,
            gapCount: try container.decodeFlexibleLifecycleInt(keys: [.gapCount, .gaps]) ?? 0,
            blockerCount: try container.decodeFlexibleLifecycleInt(keys: [.blockerCount, .blockers]) ?? 0,
            evidenceCount: try container.decodeFlexibleLifecycleInt(keys: [.evidenceCount, .evidence, .evidenceReferences]) ?? 0,
            safetyFlagCount: try container.decodeFlexibleLifecycleInt(keys: [.safetyFlagCount, .safetyFlags]) ?? 0,
            firstEventAt: try container.decodeFlexibleLifecycleString(keys: [.firstEventAt, .firstEventAtAlt]),
            latestEventAt: try container.decodeFlexibleLifecycleString(keys: [.latestEventAt, .latestEventAtAlt, .lastEventAt, .lastEventAtAlt]),
            summaryText: try container.decodeFlexibleLifecycleString(keys: [.summary, .message, .text]) ?? ""
        )
    }
}

struct SkillLifecycleTimelineRow: Decodable, Identifiable, Hashable {
    let id: String
    let occurredAt: String?
    let eventType: String
    let lifecycleStage: String
    let title: String
    let summary: String
    let agent: String?
    let skillName: String?
    let instanceID: String?
    let definitionID: String?
    let source: String?
    let severity: String?
    let status: String?
    let count: Int?
    let evidenceRefs: [String]
    let safetyFlags: [String]

    var displayStatus: String? {
        status ?? severity
    }

    enum CodingKeys: String, CodingKey {
        case id
        case rowID = "row_id"
        case eventID = "event_id"
        case occurredAt = "occurred_at"
        case occurredAtAlt = "occurredAt"
        case timestamp
        case at
        case observedAt = "observed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case eventType = "event_type"
        case eventTypeAlt = "eventType"
        case type
        case kind
        case action
        case event
        case lifecycleStage = "lifecycle_stage"
        case lifecycleStageAlt = "lifecycleStage"
        case stage
        case phase
        case title
        case label
        case name
        case summary
        case detail
        case message
        case rationale
        case agent
        case skillName = "skill_name"
        case skillNameAlt = "skillName"
        case instanceID = "instance_id"
        case instanceIDAlt = "instanceID"
        case skillID = "skill_id"
        case skillIDAlt = "skillID"
        case definitionID = "definition_id"
        case definitionIDAlt = "definitionID"
        case source
        case sourceMethod = "source_method"
        case sourceType = "source_type"
        case sourceID = "source_id"
        case severity
        case level
        case priority
        case status
        case state
        case outcome
        case count
        case eventCount = "event_count"
        case rowCount = "row_count"
        case total
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
    }

    init(
        id: String,
        occurredAt: String? = nil,
        eventType: String = "",
        lifecycleStage: String = "",
        title: String,
        summary: String = "",
        agent: String? = nil,
        skillName: String? = nil,
        instanceID: String? = nil,
        definitionID: String? = nil,
        source: String? = nil,
        severity: String? = nil,
        status: String? = nil,
        count: Int? = nil,
        evidenceRefs: [String] = [],
        safetyFlags: [String] = []
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.eventType = eventType
        self.lifecycleStage = lifecycleStage
        self.title = title
        self.summary = summary
        self.agent = agent
        self.skillName = skillName
        self.instanceID = instanceID
        self.definitionID = definitionID
        self.source = source
        self.severity = severity
        self.status = status
        self.count = count
        self.evidenceRefs = evidenceRefs
        self.safetyFlags = safetyFlags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let text = value.lifecycleNonEmpty {
            self.init(id: text, eventType: text, lifecycleStage: UIStrings.unknown, title: text, summary: text)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedOccurredAt = try container.decodeFlexibleLifecycleString(keys: [.occurredAt, .occurredAtAlt, .timestamp, .at, .observedAt, .createdAt, .updatedAt])
        let decodedEventType = try container.decodeFlexibleLifecycleString(keys: [.eventType, .eventTypeAlt, .type, .kind, .action, .event]) ?? UIStrings.unknown
        let decodedLifecycleStage = try container.decodeFlexibleLifecycleString(keys: [.lifecycleStage, .lifecycleStageAlt, .stage, .phase]) ?? UIStrings.unknown
        let decodedTitle = try container.decodeFlexibleLifecycleString(keys: [.title, .label, .name])
            ?? decodedEventType
        let decodedSummary = try container.decodeFlexibleLifecycleString(keys: [.summary, .detail, .message, .rationale]) ?? ""
        let decodedAgent = try container.decodeFlexibleLifecycleString(keys: [.agent])
        let decodedSkillName = try container.decodeFlexibleLifecycleString(keys: [.skillName, .skillNameAlt, .name])
        let decodedInstanceID = try container.decodeFlexibleLifecycleString(keys: [.instanceID, .instanceIDAlt, .skillID, .skillIDAlt])
        let decodedDefinitionID = try container.decodeFlexibleLifecycleString(keys: [.definitionID, .definitionIDAlt])
        let decodedSource = try container.decodeFlexibleLifecycleString(keys: [.source, .sourceMethod, .sourceType, .sourceID])
        let decodedSeverity = try container.decodeFlexibleLifecycleString(keys: [.severity, .level, .priority])
        let decodedStatus = try container.decodeFlexibleLifecycleString(keys: [.status, .state, .outcome])
        let decodedCount = try container.decodeFlexibleLifecycleInt(keys: [.count, .eventCount, .rowCount, .total])
        let decodedEvidenceRefs = try container.decodeFlexibleLifecycleStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        let decodedSafetyFlags = try container.decodeFlexibleLifecycleStringArray(keys: [.safetyFlags, .safetyFlagsAlt])
        let decodedID = try container.decodeFlexibleLifecycleString(keys: [.id, .rowID, .eventID, .instanceID, .instanceIDAlt])
            ?? [decodedOccurredAt, decodedEventType, decodedLifecycleStage, decodedAgent, decodedSkillName, decodedSource]
            .compactMap { $0?.lifecycleNonEmpty }
            .joined(separator: ":")
        self.init(
            id: decodedID.isEmpty ? decodedTitle : decodedID,
            occurredAt: decodedOccurredAt,
            eventType: decodedEventType,
            lifecycleStage: decodedLifecycleStage,
            title: decodedTitle,
            summary: decodedSummary,
            agent: decodedAgent,
            skillName: decodedSkillName,
            instanceID: decodedInstanceID,
            definitionID: decodedDefinitionID,
            source: decodedSource,
            severity: decodedSeverity,
            status: decodedStatus,
            count: decodedCount,
            evidenceRefs: decodedEvidenceRefs,
            safetyFlags: decodedSafetyFlags
        )
    }
}

struct SkillLifecycleTimelineResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: SkillLifecycleTimelineFilters
    let summary: SkillLifecycleTimelineSummary
    let timelineRows: [SkillLifecycleTimelineRow]
    let skillRows: [SkillLifecycleTimelineRow]
    let agentRows: [SkillLifecycleTimelineRow]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [SkillLifecycleTimelineEvidenceReference]
    let promptRequest: SkillLifecycleTimelinePromptRequest?
    let safetyFlags: SkillLifecycleTimelineSafety
    let fallbackReason: String?

    var isUnavailable: Bool {
        generatedBy == "unavailable"
            || (catalogAvailable == false
                && timelineRows.isEmpty
                && skillRows.isEmpty
                && agentRows.isEmpty
                && fallbackReason != nil)
    }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case timelineRows = "timeline_rows"
        case timelineRowsAlt = "timelineRows"
        case events
        case rows
        case skillRows = "skill_rows"
        case skillRowsAlt = "skillRows"
        case skills
        case agentRows = "agent_rows"
        case agentRowsAlt = "agentRows"
        case agents
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
        case promptMetadata = "prompt_metadata"
        case promptMetadataAlt = "promptMetadata"
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case safety
        case fallbackReason = "fallback_reason"
        case fallbackReasonAlt = "fallbackReason"
        case reason
    }

    init(
        generatedBy: String = "local-v2.66",
        catalogAvailable: Bool = true,
        filters: SkillLifecycleTimelineFilters = SkillLifecycleTimelineFilters(),
        summary: SkillLifecycleTimelineSummary = SkillLifecycleTimelineSummary(),
        timelineRows: [SkillLifecycleTimelineRow] = [],
        skillRows: [SkillLifecycleTimelineRow] = [],
        agentRows: [SkillLifecycleTimelineRow] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [SkillLifecycleTimelineEvidenceReference] = [],
        promptRequest: SkillLifecycleTimelinePromptRequest? = nil,
        safetyFlags: SkillLifecycleTimelineSafety = SkillLifecycleTimelineSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.timelineRows = timelineRows
        self.skillRows = skillRows
        self.agentRows = agentRows
        self.gapNotes = gapNotes
        self.blockerNotes = blockerNotes
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let rows = try? decoder.singleValueContainer().decode([SkillLifecycleTimelineRow].self) {
            self.init(timelineRows: rows)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTimelineRows = try container.decodeLifecycleRows(keys: [.timelineRows, .timelineRowsAlt, .events, .rows])
        let decodedSkillRows = try container.decodeLifecycleRows(keys: [.skillRows, .skillRowsAlt, .skills])
        let decodedAgentRows = try container.decodeLifecycleRows(keys: [.agentRows, .agentRowsAlt, .agents])
        let decodedSummary = try container.decodeIfPresent(SkillLifecycleTimelineSummary.self, forKey: .summary)
            ?? SkillLifecycleTimelineSummary(
                eventCount: decodedTimelineRows.count,
                skillCount: decodedSkillRows.count,
                agentCount: decodedAgentRows.count
            )
        self.init(
            generatedBy: try container.decodeFlexibleLifecycleString(keys: [.generatedBy, .generatedByAlt]) ?? "local-v2.66",
            catalogAvailable: try container.decodeFlexibleLifecycleBool(keys: [.catalogAvailable, .catalogAvailableAlt]) ?? true,
            filters: try container.decodeIfPresent(SkillLifecycleTimelineFilters.self, forKey: .filters) ?? SkillLifecycleTimelineFilters(),
            summary: decodedSummary,
            timelineRows: decodedTimelineRows,
            skillRows: decodedSkillRows,
            agentRows: decodedAgentRows,
            gapNotes: try container.decodeFlexibleLifecycleStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps]),
            blockerNotes: try container.decodeFlexibleLifecycleStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers]),
            evidenceReferences: try container.decodeLifecycleRows(type: SkillLifecycleTimelineEvidenceReference.self, keys: [.evidenceReferences, .evidenceReferencesAlt, .evidence]),
            promptRequest: try container.decodeIfPresent(SkillLifecycleTimelinePromptRequest.self, forKey: .promptRequest)
                ?? container.decodeIfPresent(SkillLifecycleTimelinePromptRequest.self, forKey: .promptRequestAlt)
                ?? container.decodeIfPresent(SkillLifecycleTimelinePromptRequest.self, forKey: .promptMetadata)
                ?? container.decodeIfPresent(SkillLifecycleTimelinePromptRequest.self, forKey: .promptMetadataAlt),
            safetyFlags: try container.decodeIfPresent(SkillLifecycleTimelineSafety.self, forKey: .safetyFlags)
                ?? container.decodeIfPresent(SkillLifecycleTimelineSafety.self, forKey: .safetyFlagsAlt)
                ?? container.decodeIfPresent(SkillLifecycleTimelineSafety.self, forKey: .safety)
                ?? SkillLifecycleTimelineSafety(),
            fallbackReason: try container.decodeFlexibleLifecycleString(keys: [.fallbackReason, .fallbackReasonAlt, .reason])
        )
    }

    static func unavailable(reason: String = UIStrings.skillLifecycleTimelineUnavailable) -> SkillLifecycleTimelineResult {
        SkillLifecycleTimelineResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            summary: SkillLifecycleTimelineSummary(summaryText: reason),
            safetyFlags: SkillLifecycleTimelineSafety(notes: [reason]),
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleLifecycleString(keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let text = value.lifecycleNonEmpty {
                return text
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value.formatted()
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value ? UIStrings.llmEnabled : UIStrings.llmDisabled
            }
        }
        return nil
    }

    func decodeFlexibleLifecycleInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value ? 1 : 0
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let int = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return int
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([SkillLifecycleTimelineRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([SkillLifecycleTimelineEvidenceReference].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleLifecycleBool(keys: [Key]) throws -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1", "enabled", "available":
                    return true
                case "false", "no", "0", "disabled", "blocked", "unavailable":
                    return false
                default:
                    break
                }
            }
        }
        return nil
    }

    func decodeFlexibleLifecycleStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.compactMap(\.lifecycleNonEmpty)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let text = value.lifecycleNonEmpty {
                return [text]
            }
            if let values = try? decodeIfPresent([SkillLifecycleTimelineEvidenceReference].self, forKey: key) {
                return values.compactMap { ($0.detail.lifecycleNonEmpty ?? $0.title.lifecycleNonEmpty) }
            }
            if let values = try? decodeIfPresent([SkillLifecycleTimelineRow].self, forKey: key) {
                return values.compactMap { ($0.summary.lifecycleNonEmpty ?? $0.title.lifecycleNonEmpty) }
            }
        }
        return []
    }

    func decodeLifecycleRows(keys: [Key]) throws -> [SkillLifecycleTimelineRow] {
        try decodeLifecycleRows(type: SkillLifecycleTimelineRow.self, keys: keys)
    }

    func decodeLifecycleRows<T: Decodable>(type: T.Type, keys: [Key]) throws -> [T] {
        for key in keys {
            if let values = try? decodeIfPresent([T].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(T.self, forKey: key) {
                return [value]
            }
        }
        return []
    }
}

private extension String {
    var lifecycleNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
