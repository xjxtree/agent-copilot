import Foundation
@testable import SkillsCopilot

struct CapabilityTaxonomyModelTests {
    func run() throws {
        try decodesFlexibleCapabilityTaxonomyPayload()
        try decodesAliasDomainsAndCoverage()
    }

    private func decodesFlexibleCapabilityTaxonomyPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.54",
          "catalog_available": true,
          "filters": {"agent":"claude-code","limit":"20","include_gaps":true},
          "summary": {
            "domain_count": 1,
            "capability_count": 2,
            "skill_count": 3,
            "agent_count": 1,
            "gap_count": 1,
            "blocker_count": 0,
            "summary": "Audit capabilities are covered but benchmark evidence is thin."
          },
          "coverage_by_agent": [
            {"agent":"claude-code","skill_count":"3","capability_count":2,"coverage_state":"covered","notes":["Release audit is covered."]}
          ],
          "domains": [
            {
              "domain_id": "audit",
              "name": "Audit workflows",
              "summary": "Local audit and release review skills.",
              "capability_count": 2,
              "skill_count": 3,
              "coverage_by_agent": [{"agent":"claude-code","skills":3,"capabilities":2,"state":"covered"}],
              "capabilities": [
                {
                  "capability_id": "release-audit",
                  "name": "Release audit",
                  "summary": "Prepare local release audit evidence.",
                  "keywords": ["audit", "release"],
                  "tools": ["rg"],
                  "rules": ["permissions.network-declared"],
                  "risk_tags": ["local-only"],
                  "representative_skills": [
                    {
                      "instance_id": "beta",
                      "definition_id": "def.beta",
                      "skill_name": "Beta",
                      "agent": "claude-code",
                      "scope": "agent-project",
                      "enabled": true,
                      "state": "loaded",
                      "quality_score": 82,
                      "readiness_score": "74%",
                      "reasons": ["Purpose maps to release audit."],
                      "evidence_refs": [{"title":"Catalog","detail":"catalog:beta","source":"catalog"}],
                      "safety_flags": ["provider not sent"]
                    }
                  ],
                  "evidence_refs": ["catalog:beta"],
                  "safety_flags": ["provider not sent"]
                }
              ],
              "gap_notes": ["No imported trace covers release audit."],
              "blocker_notes": [],
              "evidence_refs": ["domain:audit"],
              "safety_flags": ["provider not sent"]
            }
          ],
          "gap_notes": ["Codex has no equivalent audit capability."],
          "blocker_notes": [],
          "evidence_references": ["taxonomy evidence"],
          "prompt_request": {"enabled":false,"request_kind":"capability_taxonomy","summary":"Provider explanation is copy-only.","draft_copy_only":true},
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

        let result = try JSONDecoder().decode(CapabilityTaxonomyResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.54", "Capability taxonomy should decode generator metadata.")
        try expectEqual(result.filters.agents, ["claude-code"], "Filters should decode single-agent aliases.")
        try expectEqual(result.filters.limit, 20, "Filters should decode string limits.")
        try expectEqual(result.filters.includeGaps, true, "Filters should decode include gaps.")
        try expectEqual(result.summary.domainCount, 1, "Summary should decode domain count.")
        try expectEqual(result.summary.capabilityCount, 2, "Summary should decode capability count.")
        try expectEqual(result.coverageByAgent.first?.coverageState, "covered", "Top-level coverage should decode.")
        try expectEqual(result.domains.first?.name, "Audit workflows", "Domain name should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.name, "Release audit", "Capability name should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.tools, ["rg"], "Capability tools should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.representativeSkills.first?.skillName, "Beta", "Representative skill should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.representativeSkills.first?.readinessScore, 0.74, "Readiness percentage should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.representativeSkills.first?.evidenceRefs, ["catalog:beta"], "Object evidence refs should decode.")
        try expectEqual(result.gapNotes, ["Codex has no equivalent audit capability."], "Gap notes should decode.")
        try expectEqual(result.evidenceReferences.first?.detail, "taxonomy evidence", "String evidence should decode.")
        try expectEqual(result.promptRequest?.requestKind, "capability_taxonomy", "Prompt metadata should decode.")
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

    private func decodesAliasDomainsAndCoverage() throws {
        let json = """
        {
          "generatedBy": "local-v2.54",
          "catalogAvailable": true,
          "filters": {"agents":["codex"],"limit":10,"includeGaps":"false"},
          "summary": "Review taxonomy found.",
          "agent_coverage": [{"agent":"codex","skills":["gamma"],"capabilities":["review"],"status":"partial","gaps":"No benchmark."}],
          "rows": [
            {
              "domainId": "review",
              "title": "Review",
              "description": "Code review capabilities.",
              "coverage": "codex",
              "rows": [
                {
                  "capabilityId": "code-review",
                  "capability": "Code review",
                  "description": "Review local code changes.",
                  "terms": "review",
                  "risks": "missing benchmark",
                  "skills": [
                    {
                      "id": "gamma",
                      "definitionId": "codex:gamma",
                      "name": "Gamma",
                      "agent": "codex",
                      "quality": {"score": "81"},
                      "readiness": {"value": "Partial"},
                      "reason": "Purpose overlap.",
                      "evidence": "catalog:gamma",
                      "safety": "provider not sent"
                    }
                  ],
                  "evidence": [{"title":"Catalog","detail":"Gamma capability.","source":"knowledge.buildCapabilityTaxonomy"}]
                }
              ],
              "gaps": "No trace imported.",
              "blockers": "None.",
              "evidence": [{"title":"Domain","detail":"Review domain evidence.","source":"catalog"}],
              "safety": "provider not sent"
            }
          ],
          "gaps": "No trace imported.",
          "blockers": "None.",
          "evidence": [{"label":"Catalog","message":"Alias evidence.","agent":"codex"}],
          "safety_flags": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(CapabilityTaxonomyResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.54", "GeneratedBy alias should decode.")
        try expectEqual(result.filters.includeGaps, false, "includeGaps alias should decode.")
        try expectEqual(result.summary.summaryText, "Review taxonomy found.", "String summary should decode.")
        try expectEqual(result.coverageByAgent.first?.skillCount, 1, "Coverage skill arrays should count.")
        try expectEqual(result.coverageByAgent.first?.notes, ["No benchmark."], "Coverage gaps should become notes.")
        try expectEqual(result.domains.first?.id, "review", "DomainId alias should decode.")
        try expectEqual(result.domains.first?.coverageByAgent.first?.agent, "codex", "String coverage should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.id, "code-review", "CapabilityId alias should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.keywords, ["review"], "Terms string should decode.")
        try expectEqual(result.domains.first?.capabilities.first?.representativeSkills.first?.definitionID, "codex:gamma", "DefinitionId alias should decode.")
        try expectEqual(result.domains.first?.gapNotes, ["No trace imported."], "String domain gap should decode.")
        try expectEqual(result.blockerNotes, ["None."], "String blocker should decode.")
        try expectEqual(result.evidenceReferences.first?.title, "Catalog", "Evidence aliases should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }
}
