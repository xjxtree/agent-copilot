import Foundation

struct AgentSessionSkillReviewFilters: Decodable, Hashable {
    let taskText: String?
    let agent: String?
    let agents: [String]
    let selectedSkillID: String?
    let selectedSkillName: String?
    let expectedSkillNames: [String]
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let transcriptProvided: Bool

    enum CodingKeys: String, CodingKey {
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case agent
        case agents
        case selectedSkillID = "selected_skill_id"
        case selectedSkillIDAlt = "selectedSkillID"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillNameAlt = "selectedSkillName"
        case expectedSkillNames = "expected_skill_names"
        case expectedSkillNamesAlt = "expectedSkillNames"
        case expectedSkills = "expected_skills"
        case projectRoot = "project_root"
        case projectRootAlt = "projectRoot"
        case currentCWD = "current_cwd"
        case currentCWDAlt = "currentCWD"
        case workspace
        case workspaceID = "workspace_id"
        case limit
        case transcriptProvided = "transcript_provided"
        case transcriptProvidedAlt = "transcriptProvided"
        case transcript
        case transcriptText = "transcript_text"
    }

    init(
        taskText: String? = nil,
        agent: String? = nil,
        agents: [String] = [],
        selectedSkillID: String? = nil,
        selectedSkillName: String? = nil,
        expectedSkillNames: [String] = [],
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        limit: Int? = nil,
        transcriptProvided: Bool = false
    ) {
        self.taskText = taskText
        self.agent = agent
        self.agents = agents
        self.selectedSkillID = selectedSkillID
        self.selectedSkillName = selectedSkillName
        self.expectedSkillNames = expectedSkillNames
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.limit = limit
        self.transcriptProvided = transcriptProvided
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleSessionReviewStringArray(keys: [.agents, .agent])
        selectedSkillID = try container.decodeIfPresent(String.self, forKey: .selectedSkillID)
            ?? container.decodeIfPresent(String.self, forKey: .selectedSkillIDAlt)
        selectedSkillName = try container.decodeIfPresent(String.self, forKey: .selectedSkillName)
            ?? container.decodeIfPresent(String.self, forKey: .selectedSkillNameAlt)
        expectedSkillNames = try container.decodeFlexibleSessionReviewStringArray(keys: [
            .expectedSkillNames,
            .expectedSkillNamesAlt,
            .expectedSkills
        ])
        projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot)
            ?? container.decodeIfPresent(String.self, forKey: .projectRootAlt)
        currentCWD = try container.decodeIfPresent(String.self, forKey: .currentCWD)
            ?? container.decodeIfPresent(String.self, forKey: .currentCWDAlt)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
            ?? container.decodeIfPresent(String.self, forKey: .workspaceID)
        limit = try container.decodeFlexibleSessionReviewInt(keys: [.limit])
        transcriptProvided = try container.decodeIfPresent(Bool.self, forKey: .transcriptProvided)
            ?? container.decodeIfPresent(Bool.self, forKey: .transcriptProvidedAlt)
            ?? container.hasNonEmptySessionReviewString(keys: [.transcriptText, .transcript])
    }
}

struct AgentSessionSkillReviewSummary: Decodable, Hashable {
    let reviewCount: Int
    let detectedSkillCount: Int
    let expectedSkillCount: Int
    let interferenceCount: Int
    let safeNextStepCount: Int
    let safetyFlagCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case reviewCount = "review_count"
        case reviews
        case records
        case detectedSkillCount = "detected_skill_count"
        case detectedSkills = "detected_skills"
        case expectedSkillCount = "expected_skill_count"
        case expectedSkills = "expected_skills"
        case interferenceCount = "interference_count"
        case interference
        case interferenceSignals = "interference_signals"
        case safeNextStepCount = "safe_next_step_count"
        case safeNextSteps = "safe_next_steps"
        case safetyFlagCount = "safety_flag_count"
        case safetyFlags = "safety_flags"
        case summary
        case message
        case text
    }

    init(
        reviewCount: Int = 0,
        detectedSkillCount: Int = 0,
        expectedSkillCount: Int = 0,
        interferenceCount: Int = 0,
        safeNextStepCount: Int = 0,
        safetyFlagCount: Int = 0,
        summaryText: String = ""
    ) {
        self.reviewCount = reviewCount
        self.detectedSkillCount = detectedSkillCount
        self.expectedSkillCount = expectedSkillCount
        self.interferenceCount = interferenceCount
        self.safeNextStepCount = safeNextStepCount
        self.safetyFlagCount = safetyFlagCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            reviewCount: try container.decodeFlexibleSessionReviewInt(keys: [.reviewCount, .reviews, .records]) ?? 0,
            detectedSkillCount: try container.decodeFlexibleSessionReviewInt(keys: [.detectedSkillCount, .detectedSkills]) ?? 0,
            expectedSkillCount: try container.decodeFlexibleSessionReviewInt(keys: [.expectedSkillCount, .expectedSkills]) ?? 0,
            interferenceCount: try container.decodeFlexibleSessionReviewInt(keys: [.interferenceCount, .interference, .interferenceSignals]) ?? 0,
            safeNextStepCount: try container.decodeFlexibleSessionReviewInt(keys: [.safeNextStepCount, .safeNextSteps]) ?? 0,
            safetyFlagCount: try container.decodeFlexibleSessionReviewInt(keys: [.safetyFlagCount, .safetyFlags]) ?? 0,
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

private struct AgentSessionSkillReviewAnalysisPayload: Decodable, Hashable {
    let catalogAvailable: Bool?
    let outcome: String?
    let summary: String?
    let reasons: [String]
    let detectedSkills: [TaskBenchmarkSkillRef]
    let expectedSkillSignals: [AgentSessionExpectedSkillSignalPayload]
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case outcome
        case status
        case result
        case summary
        case rationale
        case message
        case reasons
        case reason
        case matchReasons = "match_reasons"
        case detectedSkills = "detected_skills"
        case detectedSkillNames = "detected_skill_names"
        case actualSkills = "actual_skills"
        case expectedSkillSignals = "expected_skill_signals"
        case expectedSkillSignalsAlt = "expectedSkillSignals"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        catalogAvailable = try container.decodeIfPresent(Bool.self, forKey: .catalogAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .catalogAvailableAlt)
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .result)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .message)
        reasons = try container.decodeFlexibleSessionReviewStringArray(keys: [.reasons, .reason, .matchReasons])
        detectedSkills = try container.decodeFlexibleSessionReviewSkillRefs(keys: [
            .detectedSkills,
            .detectedSkillNames,
            .actualSkills
        ])
        let decodedExpectedSkillSignals = try container.decodeIfPresent(
            [AgentSessionExpectedSkillSignalPayload].self,
            forKey: .expectedSkillSignals
        )
        let decodedExpectedSkillSignalsAlt = try container.decodeIfPresent(
            [AgentSessionExpectedSkillSignalPayload].self,
            forKey: .expectedSkillSignalsAlt
        )
        expectedSkillSignals = decodedExpectedSkillSignals ?? decodedExpectedSkillSignalsAlt ?? []
        evidenceRefs = try container.decodeFlexibleSessionReviewStringArray(keys: [
            .evidenceRefs,
            .evidenceRefsAlt,
            .evidence
        ])
    }
}

private struct AgentSessionExpectedSkillSignalPayload: Decodable, Hashable {
    let kind: String
    let value: String
    let matched: Bool
    let matchedInstanceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case kind
        case value
        case name
        case skillName = "skill_name"
        case matched
        case matchedInstanceIDs = "matched_instance_ids"
        case matchedInstanceIDsAlt = "matchedInstanceIDs"
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            kind = "skill"
            self.value = value
            matched = false
            matchedInstanceIDs = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "skill"
        value = try container.decodeIfPresent(String.self, forKey: .value)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .skillName)
            ?? UIStrings.unknown
        matched = try container.decodeIfPresent(Bool.self, forKey: .matched) ?? false
        matchedInstanceIDs = try container.decodeFlexibleSessionReviewStringArray(keys: [
            .matchedInstanceIDs,
            .matchedInstanceIDsAlt
        ])
    }

    var skillRef: TaskBenchmarkSkillRef {
        TaskBenchmarkSkillRef(
            instanceID: matchedInstanceIDs.first,
            name: value,
            agent: UIStrings.unknown
        )
    }
}

struct AgentSessionInterferenceSignal: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let severity: String
    let category: String
    let detail: String
    let agent: String?
    let skill: TaskBenchmarkSkillRef?
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case signalID = "signal_id"
        case signalId = "signalId"
        case title
        case label
        case name
        case severity
        case risk
        case priority
        case category
        case kind
        case type
        case detail
        case summary
        case message
        case reason
        case agent
        case skill
        case affectedSkill = "affected_skill"
        case affectedSkillAlt = "affectedSkill"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            severity = UIStrings.unknown
            category = UIStrings.unknown
            detail = value
            agent = nil
            skill = nil
            evidenceRefs = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.agentSessionReviewInterference
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .risk)
            ?? container.decodeIfPresent(String.self, forKey: .priority)
            ?? UIStrings.unknown
        category = try container.decodeIfPresent(String.self, forKey: .category)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? UIStrings.unknown
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? title
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        skill = try container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .skill)
            ?? container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .affectedSkill)
            ?? container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .affectedSkillAlt)
        evidenceRefs = try container.decodeFlexibleSessionReviewStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .signalID)
            ?? container.decodeIfPresent(String.self, forKey: .signalId)
            ?? "\(category)-\(severity)-\(title)"
    }
}

struct AgentSessionSkillReviewRecord: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let agent: String?
    let taskText: String
    let outcome: String
    let summary: String
    let reasons: [String]
    let detectedSkills: [TaskBenchmarkSkillRef]
    let expectedSkills: [TaskBenchmarkSkillRef]
    let interference: [AgentSessionInterferenceSignal]
    let safeNextSteps: [String]
    let safetyFlags: [String]
    let evidenceReferences: [CrossAgentReadinessEvidenceReference]
    let redactedExcerpt: String
    let safety: CrossAgentReadinessSafety
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case reviewID = "review_id"
        case reviewId = "reviewId"
        case sessionReviewID = "session_review_id"
        case sessionReviewId = "sessionReviewId"
        case title
        case label
        case name
        case agent
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case outcome
        case status
        case result
        case matchStatus = "match_status"
        case summary
        case rationale
        case reason
        case reasons
        case matchReasons = "match_reasons"
        case notes
        case message
        case detectedSkills = "detected_skills"
        case detectedSkillNames = "detected_skill_names"
        case detectedRoutes = "detected_routes"
        case actualSkills = "actual_skills"
        case expectedSkills = "expected_skills"
        case expectedSkillNames = "expected_skill_names"
        case expectedRoutes = "expected_routes"
        case interference
        case interferenceSignals = "interference_signals"
        case interferenceSignalsAlt = "interferenceSignals"
        case collisions
        case conflicts
        case safeNextSteps = "safe_next_steps"
        case safeNextStepsAlt = "safeNextSteps"
        case safeNextStepLabels = "safe_next_step_labels"
        case nextSteps = "next_steps"
        case recommendations
        case safetyFlags = "safety_flags"
        case safetyFlagList = "safetyFlagList"
        case warnings
        case flags
        case evidenceReferences = "evidence_references"
        case evidenceReferencesAlt = "evidenceReferences"
        case evidenceRefs = "evidence_refs"
        case evidence
        case redactedExcerpt = "redacted_excerpt"
        case excerpt
        case redactedPreview = "redacted_preview"
        case preview
        case transcriptExcerpt = "transcript_excerpt"
        case safety
        case analysis
        case createdAt = "created_at"
        case createdAtAlt = "createdAt"
        case reviewedAt = "reviewed_at"
        case updatedAt = "updated_at"
        case updatedAtAlt = "updatedAt"
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            agent = nil
            taskText = ""
            outcome = value
            summary = value
            reasons = []
            detectedSkills = []
            expectedSkills = []
            interference = []
            safeNextSteps = []
            safetyFlags = []
            evidenceReferences = []
            redactedExcerpt = ""
            safety = CrossAgentReadinessSafety()
            createdAt = nil
            updatedAt = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let analysis = (try? container.decodeIfPresent(AgentSessionSkillReviewAnalysisPayload.self, forKey: .analysis)) ?? nil
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.agentSessionReviewRecord
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
            ?? ""
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .result)
            ?? container.decodeIfPresent(String.self, forKey: .matchStatus)
            ?? analysis?.outcome
            ?? UIStrings.unknown
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? analysis?.summary
            ?? ""
        let decodedReasons = try container.decodeFlexibleSessionReviewStringArray(keys: [.reasons, .matchReasons, .notes])
        reasons = decodedReasons.isEmpty ? analysis?.reasons ?? [] : decodedReasons
        let decodedDetectedSkills = try container.decodeFlexibleSessionReviewSkillRefs(keys: [
            .detectedSkills,
            .detectedSkillNames,
            .detectedRoutes,
            .actualSkills
        ])
        detectedSkills = decodedDetectedSkills.isEmpty ? analysis?.detectedSkills ?? [] : decodedDetectedSkills
        let decodedExpectedSkills = try container.decodeFlexibleSessionReviewSkillRefs(keys: [
            .expectedSkills,
            .expectedSkillNames,
            .expectedRoutes
        ])
        let expectedFromAnalysis = analysis?.expectedSkillSignals.map(\.skillRef) ?? []
        expectedSkills = decodedExpectedSkills.isEmpty ? expectedFromAnalysis : decodedExpectedSkills
        interference = try container.decodeSessionReviewInterference(keys: [
            .interference,
            .interferenceSignals,
            .interferenceSignalsAlt,
            .collisions,
            .conflicts
        ])
        safeNextSteps = try container.decodeFlexibleSessionReviewStringArray(keys: [
            .safeNextSteps,
            .safeNextStepsAlt,
            .safeNextStepLabels,
            .nextSteps,
            .recommendations
        ])
        safetyFlags = try container.decodeFlexibleSessionReviewStringArray(keys: [.safetyFlags, .safetyFlagList, .warnings, .flags])
        let decodedEvidenceReferences = try container.decodeFlexibleSessionReviewEvidenceReferences(keys: [
            .evidenceReferences,
            .evidenceReferencesAlt,
            .evidenceRefs,
            .evidence
        ])
        evidenceReferences = decodedEvidenceReferences.isEmpty
            ? analysis?.evidenceRefs.map { container.sessionReviewEvidenceReference(from: $0) } ?? []
            : decodedEvidenceReferences
        redactedExcerpt = try container.decodeIfPresent(String.self, forKey: .redactedExcerpt)
            ?? container.decodeIfPresent(String.self, forKey: .excerpt)
            ?? container.decodeIfPresent(String.self, forKey: .redactedPreview)
            ?? container.decodeIfPresent(String.self, forKey: .preview)
            ?? container.decodeIfPresent(String.self, forKey: .transcriptExcerpt)
            ?? ""
        safety = try container.decodeIfPresent(CrossAgentReadinessSafety.self, forKey: .safety)
            ?? container.decodeIfPresent(CrossAgentReadinessSafety.self, forKey: .safetyFlags)
            ?? CrossAgentReadinessSafety(notes: safetyFlags)
        createdAt = try container.decodeFlexibleSessionReviewString(keys: [.createdAt, .createdAtAlt, .reviewedAt])
        updatedAt = try container.decodeFlexibleSessionReviewString(keys: [.updatedAt, .updatedAtAlt])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .reviewID)
            ?? container.decodeIfPresent(String.self, forKey: .reviewId)
            ?? container.decodeIfPresent(String.self, forKey: .sessionReviewID)
            ?? container.decodeIfPresent(String.self, forKey: .sessionReviewId)
            ?? "\(agent ?? "")-\(title)-\(createdAt ?? taskText)"
    }
}

typealias AgentSessionSkillReviewEvidenceReference = CrossAgentReadinessEvidenceReference
typealias AgentSessionSkillReviewSafety = CrossAgentReadinessSafety

struct AgentSessionSkillReviewResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: AgentSessionSkillReviewFilters
    let summary: AgentSessionSkillReviewSummary
    let review: AgentSessionSkillReviewRecord?
    let reviews: [AgentSessionSkillReviewRecord]
    let safeNextSteps: [String]
    let interference: [AgentSessionInterferenceSignal]
    let evidenceReferences: [AgentSessionSkillReviewEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: AgentSessionSkillReviewSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable && review == nil && reviews.isEmpty }

    enum CodingKeys: String, CodingKey {
        case id
        case reviewID = "review_id"
        case reviewId = "reviewId"
        case sessionReviewID = "session_review_id"
        case sessionReviewId = "sessionReviewId"
        case outcome
        case status
        case detectedSkills = "detected_skills"
        case detectedSkillNames = "detected_skill_names"
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case review
        case record
        case sessionReview = "session_review"
        case sessionReviewAlt = "sessionReview"
        case item
        case reviews
        case records
        case items
        case safeNextSteps = "safe_next_steps"
        case safeNextStepsAlt = "safeNextSteps"
        case safeNextStepLabels = "safe_next_step_labels"
        case interference
        case interferenceSignals = "interference_signals"
        case interferenceSignalsAlt = "interferenceSignals"
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
        filters: AgentSessionSkillReviewFilters = AgentSessionSkillReviewFilters(),
        summary: AgentSessionSkillReviewSummary = AgentSessionSkillReviewSummary(),
        review: AgentSessionSkillReviewRecord? = nil,
        reviews: [AgentSessionSkillReviewRecord] = [],
        safeNextSteps: [String] = [],
        interference: [AgentSessionInterferenceSignal] = [],
        evidenceReferences: [AgentSessionSkillReviewEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: AgentSessionSkillReviewSafety = AgentSessionSkillReviewSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.review = review
        self.reviews = reviews
        self.safeNextSteps = safeNextSteps
        self.interference = interference
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let records = try? decoder.singleValueContainer().decode([AgentSessionSkillReviewRecord].self) {
            self.init(
                catalogAvailable: true,
                summary: AgentSessionSkillReviewSummary(reviewCount: records.count),
                review: records.first,
                reviews: records
            )
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedReviews = try container.decodeSessionReviewRecords(keys: [.reviews, .records, .items])
        let decodedReview = try container.decodeIfPresent(AgentSessionSkillReviewRecord.self, forKey: .review)
            ?? container.decodeIfPresent(AgentSessionSkillReviewRecord.self, forKey: .record)
            ?? container.decodeIfPresent(AgentSessionSkillReviewRecord.self, forKey: .sessionReview)
            ?? container.decodeIfPresent(AgentSessionSkillReviewRecord.self, forKey: .sessionReviewAlt)
            ?? container.decodeIfPresent(AgentSessionSkillReviewRecord.self, forKey: .item)
            ?? (container.hasDirectSessionReviewRecord ? (try? AgentSessionSkillReviewRecord(from: decoder)) : nil)
        let decodedInterference = try container.decodeSessionReviewInterference(keys: [
            .interference,
            .interferenceSignals,
            .interferenceSignalsAlt
        ])
        let allReviews = decodedReviews.isEmpty ? decodedReview.map { [$0] } ?? [] : decodedReviews
        let generatedBy = try container.decodeIfPresent(String.self, forKey: .generatedBy)
            ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
            ?? "local"
        let catalogAvailable = try container.decodeIfPresent(Bool.self, forKey: .catalogAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .catalogAvailableAlt)
            ?? true
        let filters = try container.decodeIfPresent(AgentSessionSkillReviewFilters.self, forKey: .filters)
            ?? AgentSessionSkillReviewFilters()
        let summary = try container.decodeIfPresent(AgentSessionSkillReviewSummary.self, forKey: .summary)
            ?? AgentSessionSkillReviewSummary(
                reviewCount: allReviews.count,
                detectedSkillCount: (decodedReview?.detectedSkills.count ?? 0) + decodedReviews.reduce(0) { $0 + $1.detectedSkills.count },
                expectedSkillCount: (decodedReview?.expectedSkills.count ?? 0) + decodedReviews.reduce(0) { $0 + $1.expectedSkills.count },
                interferenceCount: decodedInterference.count + (decodedReview?.interference.count ?? 0) + decodedReviews.reduce(0) { $0 + $1.interference.count }
            )
        let review = decodedReview ?? decodedReviews.first
        let safeNextSteps = try container.decodeFlexibleSessionReviewStringArray(keys: [
            .safeNextSteps,
            .safeNextStepsAlt,
            .safeNextStepLabels
        ])
        let evidenceReferences = try container.decodeFlexibleSessionReviewEvidenceReferences(keys: [
            .evidenceReferences,
            .evidenceReferencesAlt,
            .evidence
        ])
        let promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        let safetyFlags = try container.decodeIfPresent(AgentSessionSkillReviewSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(AgentSessionSkillReviewSafety.self, forKey: .safety)
            ?? decodedReview?.safety
            ?? decodedReviews.first?.safety
            ?? AgentSessionSkillReviewSafety()
        let fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
        self.init(
            generatedBy: generatedBy,
            catalogAvailable: catalogAvailable,
            filters: filters,
            summary: summary,
            review: review,
            reviews: allReviews,
            safeNextSteps: safeNextSteps,
            interference: decodedInterference,
            evidenceReferences: evidenceReferences,
            promptRequest: promptRequest,
            safetyFlags: safetyFlags,
            fallbackReason: fallbackReason
        )
    }

    static func unavailable(reason: String = UIStrings.agentSessionReviewUnavailable) -> AgentSessionSkillReviewResult {
        AgentSessionSkillReviewResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

struct AgentSessionSkillReviewListResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: AgentSessionSkillReviewFilters
    let summary: AgentSessionSkillReviewSummary
    let reviews: [AgentSessionSkillReviewRecord]
    let evidenceReferences: [AgentSessionSkillReviewEvidenceReference]
    let safetyFlags: AgentSessionSkillReviewSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && reviews.isEmpty && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case reviews
        case records
        case items
        case sessionReviews = "session_reviews"
        case sessionReviewsAlt = "sessionReviews"
        case evidenceReferences = "evidence_references"
        case evidenceReferencesAlt = "evidenceReferences"
        case evidence
        case safetyFlags = "safety_flags"
        case safety
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(
        generatedBy: String = "local",
        catalogAvailable: Bool = true,
        filters: AgentSessionSkillReviewFilters = AgentSessionSkillReviewFilters(),
        summary: AgentSessionSkillReviewSummary = AgentSessionSkillReviewSummary(),
        reviews: [AgentSessionSkillReviewRecord] = [],
        evidenceReferences: [AgentSessionSkillReviewEvidenceReference] = [],
        safetyFlags: AgentSessionSkillReviewSafety = AgentSessionSkillReviewSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.reviews = reviews
        self.evidenceReferences = evidenceReferences
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let records = try? decoder.singleValueContainer().decode([AgentSessionSkillReviewRecord].self) {
            self.init(summary: AgentSessionSkillReviewSummary(reviewCount: records.count), reviews: records)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedReviews = try container.decodeSessionReviewRecords(keys: [
            .reviews,
            .records,
            .items,
            .sessionReviews,
            .sessionReviewsAlt
        ])
        let generatedBy = try container.decodeIfPresent(String.self, forKey: .generatedBy)
            ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
            ?? "local"
        let catalogAvailable = try container.decodeIfPresent(Bool.self, forKey: .catalogAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .catalogAvailableAlt)
            ?? true
        let filters = try container.decodeIfPresent(AgentSessionSkillReviewFilters.self, forKey: .filters)
            ?? AgentSessionSkillReviewFilters()
        let summary = try container.decodeIfPresent(AgentSessionSkillReviewSummary.self, forKey: .summary)
            ?? AgentSessionSkillReviewSummary(reviewCount: decodedReviews.count)
        let evidenceReferences = try container.decodeFlexibleSessionReviewEvidenceReferences(keys: [
            .evidenceReferences,
            .evidenceReferencesAlt,
            .evidence
        ])
        let safetyFlags = try container.decodeIfPresent(AgentSessionSkillReviewSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(AgentSessionSkillReviewSafety.self, forKey: .safety)
            ?? AgentSessionSkillReviewSafety()
        let fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
        self.init(
            generatedBy: generatedBy,
            catalogAvailable: catalogAvailable,
            filters: filters,
            summary: summary,
            reviews: decodedReviews,
            evidenceReferences: evidenceReferences,
            safetyFlags: safetyFlags,
            fallbackReason: fallbackReason
        )
    }

    static func unavailable(reason: String = UIStrings.agentSessionReviewUnavailable) -> AgentSessionSkillReviewListResult {
        AgentSessionSkillReviewListResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

struct AgentSessionSkillReviewDeleteResult: Decodable, Hashable {
    let deleted: Bool
    let reviewID: String?
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !deleted }

    enum CodingKeys: String, CodingKey {
        case deleted
        case success
        case ok
        case reviewID = "review_id"
        case reviewId = "reviewId"
        case sessionReviewID = "session_review_id"
        case sessionReviewId = "sessionReviewId"
        case id
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(deleted: Bool, reviewID: String? = nil, fallbackReason: String? = nil) {
        self.deleted = deleted
        self.reviewID = reviewID
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
            ?? container.decodeIfPresent(Bool.self, forKey: .success)
            ?? container.decodeIfPresent(Bool.self, forKey: .ok)
            ?? false
        var decodedReviewID = try container.decodeIfPresent(String.self, forKey: .reviewID)
        if decodedReviewID == nil {
            decodedReviewID = try container.decodeIfPresent(String.self, forKey: .reviewId)
        }
        if decodedReviewID == nil {
            decodedReviewID = try container.decodeIfPresent(String.self, forKey: .sessionReviewID)
        }
        if decodedReviewID == nil {
            decodedReviewID = try container.decodeIfPresent(String.self, forKey: .sessionReviewId)
        }
        if decodedReviewID == nil {
            decodedReviewID = try container.decodeIfPresent(String.self, forKey: .id)
        }
        let fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
        self.init(deleted: deleted, reviewID: decodedReviewID, fallbackReason: fallbackReason)
    }

    static func unavailable(reason: String = UIStrings.agentSessionReviewDeleteUnavailable) -> AgentSessionSkillReviewDeleteResult {
        AgentSessionSkillReviewDeleteResult(deleted: false, fallbackReason: reason)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleSessionReviewInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([AgentSessionSkillReviewRecord].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([AgentSessionInterferenceSignal].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleSessionReviewStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: key) {
                return values.map(\.name)
            }
            if let values = try? decodeIfPresent([AgentSessionInterferenceSignal].self, forKey: key) {
                return values.map(\.detail)
            }
            if let values = try? decodeIfPresent([AgentSessionSkillReviewEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(AgentSessionSkillReviewEvidenceReference.self, forKey: key) {
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

    func decodeFlexibleSessionReviewString(keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int64.self, forKey: key) {
                return "\(value)"
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return "\(value)"
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return "\(Int64(value.rounded()))"
            }
        }
        return nil
    }

    func decodeFlexibleSessionReviewEvidenceReferences(keys: [Key]) throws -> [AgentSessionSkillReviewEvidenceReference] {
        for key in keys {
            if let values = try? decodeIfPresent([AgentSessionSkillReviewEvidenceReference].self, forKey: key) {
                return values
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map { sessionReviewEvidenceReference(from: $0) }
            }
            if let value = try? decodeIfPresent(AgentSessionSkillReviewEvidenceReference.self, forKey: key) {
                return [value]
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [sessionReviewEvidenceReference(from: value)]
            }
        }
        return []
    }

    func decodeFlexibleSessionReviewSkillRefs(keys: [Key]) throws -> [TaskBenchmarkSkillRef] {
        for key in keys {
            if let values = try? decodeIfPresent([TaskBenchmarkSkillRef].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: key) {
                return [value]
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map { TaskBenchmarkSkillRef(instanceID: nil, name: $0, agent: UIStrings.unknown) }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [TaskBenchmarkSkillRef(instanceID: nil, name: value, agent: UIStrings.unknown)]
            }
        }
        return []
    }

    func decodeSessionReviewInterference(keys: [Key]) throws -> [AgentSessionInterferenceSignal] {
        for key in keys {
            if let values = try? decodeIfPresent([AgentSessionInterferenceSignal].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(AgentSessionInterferenceSignal.self, forKey: key) {
                return [value]
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map { value in
                    let json = "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
                    return (try? JSONDecoder().decode(AgentSessionInterferenceSignal.self, from: Data(json.utf8)))
                        ?? sessionReviewInterferenceSignal(from: value)
                }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [sessionReviewInterferenceSignal(from: value)]
            }
        }
        return []
    }

    func decodeSessionReviewRecords(keys: [Key]) throws -> [AgentSessionSkillReviewRecord] {
        for key in keys {
            if let values = try? decodeIfPresent([AgentSessionSkillReviewRecord].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(AgentSessionSkillReviewRecord.self, forKey: key) {
                return [value]
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.compactMap { value in
                    let json = "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
                    return try? JSONDecoder().decode(AgentSessionSkillReviewRecord.self, from: Data(json.utf8))
                }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                let json = "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
                return (try? JSONDecoder().decode(AgentSessionSkillReviewRecord.self, from: Data(json.utf8))).map { [$0] } ?? []
            }
        }
        return []
    }

    func hasNonEmptySessionReviewString(keys: [Key]) -> Bool {
        keys.contains { key in
            guard let value = try? decodeIfPresent(String.self, forKey: key) else { return false }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    var hasDirectSessionReviewRecord: Bool {
        contains(Key(stringValue: "id")!)
            || contains(Key(stringValue: "review_id")!)
            || contains(Key(stringValue: "reviewId")!)
            || contains(Key(stringValue: "session_review_id")!)
            || contains(Key(stringValue: "sessionReviewId")!)
            || contains(Key(stringValue: "outcome")!)
            || contains(Key(stringValue: "status")!)
            || contains(Key(stringValue: "detected_skills")!)
            || contains(Key(stringValue: "detected_skill_names")!)
    }

    func sessionReviewInterferenceSignal(from value: String) -> AgentSessionInterferenceSignal {
        let json = "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        return try! JSONDecoder().decode(AgentSessionInterferenceSignal.self, from: Data(json.utf8))
    }

    func sessionReviewEvidenceReference(from value: String) -> AgentSessionSkillReviewEvidenceReference {
        let json = "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        return try! JSONDecoder().decode(AgentSessionSkillReviewEvidenceReference.self, from: Data(json.utf8))
    }
}
