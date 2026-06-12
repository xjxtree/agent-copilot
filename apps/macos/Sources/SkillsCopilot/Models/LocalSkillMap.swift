import Foundation

struct LocalSkillMapFilters: Decodable, Hashable {
    let agent: String?
    let agents: [String]
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let task: String?
    let limit: Int?
    let nodeLimit: Int?
    let edgeLimit: Int?
    let clusterLimit: Int?
    let candidateInstanceIDs: [String]
    let includeEdges: Bool
    let includeClusters: Bool
    let includeTaskContext: Bool

    enum CodingKeys: String, CodingKey {
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
        case task
        case taskText = "task_text"
        case userIntent = "user_intent"
        case limit
        case nodeLimit = "node_limit"
        case nodeLimitAlt = "nodeLimit"
        case edgeLimit = "edge_limit"
        case edgeLimitAlt = "edgeLimit"
        case clusterLimit = "cluster_limit"
        case clusterLimitAlt = "clusterLimit"
        case candidateInstanceIDs = "candidate_instance_ids"
        case candidateInstanceIDsAlt = "candidateInstanceIDs"
        case instanceIDs = "instance_ids"
        case includeEdges = "include_edges"
        case includeEdgesAlt = "includeEdges"
        case edges
        case includeClusters = "include_clusters"
        case includeClustersAlt = "includeClusters"
        case clusters
        case includeTaskContext = "include_task_context"
        case includeTaskContextAlt = "includeTaskContext"
    }

    init(
        agent: String? = nil,
        agents: [String] = [],
        selectedSkillID: String? = nil,
        selectedSkillName: String? = nil,
        selectedSkillAgent: String? = nil,
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        task: String? = nil,
        limit: Int? = nil,
        nodeLimit: Int? = nil,
        edgeLimit: Int? = nil,
        clusterLimit: Int? = nil,
        candidateInstanceIDs: [String] = [],
        includeEdges: Bool = true,
        includeClusters: Bool = true,
        includeTaskContext: Bool = false
    ) {
        self.agent = agent
        self.agents = agents
        self.selectedSkillID = selectedSkillID
        self.selectedSkillName = selectedSkillName
        self.selectedSkillAgent = selectedSkillAgent
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.task = task
        self.limit = limit
        self.nodeLimit = nodeLimit
        self.edgeLimit = edgeLimit
        self.clusterLimit = clusterLimit
        self.candidateInstanceIDs = candidateInstanceIDs
        self.includeEdges = includeEdges
        self.includeClusters = includeClusters
        self.includeTaskContext = includeTaskContext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        agents = try container.decodeFlexibleLocalMapStringArray(keys: [.agents, .agent])
        selectedSkillID = try container.decodeIfPresent(String.self, forKey: .selectedSkillID)
            ?? container.decodeIfPresent(String.self, forKey: .selectedSkillIDAlt)
        selectedSkillName = try container.decodeIfPresent(String.self, forKey: .selectedSkillName)
            ?? container.decodeIfPresent(String.self, forKey: .selectedSkillNameAlt)
        selectedSkillAgent = try container.decodeIfPresent(String.self, forKey: .selectedSkillAgent)
            ?? container.decodeIfPresent(String.self, forKey: .selectedSkillAgentAlt)
        projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot)
            ?? container.decodeIfPresent(String.self, forKey: .projectRootAlt)
        currentCWD = try container.decodeIfPresent(String.self, forKey: .currentCWD)
            ?? container.decodeIfPresent(String.self, forKey: .currentCWDAlt)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
            ?? container.decodeIfPresent(String.self, forKey: .workspaceID)
        task = try container.decodeIfPresent(String.self, forKey: .task)
            ?? container.decodeIfPresent(String.self, forKey: .taskText)
            ?? container.decodeIfPresent(String.self, forKey: .userIntent)
        limit = try container.decodeFlexibleLocalMapInt(keys: [.limit])
        nodeLimit = try container.decodeFlexibleLocalMapInt(keys: [.nodeLimit, .nodeLimitAlt])
        edgeLimit = try container.decodeFlexibleLocalMapInt(keys: [.edgeLimit, .edgeLimitAlt])
        clusterLimit = try container.decodeFlexibleLocalMapInt(keys: [.clusterLimit, .clusterLimitAlt])
        candidateInstanceIDs = try container.decodeFlexibleLocalMapStringArray(keys: [.candidateInstanceIDs, .candidateInstanceIDsAlt, .instanceIDs])
        includeEdges = try container.decodeFlexibleLocalMapBool(keys: [.includeEdges, .includeEdgesAlt, .edges]) ?? true
        includeClusters = try container.decodeFlexibleLocalMapBool(keys: [.includeClusters, .includeClustersAlt, .clusters]) ?? true
        includeTaskContext = try container.decodeFlexibleLocalMapBool(keys: [.includeTaskContext, .includeTaskContextAlt]) ?? false
    }
}

struct LocalSkillMapSummary: Decodable, Hashable {
    let nodeCount: Int
    let edgeCount: Int
    let clusterCount: Int
    let domainCount: Int
    let skillCount: Int
    let agentCount: Int
    let gapCount: Int
    let blockerCount: Int
    let evidenceCount: Int
    let selectedSkillContext: String?
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case nodeCount = "node_count"
        case returnedNodeCount = "returned_node_count"
        case returnedNodeCountAlt = "returnedNodeCount"
        case nodes
        case edgeCount = "edge_count"
        case returnedEdgeCount = "returned_edge_count"
        case returnedEdgeCountAlt = "returnedEdgeCount"
        case edges
        case clusterCount = "cluster_count"
        case clusters
        case returnedClusterCount = "returned_cluster_count"
        case returnedClusterCountAlt = "returnedClusterCount"
        case domainCount = "domain_count"
        case domains
        case skillCount = "skill_count"
        case indexedSkillCount = "indexed_skill_count"
        case indexedSkillCountAlt = "indexedSkillCount"
        case candidateSkillCount = "candidate_skill_count"
        case candidateSkillCountAlt = "candidateSkillCount"
        case skillNodeCount = "skill_node_count"
        case skillNodeCountAlt = "skillNodeCount"
        case skills
        case agentCount = "agent_count"
        case agents
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case evidenceCount = "evidence_count"
        case evidence
        case evidenceReferences = "evidence_references"
        case selectedSkillContext = "selected_skill_context"
        case selectedSkillContextAlt = "selectedSkillContext"
        case selectedSkill = "selected_skill"
        case summary
        case message
        case text
    }

    init(
        nodeCount: Int = 0,
        edgeCount: Int = 0,
        clusterCount: Int = 0,
        domainCount: Int = 0,
        skillCount: Int = 0,
        agentCount: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        evidenceCount: Int = 0,
        selectedSkillContext: String? = nil,
        summaryText: String = ""
    ) {
        self.nodeCount = nodeCount
        self.edgeCount = edgeCount
        self.clusterCount = clusterCount
        self.domainCount = domainCount
        self.skillCount = skillCount
        self.agentCount = agentCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.evidenceCount = evidenceCount
        self.selectedSkillContext = selectedSkillContext
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            nodeCount: try container.decodeFlexibleLocalMapInt(keys: [.nodeCount, .returnedNodeCount, .returnedNodeCountAlt, .nodes]) ?? 0,
            edgeCount: try container.decodeFlexibleLocalMapInt(keys: [.edgeCount, .returnedEdgeCount, .returnedEdgeCountAlt, .edges]) ?? 0,
            clusterCount: try container.decodeFlexibleLocalMapInt(keys: [.clusterCount, .returnedClusterCount, .returnedClusterCountAlt, .clusters]) ?? 0,
            domainCount: try container.decodeFlexibleLocalMapInt(keys: [.domainCount, .domains]) ?? 0,
            skillCount: try container.decodeFlexibleLocalMapInt(keys: [.skillCount, .candidateSkillCount, .candidateSkillCountAlt, .skillNodeCount, .skillNodeCountAlt, .indexedSkillCount, .indexedSkillCountAlt, .skills]) ?? 0,
            agentCount: try container.decodeFlexibleLocalMapInt(keys: [.agentCount, .agents]) ?? 0,
            gapCount: try container.decodeFlexibleLocalMapInt(keys: [.gapCount, .gaps]) ?? 0,
            blockerCount: try container.decodeFlexibleLocalMapInt(keys: [.blockerCount, .blockers]) ?? 0,
            evidenceCount: try container.decodeFlexibleLocalMapInt(keys: [.evidenceCount, .evidence, .evidenceReferences]) ?? 0,
            selectedSkillContext: try container.decodeIfPresent(String.self, forKey: .selectedSkillContext)
                ?? container.decodeIfPresent(String.self, forKey: .selectedSkillContextAlt)
                ?? (try? container.decodeIfPresent(String.self, forKey: .selectedSkill)),
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

struct LocalSkillMapNode: Decodable, Hashable, Identifiable {
    let id: String
    let nodeID: String
    let label: String
    let kind: String
    let summary: String
    let instanceID: String?
    let definitionID: String?
    let skillName: String?
    let agent: String?
    let scope: String?
    let enabled: Bool?
    let state: String?
    let domain: String?
    let clusterID: String?
    let riskLevel: String?
    let weight: Double?
    let tags: [String]
    let reasons: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case nodeID = "node_id"
        case nodeIDAlt = "nodeId"
        case label
        case name
        case title
        case kind
        case nodeType = "node_type"
        case nodeTypeAlt = "nodeType"
        case type
        case category
        case summary
        case description
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case skillID = "skill_id"
        case skillId = "skillId"
        case definitionID = "definition_id"
        case definitionId = "definitionId"
        case skillName = "skill_name"
        case skillNameAlt = "skillName"
        case agent
        case scope
        case enabled
        case state
        case status
        case domain
        case domainName = "domain_name"
        case clusterID = "cluster_id"
        case clusterIDAlt = "clusterId"
        case cluster
        case riskLevel = "risk_level"
        case riskLevelAlt = "riskLevel"
        case weight
        case score
        case centrality
        case tags
        case tag
        case reasons
        case reason
        case matchReasons = "match_reasons"
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
            nodeID = value
            label = value
            kind = "skill"
            summary = ""
            instanceID = nil
            definitionID = nil
            skillName = value
            agent = nil
            scope = nil
            enabled = nil
            state = nil
            domain = nil
            clusterID = nil
            riskLevel = nil
            weight = nil
            tags = []
            reasons = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let explicitNodeID = try container.decodeIfPresent(String.self, forKey: .nodeID)
            ?? container.decodeIfPresent(String.self, forKey: .nodeIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        let skillNodeID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .skillID)
            ?? container.decodeIfPresent(String.self, forKey: .skillId)
        let decodedNodeID = explicitNodeID ?? skillNodeID ?? UIStrings.unknown
        nodeID = decodedNodeID
        instanceID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .skillID)
            ?? container.decodeIfPresent(String.self, forKey: .skillId)
        definitionID = try container.decodeIfPresent(String.self, forKey: .definitionID)
            ?? container.decodeIfPresent(String.self, forKey: .definitionId)
        skillName = try container.decodeIfPresent(String.self, forKey: .skillName)
            ?? container.decodeIfPresent(String.self, forKey: .skillNameAlt)
        label = try container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? skillName
            ?? decodedNodeID
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .nodeType)
            ?? container.decodeIfPresent(String.self, forKey: .nodeTypeAlt)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .category)
            ?? "skill"
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? ""
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        state = try container.decodeIfPresent(String.self, forKey: .state)
            ?? container.decodeIfPresent(String.self, forKey: .status)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
            ?? container.decodeIfPresent(String.self, forKey: .domainName)
        clusterID = try container.decodeIfPresent(String.self, forKey: .clusterID)
            ?? container.decodeIfPresent(String.self, forKey: .clusterIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .cluster)
        riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel)
            ?? container.decodeIfPresent(String.self, forKey: .riskLevelAlt)
        weight = try container.decodeFlexibleLocalMapDouble(keys: [.weight, .score, .centrality])
        tags = try container.decodeFlexibleLocalMapStringArray(keys: [.tags, .tag])
        reasons = try container.decodeFlexibleLocalMapStringArray(keys: [.reasons, .reason, .matchReasons])
        evidenceRefs = try container.decodeFlexibleLocalMapEvidenceStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleLocalMapStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? decodedNodeID
    }

    var statusLabel: String {
        guard let state, let enabled else { return UIStrings.unknown }
        return DisplayText.state(state, enabled: enabled)
    }
}

struct LocalSkillMapEdge: Decodable, Hashable, Identifiable {
    let id: String
    let sourceID: String?
    let targetID: String?
    let relation: String
    let label: String
    let strength: Double?
    let direction: String?
    let reasons: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case sourceID = "source_id"
        case sourceIDAlt = "sourceId"
        case source
        case from
        case targetID = "target_id"
        case targetIDAlt = "targetId"
        case target
        case to
        case relation
        case relationKind = "relation_kind"
        case edgeType = "edge_type"
        case edgeTypeAlt = "edgeType"
        case type
        case kind
        case label
        case name
        case title
        case strength
        case weight
        case score
        case direction
        case reasons
        case reason
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
            sourceID = nil
            targetID = nil
            relation = value
            label = value
            strength = nil
            direction = nil
            reasons = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceID = try container.decodeIfPresent(String.self, forKey: .sourceID)
            ?? container.decodeIfPresent(String.self, forKey: .sourceIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .source)
            ?? container.decodeIfPresent(String.self, forKey: .from)
        targetID = try container.decodeIfPresent(String.self, forKey: .targetID)
            ?? container.decodeIfPresent(String.self, forKey: .targetIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .target)
            ?? container.decodeIfPresent(String.self, forKey: .to)
        relation = try container.decodeIfPresent(String.self, forKey: .relation)
            ?? container.decodeIfPresent(String.self, forKey: .relationKind)
            ?? container.decodeIfPresent(String.self, forKey: .edgeType)
            ?? container.decodeIfPresent(String.self, forKey: .edgeTypeAlt)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? UIStrings.unknown
        label = try container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? relation
        strength = try container.decodeFlexibleLocalMapDouble(keys: [.strength, .weight, .score])
        direction = try container.decodeIfPresent(String.self, forKey: .direction)
        reasons = try container.decodeFlexibleLocalMapStringArray(keys: [.reasons, .reason])
        evidenceRefs = try container.decodeFlexibleLocalMapEvidenceStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleLocalMapStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? [sourceID, targetID, relation].compactMap { $0 }.joined(separator: "->")
    }
}

struct LocalSkillMapCluster: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let kind: String
    let summary: String
    let nodeIDs: [String]
    let representativeSkills: [CapabilityTaxonomySkill]
    let agents: [String]
    let capabilities: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case clusterID = "cluster_id"
        case clusterIDAlt = "clusterId"
        case domainID = "domain_id"
        case domainIDAlt = "domainId"
        case title
        case name
        case label
        case domain
        case domainName = "domain_name"
        case kind
        case clusterType = "cluster_type"
        case clusterTypeAlt = "clusterType"
        case type
        case category
        case summary
        case message
        case description
        case nodeIDs = "node_ids"
        case nodeIDsAlt = "nodeIds"
        case skillIDs = "skill_ids"
        case nodes
        case members
        case skills
        case representativeSkills = "representative_skills"
        case representativeSkillsAlt = "representativeSkills"
        case agents
        case agent
        case capabilities
        case capability
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
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
            kind = "cluster"
            summary = ""
            nodeIDs = []
            representativeSkills = []
            agents = []
            capabilities = []
            gapNotes = []
            blockerNotes = []
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .domain)
            ?? container.decodeIfPresent(String.self, forKey: .domainName)
            ?? UIStrings.unknown
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .clusterType)
            ?? container.decodeIfPresent(String.self, forKey: .clusterTypeAlt)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .category)
            ?? "cluster"
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? ""
        nodeIDs = try container.decodeFlexibleLocalMapStringArray(keys: [.nodeIDs, .nodeIDsAlt, .skillIDs, .nodes, .members, .skills])
        representativeSkills = try container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .representativeSkills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .representativeSkillsAlt)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .skills)
            ?? container.decodeIfPresent([CapabilityTaxonomySkill].self, forKey: .members)
            ?? []
        agents = try container.decodeFlexibleLocalMapStringArray(keys: [.agents, .agent])
        capabilities = try container.decodeFlexibleLocalMapStringArray(keys: [.capabilities, .capability])
        gapNotes = try container.decodeFlexibleLocalMapStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleLocalMapStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceRefs = try container.decodeFlexibleLocalMapEvidenceStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        safetyFlags = try container.decodeFlexibleLocalMapStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .clusterID)
            ?? container.decodeIfPresent(String.self, forKey: .clusterIDAlt)
            ?? container.decodeIfPresent(String.self, forKey: .domainID)
            ?? container.decodeIfPresent(String.self, forKey: .domainIDAlt)
            ?? title
    }
}

struct LocalSkillMapIssueRow: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let severity: String?
    let source: String?
    let agent: String?
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case label
        case name
        case detail
        case summary
        case message
        case severity
        case level
        case source
        case agent
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
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
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.unknown
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? title
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .level)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        evidenceRefs = try container.decodeFlexibleLocalMapEvidenceStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(source ?? "")-\(agent ?? "")-\(title)-\(detail)"
    }
}

typealias LocalSkillMapEvidenceReference = CrossAgentReadinessEvidenceReference
typealias LocalSkillMapSafety = CrossAgentReadinessSafety

struct LocalSkillMapPromptRequest: Decodable, Hashable {
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
            requestKind = normalizedRequestKind(value)
            previewID = nil
            summary = value
            copyOnly = true
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        requestKind = normalizedRequestKind(
            try container.decodeIfPresent(String.self, forKey: .requestKind)
                ?? container.decodeIfPresent(String.self, forKey: .kind)
                ?? "local_skill_map"
        )
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

private func normalizedRequestKind(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == "routing_accuracy" {
        return "local_skill_map"
    }
    return trimmed
}

struct LocalSkillMapResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let summary: LocalSkillMapSummary
    let filters: LocalSkillMapFilters
    let selectedSkill: CapabilityTaxonomySkill?
    let nodes: [LocalSkillMapNode]
    let edges: [LocalSkillMapEdge]
    let clusters: [LocalSkillMapCluster]
    let gapRows: [LocalSkillMapIssueRow]
    let blockerRows: [LocalSkillMapIssueRow]
    let evidenceReferences: [LocalSkillMapEvidenceReference]
    let promptRequest: LocalSkillMapPromptRequest?
    let safetyFlags: LocalSkillMapSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case summary
        case filters
        case selectedSkill = "selected_skill"
        case selectedSkillAlt = "selectedSkill"
        case nodes
        case mapNodes = "map_nodes"
        case mapNodesAlt = "mapNodes"
        case skillNodes = "skill_nodes"
        case edges
        case mapEdges = "map_edges"
        case mapEdgesAlt = "mapEdges"
        case relationships
        case links
        case clusters
        case domains
        case groups
        case gapRows = "gap_rows"
        case gapRowsAlt = "gapRows"
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerRows = "blocker_rows"
        case blockerRowsAlt = "blockerRows"
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
        summary: LocalSkillMapSummary = LocalSkillMapSummary(),
        filters: LocalSkillMapFilters = LocalSkillMapFilters(),
        selectedSkill: CapabilityTaxonomySkill? = nil,
        nodes: [LocalSkillMapNode] = [],
        edges: [LocalSkillMapEdge] = [],
        clusters: [LocalSkillMapCluster] = [],
        gapRows: [LocalSkillMapIssueRow] = [],
        blockerRows: [LocalSkillMapIssueRow] = [],
        evidenceReferences: [LocalSkillMapEvidenceReference] = [],
        promptRequest: LocalSkillMapPromptRequest? = nil,
        safetyFlags: LocalSkillMapSafety = LocalSkillMapSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.summary = summary
        self.filters = filters
        self.selectedSkill = selectedSkill
        self.nodes = nodes
        self.edges = edges
        self.clusters = clusters
        self.gapRows = gapRows
        self.blockerRows = blockerRows
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let nodes = try? decoder.singleValueContainer().decode([LocalSkillMapNode].self) {
            generatedBy = "local"
            catalogAvailable = true
            summary = LocalSkillMapSummary(nodeCount: nodes.count, skillCount: nodes.count)
            filters = LocalSkillMapFilters()
            selectedSkill = nil
            self.nodes = nodes
            edges = []
            clusters = []
            gapRows = []
            blockerRows = []
            evidenceReferences = []
            promptRequest = nil
            safetyFlags = LocalSkillMapSafety()
            fallbackReason = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedNodes = try container.decodeIfPresent([LocalSkillMapNode].self, forKey: .nodes)
            ?? container.decodeIfPresent([LocalSkillMapNode].self, forKey: .mapNodes)
            ?? container.decodeIfPresent([LocalSkillMapNode].self, forKey: .mapNodesAlt)
            ?? container.decodeIfPresent([LocalSkillMapNode].self, forKey: .skillNodes)
            ?? []
        let decodedEdges = try container.decodeIfPresent([LocalSkillMapEdge].self, forKey: .edges)
            ?? container.decodeIfPresent([LocalSkillMapEdge].self, forKey: .mapEdges)
            ?? container.decodeIfPresent([LocalSkillMapEdge].self, forKey: .mapEdgesAlt)
            ?? container.decodeIfPresent([LocalSkillMapEdge].self, forKey: .relationships)
            ?? container.decodeIfPresent([LocalSkillMapEdge].self, forKey: .links)
            ?? []
        let decodedClusters = try container.decodeIfPresent([LocalSkillMapCluster].self, forKey: .clusters)
            ?? container.decodeIfPresent([LocalSkillMapCluster].self, forKey: .domains)
            ?? container.decodeIfPresent([LocalSkillMapCluster].self, forKey: .groups)
            ?? []
        generatedBy = try container.decodeIfPresent(String.self, forKey: .generatedBy)
            ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
            ?? "local"
        catalogAvailable = try container.decodeIfPresent(Bool.self, forKey: .catalogAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .catalogAvailableAlt)
            ?? true
        summary = try container.decodeIfPresent(LocalSkillMapSummary.self, forKey: .summary)
            ?? LocalSkillMapSummary(
                nodeCount: decodedNodes.count,
                edgeCount: decodedEdges.count,
                clusterCount: decodedClusters.count,
                domainCount: decodedClusters.filter { $0.kind.localizedCaseInsensitiveContains("domain") }.count,
                skillCount: decodedNodes.filter { $0.kind.localizedCaseInsensitiveContains("skill") }.count,
                agentCount: Set(decodedNodes.compactMap(\.agent)).count
            )
        filters = try container.decodeIfPresent(LocalSkillMapFilters.self, forKey: .filters) ?? LocalSkillMapFilters()
        selectedSkill = try container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .selectedSkill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .selectedSkillAlt)
        nodes = decodedNodes
        edges = decodedEdges
        clusters = decodedClusters
        gapRows = try container.decodeFlexibleLocalMapIssueRows(keys: [.gapRows, .gapRowsAlt, .gapNotes, .gapNotesAlt, .gaps])
        blockerRows = try container.decodeFlexibleLocalMapIssueRows(keys: [.blockerRows, .blockerRowsAlt, .blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeFlexibleLocalMapEvidenceReferences(keys: [.evidenceReferences, .evidenceReferencesAlt, .evidence])
        promptRequest = try container.decodeIfPresent(LocalSkillMapPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(LocalSkillMapPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(LocalSkillMapSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(LocalSkillMapSafety.self, forKey: .safety)
            ?? LocalSkillMapSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.localSkillMapUnavailable) -> LocalSkillMapResult {
        LocalSkillMapResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleLocalMapInt(keys: [Key]) throws -> Int? {
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
            if let values = try? decodeIfPresent([LocalSkillMapNode].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([LocalSkillMapEdge].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([LocalSkillMapCluster].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([LocalSkillMapIssueRow].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([LocalSkillMapEvidenceReference].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleLocalMapDouble(keys: [Key]) throws -> Double? {
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

    func decodeFlexibleLocalMapBool(keys: [Key]) throws -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1", "enabled", "included":
                    return true
                case "false", "no", "0", "disabled", "excluded":
                    return false
                default:
                    break
                }
            }
        }
        return nil
    }

    func decodeFlexibleLocalMapStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([LocalSkillMapNode].self, forKey: key) {
                return values.map(\.nodeID)
            }
            if let values = try? decodeIfPresent([LocalSkillMapIssueRow].self, forKey: key) {
                return values.map(\.detail)
            }
            if let values = try? decodeIfPresent([LocalSkillMapEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(LocalSkillMapEvidenceReference.self, forKey: key) {
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

    func decodeFlexibleLocalMapEvidenceStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([LocalSkillMapEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(LocalSkillMapEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
            if let values = try? decodeIfPresent([LocalSkillMapIssueRow].self, forKey: key) {
                return values.map(\.detail)
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

    func decodeFlexibleLocalMapIssueRows(keys: [Key]) throws -> [LocalSkillMapIssueRow] {
        for key in keys {
            if let values = try? decodeIfPresent([LocalSkillMapIssueRow].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(LocalSkillMapIssueRow.self, forKey: key) {
                return [value]
            }
        }
        return []
    }

    func decodeFlexibleLocalMapEvidenceReferences(keys: [Key]) throws -> [LocalSkillMapEvidenceReference] {
        for key in keys {
            if let values = try? decodeIfPresent([LocalSkillMapEvidenceReference].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(LocalSkillMapEvidenceReference.self, forKey: key) {
                return [value]
            }
        }
        return []
    }
}
