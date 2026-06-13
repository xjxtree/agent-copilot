import Foundation
@testable import SkillsCopilot

struct GuidedCleanupFlowModelTests {
    func run() throws {
        try decodesGuidedCleanupFlowPayload()
        try decodesAliasesAndStringRows()
        try decodesGuidedCleanupRecordPayload()
    }

    private struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
        let id: String?
        let ok: Bool
        let result: ResultPayload?
    }

    private func decodesGuidedCleanupFlowPayload() throws {
        let data = Data(
            """
            {
              "id": "guided-1",
              "ok": true,
              "result": {
                "generated_by": "local-v2.67",
                "catalog_available": true,
                "filters": {
                  "task": "Prepare local release audit work.",
                  "agent": "claude-code",
                  "selected_skill_id": "beta",
                  "selected_skill_name": "Beta",
                  "selected_skill_agent": "claude-code",
                  "project_root": "<project-root>",
                  "current_cwd": "<project-cwd>",
                  "workspace": "Fixture Project",
                  "limit": "12",
                  "include_issue_groups": true,
                  "include_safe_next_actions": true,
                  "include_recorded_steps": true,
                  "include_evidence": true,
                  "include_safety_flags": true
                },
                "summary": {
                  "step_count": "2",
                  "issue_group_count": 1,
                  "safe_action_count": 2,
                  "recorded_step_count": 1,
                  "recommended_step_count": 1,
                  "gap_count": 1,
                  "blocker_count": 1,
                  "summary": "Review the permission finding, inspect impact, then record local metadata."
                },
                "flow_steps": [
                  {
                    "step_id": "step-review-permission",
                    "title": "Review network permission finding",
                    "kind": "finding_review",
                    "status": "preview_only",
                    "priority": "high",
                    "order": "1",
                    "action_label": "Open Findings and Fix Preview Drafts",
                    "safe_entry_method": "remediation.previewDrafts",
                    "existing_safe_method": "remediation.previewDrafts",
                    "safe_action_deep_link": {
                      "label": "Open Findings and Fix Preview Drafts",
                      "target": "analysis_action",
                      "detail_section": "analysis",
                      "method": "remediation.previewDrafts",
                      "trigger": "previewRemediationDrafts",
                      "preview_only": true,
                      "requires_confirmation": false,
                      "copy_only": true,
                      "can_apply": false,
                      "instance_ids": ["beta"],
                      "related_step_ids": ["step-review-permission"],
                      "evidence_refs": ["finding:permissions.network-declared"],
                      "safety_flags": ["provider not sent", "no write"]
                    },
                    "review_area": "Fix Preview Drafts",
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
                    "rationale": "Finding and draft preview both point to manual permission review.",
                    "detail": "No file write happens from Guided Cleanup.",
                    "recommended": true,
                    "app_local_record_only": true,
                    "evidence_refs": [{"title":"Finding","detail":"finding:permissions.network-declared"}],
                    "gap_notes": ["Codex route still lacks equivalent coverage."],
                    "blocker_notes": ["No apply/write path is exposed."],
                    "safety_flags": ["provider not sent", "metadata only", "no write"]
                  },
                  "Inspect impact preview"
                ],
                "issue_groups": [
                  {
                    "group_id": "group-permissions",
                    "title": "Permission clarity",
                    "category": "finding",
                    "severity": "high",
                    "status": "open",
                    "count": "1",
                    "summary": "One permission finding needs human review.",
                    "issue_refs": ["finding:permissions.network-declared"],
                    "safe_next_action_ids": ["open-fix-preview"],
                    "evidence_refs": ["finding:permissions.network-declared"],
                    "safety_flags": ["no write"]
                  }
                ],
                "safe_next_actions": [
                  {
                    "action_id": "open-fix-preview",
                    "title": "Open Fix Preview Drafts",
                    "kind": "existing_safe_entry",
                    "entry_method": "remediation.previewDrafts",
                    "review_area": "Fix Preview Drafts",
                    "detail": "Use the existing copy-only draft surface.",
                    "requires_preview": true,
                    "requires_confirmation": false,
                    "copy_only": true,
                    "requires_existing_safe_entry": true,
                    "app_local_only": true,
                    "can_apply_fix": false,
                    "related_step_ids": ["step-review-permission"],
                    "deep_link": {
                      "label": "Open Fix Preview Drafts",
                      "target": "analysis_action",
                      "detail_section": "analysis",
                      "method": "remediation.previewDrafts",
                      "trigger": "previewRemediationDrafts",
                      "preview_only": true,
                      "requires_confirmation": false,
                      "copy_only": true,
                      "can_apply": false,
                      "instance_ids": ["beta"],
                      "related_step_ids": ["step-review-permission"],
                      "evidence_refs": ["draft:permissions"],
                      "safety_flags": ["provider not sent", "no write"]
                    },
                    "evidence_refs": ["draft:permissions"]
                  },
                  "Open Remediation History"
                ],
                "recorded_steps": [
                  {
                    "record_id": "guided-record-1",
                    "step_id": "step-review-permission",
                    "title": "Permission review recorded",
                    "status": "recorded",
                    "decision": "reviewed",
                    "source_method": "cleanup.recordGuidedStep",
                    "recorded_at": "2026-06-12T08:00:00Z",
                    "note": "Metadata only.",
                    "metadata_redacted": true,
                    "app_local_only": true,
                    "evidence_refs": ["guided_step:step-review-permission"],
                    "safety_flags": ["app-local metadata only", "no write"]
                  }
                ],
                "gap_notes": ["Codex lacks project-scoped release audit coverage."],
                "blocker_notes": ["Actual edits remain in existing preview-first flows."],
                "evidence_references": [
                  {"title":"Guided cleanup","detail":"Derived from local cleanup/remediation evidence.","source":"cleanup.planGuidedFlow","agent":"claude-code"}
                ],
                "prompt_request": {"enabled":false,"request_kind":"guided_cleanup_flow","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},
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
                  "notes": ["provider not sent", "planning read-only"]
                }
              }
            }
            """.utf8
        )

        let envelope = try JSONDecoder().decode(ServiceEnvelope<GuidedCleanupFlowResult>.self, from: data)
        guard let result = envelope.result else {
            throw NativeModelTestFailure(description: "Guided cleanup envelope should include a result.")
        }

        try expectEqual(envelope.ok, true, "Guided cleanup envelope should decode ok.")
        try expectEqual(result.generatedBy, "local-v2.67", "Guided cleanup should decode generator metadata.")
        try expectEqual(result.filters.selectedSkillID, "beta", "Guided cleanup filters should decode selected skill id.")
        try expectEqual(result.filters.limit, 12, "Guided cleanup filters should decode string limits.")
        try expectEqual(result.summary.stepCount, 2, "Guided cleanup summary should decode step count.")
        try expectEqual(result.summary.issueGroupCount, 1, "Guided cleanup summary should decode issue group count.")
        try expectEqual(result.flowSteps.count, 2, "Guided cleanup should decode flow steps and string shorthand.")
        try expectEqual(result.flowSteps.first?.id, "step-review-permission", "Guided cleanup step should decode id.")
        try expectEqual(result.flowSteps.first?.skill?.skillName, "Beta", "Guided cleanup step should decode skill context.")
        try expectEqual(result.flowSteps.first?.recommended, true, "Guided cleanup should decode recommended step.")
        try expectEqual(result.flowSteps.first?.appLocalRecordOnly, true, "Guided cleanup should decode record-only state.")
        try expectEqual(result.flowSteps.first?.safeEntryMethod, "remediation.previewDrafts", "Guided cleanup step should decode existing safe entry method.")
        try expectEqual(result.flowSteps.first?.safeActionDeepLink.trigger, "previewRemediationDrafts", "Guided cleanup step should decode safe link trigger.")
        try expectEqual(result.flowSteps.first?.safeActionDeepLink.canApply, false, "Guided cleanup step safe link must remain non-applying.")
        try expectEqual(result.flowSteps.first?.safeActionDeepLink.copyOnly, true, "Guided cleanup step safe link should preserve copy-only draft semantics.")
        try expectEqual(result.recommendedStep?.id, "step-review-permission", "Guided cleanup should expose recommended step.")
        try expectEqual(result.issueGroups.first?.count, 1, "Guided cleanup issue groups should decode counts.")
        try expectEqual(result.safeNextActions.first?.canApplyFix, false, "Safe actions should decode no-apply fix flag.")
        try expectEqual(result.safeNextActions.first?.entryMethod, "remediation.previewDrafts", "Safe actions should decode the safe entry method.")
        try expectEqual(result.safeNextActions.first?.requiresPreview, true, "Safe actions should decode preview requirements.")
        try expectEqual(result.safeNextActions.first?.copyOnly, true, "Safe actions should decode copy-only requirements.")
        try expectEqual(result.safeNextActions.first?.relatedStepIDs, ["step-review-permission"], "Safe actions should decode related flow steps.")
        try expectEqual(result.safeNextActions.first?.deepLink.trigger, "previewRemediationDrafts", "Safe actions should decode deep link triggers.")
        try expectEqual(result.safeNextActions.first?.deepLink.canApply, false, "Safe action deep links must remain non-applying.")
        try expectEqual(result.recordedSteps.first?.sourceMethod, "cleanup.recordGuidedStep", "Recorded steps should decode source method.")
        try expectEqual(result.evidenceReferences.first?.source, "cleanup.planGuidedFlow", "Guided cleanup evidence should decode source.")
        try expectEqual(result.promptRequest?.requestKind, "guided_cleanup_flow", "Guided cleanup should decode prompt metadata.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Guided cleanup planning must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Guided cleanup planning must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Guided cleanup planning must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Guided cleanup planning must not allow script execution.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Guided cleanup planning must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Guided cleanup planning must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Guided cleanup planning must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Guided cleanup planning must not access credentials.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Guided cleanup planning must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Guided cleanup planning must not emit telemetry.")
    }

    private func decodesAliasesAndStringRows() throws {
        let json = """
        {
          "generatedBy": "local-v2.67",
          "catalogAvailable": "true",
          "filters": {"user_intent":"Review docs","agents":"codex","selectedSkillID":"alpha","selectedSkillName":"Alpha","selectedSkillAgent":"codex","projectRoot":"<project-root>","limit":5,"includeIssueGroups":"yes","includeSafeNextActions":1,"includeRecordedSteps":"enabled","includeEvidence":true,"includeSafetyFlags":true},
          "summary": "Guided alias summary.",
          "steps": "Review docs finding",
          "groups": "Docs issue group",
          "actions": "Open Knowledge Search",
          "records": "Docs metadata recorded",
          "gaps": "No fresh docs trace.",
          "blockers": "No automatic write/apply path.",
          "evidence": ["guided evidence"],
          "promptMetadata": {"available":false,"kind":"guided_alias","draft_copy_only":true},
          "safety": ["provider not sent", "no write"]
        }
        """

        let result = try JSONDecoder().decode(GuidedCleanupFlowResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.67", "GeneratedBy alias should decode.")
        try expectEqual(result.catalogAvailable, true, "CatalogAvailable alias should decode string booleans.")
        try expectEqual(result.filters.agents, ["codex"], "Guided cleanup filters should accept single agent strings.")
        try expectEqual(result.filters.selectedSkillID, "alpha", "Guided cleanup filters should decode camelCase selected skill id.")
        try expectEqual(result.summary.summaryText, "Guided alias summary.", "Guided cleanup summary should accept strings.")
        try expectEqual(result.flowSteps.first?.title, "Review docs finding", "Guided cleanup steps alias should decode string rows.")
        try expectEqual(result.issueGroups.first?.title, "Docs issue group", "Guided cleanup groups alias should decode string rows.")
        try expectEqual(result.safeNextActions.first?.title, "Open Knowledge Search", "Guided cleanup actions alias should decode string rows.")
        try expectEqual(result.recordedSteps.first?.title, "Docs metadata recorded", "Guided cleanup records alias should decode string rows.")
        try expectEqual(result.evidenceReferences.first?.detail, "guided evidence", "Guided cleanup evidence alias should accept strings.")
        try expectEqual(result.promptRequest?.requestKind, "guided_alias", "Guided cleanup prompt aliases should decode.")
        try expectEqual(result.safetyFlags.notes, ["provider not sent", "no write"], "Guided cleanup safety aliases should accept string arrays.")
    }

    private func decodesGuidedCleanupRecordPayload() throws {
        let json = """
        {
          "recorded": true,
          "generated_by": "local-v2.67",
          "app_local_only": true,
          "metadata_redacted": true,
          "record": {
            "record_id": "guided-record-native",
            "step_id": "step-review-permission",
            "title": "Native guided cleanup metadata",
            "status": "recorded",
            "decision": "reviewed",
            "source_method": "analysis.guidedCleanupFlow.ui",
            "recorded_at": "2026-06-12T08:05:00Z",
            "note": "Recorded app-local metadata only; no cleanup was applied.",
            "metadata_redacted": true,
            "app_local_only": true,
            "evidence_refs": ["guided_step:step-review-permission"],
            "safety_flags": ["app-local metadata only", "no write", "provider not sent"]
          },
          "summary": {"recorded_step_count": 1, "summary": "Recorded one guided cleanup step."},
          "message": "Guided cleanup metadata recorded.",
          "evidence_references": [{"title":"Guided record","detail":"Stored app-local metadata only.","source":"cleanup.recordGuidedStep"}],
          "prompt_request": {"enabled":false,"request_kind":"guided_cleanup_record","summary":"No provider request is sent.","draft_copy_only":true},
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
            "notes": ["app-local metadata only", "no write"]
          }
        }
        """

        let result = try JSONDecoder().decode(GuidedCleanupRecordStepResult.self, from: Data(json.utf8))
        try expectEqual(result.recorded, true, "Guided cleanup record should decode recorded status.")
        try expectEqual(result.generatedBy, "local-v2.67", "Guided cleanup record should decode generator metadata.")
        try expectEqual(result.appLocalOnly, true, "Guided cleanup record should decode app-local status.")
        try expectEqual(result.metadataRedacted, true, "Guided cleanup record should decode redaction status.")
        try expectEqual(result.record?.sourceMethod, "analysis.guidedCleanupFlow.ui", "Guided cleanup record should decode source method.")
        try expectEqual(result.record?.appLocalOnly, true, "Guided cleanup record row should decode app-local state.")
        try expectEqual(result.summary.recordedStepCount, 1, "Guided cleanup record should decode summary.")
        try expectEqual(result.evidenceReferences.first?.source, "cleanup.recordGuidedStep", "Guided cleanup record evidence should decode source.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Guided cleanup recording must not send provider requests.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Guided cleanup recording must not expose write actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Guided cleanup recording must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Guided cleanup recording must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Guided cleanup recording must not mutate triage.")
    }
}
