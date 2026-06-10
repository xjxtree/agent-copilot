@testable import SkillsCopilot

struct SkillListModelTests {
    func run() throws {
        try searchMatchesNameDefinitionAndDisplayPathCaseInsensitively()
        try agentFiltersLimitResultsAndGroupsUseStableAdapterOrder()
        try stateFiltersUseEffectiveStatusFindingsAndConflicts()
        try conflictFiltersUseCurrentAgentRuntimeSemantics()
        try sortOrdersAreStableForCoreListColumns()
    }

    private func searchMatchesNameDefinitionAndDisplayPathCaseInsensitively() throws {
        try expectEqual(
            filtered(searchText: "  alpha ").map(\.id),
            ["alpha"],
            "Search should trim whitespace and match names."
        )
        try expectEqual(
            filtered(searchText: "CODEX:GAMMA").map(\.id),
            ["gamma"],
            "Search should match definition IDs case-insensitively."
        )
        try expectEqual(
            filtered(searchText: "open code").map(\.id),
            ["omega"],
            "Search should match opencode agent aliases."
        )
        try expectEqual(
            filtered(searchText: "project/beta").map(\.id),
            ["beta"],
            "Search should match display paths."
        )
    }

    private func stateFiltersUseEffectiveStatusFindingsAndConflicts() throws {
        try expectEqual(filtered(stateFilter: .enabled).map(\.id), ["alpha", "gamma", "omega"], "Enabled filter")
        try expectEqual(filtered(stateFilter: .disabled).map(\.id), ["beta"], "Disabled filter")
        try expectEqual(filtered(stateFilter: .broken).map(\.id), ["delta"], "Broken filter")
        try expectEqual(filtered(stateFilter: .missing).map(\.id), ["epsilon"], "Missing filter")
        try expectEqual(filtered(stateFilter: .shadowed).map(\.id), ["zeta"], "Shadowed filter")
        try expectEqual(filtered(stateFilter: .unknown).map(\.id), ["theta"], "Unknown filter")
        try expectEqual(filtered(stateFilter: .withFindings).map(\.id), ["gamma"], "Findings filter")
        try expectEqual(filtered(stateFilter: .withConflicts).map(\.id), ["epsilon", "gamma"], "Conflicts filter")
        try expectEqual(filtered(stateFilter: .needsTriage).map(\.id), ["delta", "epsilon", "gamma", "theta"], "Needs triage filter")
        try expectEqual(filtered(stateFilter: .risky).map(\.id), ["gamma"], "Risky filter")
    }

    private func conflictFiltersUseCurrentAgentRuntimeSemantics() throws {
        try expectEqual(
            filtered(agentFilter: .claudeCode, stateFilter: .withConflicts).map(\.id),
            [],
            "Cross-agent duplicate/source overlap should not appear as a Claude Code runtime conflict."
        )
        try expectEqual(
            filtered(agentFilter: .codex, stateFilter: .withConflicts).map(\.id),
            ["epsilon", "gamma"],
            "Same-agent Codex runtime conflicts should remain visible for the current agent."
        )
        try expectEqual(
            filtered(agentFilter: .all, stateFilter: .withConflicts).map(\.id),
            ["epsilon", "gamma"],
            "All-agent conflict filter should still use same-agent conflict semantics."
        )
    }

    private func agentFiltersLimitResultsAndGroupsUseStableAdapterOrder() throws {
        try expectEqual(filtered(agentFilter: .all).map(\.id), ["alpha", "beta", "delta", "epsilon", "gamma", "omega", "theta", "zeta"], "All agent filter")
        try expectEqual(filtered(agentFilter: .claudeCode).map(\.id), ["alpha", "beta", "delta", "theta", "zeta"], "Claude Code agent filter")
        try expectEqual(filtered(agentFilter: .codex).map(\.id), ["epsilon", "gamma"], "Codex agent filter")
        try expectEqual(filtered(agentFilter: .opencode).map(\.id), ["omega"], "opencode agent filter")

        let groups = SkillListModel.groupedByAgent(filtered(agentFilter: .all))
        try expectEqual(groups.map(\.title), [UIStrings.claudeCode, UIStrings.codex, UIStrings.opencode], "Agent groups should use display names.")
        try expectEqual(groups.map { $0.skills.map(\.id) }, [["alpha", "beta", "delta", "theta", "zeta"], ["epsilon", "gamma"], ["omega"]], "Agent groups should preserve sorted rows.")
    }

    private func sortOrdersAreStableForCoreListColumns() throws {
        try expectEqual(filtered(sortOrder: .name).map(\.id), ["alpha", "beta", "delta", "epsilon", "gamma", "omega", "theta", "zeta"], "Name sort")
        try expectEqual(filtered(sortOrder: .scope).map(\.id), ["alpha", "delta", "epsilon", "gamma", "omega", "theta", "zeta", "beta"], "Scope sort")
        try expectEqual(filtered(sortOrder: .state).map(\.id), ["delta", "epsilon", "beta", "alpha", "gamma", "omega", "zeta", "theta"], "State sort")
        try expectEqual(filtered(sortOrder: .path).map(\.id), ["epsilon", "gamma", "alpha", "zeta", "omega", "beta", "delta", "theta"], "Path sort")
    }

    private func filtered(
        searchText: String = "",
        agentFilter: SkillAgentFilter = .all,
        stateFilter: SkillStateFilter = .all,
        sortOrder: SkillSortOrder = .name
    ) -> [SkillRecord] {
        SkillListModel.filteredAndSorted(
            skills: Self.skills,
            findings: Self.findings,
            conflicts: Self.conflicts,
            searchText: searchText,
            agentFilter: agentFilter,
            stateFilter: stateFilter,
            sortOrder: sortOrder
        )
    }

    private static let skills: [SkillRecord] = [
        skill(
            id: "beta",
            scope: "agent-project",
            path: "/tmp/project/beta/SKILL.md",
            definitionId: "def.beta",
            name: "Beta",
            state: "loaded",
            enabled: false
        ),
        skill(
            id: "gamma",
            agent: "codex",
            scope: "agent-global",
            path: "/tmp/codex/skills/gamma/SKILL.md",
            definitionId: "codex:gamma",
            name: "Gamma",
            state: "loaded",
            enabled: true
        ),
        skill(
            id: "epsilon",
            agent: "codex",
            scope: "agent-global",
            path: "/tmp/codex/skills/epsilon/SKILL.md",
            definitionId: "codex:epsilon",
            name: "Epsilon",
            state: "missing",
            enabled: false
        ),
        skill(
            id: "alpha",
            scope: "agent-global",
            path: "/tmp/global/alpha/SKILL.md",
            definitionId: "def.alpha",
            name: "Alpha",
            state: "loaded",
            enabled: true
        ),
        skill(
            id: "zeta",
            scope: "agent-global",
            path: "/tmp/global/zeta/SKILL.md",
            definitionId: "def.zeta",
            name: "Zeta",
            state: "shadowed",
            enabled: true
        ),
        skill(
            id: "delta",
            scope: "agent-global",
            path: "/tmp/project/delta/SKILL.md",
            definitionId: "def.delta",
            name: "Delta",
            state: "broken",
            enabled: false
        ),
        skill(
            id: "omega",
            agent: "opencode",
            scope: "agent-global",
            path: "/tmp/opencode/skills/omega/SKILL.md",
            definitionId: "opencode:omega",
            name: "Omega",
            state: "loaded",
            enabled: true
        ),
        skill(
            id: "theta",
            scope: "agent-global",
            path: "/tmp/project/theta/SKILL.md",
            definitionId: "def.theta",
            name: "Theta",
            state: "root-error",
            enabled: false
        ),
    ]

    private static let findings: [RuleFindingRecord] = [
        RuleFindingRecord(
            id: "finding-instance",
            instanceId: "gamma",
            definitionId: nil,
            ruleId: "frontmatter.tools-not-empty",
            severity: "warning",
            message: "Tool permissions need review",
            suggestion: nil,
            createdAt: 0
        ),
        RuleFindingRecord(
            id: "finding-definition",
            instanceId: nil,
            definitionId: "def.alpha",
            ruleId: "fingerprint.changed",
            severity: "info",
            message: "Fingerprint changed",
            suggestion: nil,
            createdAt: 0
        ),
    ]

    private static let conflicts: [ConflictGroupRecord] = [
        ConflictGroupRecord(
            id: "conflict-definition",
            definitionId: "def.beta",
            reason: "name-collision",
            winnerId: "beta",
            instanceIds: ["beta", "gamma"]
        ),
        ConflictGroupRecord(
            id: "conflict-instance",
            definitionId: "def.unmatched",
            reason: "path-collision",
            winnerId: nil,
            instanceIds: ["gamma", "epsilon"]
        ),
    ]
}
