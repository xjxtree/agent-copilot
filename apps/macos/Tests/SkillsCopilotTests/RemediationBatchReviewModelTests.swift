import Foundation
@testable import SkillsCopilot

struct RemediationBatchReviewModelTests {
    func run() throws {
        try decodesFlexibleBatchReviewPayload()
        try decodesAliasRowsAndStringCollections()
    }

    private func decodesFlexibleBatchReviewPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.59",
          "catalog_available": true,
          "filters": {
            "task": "Prepare local release audit work.",
            "agent": "claude-code",
            "project_root": "/tmp/project",
            "current_cwd": "/tmp/project",
            "workspace": "Fixture Project",
            "limit": "30",
            "review_dimensions": ["task", "risk", "rule", "agent", "workspace"],
            "risk_levels": ["medium", "high"],
            "rule_ids": ["permissions.network-declared"],
            "include_blocked": true
          },
          "summary": {
            "total_count": 3,
            "group_count": 2,
            "task_count": 1,
            "risk_count": 1,
            "rule_count": 1,
            "agent_count": 1,
            "workspace_count": 1,
            "blocker_count": 1,
            "gap_count": 1,
            "safe_next_step_count": 2,
            "summary": "Batch review groups remediation candidates before any write-capable flow."
          },
          "review_groups": [
            {
              "group_id": "risk-rules",
              "title": "Risk and rule review",
              "category": "risk_rule",
              "priority": "high",
              "summary": "Review permission findings before any manual edit.",
              "safe_next_step_labels": ["Open Findings", "Open Fix Preview Drafts"],
              "items": [
                {
                  "item_id": "rule-network",
                  "title": "Network permission declaration",
                  "category": "rule",
                  "priority": "high",
                  "status": "preview_only",
                  "agent": "claude-code",
                  "workspace": "Fixture Project",
                  "rule_id": "permissions.network-declared",
                  "risk_level": "medium",
                  "task_text": "Prepare local release audit work.",
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
                  "rationale": "Finding and draft preview both point to manual permission review.",
                  "safe_next_step_label": "Open Fix Preview Drafts",
                  "review_area": "Fix Preview Drafts",
                  "evidence_refs": ["finding:permissions.network-declared"],
                  "gap_notes": ["Codex route still lacks equivalent coverage."],
                  "blocker_notes": ["No apply/write path is exposed."],
                  "safety_flags": ["provider not sent", "preview only", "no write"]
                }
              ],
              "evidence_refs": ["finding:permissions.network-declared"],
              "gap_notes": ["Codex route still lacks equivalent coverage."],
              "blocker_notes": ["No apply/write path is exposed."],
              "safety_flags": ["preview only"]
            }
          ],
          "review_items": [
            {
              "item_id": "workspace-codex",
              "title": "Codex workspace gap",
              "category": "workspace",
              "priority": "medium",
              "status": "preview_only",
              "agent": "codex",
              "workspace": "Fixture Project",
              "rationale": "Workspace readiness reports a partial Codex route.",
              "safe_next_step_label": "Open Workspace Readiness",
              "review_area": "Workspace Readiness",
              "evidence_refs": ["workspace:codex-gap"]
            }
          ],
          "safe_next_step_labels": ["Open Remediation Planner", "Open Impact Preview"],
          "gap_notes": ["Codex lacks project-scoped release audit coverage."],
          "blocker_notes": ["No batch apply path is available from review."],
          "evidence_references": [{"title":"Batch review","detail":"Derived from local remediation evidence.","source":"remediation.batchReview","agent":"claude-code"}],
          "prompt_request": {"enabled":false,"request_kind":"remediation_batch_review","summary":"Provider explanation is not sent.","draft_copy_only":true},
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

        let result = try JSONDecoder().decode(RemediationBatchReviewResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.59", "Batch review should decode generator metadata.")
        try expectEqual(result.filters.taskText, "Prepare local release audit work.", "Batch review should decode task filter.")
        try expectEqual(result.filters.agents, ["claude-code"], "Agent alias should decode as filter array.")
        try expectEqual(result.filters.limit, 30, "String limit should decode.")
        try expectEqual(result.filters.dimensions, ["task", "risk", "rule", "agent", "workspace"], "Review dimensions should decode.")
        try expectEqual(result.filters.riskLevels, ["medium", "high"], "Risk levels should decode.")
        try expectEqual(result.filters.ruleIDs, ["permissions.network-declared"], "Rule IDs should decode.")
        try expectEqual(result.filters.includeBlocked, true, "Include blocked flag should decode.")
        try expectEqual(result.summary.totalCount, 3, "Summary total should decode.")
        try expectEqual(result.summary.groupCount, 2, "Summary group count should decode.")
        try expectEqual(result.groups.first?.title, "Risk and rule review", "Review groups should decode.")
        try expectEqual(result.groups.first?.safeNextStepLabels, ["Open Findings", "Open Fix Preview Drafts"], "Group next steps should decode.")
        try expectEqual(result.groups.first?.items.first?.ruleID, "permissions.network-declared", "Nested item rule should decode.")
        try expectEqual(result.groups.first?.items.first?.skill?.skillName, "Beta", "Nested item skill should decode.")
        try expectEqual(result.items.first?.reviewArea, "Workspace Readiness", "Top-level item review area should decode.")
        try expectEqual(result.safeNextStepLabels, ["Open Remediation Planner", "Open Impact Preview"], "Top-level next steps should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Batch review", "Evidence references should decode.")
        try expectEqual(result.promptRequest?.requestKind, "remediation_batch_review", "Prompt metadata should stay disabled/copy-only.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Batch review must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Batch review must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Batch review must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Batch review must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Batch review must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Batch review must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Batch review must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Batch review must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Batch review must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Batch review must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Batch review must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Batch review must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Batch review must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Batch review must not emit telemetry.")
    }

    private func decodesAliasRowsAndStringCollections() throws {
        let json = """
        {
          "generatedBy": "local-v2.59",
          "catalogAvailable": true,
          "filters": {"user_intent":"Review docs","agents":["codex"],"projectRoot":"/tmp/docs","limit":5,"dimensions":"task","risks":"low","rules":"body.too-long","includeBlocked":false},
          "summary": "Review batch before writing anything.",
          "groups": "Docs review group.",
          "rows": "Docs review item.",
          "safe_next_steps": "Open Knowledge Search",
          "gaps": "No fresh docs trace.",
          "blockers": "No automatic write/apply path.",
          "evidence": ["batch evidence"],
          "safety_flags": ["provider not sent", "no write"]
        }
        """

        let result = try JSONDecoder().decode(RemediationBatchReviewResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.59", "GeneratedBy alias should decode.")
        try expectEqual(result.filters.taskText, "Review docs", "User intent alias should decode.")
        try expectEqual(result.filters.dimensions, ["task"], "String dimensions should decode.")
        try expectEqual(result.filters.riskLevels, ["low"], "String risks should decode.")
        try expectEqual(result.filters.ruleIDs, ["body.too-long"], "String rules should decode.")
        try expectFalse(result.filters.includeBlocked, "IncludeBlocked alias should decode.")
        try expectEqual(result.summary.summaryText, "Review batch before writing anything.", "String summary should decode.")
        try expectEqual(result.groups.first?.title, "Docs review group.", "String group should decode to group row.")
        try expectEqual(result.items.first?.title, "Docs review item.", "String item should decode to item row.")
        try expectEqual(result.safeNextStepLabels, ["Open Knowledge Search"], "String safe next steps should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "batch evidence", "Top-level string evidence should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
