import Foundation
@testable import SkillsCopilot

struct LocalKnowledgeIndexModelTests {
    func run() throws {
        try decodesFlexibleKnowledgePayload()
        try decodesAliasRowsAndDictionaryFacets()
    }

    private func decodesFlexibleKnowledgePayload() throws {
        let json = """
        {
          "generated_by": "local-v2.52",
          "catalog_available": true,
          "filters": {"query":"release audit","agent":"claude-code","limit":"20"},
          "summary": {
            "result_count": 2,
            "agent_count": "1",
            "gap_count": 1,
            "blockers": ["No fresh trace"],
            "summary": "Beta matches release audit knowledge."
          },
          "knowledge_rows": [
            {
              "rank": "1",
              "instance_id": "beta",
              "definition_id": "def.beta",
              "skill_name": "Beta",
              "agent": "claude-code",
              "scope": "agent-project",
              "enabled": true,
              "state": "loaded",
              "snippet": "Handles local audit release notes.",
              "matched_fields": ["purpose", "tools"],
              "match_reasons": ["Purpose mentions audit."],
              "keywords": ["audit", "release"],
              "tools": ["rg"],
              "rules": ["permissions.network-declared"],
              "capability_tags": ["analysis"],
              "risk_tags": ["local-only"],
              "evidence_refs": [{"title":"Catalog","detail":"catalog:beta","source":"catalog"}],
              "safety_flags": ["provider not sent"]
            }
          ],
          "facet_rows": [{"facet":"agent","value":"claude-code","count":"1"}],
          "gap_notes": ["No trace confirms freshness."],
          "blocker_notes": ["No blockers."],
          "evidence_references": ["local index evidence"],
          "prompt_request": {"enabled":false,"request_kind":"knowledge_search","summary":"Provider explanation is copy-only.","draft_copy_only":true},
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

        let result = try JSONDecoder().decode(KnowledgeSearchResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.52", "Knowledge result should decode generator metadata.")
        try expectEqual(result.filters.query, "release audit", "Knowledge filters should decode query.")
        try expectEqual(result.filters.agents, ["claude-code"], "Knowledge filters should decode single-agent aliases.")
        try expectEqual(result.filters.limit, 20, "Knowledge filters should decode string limits.")
        try expectEqual(result.summary.resultCount, 2, "Knowledge summary should decode result count.")
        try expectEqual(result.summary.agentCount, 1, "Knowledge summary should decode agent count.")
        try expectEqual(result.summary.blockerCount, 1, "Knowledge summary should count blocker arrays.")
        try expectEqual(result.knowledgeRows.first?.rank, 1, "Knowledge rows should decode string rank.")
        try expectEqual(result.knowledgeRows.first?.skillName, "Beta", "Knowledge rows should decode skill name.")
        try expectEqual(result.knowledgeRows.first?.purpose, "Handles local audit release notes.", "Knowledge rows should decode snippet as purpose.")
        try expectEqual(result.knowledgeRows.first?.evidenceRefs, ["catalog:beta"], "Knowledge rows should tolerate object evidence refs.")
        try expectEqual(result.facetRows.first?.value, "claude-code", "Facet rows should decode.")
        try expectEqual(result.gapNotes, ["No trace confirms freshness."], "Gap notes should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "local index evidence", "String evidence should decode.")
        try expectEqual(result.promptRequest?.requestKind, "knowledge_search", "Prompt metadata should decode.")
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

    private func decodesAliasRowsAndDictionaryFacets() throws {
        let json = """
        {
          "generatedBy": "local-v2.52",
          "catalogAvailable": true,
          "filters": {"q":"routing","agents":["codex"],"limit":10},
          "summary": "Routing knowledge found.",
          "rows": [
            {
              "position": 2,
              "id": "gamma",
              "definitionId": "codex:gamma",
              "name": "Gamma",
              "agent": "codex",
              "description": "Routes local code-review work.",
              "fields": "description",
              "reason": "Description overlap.",
              "keyword": "routing",
              "capabilities": ["review"],
              "risks": ["missing benchmark"],
              "evidence": ["catalog:gamma"],
              "safety": ["provider not sent"]
            }
          ],
          "facets": {"agent":{"codex":1},"capability":{"review":1}},
          "gaps": "No benchmark coverage.",
          "blockers": "None.",
          "evidence": [{"label":"Catalog","message":"Gamma indexed.","agent":"codex"}],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(KnowledgeSearchResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.52", "GeneratedBy alias should decode.")
        try expectEqual(result.summary.summaryText, "Routing knowledge found.", "String summary should decode.")
        try expectEqual(result.knowledgeRows.first?.rank, 2, "Position alias should decode.")
        try expectEqual(result.knowledgeRows.first?.definitionID, "codex:gamma", "DefinitionId alias should decode.")
        try expectEqual(result.knowledgeRows.first?.matchedFields, ["description"], "Field string should decode as array.")
        try expectEqual(result.knowledgeRows.first?.matchReasons, ["Description overlap."], "Reason string should decode as array.")
        try expectEqual(result.facetRows.count, 2, "Dictionary facets should decode into facet rows.")
        try expectEqual(result.gapNotes, ["No benchmark coverage."], "String gap should decode as array.")
        try expectEqual(result.blockerNotes, ["None."], "String blocker should decode as array.")
        try expectEqual(result.evidenceReferences.first?.title, "Catalog", "Evidence aliases should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
