import Foundation

struct RemediationHistoryFilters: Decodable, Hashable {
    let taskText: String?
    let agent: String?
    let agents: [String]
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let ruleIDs: [String]
    let riskLevels: [String]
    let decisions: [String]
    let statuses: [String]
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case agent
        case agents
        case projectRoot = "project_root"
        case projectRootAlt = "projectRoot"
        case currentCWD = "current_cwd"
        case currentCWDAlt = "currentCWD"
        case workspace
        case workspaceID = "workspace_id"
        case ruleIDs = "rule_ids"
        case ruleIDsAlt = "ruleIds"
        case rules
        case riskLevels = "risk_levels"
        case riskLevelsAlt = "riskLevels"
        case risks
        case decisions
        case decision
        case statuses
        case status
        case limit
    }

    init(
        taskText: String? = nil,
        agent: String? = nil,
        agents: [String] = [],
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        ruleIDs: [String] = [],
        riskLevels: [String] = [],
        decisions: [String] = [],
        statuses: [String] = [],
        limit: Int? = nil
    ) {
        self.taskText = taskText
        self.agent = agent
        self.agents = agents
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.ruleIDs = ruleIDs
        self.riskLevels = riskLevels
        self.decisions = decisions
        self.statuses = statuses
        self.limit = limit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.agents, .agent])
        projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot)
            ?? container.decodeIfPresent(String.self, forKey: .projectRootAlt)
        currentCWD = try container.decodeIfPresent(String.self, forKey: .currentCWD)
            ?? container.decodeIfPresent(String.self, forKey: .currentCWDAlt)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
            ?? container.decodeIfPresent(String.self, forKey: .workspaceID)
        ruleIDs = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.ruleIDs, .ruleIDsAlt, .rules])
        riskLevels = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.riskLevels, .riskLevelsAlt, .risks])
        decisions = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.decisions, .decision])
        statuses = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.statuses, .status])
        limit = try container.decodeFlexibleRemediationHistoryInt(keys: [.limit])
    }
}

struct RemediationHistorySummary: Decodable, Hashable {
    let totalCount: Int
    let recordedCount: Int
    let recurrenceCount: Int
    let reopenedCount: Int
    let readinessImprovementCount: Int
    let decisionCount: Int
    let statusCount: Int
    let blockerCount: Int
    let gapCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case recordCount = "record_count"
        case records
        case recordedCount = "recorded_count"
        case recorded
        case recurrenceCount = "recurrence_count"
        case recurrences
        case recurring
        case reopenedCount = "reopened_count"
        case reopened
        case readinessImprovementCount = "readiness_improvement_count"
        case readinessImprovementCountAlt = "readinessImprovementCount"
        case readinessImprovements = "readiness_improvements"
        case decisionCount = "decision_count"
        case decisions
        case statusCount = "status_count"
        case statuses
        case blockerCount = "blocker_count"
        case blockers
        case gapCount = "gap_count"
        case gaps
        case summary
        case message
        case text
    }

    init(
        totalCount: Int = 0,
        recordedCount: Int = 0,
        recurrenceCount: Int = 0,
        reopenedCount: Int = 0,
        readinessImprovementCount: Int = 0,
        decisionCount: Int = 0,
        statusCount: Int = 0,
        blockerCount: Int = 0,
        gapCount: Int = 0,
        summaryText: String = ""
    ) {
        self.totalCount = totalCount
        self.recordedCount = recordedCount
        self.recurrenceCount = recurrenceCount
        self.reopenedCount = reopenedCount
        self.readinessImprovementCount = readinessImprovementCount
        self.decisionCount = decisionCount
        self.statusCount = statusCount
        self.blockerCount = blockerCount
        self.gapCount = gapCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.totalCount, .recordCount, .records]) ?? 0,
            recordedCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.recordedCount, .recorded]) ?? 0,
            recurrenceCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.recurrenceCount, .recurrences, .recurring]) ?? 0,
            reopenedCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.reopenedCount, .reopened]) ?? 0,
            readinessImprovementCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.readinessImprovementCount, .readinessImprovementCountAlt, .readinessImprovements]) ?? 0,
            decisionCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.decisionCount, .decisions]) ?? 0,
            statusCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.statusCount, .statuses]) ?? 0,
            blockerCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.blockerCount, .blockers]) ?? 0,
            gapCount: try container.decodeFlexibleRemediationHistoryInt(keys: [.gapCount, .gaps]) ?? 0,
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

struct RemediationHistoryRecord: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let category: String
    let decision: String
    let status: String
    let agent: String?
    let workspace: String?
    let ruleID: String?
    let riskLevel: String?
    let taskText: String?
    let reviewArea: String?
    let sourceMethod: String?
    let skill: CapabilityTaxonomySkill?
    let recurrenceCount: Int
    let reopenedCount: Int
    let readinessImprovement: String?
    let recordedAt: String?
    let updatedAt: String?
    let rationale: String
    let note: String
    let evidenceRefs: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case recordID = "record_id"
        case recordId = "recordId"
        case historyID = "history_id"
        case historyId = "historyId"
        case title
        case name
        case label
        case category
        case kind
        case type
        case decision
        case outcome
        case status
        case state
        case agent
        case workspace
        case ruleID = "rule_id"
        case ruleIDAlt = "ruleId"
        case rule
        case riskLevel = "risk_level"
        case riskLevelAlt = "riskLevel"
        case risk
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case reviewArea = "review_area"
        case reviewAreaAlt = "reviewArea"
        case sourceMethod = "source_method"
        case sourceMethodAlt = "sourceMethod"
        case source
        case skill
        case affectedSkill = "affected_skill"
        case affectedSkillAlt = "affectedSkill"
        case recurrenceCount = "recurrence_count"
        case recurrenceCountAlt = "recurrenceCount"
        case recurrences
        case reopenedCount = "reopened_count"
        case reopenedCountAlt = "reopenedCount"
        case reopened
        case readinessImprovement = "readiness_improvement"
        case readinessImprovementAlt = "readinessImprovement"
        case readinessDelta = "readiness_delta"
        case recordedAt = "recorded_at"
        case recordedAtAlt = "recordedAt"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case updatedAtAlt = "updatedAt"
        case rationale
        case reason
        case summary
        case note
        case notes
        case message
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case safetyFlags = "safety_flags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            category = UIStrings.remediationHistoryRecord
            decision = UIStrings.remediationHistoryDecisionReviewed
            status = UIStrings.remediationHistoryStatusRecorded
            agent = nil
            workspace = nil
            ruleID = nil
            riskLevel = nil
            taskText = nil
            reviewArea = nil
            sourceMethod = nil
            skill = nil
            recurrenceCount = 0
            reopenedCount = 0
            readinessImprovement = nil
            recordedAt = nil
            updatedAt = nil
            rationale = value
            note = ""
            evidenceRefs = []
            gapNotes = []
            blockerNotes = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? UIStrings.remediationHistoryRecord
        category = try container.decodeIfPresent(String.self, forKey: .category)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? UIStrings.remediationHistoryRecord
        decision = try container.decodeIfPresent(String.self, forKey: .decision)
            ?? container.decodeIfPresent(String.self, forKey: .outcome)
            ?? UIStrings.remediationHistoryDecisionReviewed
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? UIStrings.remediationHistoryStatusRecorded
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
        ruleID = try container.decodeIfPresent(String.self, forKey: .ruleID)
            ?? container.decodeIfPresent(String.self, forKey: .ruleIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .rule)
        riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel)
            ?? container.decodeIfPresent(String.self, forKey: .riskLevelAlt)
            ?? container.decodeIfPresent(String.self, forKey: .risk)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        reviewArea = try container.decodeIfPresent(String.self, forKey: .reviewArea)
            ?? container.decodeIfPresent(String.self, forKey: .reviewAreaAlt)
        sourceMethod = try container.decodeIfPresent(String.self, forKey: .sourceMethod)
            ?? container.decodeIfPresent(String.self, forKey: .sourceMethodAlt)
            ?? container.decodeIfPresent(String.self, forKey: .source)
        skill = try container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkillAlt)
        recurrenceCount = try container.decodeFlexibleRemediationHistoryInt(keys: [.recurrenceCount, .recurrenceCountAlt, .recurrences]) ?? 0
        reopenedCount = try container.decodeFlexibleRemediationHistoryInt(keys: [.reopenedCount, .reopenedCountAlt, .reopened]) ?? 0
        readinessImprovement = try container.decodeIfPresent(String.self, forKey: .readinessImprovement)
            ?? container.decodeIfPresent(String.self, forKey: .readinessImprovementAlt)
            ?? container.decodeIfPresent(String.self, forKey: .readinessDelta)
        recordedAt = try container.decodeIfPresent(String.self, forKey: .recordedAt)
            ?? container.decodeIfPresent(String.self, forKey: .recordedAtAlt)
            ?? container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            ?? container.decodeIfPresent(String.self, forKey: .updatedAtAlt)
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note)
            ?? container.decodeIfPresent(String.self, forKey: .notes)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
        evidenceRefs = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        gapNotes = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        safetyFlags = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .recordID)
            ?? container.decodeIfPresent(String.self, forKey: .recordId)
            ?? container.decodeIfPresent(String.self, forKey: .historyID)
            ?? container.decodeIfPresent(String.self, forKey: .historyId)
            ?? "\(category)-\(title)-\(recordedAt ?? "")"
    }
}

typealias RemediationHistoryEvidenceReference = CrossAgentReadinessEvidenceReference
typealias RemediationHistorySafety = CrossAgentReadinessSafety

struct RemediationHistoryResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: RemediationHistoryFilters
    let summary: RemediationHistorySummary
    let records: [RemediationHistoryRecord]
    let decisions: [String]
    let statuses: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [RemediationHistoryEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: RemediationHistorySafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case records
        case history
        case items
        case rows
        case decisions
        case statuses
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
        filters: RemediationHistoryFilters = RemediationHistoryFilters(),
        summary: RemediationHistorySummary = RemediationHistorySummary(),
        records: [RemediationHistoryRecord] = [],
        decisions: [String] = [],
        statuses: [String] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [RemediationHistoryEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: RemediationHistorySafety = RemediationHistorySafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.records = records
        self.decisions = decisions
        self.statuses = statuses
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
        filters = try container.decodeIfPresent(RemediationHistoryFilters.self, forKey: .filters) ?? RemediationHistoryFilters()
        records = try container.decodeRemediationHistoryRecords(keys: [.records, .history, .items, .rows])
        summary = try container.decodeIfPresent(RemediationHistorySummary.self, forKey: .summary)
            ?? RemediationHistorySummary(totalCount: records.count)
        decisions = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.decisions])
        statuses = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.statuses])
        gapNotes = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleRemediationHistoryStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([RemediationHistoryEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([RemediationHistoryEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([RemediationHistoryEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(RemediationHistorySafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(RemediationHistorySafety.self, forKey: .safety)
            ?? RemediationHistorySafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.remediationHistoryUnavailable) -> RemediationHistoryResult {
        RemediationHistoryResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

struct RemediationHistoryRecordResult: Decodable, Hashable {
    let recorded: Bool
    let record: RemediationHistoryRecord?
    let records: [RemediationHistoryRecord]
    let summary: RemediationHistorySummary
    let message: String
    let evidenceReferences: [RemediationHistoryEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: RemediationHistorySafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !recorded }

    enum CodingKeys: String, CodingKey {
        case recorded
        case ok
        case success
        case record
        case historyRecord = "history_record"
        case historyRecordAlt = "historyRecord"
        case records
        case history
        case summary
        case message
        case note
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
        recorded: Bool = false,
        record: RemediationHistoryRecord? = nil,
        records: [RemediationHistoryRecord] = [],
        summary: RemediationHistorySummary = RemediationHistorySummary(),
        message: String = "",
        evidenceReferences: [RemediationHistoryEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: RemediationHistorySafety = RemediationHistorySafety(),
        fallbackReason: String? = nil
    ) {
        self.recorded = recorded
        self.record = record
        self.records = records
        self.summary = summary
        self.message = message
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        record = try container.decodeIfPresent(RemediationHistoryRecord.self, forKey: .record)
            ?? container.decodeIfPresent(RemediationHistoryRecord.self, forKey: .historyRecord)
            ?? container.decodeIfPresent(RemediationHistoryRecord.self, forKey: .historyRecordAlt)
        records = try container.decodeRemediationHistoryRecords(keys: [.records, .history])
        recorded = try container.decodeIfPresent(Bool.self, forKey: .recorded)
            ?? container.decodeIfPresent(Bool.self, forKey: .ok)
            ?? container.decodeIfPresent(Bool.self, forKey: .success)
            ?? (record != nil)
        summary = try container.decodeIfPresent(RemediationHistorySummary.self, forKey: .summary)
            ?? RemediationHistorySummary(totalCount: records.count + (record == nil ? 0 : 1), recordedCount: recorded ? 1 : 0)
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .note)
            ?? ""
        evidenceReferences = try container.decodeIfPresent([RemediationHistoryEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([RemediationHistoryEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([RemediationHistoryEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(RemediationHistorySafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(RemediationHistorySafety.self, forKey: .safety)
            ?? RemediationHistorySafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.remediationHistoryRecordUnavailable) -> RemediationHistoryRecordResult {
        RemediationHistoryRecordResult(fallbackReason: reason)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleRemediationHistoryInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let int = Int(trimmed) {
                    return int
                }
                if let double = Double(trimmed.replacingOccurrences(of: "%", with: "")) {
                    return Int(double.rounded())
                }
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([RemediationHistoryRecord].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleRemediationHistoryStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([RemediationHistoryEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(RemediationHistoryEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return [value ? UIStrings.stateEnabled : UIStrings.stateDisabled]
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return ["\(value)"]
            }
        }
        return []
    }

    func decodeRemediationHistoryRecords(keys: [Key]) throws -> [RemediationHistoryRecord] {
        for key in keys {
            if let values = try? decodeIfPresent([RemediationHistoryRecord].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(RemediationHistoryRecord.self, forKey: key) {
                return [value]
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                let data = try JSONEncoder().encode([value])
                return try JSONDecoder().decode([RemediationHistoryRecord].self, from: data)
            }
        }
        return []
    }
}
