import Foundation
@testable import SkillsCopilot

struct RemediationPlanModelTests {
    func run() throws {
        try decodesFlexibleRemediationPlanPayload()
        try decodesAliasRowsAndStringCollections()
    }

    private func decodesFlexibleRemediationPlanPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.56",
          "catalog_available": true,
          "filters": {
            "task": "Prepare local release audit work.",
            "agent": "claude-code",
            "project_root": "/tmp/project",
            "current_cwd": "/tmp/project",
            "workspace": "Fixture Project",
            "limit": "20",
            "include_guidance_only": true
          },
          "summary": {
            "total_count": 2,
            "critical_count": 0,
            "high_count": 1,
            "medium_count": 1,
            "low_count": 0,
            "quick_win_count": 1,
            "blocker_count": 1,
            "gap_count": 1,
            "ambiguity_count": 1,
            "drift_count": 1,
            "summary": "Review the missing Codex route before tuning duplicate audit skills."
          },
          "priority_rows": [
            {
              "id": "high",
              "priority": "high",
              "title": "High priority",
              "count": "1",
              "rationale": "Blocks release audit coverage.",
              "evidence_refs": ["finding:permissions.network-declared"]
            }
          ],
          "plan_items": [
            {
              "item_id": "plan-1",
              "title": "Add Codex release audit coverage",
              "priority": "high",
              "category": "gap",
              "status": "guidance_only",
              "agent": "codex",
              "capability": "Release audit",
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
              "rationale": "Workspace readiness reports no Codex project route.",
              "suggested_action": "Open Workspace Readiness and review the Codex gap.",
              "guidance_only": true,
              "next_area": "Workspace Readiness",
              "expected_impact": "Improves cross-agent readiness for release audit tasks.",
              "gap_notes": ["Codex lacks project-scoped audit coverage."],
              "blocker_notes": [],
              "evidence_refs": ["workspace:codex-gap"],
              "safety_flags": ["provider not sent", "guidance only"]
            }
          ],
          "gap_notes": ["Codex lacks a project-scoped release audit skill."],
          "blocker_notes": ["No automatic write/apply path is exposed."],
          "evidence_references": [{"title":"Remediation planner","detail":"Derived from local workspace readiness.","source":"remediation.plan","agent":"codex"}],
          "prompt_request": {"enabled":false,"request_kind":"remediation_plan","summary":"Provider explanation is not sent.","draft_copy_only":true},
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
            "notes": ["provider not sent", "guidance only"]
          }
        }
        """

        let result = try JSONDecoder().decode(RemediationPlanResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.56", "Remediation plan should decode generator metadata.")
        try expectEqual(result.filters.taskText, "Prepare local release audit work.", "Task filter should decode.")
        try expectEqual(result.filters.agents, ["claude-code"], "Agent alias should decode as filter array.")
        try expectEqual(result.filters.limit, 20, "String limit should decode.")
        try expectEqual(result.filters.includeGuidanceOnly, true, "Guidance-only filter should decode.")
        try expectEqual(result.summary.totalCount, 2, "Summary total should decode.")
        try expectEqual(result.summary.highCount, 1, "Summary high count should decode.")
        try expectEqual(result.priorityRows.first?.title, "High priority", "Priority rows should decode.")
        try expectEqual(result.priorityRows.first?.count, 1, "Priority row string count should decode.")
        try expectEqual(result.items.first?.title, "Add Codex release audit coverage", "Plan item title should decode.")
        try expectEqual(result.items.first?.skill?.skillName, "Beta", "Plan item skill should decode.")
        try expectEqual(result.items.first?.guidanceOnly, true, "Plan items must preserve guidance-only state.")
        try expectEqual(result.items.first?.nextArea, "Workspace Readiness", "Plan item next area should decode.")
        try expectEqual(result.gapNotes, ["Codex lacks a project-scoped release audit skill."], "Top-level gaps should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Remediation planner", "Evidence references should decode.")
        try expectEqual(result.promptRequest?.requestKind, "remediation_plan", "Prompt metadata should decode as disabled/copy-only metadata.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Remediation planning must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Remediation planning must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Remediation planning must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Remediation planning must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Remediation planning must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Remediation planning must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Remediation planning must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Remediation planning must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Remediation planning must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Remediation planning must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Remediation planning must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Remediation planning must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Remediation planning must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Remediation planning must not emit telemetry.")
    }

    private func decodesAliasRowsAndStringCollections() throws {
        let json = """
        {
          "generatedBy": "local-v2.56",
          "catalogAvailable": true,
          "filters": {"user_intent":"Review docs","agents":["codex"],"projectRoot":"/tmp/docs","limit":5},
          "summary": "Review gaps first.",
          "priorities": [{"level":"medium","label":"Medium items","items":["a","b"],"reason":"Two medium issues.","evidence":"priority evidence"}],
          "recommendations": [
            {
              "id": "docs-plan",
              "name": "Review docs skill drift",
              "severity": "medium",
              "kind": "stale_drift",
              "state": "guidance_only",
              "agent": "codex",
              "capability_name": "Docs review",
              "action": "Open Stale / Drift Detection.",
              "read_only": true,
              "target_area": "Stale / Drift",
              "impact": "Clarifies drift before writing anything.",
              "gaps": "No fresh docs trace.",
              "blockers": "None.",
              "evidence": [{"title":"Drift","detail":"Fingerprint changed.","source":"analysis.detectStaleDrift"}],
              "safety": "provider not sent"
            }
          ],
          "gaps": "No fresh docs trace.",
          "blockers": "None.",
          "evidence": ["remediation evidence"],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(RemediationPlanResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.56", "GeneratedBy alias should decode.")
        try expectEqual(result.filters.taskText, "Review docs", "User intent alias should decode.")
        try expectEqual(result.summary.summaryText, "Review gaps first.", "String summary should decode.")
        try expectEqual(result.priorityRows.first?.priority, "medium", "Priority level alias should decode.")
        try expectEqual(result.priorityRows.first?.count, 2, "Priority item arrays should count.")
        try expectEqual(result.priorityRows.first?.evidenceRefs, ["priority evidence"], "Priority evidence string should decode.")
        try expectEqual(result.items.first?.title, "Review docs skill drift", "Recommendation alias should decode.")
        try expectEqual(result.items.first?.category, "stale_drift", "Kind alias should decode.")
        try expectEqual(result.items.first?.guidanceOnly, true, "Read-only alias should decode as guidance-only.")
        try expectEqual(result.items.first?.gapNotes, ["No fresh docs trace."], "Gap string should decode.")
        try expectEqual(result.items.first?.evidenceRefs, ["Fingerprint changed."], "Object evidence should decode to detail.")
        try expectEqual(result.evidenceReferences.first?.detail, "remediation evidence", "Top-level string evidence should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
