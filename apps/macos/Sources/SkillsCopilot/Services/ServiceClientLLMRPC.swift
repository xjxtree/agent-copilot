import Foundation

private enum LLMPromptRequestTimeouts {
    static let standardSendMS = 600_000
    static let taskCockpitSendMS = 300_000
}

extension ServiceClient {
    func llmStatus() async throws -> LLMStatus {
        do {
            return try await call(method: "llm.status", params: EmptyParams())
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .disabledFallback()
        }
    }

    func aiProviderStatus() async throws -> AIProviderStatus {
        do {
            return try await call(method: "llm.listProviderProfiles", params: EmptyParams())
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func saveAIProviderSettings(draft: AIProviderSettingsDraft) async throws -> AIProviderStatus {
        let params = SaveAIProviderProfileParams(
            id: draft.kind.rawValue,
            displayName: draft.kind.title,
            providerType: draft.kind.rawValue,
            baseURL: draft.trimmedEndpoint,
            model: draft.trimmedModel,
            enabled: true,
            apiVersion: draft.trimmedAPIVersion,
            apiKey: draft.trimmedAPIKey,
            singleRequestTokenLimit: draft.parsedSingleRequestTokenLimit,
            monthlyBudgetUSD: draft.parsedMonthlyBudgetUSD
        )
        do {
            let _: AIProviderSaveResult = try await call(method: "llm.saveProviderProfile", params: params)
            return try await aiProviderStatus()
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func testAIProviderConnection(draft: AIProviderSettingsDraft) async throws -> AIProviderTestResult {
        let params = TestAIProviderConnectionParams(
            profileID: draft.kind.rawValue,
            confirmationID: "settings-test-\(UUID().uuidString)",
            timeoutMS: 4_000
        )
        do {
            return try await call(method: "llm.testProviderConnection", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func prepareLLMAction(action: LLMAction, skill: SkillRecord) async throws -> LLMPrepareResult {
        do {
            return try await call(
                method: "llm.prepareAction",
                params: PrepareLLMActionParams(
                    action: action,
                    instanceId: skill.id,
                    definitionId: skill.definitionId,
                    agent: skill.agent
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .disabledFallback(action: action)
        }
    }

    func prepareSkillAnalysis(instanceIDs: [String], kind: LLMSkillAnalysisKind) async throws -> LLMSkillAnalysisPrepareResult {
        do {
            return try await call(
                method: "llm.prepareSkillAnalysis",
                params: PrepareSkillAnalysisParams(instanceIDs: instanceIDs, analysisKind: kind)
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(kind: kind)
        }
    }

    func previewPromptForLLMAction(action: LLMAction, skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: action.rawValue,
            requestKind: "action",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: nil,
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.llmSkillAnalysisUnavailable)
        }
    }

    func previewPromptForSkillAnalysis(
        instanceIDs: [String],
        kind: LLMSkillAnalysisKind,
        scope: LLMSkillAnalysisRequestScope
    ) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "skill_analysis",
            requestKind: "skill_analysis",
            analysisKind: kind,
            scope: scope.key,
            instanceIDs: instanceIDs,
            instanceId: nil,
            definitionId: nil,
            agent: nil,
            agents: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.llmSkillAnalysisUnavailable)
        }
    }

    func previewPromptForSkillQuality(skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "quality_score",
            requestKind: "quality_score",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.skillQualityPromptUnavailable)
        }
    }

    func previewPromptForTaskReadiness(taskText: String, skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "task_readiness",
            requestKind: "task_readiness",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.taskReadinessPromptUnavailable)
        }
    }

    func previewPromptForRoutingConfidence(taskText: String, skill: SkillRecord) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "routing_confidence",
            requestKind: "routing_confidence",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        do {
            return try await call(method: "llm.previewPrompt", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.routingConfidencePromptUnavailable)
        }
    }

    func confirmPromptAndSendForLLMAction(previewID: String, action: LLMAction, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: action.rawValue,
            requestKind: "action",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: nil,
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForSkillAnalysis(
        previewID: String,
        instanceIDs: [String],
        kind: LLMSkillAnalysisKind,
        scope: LLMSkillAnalysisRequestScope
    ) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "skill_analysis",
            requestKind: "skill_analysis",
            analysisKind: kind,
            scope: scope.key,
            instanceIDs: instanceIDs,
            instanceId: nil,
            definitionId: nil,
            agent: nil,
            agents: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForSkillQuality(previewID: String, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "quality_score",
            requestKind: "quality_score",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: nil,
            userIntent: nil,
            candidateInstanceIDs: nil
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForTaskReadiness(previewID: String, taskText: String, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "task_readiness",
            requestKind: "task_readiness",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func confirmPromptAndSendForRoutingConfidence(previewID: String, taskText: String, skill: SkillRecord) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "routing_confidence",
            requestKind: "routing_confidence",
            analysisKind: nil,
            scope: "selected",
            instanceIDs: [skill.id],
            instanceId: skill.id,
            definitionId: skill.definitionId,
            agent: skill.agent,
            agents: nil,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: [skill.id]
        )
        return try await confirmPromptAndSend(previewID: previewID, request: request)
    }

    func previewPromptForTaskCockpit(
        taskText: String,
        agents: [String],
        instanceIDs: [String]
    ) async throws -> LLMPromptPreview {
        let params = PreviewLLMPromptParams(
            action: "task_cockpit",
            requestKind: "task_cockpit",
            analysisKind: nil,
            scope: "agents",
            instanceIDs: instanceIDs,
            instanceId: nil,
            definitionId: nil,
            agent: nil,
            agents: agents,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: instanceIDs
        )
        do {
            return try await call(
                method: "llm.previewPrompt",
                params: params,
                timeoutMS: LLMPromptRequestTimeouts.taskCockpitSendMS
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(reason: UIStrings.taskCockpitUnavailable)
        }
    }

    func confirmPromptAndSendForTaskCockpit(
        previewID: String,
        taskText: String,
        agents: [String],
        instanceIDs: [String]
    ) async throws -> LLMPromptSendResult {
        let request = PreviewLLMPromptParams(
            action: "task_cockpit",
            requestKind: "task_cockpit",
            analysisKind: nil,
            scope: "agents",
            instanceIDs: instanceIDs,
            instanceId: nil,
            definitionId: nil,
            agent: nil,
            agents: agents,
            taskText: taskText,
            userIntent: taskText,
            candidateInstanceIDs: instanceIDs
        )
        return try await confirmPromptAndSend(
            previewID: previewID,
            request: request,
            timeoutMS: LLMPromptRequestTimeouts.taskCockpitSendMS
        )
    }

    func listLLMPromptRuns(skill: SkillRecord? = nil, limit: Int = 80) async throws -> LLMPromptRunListResult {
        let params = ListLLMPromptRunsParams(
            instanceId: skill?.id,
            action: nil,
            requestKind: nil,
            limit: limit
        )
        do {
            return try await call(method: "llm.listPromptRuns", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    func providerObservability(
        windowDays: Int = 30,
        limit: Int = 30,
        includeHistory: Bool = true,
        includeBudgetHints: Bool = true,
        includeRetentionRecommendations: Bool = true,
        includeEvidence: Bool = true
    ) async throws -> ProviderObservabilityResult {
        let params = ProviderObservabilityParams(
            windowDays: windowDays,
            limit: limit,
            includeHistory: includeHistory,
            includeBudgetHints: includeBudgetHints,
            includeRetentionRecommendations: includeRetentionRecommendations,
            includeEvidence: includeEvidence
        )
        do {
            return try await call(method: "llm.providerObservability", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }

    private func confirmPromptAndSend(
        previewID: String,
        request: PreviewLLMPromptParams,
        timeoutMS: Int = LLMPromptRequestTimeouts.standardSendMS
    ) async throws -> LLMPromptSendResult {
        let params = ConfirmLLMPromptParams(
            previewID: previewID,
            confirmationID: "prompt-confirm-\(UUID().uuidString)",
            request: request,
            timeoutMS: timeoutMS
        )
        do {
            return try await call(method: "llm.confirmPromptAndSend", params: params, timeoutMS: timeoutMS)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(previewID: previewID, reason: UIStrings.llmSkillAnalysisUnavailable)
        }
    }
}
