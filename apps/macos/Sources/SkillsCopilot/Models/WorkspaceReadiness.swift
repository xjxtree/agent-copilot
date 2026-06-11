import Foundation

struct WorkspaceReadinessFilters: Decodable, Hashable {
    let taskText: String?
    let agent: String?
    let agents: [String]
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
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
        case limit
    }

    init(
        taskText: String? = nil,
        agent: String? = nil,
        agents: [String] = [],
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        limit: Int? = nil
    ) {
        self.taskText = taskText
        self.agent = agent
        self.agents = agents
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.limit = limit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleWorkspaceStringArray(keys: [.agents, .agent])
        projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot)
            ?? container.decodeIfPresent(String.self, forKey: .projectRootAlt)
        currentCWD = try container.decodeIfPresent(String.self, forKey: .currentCWD)
            ?? container.decodeIfPresent(String.self, forKey: .currentCWDAlt)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
            ?? container.decodeIfPresent(String.self, forKey: .workspaceID)
        limit = try container.decodeFlexibleWorkspaceInt(keys: [.limit])
    }
}

struct WorkspaceReadinessSummary: Decodable, Hashable {
    let overallState: String
    let readinessScore: Int?
    let checklistCount: Int
    let readyCount: Int
    let partialCount: Int
    let blockedCount: Int
    let agentCount: Int
    let capabilityCount: Int
    let gapCount: Int
    let blockerCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case overallState = "overall_state"
        case overallStateAlt = "overallState"
        case state
        case status
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case score
        case checklistCount = "checklist_count"
        case readinessRowCount = "readiness_row_count"
        case checks
        case checklist
        case readyCount = "ready_count"
        case ready
        case partialCount = "partial_count"
        case partial
        case blockedCount = "blocked_count"
        case blockers
        case blocked
        case agentCount = "agent_count"
        case agents
        case capabilityCount = "capability_count"
        case capabilities
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case summary
        case message
        case text
    }

    init(
        overallState: String = UIStrings.unknown,
        readinessScore: Int? = nil,
        checklistCount: Int = 0,
        readyCount: Int = 0,
        partialCount: Int = 0,
        blockedCount: Int = 0,
        agentCount: Int = 0,
        capabilityCount: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        summaryText: String = ""
    ) {
        self.overallState = overallState
        self.readinessScore = readinessScore
        self.checklistCount = checklistCount
        self.readyCount = readyCount
        self.partialCount = partialCount
        self.blockedCount = blockedCount
        self.agentCount = agentCount
        self.capabilityCount = capabilityCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            overallState: try container.decodeIfPresent(String.self, forKey: .overallState)
            ?? container.decodeIfPresent(String.self, forKey: .overallStateAlt)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? UIStrings.unknown,
            readinessScore: try container.decodeFlexibleWorkspaceInt(keys: [.readinessScore, .readinessScoreAlt, .score]),
            checklistCount: try container.decodeFlexibleWorkspaceInt(keys: [.checklistCount, .readinessRowCount, .checks, .checklist]) ?? 0,
            readyCount: try container.decodeFlexibleWorkspaceInt(keys: [.readyCount, .ready]) ?? 0,
            partialCount: try container.decodeFlexibleWorkspaceInt(keys: [.partialCount, .partial]) ?? 0,
            blockedCount: try container.decodeFlexibleWorkspaceInt(keys: [.blockedCount, .blocked]) ?? 0,
            agentCount: try container.decodeFlexibleWorkspaceInt(keys: [.agentCount, .agents]) ?? 0,
            capabilityCount: try container.decodeFlexibleWorkspaceInt(keys: [.capabilityCount, .capabilities]) ?? 0,
            gapCount: try container.decodeFlexibleWorkspaceInt(keys: [.gapCount, .gaps]) ?? 0,
            blockerCount: try container.decodeFlexibleWorkspaceInt(keys: [.blockerCount, .blockers]) ?? 0,
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

struct WorkspaceReadinessChecklistRow: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let status: String
    let severity: String?
    let agent: String?
    let capability: String?
    let summary: String
    let requiredSkills: [String]
    let matchedSkills: [CapabilityTaxonomySkill]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case checkID = "check_id"
        case checkId = "checkId"
        case title
        case label
        case name
        case status
        case state
        case readinessState = "readiness_state"
        case severity
        case agent
        case capability
        case capabilityName = "capability_name"
        case domain
        case summary
        case detail
        case message
        case requiredSkills = "required_skills"
        case expectedSkills = "expected_skills"
        case matchedSkills = "matched_skills"
        case skills
        case candidateSkills = "candidate_skills"
        case gapNotes = "gap_notes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockers
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case safetyFlags = "safety_flags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            status = UIStrings.unknown
            severity = nil
            agent = nil
            capability = nil
            summary = value
            requiredSkills = []
            matchedSkills = []
            gapNotes = []
            blockerNotes = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.workspaceReadinessChecklistItem
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? container.decodeIfPresent(String.self, forKey: .readinessState)
            ?? UIStrings.unknown
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        capability = try container.decodeIfPresent(String.self, forKey: .capability)
            ?? container.decodeIfPresent(String.self, forKey: .capabilityName)
            ?? container.decodeIfPresent(String.self, forKey: .domain)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
        requiredSkills = try container.decodeFlexibleWorkspaceStringArray(keys: [.requiredSkills, .expectedSkills])
        matchedSkills = try container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .matchedSkills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .skills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .candidateSkills)
            ?? []
        gapNotes = try container.decodeFlexibleWorkspaceStringArray(keys: [.gapNotes, .gaps])
        blockerNotes = try container.decodeFlexibleWorkspaceStringArray(keys: [.blockerNotes, .blockers])
        evidenceRefs = try container.decodeFlexibleWorkspaceStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleWorkspaceStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .checkID)
            ?? container.decodeIfPresent(String.self, forKey: .checkId)
            ?? "\(agent ?? "")-\(capability ?? "")-\(title)"
    }
}

struct WorkspaceReadinessAgentRow: Decodable, Hashable, Identifiable {
    let id: String
    let agent: String
    let displayName: String?
    let readinessScore: Int?
    let readinessState: String
    let enabledSkillCount: Int
    let requiredSkillCount: Int
    let matchedSkillCount: Int
    let gapCount: Int
    let blockerCount: Int
    let notes: [String]
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case agent
        case name
        case displayName = "display_name"
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case score
        case readinessState = "readiness_state"
        case status
        case state
        case band
        case enabledSkillCount = "enabled_skill_count"
        case enabledSkills = "enabled_skills"
        case requiredSkillCount = "required_skill_count"
        case requiredSkills = "required_skills"
        case matchedSkillCount = "matched_skill_count"
        case matchedSkills = "matched_skills"
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case notes
        case note
        case reasons
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        readinessScore = try container.decodeFlexibleWorkspaceInt(keys: [.readinessScore, .readinessScoreAlt, .score])
        readinessState = try container.decodeIfPresent(String.self, forKey: .readinessState)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? container.decodeIfPresent(String.self, forKey: .band)
            ?? UIStrings.unknown
        enabledSkillCount = try container.decodeFlexibleWorkspaceInt(keys: [.enabledSkillCount, .enabledSkills]) ?? 0
        requiredSkillCount = try container.decodeFlexibleWorkspaceInt(keys: [.requiredSkillCount, .requiredSkills]) ?? 0
        matchedSkillCount = try container.decodeFlexibleWorkspaceInt(keys: [.matchedSkillCount, .matchedSkills]) ?? 0
        gapCount = try container.decodeFlexibleWorkspaceInt(keys: [.gapCount, .gaps]) ?? 0
        blockerCount = try container.decodeFlexibleWorkspaceInt(keys: [.blockerCount, .blockers]) ?? 0
        notes = try container.decodeFlexibleWorkspaceStringArray(keys: [.notes, .note, .reasons])
        evidenceRefs = try container.decodeFlexibleWorkspaceStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? agent
    }
}

struct WorkspaceReadinessCapabilityRow: Decodable, Hashable, Identifiable {
    let id: String
    let domain: String
    let capability: String
    let readinessState: String
    let readinessScore: Int?
    let agentCoverage: [CapabilityTaxonomyCoverage]
    let representativeSkills: [CapabilityTaxonomySkill]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case capabilityID = "capability_id"
        case capabilityId = "capabilityId"
        case domain
        case domainName = "domain_name"
        case domainKey = "domain_key"
        case capability
        case capabilityName = "capability_name"
        case name
        case title
        case readinessState = "readiness_state"
        case coverageState = "coverage_state"
        case status
        case state
        case readinessScore = "readiness_score"
        case readinessScoreAlt = "readinessScore"
        case score
        case agentCoverage = "agent_coverage"
        case coverageByAgent = "coverage_by_agent"
        case coverage
        case agents
        case representativeSkills = "representative_skills"
        case matchedSkills = "matched_skills"
        case skills
        case gapNotes = "gap_notes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockers
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
            ?? container.decodeIfPresent(String.self, forKey: .domainName)
            ?? container.decodeIfPresent(String.self, forKey: .domainKey)
            ?? UIStrings.capabilityTaxonomyDomain
        capability = try container.decodeIfPresent(String.self, forKey: .capability)
            ?? container.decodeIfPresent(String.self, forKey: .capabilityName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? UIStrings.capabilityTaxonomyCapability
        readinessState = try container.decodeIfPresent(String.self, forKey: .readinessState)
            ?? container.decodeIfPresent(String.self, forKey: .coverageState)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? UIStrings.unknown
        readinessScore = try container.decodeFlexibleWorkspaceInt(keys: [.readinessScore, .readinessScoreAlt, .score])
        agentCoverage = try container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .agentCoverage)
            ?? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverageByAgent)
            ?? container.decodeIfPresent([CapabilityTaxonomyCoverage].self, forKey: .coverage)
            ?? []
        representativeSkills = try container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .representativeSkills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .matchedSkills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .skills)
            ?? []
        gapNotes = try container.decodeFlexibleWorkspaceStringArray(keys: [.gapNotes, .gaps])
        blockerNotes = try container.decodeFlexibleWorkspaceStringArray(keys: [.blockerNotes, .blockers])
        evidenceRefs = try container.decodeFlexibleWorkspaceStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .capabilityID)
            ?? container.decodeIfPresent(String.self, forKey: .capabilityId)
            ?? "\(domain)-\(capability)"
    }
}

typealias WorkspaceReadinessEvidenceReference = CrossAgentReadinessEvidenceReference
typealias WorkspaceReadinessSafety = CrossAgentReadinessSafety

struct WorkspaceReadinessResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: WorkspaceReadinessFilters
    let summary: WorkspaceReadinessSummary
    let checklistRows: [WorkspaceReadinessChecklistRow]
    let agentRows: [WorkspaceReadinessAgentRow]
    let capabilityRows: [WorkspaceReadinessCapabilityRow]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [WorkspaceReadinessEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: WorkspaceReadinessSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case checklistRows = "checklist_rows"
        case checklistRowsAlt = "checklistRows"
        case readinessRows = "readiness_rows"
        case readinessRowsAlt = "readinessRows"
        case checklist
        case checks
        case rows
        case agentRows = "agent_rows"
        case agentRowsAlt = "agentRows"
        case agents
        case capabilityRows = "capability_rows"
        case capabilityRowsAlt = "capabilityRows"
        case capabilities
        case domains
        case coverageRows = "coverage_rows"
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
        filters: WorkspaceReadinessFilters = WorkspaceReadinessFilters(),
        summary: WorkspaceReadinessSummary = WorkspaceReadinessSummary(),
        checklistRows: [WorkspaceReadinessChecklistRow] = [],
        agentRows: [WorkspaceReadinessAgentRow] = [],
        capabilityRows: [WorkspaceReadinessCapabilityRow] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [WorkspaceReadinessEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: WorkspaceReadinessSafety = WorkspaceReadinessSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.checklistRows = checklistRows
        self.agentRows = agentRows
        self.capabilityRows = capabilityRows
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
        filters = try container.decodeIfPresent(WorkspaceReadinessFilters.self, forKey: .filters) ?? WorkspaceReadinessFilters()
        checklistRows = try container.decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: .checklistRows)
            ?? container.decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: .checklistRowsAlt)
            ?? container.decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: .readinessRows)
            ?? container.decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: .readinessRowsAlt)
            ?? container.decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: .checklist)
            ?? container.decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: .checks)
            ?? container.decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: .rows)
            ?? []
        agentRows = try container.decodeIfPresent([WorkspaceReadinessAgentRow].self, forKey: .agentRows)
            ?? container.decodeIfPresent([WorkspaceReadinessAgentRow].self, forKey: .agentRowsAlt)
            ?? container.decodeIfPresent([WorkspaceReadinessAgentRow].self, forKey: .agents)
            ?? []
        capabilityRows = try container.decodeIfPresent([WorkspaceReadinessCapabilityRow].self, forKey: .capabilityRows)
            ?? container.decodeIfPresent([WorkspaceReadinessCapabilityRow].self, forKey: .capabilityRowsAlt)
            ?? container.decodeIfPresent([WorkspaceReadinessCapabilityRow].self, forKey: .capabilities)
            ?? container.decodeIfPresent([WorkspaceReadinessCapabilityRow].self, forKey: .domains)
            ?? container.decodeIfPresent([WorkspaceReadinessCapabilityRow].self, forKey: .coverageRows)
            ?? []
        summary = try container.decodeIfPresent(WorkspaceReadinessSummary.self, forKey: .summary)
            ?? WorkspaceReadinessSummary(
                checklistCount: checklistRows.count,
                agentCount: agentRows.count,
                capabilityCount: capabilityRows.count
            )
        gapNotes = try container.decodeFlexibleWorkspaceStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleWorkspaceStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([WorkspaceReadinessEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([WorkspaceReadinessEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([WorkspaceReadinessEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(WorkspaceReadinessSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(WorkspaceReadinessSafety.self, forKey: .safety)
            ?? WorkspaceReadinessSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.workspaceReadinessUnavailable) -> WorkspaceReadinessResult {
        WorkspaceReadinessResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleWorkspaceInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([WorkspaceReadinessChecklistRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([WorkspaceReadinessAgentRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([WorkspaceReadinessCapabilityRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([CapabilityTaxonomySkill].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleWorkspaceStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([WorkspaceReadinessEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(WorkspaceReadinessEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
            if let values = try? decodeIfPresent([CapabilityTaxonomySkill].self, forKey: key) {
                return values.map(\.skillName)
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return [value ? UIStrings.stateEnabled : UIStrings.stateDisabled]
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return ["\(value)"]
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return [RoutingAccuracySummary.confidenceLabel(value)]
            }
        }
        return []
    }
}
