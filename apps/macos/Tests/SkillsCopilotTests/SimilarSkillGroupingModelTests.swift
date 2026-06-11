import Foundation
@testable import SkillsCopilot

struct SimilarSkillGroupingModelTests {
    func run() throws {
        try decodesFlexibleSimilarGroupingPayload()
        try decodesAliasGroupsAndMemberContexts()
    }

    private func decodesFlexibleSimilarGroupingPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.53",
          "catalog_available": true,
          "filters": {"agent":"claude-code","limit":"20","min_score":"0.62","include_singletons":false},
          "summary": {
            "group_count": 1,
            "member_count": 2,
            "duplicate_count": 1,
            "similar_count": 0,
            "confusable_count": 1,
            "high_ambiguity_count": 1,
            "coverage_redundancy_count": 1,
            "routing_ambiguity_count": 1,
            "summary": "Beta and Gamma overlap on audit routing."
          },
          "groups": [
            {
              "group_id": "grp-1",
              "rank": "1",
              "group_type": "duplicate",
              "similarity_score": "88%",
              "ambiguity_risk": "high",
              "coverage_redundancy": "substantial overlap",
              "routing_ambiguity": "likely wrong-pick",
              "title": "Audit release skills",
              "summary": "Two skills cover the same audit release workflow.",
              "why_grouped": ["Same keywords and tool declarations."],
              "shared_terms": ["audit", "release"],
              "shared_tools": ["rg"],
              "shared_rules": ["permissions.network-declared"],
              "shared_capabilities": ["analysis"],
              "shared_risks": ["routing ambiguity"],
              "source_signals": ["same project root"],
              "members": [
                {
                  "instance_id": "beta",
                  "definition_id": "def.beta",
                  "skill_name": "Beta",
                  "agent": "claude-code",
                  "scope": "agent-project",
                  "enabled": true,
                  "state": "loaded",
                  "source_path": "/tmp/beta/SKILL.md",
                  "source_kind": "project",
                  "source_root": "project",
                  "quality_score": 82,
                  "quality_band": "Good",
                  "readiness_score": "74%",
                  "readiness_band": "Partial",
                  "stale_drift_state": "fresh",
                  "reasons": ["Name and purpose overlap."],
                  "evidence_refs": [{"title":"Catalog","detail":"catalog:beta","source":"catalog"}],
                  "safety_flags": ["provider not sent"]
                }
              ],
              "evidence_refs": ["catalog:beta", "catalog:gamma"],
              "safety_flags": ["provider not sent"]
            }
          ],
          "gap_notes": ["No benchmark separates the two skills."],
          "blocker_notes": [],
          "evidence_references": ["similar grouping evidence"],
          "prompt_request": {"enabled":false,"request_kind":"similar_skill_grouping","summary":"Provider explanation is copy-only.","draft_copy_only":true},
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

        let result = try JSONDecoder().decode(SimilarSkillGroupingResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.53", "Similar grouping should decode generator metadata.")
        try expectEqual(result.filters.agents, ["claude-code"], "Filters should decode single-agent aliases.")
        try expectEqual(result.filters.limit, 20, "Filters should decode string limits.")
        try expectEqual(result.filters.minScore, 0.62, "Filters should decode min score.")
        try expectFalse(result.filters.includeSingletons, "Filters should decode singleton flag.")
        try expectEqual(result.summary.groupCount, 1, "Summary should decode group count.")
        try expectEqual(result.summary.memberCount, 2, "Summary should decode member count.")
        try expectEqual(result.summary.routingAmbiguityCount, 1, "Summary should decode routing ambiguity count.")
        try expectEqual(result.groups.first?.id, "grp-1", "Group id should decode.")
        try expectEqual(result.groups.first?.typeLabel, UIStrings.similarGroupingDuplicate, "Duplicate group type should display.")
        try expectEqual(result.groups.first?.similarityScore, 0.88, "Similarity percentage should decode.")
        try expectEqual(result.groups.first?.sharedTools, ["rg"], "Shared tools should decode.")
        try expectEqual(result.groups.first?.members.first?.skillName, "Beta", "Member skill name should decode.")
        try expectEqual(result.groups.first?.members.first?.qualityScore, 82, "Member quality should decode.")
        try expectEqual(result.groups.first?.members.first?.readinessScore, 0.74, "Member readiness percentage should decode.")
        try expectEqual(result.groups.first?.members.first?.evidenceRefs, ["catalog:beta"], "Member evidence object should decode to refs.")
        try expectEqual(result.gapNotes, ["No benchmark separates the two skills."], "Gap notes should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "similar grouping evidence", "String evidence should decode.")
        try expectEqual(result.promptRequest?.requestKind, "similar_skill_grouping", "Prompt metadata should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Safety should decode provider flag.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Safety should decode write flag.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Safety should decode script flag.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Safety should decode config flag.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Safety should decode snapshot flag.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Safety should decode triage flag.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Safety should decode credential flag.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Safety should decode cloud flag.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Safety should decode telemetry flag.")
    }

    private func decodesAliasGroupsAndMemberContexts() throws {
        let json = """
        {
          "generatedBy": "local-v2.53",
          "catalogAvailable": true,
          "filters": {"agents":["codex"],"limit":10,"threshold":70,"includeSingletons":"false"},
          "summary": "One confusable route found.",
          "rows": [
            {
              "groupId": "alias-group",
              "position": 2,
              "type": "confusable",
              "score": 72,
              "ambiguityRisk": "medium",
              "coverageRedundancy": true,
              "routingAmbiguity": "medium",
              "name": "Review helpers",
              "description": "Names are distinct but task routing overlaps.",
              "reasons": "Both mention review handoff.",
              "terms": "review",
              "tools": "rg",
              "capabilities": ["review"],
              "risks": ["wrong pick"],
              "sources": ["same compatibility root"],
              "skills": [
                {
                  "id": "gamma",
                  "definitionId": "codex:gamma",
                  "name": "Gamma",
                  "agent": "codex",
                  "source": {"path":"/tmp/gamma/SKILL.md","kind":"native","root":"codex"},
                  "quality": {"score": "81", "band": "Good"},
                  "readiness": {"score": "Partial", "band": "Partial"},
                  "stale_drift": {"state":"drift"},
                  "reason": "Purpose overlap.",
                  "evidence": "catalog:gamma",
                  "safety": "provider not sent"
                }
              ],
              "evidence": [{"title":"Catalog","detail":"Gamma grouped.","source":"knowledge.groupSimilarSkills"}],
              "safety": ["provider not sent"]
            }
          ],
          "gaps": "No trace imported.",
          "blockers": "None.",
          "evidence": [{"label":"Catalog","message":"Alias evidence.","agent":"codex"}],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(SimilarSkillGroupingResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.53", "GeneratedBy alias should decode.")
        try expectEqual(result.filters.minScore, 70, "Threshold alias should decode.")
        try expectEqual(result.summary.summaryText, "One confusable route found.", "String summary should decode.")
        try expectEqual(result.groups.first?.rank, 2, "Position alias should decode.")
        try expectEqual(result.groups.first?.typeLabel, UIStrings.similarGroupingConfusable, "Confusable alias should display.")
        try expectEqual(result.groups.first?.coverageRedundancy, UIStrings.stateEnabled, "Boolean coverage redundancy should become a readable label.")
        try expectEqual(result.groups.first?.whyGrouped, ["Both mention review handoff."], "Reason string should decode as array.")
        try expectEqual(result.groups.first?.members.first?.definitionID, "codex:gamma", "DefinitionId alias should decode.")
        try expectEqual(result.groups.first?.members.first?.sourceKind, "native", "Nested source info should decode.")
        try expectEqual(result.groups.first?.members.first?.qualityBand, "Good", "Nested quality context should decode.")
        try expectEqual(result.groups.first?.members.first?.staleDriftState, "drift", "Nested stale drift context should decode.")
        try expectEqual(result.gapNotes, ["No trace imported."], "String gap should decode as array.")
        try expectEqual(result.blockerNotes, ["None."], "String blocker should decode as array.")
        try expectEqual(result.evidenceReferences.first?.title, "Catalog", "Evidence aliases should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
