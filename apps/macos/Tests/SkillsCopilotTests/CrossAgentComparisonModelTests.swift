import Foundation
@testable import SkillsCopilot

struct CrossAgentComparisonModelTests {
    func run() throws {
        try decodesFlexibleServicePayload()
        try decodesArrayPayload()
        try localFallbackGroupsSameNameAcrossAgents()
    }

    private func decodesFlexibleServicePayload() throws {
        let data = Data(
            """
            {
              "summary": {
                "group_count": 1,
                "compared_agent_count": 2,
                "capability_mismatch_count": 1,
                "state_mismatch_count": 1
              },
              "comparisons": [
                {
                  "group_id": "cmp-review",
                  "canonical_name": "review",
                  "reason": "same-name",
                  "severity": "warning",
                  "diff_summary": "Codex is disabled while Claude Code is enabled.",
                  "selected_instance_ids": ["claude-review"],
                  "instances": [
                    {
                      "skill_id": "claude-review",
                      "skill_name": "review",
                      "agent": "claude-code",
                      "state": "loaded",
                      "enabled": true,
                      "source_scope": "user",
                      "source_root": "Claude native global",
                      "display_path": "$HOME/.claude/skills/review/SKILL.md",
                      "definition_id": "review",
                      "writable_capability": true,
                      "finding_count": 0
                    },
                    {
                      "instance_id": "codex-review",
                      "name": "review",
                      "agent": "codex",
                      "status": "loaded",
                      "enabled": false,
                      "scope": "project",
                      "root": "Codex project root",
                      "path": "<project>/.agents/skills/review/SKILL.md",
                      "definition_id": "review",
                      "capability": { "supported": false, "status": "blocked", "reason": "read-only fixture" },
                      "writable_reason": "read-only fixture",
                      "risk_finding_count": 1
                    }
                  ]
                }
              ],
              "writes_allowed": false
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(CrossAgentComparisonResult.self, from: data)

        try expectEqual(result.readOnly, true, "Cross-agent comparison payload should remain read-only when writes are not allowed.")
        try expectEqual(result.summary.totalCount, 1, "Summary should decode group count alias.")
        try expectEqual(result.summary.agentCount, 2, "Summary should decode compared agent count alias.")
        try expectEqual(result.groups.first?.id, "cmp-review", "Group ID should decode alias.")
        try expectEqual(result.groups.first?.title, "review", "Group title should decode canonical name alias.")
        try expectEqual(result.groups.first?.differences, ["Codex is disabled while Claude Code is enabled."], "String diff summary should normalize to differences.")
        try expectEqual(result.groups.first?.members.map(\.instanceID), ["claude-review", "codex-review"], "Members should decode mixed instance aliases.")
        try expectEqual(result.groups.first?.members[1].writableCapability, false, "Nested capability should decode supported=false.")
        try expectEqual(result.group(for: skill(id: "claude-review", scope: "user", path: "$HOME/.claude/skills/review/SKILL.md", definitionId: "review", name: "review"))?.id, "cmp-review", "Selected skill lookup should find member group.")
    }

    private func decodesArrayPayload() throws {
        let data = Data(
            """
            [
              {
                "id": "array-group",
                "title": "lint",
                "members": [
                  { "id": "a", "name": "lint", "agent": "claude-code", "enabled": true },
                  { "id": "b", "name": "lint", "agent": "opencode", "enabled": true }
                ]
              }
            ]
            """.utf8
        )

        let result = try JSONDecoder().decode(CrossAgentComparisonResult.self, from: data)

        try expectEqual(result.summary.totalCount, 1, "Array payload should synthesize summary.")
        try expectEqual(result.summary.agentCount, 2, "Array payload should count compared agents.")
        try expectEqual(result.groups.first?.title, "lint", "Array payload should decode groups directly.")
    }

    private func localFallbackGroupsSameNameAcrossAgents() throws {
        let skills = [
            skill(id: "claude-review", agent: "claude-code", scope: "user", path: "$HOME/.claude/skills/review/SKILL.md", definitionId: "review", name: "review", enabled: true),
            skill(id: "codex-review", agent: "codex", scope: "project", path: "<project>/.agents/skills/review/SKILL.md", definitionId: "review-v2", name: "review", enabled: false),
            skill(id: "codex-only", agent: "codex", scope: "project", path: "<project>/.agents/skills/solo/SKILL.md", definitionId: "solo", name: "solo", enabled: true),
        ]
        let findings = [
            RuleFindingRecord(
                id: "finding-codex-review",
                instanceId: "codex-review",
                definitionId: "review-v2",
                ruleId: "permissions.network-declared",
                severity: "warning",
                message: "Network access is referenced but not declared.",
                suggestion: nil,
                createdAt: 1
            )
        ]

        let result = CrossAgentComparisonResult.local(
            skills: skills,
            findings: findings,
            capabilities: [],
            agentFilter: .all,
            reason: "local"
        )

        try expectEqual(result.groups.count, 1, "Local fallback should group same-name skills across agents only.")
        try expectEqual(result.groups[0].members.map(\.instanceID), ["claude-review", "codex-review"], "Local fallback should include both cross-agent members.")
        try expectEqual(result.groups[0].hasEnabledMismatch, true, "Local fallback should detect enabled mismatch.")
        try expectEqual(result.groups[0].differences.contains(UIStrings.crossAgentComparisonDifferenceDefinition), true, "Local fallback should explain definition differences.")
        try expectEqual(result.summary.riskCount, 1, "Local fallback should count risk groups with findings.")
    }
}
