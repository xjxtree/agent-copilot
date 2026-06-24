import Foundation

extension ServiceClient {
    func importLocalTrace(
        traceText: String,
        title: String?,
        taskText: String?,
        expectedSkillNames: [String],
        skill: SkillRecord?
    ) async throws -> AgentTraceImportResult {
        let params = AgentTraceImportParams(
            traceText: traceText,
            title: title,
            task: taskText,
            expectedSkillNames: expectedSkillNames,
            candidateInstanceIDs: skill.map { [$0.id] },
            agent: skill?.agent
        )
        do {
            return try await call(method: "trace.importLocal", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func listTraceImports(limit: Int = 20) async throws -> AgentTraceImportListResult {
        do {
            return try await call(method: "trace.listImports", params: AgentTraceListParams(limit: limit))
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func deleteTraceImport(importID: String) async throws -> AgentTraceImportDeleteResult {
        do {
            return try await call(method: "trace.deleteImport", params: AgentTraceDeleteParams(importID: importID))
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func reviewAgentSessionSkillUse(
        transcriptText: String,
        taskText: String?,
        expectedSkillNames: [String],
        skill: SkillRecord?,
        project: ProjectContext?
    ) async throws -> AgentSessionSkillReviewResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = AgentSessionSkillReviewParams(
            transcriptText: transcriptText,
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            expectedSkillNames: expectedSkillNames,
            candidateInstanceIDs: skill.map { [$0.id] },
            agent: skill?.agent,
            selectedSkillID: skill?.id,
            selectedSkillName: skill?.name,
            selectedSkillAgent: skill?.agent,
            selectedSkillPath: skill?.displayPath.isEmpty == false ? skill?.displayPath : skill?.path,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name
        )
        do {
            return try await call(method: "session.reviewAgentSkillUse", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func previewLocalSessions(
        authorizedRoots: [String],
        agent: String? = nil,
        scope: LocalSessionScopeFilter = .project,
        search: String? = nil,
        project: ProjectContext? = nil,
        limit: Int = 20
    ) async throws -> LocalSessionPreviewResult {
        let normalizedSearch = search?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = LocalSessionPreviewParams(
            authorizedRoots: authorizedRoots,
            autoDiscover: authorizedRoots.isEmpty,
            agent: agent,
            scope: scope.rawValue,
            search: normalizedSearch?.isEmpty == true ? nil : normalizedSearch,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            limit: limit,
            maxFiles: 800,
            maxExcerptChars: 1000
        )
        do {
            return try await call(method: "session.previewLocalSessions", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func listAgentSessionSkillReviews(
        taskText: String? = nil,
        agent: String? = nil,
        skill: SkillRecord? = nil,
        project: ProjectContext? = nil,
        limit: Int? = 20
    ) async throws -> AgentSessionSkillReviewListResult {
        let normalizedTask = taskText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = AgentSessionSkillReviewListParams(
            task: normalizedTask?.isEmpty == true ? nil : normalizedTask,
            agent: agent ?? skill?.agent,
            selectedSkillID: skill?.id,
            selectedSkillName: skill?.name,
            selectedSkillAgent: skill?.agent,
            selectedSkillPath: skill?.displayPath.isEmpty == false ? skill?.displayPath : skill?.path,
            projectRoot: project?.rootPath,
            currentCWD: project?.currentCWD,
            workspace: project?.name,
            limit: limit
        )
        do {
            return try await call(method: "session.listSkillReviews", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func deleteAgentSessionSkillReview(reviewID: String) async throws -> AgentSessionSkillReviewDeleteResult {
        do {
            return try await call(
                method: "session.deleteSkillReview",
                params: AgentSessionSkillReviewDeleteParams(reviewID: reviewID)
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }
}
