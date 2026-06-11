import Foundation
@testable import SkillsCopilot

struct StaleDriftDetectionModelTests {
    func run() throws {
        try decodesFlexiblePayload()
        try decodesAliasRowsAndStringSafety()
    }

    private func decodesFlexiblePayload() throws {
        let json = """
        {
          "generated_by": "local-v2.51",
          "catalog_available": true,
          "filters": {
            "agent": "claude-code",
            "limit": "40",
            "include_readiness_impact": true
          },
          "summary": {
            "stale_count": 2,
            "drift_count": "1",
            "candidate_count": ["a", "b", "c"],
            "affected_agents": ["claude-code", "codex"],
            "readiness_impacts": ["impact"],
            "gap_issue_count": 2,
            "high_risk_count": 1,
            "summary": "One high-risk stale skill affects readiness."
          },
          "stale_drift_rows": [
            {
              "id": "stale-beta",
              "kind": "stale",
              "severity": "warning",
              "agent": "claude-code",
              "skill": {
                "instance_id": "beta",
                "definition_id": "def.beta",
                "skill_name": "Beta",
                "scope": "agent-project",
                "state": "loaded",
                "enabled": true
              },
              "title": "Beta appears stale",
              "summary": "Beta has not appeared in recent trace or benchmark evidence.",
              "last_seen": "2026-05-01",
              "current_signal": {"title":"Trace","detail":"No recent trace hits.","source":"routing.accuracyDashboard"},
              "expected_signal": "Expected route remains Beta.",
              "confidence": "82",
              "reasons": ["No trace hits in the current window."],
              "signals": ["Benchmark age exceeds threshold."],
              "evidence_refs": [{"title":"Catalog","detail":"catalog:beta","source":"catalog"}]
            }
          ],
          "readiness_impact_rows": [
            {"agent":"claude-code","skill_name":"Beta","severity":"warning","title":"Readiness lowered","detail":"Readiness is partial because evidence is stale.","evidence_refs":["readiness:beta"]}
          ],
          "gap_issue_rows": ["No fresh trace evidence"],
          "evidence_references": ["local freshness evidence"],
          "prompt_request": {
            "enabled": false,
            "request_kind": "stale_drift_detection",
            "summary": "Provider explanation is copy-only.",
            "draft_copy_only": true
          },
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

        let result = try JSONDecoder().decode(StaleDriftDetectionResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.51", "Stale drift should decode generator metadata.")
        try expectEqual(result.filters.agents, ["claude-code"], "Filters should decode single-agent aliases.")
        try expectEqual(result.filters.limit, 40, "Filters should decode string limits.")
        try expectEqual(result.summary.staleCount, 2, "Summary should decode stale count.")
        try expectEqual(result.summary.driftCount, 1, "Summary should decode drift count.")
        try expectEqual(result.summary.candidateCount, 3, "Summary should count candidate arrays.")
        try expectEqual(result.summary.affectedAgentCount, 2, "Summary should count affected agents.")
        try expectEqual(result.summary.readinessImpactCount, 1, "Summary should count readiness impacts.")
        try expectEqual(result.summary.highRiskCount, 1, "Summary should decode high risk count.")
        try expectEqual(result.staleDriftRows.first?.skill?.definitionID, "def.beta", "Rows should expose skill definition id.")
        try expectEqual(result.staleDriftRows.first?.currentSignal, "No recent trace hits.", "Rows should tolerate object signals.")
        try expectEqual(result.staleDriftRows.first?.confidenceLabel, "82", "Confidence label should format score values.")
        try expectEqual(result.staleDriftRows.first?.evidenceRefs, ["catalog:beta"], "Rows should tolerate object evidence refs.")
        try expectEqual(result.readinessImpactRows.first?.title, "Readiness lowered", "Readiness impact rows should decode.")
        try expectEqual(result.gapIssueRows.first?.detail, "No fresh trace evidence", "String gap rows should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "local freshness evidence", "String evidence should decode.")
        try expectEqual(result.promptRequest?.requestKind, "stale_drift_detection", "Prompt metadata should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Safety should decode provider flag.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Safety should decode write flag.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Safety should decode script flag.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Safety should decode config flag.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Safety should decode snapshot flag.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Safety should decode triage flag.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Safety should decode credential flag.")
        try expectFalse(result.safetyFlags.rawPromptPersisted, "Safety should decode raw prompt flag.")
        try expectFalse(result.safetyFlags.rawResponsePersisted, "Safety should decode raw response flag.")
        try expectFalse(result.safetyFlags.rawTracePersisted, "Safety should decode raw trace flag.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Safety should decode cloud flag.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Safety should decode telemetry flag.")
    }

    private func decodesAliasRowsAndStringSafety() throws {
        let json = """
        {
          "generatedBy": "local-v2.51",
          "catalogAvailable": true,
          "rows": [
            {
              "type": "drift",
              "risk": "medium",
              "candidate": "Docs",
              "message": "Description drifted from benchmark wording.",
              "signal": "Name overlap remains but body changed.",
              "evidence": ["catalog"]
            }
          ],
          "readinessImpacts": ["Partial readiness impact"],
          "issues": ["Benchmark drift issue"],
          "evidence": [{"label":"Trace","message":"Trace evidence.","agent":"codex"}],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(StaleDriftDetectionResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.51", "GeneratedBy alias should decode.")
        try expectEqual(result.staleDriftRows.first?.kind, "drift", "Type alias should decode as kind.")
        try expectEqual(result.staleDriftRows.first?.skill?.name, "Docs", "String candidate should decode as skill.")
        try expectEqual(result.staleDriftRows.first?.signals, ["Name overlap remains but body changed."], "Signal string should decode as array.")
        try expectEqual(result.readinessImpactRows.first?.title, "Partial readiness impact", "Readiness impact aliases should decode.")
        try expectEqual(result.gapIssueRows.first?.title, "Benchmark drift issue", "Issue aliases should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Trace", "Evidence aliases should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
