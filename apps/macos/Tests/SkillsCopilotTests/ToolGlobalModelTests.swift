import Foundation
@testable import SkillsCopilot

struct ToolGlobalModelTests {
    func run() throws {
        try toolGlobalScopeDisplaysAsReadOnlyPreview()
        try installPreviewRequiresConfirmationWithoutWriteBack()
        try backendInstallPreviewDecodesAsConfirmable()
    }

    private func toolGlobalScopeDisplaysAsReadOnlyPreview() throws {
        let record = toolGlobalSkill()

        try expectEqual(DisplayText.scope(record.scope), UIStrings.text("scope.toolGlobal", "Tool Global"), "Tool-global scope should use the localized display label.")
        try expectEqual(DisplayText.isToolGlobal(record), true, "Tool-global records should be recognized by the display model.")
        try expectEqual(DisplayText.isReadOnlyPreview(record), true, "Tool-global records should display as read-only preview rows.")
        try expectEqual(
            DisplayText.toggleDisabledReason(for: record, isWriting: false),
            UIStrings.toggleUnavailableToolGlobal,
            "Tool-global records should expose the install/copy confirmation disabled reason."
        )
    }

    private func installPreviewRequiresConfirmationWithoutWriteBack() throws {
        let record = toolGlobalSkill()
        let preview = ToolGlobalInstallPreview.localPreview(skill: record, target: .claudeCode)

        try expectEqual(preview.confirmationRequired, true, "Install preview should require confirmation.")
        try expectEqual(preview.writeBackEnabled, false, "Local fallback preview should not enable writes without backend install support.")
        try expectContains(preview.summary, record.name, "Install preview summary should name the skill.")
        try expectContains(preview.confirmationMessage, UIStrings.claudeCode, "Install preview confirmation should name the target agent.")
    }

    private func backendInstallPreviewDecodesAsConfirmable() throws {
        let payload = """
        {
          "source_instance_id": "tool-alpha",
          "source_path": "/tmp/app/tool-global/skills/tool-alpha/SKILL.md",
          "target_agent": "codex",
          "target_scope": "agent-global",
          "target_path": "/tmp/home/.agents/skills/tool-alpha/SKILL.md",
          "files": [],
          "risks": ["Only the tool-global SKILL.md source will be copied."],
          "confirmation": {
            "required": true,
            "confirmed": false,
            "fields": ["target_path"],
            "message": "Confirm install to copy this tool-global skill into the selected agent root."
          },
          "wrote": false,
          "snapshot_id": null
        }
        """.data(using: .utf8)!

        let preview = try JSONDecoder().decode(ToolGlobalInstallPreview.self, from: payload)

        try expectEqual(preview.skillID, "tool-alpha", "Backend install preview should map source_instance_id to the UI id.")
        try expectEqual(preview.target, ToolInstallTarget.codex, "Backend install preview should decode the target agent.")
        try expectEqual(preview.targetPath, "/tmp/home/.agents/skills/tool-alpha/SKILL.md", "Backend install preview should expose the target path.")
        try expectEqual(preview.writeBackEnabled, true, "Backend install preview should enable the explicit confirm action.")
        try expectEqual(preview.wrote, false, "Preview should remain non-mutating.")
        try expectContains(preview.risks.joined(separator: "\n"), "SKILL.md", "Backend risks should be visible in the sheet.")
    }

    private func toolGlobalSkill() -> SkillRecord {
        skill(
            id: "tool-alpha",
            agent: "tool-global",
            scope: "tool-global",
            path: "/tmp/skills-copilot/staging/tool-alpha/SKILL.md",
            definitionId: "tool:alpha",
            name: "Tool Alpha",
            state: "loaded",
            enabled: true
        )
    }
}
