import Foundation
@testable import SkillsCopilot

struct TaskCockpitModelTests {
    func run() throws {
        try decodesRealisticTaskCockpitPayload()
        try decodesAliasesAndStringForms()
        try decodesServiceProtocolFixture()
    }

    private struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
        let id: String?
        let ok: Bool
        let result: ResultPayload?
    }

    private func decodesRealisticTaskCockpitPayload() throws {
        let data = Data(
            """
            {
              "id": "cockpit-1",
              "ok": true,
              "result": {
                "generated_by": "local-v2.65",
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
                  "limit": "8",
                  "include_session_review": true,
                  "include_provider_observability": true,
                  "include_remediation_context": true
                },
                "summary": {
                  "task_text": "Prepare local release audit work.",
                  "summary": "Beta is the strongest route, but Codex coverage remains a gap.",
                  "route_candidate_count": 2,
                  "agent_candidate_count": 2,
                  "skill_candidate_count": 2,
                  "readiness_signal_count": 2,
                  "session_review_count": 1,
                  "provider_call_count": 3,
                  "remediation_item_count": 1,
                  "gap_count": 1,
                  "blocker_count": 1,
                  "evidence_count": 2,
                  "safety_flag_count": 1,
                  "recommended_agent": "claude-code",
                  "recommended_skill_name": "Beta",
                  "readiness_score": 78,
                  "routing_score": "88"
                },
                "route_candidates": [
                  {
                    "route_id": "route-beta",
                    "rank": 1,
                    "title": "Beta",
                    "agent": "claude-code",
                    "skill": {"instance_id":"beta","skill_name":"Beta","agent":"claude-code","definition_id":"def.beta"},
                    "readiness_score": 78,
                    "routing_score": 88,
                    "band": "High",
                    "status": "ready",
                    "summary": "Best local match for release audit.",
                    "match_reasons": ["Description matches audit work."],
                    "evidence_refs": [{"title":"Routing","detail":"route:beta"}],
                    "safety_flags": ["provider not sent"]
                  },
                  "route:alpha"
                ],
                "agent_candidates": [
                  {"agent_id":"agent-claude","title":"Claude Code","agent":"claude-code","score":82,"reasons":"Selected skill is enabled."}
                ],
                "skill_candidates": [
                  {"skill_id":"beta","name":"Beta","agent":"claude-code","readiness_score":"78","routing_score":"88"}
                ],
                "readiness_signals": [
                  {"id":"readiness-beta","title":"Readiness partial","detail":"Ready for local audit, missing release-note examples.","status":"partial","count":"1"}
                ],
                "session_review_context": [
                  {"id":"review-1","title":"Recent session matched Beta","detail":"Latest review outcome was hit.","status":"hit","source":"session.reviewAgentSkillUse"}
                ],
                "provider_observability_context": [
                  {"id":"provider-1","title":"Provider calls observed","detail":"Three redacted call metadata rows.","count":3,"source":"llm.providerObservability"}
                ],
                "remediation_context": [
                  {"id":"plan-1","title":"Add Codex release audit coverage","detail":"Guidance only; no apply path.","severity":"medium","source":"remediation.plan"}
                ],
                "gap_rows": [{"title":"Codex coverage gap","detail":"No Codex project route.","severity":"warning","agent":"codex","evidence_refs":["workspace:codex-gap"]}],
                "blocker_rows": [{"title":"No apply path","detail":"Cockpit only recommends review surfaces.","severity":"info"}],
                "evidence_references": [
                  {"title":"Task cockpit","detail":"Derived from local task readiness, routing, session, provider, and remediation metadata.","source":"task.buildCockpit","agent":"claude-code"}
                ],
                "prompt_request": {"enabled":false,"request_kind":"task_cockpit","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},
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
            }
            """.utf8
        )

        let envelope = try JSONDecoder().decode(ServiceEnvelope<TaskCockpitResult>.self, from: data)
        guard let result = envelope.result else {
            throw NativeModelTestFailure(description: "Task cockpit envelope should include a result.")
        }

        try expectEqual(envelope.ok, true, "Task cockpit envelope should decode ok.")
        try expectEqual(result.generatedBy, "local-v2.65", "Task cockpit should decode generator metadata.")
        try expectEqual(result.filters.taskText, "Prepare local release audit work.", "Task cockpit should decode task filter.")
        try expectEqual(result.filters.limit, 8, "Task cockpit should decode string limits.")
        try expectEqual(result.summary.recommendedAgent, "claude-code", "Task cockpit should decode recommended agent.")
        try expectEqual(result.summary.recommendedSkillName, "Beta", "Task cockpit should decode recommended skill.")
        try expectEqual(result.summary.routingScore, 88, "Task cockpit should decode string routing score.")
        try expectEqual(result.routeCandidates.count, 2, "Task cockpit should decode route candidates and string shorthand.")
        try expectEqual(result.routeCandidates.first?.skill?.name, "Beta", "Task cockpit route should decode skill refs.")
        try expectEqual(result.routeCandidates.first?.evidenceRefs, ["route:beta"], "Task cockpit route evidence should accept objects.")
        try expectEqual(result.routeCandidates[1].title, "route:alpha", "Task cockpit route should accept string shorthand.")
        try expectEqual(result.agentCandidates.first?.reasons, ["Selected skill is enabled."], "Task cockpit agent reasons should accept strings.")
        try expectEqual(result.skillCandidates.first?.routingScore, 88, "Task cockpit skill candidates should decode string scores.")
        try expectEqual(result.readinessSignals.first?.count, 1, "Task cockpit readiness signals should decode string counts.")
        try expectEqual(result.sessionReviewContext.first?.source, "session.reviewAgentSkillUse", "Task cockpit should decode session context.")
        try expectEqual(result.providerObservabilityContext.first?.count, 3, "Task cockpit should decode provider context.")
        try expectEqual(result.remediationContext.first?.title, "Add Codex release audit coverage", "Task cockpit should decode remediation context.")
        try expectEqual(result.gapRows.first?.agent, "codex", "Task cockpit should decode gap rows.")
        try expectEqual(result.blockerRows.first?.title, "No apply path", "Task cockpit should decode blockers.")
        try expectEqual(result.evidenceReferences.first?.source, "task.buildCockpit", "Task cockpit should decode evidence references.")
        try expectEqual(result.promptRequest?.requestKind, "task_cockpit", "Task cockpit should decode prompt metadata.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Task cockpit must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Task cockpit must not allow write-back.")
        try expectFalse(result.safetyFlags.writeActionsAvailable, "Task cockpit must not expose write actions.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Task cockpit must not allow script execution.")
        try expectFalse(result.safetyFlags.executionActionsAvailable, "Task cockpit must not expose execution actions.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Task cockpit must not mutate config.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Task cockpit must not create snapshots.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Task cockpit must not mutate triage.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Task cockpit must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Task cockpit must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Task cockpit must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Task cockpit must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Task cockpit must not sync cloud data.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Task cockpit must not emit telemetry.")
    }

    private func decodesAliasesAndStringForms() throws {
        let json = """
        {
          "generatedBy": "local-v2.65",
          "catalogAvailable": true,
          "summary": "String summary works.",
          "routes": ["Beta"],
          "agents": "claude-code",
          "skills": [{"id":"beta","title":"Beta","agent":"claude-code","score":"80"}],
          "readiness": "partial",
          "session_reviews": "hit",
          "provider_rows": "no provider sent",
          "remediation_items": "review only",
          "gaps": "No Codex route.",
          "blockers": "No apply path.",
          "evidence": ["task-cockpit:evidence"],
          "promptRequest": {"enabled":false,"requestKind":"task_cockpit","draft_copy_only":true},
          "safety": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(TaskCockpitResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.65", "GeneratedBy alias should decode.")
        try expectEqual(result.summary.summaryText, "String summary works.", "String summary should decode.")
        try expectEqual(result.routeCandidates.first?.title, "Beta", "Routes alias should decode string rows.")
        try expectEqual(result.agentCandidates.first?.title, "claude-code", "Agents alias should decode string row.")
        try expectEqual(result.skillCandidates.first?.score, 80, "Skills alias should decode score strings.")
        try expectEqual(result.readinessSignals.first?.title, "partial", "Readiness alias should decode.")
        try expectEqual(result.sessionReviewContext.first?.title, "hit", "Session alias should decode.")
        try expectEqual(result.providerObservabilityContext.first?.title, "no provider sent", "Provider alias should decode.")
        try expectEqual(result.remediationContext.first?.title, "review only", "Remediation alias should decode.")
        try expectEqual(result.gapRows.first?.title, "No Codex route.", "Gaps alias should decode.")
        try expectEqual(result.blockerRows.first?.title, "No apply path.", "Blockers alias should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "task-cockpit:evidence", "String evidence should decode.")
        try expectEqual(result.promptRequest?.requestKind, "task_cockpit", "Prompt request camel-case alias should decode.")
        try expectEqual(result.safetyFlags.notes, ["provider not sent"], "Safety string array should decode.")
    }

    private func decodesServiceProtocolFixture() throws {
        let fixtureURL = try repositoryRoot()
            .appendingPathComponent("fixtures/service-protocol/task.buildCockpit.response.json")
        let data = try Data(contentsOf: fixtureURL)
        let envelope = try JSONDecoder().decode(ServiceEnvelope<TaskCockpitResult>.self, from: data)
        guard let result = envelope.result else {
            throw NativeModelTestFailure(description: "Task cockpit fixture should include a result.")
        }

        try expectEqual(envelope.ok, true, "Task cockpit fixture envelope should decode ok.")
        try expectEqual(result.generatedBy, "local-v2.65", "Task cockpit should decode service generator metadata.")
        try expectEqual(result.summary.recommendedAgent, "codex", "Task cockpit should decode service recommended agent.")
        try expectEqual(result.summary.recommendedSkillName, "fixture-skill", "Task cockpit should decode top skill name.")
        try expectEqual(result.summary.readinessScore, 72, "Task cockpit should decode readiness score.")
        try expectEqual(result.summary.routingScore, 68, "Task cockpit should decode routing confidence score.")
        try expectEqual(result.summary.skillCandidateCount, 1, "Task cockpit should decode service candidate count.")
        try expectEqual(result.summary.agentCandidateCount, 1, "Task cockpit should decode service agent count.")
        try expectEqual(result.summary.providerCallCount, 1, "Task cockpit should decode provider observability row count.")
        try expectEqual(result.summary.remediationItemCount, 1, "Task cockpit should decode remediation next-step count.")
        try expectEqual(result.cockpitSections.count, 2, "Task cockpit should decode cockpit section rows.")
        try expectEqual(result.cockpitSections.first?.count, 1, "Task cockpit should decode section row counts.")
        try expectEqual(result.taskRows.count, 1, "Task cockpit should decode task rows.")
        try expectEqual(result.taskRows.first?.title, "Analyze repository skill quality and prepare a local readiness report", "Task cockpit task row should title from task text.")
        try expectEqual(result.agentCandidates.count, 1, "Task cockpit should decode agent route rows.")
        try expectEqual(result.agentCandidates.first?.title, "fixture-skill", "Task cockpit agent route should title from best skill name.")
        try expectEqual(result.agentCandidates.first?.score, 70, "Task cockpit agent route should decode comparison score.")
        try expectEqual(result.agentCandidates.first?.routingScore, 68, "Task cockpit agent route should decode routing confidence score.")
        try expectEqual(result.skillCandidates.count, 1, "Task cockpit should decode skill candidate rows.")
        try expectEqual(result.skillCandidates.first?.skill?.name, "fixture-skill", "Task cockpit skill candidate should build a skill ref from top-level fields.")
        try expectEqual(result.skillCandidates.first?.skill?.definitionID, "fixture-definition-id", "Task cockpit skill candidate should retain definition id.")
        try expectEqual(result.skillCandidates.first?.routingScore, 68, "Task cockpit skill candidate should decode routing confidence score.")
        try expectEqual(result.skillCandidates.first?.score, 78, "Task cockpit skill candidate should decode quality score.")
        try expectEqual(result.readinessSignals.count, 1, "Task cockpit should decode readiness rows.")
        try expectEqual(result.readinessSignals.first?.source, "task", "Task cockpit should decode readiness row type as source.")
        try expectEqual(result.sessionReviewContext.count, 1, "Task cockpit should decode session review rows.")
        try expectEqual(result.providerObservabilityContext.count, 1, "Task cockpit should decode provider observability rows.")
        try expectEqual(result.remediationContext.count, 1, "Task cockpit should decode remediation next steps.")
        try expectContains(result.remediationContext.first?.detail, "no apply action", "Task cockpit should decode suggested safe next action text.")
        try expectEqual(result.gapRows.count, 1, "Task cockpit should decode gap notes.")
        try expectEqual(result.blockerRows.count, 1, "Task cockpit should decode blocker notes.")
        try expectEqual(result.evidenceReferences.count, 3, "Task cockpit should decode service evidence references.")
        try expectEqual(result.evidenceReferences.first?.source, "skill", "Task cockpit should decode evidence source type.")
        try expectEqual(result.evidenceReferences.first?.detail, "fixture-skill-id", "Task cockpit should decode evidence source id.")
        try expectEqual(result.promptRequest?.requestKind, "task_cockpit", "Task cockpit should decode prompt action metadata.")
        try expectContains(result.promptRequest?.summary, "explicit confirmation", "Task cockpit should surface prompt preview note.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Task cockpit fixture must not send provider requests.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Task cockpit fixture must keep writes blocked.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Task cockpit fixture must keep scripts blocked.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Task cockpit fixture must not access credentials.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Task cockpit fixture must not persist raw prompts.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Task cockpit fixture must not persist raw responses.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Task cockpit fixture must not persist raw traces.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Task cockpit fixture must keep cloud sync blocked.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Task cockpit fixture must keep telemetry blocked.")
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("fixtures/service-protocol").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw NativeModelTestFailure(description: "Unable to locate repository root from \(FileManager.default.currentDirectoryPath).")
    }
}
