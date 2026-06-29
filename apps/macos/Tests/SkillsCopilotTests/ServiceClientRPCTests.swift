import Foundation
@testable import SkillsCopilot

struct ServiceClientRPCTests {
    func run() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let client = fake.serviceClient()

        let findings = try await client.listFindings()
        try expectEqual(findings.count, 0, "Catalog/config RPC wrapper should decode listFindings.")

        let mcpPreview = try await client.previewMcpServers(authorizedConfigPaths: ["/tmp/mcp.json"], limit: 2)
        try expectEqual(mcpPreview.isUnavailable, true, "Evidence RPC wrapper should map unknown methods to unavailable.")

        let sessions = try await client.previewLocalSessions(
            authorizedRoots: [],
            agent: "codex",
            scope: .all,
            search: "release",
            project: nil,
            limit: 3
        )
        try expectEqual(sessions.isUnavailable, true, "Session RPC wrapper should map unknown methods to unavailable.")

        let knowledge = try await client.searchKnowledge(query: "release audit", agent: "claude-code", limit: 20)
        try expectEqual(knowledge.generatedBy, "local-v2.52", "Knowledge RPC wrapper should decode successful results.")

        let observability = try await client.providerObservability()
        try expectEqual(observability.generatedBy, "local-v2.64", "LLM RPC wrapper should decode provider observability.")

        let remediation = try await client.planRemediation(taskText: "Prepare local release audit work.", agent: "claude-code")
        try expectEqual(remediation.generatedBy, "local-v2.56", "Remediation RPC wrapper should decode plan results.")

        let cockpit = try await client.buildTaskCockpit(taskText: "Prepare local release audit work.", agent: "claude-code")
        try expectEqual(cockpit.generatedBy, "local-v2.73", "Task RPC wrapper should decode cockpit results.")

        let calls = fake.calls()
        try expectContains(calls, "catalog.listFindings", "Catalog/config wrapper should call the catalog method.")
        try expectContains(calls, "evidence.previewMcpServers", "Evidence wrapper should call the evidence method.")
        try expectContains(calls, "session.previewLocalSessions", "Session wrapper should call the session method.")
        try expectContains(calls, #""auto_discover":true"#, "Session preview should request auto-discovery when no roots are supplied.")
        try expectContains(calls, "knowledge.search", "Knowledge wrapper should call the knowledge method.")
        try expectContains(calls, "llm.providerObservability", "LLM wrapper should call the observability method.")
        try expectContains(calls, "remediation.plan", "Remediation wrapper should call the remediation method.")
        try expectContains(calls, "task.buildCockpit", "Task wrapper should call the task method.")

        try await taskCockpitProviderCallsUseFiveMinuteSidecarTimeout()
    }

    private func taskCockpitProviderCallsUseFiveMinuteSidecarTimeout() async throws {
        let runner = RecordingServiceProcessRunner()
        let client = ServiceClient(processRunner: runner, serviceURL: URL(fileURLWithPath: "/tmp/fake-service"))

        _ = try await client.previewPromptForTaskCockpit(
            taskText: "查看下阿里云 ALB 指标与错误情况",
            agents: ["claude-code", "codex"],
            instanceIDs: ["alb-skill"]
        )
        _ = try await client.confirmPromptAndSendForTaskCockpit(
            previewID: "prompt-preview-task",
            taskText: "查看下阿里云 ALB 指标与错误情况",
            agents: ["claude-code", "codex"],
            instanceIDs: ["alb-skill"]
        )

        try expectEqual(
            runner.timeoutMilliseconds,
            [300_000, 300_000],
            "Task Preflight provider preview and send should use the five-minute sidecar timeout."
        )
        try expectEqual(
            runner.methods,
            ["llm.previewPrompt", "llm.confirmPromptAndSend"],
            "Task Preflight should use the provider preview and confirmation methods."
        )
    }
}

private final class RecordingServiceProcessRunner: ServiceProcessRunning {
    private(set) var methods: [String] = []
    private(set) var timeoutMilliseconds: [Int?] = []

    func run(executableURL: URL, input: Data, timeoutNanoseconds: UInt64?) async throws -> Data {
        timeoutMilliseconds.append(timeoutNanoseconds.map { Int($0 / 1_000_000) })

        let object = try JSONSerialization.jsonObject(with: input) as? [String: Any]
        let method = object?["method"] as? String ?? ""
        methods.append(method)

        switch method {
        case "llm.previewPrompt":
            return Data(Self.previewResponse.utf8)
        case "llm.confirmPromptAndSend":
            return Data(Self.sendResponse.utf8)
        default:
            return Data(Self.unknownMethodResponse.utf8)
        }
    }

    private static let previewResponse = """
    {"id":"test","ok":true,"result":{"preview_id":"prompt-preview-task","request_kind":"task_cockpit","scope":"agents","prompt_scope":"Task Preflight","enabled":true,"provider":"openai-compatible","model":"gpt-test","destination_host":"llm.example.com","included_fields":[],"excluded_fields":[],"redaction":{"status":"redacted","summary":"ok","redacted_fields":[],"placeholders":[]},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"preview"}}
    """

    private static let sendResponse = """
    {"id":"test","ok":true,"result":{"preview_id":"prompt-preview-task","success":true,"status":"succeeded","message":"Provider response received.","output_text":"{}","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false}}
    """

    private static let unknownMethodResponse = """
    {"id":"test","ok":false,"error":{"code":"unknown_method","message":"unknown method"}}
    """
}
