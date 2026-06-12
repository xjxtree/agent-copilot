import Foundation
@testable import SkillsCopilot

struct SkillLifecycleTimelineModelTests {
    func run() throws {
        try decodesRealisticLifecyclePayload()
        try decodesAliasesAndStringForms()
        try decodesServiceProtocolFixtureIfPresent()
    }

    private struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
        let id: String?
        let ok: Bool
        let result: ResultPayload?
    }

    private func decodesRealisticLifecyclePayload() throws {
        let data = Data(
            """
            {
              "id": "lifecycle-1",
              "ok": true,
              "result": {
                "generated_by": "local-v2.66",
                "catalog_available": true,
                "filters": {
                  "agent": "claude-code",
                  "selected_skill_id": "beta",
                  "selected_skill_name": "Beta",
                  "selected_skill_agent": "claude-code",
                  "project_root": "<project-root>",
                  "current_cwd": "<project-cwd>",
                  "workspace": "Fixture Project",
                  "limit": "20",
                  "include_skill_rows": true,
                  "include_agent_rows": true,
                  "include_evidence": true,
                  "include_safety_flags": true
                },
                "summary": {
                  "event_count": "3",
                  "skill_count": 1,
                  "agent_count": 1,
                  "event_type_count": 3,
                  "stage_count": 3,
                  "gap_count": 1,
                  "blocker_count": 1,
                  "evidence_count": 1,
                  "safety_flag_count": 1,
                  "first_event_at": "2026-06-10T09:00:00Z",
                  "latest_event_at": "2026-06-12T08:00:00Z",
                  "summary": "Beta lifecycle was reconstructed from local catalog, scan, routing, and remediation evidence."
                },
                "timeline_rows": [
                  {
                    "id": "life-scan-beta",
                    "occurred_at": "2026-06-10T09:00:00Z",
                    "event_type": "scan.detected",
                    "lifecycle_stage": "discovered",
                    "title": "Beta loaded from project root",
                    "summary": "Catalog scan detected the selected skill.",
                    "agent": "claude-code",
                    "skill_name": "Beta",
                    "instance_id": "beta",
                    "definition_id": "def.beta",
                    "source": "catalog.scanAll",
                    "severity": "info",
                    "status": "loaded",
                    "evidence_refs": [{"title":"Catalog","detail":"catalog:beta"}],
                    "safety_flags": ["provider not sent"]
                  },
                  "routing.selected"
                ],
                "skill_rows": [
                  {
                    "id": "skill-beta",
                    "event_type": "skill.aggregate",
                    "lifecycle_stage": "active",
                    "title": "Beta lifecycle",
                    "summary": "Three local lifecycle events reference Beta.",
                    "agent": "claude-code",
                    "skill_name": "Beta",
                    "instance_id": "beta",
                    "definition_id": "def.beta",
                    "source": "skill.lifecycleTimeline",
                    "status": "active",
                    "count": "3",
                    "evidence_refs": ["catalog:beta"],
                    "safety_flags": ["provider not sent"]
                  }
                ],
                "agent_rows": [
                  {
                    "id": "agent-claude",
                    "event_type": "agent.aggregate",
                    "lifecycle_stage": "active",
                    "title": "Claude Code lifecycle coverage",
                    "summary": "Claude Code has selected skill lifecycle evidence.",
                    "agent": "claude-code",
                    "source": "skill.lifecycleTimeline",
                    "status": "covered",
                    "count": 3,
                    "evidence_refs": ["agent:claude-code"],
                    "safety_flags": ["provider not sent"]
                  }
                ],
                "gap_notes": ["No Codex lifecycle evidence for this selected skill."],
                "blocker_notes": ["Lifecycle timeline is read-only and does not create snapshots."],
                "evidence_references": [
                  {"title":"Lifecycle timeline","detail":"Derived from local catalog and analysis evidence.","source":"skill.lifecycleTimeline","agent":"claude-code"}
                ],
                "prompt_request": {"enabled":false,"request_kind":"skill_lifecycle_timeline","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},
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
                  "notes": ["provider not sent", "read-only timeline"]
                }
              }
            }
            """.utf8
        )

        let envelope = try JSONDecoder().decode(ServiceEnvelope<SkillLifecycleTimelineResult>.self, from: data)
        guard let result = envelope.result else {
            throw NativeModelTestFailure(description: "Lifecycle timeline envelope should include a result.")
        }

        try expectEqual(envelope.ok, true, "Lifecycle timeline envelope should decode ok.")
        try expectEqual(result.generatedBy, "local-v2.66", "Lifecycle timeline should decode generator metadata.")
        try expectEqual(result.catalogAvailable, true, "Lifecycle timeline should decode catalog availability.")
        try expectEqual(result.filters.selectedSkillID, "beta", "Lifecycle timeline filters should decode selected skill id.")
        try expectEqual(result.filters.selectedSkillName, "Beta", "Lifecycle timeline filters should decode selected skill name.")
        try expectEqual(result.filters.selectedSkillAgent, "claude-code", "Lifecycle timeline filters should decode selected skill agent.")
        try expectEqual(result.filters.limit, 20, "Lifecycle timeline filters should decode string limits.")
        try expectEqual(result.filters.includeSkillRows, true, "Lifecycle timeline filters should decode include skill rows.")
        try expectEqual(result.filters.includeAgentRows, true, "Lifecycle timeline filters should decode include agent rows.")
        try expectEqual(result.filters.includeEvidence, true, "Lifecycle timeline filters should decode include evidence.")
        try expectEqual(result.filters.includeSafetyFlags, true, "Lifecycle timeline filters should decode include safety flags.")
        try expectEqual(result.summary.eventCount, 3, "Lifecycle timeline summary should decode event count.")
        try expectEqual(result.summary.skillCount, 1, "Lifecycle timeline summary should decode skill count.")
        try expectEqual(result.summary.agentCount, 1, "Lifecycle timeline summary should decode agent count.")
        try expectEqual(result.summary.latestEventAt, "2026-06-12T08:00:00Z", "Lifecycle timeline summary should decode latest event.")
        try expectEqual(result.timelineRows.count, 2, "Lifecycle timeline should decode rows and string shorthand.")
        try expectEqual(result.timelineRows.first?.title, "Beta loaded from project root", "Lifecycle row should decode title.")
        try expectEqual(result.timelineRows.first?.eventType, "scan.detected", "Lifecycle row should decode event type.")
        try expectEqual(result.timelineRows.first?.lifecycleStage, "discovered", "Lifecycle row should decode lifecycle stage.")
        try expectEqual(result.timelineRows.first?.skillName, "Beta", "Lifecycle row should decode skill name.")
        try expectEqual(result.timelineRows.first?.definitionID, "def.beta", "Lifecycle row should decode definition id.")
        try expectEqual(result.timelineRows.first?.evidenceRefs, ["catalog:beta"], "Lifecycle row evidence should accept objects.")
        try expectEqual(result.timelineRows[1].title, "routing.selected", "Lifecycle row should accept string shorthand.")
        try expectEqual(result.skillRows.first?.count, 3, "Lifecycle skill aggregate should decode string counts.")
        try expectEqual(result.skillRows.first?.status, "active", "Lifecycle skill aggregate should decode status.")
        try expectEqual(result.agentRows.first?.agent, "claude-code", "Lifecycle agent aggregate should decode agent.")
        try expectEqual(result.gapNotes.first, "No Codex lifecycle evidence for this selected skill.", "Lifecycle should decode gap notes.")
        try expectEqual(result.blockerNotes.first, "Lifecycle timeline is read-only and does not create snapshots.", "Lifecycle should decode blocker notes.")
        try expectEqual(result.evidenceReferences.first?.source, "skill.lifecycleTimeline", "Lifecycle should decode evidence source.")
        try expectEqual(result.promptRequest?.requestKind, "skill_lifecycle_timeline", "Lifecycle should decode prompt metadata.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Lifecycle must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Lifecycle must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Lifecycle must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Lifecycle must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Lifecycle must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Lifecycle must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Lifecycle must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Lifecycle must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Lifecycle must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Lifecycle must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Lifecycle must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Lifecycle must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Lifecycle must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Lifecycle must not emit telemetry.")
    }

    private func decodesAliasesAndStringForms() throws {
        let json = """
        {
          "generatedBy": "local-v2.66",
          "catalogAvailable": "true",
          "filters": {
            "agents": "codex",
            "selectedSkillID": "alpha",
            "selectedSkillName": "Alpha",
            "selectedSkillAgent": "codex",
            "projectRoot": "<project-root>",
            "currentCWD": "<project-cwd>",
            "workspace_id": "Fixture Workspace",
            "limit": 5,
            "includeSkillRows": "true",
            "includeAgentRows": "yes",
            "includeEvidence": 1,
            "includeSafetyFlags": "enabled"
          },
          "summary": "String summary works.",
          "events": ["scan.detected"],
          "skills": "Alpha aggregate",
          "agents": {"id":"agent-codex","kind":"agent.aggregate","stage":"active","title":"Codex coverage","agent":"codex","count":"1"},
          "gaps": "No session evidence.",
          "blockers": ["No apply path."],
          "evidence": ["lifecycle:evidence"],
          "promptMetadata": {"available":false,"kind":"lifecycle_alias","draft_copy_only":true},
          "safety": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(SkillLifecycleTimelineResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.66", "GeneratedBy alias should decode.")
        try expectEqual(result.catalogAvailable, true, "CatalogAvailable alias should decode string booleans.")
        try expectEqual(result.filters.agents, ["codex"], "Lifecycle filters should accept single agent strings.")
        try expectEqual(result.filters.selectedSkillID, "alpha", "Lifecycle filters should decode camelCase selected skill id.")
        try expectEqual(result.filters.workspace, "Fixture Workspace", "Lifecycle filters should decode workspace aliases.")
        try expectEqual(result.filters.includeSafetyFlags, true, "Lifecycle filters should decode string include safety flags.")
        try expectEqual(result.summary.summaryText, "String summary works.", "Lifecycle summary should accept strings.")
        try expectEqual(result.timelineRows.first?.title, "scan.detected", "Lifecycle events alias should decode string rows.")
        try expectEqual(result.skillRows.first?.title, "Alpha aggregate", "Lifecycle skills alias should decode string rows.")
        try expectEqual(result.agentRows.first?.agent, "codex", "Lifecycle agents alias should decode object rows.")
        try expectEqual(result.agentRows.first?.count, 1, "Lifecycle agents alias should decode string count.")
        try expectEqual(result.gapNotes, ["No session evidence."], "Lifecycle gaps alias should accept strings.")
        try expectEqual(result.blockerNotes, ["No apply path."], "Lifecycle blockers alias should accept arrays.")
        try expectEqual(result.evidenceReferences.first?.detail, "lifecycle:evidence", "Lifecycle evidence alias should accept strings.")
        try expectEqual(result.promptRequest?.requestKind, "lifecycle_alias", "Lifecycle prompt aliases should decode.")
        try expectEqual(result.safetyFlags.notes, ["provider not sent"], "Lifecycle safety aliases should accept string arrays.")
    }

    private func decodesServiceProtocolFixtureIfPresent() throws {
        guard let fixtureURL = repositoryRootIfPresent()?
            .appendingPathComponent("fixtures/service-protocol/skill.lifecycleTimeline.response.json"),
            FileManager.default.fileExists(atPath: fixtureURL.path)
        else {
            return
        }

        let data = try Data(contentsOf: fixtureURL)
        let envelope = try JSONDecoder().decode(ServiceEnvelope<SkillLifecycleTimelineResult>.self, from: data)
        guard let result = envelope.result else {
            throw NativeModelTestFailure(description: "Lifecycle timeline fixture should include a result.")
        }

        try expectEqual(envelope.ok, true, "Lifecycle timeline fixture envelope should decode ok.")
        try expectEqual(result.generatedBy, "local-v2.66", "Lifecycle timeline fixture should decode V2.66 generator.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Lifecycle fixture must keep provider request false.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Lifecycle fixture must keep writes blocked.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Lifecycle fixture must keep scripts blocked.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Lifecycle fixture must keep credentials blocked.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Lifecycle fixture must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Lifecycle fixture must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Lifecycle fixture must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Lifecycle fixture must keep cloud sync blocked.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Lifecycle fixture must keep telemetry blocked.")
    }

    private func repositoryRootIfPresent() -> URL? {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("fixtures/service-protocol").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }
}
