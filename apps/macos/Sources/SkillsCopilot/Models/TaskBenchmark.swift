import Foundation

struct TaskBenchmarkSkillRef: Codable, Hashable, Identifiable {
    let instanceID: String?
    let name: String
    let agent: String
    let definitionID: String?

    var id: String { instanceID ?? "\(agent)-\(name)" }

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case id
        case name
        case skillName = "skill_name"
        case title
        case agent
        case definitionID = "definition_id"
        case definitionId = "definitionId"
    }

    init(instanceID: String?, name: String, agent: String, definitionID: String? = nil) {
        self.instanceID = instanceID
        self.name = name
        self.agent = agent
        self.definitionID = definitionID
    }

    init(skill: SkillRecord) {
        self.init(instanceID: skill.id, name: skill.name, agent: skill.agent, definitionID: skill.definitionId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(instanceID, forKey: .instanceID)
        try container.encode(name, forKey: .name)
        try container.encode(agent, forKey: .agent)
        try container.encodeIfPresent(definitionID, forKey: .definitionID)
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            instanceID = value.isEmpty ? nil : value
            name = value.isEmpty ? UIStrings.unknown : value
            agent = UIStrings.unknown
            definitionID = nil
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
        definitionID = try container.decodeIfPresent(String.self, forKey: .definitionID)
            ?? container.decodeIfPresent(String.self, forKey: .definitionId)
    }
}

struct TaskBenchmarkRecord: Decodable, Hashable, Identifiable {
    let id: String
    let taskText: String
    let expectedSkill: TaskBenchmarkSkillRef?
    let acceptableSkills: [TaskBenchmarkSkillRef]
    let expectedSkillRefs: [String]
    let expectedSkillNames: [String]
    let acceptableAgents: [String]
    let acceptableScopes: [String]
    let successCriteria: [String]
    let createdAt: Int64?
    let updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case benchmarkID = "benchmark_id"
        case benchmarkId = "benchmarkId"
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case expectedSkill = "expected_skill"
        case expectedRoute = "expected_route"
        case expected
        case expectedSkillRefs = "expected_skill_refs"
        case expectedSkillNames = "expected_skill_names"
        case expectedInstanceID = "expected_instance_id"
        case acceptableSkills = "acceptable_skills"
        case acceptableRoutes = "acceptable_routes"
        case acceptable
        case acceptableInstanceIDs = "acceptable_instance_ids"
        case acceptableAgents = "acceptable_agents"
        case acceptableScopes = "acceptable_scopes"
        case successCriteria = "success_criteria"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        taskText: String,
        expectedSkill: TaskBenchmarkSkillRef?,
        acceptableSkills: [TaskBenchmarkSkillRef],
        expectedSkillRefs: [String] = [],
        expectedSkillNames: [String] = [],
        acceptableAgents: [String] = [],
        acceptableScopes: [String] = [],
        successCriteria: [String] = [],
        createdAt: Int64? = nil,
        updatedAt: Int64? = nil
    ) {
        self.id = id
        self.taskText = taskText
        self.expectedSkill = expectedSkill
        self.acceptableSkills = acceptableSkills
        self.expectedSkillRefs = expectedSkillRefs
        self.expectedSkillNames = expectedSkillNames
        self.acceptableAgents = acceptableAgents
        self.acceptableScopes = acceptableScopes
        self.successCriteria = successCriteria
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            taskText = value
            expectedSkill = nil
            acceptableSkills = []
            expectedSkillRefs = []
            expectedSkillNames = []
            acceptableAgents = []
            acceptableScopes = []
            successCriteria = []
            createdAt = nil
            updatedAt = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTask = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? ""
        taskText = decodedTask
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .benchmarkID)
            ?? container.decodeIfPresent(String.self, forKey: .benchmarkId)
            ?? decodedTask
        expectedSkillRefs = try container.decodeFlexibleBenchmarkStringArray(keys: [.expectedSkillRefs, .expectedInstanceID])
        expectedSkillNames = try container.decodeFlexibleBenchmarkStringArray(keys: [.expectedSkillNames])
        acceptableAgents = try container.decodeFlexibleBenchmarkStringArray(keys: [.acceptableAgents])
        acceptableScopes = try container.decodeFlexibleBenchmarkStringArray(keys: [.acceptableScopes])
        successCriteria = try container.decodeFlexibleBenchmarkStringArray(keys: [.successCriteria])
        let decodedExpected = try container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .expectedSkill)
            ?? container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .expectedRoute)
            ?? container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .expected)
        if let decodedExpected {
            expectedSkill = decodedExpected
        } else if let firstExpected = expectedSkillRefs.first ?? expectedSkillNames.first {
            expectedSkill = TaskBenchmarkSkillRef(
                instanceID: expectedSkillRefs.first,
                name: expectedSkillNames.first ?? firstExpected,
                agent: acceptableAgents.first ?? UIStrings.unknown
            )
        } else {
            expectedSkill = nil
        }
        let decodedAcceptable = try container.decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: .acceptableSkills)
            ?? container.decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: .acceptableRoutes)
            ?? container.decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: .acceptable)
            ?? container.decodeFlexibleBenchmarkSkillRefs(keys: [.acceptableInstanceIDs])
        if !decodedAcceptable.isEmpty {
            acceptableSkills = decodedAcceptable
        } else if !acceptableAgents.isEmpty || !acceptableScopes.isEmpty {
            acceptableSkills = acceptableAgents.map { agent in
                TaskBenchmarkSkillRef(instanceID: nil, name: agent, agent: agent)
            } + acceptableScopes.map { scope in
                TaskBenchmarkSkillRef(instanceID: nil, name: scope, agent: UIStrings.unknown)
            }
        } else {
            acceptableSkills = []
        }
        createdAt = try container.decodeFlexibleBenchmarkInt64(keys: [.createdAt])
        updatedAt = try container.decodeFlexibleBenchmarkInt64(keys: [.updatedAt])
    }
}

struct TaskBenchmarkListResult: Decodable, Hashable {
    let benchmarks: [TaskBenchmarkRecord]
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && benchmarks.isEmpty }

    enum CodingKeys: String, CodingKey {
        case benchmarks
        case items
        case tasks
        case taskBenchmarks = "task_benchmarks"
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(benchmarks: [TaskBenchmarkRecord], fallbackReason: String? = nil) {
        self.benchmarks = benchmarks
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let values = try? decoder.singleValueContainer().decode([TaskBenchmarkRecord].self) {
            benchmarks = values
            fallbackReason = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        benchmarks = try container.decodeIfPresent([TaskBenchmarkRecord].self, forKey: .benchmarks)
            ?? container.decodeIfPresent([TaskBenchmarkRecord].self, forKey: .items)
            ?? container.decodeIfPresent([TaskBenchmarkRecord].self, forKey: .tasks)
            ?? container.decodeIfPresent([TaskBenchmarkRecord].self, forKey: .taskBenchmarks)
            ?? []
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.taskBenchmarkUnavailable) -> TaskBenchmarkListResult {
        TaskBenchmarkListResult(benchmarks: [], fallbackReason: reason)
    }
}

struct TaskBenchmarkSaveResult: Decodable, Hashable {
    let benchmark: TaskBenchmarkRecord?
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && benchmark == nil }

    enum CodingKeys: String, CodingKey {
        case benchmark
        case item
        case record
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(benchmark: TaskBenchmarkRecord?, fallbackReason: String? = nil) {
        self.benchmark = benchmark
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nestedBenchmark = try container.decodeIfPresent(TaskBenchmarkRecord.self, forKey: .benchmark)
            ?? container.decodeIfPresent(TaskBenchmarkRecord.self, forKey: .item)
            ?? container.decodeIfPresent(TaskBenchmarkRecord.self, forKey: .record)
        if let nestedBenchmark {
            benchmark = nestedBenchmark
        } else if let directBenchmark = try? TaskBenchmarkRecord(from: decoder),
                  !directBenchmark.id.isEmpty || !directBenchmark.taskText.isEmpty {
            benchmark = directBenchmark
        } else {
            benchmark = nil
        }
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.taskBenchmarkUnavailable) -> TaskBenchmarkSaveResult {
        TaskBenchmarkSaveResult(benchmark: nil, fallbackReason: reason)
    }
}

struct TaskBenchmarkDeleteResult: Decodable, Hashable {
    let deleted: Bool
    let benchmarkID: String?
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !deleted }

    enum CodingKeys: String, CodingKey {
        case deleted
        case success
        case benchmarkID = "benchmark_id"
        case benchmarkId = "benchmarkId"
        case id
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(deleted: Bool, benchmarkID: String? = nil, fallbackReason: String? = nil) {
        self.deleted = deleted
        self.benchmarkID = benchmarkID
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
            ?? container.decodeIfPresent(Bool.self, forKey: .success)
            ?? false
        benchmarkID = try container.decodeIfPresent(String.self, forKey: .benchmarkID)
            ?? container.decodeIfPresent(String.self, forKey: .benchmarkId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.taskBenchmarkDeleteUnavailable) -> TaskBenchmarkDeleteResult {
        TaskBenchmarkDeleteResult(deleted: false, fallbackReason: reason)
    }
}

struct TaskBenchmarkEvaluationItem: Decodable, Hashable, Identifiable {
    let id: String
    let benchmark: TaskBenchmarkRecord?
    let taskText: String
    let matchStatus: String
    let topRoute: SkillRouteCandidate?
    let score: Int
    let band: String
    let expectedCovered: Bool
    let acceptableCovered: Bool
    let blockers: [String]
    let gaps: [String]
    let safetyFlags: [String]
    let evidence: [TaskReadinessEvidenceItem]

    enum CodingKeys: String, CodingKey {
        case id
        case benchmarkID = "benchmark_id"
        case benchmarkId = "benchmarkId"
        case benchmark
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case matchStatus = "match_status"
        case expectedMatchStatus = "expected_match_status"
        case status
        case outcome
        case topRoute = "top_route"
        case topCandidate = "top_candidate"
        case topSkill = "top_skill"
        case selectedRoute = "selected_route"
        case score
        case confidenceScore = "confidence_score"
        case value
        case band
        case confidenceBand = "confidence_band"
        case expectedCovered = "expected_covered"
        case expectedMatched = "expected_matched"
        case expectedMatch = "expected_match"
        case acceptableCovered = "acceptable_covered"
        case acceptableMatched = "acceptable_matched"
        case acceptableMatch = "acceptable_match"
        case blockers
        case blockerNotes = "blocker_notes"
        case gaps
        case gapNotes = "gap_notes"
        case missingCapabilities = "missing_capabilities"
        case safetyFlags = "safety_flags"
        case safety
        case warnings
        case evidence
        case evidenceItems = "evidence_items"
        case evidenceReferences = "evidence_references"
        case evidenceRefs = "evidence_refs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        benchmark = try container.decodeIfPresent(TaskBenchmarkRecord.self, forKey: .benchmark)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? benchmark?.taskText
            ?? ""
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .benchmarkID)
            ?? container.decodeIfPresent(String.self, forKey: .benchmarkId)
            ?? benchmark?.id
            ?? taskText
        matchStatus = try container.decodeIfPresent(String.self, forKey: .matchStatus)
            ?? container.decodeIfPresent(String.self, forKey: .expectedMatchStatus)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .outcome)
            ?? UIStrings.unknown
        topRoute = try container.decodeIfPresent(SkillRouteCandidate.self, forKey: .topRoute)
            ?? container.decodeIfPresent(SkillRouteCandidate.self, forKey: .topCandidate)
            ?? container.decodeIfPresent(SkillRouteCandidate.self, forKey: .topSkill)
            ?? container.decodeIfPresent(SkillRouteCandidate.self, forKey: .selectedRoute)
        let rawScore = try container.decodeFlexibleBenchmarkDouble(keys: [.score, .confidenceScore, .value]) ?? Double(topRoute?.confidenceScore ?? 0)
        score = min(100, max(0, Int(rawScore.rounded())))
        band = try container.decodeIfPresent(String.self, forKey: .band)
            ?? container.decodeIfPresent(String.self, forKey: .confidenceBand)
            ?? topRoute?.band
            ?? SkillRoutingConfidenceResult.band(for: score)
        expectedCovered = try container.decodeIfPresent(Bool.self, forKey: .expectedCovered)
            ?? container.decodeIfPresent(Bool.self, forKey: .expectedMatched)
            ?? container.decodeIfPresent(Bool.self, forKey: .expectedMatch)
            ?? (matchStatus == "expected_match")
        acceptableCovered = try container.decodeIfPresent(Bool.self, forKey: .acceptableCovered)
            ?? container.decodeIfPresent(Bool.self, forKey: .acceptableMatched)
            ?? container.decodeIfPresent(Bool.self, forKey: .acceptableMatch)
            ?? (matchStatus == "expected_match" || matchStatus == "acceptable_match")
        blockers = try container.decodeFlexibleBenchmarkStringArray(keys: [.blockers, .blockerNotes])
        gaps = try container.decodeFlexibleBenchmarkStringArray(keys: [.gaps, .gapNotes, .missingCapabilities])
        safetyFlags = try container.decodeFlexibleBenchmarkStringArray(keys: [.safetyFlags, .safety, .warnings])
        evidence = try container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceItems)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceRefs)
            ?? []
    }
}

struct TaskBenchmarkEvaluationResult: Decodable, Hashable {
    let evaluatedCount: Int
    let matchedCount: Int
    let acceptableCount: Int
    let averageScore: Int
    let evaluations: [TaskBenchmarkEvaluationItem]
    let blockers: [String]
    let gaps: [String]
    let evidence: [TaskReadinessEvidenceItem]
    let safety: TaskReadinessSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && evaluations.isEmpty }

    enum CodingKeys: String, CodingKey {
        case evaluatedCount = "evaluated_count"
        case total
        case count
        case matchedCount = "matched_count"
        case expectedMatchedCount = "expected_matched_count"
        case acceptableCount = "acceptable_count"
        case acceptableMatchedCount = "acceptable_matched_count"
        case averageScore = "average_score"
        case score
        case evaluations
        case benchmarkResults = "benchmark_results"
        case results
        case items
        case blockers
        case blockerNotes = "blocker_notes"
        case gaps
        case gapNotes = "gap_notes"
        case missingCapabilities = "missing_capabilities"
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
        evaluatedCount: Int,
        matchedCount: Int,
        acceptableCount: Int,
        averageScore: Int,
        evaluations: [TaskBenchmarkEvaluationItem],
        blockers: [String],
        gaps: [String],
        evidence: [TaskReadinessEvidenceItem],
        safety: TaskReadinessSafety,
        fallbackReason: String? = nil
    ) {
        self.evaluatedCount = evaluatedCount
        self.matchedCount = matchedCount
        self.acceptableCount = acceptableCount
        self.averageScore = min(100, max(0, averageScore))
        self.evaluations = evaluations
        self.blockers = blockers
        self.gaps = gaps
        self.evidence = evidence
        self.safety = safety
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let values = try? decoder.singleValueContainer().decode([TaskBenchmarkEvaluationItem].self) {
            evaluations = values
            evaluatedCount = values.count
            matchedCount = values.filter(\.expectedCovered).count
            acceptableCount = values.filter(\.acceptableCovered).count
            averageScore = values.isEmpty ? 0 : values.map(\.score).reduce(0, +) / values.count
            blockers = []
            gaps = []
            evidence = []
            safety = TaskReadinessSafety()
            fallbackReason = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        evaluations = try container.decodeIfPresent([TaskBenchmarkEvaluationItem].self, forKey: .evaluations)
            ?? container.decodeIfPresent([TaskBenchmarkEvaluationItem].self, forKey: .benchmarkResults)
            ?? container.decodeIfPresent([TaskBenchmarkEvaluationItem].self, forKey: .results)
            ?? container.decodeIfPresent([TaskBenchmarkEvaluationItem].self, forKey: .items)
            ?? []
        evaluatedCount = try container.decodeFlexibleBenchmarkInt(keys: [.evaluatedCount, .total, .count]) ?? evaluations.count
        matchedCount = try container.decodeFlexibleBenchmarkInt(keys: [.matchedCount, .expectedMatchedCount]) ?? evaluations.filter(\.expectedCovered).count
        acceptableCount = try container.decodeFlexibleBenchmarkInt(keys: [.acceptableCount, .acceptableMatchedCount]) ?? evaluations.filter(\.acceptableCovered).count
        let decodedAverage = try container.decodeFlexibleBenchmarkDouble(keys: [.averageScore, .score])
        averageScore = min(100, max(0, Int((decodedAverage ?? Double(evaluations.isEmpty ? 0 : evaluations.map(\.score).reduce(0, +) / evaluations.count)).rounded())))
        blockers = try container.decodeFlexibleBenchmarkStringArray(keys: [.blockers, .blockerNotes])
        gaps = try container.decodeFlexibleBenchmarkStringArray(keys: [.gaps, .gapNotes, .missingCapabilities])
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

    static func unavailable(reason: String = UIStrings.taskBenchmarkUnavailable) -> TaskBenchmarkEvaluationResult {
        TaskBenchmarkEvaluationResult(
            evaluatedCount: 0,
            matchedCount: 0,
            acceptableCount: 0,
            averageScore: 0,
            evaluations: [],
            blockers: [],
            gaps: [],
            evidence: [],
            safety: TaskReadinessSafety(),
            fallbackReason: reason
        )
    }
}

struct RoutingRegressionBaselineResult: Decodable, Hashable {
    let baselineID: String?
    let benchmarkCount: Int
    let averageScore: Int?
    let matchedCount: Int?
    let acceptableCount: Int?
    let savedAt: Int64?
    let summary: String
    let safety: TaskReadinessSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && baselineID == nil && benchmarkCount == 0 }

    enum CodingKeys: String, CodingKey {
        case baselineID = "baseline_id"
        case baselineId = "baselineId"
        case id
        case benchmarkCount = "benchmark_count"
        case benchmarkTotal = "benchmark_total"
        case count
        case averageScore = "average_score"
        case score
        case matchedCount = "matched_count"
        case acceptableCount = "acceptable_count"
        case savedAt = "saved_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case summary
        case message
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
        baselineID: String?,
        benchmarkCount: Int,
        averageScore: Int?,
        matchedCount: Int?,
        acceptableCount: Int?,
        savedAt: Int64?,
        summary: String,
        safety: TaskReadinessSafety,
        fallbackReason: String? = nil
    ) {
        self.baselineID = baselineID
        self.benchmarkCount = benchmarkCount
        self.averageScore = averageScore.map { min(100, max(0, $0)) }
        self.matchedCount = matchedCount
        self.acceptableCount = acceptableCount
        self.savedAt = savedAt
        self.summary = summary
        self.safety = safety
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baselineID = try container.decodeIfPresent(String.self, forKey: .baselineID)
            ?? container.decodeIfPresent(String.self, forKey: .baselineId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        benchmarkCount = try container.decodeFlexibleBenchmarkInt(keys: [.benchmarkCount, .benchmarkTotal, .count]) ?? 0
        averageScore = try container.decodeFlexibleBenchmarkInt(keys: [.averageScore, .score]).map { min(100, max(0, $0)) }
        matchedCount = try container.decodeFlexibleBenchmarkInt(keys: [.matchedCount])
        acceptableCount = try container.decodeFlexibleBenchmarkInt(keys: [.acceptableCount])
        savedAt = try container.decodeFlexibleBenchmarkInt64(keys: [.savedAt, .createdAt, .updatedAt])
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
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

    static func unavailable(reason: String = UIStrings.routingRegressionUnavailable) -> RoutingRegressionBaselineResult {
        RoutingRegressionBaselineResult(
            baselineID: nil,
            benchmarkCount: 0,
            averageScore: nil,
            matchedCount: nil,
            acceptableCount: nil,
            savedAt: nil,
            summary: "",
            safety: TaskReadinessSafety(),
            fallbackReason: reason
        )
    }
}

struct RoutingRegressionItem: Decodable, Hashable, Identifiable {
    let id: String
    let taskText: String
    let regressionType: String
    let previousMatchStatus: String
    let currentMatchStatus: String
    let previousScore: Int?
    let currentScore: Int?
    let scoreDelta: Int
    let confidenceDelta: Int?
    let previousTopRoute: SkillRouteCandidate?
    let currentTopRoute: SkillRouteCandidate?
    let topRouteChanged: Bool
    let newBlockers: [String]
    let newGaps: [String]
    let safetyFlags: [String]
    let evidence: [TaskReadinessEvidenceItem]

    enum CodingKeys: String, CodingKey {
        case id
        case benchmarkID = "benchmark_id"
        case benchmarkId = "benchmarkId"
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case regressionType = "regression_type"
        case type
        case status
        case previousMatchStatus = "previous_match_status"
        case baselineMatchStatus = "baseline_match_status"
        case oldMatchStatus = "old_match_status"
        case currentMatchStatus = "current_match_status"
        case newMatchStatus = "new_match_status"
        case matchStatusChange = "match_status_change"
        case previousScore = "previous_score"
        case baselineScore = "baseline_score"
        case oldScore = "old_score"
        case currentScore = "current_score"
        case newScore = "new_score"
        case scoreDelta = "score_delta"
        case delta
        case confidenceDelta = "confidence_delta"
        case previousTopRoute = "previous_top_route"
        case baselineTopRoute = "baseline_top_route"
        case oldTopRoute = "old_top_route"
        case currentTopRoute = "current_top_route"
        case newTopRoute = "new_top_route"
        case topRouteChanged = "top_route_changed"
        case routeChanged = "route_changed"
        case changed
        case newBlockers = "new_blockers"
        case blockers
        case blockerNotes = "blocker_notes"
        case newGaps = "new_gaps"
        case gaps
        case gapNotes = "gap_notes"
        case missingCapabilities = "missing_capabilities"
        case safetyFlags = "safety_flags"
        case safety
        case warnings
        case evidence
        case evidenceItems = "evidence_items"
        case evidenceReferences = "evidence_references"
        case evidenceRefs = "evidence_refs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? ""
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .benchmarkID)
            ?? container.decodeIfPresent(String.self, forKey: .benchmarkId)
            ?? taskText
        regressionType = try container.decodeIfPresent(String.self, forKey: .regressionType)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? UIStrings.unknown
        previousMatchStatus = try container.decodeIfPresent(String.self, forKey: .previousMatchStatus)
            ?? container.decodeIfPresent(String.self, forKey: .baselineMatchStatus)
            ?? container.decodeIfPresent(String.self, forKey: .oldMatchStatus)
            ?? ""
        currentMatchStatus = try container.decodeIfPresent(String.self, forKey: .currentMatchStatus)
            ?? container.decodeIfPresent(String.self, forKey: .newMatchStatus)
            ?? container.decodeIfPresent(String.self, forKey: .matchStatusChange)
            ?? ""
        previousScore = try container.decodeFlexibleBenchmarkInt(keys: [.previousScore, .baselineScore, .oldScore])
        currentScore = try container.decodeFlexibleBenchmarkInt(keys: [.currentScore, .newScore])
        let derivedDelta: Int
        if let previousScore, let currentScore {
            derivedDelta = currentScore - previousScore
        } else {
            derivedDelta = 0
        }
        scoreDelta = try container.decodeFlexibleBenchmarkInt(keys: [.scoreDelta, .delta]) ?? derivedDelta
        confidenceDelta = try container.decodeFlexibleBenchmarkInt(keys: [.confidenceDelta])
        previousTopRoute = try container.decodeIfPresent(SkillRouteCandidate.self, forKey: .previousTopRoute)
            ?? container.decodeIfPresent(SkillRouteCandidate.self, forKey: .baselineTopRoute)
            ?? container.decodeIfPresent(SkillRouteCandidate.self, forKey: .oldTopRoute)
        currentTopRoute = try container.decodeIfPresent(SkillRouteCandidate.self, forKey: .currentTopRoute)
            ?? container.decodeIfPresent(SkillRouteCandidate.self, forKey: .newTopRoute)
        topRouteChanged = try container.decodeIfPresent(Bool.self, forKey: .topRouteChanged)
            ?? container.decodeIfPresent(Bool.self, forKey: .routeChanged)
            ?? container.decodeIfPresent(Bool.self, forKey: .changed)
            ?? (previousTopRoute?.id != nil && currentTopRoute?.id != nil && previousTopRoute?.id != currentTopRoute?.id)
        newBlockers = try container.decodeFlexibleBenchmarkStringArray(keys: [.newBlockers, .blockers, .blockerNotes])
        newGaps = try container.decodeFlexibleBenchmarkStringArray(keys: [.newGaps, .gaps, .gapNotes, .missingCapabilities])
        safetyFlags = try container.decodeFlexibleBenchmarkStringArray(keys: [.safetyFlags, .safety, .warnings])
        evidence = try container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceItems)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceRefs)
            ?? []
    }
}

struct RoutingRegressionDetectionResult: Decodable, Hashable {
    let baselineID: String?
    let benchmarkCount: Int
    let regressionCount: Int
    let improvedCount: Int
    let unchangedCount: Int
    let averageScoreDelta: Int
    let matchStatusChangedCount: Int
    let topRouteChangedCount: Int
    let regressions: [RoutingRegressionItem]
    let newBlockers: [String]
    let newGaps: [String]
    let evidence: [TaskReadinessEvidenceItem]
    let safety: TaskReadinessSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && regressions.isEmpty && benchmarkCount == 0 }

    enum CodingKeys: String, CodingKey {
        case baselineID = "baseline_id"
        case baselineId = "baselineId"
        case id
        case benchmarkCount = "benchmark_count"
        case evaluatedCount = "evaluated_count"
        case count
        case regressionCount = "regression_count"
        case regressionsDetected = "regressions_detected"
        case improvedCount = "improved_count"
        case unchangedCount = "unchanged_count"
        case averageScoreDelta = "average_score_delta"
        case scoreDelta = "score_delta"
        case matchStatusChangedCount = "match_status_changed_count"
        case matchChanges = "match_changes"
        case topRouteChangedCount = "top_route_changed_count"
        case routeChanges = "route_changes"
        case regressions
        case regressionItems = "regression_items"
        case items
        case results
        case newBlockers = "new_blockers"
        case blockers
        case blockerNotes = "blocker_notes"
        case newGaps = "new_gaps"
        case gaps
        case gapNotes = "gap_notes"
        case missingCapabilities = "missing_capabilities"
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
        baselineID: String?,
        benchmarkCount: Int,
        regressionCount: Int,
        improvedCount: Int,
        unchangedCount: Int,
        averageScoreDelta: Int,
        matchStatusChangedCount: Int,
        topRouteChangedCount: Int,
        regressions: [RoutingRegressionItem],
        newBlockers: [String],
        newGaps: [String],
        evidence: [TaskReadinessEvidenceItem],
        safety: TaskReadinessSafety,
        fallbackReason: String? = nil
    ) {
        self.baselineID = baselineID
        self.benchmarkCount = benchmarkCount
        self.regressionCount = regressionCount
        self.improvedCount = improvedCount
        self.unchangedCount = unchangedCount
        self.averageScoreDelta = averageScoreDelta
        self.matchStatusChangedCount = matchStatusChangedCount
        self.topRouteChangedCount = topRouteChangedCount
        self.regressions = regressions
        self.newBlockers = newBlockers
        self.newGaps = newGaps
        self.evidence = evidence
        self.safety = safety
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let values = try? decoder.singleValueContainer().decode([RoutingRegressionItem].self) {
            baselineID = nil
            benchmarkCount = values.count
            regressionCount = values.count
            improvedCount = 0
            unchangedCount = 0
            averageScoreDelta = values.isEmpty ? 0 : values.map(\.scoreDelta).reduce(0, +) / values.count
            matchStatusChangedCount = values.filter { !$0.previousMatchStatus.isEmpty && !$0.currentMatchStatus.isEmpty && $0.previousMatchStatus != $0.currentMatchStatus }.count
            topRouteChangedCount = values.filter(\.topRouteChanged).count
            regressions = values
            newBlockers = []
            newGaps = []
            evidence = []
            safety = TaskReadinessSafety()
            fallbackReason = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        baselineID = try container.decodeIfPresent(String.self, forKey: .baselineID)
            ?? container.decodeIfPresent(String.self, forKey: .baselineId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        regressions = try container.decodeIfPresent([RoutingRegressionItem].self, forKey: .regressions)
            ?? container.decodeIfPresent([RoutingRegressionItem].self, forKey: .regressionItems)
            ?? container.decodeIfPresent([RoutingRegressionItem].self, forKey: .items)
            ?? container.decodeIfPresent([RoutingRegressionItem].self, forKey: .results)
            ?? []
        benchmarkCount = try container.decodeFlexibleBenchmarkInt(keys: [.benchmarkCount, .evaluatedCount, .count]) ?? regressions.count
        regressionCount = try container.decodeFlexibleBenchmarkInt(keys: [.regressionCount, .regressionsDetected]) ?? regressions.count
        improvedCount = try container.decodeFlexibleBenchmarkInt(keys: [.improvedCount]) ?? 0
        unchangedCount = try container.decodeFlexibleBenchmarkInt(keys: [.unchangedCount]) ?? max(0, benchmarkCount - regressionCount - improvedCount)
        averageScoreDelta = try container.decodeFlexibleBenchmarkInt(keys: [.averageScoreDelta, .scoreDelta])
            ?? (regressions.isEmpty ? 0 : regressions.map(\.scoreDelta).reduce(0, +) / regressions.count)
        matchStatusChangedCount = try container.decodeFlexibleBenchmarkInt(keys: [.matchStatusChangedCount, .matchChanges])
            ?? regressions.filter { !$0.previousMatchStatus.isEmpty && !$0.currentMatchStatus.isEmpty && $0.previousMatchStatus != $0.currentMatchStatus }.count
        topRouteChangedCount = try container.decodeFlexibleBenchmarkInt(keys: [.topRouteChangedCount, .routeChanges])
            ?? regressions.filter(\.topRouteChanged).count
        newBlockers = try container.decodeFlexibleBenchmarkStringArray(keys: [.newBlockers, .blockers, .blockerNotes])
        newGaps = try container.decodeFlexibleBenchmarkStringArray(keys: [.newGaps, .gaps, .gapNotes, .missingCapabilities])
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

    static func unavailable(reason: String = UIStrings.routingRegressionUnavailable) -> RoutingRegressionDetectionResult {
        RoutingRegressionDetectionResult(
            baselineID: nil,
            benchmarkCount: 0,
            regressionCount: 0,
            improvedCount: 0,
            unchangedCount: 0,
            averageScoreDelta: 0,
            matchStatusChangedCount: 0,
            topRouteChangedCount: 0,
            regressions: [],
            newBlockers: [],
            newGaps: [],
            evidence: [],
            safety: TaskReadinessSafety(),
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBenchmarkDouble(keys: [Key]) throws -> Double? {
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

    func decodeFlexibleBenchmarkInt(keys: [Key]) throws -> Int? {
        guard let value = try decodeFlexibleBenchmarkDouble(keys: keys) else { return nil }
        return Int(value.rounded())
    }

    func decodeFlexibleBenchmarkInt64(keys: [Key]) throws -> Int64? {
        for key in keys {
            if let value = try? decodeIfPresent(Int64.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return Int64(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let int = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return int
            }
        }
        return nil
    }

    func decodeFlexibleBenchmarkStringArray(keys: [Key]) throws -> [String] {
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

    func decodeFlexibleBenchmarkSkillRefs(keys: [Key]) throws -> [TaskBenchmarkSkillRef] {
        for key in keys {
            if let values = try? decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: key) {
                return values
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map { TaskBenchmarkSkillRef(instanceID: $0, name: $0, agent: UIStrings.unknown) }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [TaskBenchmarkSkillRef(instanceID: value, name: value, agent: UIStrings.unknown)]
            }
        }
        return []
    }
}
