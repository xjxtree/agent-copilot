import Foundation

extension ServiceClient {
    func scoreSkillQuality(skill: SkillRecord) async throws -> SkillQualityScoreResult {
        let params = ScoreSkillQualityParams(
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent
        )
        do {
            return try await call(method: "analysis.scoreSkillQuality", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(skillID: skill.id)
        }
    }

    func checkTaskReadiness(taskText: String, skill: SkillRecord) async throws -> TaskReadinessResult {
        let params = TaskReadinessParams(
            task: taskText,
            agent: skill.agent,
            candidateInstanceIDs: [skill.id]
        )
        do {
            return try await call(method: "task.checkReadiness", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(taskText: taskText)
        }
    }

    func rankSkillRoutes(taskText: String, skill: SkillRecord, limit: Int = 6) async throws -> SkillRoutingConfidenceResult {
        let params = TaskRoutingConfidenceParams(
            task: taskText,
            agent: skill.agent,
            candidateInstanceIDs: [skill.id],
            limit: limit
        )
        do {
            return try await call(method: "task.rankSkillRoutes", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(taskText: taskText)
        }
    }

    func compareAgentReadiness(
        taskText: String,
        agents: [String]? = nil,
        limitPerAgent: Int = 3,
        includeRoutingAccuracy: Bool = true,
        includeBenchmarks: Bool = true
    ) async throws -> CrossAgentReadinessResult {
        let params = CrossAgentReadinessParams(
            task: taskText,
            agents: agents,
            limitPerAgent: limitPerAgent,
            includeRoutingAccuracy: includeRoutingAccuracy,
            includeBenchmarks: includeBenchmarks
        )
        do {
            return try await call(method: "task.compareAgentReadiness", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(taskText: taskText)
        }
    }

    func buildTaskCockpit(
        taskText: String,
        agent: String? = nil,
        project: ProjectContext? = nil,
        selectedSkill: SkillRecord? = nil,
        limit: Int? = 8,
        includeSessionReview: Bool = true,
        includeProviderObservability: Bool = true,
        includeRemediationContext: Bool = true,
        includeEvidence: Bool = true
    ) async throws -> TaskCockpitResult {
        let params = TaskCockpitParams(
            task: taskText,
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
            includeSessionReview: includeSessionReview,
            includeProviderObservability: includeProviderObservability,
            includeRemediationContext: includeRemediationContext,
            includeEvidence: includeEvidence
        )
        do {
            return try await call(method: "task.buildCockpit", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(taskText: taskText)
        }
    }

    func listTaskBenchmarks(skill: SkillRecord?) async throws -> TaskBenchmarkListResult {
        let params = TaskBenchmarkListParams(limit: nil)
        do {
            return try await call(method: "task.listBenchmarks", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func saveTaskBenchmark(taskText: String, skill: SkillRecord) async throws -> TaskBenchmarkSaveResult {
        let params = TaskBenchmarkSaveParams(
            task: taskText,
            title: nil,
            expectedSkillRefs: [skill.id, skill.definitionId],
            expectedSkillNames: [skill.name],
            acceptableAgents: [skill.agent],
            acceptableScopes: [skill.scope],
            successCriteria: [UIStrings.taskBenchmarkSuccessCriterion]
        )
        do {
            return try await call(method: "task.saveBenchmark", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func evaluateTaskBenchmarks(skill: SkillRecord?, benchmarkIDs: [String]? = nil, limit: Int = 6) async throws -> TaskBenchmarkEvaluationResult {
        let params = TaskBenchmarkEvaluateParams(
            benchmarkIDs: benchmarkIDs,
            limit: limit
        )
        do {
            return try await call(method: "task.evaluateBenchmarks", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func saveRoutingBaseline(skill: SkillRecord?, benchmarkIDs: [String]? = nil, limit: Int = 20) async throws -> RoutingRegressionBaselineResult {
        let params = RoutingRegressionParams(
            benchmarkIDs: benchmarkIDs,
            limit: limit
        )
        do {
            return try await call(method: "task.saveRoutingBaseline", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func detectRoutingRegression(skill: SkillRecord?, benchmarkIDs: [String]? = nil, limit: Int = 20) async throws -> RoutingRegressionDetectionResult {
        let params = RoutingRegressionParams(
            benchmarkIDs: benchmarkIDs,
            limit: limit
        )
        do {
            return try await call(method: "task.detectRoutingRegression", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func routingAccuracyDashboard(
        agent: String? = nil,
        windowDays: Int? = 30,
        limit: Int? = 20,
        includeHistory: Bool = true,
        includeRecentEvidence: Bool = true
    ) async throws -> RoutingAccuracyDashboard {
        let params = RoutingAccuracyDashboardParams(
            agent: agent,
            windowDays: windowDays,
            limit: limit,
            includeHistory: includeHistory,
            includeRecentEvidence: includeRecentEvidence
        )
        do {
            return try await call(method: "routing.accuracyDashboard", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func detectStaleDrift(
        agent: String? = nil,
        limit: Int? = 40,
        includeReadinessImpact: Bool = true
    ) async throws -> StaleDriftDetectionResult {
        let params = StaleDriftDetectionParams(
            agent: agent,
            limit: limit,
            includeReadinessImpact: includeReadinessImpact
        )
        do {
            return try await call(method: "analysis.detectStaleDrift", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func deleteTaskBenchmark(benchmarkID: String) async throws -> TaskBenchmarkDeleteResult {
        do {
            return try await call(method: "task.deleteBenchmark", params: TaskBenchmarkDeleteParams(benchmarkId: benchmarkID))
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }
}
