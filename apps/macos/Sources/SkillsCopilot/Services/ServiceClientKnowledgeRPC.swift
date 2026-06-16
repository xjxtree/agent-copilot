import Foundation

extension ServiceClient {
    func searchKnowledge(query: String, agent: String? = nil, limit: Int? = 20) async throws -> KnowledgeSearchResult {
        let params = KnowledgeSearchParams(query: query, agent: agent, limit: limit)
        do {
            return try await call(method: "knowledge.search", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func buildLocalSkillMap(
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        limit: Int? = 30,
        includeEdges: Bool = true,
        includeClusters: Bool = true,
        includeEvidence: Bool = true
    ) async throws -> LocalSkillMapResult {
        let params = LocalSkillMapParams(
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            limit: limit,
            includeEdges: includeEdges,
            includeClusters: includeClusters,
            includeEvidence: includeEvidence
        )
        do {
            return try await call(method: "knowledge.buildLocalSkillMap", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func loadSkillLifecycleTimeline(
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        limit: Int? = 20,
        includeSkillRows: Bool = true,
        includeAgentRows: Bool = true,
        includeEvidence: Bool = true,
        includeSafetyFlags: Bool = true
    ) async throws -> SkillLifecycleTimelineResult {
        let params = SkillLifecycleTimelineParams(
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            selectedSkillID: selectedSkill?.id,
            selectedSkillName: selectedSkill?.name,
            selectedSkillAgent: selectedSkill?.agent,
            selectedSkillPath: selectedSkill?.displayPath.isEmpty == false ? selectedSkill?.displayPath : selectedSkill?.path,
            candidateInstanceIDs: selectedSkill.map { [$0.id] },
            limit: limit,
            includeSkillRows: includeSkillRows,
            includeAgentRows: includeAgentRows,
            includeEvidence: includeEvidence,
            includeSafetyFlags: includeSafetyFlags
        )
        do {
            return try await call(method: "skill.lifecycleTimeline", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func groupSimilarSkills(
        agent: String? = nil,
        limit: Int? = 20,
        minScore: Double? = 0.62,
        includeSingletons: Bool = false
    ) async throws -> SimilarSkillGroupingResult {
        let params = SimilarSkillGroupingParams(
            agent: agent,
            limit: limit,
            minScore: minScore,
            includeSingletons: includeSingletons
        )
        do {
            return try await call(method: "knowledge.groupSimilarSkills", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func buildCapabilityTaxonomy(
        agent: String? = nil,
        limit: Int? = 20,
        includeSingleSkillDomains: Bool = true
    ) async throws -> CapabilityTaxonomyResult {
        let params = CapabilityTaxonomyParams(
            agent: agent,
            limit: limit,
            includeSingleSkillDomains: includeSingleSkillDomains
        )
        do {
            return try await call(method: "knowledge.buildCapabilityTaxonomy", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func checkWorkspaceReadiness(
        taskText: String? = nil,
        agent: String? = nil,
        project: ProjectContext? = nil,
        limit: Int? = 40,
        includeChecklist: Bool = true,
        includeCapabilities: Bool = true
    ) async throws -> WorkspaceReadinessResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = WorkspaceReadinessParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            limit: limit,
            includeChecklist: includeChecklist,
            includeCapabilities: includeCapabilities
        )
        do {
            return try await call(method: "workspace.checkReadiness", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }
}
