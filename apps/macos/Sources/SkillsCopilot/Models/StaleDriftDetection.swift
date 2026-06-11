import Foundation

struct StaleDriftFilters: Decodable, Hashable {
    let agent: String?
    let agents: [String]
    let limit: Int?
    let includeReadinessImpact: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case agents
        case limit
        case includeReadinessImpact = "include_readiness_impact"
        case includeReadinessImpactAlt = "includeReadinessImpact"
    }

    init(agent: String? = nil, agents: [String] = [], limit: Int? = nil, includeReadinessImpact: Bool = true) {
        self.agent = agent
        self.agents = agents
        self.limit = limit
        self.includeReadinessImpact = includeReadinessImpact
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        let decodedAgents = try container.decodeFlexibleStaleDriftStringArray(keys: [.agents, .agent])
        agents = decodedAgents
        limit = try container.decodeFlexibleStaleDriftInt(keys: [.limit])
        includeReadinessImpact = try container.decodeIfPresent(Bool.self, forKey: .includeReadinessImpact)
            ?? container.decodeIfPresent(Bool.self, forKey: .includeReadinessImpactAlt)
            ?? true
    }
}

struct StaleDriftSummary: Decodable, Hashable {
    let staleCount: Int
    let driftCount: Int
    let candidateCount: Int
    let affectedAgentCount: Int
    let readinessImpactCount: Int
    let gapIssueCount: Int
    let highRiskCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case staleCount = "stale_count"
        case stale
        case driftCount = "drift_count"
        case drift
        case candidateCount = "candidate_count"
        case candidates
        case affectedAgentCount = "affected_agent_count"
        case affectedAgents = "affected_agents"
        case readinessImpactCount = "readiness_impact_count"
        case readinessImpacts = "readiness_impacts"
        case gapIssueCount = "gap_issue_count"
        case gaps
        case issues
        case highRiskCount = "high_risk_count"
        case highRisk = "high_risk"
        case summary
        case message
    }

    init(
        staleCount: Int = 0,
        driftCount: Int = 0,
        candidateCount: Int = 0,
        affectedAgentCount: Int = 0,
        readinessImpactCount: Int = 0,
        gapIssueCount: Int = 0,
        highRiskCount: Int = 0,
        summaryText: String = ""
    ) {
        self.staleCount = staleCount
        self.driftCount = driftCount
        self.candidateCount = candidateCount
        self.affectedAgentCount = affectedAgentCount
        self.readinessImpactCount = readinessImpactCount
        self.gapIssueCount = gapIssueCount
        self.highRiskCount = highRiskCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        staleCount = try container.decodeFlexibleStaleDriftInt(keys: [.staleCount, .stale]) ?? 0
        driftCount = try container.decodeFlexibleStaleDriftInt(keys: [.driftCount, .drift]) ?? 0
        candidateCount = try container.decodeFlexibleStaleDriftInt(keys: [.candidateCount, .candidates]) ?? 0
        affectedAgentCount = try container.decodeFlexibleStaleDriftInt(keys: [.affectedAgentCount, .affectedAgents]) ?? 0
        readinessImpactCount = try container.decodeFlexibleStaleDriftInt(keys: [.readinessImpactCount, .readinessImpacts]) ?? 0
        gapIssueCount = try container.decodeFlexibleStaleDriftInt(keys: [.gapIssueCount, .gaps, .issues]) ?? 0
        highRiskCount = try container.decodeFlexibleStaleDriftInt(keys: [.highRiskCount, .highRisk]) ?? 0
        summaryText = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
    }
}

struct StaleDriftSkillRef: Decodable, Hashable {
    let instanceID: String?
    let definitionID: String?
    let name: String
    let agent: String?
    let scope: String?
    let state: String?
    let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case instanceIDAlt = "instanceId"
        case definitionID = "definition_id"
        case definitionIDAlt = "definitionId"
        case id
        case name
        case skillName = "skill_name"
        case title
        case agent
        case scope
        case state
        case enabled
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            instanceID = nil
            definitionID = nil
            name = value
            agent = nil
            scope = nil
            state = nil
            enabled = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        definitionID = try container.decodeIfPresent(String.self, forKey: .definitionID)
            ?? container.decodeIfPresent(String.self, forKey: .definitionIDAlt)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .skillName)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? instanceID
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
    }
}

struct StaleDriftRow: Decodable, Hashable, Identifiable {
    let id: String
    let kind: String
    let severity: String?
    let agent: String?
    let skill: StaleDriftSkillRef?
    let title: String
    let summary: String
    let lastSeen: String?
    let currentSignal: String?
    let expectedSignal: String?
    let confidence: Double?
    let reasons: [String]
    let signals: [String]
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case type
        case category
        case severity
        case risk
        case agent
        case skill
        case candidate
        case title
        case name
        case summary
        case detail
        case message
        case lastSeen = "last_seen"
        case lastSeenAlt = "lastSeen"
        case currentSignal = "current_signal"
        case currentSignalAlt = "currentSignal"
        case current
        case expectedSignal = "expected_signal"
        case expectedSignalAlt = "expectedSignal"
        case expected
        case confidence
        case score
        case reasons
        case reason
        case signals
        case signal
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case evidenceReferences = "evidence_references"
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            kind = UIStrings.staleDriftCandidate
            severity = nil
            agent = nil
            skill = nil
            title = value
            summary = value
            lastSeen = nil
            currentSignal = nil
            expectedSignal = nil
            confidence = nil
            reasons = []
            signals = []
            evidenceRefs = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .category)
            ?? UIStrings.staleDriftCandidate
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .risk)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        skill = try container.decodeIfPresent(StaleDriftSkillRef.self, forKey: .skill)
            ?? container.decodeIfPresent(StaleDriftSkillRef.self, forKey: .candidate)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? skill?.name
            ?? UIStrings.staleDriftCandidate
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? title
        lastSeen = try container.decodeIfPresent(String.self, forKey: .lastSeen)
            ?? container.decodeIfPresent(String.self, forKey: .lastSeenAlt)
        currentSignal = try container.decodeFlexibleStaleDriftString(keys: [.currentSignal, .currentSignalAlt, .current])
        expectedSignal = try container.decodeFlexibleStaleDriftString(keys: [.expectedSignal, .expectedSignalAlt, .expected])
        confidence = try container.decodeFlexibleStaleDriftDouble(keys: [.confidence, .score])
        reasons = try container.decodeFlexibleStaleDriftStringArray(keys: [.reasons, .reason])
        signals = try container.decodeFlexibleStaleDriftStringArray(keys: [.signals, .signal])
        evidenceRefs = try container.decodeFlexibleStaleDriftStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence, .evidenceReferences])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(agent ?? "")-\(kind)-\(title)-\(summary)"
    }

    var confidenceLabel: String {
        guard let confidence else { return UIStrings.unknown }
        return RoutingAccuracySummary.confidenceLabel(confidence)
    }
}

struct StaleDriftImpactRow: Decodable, Hashable, Identifiable {
    let id: String
    let agent: String?
    let skillName: String?
    let severity: String?
    let title: String
    let detail: String
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case agent
        case skillName = "skill_name"
        case skillNameAlt = "skillName"
        case severity
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
            agent = nil
            skillName = nil
            severity = nil
            title = value
            detail = value
            evidenceRefs = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        skillName = try container.decodeIfPresent(String.self, forKey: .skillName)
            ?? container.decodeIfPresent(String.self, forKey: .skillNameAlt)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? title
        evidenceRefs = try container.decodeFlexibleStaleDriftStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(agent ?? "")-\(skillName ?? "")-\(title)-\(detail)"
    }
}

typealias StaleDriftEvidenceReference = CrossAgentReadinessEvidenceReference
typealias StaleDriftSafety = CrossAgentReadinessSafety

struct StaleDriftDetectionResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: StaleDriftFilters
    let summary: StaleDriftSummary
    let staleDriftRows: [StaleDriftRow]
    let readinessImpactRows: [StaleDriftImpactRow]
    let gapIssueRows: [StaleDriftImpactRow]
    let evidenceReferences: [StaleDriftEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: StaleDriftSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case staleDriftRows = "stale_drift_rows"
        case staleDriftRowsAlt = "staleDriftRows"
        case rows
        case candidates
        case readinessImpactRows = "readiness_impact_rows"
        case readinessImpactRowsAlt = "readinessImpactRows"
        case readinessImpacts = "readiness_impacts"
        case readinessImpactsAlt = "readinessImpacts"
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
        generatedBy: String = "local",
        catalogAvailable: Bool = false,
        filters: StaleDriftFilters = StaleDriftFilters(),
        summary: StaleDriftSummary = StaleDriftSummary(),
        staleDriftRows: [StaleDriftRow] = [],
        readinessImpactRows: [StaleDriftImpactRow] = [],
        gapIssueRows: [StaleDriftImpactRow] = [],
        evidenceReferences: [StaleDriftEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: StaleDriftSafety = StaleDriftSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.staleDriftRows = staleDriftRows
        self.readinessImpactRows = readinessImpactRows
        self.gapIssueRows = gapIssueRows
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
        filters = try container.decodeIfPresent(StaleDriftFilters.self, forKey: .filters) ?? StaleDriftFilters()
        summary = try container.decodeIfPresent(StaleDriftSummary.self, forKey: .summary) ?? StaleDriftSummary()
        staleDriftRows = try container.decodeIfPresent([StaleDriftRow].self, forKey: .staleDriftRows)
            ?? container.decodeIfPresent([StaleDriftRow].self, forKey: .staleDriftRowsAlt)
            ?? container.decodeIfPresent([StaleDriftRow].self, forKey: .rows)
            ?? container.decodeIfPresent([StaleDriftRow].self, forKey: .candidates)
            ?? []
        readinessImpactRows = try container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .readinessImpactRows)
            ?? container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .readinessImpactRowsAlt)
            ?? container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .readinessImpacts)
            ?? container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .readinessImpactsAlt)
            ?? []
        gapIssueRows = try container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .gapIssueRows)
            ?? container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .gapIssueRowsAlt)
            ?? container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .gaps)
            ?? container.decodeIfPresent([StaleDriftImpactRow].self, forKey: .issues)
            ?? []
        evidenceReferences = try container.decodeIfPresent([StaleDriftEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([StaleDriftEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([StaleDriftEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        if let decodedSafety = try container.decodeIfPresent(StaleDriftSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(StaleDriftSafety.self, forKey: .safety) {
            safetyFlags = decodedSafety
        } else {
            safetyFlags = StaleDriftSafety(
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

    static func unavailable(reason: String = UIStrings.staleDriftUnavailable) -> StaleDriftDetectionResult {
        StaleDriftDetectionResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStaleDriftInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([StaleDriftRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([StaleDriftImpactRow].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleStaleDriftDouble(keys: [Key]) throws -> Double? {
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

    func decodeFlexibleStaleDriftString(keys: [Key]) throws -> String? {
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
            if let value = try? decodeIfPresent(StaleDriftEvidenceReference.self, forKey: key) {
                return value.detail
            }
        }
        return nil
    }

    func decodeFlexibleStaleDriftStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([StaleDriftEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let values = try? decodeIfPresent([StaleDriftImpactRow].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(StaleDriftEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
        }
        return []
    }
}
