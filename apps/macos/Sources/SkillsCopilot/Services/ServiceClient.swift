import Foundation

struct ServiceErrorPayload: Codable, Error {
    let code: String
    let message: String
}

struct AppVersion: Codable, Hashable {
    let protocolVersion: Int
    let version: String

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case version
    }
}

struct AppStateSnapshot: Codable, Hashable {
    let status: ServiceStatus
    let skills: [SkillRecord]
    let findings: [RuleFindingRecord]
    let conflicts: [ConflictGroupRecord]
    let health: SkillHealthSummary
    let snapshots: [ConfigSnapshotRecord]

    enum CodingKeys: String, CodingKey {
        case status
        case skills
        case findings
        case conflicts
        case health
        case snapshots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(ServiceStatus.self, forKey: .status)
        skills = try container.decode([SkillRecord].self, forKey: .skills)
        findings = try container.decode([RuleFindingRecord].self, forKey: .findings)
        conflicts = try container.decode([ConflictGroupRecord].self, forKey: .conflicts)
        health = try container.decodeIfPresent(SkillHealthSummary.self, forKey: .health) ?? .empty
        snapshots = try container.decodeIfPresent([ConfigSnapshotRecord].self, forKey: .snapshots) ?? []
    }
}

private struct ServiceRequest<Params: Encodable>: Encodable {
    let id: String
    let method: String
    let params: Params
}

private struct EmptyParams: Encodable {}

private struct CleanupListQueueParams: Encodable {
    let agent: String?
    let limit: Int?
}

private struct CrossAgentComparisonParams: Encodable {
    let agent: String?
    let instanceId: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case agent
        case instanceId = "instance_id"
        case limit
    }
}

private struct LocalReportExportParams: Encodable {
    let formats: [LocalReportFormat]
    let agent: String?
    let instanceId: String?
    let stateFilter: String?
    let search: String?

    enum CodingKeys: String, CodingKey {
        case formats
        case agent
        case instanceId = "instance_id"
        case stateFilter = "state_filter"
        case search
    }
}

private struct GetSkillParams: Encodable {
    let instanceId: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
    }
}

private struct ToggleSkillParams: Encodable {
    let instanceId: String
    let on: Bool

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case on
    }
}

private struct BatchToggleParams: Encodable {
    let instanceIDs: [String]
    let targetEnabled: Bool
    let action: String
    let previewToken: String?
    let confirmed: Bool?

    enum CodingKeys: String, CodingKey {
        case instanceIDs = "instance_ids"
        case targetEnabled = "target_enabled"
        case action
        case previewToken = "preview_token"
        case confirmed
    }
}

private struct ToolInstallPreviewParams: Encodable {
    let instanceId: String
    let targetAgent: String
    let targetScope: String
    let confirmed: Bool

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case targetAgent = "target_agent"
        case targetScope = "target_scope"
        case confirmed
    }
}

private struct PrepareSkillAnalysisParams: Encodable {
    let instanceIDs: [String]
    let analysisKind: LLMSkillAnalysisKind

    enum CodingKeys: String, CodingKey {
        case instanceIDs = "instance_ids"
        case analysisKind = "analysis_kind"
    }
}

private struct PrepareLLMActionParams: Encodable {
    let action: LLMAction
    let instanceId: String
    let definitionId: String
    let agent: String

    enum CodingKeys: String, CodingKey {
        case action = "kind"
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
    }
}

private struct ScriptExecutionParams: Encodable {
    let instanceId: String
    let definitionId: String
    let agent: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case definitionId = "definition_id"
        case agent
    }
}

private struct SnapshotParams: Encodable {
    let snapshotId: String

    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
    }
}

private struct ListAgentConfigSnapshotsParams: Encodable {
    let agent: String
    let scope: String?
}

private struct ListSkillEventsParams: Encodable {
    let instanceId: String
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case limit
    }
}

private struct SetFindingTriageParams: Encodable {
    let triageKey: String
    let status: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case triageKey = "triage_key"
        case status
        case note
    }
}

private struct ClearFindingTriageParams: Encodable {
    let triageKey: String

    enum CodingKeys: String, CodingKey {
        case triageKey = "triage_key"
    }
}

private struct SetRuleSeverityOverrideParams: Encodable {
    let ruleId: String
    let severity: String

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case severity
    }
}

private struct ClearRuleSeverityOverrideParams: Encodable {
    let ruleId: String

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
    }
}

private struct SetRuleSuppressionParams: Encodable {
    let ruleId: String
    let scope: String
    let findingGroupId: String?
    let suppressed: Bool
    let note: String?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case scope
        case findingGroupId = "finding_group_id"
        case suppressed
        case note
    }
}

private struct ClearRuleSuppressionParams: Encodable {
    let ruleId: String
    let scope: String
    let findingGroupId: String?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case scope
        case findingGroupId = "finding_group_id"
    }
}

private struct SaveClaudeSettingsParams: Encodable {
    let content: String
}

private struct ProjectContextParams: Encodable {
    let rootPath: String
    let currentCWD: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case rootPath = "root_path"
        case currentCWD = "current_cwd"
        case name
    }
}

private struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
    let id: String?
    let ok: Bool
    let result: ResultPayload?
    let error: ServiceErrorPayload?
}

final class ServiceClient {
    enum ClientError: LocalizedError {
        case missingBinary
        case invalidOutput(String)
        case service(ServiceErrorPayload)
        case processFailed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .missingBinary:
                return "skills-copilot-service was not found in the app bundle."
            case .invalidOutput(let output):
                return "Invalid service output: \(output)"
            case .service(let error):
                return "\(error.code): \(error.message)"
            case .processFailed(let status, let stderr):
                return "Service exited with \(status): \(stderr)"
            }
        }
    }

    func status() async throws -> ServiceStatus {
        try await call(method: "service.status", params: EmptyParams())
    }

    func listAdapterCapabilities() async throws -> [AdapterCapabilityRecord] {
        try await call(method: "adapter.listCapabilities", params: EmptyParams())
    }

    func appVersion() async throws -> AppVersion {
        try await call(method: "app.version", params: EmptyParams())
    }

    func appStateSnapshot() async throws -> AppStateSnapshot {
        try await call(method: "app.stateSnapshot", params: EmptyParams())
    }

    func listCleanupQueue(agent: String? = nil, limit: Int? = nil) async throws -> CleanupQueueResult {
        do {
            return try await call(
                method: "cleanup.listQueue",
                params: CleanupListQueueParams(agent: agent, limit: limit)
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .emptyFallback(reason: UIStrings.cleanupUnavailableFallback)
        }
    }

    func listCrossAgentComparisons(agent: String? = nil, instanceID: String? = nil, limit: Int? = nil) async throws -> CrossAgentComparisonResult {
        let params = CrossAgentComparisonParams(agent: agent, instanceId: instanceID, limit: limit)
        do {
            return try await call(method: "comparison.listCrossAgent", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return try await call(method: "analysis.listComparisons", params: params)
        }
    }

    func exportLocalReport(
        format: LocalReportFormat,
        agent: String? = nil,
        instanceID: String? = nil,
        stateFilter: String? = nil,
        search: String? = nil
    ) async throws -> LocalReportExportResult {
        do {
            return try await call(
                method: "report.exportLocal",
                params: LocalReportExportParams(
                    formats: [format],
                    agent: agent,
                    instanceId: instanceID,
                    stateFilter: stateFilter,
                    search: search
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(format: format)
        }
    }

    func listSkills() async throws -> [SkillRecord] {
        try await call(method: "catalog.listSkills", params: EmptyParams())
    }

    func llmStatus() async throws -> LLMStatus {
        do {
            return try await call(method: "llm.status", params: EmptyParams())
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .disabledFallback()
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

    func previewScriptExecution(skill: SkillRecord) async throws -> ScriptExecutionPreview {
        do {
            return try await call(
                method: "script.previewExecution",
                params: ScriptExecutionParams(
                    instanceId: skill.id,
                    definitionId: skill.definitionId,
                    agent: skill.agent
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(skill: skill)
        }
    }

    func scriptExecutionAuditStatus(skill: SkillRecord) async throws -> ScriptExecutionPreview {
        do {
            return try await call(
                method: "script.auditStatus",
                params: ScriptExecutionParams(
                    instanceId: skill.id,
                    definitionId: skill.definitionId,
                    agent: skill.agent
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable(skill: skill)
        }
    }

    func scanAll() async throws -> ScanResult {
        try await call(method: "catalog.scanAll", params: EmptyParams())
    }

    func scanClaude() async throws -> ScanResult {
        try await call(method: "catalog.scanClaude", params: EmptyParams())
    }

    func getProjectContext() async throws -> ProjectContextState {
        do {
            return try await call(method: "project.getContext", params: EmptyParams())
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return ProjectContextState(active: nil, recent: [])
        }
    }

    func setProjectContext(rootPath: String, currentCWD: String?, name: String?) async throws -> ProjectContextState {
        try await call(
            method: "project.setContext",
            params: ProjectContextParams(rootPath: rootPath, currentCWD: currentCWD, name: name)
        )
    }

    func clearProjectContext() async throws -> ProjectContextState {
        try await call(method: "project.clearContext", params: EmptyParams())
    }

    func validateProjectContext(rootPath: String, currentCWD: String?, name: String?) async throws -> ProjectContext {
        try await call(
            method: "project.validateContext",
            params: ProjectContextParams(rootPath: rootPath, currentCWD: currentCWD, name: name)
        )
    }

    func getSkill(instanceID: String) async throws -> SkillDetailRecord {
        try await call(
            method: "catalog.getSkill",
            params: GetSkillParams(instanceId: instanceID)
        )
    }

    func listFindings() async throws -> [RuleFindingRecord] {
        try await call(method: "catalog.listFindings", params: EmptyParams())
    }

    func listFindingTriage() async throws -> [FindingTriageRecord] {
        try await call(method: "catalog.listFindingTriage", params: EmptyParams())
    }

    func setFindingTriage(triageKey: String, status: FindingTriageStatus, note: String? = nil) async throws -> FindingTriageRecord {
        try await call(
            method: "catalog.setFindingTriage",
            params: SetFindingTriageParams(triageKey: triageKey, status: status.rawValue, note: note)
        )
    }

    func clearFindingTriage(triageKey: String) async throws -> Bool {
        try await call(
            method: "catalog.clearFindingTriage",
            params: ClearFindingTriageParams(triageKey: triageKey)
        )
    }

    func listRuleTuning() async throws -> [RuleTuningRecord] {
        do {
            let list: RuleTuningList = try await call(method: "rules.listTuning", params: EmptyParams())
            return list.records
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return []
        }
    }

    func setSeverityOverride(ruleId: String, severity: String) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.setSeverityOverride",
            params: SetRuleSeverityOverrideParams(ruleId: ruleId, severity: severity)
        )
        return result.record
    }

    func clearSeverityOverride(ruleId: String) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.clearSeverityOverride",
            params: ClearRuleSeverityOverrideParams(ruleId: ruleId)
        )
        return result.record
    }

    func setSuppression(ruleId: String, scope: RuleTuningScope, findingGroupId: String?, note: String? = nil) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.setSuppression",
            params: SetRuleSuppressionParams(
                ruleId: ruleId,
                scope: scope.rawValue,
                findingGroupId: scope == .findingGroup ? findingGroupId : nil,
                suppressed: true,
                note: note
            )
        )
        return result.record
    }

    func clearSuppression(ruleId: String, scope: RuleTuningScope, findingGroupId: String?) async throws -> RuleTuningRecord? {
        let result: RuleTuningMutationResult = try await call(
            method: "rules.clearSuppression",
            params: ClearRuleSuppressionParams(
                ruleId: ruleId,
                scope: scope.rawValue,
                findingGroupId: scope == .findingGroup ? findingGroupId : nil
            )
        )
        return result.record
    }

    func listConflicts() async throws -> [ConflictGroupRecord] {
        try await call(method: "catalog.listConflicts", params: EmptyParams())
    }

    func listSnapshots() async throws -> [ConfigSnapshotRecord] {
        try await call(method: "snapshot.list", params: EmptyParams())
    }

    func listAgentConfigSnapshots(agent: String, scope: String? = nil) async throws -> [ConfigSnapshotRecord] {
        try await call(
            method: "snapshot.listAgentConfig",
            params: ListAgentConfigSnapshotsParams(agent: agent, scope: scope)
        )
    }

    func listSkillEvents(instanceID: String, limit: Int? = nil) async throws -> [SkillEventRecord] {
        try await call(
            method: "skill.listEvents",
            params: ListSkillEventsParams(instanceId: instanceID, limit: limit)
        )
    }

    func toggleSkill(instanceID: String, on: Bool) async throws -> SkillRecord {
        try await call(
            method: "config.toggleSkill",
            params: ToggleSkillParams(instanceId: instanceID, on: on)
        )
    }

    func previewBatchSkillToggles(instanceIDs: [String], on: Bool) async throws -> BatchTogglePreview {
        let params = BatchToggleParams(
            instanceIDs: instanceIDs,
            targetEnabled: on,
            action: BatchToggleAction.from(targetEnabled: on).rawValue,
            previewToken: nil,
            confirmed: false
        )
        do {
            return try await call(method: "batch.previewSkillToggles", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return try await call(method: "batch.previewToggle", params: params)
        }
    }

    func applyBatchSkillToggles(preview: BatchTogglePreview) async throws -> BatchToggleApplyResult {
        let params = BatchToggleParams(
            instanceIDs: preview.affectedSkills.map(\.instanceID),
            targetEnabled: preview.targetEnabled,
            action: preview.action.rawValue,
            previewToken: preview.id,
            confirmed: true
        )
        do {
            return try await call(method: "batch.applySkillToggles", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return try await call(method: "batch.applyToggle", params: params)
        }
    }

    func previewToolInstall(skill: SkillRecord, target: ToolInstallTarget) async throws -> ToolGlobalInstallPreview {
        try await installToolSkill(skill: skill, target: target, confirmed: false)
    }

    func confirmToolInstall(skill: SkillRecord, target: ToolInstallTarget) async throws -> ToolGlobalInstallPreview {
        try await installToolSkill(skill: skill, target: target, confirmed: true)
    }

    private func installToolSkill(skill: SkillRecord, target: ToolInstallTarget, confirmed: Bool) async throws -> ToolGlobalInstallPreview {
        do {
            return try await call(
                method: "skill.install",
                params: ToolInstallPreviewParams(
                    instanceId: skill.id,
                    targetAgent: target.rawValue,
                    targetScope: "agent-global",
                    confirmed: confirmed
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            if confirmed {
                throw ClientError.service(error)
            }
            return try await legacyPreviewToolInstall(skill: skill, target: target)
        }
    }

    private func legacyPreviewToolInstall(skill: SkillRecord, target: ToolInstallTarget) async throws -> ToolGlobalInstallPreview {
        do {
            return try await call(
                method: "tool.previewInstall",
                params: ToolInstallPreviewParams(
                    instanceId: skill.id,
                    targetAgent: target.rawValue,
                    targetScope: "agent-global",
                    confirmed: false
                )
            )
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .localPreview(skill: skill, target: target)
        }
    }

    func readClaudeSettings() async throws -> ConfigDocumentRecord {
        try await call(method: "config.readClaudeSettings", params: EmptyParams())
    }

    func saveClaudeSettings(content: String) async throws -> ConfigDocumentRecord {
        try await call(
            method: "config.saveClaudeSettings",
            params: SaveClaudeSettingsParams(content: content)
        )
    }

    func previewSnapshotRollback(snapshotID: String) async throws -> SnapshotRollbackPreviewRecord {
        try await call(
            method: "snapshot.previewRollback",
            params: SnapshotParams(snapshotId: snapshotID)
        )
    }

    func rollbackSnapshot(snapshotID: String) async throws -> Int {
        try await call(
            method: "snapshot.rollback",
            params: SnapshotParams(snapshotId: snapshotID)
        )
    }

    private func call<ResultPayload: Decodable, Params: Encodable>(
        method: String,
        params: Params
    ) async throws -> ResultPayload {
        let request = ServiceRequest(
            id: UUID().uuidString,
            method: method,
            params: params
        )
        let input = try JSONEncoder().encode(request)
        let output = try await runService(input: input)
        let envelope = try JSONDecoder().decode(ServiceEnvelope<ResultPayload>.self, from: output)
        if envelope.ok, let result = envelope.result {
            return result
        }
        if let error = envelope.error {
            throw ClientError.service(error)
        }
        throw ClientError.invalidOutput(String(data: output, encoding: .utf8) ?? "<binary>")
    }

    private func runService(input: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = try self.resolveServiceURL()

            let stdin = Pipe()
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            stdin.fileHandleForWriting.write(input)
            try stdin.fileHandleForWriting.close()

            let output = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let message = String(data: errorOutput, encoding: .utf8) ?? ""
                throw ClientError.processFailed(process.terminationStatus, message)
            }
            return output
        }.value
    }

    private func resolveServiceURL() throws -> URL {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["SKILLS_COPILOT_SERVICE_PATH"],
           !override.isEmpty {
            let overrideURL = URL(fileURLWithPath: override)
            if FileManager.default.isExecutableFile(atPath: overrideURL.path) {
                return overrideURL
            }
        }
        #endif
        if let url = Bundle.main.url(forResource: "skills-copilot-service", withExtension: nil) {
            return url
        }
        throw ClientError.missingBinary
    }
}
