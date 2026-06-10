@testable import SkillsCopilot

struct AgentConfigTimelineModelTests {
    func run() throws {
        try timelineShowsOnlySelectedAgentSnapshots()
        try allAgentsDoesNotMixRollbackPoints()
    }

    private func timelineShowsOnlySelectedAgentSnapshots() throws {
        let snapshots = [
            snapshot(id: "old-claude", agent: "claude-code", target: "/tmp/claude/settings.json", reason: "toggle beta", createdAt: 10),
            snapshot(id: "new-codex", agent: "codex", target: "/tmp/project/.codex/config.toml", reason: "disable gamma", createdAt: 30),
            snapshot(id: "old-codex", agent: "codex", target: "/tmp/codex/config.toml", reason: "", createdAt: 20),
            snapshot(id: "older-codex", agent: "codex", target: "/tmp/codex/older.toml", reason: "older", createdAt: 15),
        ]

        let model = AgentConfigTimelineModel.make(snapshots: snapshots, agentFilter: .codex, limit: 2)

        try expectEqual(model.isSpecificAgent, true, "Timeline should be active for a specific agent.")
        try expectEqual(model.agentTitle, UIStrings.codex, "Timeline should use selected agent display name.")
        try expectEqual(model.items.map(\.id), ["new-codex", "old-codex"], "Timeline should sort newest first and keep only the selected agent.")
        try expectEqual(model.hiddenCount, 1, "Timeline should keep older entries out of the compact sidebar.")
        try expectEqual(model.items[0].targetSummary, ".../.codex/config.toml", "Timeline should summarize config target paths.")
        try expectEqual(model.items[1].actionText, UIStrings.agentConfigTimelineDefaultAction, "Empty reasons should fall back to a stable action label.")
        try expectEqual(model.items[0].statusText, UIStrings.agentConfigTimelineStatus, "Timeline rows should expose a visible rollback-point status.")
    }

    private func allAgentsDoesNotMixRollbackPoints() throws {
        let model = AgentConfigTimelineModel.make(
            snapshots: [
                snapshot(id: "claude", agent: "claude-code", target: "/tmp/claude/settings.json", createdAt: 10),
                snapshot(id: "codex", agent: "codex", target: "/tmp/codex/config.toml", createdAt: 20),
            ],
            agentFilter: .all
        )

        try expectEqual(model.isSpecificAgent, false, "All Agents should not expose a mixed config timeline.")
        try expectEqual(model.items.count, 0, "All Agents should not mix rollback points from different agents.")
        try expectEqual(model.summaryText, UIStrings.agentConfigTimelineSelectAgent, "All Agents should ask for one selected agent.")
    }

    private func snapshot(
        id: String,
        agent: String,
        target: String,
        reason: String = "config write",
        createdAt: Int64
    ) -> ConfigSnapshotRecord {
        ConfigSnapshotRecord(
            id: id,
            agent: agent,
            scope: "agent-global",
            target: target,
            content: "{}",
            reason: reason,
            createdAt: createdAt
        )
    }
}
