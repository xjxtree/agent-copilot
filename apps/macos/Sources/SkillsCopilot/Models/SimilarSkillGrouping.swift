import Foundation

struct SimilarSkillGroupingFilters: Decodable, Hashable {
    let agent: String?
    let agents: [String]
    let limit: Int?
    let minScore: Double?
    let includeSingletons: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case agents
        case limit
        case minScore = "min_score"
        case minScoreAlt = "minScore"
        case threshold
        case includeSingletons = "include_singletons"
        case includeSingletonsAlt = "includeSingletons"
        case singletons
    }

    init(agent: String? = nil, agents: [String] = [], limit: Int? = nil, minScore: Double? = nil, includeSingletons: Bool = false) {
        self.agent = agent
        self.agents = agents
        self.limit = limit
        self.minScore = minScore
        self.includeSingletons = includeSingletons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleSimilarStringArray(keys: [.agents, .agent])
        limit = try container.decodeFlexibleSimilarInt(keys: [.limit])
        minScore = try container.decodeFlexibleSimilarDouble(keys: [.minScore, .minScoreAlt, .threshold])
        includeSingletons = try container.decodeFlexibleSimilarBool(keys: [.includeSingletons, .includeSingletonsAlt, .singletons]) ?? false
    }
}

struct SimilarSkillGroupingSummary: Decodable, Hashable {
    let groupCount: Int
    let memberCount: Int
    let duplicateCount: Int
    let similarCount: Int
    let confusableCount: Int
    let highAmbiguityCount: Int
    let coverageRedundancyCount: Int
    let routingAmbiguityCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case groupCount = "group_count"
        case groups
        case memberCount = "member_count"
        case members
        case duplicateCount = "duplicate_count"
        case duplicates
        case similarCount = "similar_count"
        case similar
        case confusableCount = "confusable_count"
        case confusable
        case highAmbiguityCount = "high_ambiguity_count"
        case highAmbiguity = "highAmbiguity"
        case coverageRedundancyCount = "coverage_redundancy_count"
        case coverageRedundancy = "coverageRedundancy"
        case routingAmbiguityCount = "routing_ambiguity_count"
        case routingAmbiguity = "routingAmbiguity"
        case summary
        case message
        case text
    }

    init(
        groupCount: Int = 0,
        memberCount: Int = 0,
        duplicateCount: Int = 0,
        similarCount: Int = 0,
        confusableCount: Int = 0,
        highAmbiguityCount: Int = 0,
        coverageRedundancyCount: Int = 0,
        routingAmbiguityCount: Int = 0,
        summaryText: String = ""
    ) {
        self.groupCount = groupCount
        self.memberCount = memberCount
        self.duplicateCount = duplicateCount
        self.similarCount = similarCount
        self.confusableCount = confusableCount
        self.highAmbiguityCount = highAmbiguityCount
        self.coverageRedundancyCount = coverageRedundancyCount
        self.routingAmbiguityCount = routingAmbiguityCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            groupCount = 0
            memberCount = 0
            duplicateCount = 0
            similarCount = 0
            confusableCount = 0
            highAmbiguityCount = 0
            coverageRedundancyCount = 0
            routingAmbiguityCount = 0
            summaryText = value
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupCount = try container.decodeFlexibleSimilarInt(keys: [.groupCount, .groups]) ?? 0
        memberCount = try container.decodeFlexibleSimilarInt(keys: [.memberCount, .members]) ?? 0
        duplicateCount = try container.decodeFlexibleSimilarInt(keys: [.duplicateCount, .duplicates]) ?? 0
        similarCount = try container.decodeFlexibleSimilarInt(keys: [.similarCount, .similar]) ?? 0
        confusableCount = try container.decodeFlexibleSimilarInt(keys: [.confusableCount, .confusable]) ?? 0
        highAmbiguityCount = try container.decodeFlexibleSimilarInt(keys: [.highAmbiguityCount, .highAmbiguity]) ?? 0
        coverageRedundancyCount = try container.decodeFlexibleSimilarInt(keys: [.coverageRedundancyCount, .coverageRedundancy]) ?? 0
        routingAmbiguityCount = try container.decodeFlexibleSimilarInt(keys: [.routingAmbiguityCount, .routingAmbiguity]) ?? 0
        summaryText = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .text)
            ?? ""
    }
}

struct SimilarSkillMember: Decodable, Hashable, Identifiable {
    let id: String
    let instanceID: String?
    let definitionID: String?
    let skillName: String
    let agent: String?
    let scope: String?
    let enabled: Bool?
    let state: String?
    let sourcePath: String?
    let sourceKind: String?
    let sourceRoot: String?
    let qualityScore: Double?
    let qualityBand: String?
    let readinessScore: Double?
    let readinessBand: String?
    let staleDriftState: String?
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
        case source
        case sourcePath = "source_path"
        case sourcePathAlt = "sourcePath"
        case path
        case sourceKind = "source_kind"
        case sourceKindAlt = "sourceKind"
        case sourceRoot = "source_root"
        case sourceRootAlt = "sourceRoot"
        case root
        case qualityScore = "quality_score"
        case qualityScoreAlt = "qualityScore"
        case quality
        case qualityBand = "quality_band"
        case qualityBandAlt = "qualityBand"
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case readiness
        case readinessBand = "readiness_band"
        case readinessBandAlt = "readinessBand"
        case staleDriftState = "stale_drift_state"
        case staleDriftStateAlt = "staleDriftState"
        case staleDrift = "stale_drift"
        case reasons
        case reason
        case matchReasons = "match_reasons"
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
            sourcePath = nil
            sourceKind = nil
            sourceRoot = nil
            qualityScore = nil
            qualityBand = nil
            readinessScore = nil
            readinessBand = nil
            staleDriftState = nil
            reasons = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sourceInfo = try container.decodeIfPresent(SimilarSkillSourceInfo.self, forKey: .source)
        let qualityContext = try container.decodeIfPresent(SimilarSkillScoreContext.self, forKey: .quality)
        let readinessContext = try container.decodeIfPresent(SimilarSkillScoreContext.self, forKey: .readiness)
        let staleDriftContext = try container.decodeIfPresent(SimilarSkillStateContext.self, forKey: .staleDrift)

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
        sourcePath = try container.decodeIfPresent(String.self, forKey: .sourcePath)
            ?? container.decodeIfPresent(String.self, forKey: .sourcePathAlt)
            ?? container.decodeIfPresent(String.self, forKey: .path)
            ?? sourceInfo?.path
        sourceKind = try container.decodeIfPresent(String.self, forKey: .sourceKind)
            ?? container.decodeIfPresent(String.self, forKey: .sourceKindAlt)
            ?? sourceInfo?.kind
        sourceRoot = try container.decodeIfPresent(String.self, forKey: .sourceRoot)
            ?? container.decodeIfPresent(String.self, forKey: .sourceRootAlt)
            ?? container.decodeIfPresent(String.self, forKey: .root)
            ?? sourceInfo?.root
        qualityScore = try container.decodeFlexibleSimilarDouble(keys: [.qualityScore, .qualityScoreAlt]) ?? qualityContext?.score
        qualityBand = try container.decodeIfPresent(String.self, forKey: .qualityBand)
            ?? container.decodeIfPresent(String.self, forKey: .qualityBandAlt)
            ?? qualityContext?.band
        readinessScore = try container.decodeFlexibleSimilarDouble(keys: [.readinessScore, .readinessScoreAlt]) ?? readinessContext?.score
        readinessBand = try container.decodeIfPresent(String.self, forKey: .readinessBand)
            ?? container.decodeIfPresent(String.self, forKey: .readinessBandAlt)
            ?? readinessContext?.band
        staleDriftState = try container.decodeIfPresent(String.self, forKey: .staleDriftState)
            ?? container.decodeIfPresent(String.self, forKey: .staleDriftStateAlt)
            ?? staleDriftContext?.state
            ?? staleDriftContext?.summary
        reasons = try container.decodeFlexibleSimilarStringArray(keys: [.reasons, .reason, .matchReasons])
        evidenceRefs = try container.decodeFlexibleSimilarStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleSimilarStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? instanceID
            ?? "\(agent ?? "")-\(definitionID ?? "")-\(skillName)"
    }

    var statusLabel: String {
        guard let state, let enabled else { return UIStrings.unknown }
        return DisplayText.state(state, enabled: enabled)
    }
}

struct SimilarSkillGroup: Decodable, Hashable, Identifiable {
    let id: String
    let rank: Int?
    let groupType: String
    let similarityScore: Double?
    let ambiguityRisk: String?
    let coverageRedundancy: String?
    let routingAmbiguity: String?
    let title: String
    let summary: String
    let whyGrouped: [String]
    let sharedTerms: [String]
    let sharedTools: [String]
    let sharedRules: [String]
    let sharedCapabilities: [String]
    let sharedRisks: [String]
    let sourceSignals: [String]
    let members: [SimilarSkillMember]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case groupId = "groupId"
        case rank
        case position
        case groupType = "group_type"
        case groupTypeAlt = "groupType"
        case type
        case kind
        case similarityScore = "similarity_score"
        case similarityScoreAlt = "similarityScore"
        case score
        case ambiguityRisk = "ambiguity_risk"
        case ambiguityRiskAlt = "ambiguityRisk"
        case risk
        case coverageRedundancy = "coverage_redundancy"
        case coverageRedundancyAlt = "coverageRedundancy"
        case routingAmbiguity = "routing_ambiguity"
        case routingAmbiguityAlt = "routingAmbiguity"
        case title
        case name
        case summary
        case description
        case whyGrouped = "why_grouped"
        case whyGroupedAlt = "whyGrouped"
        case reasons
        case sharedTerms = "shared_terms"
        case sharedTermsAlt = "sharedTerms"
        case terms
        case keywords
        case sharedTools = "shared_tools"
        case sharedToolsAlt = "sharedTools"
        case tools
        case sharedRules = "shared_rules"
        case sharedRulesAlt = "sharedRules"
        case rules
        case sharedCapabilities = "shared_capabilities"
        case sharedCapabilitiesAlt = "sharedCapabilities"
        case capabilitySignals = "capability_signals"
        case capabilitySignalsAlt = "capabilitySignals"
        case capabilities
        case sharedRisks = "shared_risks"
        case sharedRisksAlt = "sharedRisks"
        case riskSignals = "risk_signals"
        case riskSignalsAlt = "riskSignals"
        case risks
        case sourceSignals = "source_signals"
        case sourceSignalsAlt = "sourceSignals"
        case sources
        case sourceOverlap = "source_overlap"
        case members
        case skills
        case rows
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
            rank = nil
            groupType = UIStrings.similarGroupingSimilar
            similarityScore = nil
            ambiguityRisk = nil
            coverageRedundancy = nil
            routingAmbiguity = nil
            title = value
            summary = ""
            whyGrouped = []
            sharedTerms = []
            sharedTools = []
            sharedRules = []
            sharedCapabilities = []
            sharedRisks = []
            sourceSignals = []
            members = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decodeFlexibleSimilarInt(keys: [.rank, .position])
        groupType = try container.decodeIfPresent(String.self, forKey: .groupType)
            ?? container.decodeIfPresent(String.self, forKey: .groupTypeAlt)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? UIStrings.similarGroupingSimilar
        similarityScore = try container.decodeFlexibleSimilarDouble(keys: [.similarityScore, .similarityScoreAlt, .score])
        ambiguityRisk = try container.decodeIfPresent(String.self, forKey: .ambiguityRisk)
            ?? container.decodeIfPresent(String.self, forKey: .ambiguityRiskAlt)
            ?? container.decodeIfPresent(String.self, forKey: .risk)
        coverageRedundancy = try container.decodeFlexibleSimilarString(keys: [.coverageRedundancy, .coverageRedundancyAlt])
        routingAmbiguity = try container.decodeFlexibleSimilarString(keys: [.routingAmbiguity, .routingAmbiguityAlt])
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.similarGroupingGroup
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? ""
        whyGrouped = try container.decodeFlexibleSimilarStringArray(keys: [.whyGrouped, .whyGroupedAlt, .reasons])
        sharedTerms = try container.decodeFlexibleSimilarStringArray(keys: [.sharedTerms, .sharedTermsAlt, .terms, .keywords])
        sharedTools = try container.decodeFlexibleSimilarStringArray(keys: [.sharedTools, .sharedToolsAlt, .tools])
        sharedRules = try container.decodeFlexibleSimilarStringArray(keys: [.sharedRules, .sharedRulesAlt, .rules])
        sharedCapabilities = try container.decodeFlexibleSimilarStringArray(keys: [.sharedCapabilities, .sharedCapabilitiesAlt, .capabilitySignals, .capabilitySignalsAlt, .capabilities])
        sharedRisks = try container.decodeFlexibleSimilarStringArray(keys: [.sharedRisks, .sharedRisksAlt, .riskSignals, .riskSignalsAlt, .risks])
        sourceSignals = try container.decodeFlexibleSimilarStringArray(keys: [.sourceSignals, .sourceSignalsAlt, .sources, .sourceOverlap])
        members = try container.decodeIfPresent([SimilarSkillMember].self, forKey: .members)
            ?? container.decodeIfPresent([SimilarSkillMember].self, forKey: .skills)
            ?? container.decodeIfPresent([SimilarSkillMember].self, forKey: .rows)
            ?? []
        evidenceRefs = try container.decodeFlexibleSimilarStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleSimilarStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .groupID)
            ?? container.decodeIfPresent(String.self, forKey: .groupId)
            ?? "\(groupType)-\(title)-\(rank ?? 0)"
    }

    var typeLabel: String {
        switch groupType.lowercased() {
        case "duplicate", "duplicates", "same_name", "same-name":
            return UIStrings.similarGroupingDuplicate
        case "confusable", "ambiguous", "routing_ambiguity", "routing-ambiguity":
            return UIStrings.similarGroupingConfusable
        default:
            return UIStrings.similarGroupingSimilar
        }
    }

    var displayRank: String {
        guard let rank else { return UIStrings.unknown }
        return "#\(rank)"
    }
}

typealias SimilarSkillEvidenceReference = CrossAgentReadinessEvidenceReference
typealias SimilarSkillSafety = CrossAgentReadinessSafety

struct SimilarSkillGroupingResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: SimilarSkillGroupingFilters
    let summary: SimilarSkillGroupingSummary
    let groups: [SimilarSkillGroup]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [SimilarSkillEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: SimilarSkillSafety
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
        case rows
        case results
        case matches
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
        filters: SimilarSkillGroupingFilters = SimilarSkillGroupingFilters(),
        summary: SimilarSkillGroupingSummary = SimilarSkillGroupingSummary(),
        groups: [SimilarSkillGroup] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [SimilarSkillEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: SimilarSkillSafety = SimilarSkillSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.groups = groups
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
        filters = try container.decodeIfPresent(SimilarSkillGroupingFilters.self, forKey: .filters) ?? SimilarSkillGroupingFilters()
        groups = try container.decodeIfPresent([SimilarSkillGroup].self, forKey: .groups)
            ?? container.decodeIfPresent([SimilarSkillGroup].self, forKey: .rows)
            ?? container.decodeIfPresent([SimilarSkillGroup].self, forKey: .results)
            ?? container.decodeIfPresent([SimilarSkillGroup].self, forKey: .matches)
            ?? []
        summary = try container.decodeIfPresent(SimilarSkillGroupingSummary.self, forKey: .summary)
            ?? SimilarSkillGroupingSummary(groupCount: groups.count, memberCount: groups.reduce(0) { $0 + $1.members.count })
        gapNotes = try container.decodeFlexibleSimilarStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleSimilarStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([SimilarSkillEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([SimilarSkillEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([SimilarSkillEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(SimilarSkillSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(SimilarSkillSafety.self, forKey: .safety)
            ?? SimilarSkillSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.similarGroupingUnavailable) -> SimilarSkillGroupingResult {
        SimilarSkillGroupingResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private struct SimilarSkillSourceInfo: Decodable, Hashable {
    let path: String?
    let kind: String?
    let root: String?

    enum CodingKeys: String, CodingKey {
        case path
        case sourcePath = "source_path"
        case sourcePathAlt = "sourcePath"
        case kind
        case sourceKind = "source_kind"
        case sourceKindAlt = "sourceKind"
        case root
        case sourceRoot = "source_root"
        case sourceRootAlt = "sourceRoot"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeIfPresent(String.self, forKey: .path)
            ?? container.decodeIfPresent(String.self, forKey: .sourcePath)
            ?? container.decodeIfPresent(String.self, forKey: .sourcePathAlt)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .sourceKind)
            ?? container.decodeIfPresent(String.self, forKey: .sourceKindAlt)
        root = try container.decodeIfPresent(String.self, forKey: .root)
            ?? container.decodeIfPresent(String.self, forKey: .sourceRoot)
            ?? container.decodeIfPresent(String.self, forKey: .sourceRootAlt)
    }
}

private struct SimilarSkillScoreContext: Decodable, Hashable {
    let score: Double?
    let band: String?

    enum CodingKeys: String, CodingKey {
        case score
        case value
        case qualityScore = "quality_score"
        case readinessScore = "readiness_score"
        case band
        case label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decodeFlexibleSimilarDouble(keys: [.score, .value, .qualityScore, .readinessScore])
        band = try container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .label)
    }
}

private struct SimilarSkillStateContext: Decodable, Hashable {
    let state: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case state
        case kind
        case status
        case summary
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            state = value
            summary = value
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decodeIfPresent(String.self, forKey: .state)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .status)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleSimilarInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([SimilarSkillGroup].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([SimilarSkillMember].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleSimilarDouble(keys: [Key]) throws -> Double? {
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

    func decodeFlexibleSimilarBool(keys: [Key]) throws -> Bool? {
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

    func decodeFlexibleSimilarString(keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value ? UIStrings.stateEnabled : UIStrings.stateDisabled
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return "\(value)"
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return RoutingAccuracySummary.confidenceLabel(value)
            }
        }
        return nil
    }

    func decodeFlexibleSimilarStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([SimilarSkillEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(SimilarSkillEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
            if let values = try? decodeIfPresent([SimilarSkillMember].self, forKey: key) {
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
