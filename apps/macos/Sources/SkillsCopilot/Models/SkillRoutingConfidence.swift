import Foundation

struct SkillRouteCandidate: Decodable, Hashable, Identifiable {
    let instanceID: String?
    let name: String
    let agent: String
    let confidenceScore: Int
    let band: String
    let summary: String
    let matchReasons: [String]
    let ambiguityWarnings: [String]
    let wrongPickRisks: [String]
    let evidence: [TaskReadinessEvidenceItem]

    var id: String { instanceID ?? "\(agent)-\(name)" }

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case id
        case name
        case skillName = "skill_name"
        case title
        case agent
        case confidenceScore = "confidence_score"
        case score
        case value
        case band
        case confidenceBand = "confidence_band"
        case status
        case summary
        case rationale
        case reason
        case matchReasons = "match_reasons"
        case matchReason = "match_reason"
        case confidenceRationale = "confidence_rationale"
        case reasons
        case matches
        case signals
        case ambiguityWarnings = "ambiguity_warnings"
        case ambiguity
        case warnings
        case wrongPickRisks = "wrong_pick_risks"
        case likelyWrongPickRisks = "likely_wrong_pick_risks"
        case likelyMissRisks = "likely_miss_risks"
        case wrongPickRisk = "wrong_pick_risk"
        case missExplanations = "miss_explanations"
        case risks
        case evidence
        case evidenceReferences = "evidence_references"
        case evidenceItems = "evidence_items"
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            instanceID = nil
            name = value
            agent = UIStrings.unknown
            confidenceScore = 0
            band = "Low"
            summary = ""
            matchReasons = []
            ambiguityWarnings = []
            wrongPickRisks = []
            evidence = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .skillName)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? instanceID
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent) ?? UIStrings.unknown
        let rawScore = try container.decodeFlexibleRoutingDouble(keys: [.confidenceScore, .score, .value]) ?? 0
        confidenceScore = min(100, max(0, Int(rawScore.rounded())))
        band = try container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .confidenceBand)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? SkillRoutingConfidenceResult.band(for: confidenceScore)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? ""
        matchReasons = try container.decodeFlexibleRoutingStringArray(keys: [.matchReasons, .matchReason, .confidenceRationale, .reasons, .matches, .signals])
        ambiguityWarnings = try container.decodeFlexibleRoutingStringArray(keys: [.ambiguityWarnings, .ambiguity, .warnings])
        wrongPickRisks = try container.decodeFlexibleRoutingStringArray(keys: [.wrongPickRisks, .likelyWrongPickRisks, .likelyMissRisks, .wrongPickRisk, .missExplanations, .risks])
        evidence = try container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceItems)
            ?? []
    }
}

struct SkillRoutingConfidenceResult: Decodable, Identifiable, Hashable {
    let taskText: String
    let score: Int
    let band: String
    let summary: String
    let routes: [SkillRouteCandidate]
    let ambiguityWarnings: [String]
    let wrongPickRisks: [String]
    let evidence: [TaskReadinessEvidenceItem]
    let safety: TaskReadinessSafety
    let fallbackReason: String?

    var id: String { taskText.isEmpty ? "routing-confidence" : taskText }

    enum CodingKeys: String, CodingKey {
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case overallConfidenceScore = "overall_confidence_score"
        case confidenceScore = "confidence_score"
        case score
        case value
        case overallConfidenceBand = "overall_confidence_band"
        case band
        case confidenceBand = "confidence_band"
        case status
        case summary
        case rationale
        case routes
        case routeCandidates = "route_candidates"
        case candidateRoutes = "candidate_routes"
        case candidateSkills = "candidate_skills"
        case candidates
        case skills
        case ambiguityWarnings = "ambiguity_warnings"
        case ambiguity
        case warnings
        case wrongPickRisks = "wrong_pick_risks"
        case likelyWrongPickRisks = "likely_wrong_pick_risks"
        case likelyMissRisks = "likely_miss_risks"
        case missExplanations = "miss_explanations"
        case risks
        case evidence
        case evidenceReferences = "evidence_references"
        case evidenceItems = "evidence_items"
        case safety
        case safetyFlags = "safety_flags"
        case fallbackReason = "fallback_reason"
        case reason
        case providerRequestSent = "provider_request_sent"
        case writeBackAllowed = "write_back_allowed"
        case writeActionsAvailable = "write_actions_available"
        case scriptExecutionAllowed = "script_execution_allowed"
        case executionActionsAvailable = "execution_actions_available"
        case configMutationAllowed = "config_mutation_allowed"
        case snapshotCreated = "snapshot_created"
        case triageMutationAllowed = "triage_mutation_allowed"
        case credentialAccessed = "credential_accessed"
        case rawSecretReturned = "raw_secret_returned"
    }

    init(
        taskText: String,
        score: Int,
        band: String,
        summary: String,
        routes: [SkillRouteCandidate],
        ambiguityWarnings: [String],
        wrongPickRisks: [String],
        evidence: [TaskReadinessEvidenceItem],
        safety: TaskReadinessSafety,
        fallbackReason: String? = nil
    ) {
        self.taskText = taskText
        self.score = min(100, max(0, score))
        self.band = band
        self.summary = summary
        self.routes = routes
        self.ambiguityWarnings = ambiguityWarnings
        self.wrongPickRisks = wrongPickRisks
        self.evidence = evidence
        self.safety = safety
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? ""
        let rawScore = try container.decodeFlexibleRoutingDouble(keys: [.overallConfidenceScore, .confidenceScore, .score, .value]) ?? 0
        score = min(100, max(0, Int(rawScore.rounded())))
        band = try container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .overallConfidenceBand)
            ?? container.decodeIfPresent(String.self, forKey: .confidenceBand)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? Self.band(for: score)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? ""
        routes = try container.decodeIfPresent([SkillRouteCandidate].self, forKey: .routes)
            ?? container.decodeIfPresent([SkillRouteCandidate].self, forKey: .routeCandidates)
            ?? container.decodeIfPresent([SkillRouteCandidate].self, forKey: .candidateRoutes)
            ?? container.decodeIfPresent([SkillRouteCandidate].self, forKey: .candidateSkills)
            ?? container.decodeIfPresent([SkillRouteCandidate].self, forKey: .candidates)
            ?? container.decodeIfPresent([SkillRouteCandidate].self, forKey: .skills)
            ?? []
        ambiguityWarnings = try container.decodeFlexibleRoutingStringArray(keys: [.ambiguityWarnings, .ambiguity, .warnings])
        wrongPickRisks = try container.decodeFlexibleRoutingStringArray(keys: [.wrongPickRisks, .likelyWrongPickRisks, .likelyMissRisks, .missExplanations, .risks])
        evidence = try container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceItems)
            ?? []
        if let decodedSafety = try container.decodeIfPresent(TaskReadinessSafety.self, forKey: .safety)
            ?? container.decodeIfPresent(TaskReadinessSafety.self, forKey: .safetyFlags) {
            safety = decodedSafety
        } else {
            safety = TaskReadinessSafety(
                providerRequestSent: try container.decodeIfPresent(Bool.self, forKey: .providerRequestSent) ?? false,
                writeBackAllowed: try container.decodeIfPresent(Bool.self, forKey: .writeBackAllowed) ?? false,
                writeActionsAvailable: try container.decodeIfPresent(Bool.self, forKey: .writeActionsAvailable) ?? false,
                scriptExecutionAllowed: try container.decodeIfPresent(Bool.self, forKey: .scriptExecutionAllowed) ?? false,
                executionActionsAvailable: try container.decodeIfPresent(Bool.self, forKey: .executionActionsAvailable) ?? false,
                configMutationAllowed: try container.decodeIfPresent(Bool.self, forKey: .configMutationAllowed) ?? false,
                snapshotCreated: try container.decodeIfPresent(Bool.self, forKey: .snapshotCreated) ?? false,
                triageMutationAllowed: try container.decodeIfPresent(Bool.self, forKey: .triageMutationAllowed) ?? false,
                credentialAccessed: try container.decodeIfPresent(Bool.self, forKey: .credentialAccessed) ?? false,
                rawSecretReturned: try container.decodeIfPresent(Bool.self, forKey: .rawSecretReturned) ?? false
            )
        }
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(taskText: String, reason: String = UIStrings.routingConfidenceUnavailable) -> SkillRoutingConfidenceResult {
        SkillRoutingConfidenceResult(
            taskText: taskText,
            score: 0,
            band: UIStrings.unknown,
            summary: reason,
            routes: [],
            ambiguityWarnings: [],
            wrongPickRisks: [],
            evidence: [],
            safety: TaskReadinessSafety(),
            fallbackReason: reason
        )
    }

    static func band(for score: Int) -> String {
        switch score {
        case 85...100:
            return "High"
        case 65..<85:
            return "Medium"
        case 40..<65:
            return "Low"
        default:
            return "Blocked"
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleRoutingDouble(keys: [Key]) throws -> Double? {
        for key in keys {
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let double = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return double
            }
        }
        return nil
    }

    func decodeFlexibleRoutingStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: key) {
                return values.map(\.detail)
            }
        }
        return []
    }
}
