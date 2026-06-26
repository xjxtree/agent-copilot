import Foundation
@testable import SkillsCopilot

struct SkillManagerModelTests {
    func run() throws {
        try defaultTargetsMatchSupportedManagerOrder()
        try mutationPreviewDecodesCommandAndAgentTargets()
    }

    private func defaultTargetsMatchSupportedManagerOrder() throws {
        try expectEqual(
            SkillManagerAgent.defaultTargets.map(\.rawValue),
            [
                "claude-code",
                "pi",
                "opencode",
                "codex",
                "hermes-agent",
                "openclaw"
            ],
            "Skill Manager should default to every app-supported agent in the manager order."
        )
    }

    private func mutationPreviewDecodesCommandAndAgentTargets() throws {
        let payload = """
        {
          "preview": {
            "tool_id": "npx-skills",
            "operation": "install",
            "command": [
              "/usr/local/bin/npx",
              "skills",
              "add",
              "vercel-labs/agent-skills",
              "--skill",
              "frontend-design",
              "--agent",
              "claude-code",
              "--agent",
              "pi",
              "--agent",
              "opencode",
              "--agent",
              "codex",
              "--agent",
              "hermes-agent",
              "--agent",
              "openclaw",
              "-y"
            ],
            "cwd": "/tmp/project",
            "env": [
              {"key": "DISABLE_TELEMETRY", "value": "1"},
              {"key": "DO_NOT_TRACK", "value": "1"}
            ],
            "requires_confirmation": true,
            "confirmed": false,
            "network_required": true,
            "network_allowed": false,
            "will_run": false,
            "preview_token": "skill-manager:test",
            "summary": "Install preview",
            "risks": ["External manager writes selected targets."]
          },
          "output": null,
          "applied": false,
          "scanned_count": 0,
          "updated_skills": []
        }
        """.data(using: .utf8)!

        let preview = try JSONDecoder().decode(SkillManagerMutationRecord.self, from: payload)

        try expectEqual(preview.preview.toolId, "npx-skills", "Mutation preview should decode the tool id.")
        try expectEqual(preview.preview.operation, "install", "Mutation preview should decode operation.")
        try expectEqual(preview.applied, false, "Preview payload must remain non-mutating.")
        try expectEqual(
            preview.preview.command.filter { $0 == "--agent" }.count,
            SkillManagerAgent.defaultTargets.count,
            "Install preview should include one --agent flag for every default target."
        )
        try expectEqual(
            preview.preview.command.contains("--copy"),
            false,
            "Symlink distribution should not send --copy."
        )
        try expectEqual(
            preview.preview.env.contains { $0.key == "DISABLE_TELEMETRY" && $0.value == "1" },
            true,
            "Manager preview should expose telemetry-off env."
        )
    }
}
