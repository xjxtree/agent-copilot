import Foundation
@testable import SkillsCopilot

struct CrossAgentReadinessModelTests {
    func run() throws {
        try decodesFlexiblePayload()
        try decodesStringRecommendationAndEvidenceAliases()
    }

    private func decodesFlexiblePayload() throws {
        let json = """
        {
          "generated_by": "local-v2.50",
          "catalog_available": true,
          "filters": {
            "agent": "claude-code",
            "limit_per_agent": "3",
            "include_routing_accuracy": true,
            "include_benchmarks": true
          },
          "summary": {
            "agent_count": 2,
            "candidate_count": "5",
            "ready_agent_count": 1,
            "partial_agent_count": 1,
            "blocked_agent_count": 0,
            "gap_issue_count": ["one", "two"],
            "average_readiness_score": "81",
            "average_routing_score": 0.72,
            "recommended_agent": "claude-code",
            "summary": "Claude Code is strongest."
          },
          "recommended_agent": {
            "agent": "claude-code",
            "display_name": "Claude Code",
            "comparison_score": 93,
            "readiness_score": "88",
            "routing_confidence_score": 91,
            "skill_name": "Beta",
            "reason": "Best local evidence."
          },
          "agent_rows": [
            {
              "rank": 1,
              "agent": "claude-code",
              "display_name": "Claude Code",
              "comparison_score": 93,
              "readiness_score": "88",
              "readiness_band": "Ready",
              "routing_confidence_score": 91.2,
              "routing_confidence_band": "High",
              "best_candidate": {
                "instance_id": "beta",
                "definition_id": "def.beta",
                "skill_name": "Beta",
                "scope": "agent-project",
                "enabled": true,
                "state": "loaded",
                "readiness_score": 88,
                "readiness_band": "Ready",
                "routing_confidence_score": 91,
                "routing_confidence_band": "High",
                "quality_score": 82
              },
              "candidate_count": 3,
              "enabled_scope_risk_state": {
                "enabled": true,
                "scope": "agent-project",
                "state": "loaded",
                "risk_level": "low",
                "risk_summary": "Low local risk.",
                "writable_status": "verified",
                "adapter_status": "healthy"
              },
              "blocker_count": 0,
              "gap_count": 1,
              "reasons": ["metadata match"],
              "blocker_notes": [],
              "gap_notes": ["No release note example."],
              "routing_accuracy_context": {"accuracy_rate":0.875,"regression_count":0},
              "benchmark_context": {"benchmark_count":4,"matched_count":3,"gap_count":1},
              "evidence_refs": [{"title":"Catalog","detail":"Beta matched.","source":"local"}]
            }
          ],
          "gap_issue_rows": [
            {"source":"benchmark","severity":"warning","agent":"codex","title":"Missing benchmark","detail":"No Codex benchmark.","evidence_refs":["bench:none"]}
          ],
          "evidence_references": ["local catalog evidence"],
          "prompt_request": {
            "enabled": false,
            "request_kind": "cross_agent_task_readiness",
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

        let result = try JSONDecoder().decode(CrossAgentReadinessResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.50", "Cross-agent readiness should decode generator metadata.")
        try expectEqual(result.filters.agents, ["claude-code"], "Filters should decode single-agent aliases as arrays.")
        try expectEqual(result.filters.limitPerAgent, 3, "Filters should decode string limits.")
        try expectEqual(result.summary.agentCount, 2, "Summary should decode agent count.")
        try expectEqual(result.summary.candidateCount, 5, "Summary should decode candidate count.")
        try expectEqual(result.summary.gapCount, 2, "Summary should count flexible gap arrays.")
        try expectEqual(result.summary.readyCount, 1, "Summary should decode ready_agent_count.")
        try expectEqual(result.summary.partialCount, 1, "Summary should decode partial_agent_count.")
        try expectEqual(result.summary.blockedCount, 0, "Summary should decode blocked_agent_count.")
        try expectEqual(result.summary.recommendedAgent, "claude-code", "Summary should decode recommended agent.")
        try expectEqual(CrossAgentReadinessSummary.scoreLabel(result.summary.averageRoutingScore), "72%", "Score label should format fractional scores.")
        try expectEqual(result.recommendedAgent?.agent, "claude-code", "Recommendation should decode agent.")
        try expectEqual(result.recommendedAgent?.displayName, "Claude Code", "Recommendation should decode display name.")
        try expectEqual(result.recommendedAgent?.comparisonScore, 93, "Recommendation should decode comparison score.")
        try expectEqual(result.recommendedAgent?.score, 88, "Recommendation should decode flexible score.")
        try expectEqual(result.recommendedAgent?.routingScore, 91, "Recommendation should decode routing confidence score.")
        try expectEqual(result.recommendedAgent?.skill?.name, "Beta", "Recommendation should decode best skill.")
        try expectEqual(result.agentRows.first?.rank, 1, "Agent row should decode rank.")
        try expectEqual(result.agentRows.first?.displayName, "Claude Code", "Agent row should decode display name.")
        try expectEqual(result.agentRows.first?.comparisonScore, 93, "Agent row should decode comparison score.")
        try expectEqual(result.agentRows.first?.routingScore, 91, "Agent row should decode rounded routing score.")
        try expectEqual(result.agentRows.first?.bestCandidateSkill?.definitionID, "def.beta", "Best candidate should decode definition id.")
        try expectEqual(result.agentRows.first?.bestCandidateSkill?.enabled, true, "Best candidate should decode enabled flag.")
        try expectEqual(result.agentRows.first?.bestCandidateSkill?.qualityScore, 82, "Best candidate should decode quality score.")
        try expectEqual(result.agentRows.first?.bestCandidateSkill?.name, "Beta", "Agent row should decode string best skill.")
        try expectEqual(result.agentRows.first?.enabledState, "Enabled", "Agent row should decode nested enabled state.")
        try expectEqual(result.agentRows.first?.scopeState, "agent-project", "Agent row should decode nested scope state.")
        try expectEqual(result.agentRows.first?.riskState, "low", "Agent row should decode nested risk state.")
        try expectEqual(result.agentRows.first?.accuracyContext, "87.5% · Regressions 0", "Agent row should decode nested routing accuracy context.")
        try expectEqual(result.agentRows.first?.benchmarkContext, "Benchmarks 4 · Expected matched 3 · Gaps / missing capabilities 1", "Agent row should decode nested benchmark context.")
        try expectEqual(result.agentRows.first?.gapNotes, ["No release note example."], "Agent row should decode gap notes.")
        try expectEqual(result.agentRows.first?.evidenceRefs, ["Beta matched."], "Agent row should tolerate object evidence references.")
        try expectEqual(result.gapIssueRows.first?.evidenceRefs, ["bench:none"], "Gap rows should expose evidence refs.")
        try expectEqual(result.evidenceReferences.first?.detail, "local catalog evidence", "String evidence references should decode.")
        try expectEqual(result.promptRequest?.requestKind, "cross_agent_task_readiness", "Prompt metadata should decode request kind.")
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

    private func decodesStringRecommendationAndEvidenceAliases() throws {
        let json = """
        {
          "task": "Route docs work.",
          "recommended_agent": "codex",
          "agents": [
            {
              "name": "codex",
              "score": 76,
              "band": "Partial",
              "confidence_score": "68",
              "confidence_band": "Medium",
              "skill": {"skill_name":"Docs"},
              "candidates": ["a", "b"],
              "enabled": "mixed",
              "scope": "global",
              "risk": "medium",
              "blockers": ["needs project"],
              "gaps": ["examples"],
              "reason": "Good documentation fit.",
              "evidence": ["catalog"]
            }
          ],
          "issues": ["Benchmark gap"],
          "evidence": [{"label":"Trace","message":"Trace evidence.","agent":"codex"}],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(CrossAgentReadinessResult.self, from: Data(json.utf8))
        try expectEqual(result.taskText, "Route docs work.", "Task alias should decode.")
        try expectEqual(result.recommendedAgent?.agent, "codex", "String recommendation should decode.")
        try expectEqual(result.agentRows.first?.readinessScore, 76, "Score alias should decode.")
        try expectEqual(result.agentRows.first?.routingScore, 68, "Confidence alias should decode as routing score.")
        try expectEqual(result.agentRows.first?.candidateCount, 2, "Candidate arrays should count.")
        try expectEqual(result.agentRows.first?.reasons, ["Good documentation fit."], "Reason strings should decode as arrays.")
        try expectEqual(result.gapIssueRows.first?.title, "Benchmark gap", "String issue rows should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Trace", "Evidence aliases should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
