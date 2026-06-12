import Foundation
@testable import SkillsCopilot

struct LocalSkillMapModelTests {
    func run() throws {
        try decodesFlexibleMapPayload()
        try decodesAliasAndStringForms()
        try decodesServiceProtocolFixture()
    }

    private struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
        let id: String?
        let ok: Bool
        let result: ResultPayload?
    }

    private func decodesFlexibleMapPayload() throws {
        let json = """
        {
          "generated_by": "local-v2.63",
          "catalog_available": true,
          "filters": {
            "agent": "claude-code",
            "selected_skill_id": "beta",
            "selected_skill_name": "Beta",
            "selected_skill_agent": "claude-code",
            "project_root": "<project-root>",
            "current_cwd": "<project-cwd>",
            "workspace": "Fixture Project",
            "limit": "30",
            "include_edges": true,
            "include_clusters": true
          },
          "summary": {
            "node_count": "2",
            "edge_count": 1,
            "cluster_count": 1,
            "domain_count": 1,
            "skill_count": 2,
            "agent_count": 1,
            "gap_count": 1,
            "blocker_count": 0,
            "evidence_count": 1,
            "selected_skill_context": "Beta in Claude Code project scope",
            "summary": "Beta sits in the release-audit cluster."
          },
          "selected_skill": {
            "instance_id": "beta",
            "definition_id": "def.beta",
            "skill_name": "Beta",
            "agent": "claude-code",
            "scope": "agent-project",
            "enabled": true,
            "state": "loaded"
          },
          "nodes": [
            {
              "node_id": "skill:beta",
              "label": "Beta",
              "kind": "skill",
              "instance_id": "beta",
              "definition_id": "def.beta",
              "skill_name": "Beta",
              "agent": "claude-code",
              "scope": "agent-project",
              "enabled": true,
              "state": "loaded",
              "domain": "Release audit",
              "cluster_id": "cluster:audit",
              "weight": "0.91",
              "reasons": "Selected skill anchors this map.",
              "evidence_refs": [{"title":"Catalog","detail":"catalog:beta"}],
              "safety_flags": ["provider not sent"]
            },
            "skill:alpha"
          ],
          "edges": [
            {
              "source_id": "skill:beta",
              "target_id": "skill:alpha",
              "relation_kind": "similar-purpose",
              "label": "Shared audit purpose",
              "strength": "0.74",
              "direction": "undirected",
              "reasons": ["Shared keywords and tools."],
              "evidence": ["similar:audit"]
            }
          ],
          "clusters": [
            {
              "cluster_id": "cluster:audit",
              "name": "Release audit",
              "kind": "domain",
              "summary": "Skills that support release audit workflows.",
              "node_ids": ["skill:beta", "skill:alpha"],
              "agents": "claude-code",
              "capabilities": ["release-audit"],
              "gap_notes": "No Codex project route.",
              "blocker_notes": [],
              "evidence_refs": ["domain:audit"],
              "safety_flags": ["provider not sent"]
            }
          ],
          "gap_rows": [{"title":"Missing Codex route","detail":"No Codex project route.","severity":"warning","agent":"codex","evidence_refs":["workspace:codex-gap"]}],
          "blocker_rows": [],
          "evidence_references": [{"title":"Local skill map","detail":"Map derived from local catalog evidence.","source":"knowledge.buildLocalSkillMap","agent":"claude-code"}],
          "prompt_request": {"enabled":false,"request_kind":"local_skill_map","summary":"Provider explanation is copy-only.","draft_copy_only":true},
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

        let result = try JSONDecoder().decode(LocalSkillMapResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.63", "Local map should decode generator metadata.")
        try expectEqual(result.filters.selectedSkillID, "beta", "Local map filters should decode selected skill id.")
        try expectEqual(result.filters.limit, 30, "Local map filters should decode string limits.")
        try expectEqual(result.summary.nodeCount, 2, "Local map summary should decode node count.")
        try expectEqual(result.summary.edgeCount, 1, "Local map summary should decode edge count.")
        try expectEqual(result.summary.summaryText, "Beta sits in the release-audit cluster.", "Local map summary should decode summary text.")
        try expectEqual(result.selectedSkill?.skillName, "Beta", "Local map should decode selected skill context.")
        try expectEqual(result.nodes.first?.nodeID, "skill:beta", "Local map nodes should decode node ids.")
        try expectEqual(result.nodes.first?.weight, 0.91, "Local map nodes should decode string weights.")
        try expectEqual(result.nodes.first?.reasons, ["Selected skill anchors this map."], "Local map node reasons should accept strings.")
        try expectEqual(result.nodes.first?.evidenceRefs, ["catalog:beta"], "Local map node evidence should accept objects.")
        try expectEqual(result.nodes[1].label, "skill:alpha", "Local map nodes should accept string shorthand.")
        try expectEqual(result.edges.first?.sourceID, "skill:beta", "Local map edges should decode source ids.")
        try expectEqual(result.edges.first?.relation, "similar-purpose", "Local map edges should decode relation aliases.")
        try expectEqual(result.edges.first?.strength, 0.74, "Local map edges should decode string strengths.")
        try expectEqual(result.clusters.first?.title, "Release audit", "Local map clusters should decode names.")
        try expectEqual(result.clusters.first?.nodeIDs, ["skill:beta", "skill:alpha"], "Local map clusters should decode node ids.")
        try expectEqual(result.clusters.first?.gapNotes, ["No Codex project route."], "Local map clusters should accept string gap notes.")
        try expectEqual(result.gapRows.first?.title, "Missing Codex route", "Local map gap rows should decode objects.")
        try expectEqual(result.evidenceReferences.first?.source, "knowledge.buildLocalSkillMap", "Local map evidence should decode source.")
        try expectEqual(result.promptRequest?.requestKind, "local_skill_map", "Local map prompt metadata should decode.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Local map must default provider request to false.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Local map must decode write-back blocked.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Local map must decode script execution blocked.")
        try expectFalse(result.safetyFlags.configMutationAllowed, "Local map must decode config mutation blocked.")
        try expectFalse(result.safetyFlags.snapshotCreated, "Local map must decode snapshot creation blocked.")
        try expectFalse(result.safetyFlags.triageMutationAllowed, "Local map must decode triage mutation blocked.")
        try expectFalse(result.safetyFlags.credentialAccessed, "Local map must decode credential access blocked.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Local map must decode cloud sync blocked.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Local map must decode telemetry blocked.")
    }

    private func decodesAliasAndStringForms() throws {
        let json = """
        {
          "generatedBy": "local-v2.63",
          "catalogAvailable": true,
          "summary": "String summary works.",
          "mapNodes": [{"id":"n1","title":"Alpha","type":"skill","score":1}],
          "links": ["Alpha -> Beta"],
          "domains": ["Audit"],
          "gaps": "No imported trace.",
          "blockers": "None.",
          "evidence": ["local-map:evidence"],
          "prompt_request": {"enabled":false,"request_kind":"routing_accuracy","draft_copy_only":true},
          "safety": ["provider not sent"]
        }
        """

        let result = try JSONDecoder().decode(LocalSkillMapResult.self, from: Data(json.utf8))
        try expectEqual(result.generatedBy, "local-v2.63", "GeneratedBy alias should decode.")
        try expectEqual(result.summary.summaryText, "String summary works.", "String summary should decode.")
        try expectEqual(result.nodes.first?.label, "Alpha", "MapNodes alias should decode.")
        try expectEqual(result.edges.first?.label, "Alpha -> Beta", "String edge should decode.")
        try expectEqual(result.clusters.first?.title, "Audit", "String domain should decode as cluster.")
        try expectEqual(result.gapRows.first?.detail, "No imported trace.", "String gaps should decode as rows.")
        try expectEqual(result.blockerRows.first?.detail, "None.", "String blockers should decode as rows.")
        try expectEqual(result.evidenceReferences.first?.detail, "local-map:evidence", "String evidence should decode.")
        try expectEqual(result.promptRequest?.requestKind, "local_skill_map", "Local map prompt metadata should normalize copied routing request kinds.")
        try expectFalse(result.safetyFlags.providerRequestSent, "String safety notes should keep provider flag false.")
    }

    private func decodesServiceProtocolFixture() throws {
        let fixtureURL = try repositoryRoot()
            .appendingPathComponent("fixtures/service-protocol/knowledge.buildLocalSkillMap.response.json")
        let data = try Data(contentsOf: fixtureURL)
        let envelope = try JSONDecoder().decode(ServiceEnvelope<LocalSkillMapResult>.self, from: data)
        guard let result = envelope.result else {
            throw NativeModelTestFailure(description: "Local skill map fixture should include a result.")
        }

        try expectEqual(envelope.ok, true, "Local skill map fixture envelope should decode ok.")
        try expectEqual(result.generatedBy, "deterministic-service", "Local map should decode service generator metadata.")
        try expectEqual(result.filters.task, "fixture local skill map", "Local map should decode service task filter.")
        try expectEqual(result.filters.nodeLimit, 32, "Local map should decode service node_limit.")
        try expectEqual(result.filters.edgeLimit, 64, "Local map should decode service edge_limit.")
        try expectEqual(result.filters.clusterLimit, 8, "Local map should decode service cluster_limit.")
        try expectEqual(result.filters.candidateInstanceIDs.count, 2, "Local map should decode service candidate ids.")
        try expectEqual(result.filters.includeTaskContext, true, "Local map should decode include_task_context.")
        try expectEqual(result.summary.nodeCount, 7, "Local map should decode returned_node_count.")
        try expectEqual(result.summary.edgeCount, 6, "Local map should decode returned_edge_count.")
        try expectEqual(result.summary.clusterCount, 2, "Local map should decode returned_cluster_count.")
        try expectEqual(result.summary.skillCount, 2, "Local map should decode candidate skill count.")
        try expectEqual(result.nodes.first?.kind, "task_coverage", "Local map should decode node_type.")
        try expectEqual(result.nodes.first?.summary, "Local skill map task context: fixture local skill map", "Local map should decode node summary.")
        try expectEqual(result.nodes.first?.tags, ["read-only", "task-context"], "Local map should decode node tags.")
        try expectEqual(result.edges.first?.relation, "task_readiness", "Local map should decode edge_type.")
        try expectEqual(result.clusters.first?.kind, "capability_domain", "Local map should decode cluster_type.")
        try expectFalse(result.safetyFlags.providerRequestSent, "Local map fixture must keep provider request false.")
        try expectFalse(result.safetyFlags.writeBackAllowed, "Local map fixture must keep writes blocked.")
        try expectFalse(result.safetyFlags.scriptExecutionAllowed, "Local map fixture must keep scripts blocked.")
        try expectFalse(result.safetyFlags.cloudSyncEnabled, "Local map fixture must keep cloud sync blocked.")
        try expectFalse(result.safetyFlags.telemetryEnabled, "Local map fixture must keep telemetry blocked.")
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
