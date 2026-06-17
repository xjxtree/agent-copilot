import Foundation
@testable import SkillsCopilot

struct McpServerPreviewModelTests {
    func run() throws {
        try previewDecodesRedactedServerRowsAndSafety()
        try unavailableKeepsAuthorizationRequired()
    }

    private func previewDecodesRedactedServerRowsAndSafety() throws {
        let payload = """
        {
          "generated_by": "local-v2.87",
          "authorized": true,
          "authorization_required": false,
          "evidence_available": true,
          "evidence_insufficient": false,
          "authorized_paths": [{"path":"$HOME/.config/agent/mcp.json","status":"authorized-read-only","server_count":1}],
          "count": 1,
          "server_rows": [{
            "id": "mcp-server-fixture",
            "name": "filesystem",
            "source_path": "$HOME/.config/agent/mcp.json",
            "transport": "stdio",
            "command": "$HOME/.local/bin/mcp-filesystem",
            "args_count": 2,
            "env_key_count": 1,
            "evidence_refs": ["mcp.server:filesystem"]
          }],
          "gap_notes": [],
          "blocker_notes": [],
          "redaction_summary": {
            "status": "redacted-local-only",
            "redacted_value_count": 2,
            "redacted_fields": ["local paths"],
            "raw_trace_persisted": false,
            "raw_prompt_persisted": false,
            "raw_response_persisted": false,
            "raw_secret_returned": false
          },
          "safety_flags": {
            "read_only": true,
            "app_local_only": true,
            "provider_request_sent": false,
            "write_back_allowed": false,
            "write_actions_available": false,
            "skill_files_mutated": false,
            "agent_config_mutated": false,
            "script_execution_allowed": false,
            "execution_actions_available": false,
            "config_mutation_allowed": false,
            "snapshot_created": false,
            "triage_mutation_allowed": false,
            "credential_accessed": false,
            "raw_secret_returned": false,
            "raw_prompt_persisted": false,
            "raw_response_persisted": false,
            "raw_trace_persisted": false,
            "cloud_sync_performed": false,
            "telemetry_emitted": false
          }
        }
        """

        let result = try JSONDecoder().decode(McpServerPreviewResult.self, from: Data(payload.utf8))
        try expectEqual(result.generatedBy, "local-v2.87", "MCP preview generator")
        try expectEqual(result.authorizationRequired, false, "Authorized preview should not require more authorization.")
        try expectEqual(result.evidenceAvailable, true, "MCP preview should mark evidence available.")
        try expectEqual(result.serverRows.first?.transport, "stdio", "Transport should decode.")
        try expectEqual(result.serverRows.first?.envKeyCount, 1, "Env key count should decode without env values.")
        try expectEqual(result.serverRows.first?.evidenceRefs.count, 1, "Evidence refs should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Preview should not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Preview should not enable writes.")
        try expectFalse(result.redactionSummary.rawTracePersisted, "Preview redaction summary should forbid raw trace persistence.")
    }

    private func unavailableKeepsAuthorizationRequired() throws {
        let result = McpServerPreviewResult.unavailable(reason: "missing method")
        try expectEqual(result.authorizationRequired, true, "Unavailable preview should remain default-off.")
        try expectEqual(result.serverRows.count, 0, "Unavailable preview should not synthesize rows.")
    }
}
