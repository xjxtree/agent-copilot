import Foundation
@testable import SkillsCopilot

struct CleanupQueueModelTests {
    func run() throws {
        try decodesFlexibleServicePayload()
        try filtersByKindPriorityAndAgent()
        try fallbackIsReadOnlyAndEmpty()
    }

    private func decodesFlexibleServicePayload() throws {
        let data = Data(
            """
            {
              "summary": {
                "total_count": 2,
                "counts_by_kind": {
                  "finding": 1,
                  "conflict": 1
                },
                "counts_by_priority": {
                  "high": 1,
                  "medium": 1
                },
                "read_only": true,
                "writes_allowed": false,
                "provider_request_sent": false
              },
              "items": [
                {
                  "id": "conflict-beta",
                  "kind": "conflict",
                  "severity": "high",
                  "agent": "claude-code",
                  "scope": "user",
                  "skill_id": "beta",
                  "skill_name": "Beta",
                  "title": "Duplicate runtime skill",
                  "detail": "Two same-agent skills resolve to the same name.",
                  "recommended_next_action_label": "Review conflict",
                  "read_only": true,
                  "writes_allowed": false,
                  "provider_request_sent": false
                },
                {
                  "id": "finding-alpha",
                  "kind": "finding",
                  "priority": "warning",
                  "agent": "codex",
                  "skill_id": "alpha",
                  "skill_name": "Alpha",
                  "title": "Network declaration missing",
                  "detail": "Network access is referenced but not declared.",
                  "recommended_next_action_label": "Review finding",
                  "writes_allowed": false,
                  "provider_request_sent": false
                }
              ]
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(CleanupQueueResult.self, from: data)

        try expectEqual(result.summary.total, 2, "Cleanup summary should decode totals.")
        try expectEqual(result.summary.findingCount, 1, "Cleanup summary should decode counts by kind.")
        try expectEqual(result.summary.conflictCount, 1, "Cleanup summary should decode conflict counts by kind.")
        try expectEqual(result.items.map(\.id), ["conflict-beta", "finding-alpha"], "Cleanup items should sort by priority rank.")
        try expectEqual(result.items[0].nextActionLabel, "Review conflict", "Cleanup items should decode service next action labels.")
        try expectEqual(result.items[0].skillScope, "user", "Cleanup items should decode service scope as skill scope.")
        try expectEqual(result.items[0].priority, .high, "Severity should decode as priority fallback.")
        try expectEqual(result.items[1].priority, .medium, "Warning should normalize to medium priority.")
        try expectEqual(result.items[1].scriptExecutionBlocked, true, "Missing safety flags should default to blocked.")
        try expectEqual(result.items[1].aiProviderCallBlocked, true, "AI provider calls should default to blocked.")
        try expectEqual(result.items[1].credentialStorageBlocked, true, "Credential storage should default to blocked.")
    }

    private func filtersByKindPriorityAndAgent() throws {
        let items = [
            item(id: "a", kind: .finding, priority: .critical, agent: "claude-code"),
            item(id: "b", kind: .analysis, priority: .info, agent: "codex"),
            item(id: "c", kind: .conflict, priority: .high, agent: "claude-code"),
        ]

        try expectEqual(
            CleanupQueueModel.filtered(items: items, kindFilter: .conflict, priorityFilter: .criticalHigh, agentFilter: .claudeCode).map(\.id),
            ["c"],
            "Cleanup filters should compose kind, priority, and selected agent."
        )

        try expectEqual(
            CleanupQueueModel.filtered(items: items, kindFilter: .all, priorityFilter: .lowInfo, agentFilter: .all).map(\.id),
            ["b"],
            "All-agent cleanup filtering should keep low/info analysis insights."
        )
    }

    private func fallbackIsReadOnlyAndEmpty() throws {
        let result = CleanupQueueResult.emptyFallback(reason: "unavailable")

        try expectEqual(result.summary.total, 0, "Fallback should expose an empty queue.")
        try expectEqual(result.readOnly, true, "Fallback should remain read-only.")
        try expectEqual(result.fallbackReason, "unavailable", "Fallback should preserve the unavailable reason.")
    }

    private func item(id: String, kind: CleanupQueueKind, priority: CleanupQueuePriority, agent: String) -> CleanupQueueItem {
        CleanupQueueItem(
            id: id,
            kind: kind,
            priority: priority,
            agent: agent,
            skillID: id,
            skillName: id,
            skillScope: "user",
            title: id,
            detail: id,
            nextActionLabel: "Open"
        )
    }
}
