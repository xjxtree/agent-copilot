import Foundation

struct CrossAgentReadinessFilters: Decodable, Hashable {
    let agents: [String]
    let limitPerAgent: Int?
    let includeRoutingAccuracy: Bool
    let includeBenchmarks: Bool

    enum CodingKeys: String, CodingKey {
        case agents
        case agent
        case limitPerAgent = "limit_per_agent"
        case limitPerAgentAlt = "limitPerAgent"
        case includeRoutingAccuracy = "include_routing_accuracy"
        case includeRoutingAccuracyAlt = "includeRoutingAccuracy"
        case includeBenchmarks = "include_benchmarks"
        case includeBenchmarksAlt = "includeBenchmarks"
    }

    init(
        agents: [String] = [],
        limitPerAgent: Int? = nil,
        includeRoutingAccuracy: Bool = true,
        includeBenchmarks: Bool = true
    ) {
        self.agents = agents
        self.limitPerAgent = limitPerAgent
        self.includeRoutingAccuracy = includeRoutingAccuracy
        self.includeBenchmarks = includeBenchmarks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agents = try container.decodeFlexibleCrossAgentStringArray(keys: [.agents, .agent])
        limitPerAgent = try container.decodeFlexibleCrossAgentInt(keys: [.limitPerAgent, .limitPerAgentAlt])
        includeRoutingAccuracy = try container.decodeIfPresent(Bool.self, forKey: .includeRoutingAccuracy)
            ?? container.decodeIfPresent(Bool.self, forKey: .includeRoutingAccuracyAlt)
            ?? true
        includeBenchmarks = try container.decodeIfPresent(Bool.self, forKey: .includeBenchmarks)
            ?? container.decodeIfPresent(Bool.self, forKey: .includeBenchmarksAlt)
            ?? true
    }
}

struct CrossAgentReadinessSummary: Decodable, Hashable {
    let agentCount: Int
    let candidateCount: Int
    let readyCount: Int
    let partialCount: Int
    let blockedCount: Int
    let gapCount: Int
    let blockerCount: Int
    let averageReadinessScore: Double?
    let averageRoutingScore: Double?
    let recommendedAgent: String?
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case agentCount = "agent_count"
        case agents
        case candidateCount = "candidate_count"
        case candidates
        case readyCount = "ready_count"
        case readyAgentCount = "ready_agent_count"
        case ready
        case partialCount = "partial_count"
        case partialAgentCount = "partial_agent_count"
        case partial
        case blockedCount = "blocked_count"
        case blockedAgentCount = "blocked_agent_count"
        case blocked
        case gapCount = "gap_count"
        case gapIssueCount = "gap_issue_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case averageReadinessScore = "average_readiness_score"
        case avgReadinessScore = "avg_readiness_score"
        case averageRoutingScore = "average_routing_score"
        case avgRoutingScore = "avg_routing_score"
        case recommendedAgent = "recommended_agent"
        case summary
        case message
    }

    init(
        agentCount: Int = 0,
        candidateCount: Int = 0,
        readyCount: Int = 0,
        partialCount: Int = 0,
        blockedCount: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        averageReadinessScore: Double? = nil,
        averageRoutingScore: Double? = nil,
        recommendedAgent: String? = nil,
        summaryText: String = ""
    ) {
        self.agentCount = agentCount
        self.candidateCount = candidateCount
        self.readyCount = readyCount
        self.partialCount = partialCount
        self.blockedCount = blockedCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.averageReadinessScore = averageReadinessScore
        self.averageRoutingScore = averageRoutingScore
        self.recommendedAgent = recommendedAgent
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agentCount = try container.decodeFlexibleCrossAgentInt(keys: [.agentCount, .agents]) ?? 0
        candidateCount = try container.decodeFlexibleCrossAgentInt(keys: [.candidateCount, .candidates]) ?? 0
        readyCount = try container.decodeFlexibleCrossAgentInt(keys: [.readyCount, .readyAgentCount, .ready]) ?? 0
        partialCount = try container.decodeFlexibleCrossAgentInt(keys: [.partialCount, .partialAgentCount, .partial]) ?? 0
        blockedCount = try container.decodeFlexibleCrossAgentInt(keys: [.blockedCount, .blockedAgentCount, .blocked]) ?? 0
        gapCount = try container.decodeFlexibleCrossAgentInt(keys: [.gapCount, .gapIssueCount, .gaps]) ?? 0
        blockerCount = try container.decodeFlexibleCrossAgentInt(keys: [.blockerCount, .blockers]) ?? 0
        averageReadinessScore = try container.decodeFlexibleCrossAgentDouble(keys: [.averageReadinessScore, .avgReadinessScore])
        averageRoutingScore = try container.decodeFlexibleCrossAgentDouble(keys: [.averageRoutingScore, .avgRoutingScore])
        recommendedAgent = try container.decodeIfPresent(String.self, forKey: .recommendedAgent)
        summaryText = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
    }

    static func scoreLabel(_ value: Double?) -> String {
        guard let value else { return UIStrings.unknown }
        if value <= 1 {
            return value.formatted(.percent.precision(.fractionLength(0...1)))
        }
        return Int(value.rounded()).formatted()
    }
}

struct CrossAgentReadinessSkillRef: Decodable, Hashable, Identifiable {
    let instanceID: String?
    let definitionID: String?
    let name: String
    let agent: String?
    let scope: String?
    let enabled: Bool?
    let state: String?
    let readinessScore: Int?
    let readinessBand: String?
    let routingScore: Int?
    let routingBand: String?
    let qualityScore: Int?

    var id: String { instanceID ?? "\(agent ?? "")-\(scope ?? "")-\(name)" }

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case definitionID = "definition_id"
        case definitionId = "definitionId"
        case id
        case name
        case skillName = "skill_name"
        case title
        case agent
        case scope
        case enabled
        case state
        case readinessScore = "readiness_score"
        case readinessBand = "readiness_band"
        case routingScore = "routing_confidence_score"
        case routingScoreAlt = "routing_score"
        case routingBand = "routing_confidence_band"
        case routingBandAlt = "routing_band"
        case qualityScore = "quality_score"
    }

    init(instanceID: String? = nil, definitionID: String? = nil, name: String, agent: String? = nil, scope: String? = nil, enabled: Bool? = nil, state: String? = nil, readinessScore: Int? = nil, readinessBand: String? = nil, routingScore: Int? = nil, routingBand: String? = nil, qualityScore: Int? = nil) {
        self.instanceID = instanceID
        self.definitionID = definitionID
        self.name = name
        self.agent = agent
        self.scope = scope
        self.enabled = enabled
        self.state = state
        self.readinessScore = readinessScore
        self.readinessBand = readinessBand
        self.routingScore = routingScore
        self.routingBand = routingBand
        self.qualityScore = qualityScore
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            instanceID = nil
            definitionID = nil
            name = value
            agent = nil
            scope = nil
            enabled = nil
            state = nil
            readinessScore = nil
            readinessBand = nil
            routingScore = nil
            routingBand = nil
            qualityScore = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        definitionID = try container.decodeIfPresent(String.self, forKey: .definitionID)
            ?? container.decodeIfPresent(String.self, forKey: .definitionId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .skillName)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? instanceID
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        readinessScore = try container.decodeFlexibleCrossAgentInt(keys: [.readinessScore])
        readinessBand = try container.decodeIfPresent(String.self, forKey: .readinessBand)
        routingScore = try container.decodeFlexibleCrossAgentInt(keys: [.routingScore, .routingScoreAlt])
        routingBand = try container.decodeIfPresent(String.self, forKey: .routingBand)
            ?? container.decodeIfPresent(String.self, forKey: .routingBandAlt)
        qualityScore = try container.decodeFlexibleCrossAgentInt(keys: [.qualityScore])
    }
}

struct CrossAgentReadinessStateSummary: Decodable, Hashable {
    let enabled: Bool?
    let scope: String?
    let state: String?
    let riskLevel: String?
    let riskSummary: String?
    let writableStatus: String?
    let adapterStatus: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case scope
        case state
        case riskLevel = "risk_level"
        case riskSummary = "risk_summary"
        case writableStatus = "writable_status"
        case adapterStatus = "adapter_status"
    }
}

struct CrossAgentReadinessContext: Decodable, Hashable {
    let summary: String

    enum CodingKeys: String, CodingKey {
        case summary
        case detail
        case message
        case status
        case hitRate = "hit_rate"
        case accuracyRate = "accuracy_rate"
        case regressionCount = "regression_count"
        case benchmarkCount = "benchmark_count"
        case matchedCount = "matched_count"
        case gapCount = "gap_count"
    }

    init(summary: String = "") {
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            summary = value
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedSummary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .status) {
            summary = decodedSummary
            return
        }
        let parts = [
            try container.decodeFlexibleCrossAgentDouble(keys: [.accuracyRate, .hitRate]).map(RoutingAccuracySummary.percentLabel),
            try container.decodeFlexibleCrossAgentInt(keys: [.regressionCount]).map { "\(UIStrings.routingAccuracyRegressions) \($0)" },
            try container.decodeFlexibleCrossAgentInt(keys: [.benchmarkCount]).map { "\(UIStrings.routingAccuracyBenchmarks) \($0)" },
            try container.decodeFlexibleCrossAgentInt(keys: [.matchedCount]).map { "\(UIStrings.taskBenchmarkMatched) \($0)" },
            try container.decodeFlexibleCrossAgentInt(keys: [.gapCount]).map { "\(UIStrings.taskReadinessGaps) \($0)" }
        ].compactMap { $0 }
        summary = parts.joined(separator: " · ")
    }
}

struct CrossAgentReadinessRecommendedAgent: Decodable, Hashable {
    let agent: String
    let displayName: String?
    let comparisonScore: Int?
    let score: Int?
    let routingScore: Int?
    let band: String?
    let summary: String
    let skill: CrossAgentReadinessSkillRef?

    enum CodingKeys: String, CodingKey {
        case agent
        case name
        case displayName = "display_name"
        case comparisonScore = "comparison_score"
        case score
        case readinessScore = "readiness_score"
        case routingScore = "routing_confidence_score"
        case band
        case readinessBand = "readiness_band"
        case summary
        case reason
        case rationale
        case skillName = "skill_name"
        case skill
        case bestCandidateSkill = "best_candidate_skill"
        case bestSkill = "best_skill"
    }

    init(agent: String, displayName: String? = nil, comparisonScore: Int? = nil, score: Int? = nil, routingScore: Int? = nil, band: String? = nil, summary: String = "", skill: CrossAgentReadinessSkillRef? = nil) {
        self.agent = agent
        self.displayName = displayName
        self.comparisonScore = comparisonScore
        self.score = score
        self.routingScore = routingScore
        self.band = band
        self.summary = summary
        self.skill = skill
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            agent = value
            displayName = nil
            comparisonScore = nil
            score = nil
            routingScore = nil
            band = nil
            summary = ""
            skill = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        comparisonScore = try container.decodeFlexibleCrossAgentInt(keys: [.comparisonScore])
        score = try container.decodeFlexibleCrossAgentInt(keys: [.readinessScore, .score])
        routingScore = try container.decodeFlexibleCrossAgentInt(keys: [.routingScore])
        band = try container.decodeIfPresent(String.self, forKey: .readinessBand)
            ?? container.decodeIfPresent(String.self, forKey: .band)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? ""
        let decodedSkill = try container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .bestCandidateSkill)
            ?? container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .bestSkill)
            ?? container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .skill)
        if let decodedSkill {
            skill = decodedSkill
        } else if let skillName = try container.decodeIfPresent(String.self, forKey: .skillName) {
            skill = CrossAgentReadinessSkillRef(name: skillName, agent: agent)
        } else {
            skill = nil
        }
    }
}

struct CrossAgentReadinessAgentRow: Decodable, Hashable, Identifiable {
    let rank: Int?
    let agent: String
    let displayName: String?
    let comparisonScore: Int?
    let readinessScore: Int
    let readinessBand: String
    let routingScore: Int?
    let routingBand: String?
    let bestCandidateSkill: CrossAgentReadinessSkillRef?
    let candidateCount: Int
    let enabledState: String?
    let scopeState: String?
    let riskState: String?
    let blockerCount: Int
    let gapCount: Int
    let accuracyContext: String?
    let benchmarkContext: String?
    let regressionContext: String?
    let reasons: [String]
    let blockerNotes: [String]
    let gapNotes: [String]
    let evidenceRefs: [String]

    var id: String { agent }

    enum CodingKeys: String, CodingKey {
        case rank
        case agent
        case name
        case displayName = "display_name"
        case comparisonScore = "comparison_score"
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case score
        case readinessBand = "readiness_band"
        case readinessBandAlt = "readinessBand"
        case band
        case status
        case routingConfidenceScore = "routing_confidence_score"
        case routingScore = "routing_score"
        case routingScoreAlt = "routingScore"
        case confidenceScore = "confidence_score"
        case routingConfidenceBand = "routing_confidence_band"
        case routingBand = "routing_band"
        case routingBandAlt = "routingBand"
        case confidenceBand = "confidence_band"
        case bestCandidate = "best_candidate"
        case bestCandidateSkill = "best_candidate_skill"
        case bestCandidateSkillAlt = "bestCandidateSkill"
        case bestSkill = "best_skill"
        case skill
        case candidateCount = "candidate_count"
        case candidateCountAlt = "candidateCount"
        case candidates
        case enabledState = "enabled_state"
        case enabledStateAlt = "enabledState"
        case enabled
        case scopeState = "scope_state"
        case scopeStateAlt = "scopeState"
        case scope
        case riskState = "risk_state"
        case riskStateAlt = "riskState"
        case risk
        case enabledScopeRiskState = "enabled_scope_risk_state"
        case blockerCount = "blocker_count"
        case blockerCountAlt = "blockerCount"
        case blockers
        case gapCount = "gap_count"
        case gapCountAlt = "gapCount"
        case gaps
        case accuracyContext = "accuracy_context"
        case accuracyContextAlt = "accuracyContext"
        case accuracy
        case routingAccuracyContext = "routing_accuracy_context"
        case benchmarkContext = "benchmark_context"
        case regressionContext = "regression_context"
        case regressionContextAlt = "regressionContext"
        case regression
        case reasons
        case reason
        case matchReasons = "match_reasons"
        case matchReasonsAlt = "matchReasons"
        case blockerNotes = "blocker_notes"
        case gapNotes = "gap_notes"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case evidenceReferences = "evidence_references"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decodeFlexibleCrossAgentInt(keys: [.rank])
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        comparisonScore = try container.decodeFlexibleCrossAgentInt(keys: [.comparisonScore])
        readinessScore = min(100, max(0, try container.decodeFlexibleCrossAgentInt(keys: [.readinessScore, .readinessScoreAlt, .score]) ?? 0))
        readinessBand = try container.decodeIfPresent(String.self, forKey: .readinessBand)
            ?? container.decodeIfPresent(String.self, forKey: .readinessBandAlt)
            ?? container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? SkillRoutingConfidenceResult.band(for: readinessScore)
        routingScore = try container.decodeFlexibleCrossAgentInt(keys: [.routingConfidenceScore, .routingScore, .routingScoreAlt, .confidenceScore]).map { min(100, max(0, $0)) }
        routingBand = try container.decodeIfPresent(String.self, forKey: .routingConfidenceBand)
            ?? container.decodeIfPresent(String.self, forKey: .routingBand)
            ?? container.decodeIfPresent(String.self, forKey: .routingBandAlt)
            ?? container.decodeIfPresent(String.self, forKey: .confidenceBand)
        bestCandidateSkill = try container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .bestCandidate)
            ?? container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .bestCandidateSkill)
            ?? container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .bestCandidateSkillAlt)
            ?? container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .bestSkill)
            ?? container.decodeIfPresent(CrossAgentReadinessSkillRef.self, forKey: .skill)
        candidateCount = try container.decodeFlexibleCrossAgentInt(keys: [.candidateCount, .candidateCountAlt, .candidates]) ?? 0
        let stateSummary = try container.decodeIfPresent(CrossAgentReadinessStateSummary.self, forKey: .enabledScopeRiskState)
        enabledState = try container.decodeFlexibleCrossAgentString(keys: [.enabledState, .enabledStateAlt, .enabled])
            ?? stateSummary?.enabled.map { $0 ? UIStrings.stateEnabled : UIStrings.stateDisabled }
        scopeState = try container.decodeFlexibleCrossAgentString(keys: [.scopeState, .scopeStateAlt, .scope])
            ?? stateSummary?.scope
        riskState = try container.decodeFlexibleCrossAgentString(keys: [.riskState, .riskStateAlt, .risk])
            ?? stateSummary?.riskLevel
            ?? stateSummary?.riskSummary
        blockerCount = try container.decodeFlexibleCrossAgentInt(keys: [.blockerCount, .blockerCountAlt, .blockers]) ?? 0
        gapCount = try container.decodeFlexibleCrossAgentInt(keys: [.gapCount, .gapCountAlt, .gaps]) ?? 0
        accuracyContext = try container.decodeFlexibleCrossAgentString(keys: [.accuracyContext, .accuracyContextAlt, .accuracy])
            ?? container.decodeIfPresent(CrossAgentReadinessContext.self, forKey: .routingAccuracyContext)?.summary.nonEmptyCrossAgentText
        benchmarkContext = try container.decodeIfPresent(CrossAgentReadinessContext.self, forKey: .benchmarkContext)?.summary.nonEmptyCrossAgentText
        regressionContext = try container.decodeFlexibleCrossAgentString(keys: [.regressionContext, .regressionContextAlt, .regression])
            ?? stateSummary?.adapterStatus
        reasons = try container.decodeFlexibleCrossAgentStringArray(keys: [.reasons, .reason, .matchReasons, .matchReasonsAlt])
        blockerNotes = try container.decodeFlexibleCrossAgentStringArray(keys: [.blockerNotes])
        gapNotes = try container.decodeFlexibleCrossAgentStringArray(keys: [.gapNotes])
        evidenceRefs = try container.decodeFlexibleCrossAgentStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence, .evidenceReferences])
    }

    var routingLabel: String {
        guard let routingScore else { return UIStrings.unknown }
        if let routingBand, !routingBand.isEmpty {
            return "\(routingScore) · \(routingBand)"
        }
        return "\(routingScore)"
    }
}

struct CrossAgentReadinessGapIssueRow: Decodable, Hashable, Identifiable {
    let id: String
    let source: String?
    let severity: String?
    let agent: String?
    let title: String
    let detail: String
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case severity
        case agent
        case title
        case label
        case name
        case detail
        case summary
        case message
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            source = nil
            severity = nil
            agent = nil
            title = value
            detail = value
            evidenceRefs = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? title
        evidenceRefs = try container.decodeFlexibleCrossAgentStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(source ?? "")-\(agent ?? "")-\(title)-\(detail)"
    }
}

struct CrossAgentReadinessEvidenceReference: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let source: String?
    let agent: String?

    init(stringValue value: String) {
        id = value
        title = value
        detail = value
        source = nil
        agent = nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case label
        case name
        case detail
        case summary
        case message
        case source
        case agent
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            detail = value
            source = nil
            agent = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? title
        source = try container.decodeIfPresent(String.self, forKey: .source)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(source ?? "")-\(agent ?? "")-\(title)-\(detail)"
    }
}

struct CrossAgentReadinessSafety: Decodable, Hashable {
    let providerRequestSent: Bool
    let writeBackAllowed: Bool
    let writeActionsAvailable: Bool
    let scriptExecutionAllowed: Bool
    let executionActionsAvailable: Bool
    let configMutationAllowed: Bool
    let snapshotCreated: Bool
    let triageMutationAllowed: Bool
    let credentialAccessed: Bool
    let rawPromptPersisted: Bool
    let rawResponsePersisted: Bool
    let rawTracePersisted: Bool
    let cloudSyncEnabled: Bool
    let telemetryEnabled: Bool
    let rawSecretReturned: Bool
    let notes: [String]

    var allReadOnlyFlagsClear: Bool {
        !providerRequestSent
            && !writeBackAllowed
            && !writeActionsAvailable
            && !scriptExecutionAllowed
            && !executionActionsAvailable
            && !configMutationAllowed
            && !snapshotCreated
            && !triageMutationAllowed
            && !credentialAccessed
            && !rawPromptPersisted
            && !rawResponsePersisted
            && !rawTracePersisted
            && !cloudSyncEnabled
            && !telemetryEnabled
            && !rawSecretReturned
    }

    enum CodingKeys: String, CodingKey {
        case providerRequestSent = "provider_request_sent"
        case providerCallSent = "provider_call_sent"
        case writeBackAllowed = "write_back_allowed"
        case writeActionsAvailable = "write_actions_available"
        case writesAllowed = "writes_allowed"
        case scriptExecutionAllowed = "script_execution_allowed"
        case executionActionsAvailable = "execution_actions_available"
        case configMutationAllowed = "config_mutation_allowed"
        case snapshotCreated = "snapshot_created"
        case triageMutationAllowed = "triage_mutation_allowed"
        case credentialAccessed = "credential_accessed"
        case rawPromptPersisted = "raw_prompt_persisted"
        case rawResponsePersisted = "raw_response_persisted"
        case rawTracePersisted = "raw_trace_persisted"
        case rawTraceStored = "raw_trace_stored"
        case cloudSyncEnabled = "cloud_sync_enabled"
        case cloudSyncPerformed = "cloud_sync_performed"
        case cloudSync = "cloud_sync"
        case telemetryEnabled = "telemetry_enabled"
        case telemetryEmitted = "telemetry_emitted"
        case telemetry
        case rawSecretReturned = "raw_secret_returned"
        case notes
        case flags
    }

    init(
        providerRequestSent: Bool = false,
        writeBackAllowed: Bool = false,
        writeActionsAvailable: Bool = false,
        scriptExecutionAllowed: Bool = false,
        executionActionsAvailable: Bool = false,
        configMutationAllowed: Bool = false,
        snapshotCreated: Bool = false,
        triageMutationAllowed: Bool = false,
        credentialAccessed: Bool = false,
        rawPromptPersisted: Bool = false,
        rawResponsePersisted: Bool = false,
        rawTracePersisted: Bool = false,
        cloudSyncEnabled: Bool = false,
        telemetryEnabled: Bool = false,
        rawSecretReturned: Bool = false,
        notes: [String] = []
    ) {
        self.providerRequestSent = providerRequestSent
        self.writeBackAllowed = writeBackAllowed
        self.writeActionsAvailable = writeActionsAvailable
        self.scriptExecutionAllowed = scriptExecutionAllowed
        self.executionActionsAvailable = executionActionsAvailable
        self.configMutationAllowed = configMutationAllowed
        self.snapshotCreated = snapshotCreated
        self.triageMutationAllowed = triageMutationAllowed
        self.credentialAccessed = credentialAccessed
        self.rawPromptPersisted = rawPromptPersisted
        self.rawResponsePersisted = rawResponsePersisted
        self.rawTracePersisted = rawTracePersisted
        self.cloudSyncEnabled = cloudSyncEnabled
        self.telemetryEnabled = telemetryEnabled
        self.rawSecretReturned = rawSecretReturned
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        if let values = try? decoder.singleValueContainer().decode([String].self) {
            self.init(notes: values)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            providerRequestSent: try container.decodeIfPresent(Bool.self, forKey: .providerRequestSent)
                ?? container.decodeIfPresent(Bool.self, forKey: .providerCallSent)
                ?? false,
            writeBackAllowed: try container.decodeIfPresent(Bool.self, forKey: .writeBackAllowed) ?? false,
            writeActionsAvailable: try container.decodeIfPresent(Bool.self, forKey: .writeActionsAvailable)
                ?? container.decodeIfPresent(Bool.self, forKey: .writesAllowed)
                ?? false,
            scriptExecutionAllowed: try container.decodeIfPresent(Bool.self, forKey: .scriptExecutionAllowed) ?? false,
            executionActionsAvailable: try container.decodeIfPresent(Bool.self, forKey: .executionActionsAvailable) ?? false,
            configMutationAllowed: try container.decodeIfPresent(Bool.self, forKey: .configMutationAllowed) ?? false,
            snapshotCreated: try container.decodeIfPresent(Bool.self, forKey: .snapshotCreated) ?? false,
            triageMutationAllowed: try container.decodeIfPresent(Bool.self, forKey: .triageMutationAllowed) ?? false,
            credentialAccessed: try container.decodeIfPresent(Bool.self, forKey: .credentialAccessed) ?? false,
            rawPromptPersisted: try container.decodeIfPresent(Bool.self, forKey: .rawPromptPersisted) ?? false,
            rawResponsePersisted: try container.decodeIfPresent(Bool.self, forKey: .rawResponsePersisted) ?? false,
            rawTracePersisted: try container.decodeIfPresent(Bool.self, forKey: .rawTracePersisted)
                ?? container.decodeIfPresent(Bool.self, forKey: .rawTraceStored)
                ?? false,
            cloudSyncEnabled: try container.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled)
                ?? container.decodeIfPresent(Bool.self, forKey: .cloudSyncPerformed)
                ?? container.decodeIfPresent(Bool.self, forKey: .cloudSync)
                ?? false,
            telemetryEnabled: try container.decodeIfPresent(Bool.self, forKey: .telemetryEnabled)
                ?? container.decodeIfPresent(Bool.self, forKey: .telemetryEmitted)
                ?? container.decodeIfPresent(Bool.self, forKey: .telemetry)
                ?? false,
            rawSecretReturned: try container.decodeIfPresent(Bool.self, forKey: .rawSecretReturned) ?? false,
            notes: try container.decodeFlexibleCrossAgentStringArray(keys: [.notes, .flags])
        )
    }
}

struct CrossAgentReadinessResult: Decodable, Hashable {
    let taskText: String
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: CrossAgentReadinessFilters
    let summary: CrossAgentReadinessSummary
    let agentRows: [CrossAgentReadinessAgentRow]
    let recommendedAgent: CrossAgentReadinessRecommendedAgent?
    let gapIssueRows: [CrossAgentReadinessGapIssueRow]
    let evidenceReferences: [CrossAgentReadinessEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: CrossAgentReadinessSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case agentRows = "agent_rows"
        case agentRowsAlt = "agentRows"
        case agents
        case recommendedAgent = "recommended_agent"
        case recommendedAgentAlt = "recommendedAgent"
        case recommendation
        case gapIssueRows = "gap_issue_rows"
        case gapIssueRowsAlt = "gapIssueRows"
        case gaps
        case issues
        case evidenceReferences = "evidence_references"
        case evidenceReferencesAlt = "evidenceReferences"
        case evidence
        case promptRequest = "prompt_request"
        case promptRequestAlt = "promptRequest"
        case safetyFlags = "safety_flags"
        case safety
        case fallbackReason = "fallback_reason"
        case reason
        case providerRequestSent = "provider_request_sent"
        case writeBackAllowed = "write_back_allowed"
        case scriptExecutionAllowed = "script_execution_allowed"
        case configMutationAllowed = "config_mutation_allowed"
        case snapshotCreated = "snapshot_created"
        case triageMutationAllowed = "triage_mutation_allowed"
        case credentialAccessed = "credential_accessed"
        case rawPromptPersisted = "raw_prompt_persisted"
        case rawResponsePersisted = "raw_response_persisted"
        case rawTracePersisted = "raw_trace_persisted"
        case cloudSyncEnabled = "cloud_sync_enabled"
        case telemetryEnabled = "telemetry_enabled"
        case rawSecretReturned = "raw_secret_returned"
    }

    init(
        taskText: String = "",
        generatedBy: String = "local",
        catalogAvailable: Bool = false,
        filters: CrossAgentReadinessFilters = CrossAgentReadinessFilters(),
        summary: CrossAgentReadinessSummary = CrossAgentReadinessSummary(),
        agentRows: [CrossAgentReadinessAgentRow] = [],
        recommendedAgent: CrossAgentReadinessRecommendedAgent? = nil,
        gapIssueRows: [CrossAgentReadinessGapIssueRow] = [],
        evidenceReferences: [CrossAgentReadinessEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: CrossAgentReadinessSafety = CrossAgentReadinessSafety(),
        fallbackReason: String? = nil
    ) {
        self.taskText = taskText
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.agentRows = agentRows
        self.recommendedAgent = recommendedAgent
        self.gapIssueRows = gapIssueRows
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? ""
        generatedBy = try container.decodeIfPresent(String.self, forKey: .generatedBy)
            ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
            ?? "local"
        catalogAvailable = try container.decodeIfPresent(Bool.self, forKey: .catalogAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .catalogAvailableAlt)
            ?? true
        filters = try container.decodeIfPresent(CrossAgentReadinessFilters.self, forKey: .filters) ?? CrossAgentReadinessFilters()
        summary = try container.decodeIfPresent(CrossAgentReadinessSummary.self, forKey: .summary) ?? CrossAgentReadinessSummary()
        agentRows = try container.decodeIfPresent([CrossAgentReadinessAgentRow].self, forKey: .agentRows)
            ?? container.decodeIfPresent([CrossAgentReadinessAgentRow].self, forKey: .agentRowsAlt)
            ?? container.decodeIfPresent([CrossAgentReadinessAgentRow].self, forKey: .agents)
            ?? []
        recommendedAgent = try container.decodeIfPresent(CrossAgentReadinessRecommendedAgent.self, forKey: .recommendedAgent)
            ?? container.decodeIfPresent(CrossAgentReadinessRecommendedAgent.self, forKey: .recommendedAgentAlt)
            ?? container.decodeIfPresent(CrossAgentReadinessRecommendedAgent.self, forKey: .recommendation)
        gapIssueRows = try container.decodeIfPresent([CrossAgentReadinessGapIssueRow].self, forKey: .gapIssueRows)
            ?? container.decodeIfPresent([CrossAgentReadinessGapIssueRow].self, forKey: .gapIssueRowsAlt)
            ?? container.decodeIfPresent([CrossAgentReadinessGapIssueRow].self, forKey: .gaps)
            ?? container.decodeIfPresent([CrossAgentReadinessGapIssueRow].self, forKey: .issues)
            ?? []
        evidenceReferences = try container.decodeIfPresent([CrossAgentReadinessEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([CrossAgentReadinessEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([CrossAgentReadinessEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        if let decodedSafety = try container.decodeIfPresent(CrossAgentReadinessSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(CrossAgentReadinessSafety.self, forKey: .safety) {
            safetyFlags = decodedSafety
        } else {
            safetyFlags = CrossAgentReadinessSafety(
                providerRequestSent: try container.decodeIfPresent(Bool.self, forKey: .providerRequestSent) ?? false,
                writeBackAllowed: try container.decodeIfPresent(Bool.self, forKey: .writeBackAllowed) ?? false,
                scriptExecutionAllowed: try container.decodeIfPresent(Bool.self, forKey: .scriptExecutionAllowed) ?? false,
                configMutationAllowed: try container.decodeIfPresent(Bool.self, forKey: .configMutationAllowed) ?? false,
                snapshotCreated: try container.decodeIfPresent(Bool.self, forKey: .snapshotCreated) ?? false,
                triageMutationAllowed: try container.decodeIfPresent(Bool.self, forKey: .triageMutationAllowed) ?? false,
                credentialAccessed: try container.decodeIfPresent(Bool.self, forKey: .credentialAccessed) ?? false,
                rawPromptPersisted: try container.decodeIfPresent(Bool.self, forKey: .rawPromptPersisted) ?? false,
                rawResponsePersisted: try container.decodeIfPresent(Bool.self, forKey: .rawResponsePersisted) ?? false,
                rawTracePersisted: try container.decodeIfPresent(Bool.self, forKey: .rawTracePersisted) ?? false,
                cloudSyncEnabled: try container.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled) ?? false,
                telemetryEnabled: try container.decodeIfPresent(Bool.self, forKey: .telemetryEnabled) ?? false,
                rawSecretReturned: try container.decodeIfPresent(Bool.self, forKey: .rawSecretReturned) ?? false
            )
        }
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(taskText: String = "", reason: String = UIStrings.crossAgentReadinessUnavailable) -> CrossAgentReadinessResult {
        CrossAgentReadinessResult(
            taskText: taskText,
            generatedBy: "unavailable",
            catalogAvailable: false,
            safetyFlags: CrossAgentReadinessSafety(),
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleCrossAgentInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([CrossAgentReadinessGapIssueRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([CrossAgentReadinessAgentRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([CrossAgentReadinessSkillRef].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleCrossAgentString(keys: [Key]) throws -> String? {
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
                return "\(value)"
            }
        }
        return nil
    }

    func decodeFlexibleCrossAgentDouble(keys: [Key]) throws -> Double? {
        for key in keys {
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let double = Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")) {
                return value.contains("%") ? double / 100 : double
            }
        }
        return nil
    }

    func decodeFlexibleCrossAgentStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([CrossAgentReadinessEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let values = try? decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: key) {
                return values.map(\.detail)
            }
        }
        return []
    }
}

private extension String {
    var nonEmptyCrossAgentText: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
