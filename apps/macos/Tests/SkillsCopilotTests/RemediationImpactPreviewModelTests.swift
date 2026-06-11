import Foundation
@testable import SkillsCopilot

struct RemediationImpactPreviewModelTests {
    func run() throws {
        try decodesFlexibleImpactPreviewPayload()
        try decodesAliasImpactRowsAndStringCollections()
    }

    private func decodesFlexibleImpactPreviewPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.58",
          "catalog_available": true,
          "filters": {
            "task": "Prepare local release audit work.",
            "agent": "claude-code",
            "project_root": "/tmp/project",
            "current_cwd": "/tmp/project",
            "workspace": "Fixture Project",
            "limit": "20"
          },
          "summary": {
            "total_count": 6,
            "task_impact_count": 1,
            "agent_impact_count": 1,
            "skill_impact_count": 1,
            "risk_delta_count": 1,
            "snapshot_rollback_count": 1,
            "blocker_count": 1,
            "gap_count": 1,
            "no_write_count": 1,
            "summary": "Impact preview is read-only and shows where remediation would improve routing confidence."
          },
          "impact_rows": [
            {
              "row_id": "impact-overall",
              "title": "Overall readiness improves",
              "category": "overall",
              "impact": "Improves release audit readiness without writing files.",
              "rationale": "Derived from remediation plan and workspace readiness.",
              "severity": "info",
              "evidence_refs": ["remediation:plan"],
              "safety_flags": ["provider not sent", "no write"]
            }
          ],
          "task_impact_rows": [
            {
              "row_id": "task-release-audit",
              "title": "Release audit route gets clearer",
              "category": "task",
              "before": "Partial",
              "after": "Ready",
              "delta": "+12 readiness",
              "impact": "The selected task has a stronger local route.",
              "rationale": "Routing confidence and workspace readiness both point to Beta.",
              "severity": "medium",
              "evidence_refs": ["task:release-audit"]
            }
          ],
          "agent_impact_rows": [
            {
              "row_id": "agent-claude",
              "title": "Claude Code remains the recommended agent",
              "category": "agent",
              "agent": "claude-code",
              "delta": "+8 comparison",
              "impact": "No cross-agent write path is needed.",
              "severity": "low"
            }
          ],
          "skill_impact_rows": [
            {
              "row_id": "skill-beta",
              "title": "Beta benefits from clearer permissions",
              "category": "skill",
              "agent": "claude-code",
              "skill": {
                "instance_id": "beta",
                "definition_id": "def.beta",
                "skill_name": "Beta",
                "agent": "claude-code",
                "scope": "agent-project",
                "enabled": true,
                "state": "loaded",
                "readiness_score": 78
              },
              "impact": "The permission finding would become easier to review.",
              "severity": "medium"
            }
          ],
          "risk_delta_rows": [
            {
              "row_id": "risk-network",
              "title": "Network declaration risk drops",
              "category": "risk_delta",
              "before": "Medium",
              "after": "Low",
              "delta": "-1 risk band",
              "impact": "Manual review remains required.",
              "severity": "warning"
            }
          ],
          "snapshot_rollback_rows": [
            {
              "row_id": "rollback-none",
              "title": "No snapshot is created",
              "category": "snapshot_rollback",
              "impact": "Rollback remains a plan note only because no write happens.",
              "severity": "info",
              "safety_flags": ["snapshot not created"]
            }
          ],
          "gap_notes": ["Codex still lacks project-scoped coverage."],
          "blocker_notes": ["No apply/write path is exposed."],
          "evidence_references": [{"title":"Impact preview","detail":"Derived from local remediation evidence.","source":"remediation.previewImpact","agent":"claude-code"}],
          "prompt_request": {"enabled":false,"request_kind":"remediation_preview_impact","summary":"Provider explanation is not sent.","draft_copy_only":true},
          "safety_flags": {
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
            "notes": ["provider not sent", "preview only", "no write"]
          }
        }
        """

        let result = try JSONDecoder().decode(RemediationImpactPreviewResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.58", "Impact preview should decode generator metadata.")
        try expectEqual(result.filters.taskText, "Prepare local release audit work.", "Task filter should decode.")
        try expectEqual(result.filters.agents, ["claude-code"], "Agent alias should decode as filter array.")
        try expectEqual(result.filters.limit, 20, "String limit should decode.")
        try expectEqual(result.summary.totalCount, 6, "Summary total should decode.")
        try expectEqual(result.summary.taskImpactCount, 1, "Task impact count should decode.")
        try expectEqual(result.summary.noWriteCount, 1, "No-write count should decode.")
        try expectEqual(result.impactRows.first?.title, "Overall readiness improves", "General impact rows should decode.")
        try expectEqual(result.taskImpactRows.first?.delta, "+12 readiness", "Task impact delta should decode.")
        try expectEqual(result.agentImpactRows.first?.agent, "claude-code", "Agent impact row should decode.")
        try expectEqual(result.skillImpactRows.first?.skill?.skillName, "Beta", "Skill impact row should decode referenced skill.")
        try expectEqual(result.riskDeltaRows.first?.before, "Medium", "Risk delta baseline should decode.")
        try expectEqual(result.snapshotRollbackRows.first?.title, "No snapshot is created", "Snapshot rollback row should decode.")
        try expectEqual(result.gapNotes, ["Codex still lacks project-scoped coverage."], "Top-level gaps should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Impact preview", "Evidence references should decode.")
        try expectEqual(result.promptRequest?.requestKind, "remediation_preview_impact", "Prompt metadata should decode as disabled/copy-only metadata.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Impact preview must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Impact preview must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Impact preview must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Impact preview must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Impact preview must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Impact preview must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Impact preview must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Impact preview must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Impact preview must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Impact preview must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Impact preview must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Impact preview must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Impact preview must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Impact preview must not emit telemetry.")
    }

    private func decodesAliasImpactRowsAndStringCollections() throws {
        let json = """
        {
          "generatedBy": "local-v2.58",
          "catalogAvailable": true,
          "filters": {"user_intent":"Review docs","agents":["codex"],"projectRoot":"/tmp/docs","limit":5},
          "summary": "Review impact before writing anything.",
          "impacts": "General impact note.",
          "task_impacts": [{"id":"task-docs","name":"Docs task improves","kind":"task","current":"Partial","target":"Ready","change":"+9","expected_impact":"Cleaner route.","reason":"Local evidence improves.","priority":"medium","evidence":[{"title":"Task","detail":"Readiness changed.","source":"task.checkReadiness"}],"safety":"preview only"}],
          "agent_impacts": "Codex remains partial.",
          "skill_impacts": "Skill wording impact.",
          "risk_deltas": "Risk remains manual-review only.",
          "snapshot_rollback": "No snapshot is created.",
          "gaps": "No fresh docs trace.",
          "blockers": "No automatic write/apply path.",
          "evidence": ["impact evidence"],
          "safety_flags": ["provider not sent", "no write"]
        }
        """

        let result = try JSONDecoder().decode(RemediationImpactPreviewResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.58", "GeneratedBy alias should decode.")
        try expectEqual(result.filters.taskText, "Review docs", "User intent alias should decode.")
        try expectEqual(result.summary.summaryText, "Review impact before writing anything.", "String summary should decode.")
        try expectEqual(result.impactRows.first?.title, "General impact note.", "String impact should decode to row.")
        try expectEqual(result.taskImpactRows.first?.title, "Docs task improves", "Task row name alias should decode.")
        try expectEqual(result.taskImpactRows.first?.before, "Partial", "Current alias should decode.")
        try expectEqual(result.taskImpactRows.first?.after, "Ready", "Target alias should decode.")
        try expectEqual(result.taskImpactRows.first?.delta, "+9", "Change alias should decode.")
        try expectEqual(result.taskImpactRows.first?.evidenceRefs, ["Readiness changed."], "Object evidence should decode to detail.")
        try expectEqual(result.agentImpactRows.first?.title, "Codex remains partial.", "String agent impact should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "impact evidence", "Top-level string evidence should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
