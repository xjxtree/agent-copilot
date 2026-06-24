@testable import SkillsCopilot

struct ServiceClientRPCTests {
    func run() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let client = ServiceClient()

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
    }
}
