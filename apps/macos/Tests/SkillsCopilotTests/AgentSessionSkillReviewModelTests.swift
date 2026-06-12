import Foundation
@testable import SkillsCopilot

struct AgentSessionSkillReviewModelTests {
    func run() throws {
        try decodesFlexibleSessionReviewPayload()
        try decodesServiceWireSessionReviewPayload()
        try decodesListAndDeletePayloads()
    }

    private func decodesFlexibleSessionReviewPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.62",
          "catalog_available": true,
          "filters": {
            "task": "Ship a local skills audit.",
            "agent": "codex",
            "selected_skill_id": "codex-audit",
            "selected_skill_name": "audit",
            "expected_skill_names": "audit",
            "project_root": "/tmp/project",
            "current_cwd": "/tmp/project",
            "workspace": "Fixture Project",
            "limit": "20",
            "transcript_provided": true
          },
          "summary": {
            "review_count": 1,
            "detected_skill_count": 2,
            "expected_skill_count": 1,
            "interference_count": 1,
            "safe_next_step_count": 2,
            "safety_flag_count": 3,
            "summary": "The session used the expected audit skill with one interference signal."
          },
          "review": {
            "review_id": "session-review-1",
            "title": "Audit session",
            "agent": "codex",
            "task_text": "Ship a local skills audit.",
            "outcome": "matched",
            "summary": "Expected skill was selected; a similarly named Claude skill appeared in context.",
            "reasons": ["Expected skill invocation was present."],
            "detected_skills": [
              {"instance_id":"codex-audit","name":"audit","agent":"codex","definition_id":"def.audit"},
              "review"
            ],
            "expected_skill_names": ["audit"],
            "interference_signals": [
              {
                "signal_id": "same-name-claude",
                "title": "Same-name context",
                "severity": "medium",
                "category": "routing",
                "detail": "A Claude skill with a similar name was mentioned before selection.",
                "agent": "claude-code",
                "skill": {"instance_id":"claude-audit","name":"audit","agent":"claude-code"},
                "evidence_refs": ["trace:redacted:line-4"]
              }
            ],
            "safe_next_steps": ["Open Routing Confidence", "Compare same-name skills"],
            "safety_flags": ["app-local metadata", "provider not sent", "no write"],
            "evidence_references": [{"title":"Session","detail":"Derived from redacted transcript metadata.","source":"session.reviewAgentSkillUse","agent":"codex"}],
            "redacted_excerpt": "[REDACTED_HOME]/project: use audit skill",
            "safety": {
              "provider_request_sent": false,
              "write_back_allowed": false,
              "write_actions_available": false,
              "script_execution_allowed": false,
              "execution_actions_available": false,
              "config_mutation_allowed": false,
              "snapshot_created": false,
              "triage_mutation_allowed": false,
              "credential_accessed": false,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false,
              "raw_trace_persisted": false,
              "cloud_sync_enabled": false,
              "telemetry_enabled": false,
              "raw_secret_returned": false,
              "notes": ["copy-only review"]
            },
            "created_at": "2026-06-12T09:00:00Z"
          },
          "safe_next_step_labels": "Open Agent Session Skill Review",
          "interference": "Same-name context",
          "evidence": ["session:review:1"],
          "prompt_request": {"enabled":false,"request_kind":"agent_session_skill_review","summary":"Provider explanation is not sent.","draft_copy_only":true},
          "safety_flags": {"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false}
        }
        """

        let result = try JSONDecoder().decode(AgentSessionSkillReviewResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.62", "Session review should decode generator metadata.")
        try expectEqual(result.filters.taskText, "Ship a local skills audit.", "Task filter should decode.")
        try expectEqual(result.filters.expectedSkillNames, ["audit"], "String expected skill names should decode as array.")
        try expectEqual(result.filters.limit, 20, "String limit should decode.")
        try expectEqual(result.filters.transcriptProvided, true, "Transcript provided flag should decode.")
        try expectEqual(result.summary.interferenceCount, 1, "Summary should expose interference count.")
        try expectEqual(result.review?.id, "session-review-1", "Nested review should decode.")
        try expectEqual(result.review?.outcome, "matched", "Review outcome should decode.")
        try expectEqual(result.review?.reasons, ["Expected skill invocation was present."], "Review reasons should decode.")
        try expectEqual(result.review?.detectedSkills.first?.definitionID, "def.audit", "Detected skill definition should decode.")
        try expectEqual(result.review?.detectedSkills.last?.name, "review", "String detected skill should decode.")
        try expectEqual(result.review?.expectedSkills.first?.name, "audit", "Expected skill name should decode.")
        try expectEqual(result.review?.interference.first?.skill?.agent, "claude-code", "Interference skill should decode.")
        try expectEqual(result.review?.safeNextSteps.first, "Open Routing Confidence", "Safe next steps should decode.")
        try expectEqual(result.review?.evidenceReferences.first?.source, "session.reviewAgentSkillUse", "Review evidence source should decode.")
        try expectEqual(result.safeNextSteps, ["Open Agent Session Skill Review"], "Top-level safe next steps should decode string alias.")
        try expectEqual(result.interference.first?.title, "Same-name context", "Top-level string interference should decode.")
        try expectEqual(result.promptRequest?.requestKind, "agent_session_skill_review", "Prompt metadata should stay disabled/copy-only.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Session review must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Session review must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Session review must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Session review must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Session review must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Session review must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Session review must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Session review must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Session review must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Session review must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Session review must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Session review must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Session review must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Session review must not emit telemetry.")
    }

    private func decodesServiceWireSessionReviewPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.62",
          "review": {
            "id": "agent-session-review-fixture",
            "title": "Agent session review fixture",
            "source_kind": "agent-session-transcript",
            "agent": "claude-code",
            "task": "fixture task",
            "trace_import_ids": ["trace-import-fixture"],
            "missing_trace_import_ids": [],
            "expected_skill_refs": ["fixture-skill-id"],
            "expected_skill_names": ["fixture-skill"],
            "excerpt": "Assistant selected fixture-skill-id.",
            "excerpt_char_count": 36,
            "content_hash": "fixture-content-hash",
            "redaction_summary": {
              "status": "clean",
              "redacted_value_count": 0,
              "redacted_fields": [],
              "placeholders": [],
              "raw_trace_persisted": false,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false,
              "raw_secret_returned": false
            },
            "reviewed_at": 1,
            "analysis": {
              "generated_by": "deterministic-service",
              "catalog_available": true,
              "outcome": "hit",
              "summary": "Session skill-use review outcome is hit.",
              "reasons": ["Detected expected local catalog skill."],
              "detected_skills": [
                {
                  "instance_id": "fixture-skill-id",
                  "definition_id": "fixture-definition-id",
                  "skill_name": "fixture-skill",
                  "agent": "claude-code",
                  "scope": "agent-global",
                  "evidence_refs": ["skill:fixture-skill-id"],
                  "match_terms": ["fixture-skill-id"]
                }
              ],
              "expected_skill_signals": [
                {
                  "kind": "skill_ref",
                  "value": "fixture-skill-id",
                  "matched": true,
                  "matched_instance_ids": ["fixture-skill-id"]
                }
              ],
              "referenced_traces": [
                {
                  "id": "trace-import-fixture",
                  "title": "Trace import fixture",
                  "outcome": "hit",
                  "imported_at": 1,
                  "detected_skill_count": 1,
                  "evidence_refs": ["skill:fixture-skill-id"]
                }
              ],
              "evidence_refs": ["skill:fixture-skill-id", "trace-import:trace-import-fixture"]
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
          },
          "count": 1,
          "app_local_only": true,
          "review_file": "agent-session-reviews.json",
          "provider_request_sent": false,
          "skill_files_mutated": false,
          "agent_config_mutated": false,
          "snapshot_created": false,
          "triage_mutated": false,
          "raw_prompt_persisted": false,
          "raw_response_persisted": false,
          "raw_trace_persisted": false
        }
        """

        let result = try JSONDecoder().decode(AgentSessionSkillReviewResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.62", "Service wire generator should decode.")
        try expectEqual(result.review?.id, "agent-session-review-fixture", "Service wire review id should decode.")
        try expectEqual(result.review?.outcome, "hit", "Service wire nested analysis outcome should decode.")
        try expectEqual(result.review?.summary, "Session skill-use review outcome is hit.", "Service wire nested analysis summary should decode.")
        try expectEqual(result.review?.reasons, ["Detected expected local catalog skill."], "Service wire nested analysis reasons should decode.")
        try expectEqual(result.review?.detectedSkills.first?.name, "fixture-skill", "Service wire trace detected skill_name should decode.")
        try expectEqual(result.review?.detectedSkills.first?.definitionID, "fixture-definition-id", "Service wire trace definition id should decode.")
        try expectEqual(result.review?.expectedSkills.first?.name, "fixture-skill", "Service wire expected skill names should decode.")
        try expectEqual(result.review?.evidenceReferences.last?.detail, "trace-import:trace-import-fixture", "Service wire string evidence refs should decode.")
        try expectEqual(result.review?.createdAt, "1", "Service wire numeric reviewed_at should decode without throwing.")
        try expectFalse(result.review?.safety.cloudSyncEnabled ?? true, "Service wire cloud_sync_performed alias should decode.")
        try expectFalse(result.review?.safety.telemetryEnabled ?? true, "Service wire telemetry_emitted alias should decode.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Top-level safety should inherit review safety when absent.")
    }

    private func decodesListAndDeletePayloads() throws {
        let listJSON = """
        {
          "generatedBy": "local-v2.62",
          "catalogAvailable": true,
          "filters": {"user_intent":"Review session","agents":["codex"],"expected_skills":["audit"],"transcript_text":"redacted excerpt"},
          "summary": "Two session reviews are stored locally.",
          "session_reviews": [
            {"session_review_id":"review-a","title":"A","status":"matched","detected_skill_names":"audit","safe_next_steps":"Open Details","safety_flags":["local metadata"]},
            "Fallback review"
          ],
          "evidence_references": ["session:list"],
          "safety_flags": ["provider not sent", "no write"]
        }
        """

        let list = try JSONDecoder().decode(AgentSessionSkillReviewListResult.self, from: Data(listJSON.utf8))
        try expectEqual(list.generatedBy, "local-v2.62", "GeneratedBy alias should decode.")
        try expectEqual(list.filters.taskText, "Review session", "User intent alias should decode.")
        try expectEqual(list.filters.transcriptProvided, true, "Transcript text should imply transcript provided.")
        try expectEqual(list.summary.summaryText, "Two session reviews are stored locally.", "String summary should decode.")
        try expectEqual(list.reviews.first?.id, "review-a", "List review ID should decode.")
        try expectEqual(list.reviews.first?.detectedSkills.first?.name, "audit", "List detected skill string should decode.")
        try expectEqual(list.reviews.first?.safeNextSteps, ["Open Details"], "List safe next step string should decode.")
        try expectEqual(list.reviews.last?.title, "Fallback review", "String review row should decode.")
        try expectEqual(list.evidenceReferences.first?.detail, "session:list", "String list evidence should decode.")
        try expectFalse(list.safetyFlags.providerRequestSent, "String safety flags must keep provider flag false.")

        let deleteJSON = """
        {"success":true,"session_review_id":"review-a"}
        """
        let delete = try JSONDecoder().decode(AgentSessionSkillReviewDeleteResult.self, from: Data(deleteJSON.utf8))
        try expectEqual(delete.deleted, true, "Delete success alias should decode.")
        try expectEqual(delete.reviewID, "review-a", "Delete review id alias should decode.")
    }
}
