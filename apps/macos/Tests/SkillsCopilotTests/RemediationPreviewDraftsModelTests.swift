import Foundation
@testable import SkillsCopilot

struct RemediationPreviewDraftsModelTests {
    func run() throws {
        try decodesFlexibleFixPreviewDraftPayload()
        try decodesAliasDraftRowsAndStringCollections()
    }

    private func decodesFlexibleFixPreviewDraftPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.57",
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
            "total_count": 2,
            "frontmatter_count": 1,
            "description_count": 0,
            "permissions_count": 1,
            "dependency_count": 0,
            "policy_count": 0,
            "blocker_count": 1,
            "copy_only_count": 2,
            "summary": "Two copy-only drafts are available."
          },
          "draft_items": [
            {
              "draft_id": "draft-frontmatter",
              "title": "Declare network permission",
              "draft_type": "frontmatter",
              "agent": "claude-code",
              "affected_skill": {
                "instance_id": "beta",
                "definition_id": "def.beta",
                "skill_name": "Beta",
                "agent": "claude-code",
                "scope": "agent-project",
                "enabled": true,
                "state": "loaded",
                "readiness_score": 78
              },
              "finding_id": "finding-beta",
              "rule_id": "permissions.network-declared",
              "current_text": "permissions: {}",
              "proposed_text": "permissions:\\n  network: true",
              "rationale": "Finding reports undeclared network access.",
              "confidence_score": "82",
              "confidence_band": "High",
              "copy_label": "Copy YAML",
              "edit_guidance": "Paste into frontmatter after review.",
              "evidence_refs": ["finding:permissions.network-declared"],
              "blocker_notes": ["Review network intent before editing."],
              "safety_flags": ["copy only", "provider not sent"]
            }
          ],
          "gap_notes": ["No dependency draft needed."],
          "blocker_notes": ["No automatic write/apply path is exposed."],
          "evidence_references": [{"title":"Fix preview","detail":"Derived from local findings.","source":"remediation.previewDrafts","agent":"claude-code"}],
          "prompt_request": {"enabled":false,"request_kind":"remediation_preview_drafts","summary":"Provider explanation is not sent.","draft_copy_only":true},
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
            "notes": ["provider not sent", "copy only"]
          }
        }
        """

        let result = try JSONDecoder().decode(RemediationPreviewDraftsResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.57", "Fix preview drafts should decode generator metadata.")
        try expectEqual(result.filters.taskText, "Prepare local release audit work.", "Task filter should decode.")
        try expectEqual(result.filters.agents, ["claude-code"], "Agent alias should decode as filter array.")
        try expectEqual(result.filters.limit, 20, "String limit should decode.")
        try expectEqual(result.summary.totalCount, 2, "Summary total should decode.")
        try expectEqual(result.summary.frontmatterCount, 1, "Frontmatter count should decode.")
        try expectEqual(result.summary.permissionsCount, 1, "Permissions count should decode.")
        try expectEqual(result.summary.copyOnlyCount, 2, "Copy-only count should decode.")
        try expectEqual(result.draftItems.first?.id, "draft-frontmatter", "Draft id should decode.")
        try expectEqual(result.draftItems.first?.draftType, "frontmatter", "Draft type should decode.")
        try expectEqual(result.draftItems.first?.affectedSkill?.skillName, "Beta", "Affected skill should decode.")
        try expectEqual(result.draftItems.first?.ruleID, "permissions.network-declared", "Rule id should decode.")
        try expectEqual(result.draftItems.first?.proposedText, "permissions:\n  network: true", "Proposed text should decode.")
        try expectEqual(result.draftItems.first?.confidenceScore, 82, "String confidence should decode.")
        try expectEqual(result.draftItems.first?.copyLabel, "Copy YAML", "Copy label should decode.")
        try expectEqual(result.draftItems.first?.editGuidance, "Paste into frontmatter after review.", "Edit guidance should decode.")
        try expectEqual(result.gapNotes, ["No dependency draft needed."], "Top-level gaps should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Fix preview", "Evidence references should decode.")
        try expectEqual(result.promptRequest?.requestKind, "remediation_preview_drafts", "Prompt metadata should decode as disabled/copy-only metadata.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Fix preview drafts must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Fix preview drafts must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Fix preview drafts must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Fix preview drafts must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Fix preview drafts must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Fix preview drafts must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Fix preview drafts must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Fix preview drafts must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Fix preview drafts must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Fix preview drafts must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Fix preview drafts must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Fix preview drafts must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Fix preview drafts must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Fix preview drafts must not emit telemetry.")
    }

    private func decodesAliasDraftRowsAndStringCollections() throws {
        let json = """
        {
          "generatedBy": "local-v2.57",
          "catalogAvailable": true,
          "filters": {"user_intent":"Review docs","agents":["codex"],"projectRoot":"/tmp/docs","limit":5},
          "summary": "Review copy-only drafts.",
          "drafts": [
            {
              "id": "policy-draft",
              "name": "Clarify human confirmation",
              "kind": "policy",
              "agent": "codex",
              "skill_ref": {
                "instance_id": "gamma",
                "definition_id": "codex:gamma",
                "skill_name": "Gamma",
                "scope": "agent-global",
                "state": "loaded",
                "enabled": true
              },
              "finding": "finding-gamma",
              "rule": "permissions.exec-needs-human",
              "before": "Run commands automatically.",
              "proposed_patch": "- Run commands automatically.\\n+ Ask the user to confirm before running commands.",
              "reason": "Execution-capable guidance needs human confirmation.",
              "confidence": 74,
              "band": "Medium",
              "copy_action": "Copy patch",
              "guidance": "Review in SKILL.md.",
              "evidence": [{"title":"Finding","detail":"Execution policy warning.","source":"findings"}],
              "blockers": "Manual review required.",
              "safety": "copy only"
            }
          ],
          "gaps": "No description draft.",
          "blockers": "No automatic write/apply path.",
          "evidence": ["fix preview evidence"],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(RemediationPreviewDraftsResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.57", "GeneratedBy alias should decode.")
        try expectEqual(result.filters.taskText, "Review docs", "User intent alias should decode.")
        try expectEqual(result.summary.summaryText, "Review copy-only drafts.", "String summary should decode.")
        try expectEqual(result.draftItems.first?.title, "Clarify human confirmation", "Draft name alias should decode.")
        try expectEqual(result.draftItems.first?.draftType, "policy", "Draft kind alias should decode.")
        try expectEqual(result.draftItems.first?.affectedSkill?.skillName, "Gamma", "Skill ref alias should decode.")
        try expectEqual(result.draftItems.first?.proposedText, "- Run commands automatically.\n+ Ask the user to confirm before running commands.", "Patch alias should decode as proposed text.")
        try expectEqual(result.draftItems.first?.evidenceRefs, ["Execution policy warning."], "Object evidence should decode to detail.")
        try expectEqual(result.draftItems.first?.blockerNotes, ["Manual review required."], "Blocker string should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "fix preview evidence", "Top-level string evidence should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
