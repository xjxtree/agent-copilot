import Foundation

struct KnowledgeSearchFilters: Decodable, Hashable {
    let query: String
    let agent: String?
    let agents: [String]
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case query
        case q
        case search
        case agent
        case agents
        case limit
    }

    init(query: String = "", agent: String? = nil, agents: [String] = [], limit: Int? = nil) {
        self.query = query
        self.agent = agent
        self.agents = agents
        self.limit = limit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = try container.decodeIfPresent(String.self, forKey: .query)
            ?? container.decodeIfPresent(String.self, forKey: .q)
            ?? container.decodeIfPresent(String.self, forKey: .search)
            ?? ""
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleKnowledgeStringArray(keys: [.agents, .agent])
        limit = try container.decodeFlexibleKnowledgeInt(keys: [.limit])
    }
}

struct KnowledgeSearchSummary: Decodable, Hashable {
    let resultCount: Int
    let agentCount: Int
    let gapCount: Int
    let blockerCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case resultCount = "result_count"
        case results
        case rows
        case matches
        case agentCount = "agent_count"
        case agents
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case summary
        case message
        case text
    }

    init(resultCount: Int = 0, agentCount: Int = 0, gapCount: Int = 0, blockerCount: Int = 0, summaryText: String = "") {
        self.resultCount = resultCount
        self.agentCount = agentCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            resultCount = 0
            agentCount = 0
            gapCount = 0
            blockerCount = 0
            summaryText = value
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultCount = try container.decodeFlexibleKnowledgeInt(keys: [.resultCount, .results, .rows, .matches]) ?? 0
        agentCount = try container.decodeFlexibleKnowledgeInt(keys: [.agentCount, .agents]) ?? 0
        gapCount = try container.decodeFlexibleKnowledgeInt(keys: [.gapCount, .gaps]) ?? 0
        blockerCount = try container.decodeFlexibleKnowledgeInt(keys: [.blockerCount, .blockers]) ?? 0
        summaryText = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .text)
            ?? ""
    }
}

struct KnowledgeFacetRow: Decodable, Hashable, Identifiable {
    let id: String
    let facet: String
    let value: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case id
        case facet
        case kind
        case field
        case category
        case value
        case label
        case name
        case count
        case total
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            facet = UIStrings.knowledgeFacet
            self.value = value
            count = 1
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        facet = try container.decodeIfPresent(String.self, forKey: .facet)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .field)
            ?? container.decodeIfPresent(String.self, forKey: .category)
            ?? UIStrings.knowledgeFacet
        value = try container.decodeIfPresent(String.self, forKey: .value)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        count = try container.decodeFlexibleKnowledgeInt(keys: [.count, .total]) ?? 0
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(facet)-\(value)-\(count)"
    }
}

struct KnowledgeSearchRow: Decodable, Hashable, Identifiable {
    let id: String
    let rank: Int?
    let instanceID: String?
    let definitionID: String?
    let skillName: String
    let agent: String?
    let scope: String?
    let enabled: Bool?
    let state: String?
    let purpose: String
    let matchedFields: [String]
    let matchReasons: [String]
    let keywords: [String]
    let tools: [String]
    let rules: [String]
    let capabilityTags: [String]
    let riskTags: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case rank
        case position
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case definitionID = "definition_id"
        case definitionId = "definitionId"
        case skillName = "skill_name"
        case skillNameAlt = "skillName"
        case name
        case title
        case agent
        case scope
        case enabled
        case state
        case purpose
        case snippet
        case description
        case summary
        case matchedFields = "matched_fields"
        case matchedFieldsAlt = "matchedFields"
        case fields
        case matchReasons = "match_reasons"
        case matchReasonsAlt = "matchReasons"
        case reasons
        case reason
        case keywords
        case keyword
        case tools
        case toolNames = "tool_names"
        case rules
        case ruleIDs = "rule_ids"
        case capabilityTags = "capability_tags"
        case capabilityTagsAlt = "capabilityTags"
        case capabilities
        case riskTags = "risk_tags"
        case riskTagsAlt = "riskTags"
        case risks
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case evidenceReferences = "evidence_references"
        case safetyFlags = "safety_flags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            rank = nil
            instanceID = nil
            definitionID = nil
            skillName = value
            agent = nil
            scope = nil
            enabled = nil
            state = nil
            purpose = value
            matchedFields = []
            matchReasons = []
            keywords = []
            tools = []
            rules = []
            capabilityTags = []
            riskTags = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decodeFlexibleKnowledgeInt(keys: [.rank, .position])
        instanceID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        definitionID = try container.decodeIfPresent(String.self, forKey: .definitionID)
            ?? container.decodeIfPresent(String.self, forKey: .definitionId)
        skillName = try container.decodeIfPresent(String.self, forKey: .skillName)
            ?? container.decodeIfPresent(String.self, forKey: .skillNameAlt)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? instanceID
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose)
            ?? container.decodeIfPresent(String.self, forKey: .snippet)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        matchedFields = try container.decodeFlexibleKnowledgeStringArray(keys: [.matchedFields, .matchedFieldsAlt, .fields])
        matchReasons = try container.decodeFlexibleKnowledgeStringArray(keys: [.matchReasons, .matchReasonsAlt, .reasons, .reason])
        keywords = try container.decodeFlexibleKnowledgeStringArray(keys: [.keywords, .keyword])
        tools = try container.decodeFlexibleKnowledgeStringArray(keys: [.tools, .toolNames])
        rules = try container.decodeFlexibleKnowledgeStringArray(keys: [.rules, .ruleIDs])
        capabilityTags = try container.decodeFlexibleKnowledgeStringArray(keys: [.capabilityTags, .capabilityTagsAlt, .capabilities])
        riskTags = try container.decodeFlexibleKnowledgeStringArray(keys: [.riskTags, .riskTagsAlt, .risks])
        evidenceRefs = try container.decodeFlexibleKnowledgeStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence, .evidenceReferences])
        safetyFlags = try container.decodeFlexibleKnowledgeStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? instanceID ?? "\(agent ?? "")-\(definitionID ?? "")-\(skillName)-\(rank ?? 0)"
    }

    var displayRank: String {
        guard let rank else { return UIStrings.unknown }
        return "#\(rank)"
    }

    var statusLabel: String {
        guard let state, let enabled else { return UIStrings.unknown }
        return DisplayText.state(state, enabled: enabled)
    }
}

typealias KnowledgeEvidenceReference = CrossAgentReadinessEvidenceReference
typealias KnowledgeSafety = CrossAgentReadinessSafety

struct KnowledgeSearchResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let summary: KnowledgeSearchSummary
    let filters: KnowledgeSearchFilters
    let knowledgeRows: [KnowledgeSearchRow]
    let facetRows: [KnowledgeFacetRow]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [KnowledgeEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: KnowledgeSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case summary
        case filters
        case knowledgeRows = "knowledge_rows"
        case knowledgeRowsAlt = "knowledgeRows"
        case rows
        case results
        case matches
        case facetRows = "facet_rows"
        case facetRowsAlt = "facetRows"
        case facets
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
        summary: KnowledgeSearchSummary = KnowledgeSearchSummary(),
        filters: KnowledgeSearchFilters = KnowledgeSearchFilters(),
        knowledgeRows: [KnowledgeSearchRow] = [],
        facetRows: [KnowledgeFacetRow] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [KnowledgeEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: KnowledgeSafety = KnowledgeSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.summary = summary
        self.filters = filters
        self.knowledgeRows = knowledgeRows
        self.facetRows = facetRows
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
        summary = try container.decodeIfPresent(KnowledgeSearchSummary.self, forKey: .summary) ?? KnowledgeSearchSummary()
        filters = try container.decodeIfPresent(KnowledgeSearchFilters.self, forKey: .filters) ?? KnowledgeSearchFilters()
        knowledgeRows = try container.decodeIfPresent([KnowledgeSearchRow].self, forKey: .knowledgeRows)
            ?? container.decodeIfPresent([KnowledgeSearchRow].self, forKey: .knowledgeRowsAlt)
            ?? container.decodeIfPresent([KnowledgeSearchRow].self, forKey: .rows)
            ?? container.decodeIfPresent([KnowledgeSearchRow].self, forKey: .results)
            ?? container.decodeIfPresent([KnowledgeSearchRow].self, forKey: .matches)
            ?? []
        facetRows = try container.decodeIfPresent([KnowledgeFacetRow].self, forKey: .facetRows)
            ?? container.decodeIfPresent([KnowledgeFacetRow].self, forKey: .facetRowsAlt)
            ?? KnowledgeSearchResult.decodeFacets(container: container, key: .facets)
            ?? []
        gapNotes = try container.decodeFlexibleKnowledgeStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleKnowledgeStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([KnowledgeEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([KnowledgeEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([KnowledgeEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(KnowledgeSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(KnowledgeSafety.self, forKey: .safety)
            ?? KnowledgeSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.knowledgeUnavailable) -> KnowledgeSearchResult {
        KnowledgeSearchResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }

    private static func decodeFacets(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> [KnowledgeFacetRow]? {
        if let rows = try? container.decodeIfPresent([KnowledgeFacetRow].self, forKey: key) {
            return rows
        }
        guard let dictionary = try? container.decodeIfPresent([String: [String: Int]].self, forKey: key) else {
            return nil
        }
        return dictionary.flatMap { facet, values in
            values.map { value, count in
                KnowledgeFacetRow.synthetic(facet: facet, value: value, count: count)
            }
        }
        .sorted { lhs, rhs in
            if lhs.facet == rhs.facet {
                return lhs.value < rhs.value
            }
            return lhs.facet < rhs.facet
        }
    }
}

private extension KnowledgeFacetRow {
    static func synthetic(facet: String, value: String, count: Int) -> KnowledgeFacetRow {
        KnowledgeFacetRow(fallbackFacet: facet, value: value, count: count)
    }

    init(fallbackFacet: String, value: String, count: Int) {
        self.id = "\(fallbackFacet)-\(value)-\(count)"
        self.facet = fallbackFacet
        self.value = value
        self.count = count
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleKnowledgeInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let int = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return int
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([KnowledgeSearchRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([KnowledgeFacetRow].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleKnowledgeStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([KnowledgeEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let values = try? decodeIfPresent([KnowledgeFacetRow].self, forKey: key) {
                return values.map { "\($0.facet): \($0.value)" }
            }
            if let value = try? decodeIfPresent(KnowledgeEvidenceReference.self, forKey: key) {
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
