import Foundation

struct AgentTraceRedactionSummary: Decodable, Hashable {
    let status: String
    let summary: String
    let redactedFields: [String]
    let placeholders: [String]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case status
        case summary
        case message
        case redactedFields = "redacted_fields"
        case fields
        case placeholders
        case warnings
    }

    init(
        status: String = UIStrings.unknown,
        summary: String = "",
        redactedFields: [String] = [],
        placeholders: [String] = [],
        warnings: [String] = []
    ) {
        self.status = status
        self.summary = summary
        self.redactedFields = redactedFields
        self.placeholders = placeholders
        self.warnings = warnings
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            status = value
            summary = value
            redactedFields = []
            placeholders = []
            warnings = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? UIStrings.unknown
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
        redactedFields = try container.decodeFlexibleTraceStringArray(keys: [.redactedFields, .fields])
        placeholders = try container.decodeFlexibleTraceStringArray(keys: [.placeholders])
        warnings = try container.decodeFlexibleTraceStringArray(keys: [.warnings])
    }
}

struct AgentTraceImportRecord: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let taskText: String
    let outcome: String
    let detectedSkills: [TaskBenchmarkSkillRef]
    let expectedSkills: [TaskBenchmarkSkillRef]
    let redactedExcerpt: String
    let redaction: AgentTraceRedactionSummary
    let reasons: [String]
    let evidence: [TaskReadinessEvidenceItem]
    let safetyFlags: [String]
    let safety: TaskReadinessSafety
    let createdAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case importID = "import_id"
        case importId = "importId"
        case traceID = "trace_id"
        case traceId = "traceId"
        case title
        case name
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case outcome
        case status
        case matchStatus = "match_status"
        case detectedSkills = "detected_skills"
        case detectedSkillNames = "detected_skill_names"
        case detectedRoutes = "detected_routes"
        case actualSkills = "actual_skills"
        case expectedSkills = "expected_skills"
        case expectedSkillNames = "expected_skill_names"
        case expectedRoutes = "expected_routes"
        case redactedExcerpt = "redacted_excerpt"
        case excerpt
        case redactedPreview = "redacted_preview"
        case preview
        case redaction
        case redactionSummary = "redaction_summary"
        case reasons
        case reason
        case matchReasons = "match_reasons"
        case evidence
        case evidenceItems = "evidence_items"
        case evidenceReferences = "evidence_references"
        case evidenceRefs = "evidence_refs"
        case analysis
        case safetyFlags = "safety_flags"
        case safetyFlagList = "safety_flag_list"
        case warnings
        case safety
        case createdAt = "created_at"
        case importedAt = "imported_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        title: String,
        taskText: String,
        outcome: String,
        detectedSkills: [TaskBenchmarkSkillRef],
        expectedSkills: [TaskBenchmarkSkillRef],
        redactedExcerpt: String,
        redaction: AgentTraceRedactionSummary,
        reasons: [String],
        evidence: [TaskReadinessEvidenceItem],
        safetyFlags: [String],
        safety: TaskReadinessSafety,
        createdAt: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.taskText = taskText
        self.outcome = outcome
        self.detectedSkills = detectedSkills
        self.expectedSkills = expectedSkills
        self.redactedExcerpt = redactedExcerpt
        self.redaction = redaction
        self.reasons = reasons
        self.evidence = evidence
        self.safetyFlags = safetyFlags
        self.safety = safety
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? ""
        let decodedTask = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? ""
        var decodedID = try container.decodeIfPresent(String.self, forKey: .id)
        if decodedID == nil {
            decodedID = try container.decodeIfPresent(String.self, forKey: .importID)
        }
        if decodedID == nil {
            decodedID = try container.decodeIfPresent(String.self, forKey: .importId)
        }
        if decodedID == nil {
            decodedID = try container.decodeIfPresent(String.self, forKey: .traceID)
        }
        if decodedID == nil {
            decodedID = try container.decodeIfPresent(String.self, forKey: .traceId)
        }
        let analysis = try container.decodeIfPresent(AgentTraceAnalysisPayload.self, forKey: .analysis)
        id = decodedID
            ?? (!decodedTitle.isEmpty ? decodedTitle : nil)
            ?? (!decodedTask.isEmpty ? decodedTask : nil)
            ?? UIStrings.unknown
        title = decodedTitle
        taskText = decodedTask
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .matchStatus)
            ?? analysis?.outcome
            ?? UIStrings.unknown
        detectedSkills = try container.decodeFlexibleTraceSkillRefs(keys: [
            .detectedSkills,
            .detectedSkillNames,
            .detectedRoutes,
            .actualSkills
        ]).nonEmptyOr(analysis?.detectedSkills ?? [])
        expectedSkills = try container.decodeFlexibleTraceSkillRefs(keys: [
            .expectedSkills,
            .expectedSkillNames,
            .expectedRoutes
        ])
        redactedExcerpt = try container.decodeIfPresent(String.self, forKey: .redactedExcerpt)
            ?? container.decodeIfPresent(String.self, forKey: .excerpt)
            ?? container.decodeIfPresent(String.self, forKey: .redactedPreview)
            ?? container.decodeIfPresent(String.self, forKey: .preview)
            ?? ""
        redaction = try container.decodeIfPresent(AgentTraceRedactionSummary.self, forKey: .redaction)
            ?? container.decodeIfPresent(AgentTraceRedactionSummary.self, forKey: .redactionSummary)
            ?? AgentTraceRedactionSummary()
        reasons = try container.decodeFlexibleTraceStringArray(keys: [.reasons, .reason, .matchReasons])
            .nonEmptyOr(analysis?.reasons ?? [])
        evidence = try container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceItems)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceRefs)
            ?? analysis?.evidence
            ?? []
        safetyFlags = try container.decodeFlexibleTraceStringArray(keys: [.safetyFlags, .safetyFlagList, .warnings])
        safety = try container.decodeIfPresent(TaskReadinessSafety.self, forKey: .safety)
            ?? container.decodeIfPresent(TaskReadinessSafety.self, forKey: .safetyFlags)
            ?? TaskReadinessSafety()
        createdAt = try container.decodeFlexibleTraceInt64(keys: [.createdAt, .importedAt, .updatedAt])
    }
}

private struct AgentTraceAnalysisPayload: Decodable, Hashable {
    let outcome: String
    let reasons: [String]
    let detectedSkills: [TaskBenchmarkSkillRef]
    let evidence: [TaskReadinessEvidenceItem]

    enum CodingKeys: String, CodingKey {
        case outcome
        case status
        case matchStatus = "match_status"
        case reasons
        case reason
        case matchReasons = "match_reasons"
        case detectedSkills = "detected_skills"
        case detectedSkillNames = "detected_skill_names"
        case actualSkills = "actual_skills"
        case evidence
        case evidenceItems = "evidence_items"
        case evidenceReferences = "evidence_references"
        case evidenceRefs = "evidence_refs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .matchStatus)
            ?? UIStrings.unknown
        reasons = try container.decodeFlexibleTraceStringArray(keys: [.reasons, .reason, .matchReasons])
        detectedSkills = try container.decodeFlexibleTraceSkillRefs(keys: [
            .detectedSkills,
            .detectedSkillNames,
            .actualSkills
        ])
        evidence = try container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidence)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceItems)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([TaskReadinessEvidenceItem].self, forKey: .evidenceRefs)
            ?? []
    }
}

struct AgentTraceImportResult: Decodable, Hashable {
    let record: AgentTraceImportRecord?
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && record == nil }

    enum CodingKeys: String, CodingKey {
        case record
        case trace
        case imported
        case item
        case importRecord = "import"
        case id
        case importID = "import_id"
        case traceID = "trace_id"
        case outcome
        case status
        case detectedSkills = "detected_skills"
        case detectedSkillNames = "detected_skill_names"
        case redactedExcerpt = "redacted_excerpt"
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(record: AgentTraceImportRecord?, fallbackReason: String? = nil) {
        self.record = record
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        var nestedRecord = try container?.decodeIfPresent(AgentTraceImportRecord.self, forKey: .record)
        if nestedRecord == nil {
            nestedRecord = try container?.decodeIfPresent(AgentTraceImportRecord.self, forKey: .trace)
        }
        if nestedRecord == nil {
            nestedRecord = try container?.decodeIfPresent(AgentTraceImportRecord.self, forKey: .imported)
        }
        if nestedRecord == nil {
            nestedRecord = try container?.decodeIfPresent(AgentTraceImportRecord.self, forKey: .item)
        }
        if nestedRecord == nil {
            nestedRecord = try container?.decodeIfPresent(AgentTraceImportRecord.self, forKey: .importRecord)
        }
        if let nestedRecord {
            record = nestedRecord
        } else if let container,
                  container.contains(.id)
                    || container.contains(.importID)
                    || container.contains(.traceID)
                    || container.contains(.outcome)
                    || container.contains(.status)
                    || container.contains(.detectedSkills)
                    || container.contains(.detectedSkillNames)
                    || container.contains(.redactedExcerpt) {
            record = try? AgentTraceImportRecord(from: decoder)
        } else {
            record = nil
        }
        fallbackReason = try container?.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container?.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.traceImportUnavailable) -> AgentTraceImportResult {
        AgentTraceImportResult(record: nil, fallbackReason: reason)
    }
}

struct AgentTraceImportListResult: Decodable, Hashable {
    let imports: [AgentTraceImportRecord]
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && imports.isEmpty }

    enum CodingKeys: String, CodingKey {
        case imports
        case records
        case items
        case traces
        case traceImports = "trace_imports"
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(imports: [AgentTraceImportRecord], fallbackReason: String? = nil) {
        self.imports = imports
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let values = try? decoder.singleValueContainer().decode([AgentTraceImportRecord].self) {
            imports = values
            fallbackReason = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        imports = try container.decodeIfPresent([AgentTraceImportRecord].self, forKey: .imports)
            ?? container.decodeIfPresent([AgentTraceImportRecord].self, forKey: .records)
            ?? container.decodeIfPresent([AgentTraceImportRecord].self, forKey: .items)
            ?? container.decodeIfPresent([AgentTraceImportRecord].self, forKey: .traces)
            ?? container.decodeIfPresent([AgentTraceImportRecord].self, forKey: .traceImports)
            ?? []
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.traceImportUnavailable) -> AgentTraceImportListResult {
        AgentTraceImportListResult(imports: [], fallbackReason: reason)
    }
}

struct AgentTraceImportDeleteResult: Decodable, Hashable {
    let deleted: Bool
    let importID: String?
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !deleted }

    enum CodingKeys: String, CodingKey {
        case deleted
        case success
        case importID = "import_id"
        case importId = "importId"
        case traceID = "trace_id"
        case traceId = "traceId"
        case id
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(deleted: Bool, importID: String? = nil, fallbackReason: String? = nil) {
        self.deleted = deleted
        self.importID = importID
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
            ?? container.decodeIfPresent(Bool.self, forKey: .success)
            ?? false
        var decodedImportID = try container.decodeIfPresent(String.self, forKey: .importID)
        if decodedImportID == nil {
            decodedImportID = try container.decodeIfPresent(String.self, forKey: .importId)
        }
        if decodedImportID == nil {
            decodedImportID = try container.decodeIfPresent(String.self, forKey: .traceID)
        }
        if decodedImportID == nil {
            decodedImportID = try container.decodeIfPresent(String.self, forKey: .traceId)
        }
        if decodedImportID == nil {
            decodedImportID = try container.decodeIfPresent(String.self, forKey: .id)
        }
        importID = decodedImportID
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.traceImportDeleteUnavailable) -> AgentTraceImportDeleteResult {
        AgentTraceImportDeleteResult(deleted: false, fallbackReason: reason)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleTraceStringArray(keys: [Key]) throws -> [String] {
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
            if let values = try? decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: key) {
                return values.map(\.name)
            }
        }
        return []
    }

    func decodeFlexibleTraceSkillRefs(keys: [Key]) throws -> [TaskBenchmarkSkillRef] {
        for key in keys {
            if let values = try? decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: key) {
                return values
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map {
                    TaskBenchmarkSkillRef(instanceID: nil, name: $0, agent: UIStrings.unknown)
                }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [TaskBenchmarkSkillRef(instanceID: nil, name: value, agent: UIStrings.unknown)]
            }
        }
        return []
    }

    func decodeFlexibleTraceInt64(keys: [Key]) throws -> Int64? {
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
}

private extension Array {
    func nonEmptyOr(_ fallback: [Element]) -> [Element] {
        isEmpty ? fallback : self
    }
}
