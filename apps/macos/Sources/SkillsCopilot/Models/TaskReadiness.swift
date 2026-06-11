import Foundation

struct TaskReadinessCandidateSkill: Decodable, Hashable, Identifiable {
    let instanceID: String?
    let name: String
    let agent: String
    let readiness: String?
    let score: Int?
    let rationale: String
    let evidence: [String]

    var id: String { instanceID ?? "\(agent)-\(name)" }

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case id
        case name
        case title
        case agent
        case readiness
        case band
        case status
        case score
        case value
        case rationale
        case reason
        case summary
        case evidence
        case signals
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            instanceID = nil
            name = value
            agent = UIStrings.unknown
            readiness = nil
            score = nil
            rationale = ""
            evidence = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? instanceID
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent) ?? UIStrings.unknown
        readiness = try container.decodeIfPresent(String.self, forKey: .readiness)
            ?? container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .status)
        score = try container.decodeFlexibleInt(keys: [.score, .value])
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        evidence = try container.decodeFlexibleStringArray(keys: [.evidence, .signals])
    }
}

struct TaskReadinessEvidenceItem: Decodable, Hashable, Identifiable {
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
            ?? title
        let decodedSource = try container.decodeIfPresent(String.self, forKey: .source)
        let decodedSourceID = try container.decodeIfPresent(String.self, forKey: .sourceID)
        let decodedSourceType = try container.decodeIfPresent(String.self, forKey: .sourceType)
        let decodedRuleID = try container.decodeIfPresent(String.self, forKey: .ruleID)
        let decodedSeverity = try container.decodeIfPresent(String.self, forKey: .severity)
        source = decodedSource ?? decodedSourceID ?? decodedSourceType ?? decodedRuleID ?? decodedSeverity
    }
}

struct TaskReadinessSafety: Decodable, Hashable {
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

struct TaskReadinessResult: Decodable, Identifiable, Hashable {
    let taskText: String
    let score: Int
    let band: String
    let summary: String
    let candidateSkills: [TaskReadinessCandidateSkill]
    let gaps: [String]
    let blockers: [String]
    let riskNotes: [String]
    let evidence: [TaskReadinessEvidenceItem]
    let safety: TaskReadinessSafety
    let fallbackReason: String?

    var id: String { taskText.isEmpty ? "task-readiness" : taskText }

    enum CodingKeys: String, CodingKey {
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case score
        case readinessScore = "readiness_score"
        case value
        case band
        case readinessBand = "readiness_band"
        case grade
        case status
        case summary
        case rationale
        case candidateSkills = "candidate_skills"
        case candidates
        case skills
        case gaps
        case missingCapabilities = "missing_capabilities"
        case missing
        case blockers
        case riskNotes = "risk_notes"
        case risks
        case riskNotesAlt = "riskNotes"
        case evidence
        case evidenceItems = "evidence_items"
        case evidenceReferences = "evidence_references"
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
        candidateSkills: [TaskReadinessCandidateSkill],
        gaps: [String],
        blockers: [String],
        riskNotes: [String],
        evidence: [TaskReadinessEvidenceItem],
        safety: TaskReadinessSafety,
        fallbackReason: String? = nil
    ) {
        self.taskText = taskText
        self.score = min(100, max(0, score))
        self.band = band
        self.summary = summary
        self.candidateSkills = candidateSkills
        self.gaps = gaps
        self.blockers = blockers
        self.riskNotes = riskNotes
        self.evidence = evidence
        self.safety = safety
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? ""
        let rawScore = try container.decodeFlexibleDouble(keys: [.score, .readinessScore, .value]) ?? 0
        score = min(100, max(0, Int(rawScore.rounded())))
        band = try container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .readinessBand)
            ?? container.decodeIfPresent(String.self, forKey: .grade)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? Self.band(for: score)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? ""
        candidateSkills = try container.decodeIfPresent([TaskReadinessCandidateSkill].self, forKey: .candidateSkills)
            ?? container.decodeIfPresent([TaskReadinessCandidateSkill].self, forKey: .candidates)
            ?? container.decodeIfPresent([TaskReadinessCandidateSkill].self, forKey: .skills)
            ?? []
        gaps = try container.decodeFlexibleStringArray(keys: [.gaps, .missingCapabilities, .missing])
        blockers = try container.decodeFlexibleStringArray(keys: [.blockers])
        riskNotes = try container.decodeFlexibleStringArray(keys: [.riskNotes, .risks, .riskNotesAlt])
        evidence = try container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceItems)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceReferences)
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

    static func unavailable(taskText: String, reason: String = UIStrings.taskReadinessUnavailable) -> TaskReadinessResult {
        TaskReadinessResult(
            taskText: taskText,
            score: 0,
            band: UIStrings.unknown,
            summary: reason,
            candidateSkills: [],
            gaps: [],
            blockers: [],
            riskNotes: [],
            evidence: [],
            safety: TaskReadinessSafety(),
            fallbackReason: reason
        )
    }

    private static func band(for score: Int) -> String {
        switch score {
        case 85...100:
            return "Ready"
        case 65..<85:
            return "Partial"
        case 40..<65:
            return "Gaps"
        default:
            return "Blocked"
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
            if let values = try? decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: key) {
                return values.map(\.detail)
            }
        }
        return []
    }
}
