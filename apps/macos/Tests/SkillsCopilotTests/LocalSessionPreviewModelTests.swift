import Foundation
@testable import SkillsCopilot

struct LocalSessionPreviewModelTests {
    func run() throws {
        try previewDecodesRedactedRowsAndSafety()
        try unavailableKeepsAuthorizationRequired()
    }

    private func previewDecodesRedactedRowsAndSafety() throws {
        let payload = """
        {
          "generated_by": "local-v2.87",
          "authorized": true,
          "authorization_required": false,
          "roots": [{"root":"$HOME/.codex/sessions","status":"authorized-read-only","candidate_count":1}],
          "count": 1,
          "total_candidate_count": 1,
          "session_rows": [{
            "id": "local-session-fixture",
            "title": "fixture",
            "source_kind": "authorized-local-session",
            "agent": "codex",
            "redacted_path": "$HOME/.codex/sessions/fixture.jsonl",
            "excerpt": "Used fixture-skill-id with <redacted>.",
            "excerpt_char_count": 38,
            "content_hash": "fixturehash",
            "evidence_refs": ["session.path:$HOME/.codex/sessions/fixture.jsonl"]
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

        let result = try JSONDecoder().decode(LocalSessionPreviewResult.self, from: Data(payload.utf8))
        try expectEqual(result.generatedBy, "local-v2.87", "Local session preview generator")
        try expectEqual(result.authorizationRequired, false, "Authorized preview should not require more authorization.")
        try expectEqual(result.sessionRows.first?.agent, "codex", "Agent should decode from preview row.")
        try expectEqual(result.sessionRows.first?.evidenceRefs.count, 1, "Evidence refs should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Preview should not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Preview should not enable writes.")
        try expectFalse(result.redactionSummary.rawTracePersisted, "Preview redaction summary should forbid raw trace persistence.")
    }

    private func unavailableKeepsAuthorizationRequired() throws {
        let result = LocalSessionPreviewResult.unavailable(reason: "missing method")
        try expectEqual(result.authorizationRequired, true, "Unavailable preview should remain default-off.")
        try expectEqual(result.sessionRows.count, 0, "Unavailable preview should not synthesize rows.")
    }
}
