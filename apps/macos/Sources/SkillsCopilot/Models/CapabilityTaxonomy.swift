import Foundation

struct CapabilityTaxonomyFilters: Decodable, Hashable {
    let agent: String?
    let agents: [String]
    let limit: Int?
    let includeGaps: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case agents
        case limit
        case includeGaps = "include_gaps"
        case includeGapsAlt = "includeGaps"
        case gaps
    }

    init(agent: String? = nil, agents: [String] = [], limit: Int? = nil, includeGaps: Bool = true) {
        self.agent = agent
        self.agents = agents
        self.limit = limit
        self.includeGaps = includeGaps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleCapabilityStringArray(keys: [.agents, .agent])
        limit = try container.decodeFlexibleCapabilityInt(keys: [.limit])
        includeGaps = try container.decodeFlexibleCapabilityBool(keys: [.includeGaps, .includeGapsAlt, .gaps]) ?? true
    }
}

struct CapabilityTaxonomySummary: Decodable, Hashable {
    let domainCount: Int
    let capabilityCount: Int
    let skillCount: Int
    let agentCount: Int
    let gapCount: Int
    let blockerCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case domainCount = "domain_count"
        case domains
        case capabilityCount = "capability_count"
        case capabilities
        case skillCount = "skill_count"
        case skills
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

    init(
        domainCount: Int = 0,
        capabilityCount: Int = 0,
        skillCount: Int = 0,
        agentCount: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        summaryText: String = ""
    ) {
        self.domainCount = domainCount
        self.capabilityCount = capabilityCount
        self.skillCount = skillCount
        self.agentCount = agentCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            domainCount = 0
            capabilityCount = 0
            skillCount = 0
            agentCount = 0
            gapCount = 0
            blockerCount = 0
            summaryText = value
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        domainCount = try container.decodeFlexibleCapabilityInt(keys: [.domainCount, .domains]) ?? 0
        capabilityCount = try container.decodeFlexibleCapabilityInt(keys: [.capabilityCount, .capabilities]) ?? 0
        skillCount = try container.decodeFlexibleCapabilityInt(keys: [.skillCount, .skills]) ?? 0
        agentCount = try container.decodeFlexibleCapabilityInt(keys: [.agentCount, .agents]) ?? 0
        gapCount = try container.decodeFlexibleCapabilityInt(keys: [.gapCount, .gaps]) ?? 0
        blockerCount = try container.decodeFlexibleCapabilityInt(keys: [.blockerCount, .blockers]) ?? 0
        summaryText = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .text)
            ?? ""
    }
}

struct CapabilityTaxonomySkill: Decodable, Hashable, Identifiable {
    let id: String
    let instanceID: String?
    let definitionID: String?
    let skillName: String
    let agent: String?
    let scope: String?
    let enabled: Bool?
    let state: String?
    let qualityScore: Double?
    let readinessScore: Double?
    let reasons: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
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
        case qualityScore = "quality_score"
        case qualityScoreAlt = "qualityScore"
        case quality
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case readiness
        case reasons
        case reason
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
            instanceID = value
            definitionID = nil
            skillName = value
            agent = nil
            scope = nil
            enabled = nil
            state = nil
            qualityScore = nil
            readinessScore = nil
            reasons = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let qualityContext = try container.decodeIfPresent(CapabilityScoreContext.self, forKey: .quality)
        let readinessContext = try container.decodeIfPresent(CapabilityScoreContext.self, forKey: .readiness)
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
        qualityScore = try container.decodeFlexibleCapabilityDouble(keys: [.qualityScore, .qualityScoreAlt]) ?? qualityContext?.score
        readinessScore = try container.decodeFlexibleCapabilityDouble(keys: [.readinessScore, .readinessScoreAlt]) ?? readinessContext?.score
        reasons = try container.decodeFlexibleCapabilityStringArray(keys: [.reasons, .reason])
        evidenceRefs = try container.decodeFlexibleCapabilityStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleCapabilityStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? instanceID
            ?? "\(agent ?? "")-\(definitionID ?? "")-\(skillName)"
    }

    var statusLabel: String {
        guard let state, let enabled else { return UIStrings.unknown }
        return DisplayText.state(state, enabled: enabled)
    }
}

struct CapabilityTaxonomyCoverage: Decodable, Hashable, Identifiable {
    let id: String
    let agent: String
    let skillCount: Int
    let capabilityCount: Int
    let coverageState: String
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case agent
        case displayName = "display_name"
        case displayNameAlt = "displayName"
        case skillCount = "skill_count"
        case skillCountAlt = "skillCount"
        case skills
        case capabilityCount = "capability_count"
        case capabilityCountAlt = "capabilityCount"
        case capabilities
        case coverageState = "coverage_state"
        case coverageStateAlt = "coverageState"
        case state
        case status
        case notes
        case note
        case gaps
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            agent = value
            skillCount = 0
            capabilityCount = 0
            coverageState = UIStrings.unknown
            notes = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .displayNameAlt)
            ?? UIStrings.unknown
        skillCount = try container.decodeFlexibleCapabilityInt(keys: [.skillCount, .skillCountAlt, .skills]) ?? 0
        capabilityCount = try container.decodeFlexibleCapabilityInt(keys: [.capabilityCount, .capabilityCountAlt, .capabilities]) ?? 0
        coverageState = try container.decodeIfPresent(String.self, forKey: .coverageState)
            ?? container.decodeIfPresent(String.self, forKey: .coverageStateAlt)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? UIStrings.unknown
        notes = try container.decodeFlexibleCapabilityStringArray(keys: [.notes, .note, .gaps])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? agent
    }
}

struct CapabilityTaxonomyCapability: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let summary: String
    let keywords: [String]
    let tools: [String]
    let rules: [String]
    let riskTags: [String]
    let representativeSkills: [CapabilityTaxonomySkill]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case capabilityID = "capability_id"
        case capabilityId = "capabilityId"
        case name
        case title
        case capability
        case summary
        case description
        case keywords
        case terms
        case tools
        case rules
        case riskTags = "risk_tags"
        case riskTagsAlt = "riskTags"
        case risks
        case representativeSkills = "representative_skills"
        case representativeSkillsAlt = "representativeSkills"
        case skills
        case members
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
            name = value
            summary = ""
            keywords = []
            tools = []
            rules = []
            riskTags = []
            representativeSkills = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .capability)
            ?? UIStrings.capabilityTaxonomyCapability
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? ""
        keywords = try container.decodeFlexibleCapabilityStringArray(keys: [.keywords, .terms])
        tools = try container.decodeFlexibleCapabilityStringArray(keys: [.tools])
        rules = try container.decodeFlexibleCapabilityStringArray(keys: [.rules])
        riskTags = try container.decodeFlexibleCapabilityStringArray(keys: [.riskTags, .riskTagsAlt, .risks])
        representativeSkills = try container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .representativeSkills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .representativeSkillsAlt)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .skills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .members)
            ?? []
        evidenceRefs = try container.decodeFlexibleCapabilityStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleCapabilityStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .capabilityID)
            ?? container.decodeIfPresent(String.self, forKey: .capabilityId)
            ?? name
    }
}

struct CapabilityTaxonomyDomain: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let summary: String
    let capabilityCount: Int
    let skillCount: Int
    let coverageByAgent: [CapabilityTaxonomyCoverage]
    let capabilities: [CapabilityTaxonomyCapability]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case domainID = "domain_id"
        case domainId = "domainId"
        case name
        case title
        case domain
        case summary
        case description
        case capabilityCount = "capability_count"
        case capabilityCountAlt = "capabilityCount"
        case skillCount = "skill_count"
        case skillCountAlt = "skillCount"
        case coverageByAgent = "coverage_by_agent"
        case coverageByAgentAlt = "coverageByAgent"
        case agentCoverage = "agent_coverage"
        case coverage
        case capabilities
        case rows
        case skills
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
            name = value
            summary = ""
            capabilityCount = 0
            skillCount = 0
            coverageByAgent = []
            capabilities = []
            gapNotes = []
            blockerNotes = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .domain)
            ?? UIStrings.capabilityTaxonomyDomain
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? ""
        let coverageRows = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverageByAgent)) ?? nil
        let coverageRowsAlt = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverageByAgentAlt)) ?? nil
        let agentCoverageRows = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .agentCoverage)) ?? nil
        let genericCoverageRows = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverage)) ?? nil
        coverageByAgent = coverageRows
            ?? coverageRowsAlt
            ?? agentCoverageRows
            ?? genericCoverageRows
            ?? CapabilityTaxonomyDomain.decodeCoverageAliases(container: container)
            ?? []
        capabilities = try container.decodeIfPresent([CapabilityTaxonomyCapability].self, forKey: .capabilities)
            ?? container.decodeIfPresent([CapabilityTaxonomyCapability].self, forKey: .rows)
            ?? []
        let directSkills = try container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .skills) ?? []
        capabilityCount = try container.decodeFlexibleCapabilityInt(keys: [.capabilityCount, .capabilityCountAlt])
            ?? capabilities.count
        skillCount = try container.decodeFlexibleCapabilityInt(keys: [.skillCount, .skillCountAlt])
            ?? capabilities.reduce(directSkills.count) { $0 + $1.representativeSkills.count }
        gapNotes = try container.decodeFlexibleCapabilityStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleCapabilityStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceRefs = try container.decodeFlexibleCapabilityStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleCapabilityStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .domainID)
            ?? container.decodeIfPresent(String.self, forKey: .domainId)
            ?? name
    }

    private static func decodeCoverageAliases(container: KeyedDecodingContainer<CodingKeys>) -> [CapabilityTaxonomyCoverage]? {
        let agents = (try? container.decodeFlexibleCapabilityStringArray(keys: [.coverage])) ?? []
        guard !agents.isEmpty else { return nil }
        return agents.map { CapabilityTaxonomyCoverage.synthetic(agent: $0) }
    }
}

typealias CapabilityTaxonomyEvidenceReference = CrossAgentReadinessEvidenceReference
typealias CapabilityTaxonomySafety = CrossAgentReadinessSafety

struct CapabilityTaxonomyResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: CapabilityTaxonomyFilters
    let summary: CapabilityTaxonomySummary
    let domains: [CapabilityTaxonomyDomain]
    let coverageByAgent: [CapabilityTaxonomyCoverage]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [CapabilityTaxonomyEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: CapabilityTaxonomySafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case domains
        case rows
        case results
        case taxonomy
        case coverageByAgent = "coverage_by_agent"
        case coverageByAgentAlt = "coverageByAgent"
        case agentCoverage = "agent_coverage"
        case coverage
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
        filters: CapabilityTaxonomyFilters = CapabilityTaxonomyFilters(),
        summary: CapabilityTaxonomySummary = CapabilityTaxonomySummary(),
        domains: [CapabilityTaxonomyDomain] = [],
        coverageByAgent: [CapabilityTaxonomyCoverage] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [CapabilityTaxonomyEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: CapabilityTaxonomySafety = CapabilityTaxonomySafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.domains = domains
        self.coverageByAgent = coverageByAgent
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
        filters = try container.decodeIfPresent(CapabilityTaxonomyFilters.self, forKey: .filters) ?? CapabilityTaxonomyFilters()
        domains = try container.decodeIfPresent([CapabilityTaxonomyDomain].self, forKey: .domains)
            ?? container.decodeIfPresent([CapabilityTaxonomyDomain].self, forKey: .rows)
            ?? container.decodeIfPresent([CapabilityTaxonomyDomain].self, forKey: .results)
            ?? container.decodeIfPresent([CapabilityTaxonomyDomain].self, forKey: .taxonomy)
            ?? []
        let coverageRows = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverageByAgent)) ?? nil
        let coverageRowsAlt = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverageByAgentAlt)) ?? nil
        let agentCoverageRows = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .agentCoverage)) ?? nil
        let genericCoverageRows = (try? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverage)) ?? nil
        coverageByAgent = coverageRows
            ?? coverageRowsAlt
            ?? agentCoverageRows
            ?? genericCoverageRows
            ?? []
        summary = try container.decodeIfPresent(CapabilityTaxonomySummary.self, forKey: .summary)
            ?? CapabilityTaxonomySummary(
                domainCount: domains.count,
                capabilityCount: domains.reduce(0) { $0 + $1.capabilityCount },
                skillCount: domains.reduce(0) { $0 + $1.skillCount },
                agentCount: Set(coverageByAgent.map(\.agent)).count
            )
        gapNotes = try container.decodeFlexibleCapabilityStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleCapabilityStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([CapabilityTaxonomyEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([CapabilityTaxonomyEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([CapabilityTaxonomyEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(CapabilityTaxonomySafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(CapabilityTaxonomySafety.self, forKey: .safety)
            ?? CapabilityTaxonomySafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.capabilityTaxonomyUnavailable) -> CapabilityTaxonomyResult {
        CapabilityTaxonomyResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension CapabilityTaxonomyCoverage {
    static func synthetic(agent: String) -> CapabilityTaxonomyCoverage {
        CapabilityTaxonomyCoverage(agent: agent)
    }

    init(agent: String) {
        self.id = agent
        self.agent = agent
        self.skillCount = 0
        self.capabilityCount = 0
        self.coverageState = UIStrings.unknown
        self.notes = []
    }
}

private struct CapabilityScoreContext: Decodable, Hashable {
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case score
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decodeFlexibleCapabilityDouble(keys: [.score, .value])
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleCapabilityInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([CapabilityTaxonomyDomain].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([CapabilityTaxonomyCapability].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([CapabilityTaxonomySkill].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleCapabilityDouble(keys: [Key]) throws -> Double? {
        for key in keys {
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let double = Double(trimmed.replacingOccurrences(of: "%", with: "")) {
                    return trimmed.contains("%") ? double / 100 : double
                }
            }
        }
        return nil
    }

    func decodeFlexibleCapabilityBool(keys: [Key]) throws -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1", "enabled":
                    return true
                case "false", "no", "0", "disabled":
                    return false
                default:
                    continue
                }
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
        }
        return nil
    }

    func decodeFlexibleCapabilityStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([CapabilityTaxonomyEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(CapabilityTaxonomyEvidenceReference.self, forKey: key) {
                return [value.detail]
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
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return [RoutingAccuracySummary.confidenceLabel(value)]
            }
        }
        return []
    }
}
