import Foundation

struct TaskCockpitOperationState: Hashable {
    enum Phase: String, Hashable {
        case idle
        case preparing
        case completed
        case fallback
        case timedOut
        case cancelled
        case failed
    }

    let phase: Phase
    let taskText: String
    let message: String
    let startedAt: Date?
    let finishedAt: Date?
    let timeoutSeconds: Int

    static let idle = TaskCockpitOperationState(
        phase: .idle,
        taskText: "",
        message: "",
        startedAt: nil,
        finishedAt: nil,
        timeoutSeconds: 0
    )

    var isPreparing: Bool {
        phase == .preparing
    }

    var canCancel: Bool {
        phase == .preparing
    }

    var canRetry: Bool {
        switch phase {
        case .fallback, .timedOut, .cancelled, .failed:
            return !taskText.isEmpty
        case .idle, .preparing, .completed:
            return false
        }
    }

    func elapsedSeconds(now: Date = Date()) -> Int {
        guard let startedAt else { return 0 }
        let end = finishedAt ?? now
        return max(0, Int(end.timeIntervalSince(startedAt).rounded(.down)))
    }

    static func preparing(taskText: String, startedAt: Date = Date(), timeoutSeconds: Int) -> TaskCockpitOperationState {
        TaskCockpitOperationState(
            phase: .preparing,
            taskText: taskText,
            message: UIStrings.taskCockpitPreparingStatus(elapsedSeconds: 0, timeoutSeconds: timeoutSeconds),
            startedAt: startedAt,
            finishedAt: nil,
            timeoutSeconds: timeoutSeconds
        )
    }

    func finished(phase: Phase, message: String, finishedAt: Date = Date()) -> TaskCockpitOperationState {
        TaskCockpitOperationState(
            phase: phase,
            taskText: taskText,
            message: message,
            startedAt: startedAt,
            finishedAt: finishedAt,
            timeoutSeconds: timeoutSeconds
        )
    }
}

struct TaskCockpitFilters: Decodable, Hashable {
    let taskText: String
    let agent: String?
    let agents: [String]
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let includeSessionReview: Bool
    let includeProviderObservability: Bool
    let includeRemediationContext: Bool

    enum CodingKeys: String, CodingKey {
        case task
        case taskText = "task_text"
        case taskTextAlt = "taskText"
        case userIntent = "user_intent"
        case agent
        case agents
        case selectedSkillID = "selected_skill_id"
        case selectedSkillIDAlt = "selectedSkillID"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillNameAlt = "selectedSkillName"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillAgentAlt = "selectedSkillAgent"
        case projectRoot = "project_root"
        case projectRootAlt = "projectRoot"
        case currentCWD = "current_cwd"
        case currentCWDAlt = "currentCWD"
        case workspace
        case workspaceID = "workspace_id"
        case limit
        case includeSessionReview = "include_session_review"
        case includeSessionReviewAlt = "includeSessionReview"
        case includeProviderObservability = "include_provider_observability"
        case includeProviderObservabilityAlt = "includeProviderObservability"
        case includeRemediationContext = "include_remediation_context"
        case includeRemediationContextAlt = "includeRemediationContext"
    }

    init(
        taskText: String = "",
        agent: String? = nil,
        agents: [String] = [],
        selectedSkillID: String? = nil,
        selectedSkillName: String? = nil,
        selectedSkillAgent: String? = nil,
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        limit: Int? = nil,
        includeSessionReview: Bool = true,
        includeProviderObservability: Bool = true,
        includeRemediationContext: Bool = true
    ) {
        self.taskText = taskText
        self.agent = agent
        self.agents = agents
        self.selectedSkillID = selectedSkillID
        self.selectedSkillName = selectedSkillName
        self.selectedSkillAgent = selectedSkillAgent
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.limit = limit
        self.includeSessionReview = includeSessionReview
        self.includeProviderObservability = includeProviderObservability
        self.includeRemediationContext = includeRemediationContext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeFlexibleTaskCockpitString(keys: [.task, .taskText, .taskTextAlt, .userIntent]) ?? ""
        agent = try container.decodeFlexibleTaskCockpitString(keys: [.agent])
        agents = try container.decodeFlexibleTaskCockpitStringArray(keys: [.agents, .agent])
        selectedSkillID = try container.decodeFlexibleTaskCockpitString(keys: [.selectedSkillID, .selectedSkillIDAlt])
        selectedSkillName = try container.decodeFlexibleTaskCockpitString(keys: [.selectedSkillName, .selectedSkillNameAlt])
        selectedSkillAgent = try container.decodeFlexibleTaskCockpitString(keys: [.selectedSkillAgent, .selectedSkillAgentAlt])
        projectRoot = try container.decodeFlexibleTaskCockpitString(keys: [.projectRoot, .projectRootAlt])
        currentCWD = try container.decodeFlexibleTaskCockpitString(keys: [.currentCWD, .currentCWDAlt])
        workspace = try container.decodeFlexibleTaskCockpitString(keys: [.workspace, .workspaceID])
        limit = try container.decodeFlexibleTaskCockpitInt(keys: [.limit])
        includeSessionReview = try container.decodeFlexibleTaskCockpitBool(keys: [.includeSessionReview, .includeSessionReviewAlt]) ?? true
        includeProviderObservability = try container.decodeFlexibleTaskCockpitBool(keys: [.includeProviderObservability, .includeProviderObservabilityAlt]) ?? true
        includeRemediationContext = try container.decodeFlexibleTaskCockpitBool(keys: [.includeRemediationContext, .includeRemediationContextAlt]) ?? true
    }
}

struct TaskCockpitSummary: Decodable, Hashable {
    let taskText: String
    let summaryText: String
    let routeCandidateCount: Int
    let agentCandidateCount: Int
    let skillCandidateCount: Int
    let readinessSignalCount: Int
    let sessionReviewCount: Int
    let providerCallCount: Int
    let remediationItemCount: Int
    let gapCount: Int
    let blockerCount: Int
    let evidenceCount: Int
    let safetyFlagCount: Int
    let recommendedAgent: String?
    let recommendedSkillName: String?
    let readinessScore: Int?
    let routingScore: Int?

    enum CodingKeys: String, CodingKey {
        case task
        case taskText = "task_text"
        case taskTextAlt = "taskText"
        case userIntent = "user_intent"
        case summary
        case message
        case text
        case routeCandidateCount = "route_candidate_count"
        case routeCandidateCountAlt = "routeCandidateCount"
        case routeCount = "route_count"
        case routes
        case agentCandidateCount = "agent_candidate_count"
        case agentCandidateCountAlt = "agentCandidateCount"
        case agentCount = "agent_count"
        case agents
        case skillCandidateCount = "skill_candidate_count"
        case skillCandidateCountAlt = "skillCandidateCount"
        case candidateSkillCount = "candidate_skill_count"
        case candidateCount = "candidate_count"
        case skills
        case readinessSignalCount = "readiness_signal_count"
        case readinessSignalCountAlt = "readinessSignalCount"
        case readinessSignals = "readiness_signals"
        case sessionReviewCount = "session_review_count"
        case sessionReviewCountAlt = "sessionReviewCount"
        case sessionReviews = "session_reviews"
        case providerCallCount = "provider_call_count"
        case providerCallCountAlt = "providerCallCount"
        case providerObservabilityRowCount = "provider_observability_row_count"
        case providerCalls = "provider_calls"
        case remediationItemCount = "remediation_item_count"
        case remediationItemCountAlt = "remediationItemCount"
        case remediationNextStepCount = "remediation_next_step_count"
        case remediationItems = "remediation_items"
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case evidenceCount = "evidence_count"
        case evidence
        case evidenceReferences = "evidence_references"
        case safetyFlagCount = "safety_flag_count"
        case safetyFlags = "safety_flags"
        case recommendedAgent = "recommended_agent"
        case recommendedAgentAlt = "recommendedAgent"
        case recommendedSkillName = "recommended_skill_name"
        case recommendedSkillNameAlt = "recommendedSkillName"
        case topSkillName = "top_skill_name"
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case routingScore = "routing_score"
        case routingScoreAlt = "routingScore"
        case routingConfidenceScore = "routing_confidence_score"
        case routingConfidenceScoreAlt = "routingConfidenceScore"
        case confidenceScore = "confidence_score"
    }

    init(
        taskText: String = "",
        summaryText: String = "",
        routeCandidateCount: Int = 0,
        agentCandidateCount: Int = 0,
        skillCandidateCount: Int = 0,
        readinessSignalCount: Int = 0,
        sessionReviewCount: Int = 0,
        providerCallCount: Int = 0,
        remediationItemCount: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        evidenceCount: Int = 0,
        safetyFlagCount: Int = 0,
        recommendedAgent: String? = nil,
        recommendedSkillName: String? = nil,
        readinessScore: Int? = nil,
        routingScore: Int? = nil
    ) {
        self.taskText = taskText
        self.summaryText = summaryText
        self.routeCandidateCount = routeCandidateCount
        self.agentCandidateCount = agentCandidateCount
        self.skillCandidateCount = skillCandidateCount
        self.readinessSignalCount = readinessSignalCount
        self.sessionReviewCount = sessionReviewCount
        self.providerCallCount = providerCallCount
        self.remediationItemCount = remediationItemCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.evidenceCount = evidenceCount
        self.safetyFlagCount = safetyFlagCount
        self.recommendedAgent = recommendedAgent
        self.recommendedSkillName = recommendedSkillName
        self.readinessScore = readinessScore
        self.routingScore = routingScore
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            taskText: try container.decodeFlexibleTaskCockpitString(keys: [.task, .taskText, .taskTextAlt, .userIntent]) ?? "",
            summaryText: try container.decodeFlexibleTaskCockpitString(keys: [.summary, .message, .text]) ?? "",
            routeCandidateCount: try container.decodeFlexibleTaskCockpitInt(keys: [.routeCandidateCount, .routeCandidateCountAlt, .routeCount, .routes]) ?? 0,
            agentCandidateCount: try container.decodeFlexibleTaskCockpitInt(keys: [.agentCandidateCount, .agentCandidateCountAlt, .agentCount, .agents]) ?? 0,
            skillCandidateCount: try container.decodeFlexibleTaskCockpitInt(keys: [.skillCandidateCount, .skillCandidateCountAlt, .candidateSkillCount, .candidateCount, .skills]) ?? 0,
            readinessSignalCount: try container.decodeFlexibleTaskCockpitInt(keys: [.readinessSignalCount, .readinessSignalCountAlt, .readinessSignals]) ?? 0,
            sessionReviewCount: try container.decodeFlexibleTaskCockpitInt(keys: [.sessionReviewCount, .sessionReviewCountAlt, .sessionReviews]) ?? 0,
            providerCallCount: try container.decodeFlexibleTaskCockpitInt(keys: [.providerCallCount, .providerCallCountAlt, .providerObservabilityRowCount, .providerCalls]) ?? 0,
            remediationItemCount: try container.decodeFlexibleTaskCockpitInt(keys: [.remediationItemCount, .remediationItemCountAlt, .remediationNextStepCount, .remediationItems]) ?? 0,
            gapCount: try container.decodeFlexibleTaskCockpitInt(keys: [.gapCount, .gaps]) ?? 0,
            blockerCount: try container.decodeFlexibleTaskCockpitInt(keys: [.blockerCount, .blockers]) ?? 0,
            evidenceCount: try container.decodeFlexibleTaskCockpitInt(keys: [.evidenceCount, .evidence, .evidenceReferences]) ?? 0,
            safetyFlagCount: try container.decodeFlexibleTaskCockpitInt(keys: [.safetyFlagCount, .safetyFlags]) ?? 0,
            recommendedAgent: try container.decodeFlexibleTaskCockpitString(keys: [.recommendedAgent, .recommendedAgentAlt]),
            recommendedSkillName: try container.decodeFlexibleTaskCockpitString(keys: [.recommendedSkillName, .recommendedSkillNameAlt, .topSkillName]),
            readinessScore: try container.decodeFlexibleTaskCockpitInt(keys: [.readinessScore, .readinessScoreAlt]),
            routingScore: try container.decodeFlexibleTaskCockpitInt(keys: [.routingScore, .routingScoreAlt, .routingConfidenceScore, .routingConfidenceScoreAlt, .confidenceScore])
        )
    }
}

struct TaskCockpitCandidateRow: Decodable, Hashable, Identifiable {
    let id: String
    let rank: Int?
    let title: String
    let agent: String?
    let skill: TaskBenchmarkSkillRef?
    let readinessScore: Int?
    let routingScore: Int?
    let score: Int?
    let band: String?
    let status: String?
    let summary: String
    let reasons: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case routeID = "route_id"
        case agentID = "agent_id"
        case skillID = "skill_id"
        case instanceID = "instance_id"
        case rank
        case position
        case title
        case name
        case label
        case task
        case displayName = "display_name"
        case displayNameAlt = "displayName"
        case skillName = "skill_name"
        case skillNameAlt = "skillName"
        case bestSkillName = "best_skill_name"
        case bestSkillNameAlt = "bestSkillName"
        case definitionID = "definition_id"
        case definitionIDAlt = "definitionId"
        case agent
        case skill
        case candidateSkill = "candidate_skill"
        case route
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case routingScore = "routing_score"
        case routingScoreAlt = "routingScore"
        case routingConfidenceScore = "routing_confidence_score"
        case routingConfidenceScoreAlt = "routingConfidenceScore"
        case confidenceScore = "confidence_score"
        case comparisonScore = "comparison_score"
        case comparisonScoreAlt = "comparisonScore"
        case qualityScore = "quality_score"
        case qualityScoreAlt = "qualityScore"
        case score
        case value
        case band
        case readinessBand = "readiness_band"
        case routingConfidenceBand = "routing_confidence_band"
        case routingConfidenceBandAlt = "routingConfidenceBand"
        case confidenceBand = "confidence_band"
        case status
        case state
        case enabled
        case scope
        case summary
        case detail
        case rationale
        case reasons
        case reason
        case matchReasons = "match_reasons"
        case blockerNotes = "blocker_notes"
        case gapNotes = "gap_notes"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case flags
    }

    init(
        id: String,
        rank: Int? = nil,
        title: String,
        agent: String? = nil,
        skill: TaskBenchmarkSkillRef? = nil,
        readinessScore: Int? = nil,
        routingScore: Int? = nil,
        score: Int? = nil,
        band: String? = nil,
        status: String? = nil,
        summary: String = "",
        reasons: [String] = [],
        evidenceRefs: [String] = [],
        safetyFlags: [String] = []
    ) {
        self.id = id
        self.rank = rank
        self.title = title
        self.agent = agent
        self.skill = skill
        self.readinessScore = readinessScore
        self.routingScore = routingScore
        self.score = score
        self.band = band
        self.status = status
        self.summary = summary
        self.reasons = reasons
        self.evidenceRefs = evidenceRefs
        self.safetyFlags = safetyFlags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(id: value, title: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let topLevelSkillName = try container.decodeFlexibleTaskCockpitString(keys: [.skillName, .skillNameAlt, .bestSkillName, .bestSkillNameAlt])
        let topLevelInstanceID = try container.decodeFlexibleTaskCockpitString(keys: [.instanceID, .skillID])
        let decodedAgent = try container.decodeFlexibleTaskCockpitString(keys: [.agent])
        let topLevelDefinitionID = try container.decodeFlexibleTaskCockpitString(keys: [.definitionID, .definitionIDAlt])
        let topLevelSkill = topLevelSkillName.map {
            TaskBenchmarkSkillRef(
                instanceID: topLevelInstanceID,
                name: $0,
                agent: decodedAgent ?? UIStrings.unknown,
                definitionID: topLevelDefinitionID
            )
        }
        let decodedSkill = try container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .skill)
            ?? container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .candidateSkill)
            ?? container.decodeIfPresent(TaskBenchmarkSkillRef.self, forKey: .route)
            ?? topLevelSkill
        let decodedTitle = try container.decodeFlexibleTaskCockpitString(keys: [.title, .name, .label, .task, .skillName, .skillNameAlt, .bestSkillName, .bestSkillNameAlt, .displayName, .displayNameAlt])
            ?? decodedSkill?.name
            ?? UIStrings.unknown
        let rowAgent = decodedAgent ?? decodedSkill?.agent
        self.init(
            id: try container.decodeFlexibleTaskCockpitString(keys: [.id, .routeID, .agentID, .skillID, .instanceID]) ?? "\(decodedAgent ?? "candidate")-\(decodedTitle)",
            rank: try container.decodeFlexibleTaskCockpitInt(keys: [.rank, .position]),
            title: decodedTitle,
            agent: rowAgent,
            skill: decodedSkill,
            readinessScore: try container.decodeFlexibleTaskCockpitInt(keys: [.readinessScore, .readinessScoreAlt]),
            routingScore: try container.decodeFlexibleTaskCockpitInt(keys: [.routingScore, .routingScoreAlt, .routingConfidenceScore, .routingConfidenceScoreAlt, .confidenceScore]),
            score: try container.decodeFlexibleTaskCockpitInt(keys: [.score, .value, .comparisonScore, .comparisonScoreAlt, .qualityScore, .qualityScoreAlt]),
            band: try container.decodeFlexibleTaskCockpitString(keys: [.band, .readinessBand, .routingConfidenceBand, .routingConfidenceBandAlt, .confidenceBand]),
            status: try container.decodeFlexibleTaskCockpitString(keys: [.status, .state, .enabled]),
            summary: try container.decodeFlexibleTaskCockpitString(keys: [.summary, .detail, .rationale, .scope]) ?? "",
            reasons: try container.decodeFlexibleTaskCockpitStringArray(keys: [.reasons, .reason, .matchReasons]),
            evidenceRefs: try container.decodeFlexibleTaskCockpitStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence]),
            safetyFlags: try container.decodeFlexibleTaskCockpitStringArray(keys: [.safetyFlags, .safetyFlagsAlt, .flags, .blockerNotes, .gapNotes])
        )
    }
}

struct TaskCockpitContextRow: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let status: String?
    let severity: String?
    let source: String?
    let agent: String?
    let count: Int?
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case rowID = "row_id"
        case title
        case name
        case label
        case task
        case detail
        case summary
        case message
        case suggestedSafeNextAction = "suggested_safe_next_action"
        case suggestedSafeNextActionAlt = "suggestedSafeNextAction"
        case status
        case outcome
        case severity
        case priority
        case source
        case sourceMethod = "source_method"
        case rowType = "row_type"
        case agent
        case count
        case total
        case rowCount = "row_count"
        case rowCountAlt = "rowCount"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case flags
    }

    init(
        id: String,
        title: String,
        detail: String = "",
        status: String? = nil,
        severity: String? = nil,
        source: String? = nil,
        agent: String? = nil,
        count: Int? = nil,
        evidenceRefs: [String] = [],
        safetyFlags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.severity = severity
        self.source = source
        self.agent = agent
        self.count = count
        self.evidenceRefs = evidenceRefs
        self.safetyFlags = safetyFlags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(id: value, title: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTitle = try container.decodeFlexibleTaskCockpitString(keys: [.title, .name, .label, .task]) ?? UIStrings.unknown
        self.init(
            id: try container.decodeFlexibleTaskCockpitString(keys: [.id, .rowID]) ?? decodedTitle,
            title: decodedTitle,
            detail: try container.decodeFlexibleTaskCockpitString(keys: [.detail, .summary, .message, .suggestedSafeNextAction, .suggestedSafeNextActionAlt]) ?? "",
            status: try container.decodeFlexibleTaskCockpitString(keys: [.status, .outcome]),
            severity: try container.decodeFlexibleTaskCockpitString(keys: [.severity, .priority]),
            source: try container.decodeFlexibleTaskCockpitString(keys: [.source, .sourceMethod, .rowType]),
            agent: try container.decodeFlexibleTaskCockpitString(keys: [.agent]),
            count: try container.decodeFlexibleTaskCockpitInt(keys: [.count, .total, .rowCount, .rowCountAlt]),
            evidenceRefs: try container.decodeFlexibleTaskCockpitStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence]),
            safetyFlags: try container.decodeFlexibleTaskCockpitStringArray(keys: [.safetyFlags, .safetyFlagsAlt, .flags])
        )
    }
}

struct TaskCockpitResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: TaskCockpitFilters
    let summary: TaskCockpitSummary
    let cockpitSections: [TaskCockpitContextRow]
    let taskRows: [TaskCockpitCandidateRow]
    let routeCandidates: [TaskCockpitCandidateRow]
    let agentCandidates: [TaskCockpitCandidateRow]
    let skillCandidates: [TaskCockpitCandidateRow]
    let readinessSignals: [TaskCockpitContextRow]
    let sessionReviewContext: [TaskCockpitContextRow]
    let providerObservabilityContext: [TaskCockpitContextRow]
    let remediationContext: [TaskCockpitContextRow]
    let gapRows: [TaskCockpitContextRow]
    let blockerRows: [TaskCockpitContextRow]
    let evidenceReferences: [ProviderObservabilityEvidenceReference]
    let promptRequest: ProviderObservabilityPromptRequest?
    let aggregation: TaskCockpitAggregation?
    let safetyFlags: ProviderObservabilitySafety
    let fallbackReason: String?

    var isUnavailable: Bool {
        generatedBy == "unavailable" || fallbackReason != nil && routeCandidates.isEmpty && agentCandidates.isEmpty && skillCandidates.isEmpty
    }

    var recoveryDiagnosticReason: String? {
        if let fallbackReason, !fallbackReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallbackReason
        }
        if !catalogAvailable {
            return UIStrings.taskCockpitCatalogUnavailableDiagnostic
        }
        if hasNoReturnedRows {
            return UIStrings.taskCockpitPartialNoRows
        }
        return nil
    }

    private var hasNoReturnedRows: Bool {
        routeCandidates.isEmpty
            && agentCandidates.isEmpty
            && skillCandidates.isEmpty
            && readinessSignals.isEmpty
            && sessionReviewContext.isEmpty
            && providerObservabilityContext.isEmpty
            && remediationContext.isEmpty
            && gapRows.isEmpty
            && blockerRows.isEmpty
            && evidenceReferences.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case taskSummary = "task_summary"
        case cockpitSections = "cockpit_sections"
        case cockpitSectionsAlt = "cockpitSections"
        case sections
        case taskRows = "task_rows"
        case taskRowsAlt = "taskRows"
        case routeCandidates = "route_candidates"
        case routeCandidatesAlt = "routeCandidates"
        case routes
        case candidateRoutes = "candidate_routes"
        case agentCandidates = "agent_candidates"
        case agentCandidatesAlt = "agentCandidates"
        case agentRows = "agent_rows"
        case agentRouteRows = "agent_route_rows"
        case agents
        case skillCandidates = "skill_candidates"
        case skillCandidatesAlt = "skillCandidates"
        case skillCandidateRows = "skill_candidate_rows"
        case candidateSkills = "candidate_skills"
        case skills
        case readinessSignals = "readiness_signals"
        case readinessSignalsAlt = "readinessSignals"
        case readinessRows = "readiness_rows"
        case readiness
        case signals
        case sessionReviewContext = "session_review_context"
        case sessionReviewContextAlt = "sessionReviewContext"
        case sessionReviewRows = "session_review_rows"
        case sessionReviews = "session_reviews"
        case providerObservabilityContext = "provider_observability_context"
        case providerObservabilityContextAlt = "providerObservabilityContext"
        case providerRows = "provider_rows"
        case providerObservabilityRows = "provider_observability_rows"
        case remediationContext = "remediation_context"
        case remediationContextAlt = "remediationContext"
        case remediationRows = "remediation_rows"
        case remediationNextSteps = "remediation_next_steps"
        case remediationItems = "remediation_items"
        case gapRows = "gap_rows"
        case gapNotes = "gap_notes"
        case gaps
        case blockerRows = "blocker_rows"
        case blockerNotes = "blocker_notes"
        case blockers
        case evidenceReferences = "evidence_references"
        case evidenceReferencesAlt = "evidenceReferences"
        case evidence
        case promptRequest = "prompt_request"
        case promptRequestAlt = "promptRequest"
        case aggregation
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case safety
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(
        generatedBy: String = "local-v2.73",
        catalogAvailable: Bool = true,
        filters: TaskCockpitFilters = TaskCockpitFilters(),
        summary: TaskCockpitSummary = TaskCockpitSummary(),
        cockpitSections: [TaskCockpitContextRow] = [],
        taskRows: [TaskCockpitCandidateRow] = [],
        routeCandidates: [TaskCockpitCandidateRow] = [],
        agentCandidates: [TaskCockpitCandidateRow] = [],
        skillCandidates: [TaskCockpitCandidateRow] = [],
        readinessSignals: [TaskCockpitContextRow] = [],
        sessionReviewContext: [TaskCockpitContextRow] = [],
        providerObservabilityContext: [TaskCockpitContextRow] = [],
        remediationContext: [TaskCockpitContextRow] = [],
        gapRows: [TaskCockpitContextRow] = [],
        blockerRows: [TaskCockpitContextRow] = [],
        evidenceReferences: [ProviderObservabilityEvidenceReference] = [],
        promptRequest: ProviderObservabilityPromptRequest? = nil,
        aggregation: TaskCockpitAggregation? = nil,
        safetyFlags: ProviderObservabilitySafety = ProviderObservabilitySafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.cockpitSections = cockpitSections
        self.taskRows = taskRows
        self.routeCandidates = routeCandidates
        self.agentCandidates = agentCandidates
        self.skillCandidates = skillCandidates
        self.readinessSignals = readinessSignals
        self.sessionReviewContext = sessionReviewContext
        self.providerObservabilityContext = providerObservabilityContext
        self.remediationContext = remediationContext
        self.gapRows = gapRows
        self.blockerRows = blockerRows
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.aggregation = aggregation
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            generatedBy: try container.decodeFlexibleTaskCockpitString(keys: [.generatedBy, .generatedByAlt]) ?? "local-v2.73",
            catalogAvailable: try container.decodeFlexibleTaskCockpitBool(keys: [.catalogAvailable, .catalogAvailableAlt]) ?? true,
            filters: try container.decodeIfPresent(TaskCockpitFilters.self, forKey: .filters) ?? TaskCockpitFilters(),
            summary: try container.decodeIfPresent(TaskCockpitSummary.self, forKey: .summary)
                ?? container.decodeIfPresent(TaskCockpitSummary.self, forKey: .taskSummary)
                ?? TaskCockpitSummary(),
            cockpitSections: try container.decodeFlexibleTaskCockpitContextRows(keys: [.cockpitSections, .cockpitSectionsAlt, .sections]),
            taskRows: try container.decodeFlexibleTaskCockpitRows(keys: [.taskRows, .taskRowsAlt]),
            routeCandidates: try container.decodeFlexibleTaskCockpitRows(keys: [.routeCandidates, .routeCandidatesAlt, .routes, .candidateRoutes]),
            agentCandidates: try container.decodeFlexibleTaskCockpitRows(keys: [.agentCandidates, .agentCandidatesAlt, .agentRows, .agentRouteRows, .agents]),
            skillCandidates: try container.decodeFlexibleTaskCockpitRows(keys: [.skillCandidates, .skillCandidatesAlt, .skillCandidateRows, .candidateSkills, .skills]),
            readinessSignals: try container.decodeFlexibleTaskCockpitContextRows(keys: [.readinessSignals, .readinessSignalsAlt, .readinessRows, .readiness, .signals]),
            sessionReviewContext: try container.decodeFlexibleTaskCockpitContextRows(keys: [.sessionReviewContext, .sessionReviewContextAlt, .sessionReviewRows, .sessionReviews]),
            providerObservabilityContext: try container.decodeFlexibleTaskCockpitContextRows(keys: [.providerObservabilityContext, .providerObservabilityContextAlt, .providerRows, .providerObservabilityRows]),
            remediationContext: try container.decodeFlexibleTaskCockpitContextRows(keys: [.remediationContext, .remediationContextAlt, .remediationRows, .remediationNextSteps, .remediationItems]),
            gapRows: try container.decodeFlexibleTaskCockpitContextRows(keys: [.gapRows, .gapNotes, .gaps]),
            blockerRows: try container.decodeFlexibleTaskCockpitContextRows(keys: [.blockerRows, .blockerNotes, .blockers]),
            evidenceReferences: try container.decodeFlexibleTaskCockpitEvidence(keys: [.evidenceReferences, .evidenceReferencesAlt, .evidence]),
            promptRequest: try container.decodeIfPresent(ProviderObservabilityPromptRequest.self, forKey: .promptRequest)
                ?? container.decodeIfPresent(ProviderObservabilityPromptRequest.self, forKey: .promptRequestAlt),
            aggregation: try container.decodeIfPresent(TaskCockpitAggregation.self, forKey: .aggregation),
            safetyFlags: try container.decodeIfPresent(ProviderObservabilitySafety.self, forKey: .safetyFlags)
                ?? container.decodeIfPresent(ProviderObservabilitySafety.self, forKey: .safetyFlagsAlt)
                ?? container.decodeIfPresent(ProviderObservabilitySafety.self, forKey: .safety)
                ?? ProviderObservabilitySafety(),
            fallbackReason: try container.decodeFlexibleTaskCockpitString(keys: [.fallbackReason, .reason])
        )
    }

    static func unavailable(taskText: String = "", reason: String = UIStrings.taskCockpitUnavailable) -> TaskCockpitResult {
        TaskCockpitResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            filters: TaskCockpitFilters(taskText: taskText),
            summary: TaskCockpitSummary(taskText: taskText, summaryText: reason),
            safetyFlags: ProviderObservabilitySafety(notes: [reason]),
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleTaskCockpitString(keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return "\(value)"
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return "\(value)"
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value ? UIStrings.stateEnabled : UIStrings.stateDisabled
            }
        }
        return nil
    }

    func decodeFlexibleTaskCockpitInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let intValue = Int(trimmed) {
                    return intValue
                }
                if let doubleValue = Double(trimmed) {
                    return Int(doubleValue.rounded())
                }
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([TaskCockpitCandidateRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([TaskCockpitContextRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([ProviderObservabilityEvidenceReference].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleTaskCockpitBool(keys: [Key]) throws -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1", "enabled", "available":
                    return true
                case "false", "no", "0", "disabled", "unavailable":
                    return false
                default:
                    continue
                }
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
        }
        return nil
    }

    func decodeFlexibleTaskCockpitStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([ProviderObservabilityEvidenceReference].self, forKey: key) {
                return values.map { item in
                    if !item.detail.isEmpty { return item.detail }
                    if let source = item.source, !source.isEmpty { return source }
                    return item.title
                }
            }
            if let values = try? decodeIfPresent([TaskCockpitContextRow].self, forKey: key) {
                return values.map(\.title)
            }
        }
        return []
    }

    func decodeFlexibleTaskCockpitRows(keys: [Key]) throws -> [TaskCockpitCandidateRow] {
        for key in keys {
            if let values = try? decodeIfPresent([TaskCockpitCandidateRow].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(TaskCockpitCandidateRow.self, forKey: key) {
                return [value]
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map { TaskCockpitCandidateRow(id: $0, title: $0) }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [TaskCockpitCandidateRow(id: value, title: value)]
            }
        }
        return []
    }

    func decodeFlexibleTaskCockpitContextRows(keys: [Key]) throws -> [TaskCockpitContextRow] {
        for key in keys {
            if let values = try? decodeIfPresent([TaskCockpitContextRow].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(TaskCockpitContextRow.self, forKey: key) {
                return [value]
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map { TaskCockpitContextRow(id: $0, title: $0) }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [TaskCockpitContextRow(id: value, title: value)]
            }
        }
        return []
    }

    func decodeFlexibleTaskCockpitEvidence(keys: [Key]) throws -> [ProviderObservabilityEvidenceReference] {
        for key in keys {
            if let values = try? decodeIfPresent([ProviderObservabilityEvidenceReference].self, forKey: key) {
                return values
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.map { ProviderObservabilityEvidenceReference(title: $0, detail: $0, source: nil) }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return [ProviderObservabilityEvidenceReference(title: value, detail: value, source: nil)]
            }
        }
        return []
    }
}
