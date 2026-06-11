import Foundation
@testable import SkillsCopilot

struct RemediationHistoryModelTests {
    func run() throws {
        try decodesFlexibleRemediationHistoryPayload()
        try decodesRecordResultPayload()
    }

    private func decodesFlexibleRemediationHistoryPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.60",
          "catalog_available": true,
          "filters": {
            "task": "Prepare local release audit work.",
            "agent": "claude-code",
            "limit": "30",
            "rule_ids": "permissions.network-declared",
            "risk_levels": ["medium"],
            "decisions": ["reviewed"],
            "statuses": ["recorded"]
          },
          "summary": {
            "total_count": 2,
            "recorded_count": 2,
            "recurrence_count": 1,
            "reopened_count": 1,
            "readiness_improvement_count": 1,
            "decision_count": 1,
            "status_count": 1,
            "blocker_count": 1,
            "gap_count": 1,
            "summary": "Two local remediation history records are available."
          },
          "records": [
            {
              "record_id": "hist-1",
              "title": "Network permission reviewed",
              "category": "rule",
              "decision": "reviewed",
              "status": "recorded",
              "agent": "claude-code",
              "workspace": "Fixture Project",
              "rule_id": "permissions.network-declared",
              "risk_level": "medium",
              "task_text": "Prepare local release audit work.",
              "review_area": "Fix Preview Drafts",
              "source_method": "remediation.previewDrafts",
              "skill": {"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},
              "recurrence_count": 1,
              "reopened_count": 1,
              "readiness_improvement": "+8",
              "recorded_at": "2026-06-12T08:00:00Z",
              "rationale": "Finding and draft were reviewed locally.",
              "note": "Audit-only record.",
              "evidence_refs": ["finding:permissions.network-declared"],
              "gap_notes": ["Codex route still lacks coverage."],
              "blocker_notes": ["No apply path is exposed."],
              "safety_flags": ["local audit only", "no write"]
            }
          ],
          "decisions": ["reviewed"],
          "statuses": ["recorded"],
          "gap_notes": ["Workspace gap remains."],
          "blocker_notes": ["No direct write path."],
          "evidence_references": [{"title":"History","detail":"Derived from app-local records.","source":"remediation.listHistory","agent":"claude-code"}],
          "prompt_request": {"enabled":false,"request_kind":"remediation_history","summary":"Provider explanation is not sent.","draft_copy_only":true},
          "safety_flags": {"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["app-local history"]}
        }
        """

        let result = try JSONDecoder().decode(RemediationHistoryResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.60", "History should expose generator metadata.")
        try expectEqual(result.filters.limit, 30, "History filters should decode string limits.")
        try expectEqual(result.filters.ruleIDs, ["permissions.network-declared"], "History filters should decode single string rules.")
        try expectEqual(result.summary.recurrenceCount, 1, "History should expose recurrence counts.")
        try expectEqual(result.summary.reopenedCount, 1, "History should expose reopened counts.")
        try expectEqual(result.summary.readinessImprovementCount, 1, "History should expose readiness improvement counts.")
        try expectEqual(result.records.first?.skill?.skillName, "Beta", "History should expose affected skill evidence.")
        try expectEqual(result.records.first?.readinessImprovement, "+8", "History records should decode readiness improvement.")
        try expectEqual(result.evidenceReferences.first?.source, "remediation.listHistory", "History should expose evidence source.")
        try expectEqual(result.promptRequest?.requestKind, "remediation_history", "History should expose prompt metadata as disabled/copy-only.")
        try expectFalse(result.safetyFlags.providerRequestSent, "History list must not send provider requests.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "History list must not expose write actions.")
    }

    private func decodesRecordResultPayload() throws {
        let json = """
        {
          "recorded": true,
          "record": {
            "id": "hist-new",
            "title": "Native Analysis local audit",
            "category": "audit",
            "decision": "reviewed",
            "status": "recorded",
            "source_method": "analysis.remediationHistory.ui",
            "note": "Recorded local audit metadata only.",
            "safety_flags": ["local audit only", "no write"]
          },
          "summary": "Recorded one local audit entry.",
          "message": "Local remediation history recorded.",
          "evidence": ["history:hist-new"],
          "safety": {"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}
        }
        """

        let result = try JSONDecoder().decode(RemediationHistoryRecordResult.self, from: Data(json.utf8))
        try expectEqual(result.recorded, true, "Record result should expose recorded=true.")
        try expectEqual(result.record?.sourceMethod, "analysis.remediationHistory.ui", "Record result should expose source method.")
        try expectEqual(result.summary.summaryText, "Recorded one local audit entry.", "Record result should decode string summary.")
        try expectEqual(result.evidenceReferences.first?.detail, "history:hist-new", "Record result should decode string evidence.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Record history must not expose write actions.")
    }
}
