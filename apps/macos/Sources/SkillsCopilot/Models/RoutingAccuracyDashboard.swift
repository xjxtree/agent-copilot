import Foundation

struct RoutingAccuracyFilters: Decodable, Hashable {
    let agent: String?
    let windowDays: Int?
    let limit: Int?
    let includeHistory: Bool
    let includeRecentEvidence: Bool

    enum CodingKeys: String, CodingKey {
        case agent
        case windowDays = "window_days"
        case windowDaysAlt = "windowDays"
        case limit
        case includeHistory = "include_history"
        case includeHistoryAlt = "includeHistory"
        case includeRecentEvidence = "include_recent_evidence"
        case includeRecentEvidenceAlt = "includeRecentEvidence"
    }

    init(
        agent: String? = nil,
        windowDays: Int? = nil,
        limit: Int? = nil,
        includeHistory: Bool = true,
        includeRecentEvidence: Bool = true
    ) {
        self.agent = agent
        self.windowDays = windowDays
        self.limit = limit
        self.includeHistory = includeHistory
        self.includeRecentEvidence = includeRecentEvidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        windowDays = try container.decodeFlexibleRoutingAccuracyInt(keys: [.windowDays, .windowDaysAlt])
        limit = try container.decodeFlexibleRoutingAccuracyInt(keys: [.limit])
        includeHistory = try container.decodeIfPresent(Bool.self, forKey: .includeHistory)
            ?? container.decodeIfPresent(Bool.self, forKey: .includeHistoryAlt)
            ?? true
        includeRecentEvidence = try container.decodeIfPresent(Bool.self, forKey: .includeRecentEvidence)
            ?? container.decodeIfPresent(Bool.self, forKey: .includeRecentEvidenceAlt)
            ?? true
    }
}

struct RoutingAccuracyOutcomes: Decodable, Hashable {
    let hit: Int
    let miss: Int
    let wrongPick: Int
    let ambiguous: Int
    let unknown: Int

    var total: Int { hit + miss + wrongPick + ambiguous + unknown }

    enum CodingKeys: String, CodingKey {
        case hit
        case hits
        case miss
        case misses
        case wrongPick = "wrong_pick"
        case wrongPicks = "wrong_picks"
        case ambiguous
        case unknown
    }

    init(hit: Int = 0, miss: Int = 0, wrongPick: Int = 0, ambiguous: Int = 0, unknown: Int = 0) {
        self.hit = hit
        self.miss = miss
        self.wrongPick = wrongPick
        self.ambiguous = ambiguous
        self.unknown = unknown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hit = try container.decodeFlexibleRoutingAccuracyInt(keys: [.hit, .hits]) ?? 0
        miss = try container.decodeFlexibleRoutingAccuracyInt(keys: [.miss, .misses]) ?? 0
        wrongPick = try container.decodeFlexibleRoutingAccuracyInt(keys: [.wrongPick, .wrongPicks]) ?? 0
        ambiguous = try container.decodeFlexibleRoutingAccuracyInt(keys: [.ambiguous]) ?? 0
        unknown = try container.decodeFlexibleRoutingAccuracyInt(keys: [.unknown]) ?? 0
    }
}

struct RoutingAccuracySummary: Decodable, Hashable {
    let hitCount: Int
    let missCount: Int
    let wrongPickCount: Int
    let ambiguousCount: Int
    let unknownCount: Int
    let totalImports: Int
    let totalBenchmarks: Int
    let totalRegressions: Int
    let gapCount: Int
    let blockerCount: Int
    let regressionCount: Int
    let benchmarkMatchedCount: Int
    let benchmarkGapCount: Int
    let missingBenchmarkCount: Int
    let summaryText: String
    let averageConfidence: Double?
    let accuracyRate: Double?
    let knownOutcomeRate: Double?
    let hitRate: Double?
    let missRate: Double?
    let wrongPickRate: Double?
    let ambiguousRate: Double?
    let unknownRate: Double?

    var totalOutcomes: Int {
        let summed = hitCount + missCount + wrongPickCount + ambiguousCount + unknownCount
        return summed > 0 ? summed : totalImports
    }

    enum CodingKeys: String, CodingKey {
        case hitCount = "hit_count"
        case hits
        case hit
        case missCount = "miss_count"
        case misses
        case miss
        case wrongPickCount = "wrong_pick_count"
        case wrongPicks = "wrong_picks"
        case wrongPick = "wrong_pick"
        case ambiguousCount = "ambiguous_count"
        case ambiguous
        case unknownCount = "unknown_count"
        case unknown
        case totalImports = "total_imports"
        case traceCount = "trace_count"
        case importCount = "import_count"
        case imports
        case totalBenchmarks = "total_benchmarks"
        case benchmarkCount = "benchmark_count"
        case benchmarkMatchedCount = "benchmark_matched_count"
        case benchmarkGapCount = "benchmark_gap_count"
        case missingBenchmarkCount = "missing_benchmark_count"
        case benchmarks
        case totalRegressions = "total_regressions"
        case regressionTotal = "regression_total"
        case regressions
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case regressionCount = "regression_count"
        case summary
        case avgConfidence = "avg_confidence"
        case averageConfidence = "average_confidence"
        case averageConfidenceScore = "average_confidence_score"
        case accuracyRate = "accuracy_rate"
        case knownOutcomeRate = "known_outcome_rate"
        case hitRate = "hit_rate"
        case missRate = "miss_rate"
        case wrongPickRate = "wrong_pick_rate"
        case ambiguousRate = "ambiguous_rate"
        case unknownRate = "unknown_rate"
    }

    init(
        hitCount: Int = 0,
        missCount: Int = 0,
        wrongPickCount: Int = 0,
        ambiguousCount: Int = 0,
        unknownCount: Int = 0,
        totalImports: Int = 0,
        totalBenchmarks: Int = 0,
        totalRegressions: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        regressionCount: Int = 0,
        benchmarkMatchedCount: Int = 0,
        benchmarkGapCount: Int = 0,
        missingBenchmarkCount: Int = 0,
        summaryText: String = "",
        averageConfidence: Double? = nil,
        accuracyRate: Double? = nil,
        knownOutcomeRate: Double? = nil,
        hitRate: Double? = nil,
        missRate: Double? = nil,
        wrongPickRate: Double? = nil,
        ambiguousRate: Double? = nil,
        unknownRate: Double? = nil
    ) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.wrongPickCount = wrongPickCount
        self.ambiguousCount = ambiguousCount
        self.unknownCount = unknownCount
        self.totalImports = totalImports
        self.totalBenchmarks = totalBenchmarks
        self.totalRegressions = totalRegressions
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.regressionCount = regressionCount
        self.benchmarkMatchedCount = benchmarkMatchedCount
        self.benchmarkGapCount = benchmarkGapCount
        self.missingBenchmarkCount = missingBenchmarkCount
        self.summaryText = summaryText
        self.averageConfidence = averageConfidence
        self.accuracyRate = accuracyRate
        self.knownOutcomeRate = knownOutcomeRate
        self.hitRate = hitRate
        self.missRate = missRate
        self.wrongPickRate = wrongPickRate
        self.ambiguousRate = ambiguousRate
        self.unknownRate = unknownRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hitCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.hitCount, .hits, .hit]) ?? 0
        missCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.missCount, .misses, .miss]) ?? 0
        wrongPickCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.wrongPickCount, .wrongPicks, .wrongPick]) ?? 0
        ambiguousCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.ambiguousCount, .ambiguous]) ?? 0
        unknownCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.unknownCount, .unknown]) ?? 0
        totalImports = try container.decodeFlexibleRoutingAccuracyInt(keys: [.totalImports, .traceCount, .importCount, .imports]) ?? 0
        totalBenchmarks = try container.decodeFlexibleRoutingAccuracyInt(keys: [.totalBenchmarks, .benchmarkCount, .benchmarks]) ?? 0
        totalRegressions = try container.decodeFlexibleRoutingAccuracyInt(keys: [.totalRegressions, .regressionTotal, .regressions]) ?? 0
        gapCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.gapCount, .gaps]) ?? 0
        blockerCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.blockerCount, .blockers]) ?? 0
        regressionCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.regressionCount]) ?? totalRegressions
        benchmarkMatchedCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.benchmarkMatchedCount]) ?? 0
        benchmarkGapCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.benchmarkGapCount]) ?? gapCount
        missingBenchmarkCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.missingBenchmarkCount]) ?? 0
        summaryText = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        averageConfidence = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.averageConfidence, .avgConfidence, .averageConfidenceScore])
        accuracyRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.accuracyRate])
        knownOutcomeRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.knownOutcomeRate])
        hitRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.hitRate])
        missRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.missRate])
        wrongPickRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.wrongPickRate])
        ambiguousRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.ambiguousRate])
        unknownRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.unknownRate])
    }

    func rateLabel(_ explicitRate: Double?, count: Int) -> String {
        if let explicitRate {
            return Self.percentLabel(explicitRate)
        }
        guard totalOutcomes > 0 else { return Self.percentLabel(0) }
        return Self.percentLabel(Double(count) / Double(totalOutcomes))
    }

    static func countLabel(_ count: Int) -> String {
        count.formatted()
    }

    static func percentLabel(_ value: Double) -> String {
        let normalized = value > 1 ? value / 100 : value
        return normalized.formatted(.percent.precision(.fractionLength(0...1)))
    }

    static func confidenceLabel(_ value: Double?) -> String {
        guard let value else { return UIStrings.unknown }
        if value <= 1 {
            return percentLabel(value)
        }
        return Int(value.rounded()).formatted()
    }
}

struct RoutingAccuracyAgentRow: Decodable, Hashable, Identifiable {
    let agent: String
    let hitCount: Int
    let missCount: Int
    let wrongPickCount: Int
    let ambiguousCount: Int
    let unknownCount: Int
    let totalCount: Int
    let hitRate: Double?
    let wrongPickRate: Double?
    let averageConfidence: Double?
    let gapCount: Int
    let blockerCount: Int
    let regressionCount: Int
    let benchmarkCount: Int
    let benchmarkMatchedCount: Int
    let benchmarkGapCount: Int
    let recentEvidenceCount: Int
    let notes: [String]

    var id: String { agent }

    enum CodingKeys: String, CodingKey {
        case agent
        case name
        case hitCount = "hit_count"
        case hits
        case missCount = "miss_count"
        case misses
        case wrongPickCount = "wrong_pick_count"
        case wrongPicks = "wrong_picks"
        case ambiguousCount = "ambiguous_count"
        case ambiguous
        case unknownCount = "unknown_count"
        case unknown
        case outcomes
        case traceCount = "trace_count"
        case totalCount = "total_count"
        case total
        case count
        case hitRate = "hit_rate"
        case accuracyRate = "accuracy_rate"
        case wrongPickRate = "wrong_pick_rate"
        case averageConfidence = "average_confidence"
        case avgConfidence = "avg_confidence"
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case regressionCount = "regression_count"
        case regressions
        case benchmarkCount = "benchmark_count"
        case benchmarkMatchedCount = "benchmark_matched_count"
        case benchmarkGapCount = "benchmark_gap_count"
        case recentEvidenceCount = "recent_evidence_count"
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        let decodedOutcomes = try container.decodeIfPresent(RoutingAccuracyOutcomes.self, forKey: .outcomes) ?? RoutingAccuracyOutcomes()
        hitCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.hitCount, .hits]) ?? decodedOutcomes.hit
        missCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.missCount, .misses]) ?? decodedOutcomes.miss
        wrongPickCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.wrongPickCount, .wrongPicks]) ?? decodedOutcomes.wrongPick
        ambiguousCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.ambiguousCount, .ambiguous]) ?? decodedOutcomes.ambiguous
        unknownCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.unknownCount, .unknown]) ?? decodedOutcomes.unknown
        let summed = hitCount + missCount + wrongPickCount + ambiguousCount + unknownCount
        totalCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.traceCount, .totalCount, .total, .count]) ?? summed
        hitRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.accuracyRate, .hitRate])
        wrongPickRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.wrongPickRate])
        averageConfidence = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.averageConfidence, .avgConfidence])
        gapCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.gapCount, .gaps]) ?? 0
        blockerCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.blockerCount, .blockers]) ?? 0
        regressionCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.regressionCount, .regressions]) ?? 0
        benchmarkCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.benchmarkCount]) ?? 0
        benchmarkMatchedCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.benchmarkMatchedCount]) ?? 0
        benchmarkGapCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.benchmarkGapCount]) ?? gapCount
        recentEvidenceCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.recentEvidenceCount]) ?? 0
        notes = try container.decodeFlexibleRoutingAccuracyStringArray(keys: [.notes])
    }

    func hitRateLabel() -> String {
        if let hitRate {
            return RoutingAccuracySummary.percentLabel(hitRate)
        }
        guard totalCount > 0 else { return RoutingAccuracySummary.percentLabel(0) }
        return RoutingAccuracySummary.percentLabel(Double(hitCount) / Double(totalCount))
    }

    func wrongPickRateLabel() -> String {
        if let wrongPickRate {
            return RoutingAccuracySummary.percentLabel(wrongPickRate)
        }
        guard totalCount > 0 else { return RoutingAccuracySummary.percentLabel(0) }
        return RoutingAccuracySummary.percentLabel(Double(wrongPickCount) / Double(totalCount))
    }
}

struct RoutingAccuracyHistoryPoint: Decodable, Hashable, Identifiable {
    let id: String
    let label: String
    let totalCount: Int
    let hitRate: Double?
    let wrongPickRate: Double?
    let regressionCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case bucket
        case date
        case unixDay = "unix_day"
        case windowStart = "window_start"
        case traceCount = "trace_count"
        case outcomes
        case totalCount = "total_count"
        case total
        case count
        case hitRate = "hit_rate"
        case accuracyRate = "accuracy_rate"
        case wrongPickRate = "wrong_pick_rate"
        case regressionCount = "regression_count"
        case regressions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let unixDayLabel = try container.decodeFlexibleRoutingAccuracyInt(keys: [.unixDay]).map { String($0) }
        let decodedLabel = try container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .bucket)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? container.decodeIfPresent(String.self, forKey: .windowStart)
            ?? unixDayLabel
            ?? UIStrings.unknown
        label = decodedLabel
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? decodedLabel
        let decodedOutcomes = try container.decodeIfPresent(RoutingAccuracyOutcomes.self, forKey: .outcomes) ?? RoutingAccuracyOutcomes()
        totalCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.traceCount, .totalCount, .total, .count]) ?? decodedOutcomes.total
        hitRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.accuracyRate, .hitRate])
        wrongPickRate = try container.decodeFlexibleRoutingAccuracyDouble(keys: [.wrongPickRate])
        regressionCount = try container.decodeFlexibleRoutingAccuracyInt(keys: [.regressionCount, .regressions]) ?? 0
    }
}

struct RoutingAccuracyGap: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let severity: String?
    let source: String?
    let agent: String?
    let evidenceRefs: [String]
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case label
        case name
        case detail
        case summary
        case message
        case severity
        case source
        case agent
        case evidenceRefs = "evidence_refs"
        case evidence
        case count
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            detail = value
            severity = nil
            source = nil
            agent = nil
            evidenceRefs = []
            count = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        title = decodedTitle
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? decodedTitle
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(decodedTitle)-\(detail)"
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        evidenceRefs = try container.decodeFlexibleRoutingAccuracyStringArray(keys: [.evidenceRefs, .evidence])
        count = try container.decodeFlexibleRoutingAccuracyInt(keys: [.count])
    }
}

struct RoutingAccuracyEvidenceRow: Decodable, Hashable, Identifiable {
    let id: String
    let source: String?
    let agent: String?
    let title: String
    let outcome: String?
    let detail: String
    let evidenceRefs: [String]
    let observedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case agent
        case title
        case label
        case name
        case outcome
        case detail
        case summary
        case message
        case evidenceRefs = "evidence_refs"
        case evidence
        case observedAt = "observed_at"
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            source = nil
            agent = nil
            title = value
            outcome = nil
            detail = value
            evidenceRefs = []
            observedAt = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? title
        evidenceRefs = try container.decodeFlexibleRoutingAccuracyStringArray(keys: [.evidenceRefs, .evidence])
        observedAt = try container.decodeFlexibleRoutingAccuracyInt64(keys: [.observedAt])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(source ?? "")-\(agent ?? "")-\(title)-\(detail)-\(observedAt ?? 0)"
    }
}

struct RoutingAccuracyPromptRequest: Decodable, Hashable {
    let enabled: Bool
    let requestKind: String
    let previewID: String?
    let summary: String
    let copyOnly: Bool

    enum CodingKeys: String, CodingKey {
        case enabled
        case requestKind = "request_kind"
        case kind
        case previewID = "preview_id"
        case previewId = "previewId"
        case id
        case summary
        case message
        case copyOnly = "copy_only"
        case draftCopyOnly = "draft_copy_only"
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            enabled = false
            requestKind = value
            previewID = nil
            summary = value
            copyOnly = true
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        requestKind = try container.decodeIfPresent(String.self, forKey: .requestKind)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? "routing_accuracy"
        previewID = try container.decodeIfPresent(String.self, forKey: .previewID)
            ?? container.decodeIfPresent(String.self, forKey: .previewId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
        copyOnly = try container.decodeIfPresent(Bool.self, forKey: .copyOnly)
            ?? container.decodeIfPresent(Bool.self, forKey: .draftCopyOnly)
            ?? true
    }
}

struct RoutingAccuracySafety: Decodable, Hashable {
    let providerRequestSent: Bool
    let writeBackAllowed: Bool
    let scriptExecutionAllowed: Bool
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
            && !scriptExecutionAllowed
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
        case writesAllowed = "writes_allowed"
        case scriptExecutionAllowed = "script_execution_allowed"
        case configMutationAllowed = "config_mutation_allowed"
        case snapshotCreated = "snapshot_created"
        case triageMutationAllowed = "triage_mutation_allowed"
        case credentialAccessed = "credential_accessed"
        case rawPromptPersisted = "raw_prompt_persisted"
        case rawResponsePersisted = "raw_response_persisted"
        case rawTracePersisted = "raw_trace_persisted"
        case rawTraceStored = "raw_trace_stored"
        case cloudSyncEnabled = "cloud_sync_enabled"
        case cloudSync = "cloud_sync"
        case telemetryEnabled = "telemetry_enabled"
        case telemetry
        case rawSecretReturned = "raw_secret_returned"
        case notes
        case flags
    }

    init(
        providerRequestSent: Bool = false,
        writeBackAllowed: Bool = false,
        scriptExecutionAllowed: Bool = false,
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
        self.scriptExecutionAllowed = scriptExecutionAllowed
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
        let providerRequestSent = try container.decodeIfPresent(Bool.self, forKey: .providerRequestSent)
            ?? container.decodeIfPresent(Bool.self, forKey: .providerCallSent)
            ?? false
        let writeBackAllowed = try container.decodeIfPresent(Bool.self, forKey: .writeBackAllowed)
            ?? container.decodeIfPresent(Bool.self, forKey: .writesAllowed)
            ?? false
        let scriptExecutionAllowed = try container.decodeIfPresent(Bool.self, forKey: .scriptExecutionAllowed) ?? false
        let configMutationAllowed = try container.decodeIfPresent(Bool.self, forKey: .configMutationAllowed) ?? false
        let snapshotCreated = try container.decodeIfPresent(Bool.self, forKey: .snapshotCreated) ?? false
        let triageMutationAllowed = try container.decodeIfPresent(Bool.self, forKey: .triageMutationAllowed) ?? false
        let credentialAccessed = try container.decodeIfPresent(Bool.self, forKey: .credentialAccessed) ?? false
        let rawPromptPersisted = try container.decodeIfPresent(Bool.self, forKey: .rawPromptPersisted) ?? false
        let rawResponsePersisted = try container.decodeIfPresent(Bool.self, forKey: .rawResponsePersisted) ?? false
        let rawTracePersisted = try container.decodeIfPresent(Bool.self, forKey: .rawTracePersisted)
            ?? container.decodeIfPresent(Bool.self, forKey: .rawTraceStored)
            ?? false
        let cloudSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .cloudSync)
            ?? false
        let telemetryEnabled = try container.decodeIfPresent(Bool.self, forKey: .telemetryEnabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .telemetry)
            ?? false
        let rawSecretReturned = try container.decodeIfPresent(Bool.self, forKey: .rawSecretReturned) ?? false
        let notes = try container.decodeFlexibleRoutingAccuracyStringArray(keys: [.notes, .flags])
        self.init(
            providerRequestSent: providerRequestSent,
            writeBackAllowed: writeBackAllowed,
            scriptExecutionAllowed: scriptExecutionAllowed,
            configMutationAllowed: configMutationAllowed,
            snapshotCreated: snapshotCreated,
            triageMutationAllowed: triageMutationAllowed,
            credentialAccessed: credentialAccessed,
            rawPromptPersisted: rawPromptPersisted,
            rawResponsePersisted: rawResponsePersisted,
            rawTracePersisted: rawTracePersisted,
            cloudSyncEnabled: cloudSyncEnabled,
            telemetryEnabled: telemetryEnabled,
            rawSecretReturned: rawSecretReturned,
            notes: notes
        )
    }
}

struct RoutingAccuracyDashboard: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: RoutingAccuracyFilters
    let summary: RoutingAccuracySummary
    let agents: [RoutingAccuracyAgentRow]
    let history: [RoutingAccuracyHistoryPoint]
    let gaps: [RoutingAccuracyGap]
    let recentEvidence: [RoutingAccuracyEvidenceRow]
    let blockerNotes: [String]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: RoutingAccuracySafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case agents
        case agentRows = "agent_rows"
        case history
        case historyRows = "history_rows"
        case trend
        case gaps
        case gapItems = "gap_items"
        case gapIssueRows = "gap_issue_rows"
        case blockerNotes = "blocker_notes"
        case recentEvidence = "recent_evidence"
        case recentEvidenceRows = "recent_evidence_rows"
        case recentEvidenceAlt = "recentEvidence"
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
        filters: RoutingAccuracyFilters = RoutingAccuracyFilters(),
        summary: RoutingAccuracySummary = RoutingAccuracySummary(),
        agents: [RoutingAccuracyAgentRow] = [],
        history: [RoutingAccuracyHistoryPoint] = [],
        gaps: [RoutingAccuracyGap] = [],
        recentEvidence: [RoutingAccuracyEvidenceRow] = [],
        blockerNotes: [String] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: RoutingAccuracySafety = RoutingAccuracySafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.agents = agents
        self.history = history
        self.gaps = gaps
        self.recentEvidence = recentEvidence
        self.blockerNotes = blockerNotes
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
        filters = try container.decodeIfPresent(RoutingAccuracyFilters.self, forKey: .filters) ?? RoutingAccuracyFilters()
        summary = try container.decodeIfPresent(RoutingAccuracySummary.self, forKey: .summary) ?? RoutingAccuracySummary()
        agents = try container.decodeIfPresent([RoutingAccuracyAgentRow].self, forKey: .agents)
            ?? container.decodeIfPresent([RoutingAccuracyAgentRow].self, forKey: .agentRows)
            ?? []
        history = try container.decodeIfPresent([RoutingAccuracyHistoryPoint].self, forKey: .history)
            ?? container.decodeIfPresent([RoutingAccuracyHistoryPoint].self, forKey: .historyRows)
            ?? container.decodeIfPresent([RoutingAccuracyHistoryPoint].self, forKey: .trend)
            ?? []
        gaps = try container.decodeIfPresent([RoutingAccuracyGap].self, forKey: .gaps)
            ?? container.decodeIfPresent([RoutingAccuracyGap].self, forKey: .gapItems)
            ?? container.decodeIfPresent([RoutingAccuracyGap].self, forKey: .gapIssueRows)
            ?? []
        blockerNotes = try container.decodeFlexibleRoutingAccuracyStringArray(keys: [.blockerNotes])
        recentEvidence = try container.decodeIfPresent([RoutingAccuracyEvidenceRow].self, forKey: .recentEvidenceRows)
            ?? container.decodeIfPresent([RoutingAccuracyEvidenceRow].self, forKey: .recentEvidence)
            ?? container.decodeIfPresent([RoutingAccuracyEvidenceRow].self, forKey: .recentEvidenceAlt)
            ?? container.decodeIfPresent([RoutingAccuracyEvidenceRow].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        if let decodedSafety = try container.decodeIfPresent(RoutingAccuracySafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(RoutingAccuracySafety.self, forKey: .safety) {
            safetyFlags = decodedSafety
        } else {
            safetyFlags = RoutingAccuracySafety(
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

    static func unavailable(reason: String = UIStrings.routingAccuracyUnavailable) -> RoutingAccuracyDashboard {
        RoutingAccuracyDashboard(
            generatedBy: "unavailable",
            catalogAvailable: false,
            safetyFlags: RoutingAccuracySafety(),
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleRoutingAccuracyInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([RoutingAccuracyGap].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleRoutingAccuracyDouble(keys: [Key]) throws -> Double? {
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

    func decodeFlexibleRoutingAccuracyInt64(keys: [Key]) throws -> Int64? {
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

    func decodeFlexibleRoutingAccuracyStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
        }
        return []
    }
}
