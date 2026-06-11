import Foundation
@testable import SkillsCopilot

struct WorkspaceReadinessModelTests {
    func run() throws {
        try decodesFlexibleWorkspaceReadinessPayload()
        try decodesAliasChecklistAndCapabilityRows()
    }

    private func decodesFlexibleWorkspaceReadinessPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.55",
          "catalog_available": true,
          "filters": {
            "task": "Prepare local release audit work.",
            "agent": "claude-code",
            "project_root": "/tmp/project",
            "current_cwd": "/tmp/project",
            "workspace": "Fixture Project",
            "limit": "40"
          },
          "summary": {
            "overall_state": "partial",
            "readiness_score": 78,
            "checklist_count": 2,
            "ready_count": 1,
            "partial_count": 1,
            "blocked_count": 0,
            "agent_count": 2,
            "capability_count": 2,
            "gap_count": 1,
            "blocker_count": 0,
            "summary": "Workspace is partially ready for release audit work."
          },
          "checklist_rows": [
            {
              "check_id": "release-audit",
              "title": "Release audit skill enabled",
              "status": "ready",
              "severity": "info",
              "agent": "claude-code",
              "capability": "Release audit",
              "summary": "Beta is enabled and project scoped.",
              "required_skills": ["Beta"],
              "matched_skills": [
                {
                  "instance_id": "beta",
                  "definition_id": "def.beta",
                  "skill_name": "Beta",
                  "agent": "claude-code",
                  "scope": "agent-project",
                  "enabled": true,
                  "state": "loaded",
                  "quality_score": 82,
                  "readiness_score": 78,
                  "reasons": ["Project-scoped audit coverage."],
                  "evidence_refs": ["catalog:beta"],
                  "safety_flags": ["provider not sent"]
                }
              ],
              "gaps": [],
              "blockers": [],
              "evidence_refs": ["catalog:beta"],
              "safety_flags": ["provider not sent"]
            }
          ],
          "agent_rows": [
            {
              "agent": "claude-code",
              "display_name": "Claude Code",
              "readiness_score": 86,
              "readiness_state": "ready",
              "enabled_skill_count": 3,
              "required_skill_count": 2,
              "matched_skill_count": 2,
              "gap_count": 0,
              "blocker_count": 0,
              "notes": ["Project skills are scoped correctly."],
              "evidence_refs": ["agent:claude-code"]
            }
          ],
          "capability_rows": [
            {
              "capability_id": "release-audit",
              "domain": "Release & Validation",
              "capability": "Release audit",
              "readiness_state": "partial",
              "readiness_score": 78,
              "agent_coverage": [{"agent":"claude-code","skill_count":2,"capability_count":1,"coverage_state":"covered"}],
              "representative_skills": [{"instance_id":"beta","skill_name":"Beta","agent":"claude-code"}],
              "gap_notes": ["No Codex route is enabled."],
              "blocker_notes": [],
              "evidence_refs": ["capability:release-audit"]
            }
          ],
          "gap_notes": ["Codex lacks a project-scoped release audit skill."],
          "blocker_notes": [],
          "evidence_references": [{"title":"Workspace readiness","detail":"Derived from local catalog evidence.","source":"workspace.checkReadiness","agent":"claude-code"}],
          "prompt_request": {"enabled":false,"request_kind":"workspace_readiness","summary":"Provider explanation is copy-only.","draft_copy_only":true},
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
            "notes": ["provider not sent"]
          }
        }
        """

        let result = try JSONDecoder().decode(WorkspaceReadinessResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.55", "Workspace readiness should decode generator metadata.")
        try expectEqual(result.filters.taskText, "Prepare local release audit work.", "Task filter should decode.")
        try expectEqual(result.filters.agents, ["claude-code"], "Agent alias should decode as filter array.")
        try expectEqual(result.filters.projectRoot, "/tmp/project", "Project root should decode.")
        try expectEqual(result.summary.overallState, "partial", "Summary should decode overall state.")
        try expectEqual(result.summary.readinessScore, 78, "Summary should decode readiness score.")
        try expectEqual(result.checklistRows.first?.title, "Release audit skill enabled", "Checklist title should decode.")
        try expectEqual(result.checklistRows.first?.matchedSkills.first?.skillName, "Beta", "Checklist matched skills should decode.")
        try expectEqual(result.agentRows.first?.displayName, "Claude Code", "Agent rows should decode display names.")
        try expectEqual(result.agentRows.first?.matchedSkillCount, 2, "Agent matched counts should decode.")
        try expectEqual(result.capabilityRows.first?.capability, "Release audit", "Capability rows should decode names.")
        try expectEqual(result.capabilityRows.first?.agentCoverage.first?.agent, "claude-code", "Capability coverage should decode.")
        try expectEqual(result.gapNotes, ["Codex lacks a project-scoped release audit skill."], "Top-level gaps should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Workspace readiness", "Evidence references should decode.")
        try expectEqual(result.promptRequest?.requestKind, "workspace_readiness", "Prompt metadata should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Workspace readiness must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Workspace readiness must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Workspace readiness must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Workspace readiness must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Workspace readiness must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Workspace readiness must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Workspace readiness must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Workspace readiness must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Workspace readiness must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Workspace readiness must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Workspace readiness must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Workspace readiness must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Workspace readiness must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Workspace readiness must not emit telemetry.")
    }

    private func decodesAliasChecklistAndCapabilityRows() throws {
        let json = """
        {
          "generatedBy": "local-v2.55",
          "catalogAvailable": true,
          "filters": {"user_intent":"Review docs","agents":["codex"],"projectRoot":"/tmp/docs","limit":5},
          "summary": "Workspace can review docs with partial coverage.",
          "checks": [
            {
              "id": "docs",
              "label": "Docs skill scoped",
              "state": "partial",
              "domain": "Documentation",
              "expected_skills": "Docs",
              "skills": ["Docs"],
              "evidence": [{"title":"Catalog","detail":"Docs evidence.","source":"catalog"}]
            }
          ],
          "agents": [
            {
              "name": "codex",
              "score": "71",
              "status": "partial",
              "enabled_skills": ["Docs"],
              "required_skills": ["Docs", "Review"],
              "matched_skills": ["Docs"],
              "gaps": ["Review"],
              "blockers": []
            }
          ],
          "capabilities": [
            {
              "capabilityId": "docs-review",
              "domain_name": "Documentation",
              "title": "Docs review",
              "coverage_state": "partial",
              "score": "71",
              "skills": ["Docs"],
              "gaps": "No review benchmark.",
              "evidence": "capability:docs-review"
            }
          ],
          "gaps": "No review benchmark.",
          "evidence": ["workspace evidence"],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(WorkspaceReadinessResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.55", "GeneratedBy alias should decode.")
        try expectEqual(result.filters.taskText, "Review docs", "User intent alias should decode.")
        try expectEqual(result.summary.summaryText, "Workspace can review docs with partial coverage.", "String summary should decode.")
        try expectEqual(result.checklistRows.first?.title, "Docs skill scoped", "Checklist label alias should decode.")
        try expectEqual(result.checklistRows.first?.requiredSkills, ["Docs"], "Expected skill string should decode.")
        try expectEqual(result.checklistRows.first?.matchedSkills.first?.skillName, "Docs", "String skill should decode through shared skill model.")
        try expectEqual(result.agentRows.first?.enabledSkillCount, 1, "Agent enabled skill arrays should count.")
        try expectEqual(result.agentRows.first?.requiredSkillCount, 2, "Agent required skill arrays should count.")
        try expectEqual(result.capabilityRows.first?.id, "docs-review", "CapabilityId alias should decode.")
        try expectEqual(result.capabilityRows.first?.gapNotes, ["No review benchmark."], "Capability gap string should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "workspace evidence", "String evidence should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
