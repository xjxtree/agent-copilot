import Foundation

struct SkillQualityComponent: Decodable, Hashable, Identifiable {
    let key: String
    let label: String
    let score: Int
    let maxScore: Int?
    let weight: Double?
    let status: String?
    let summary: String
    let evidence: [String]

    var id: String { key.isEmpty ? label : key }

    enum CodingKeys: String, CodingKey {
        case key
        case id
        case name
        case label
        case title
        case score
        case value
        case maxScore = "max_score"
        case max
        case weight
        case status
        case band
        case summary
        case reason
        case rationale
        case evidence
        case signals
        case evidenceRefs = "evidence_refs"
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            key = value
            label = value
            score = 0
            maxScore = nil
            weight = nil
            status = nil
            summary = value
            evidence = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedKey = try container.decodeIfPresent(String.self, forKey: .key)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? UIStrings.unknown
        key = decodedKey
        label = try container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? decodedKey
        score = Self.clampedScore(
            try container.decodeFlexibleDouble(keys: [.score, .value]) ?? 0
        )
        maxScore = try container.decodeFlexibleInt(keys: [.maxScore, .max])
        weight = try container.decodeFlexibleDouble(keys: [.weight])
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .band)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? ""
        evidence = try container.decodeFlexibleStringArray(keys: [.evidence, .signals, .evidenceRefs])
    }

    private static func clampedScore(_ value: Double) -> Int {
        min(100, max(0, Int(value.rounded())))
    }
}

struct SkillQualityEvidenceItem: Decodable, Hashable, Identifiable {
    let title: String
    let detail: String
    let source: String?

    var id: String { "\(title)-\(detail)-\(source ?? "")" }

    enum CodingKeys: String, CodingKey {
        case title
        case label
        case name
        case detail
        case summary
        case message
        case source
        case sourceID = "source_id"
        case sourceType = "source_type"
        case kind
        case ruleID = "rule_id"
        case severity
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            title = value
            detail = value
            source = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? UIStrings.unknown
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? title
        let decodedSource = try container.decodeIfPresent(String.self, forKey: .source)
        let decodedRuleID = try container.decodeIfPresent(String.self, forKey: .ruleID)
        let decodedSourceID = try container.decodeIfPresent(String.self, forKey: .sourceID)
        let decodedSourceType = try container.decodeIfPresent(String.self, forKey: .sourceType)
        let decodedSeverity = try container.decodeIfPresent(String.self, forKey: .severity)
        source = decodedSource ?? decodedRuleID ?? decodedSourceID ?? decodedSourceType ?? decodedSeverity
    }
}

struct SkillQualitySafety: Decodable, Hashable {
    let providerRequestSent: Bool
    let writeBackAllowed: Bool
    let writeActionsAvailable: Bool
    let scriptExecutionAllowed: Bool
    let executionActionsAvailable: Bool
    let configMutationAllowed: Bool
    let snapshotCreated: Bool
    let triageMutationAllowed: Bool
    let credentialAccessed: Bool
    let rawSecretReturned: Bool

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
        case rawSecretReturned = "raw_secret_returned"
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
        rawSecretReturned: Bool = false
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
        self.rawSecretReturned = rawSecretReturned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerRequestSent = try container.decodeIfPresent(Bool.self, forKey: .providerRequestSent)
            ?? container.decodeIfPresent(Bool.self, forKey: .providerCallSent)
            ?? false
        writeBackAllowed = try container.decodeIfPresent(Bool.self, forKey: .writeBackAllowed) ?? false
        writeActionsAvailable = try container.decodeIfPresent(Bool.self, forKey: .writeActionsAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .writesAllowed)
            ?? false
        scriptExecutionAllowed = try container.decodeIfPresent(Bool.self, forKey: .scriptExecutionAllowed) ?? false
        executionActionsAvailable = try container.decodeIfPresent(Bool.self, forKey: .executionActionsAvailable) ?? false
        configMutationAllowed = try container.decodeIfPresent(Bool.self, forKey: .configMutationAllowed) ?? false
        snapshotCreated = try container.decodeIfPresent(Bool.self, forKey: .snapshotCreated) ?? false
        triageMutationAllowed = try container.decodeIfPresent(Bool.self, forKey: .triageMutationAllowed) ?? false
        credentialAccessed = try container.decodeIfPresent(Bool.self, forKey: .credentialAccessed) ?? false
        rawSecretReturned = try container.decodeIfPresent(Bool.self, forKey: .rawSecretReturned) ?? false
    }
}

struct SkillQualityScoreResult: Decodable, Identifiable, Hashable {
    let skillID: String
    let score: Int
    let band: String
    let grade: String?
    let summary: String
    let components: [SkillQualityComponent]
    let evidence: [SkillQualityEvidenceItem]
    let riskNotes: [String]
    let suggestedImprovements: [String]
    let safety: SkillQualitySafety
    let fallbackReason: String?

    var id: String { skillID.isEmpty ? "quality-score" : skillID }
    var displayBand: String { grade?.isEmpty == false ? grade! : band }

    enum CodingKeys: String, CodingKey {
        case skillID = "skill_id"
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case id
        case score
        case qualityScore = "quality_score"
        case value
        case band
        case grade
        case rating
        case summary
        case rationale
        case components
        case componentScores = "component_scores"
        case evidence
        case evidenceReferences = "evidence_references"
        case evidenceItems = "evidence_items"
        case riskNotes = "risk_notes"
        case risks
        case riskNotesAlt = "riskNotes"
        case suggestedImprovements = "suggested_improvements"
        case suggestions
        case improvements
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
        skillID: String,
        score: Int,
        band: String,
        grade: String? = nil,
        summary: String,
        components: [SkillQualityComponent],
        evidence: [SkillQualityEvidenceItem],
        riskNotes: [String],
        suggestedImprovements: [String],
        safety: SkillQualitySafety,
        fallbackReason: String? = nil
    ) {
        self.skillID = skillID
        self.score = min(100, max(0, score))
        self.band = band
        self.grade = grade
        self.summary = summary
        self.components = components
        self.evidence = evidence
        self.riskNotes = riskNotes
        self.suggestedImprovements = suggestedImprovements
        self.safety = safety
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skillID = try container.decodeIfPresent(String.self, forKey: .skillID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? ""
        let rawScore = try container.decodeFlexibleDouble(keys: [.score, .qualityScore, .value]) ?? 0
        score = min(100, max(0, Int(rawScore.rounded())))
        band = try container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .rating)
            ?? Self.band(for: score)
        grade = try container.decodeIfPresent(String.self, forKey: .grade)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? ""
        components = try container.decodeIfPresent([SkillQualityComponent].self, forKey: .components)
            ?? container.decodeIfPresent([SkillQualityComponent].self, forKey: .componentScores)
            ?? []
        evidence = try container.decodeIfPresent([SkillQualityEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([SkillQualityEvidenceItem].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([SkillQualityEvidenceItem].self, forKey: .evidenceItems)
            ?? []
        riskNotes = try container.decodeFlexibleStringArray(keys: [.riskNotes, .risks, .riskNotesAlt])
        suggestedImprovements = try container.decodeFlexibleStringArray(keys: [.suggestedImprovements, .suggestions, .improvements])
        if let decodedSafety = try container.decodeIfPresent(SkillQualitySafety.self, forKey: .safety)
            ?? container.decodeIfPresent(SkillQualitySafety.self, forKey: .safetyFlags) {
            safety = decodedSafety
        } else {
            safety = SkillQualitySafety(
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

    static func unavailable(skillID: String, reason: String = UIStrings.skillQualityUnavailable) -> SkillQualityScoreResult {
        SkillQualityScoreResult(
            skillID: skillID,
            score: 0,
            band: UIStrings.unknown,
            summary: reason,
            components: [],
            evidence: [],
            riskNotes: [],
            suggestedImprovements: [],
            safety: SkillQualitySafety(),
            fallbackReason: reason
        )
    }

    private static func band(for score: Int) -> String {
        switch score {
        case 90...100:
            return "Excellent"
        case 75..<90:
            return "Good"
        case 60..<75:
            return "Needs work"
        default:
            return "Risky"
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(keys: [Key]) throws -> Double? {
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

    func decodeFlexibleInt(keys: [Key]) throws -> Int? {
        guard let value = try decodeFlexibleDouble(keys: keys) else { return nil }
        return Int(value.rounded())
    }

    func decodeFlexibleStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([SkillQualityEvidenceItem].self, forKey: key) {
                return values.map(\.detail)
            }
        }
        return []
    }
}
