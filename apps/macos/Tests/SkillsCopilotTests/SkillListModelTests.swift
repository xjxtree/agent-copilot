@testable import SkillsCopilot

struct SkillListModelTests {
    func run() throws {
        try detailWorkbenchSectionsExposeDiagnostics()
        try findingIssueGroupsPreserveRemediationAndImpactCounts()
        try searchMatchesNameDefinitionAndDisplayPathCaseInsensitively()
        try agentFiltersLimitResultsAndGroupsUseStableAdapterOrder()
        try stateFiltersUseEffectiveStatusFindingsAndConflicts()
        try problemItemsUseCurrentAgentRuntimeSemantics()
        try scopeFiltersSeparateProjectAndGlobalSkills()
        try sortOrdersAreStableForCoreListColumns()
        try sortDirectionCanReverseCoreListColumns()
        try skillProvenanceClassifiesAgentRootsDeterministically()
        try skillIdentitySummaryAndDedupeExplanationAreStable()
        try privacyPathDisplayRedactsAndCollapsesLocalPaths()
        try privacyPathDisplayRedactsEmbeddedEvidencePaths()
    }

    private func detailWorkbenchSectionsExposeDiagnostics() throws {
        try expectEqual(
            DetailSection.visibleCases,
            [.overview, .findings, .history, .analysis, .metadata],
            "Skill detail switcher should expose overview, issues, history, smart analysis, and metadata while omitting retired work surfaces."
        )
        try expectEqual(DetailSection.primaryWorkCases, [], "Sidebar Work surfaces should remain retired; Provider Observability lives in Settings.")
        try expectEqual(DetailSection.agentWorkspace.title, "Agent Workspace", "Agent Workspace should be the default aggregate surface.")
        try expectEqual(DetailSection.guidedCleanup.title, "Guided Cleanup Flow", "Guided Cleanup section title")
        try expectEqual(DetailSection.observability.title, "Provider Observability", "Provider Observability section title")
        try expectEqual(DetailSection.findings.title, "Issues", "Findings tab should be renamed for user-facing issue review.")
        try expectEqual(DetailSection.conflicts.title, "Issues", "Legacy conflicts route should resolve to the user-facing issue review.")
        try expectEqual(DetailSection.history.title, "History", "History section title")
        try expectEqual(DetailSection.analysis.title, "Smart Analysis", "Smart Analysis section title")
        try expectEqual(DetailSection.metadata.title, "Metadata", "Metadata section title")
        try expectEqual(DetailSection.overview.systemImage, "chart.pie", "Overview tab should use a unified icon.")
        try expectEqual(DetailSection.analysis.systemImage, "sparkles", "Smart Analysis tab should use a unified icon.")
        try expectEqual(DetailSection.metadata.systemImage, "info.circle", "Metadata tab should use a unified icon.")
    }

    private func findingIssueGroupsPreserveRemediationAndImpactCounts() throws {
        let findings = [
            RuleFindingRecord(
                id: "finding-1",
                instanceId: "alpha",
                definitionId: "def.alpha",
                ruleId: "permissions.exec-needs-human",
                severity: "warning",
                message: "Execution requires a human gate.",
                suggestion: "Require human confirmation before execution.",
                createdAt: 30
            ),
            RuleFindingRecord(
                id: "finding-2",
                instanceId: "beta",
                definitionId: "def.beta",
                ruleId: "permissions.exec-needs-human",
                severity: "warning",
                message: "Execution requires a human gate.",
                suggestion: "Require human confirmation before execution.",
                createdAt: 20
            ),
        ]

        let groups = FindingDisplayModel.issueGroups(
            findings: findings,
            severityFilter: FindingDisplayModel.allFilterValue,
            ruleFilter: FindingDisplayModel.allFilterValue
        )

        try expectEqual(groups.count, 1, "Matching findings should collapse into one issue group.")
        try expectEqual(groups[0].impactedInstanceCount, 2, "Issue groups should retain impacted instance count.")
        try expectEqual(groups[0].entryCount, 2, "Issue groups should retain scan entry count.")
        try expectEqual(groups[0].remediation, "Require human confirmation before execution.", "Issue groups should keep remediation text.")
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
        try expectEqual(filtered(stateFilter: .withFindings).map(\.id), ["delta", "epsilon", "gamma", "theta"], "Problem item filter")
        try expectEqual(filtered(stateFilter: .risky).map(\.id), ["gamma"], "Risky filter")
    }

    private func problemItemsUseCurrentAgentRuntimeSemantics() throws {
        try expectEqual(
            filtered(agentFilter: .claudeCode, stateFilter: .withFindings).map(\.id),
            ["delta", "theta"],
            "Problem items should include broken/unknown Claude Code records but not cross-agent duplicate/source-overlap groups."
        )
        try expectEqual(
            filtered(agentFilter: .codex, stateFilter: .withFindings).map(\.id),
            ["epsilon", "gamma"],
            "Problem items should include same-agent Codex runtime conflicts and missing/finding records."
        )
        try expectEqual(
            filtered(agentFilter: .all, stateFilter: .withFindings).map(\.id),
            ["delta", "epsilon", "gamma", "theta"],
            "The all-agent Problem Items filter should fold issue groups, same-agent conflicts, and broken/missing/unknown states together."
        )
        try expectEqual(
            SkillListModel.sameAgentConflictGroupCount(skills: Self.skills, conflicts: Self.conflicts),
            1,
            "Presentation conflict count should exclude cross-agent duplicate/source-overlap groups."
        )
    }

    private func scopeFiltersSeparateProjectAndGlobalSkills() throws {
        try expectEqual(filtered(scopeFilter: .project).map(\.id), ["beta"], "Project scope filter")
        try expectEqual(filtered(scopeFilter: .global).map(\.id), ["alpha", "delta", "epsilon", "gamma", "omega", "theta", "zeta"], "Global scope filter")
        try expectEqual(
            filtered(agentFilter: .codex, scopeFilter: .global).map(\.id),
            ["epsilon", "gamma"],
            "Scope filter should compose with the selected agent."
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

    private func sortDirectionCanReverseCoreListColumns() throws {
        try expectEqual(
            filtered(sortOrder: .name, sortDirection: .descending).map(\.id),
            ["zeta", "theta", "omega", "gamma", "epsilon", "delta", "beta", "alpha"],
            "Name descending sort"
        )
    }

    private func skillProvenanceClassifiesAgentRootsDeterministically() throws {
        let opencodeProject = Self.identityRecord(
            agent: "opencode",
            scope: "agent-project",
            path: "/repo/.opencode/skills/foo/SKILL.md"
        )
        let opencodeGlobal = Self.identityRecord(
            agent: "opencode",
            scope: "agent-global",
            path: "$HOME/.config/opencode/skills/foo/SKILL.md"
        )
        let opencodeClaudeCompatibility = Self.identityRecord(
            agent: "opencode",
            scope: "agent-project",
            path: "/repo/.claude/skills/foo/SKILL.md"
        )
        let opencodeAgentsCompatibility = Self.identityRecord(
            agent: "opencode",
            scope: "agent-project",
            path: "/repo/.agents/skills/foo/SKILL.md"
        )
        let opencodeConfigured = Self.identityRecord(
            agent: "opencode",
            scope: "agent-global",
            path: "/fixture/custom-opencode-skills/foo/SKILL.md"
        )
        let codexAgentsNative = Self.identityRecord(
            agent: "codex",
            scope: "agent-project",
            path: "/repo/.agents/skills/foo/SKILL.md"
        )
        let claudeAgentsCompatibility = Self.identityRecord(
            agent: "claude-code",
            scope: "agent-project",
            path: "/repo/.agents/skills/foo/SKILL.md"
        )
        let claudeGlobalDisplayAgent = Self.identityRecord(
            agent: "Claude Code",
            scope: "Agent Global",
            path: "~/.claude/skills/foo/SKILL.md"
        )
        let claudeDisplayPathOnly = Self.identityRecord(
            agent: "Claude Code",
            scope: "Agent Global",
            path: "stable-instance-id",
            displayPath: "$HOME/.claude/skills/foo/SKILL.md"
        )
        let piDirectorySkill = Self.identityRecord(
            agent: "pi",
            scope: "agent-global",
            path: "$HOME/.pi/skills/foo/SKILL.md"
        )
        let piDirectDocument = Self.identityRecord(
            agent: "pi",
            scope: "agent-global",
            path: "$HOME/.pi/skills/foo.md"
        )
        let hermesSkill = Self.identityRecord(
            agent: "hermes",
            scope: "agent-global",
            path: "$HOME/.hermes/skills/foo/SKILL.md"
        )
        let hermesExternalSkill = Self.identityRecord(
            agent: "hermes",
            scope: "agent-external",
            path: "/mnt/shared/hermes-skills/foo/SKILL.md"
        )
        let openClawSkill = Self.identityRecord(
            agent: "openclaw",
            scope: "agent-project",
            path: "/repo/skills/foo/SKILL.md"
        )

        try expectEqual(opencodeProject.provenance.rootKind, .native, "opencode project .opencode roots should be native.")
        try expectEqual(opencodeProject.provenance.scopeKind, .project, "opencode project .opencode roots should remain project scoped.")
        try expectEqual(opencodeProject.provenance.label, "opencode native project", "opencode project native label")
        try expectEqual(opencodeGlobal.provenance.rootKind, .native, "opencode ~/.config/opencode roots should be native.")
        try expectEqual(opencodeGlobal.provenance.scopeKind, .global, "opencode ~/.config/opencode roots should be global scoped.")
        try expectEqual(opencodeGlobal.provenance.label, "opencode native global", "opencode global native label")
        try expectEqual(opencodeClaudeCompatibility.provenance.rootKind, .compatibility, "opencode .claude roots should be compatibility roots.")
        try expectEqual(opencodeAgentsCompatibility.provenance.rootKind, .compatibility, "opencode .agents roots should be compatibility roots.")
        try expectEqual(opencodeConfigured.provenance.rootKind, .configured, "opencode skills.paths rows should be configured roots.")
        try expectEqual(opencodeConfigured.provenance.label, "opencode configured global", "opencode configured root label")
        try expectEqual(codexAgentsNative.provenance.rootKind, .native, "Codex .agents roots should be native roots.")
        try expectEqual(claudeAgentsCompatibility.provenance.rootKind, .unknown, "Claude Code should not treat .agents roots as native Claude roots.")
        try expectEqual(claudeGlobalDisplayAgent.provenance.rootKind, .native, "Claude Code display agent and tilde .claude roots should be native.")
        try expectEqual(claudeGlobalDisplayAgent.provenance.label, "Claude Code native global", "Claude Code display agent label")
        try expectEqual(claudeDisplayPathOnly.provenance.rootKind, .native, "Display path should classify provenance when path is a stable record ID.")
        try expectEqual(piDirectorySkill.isCatalogedSkillIdentity, true, "Pi directory SKILL.md records should remain cataloged skills.")
        try expectEqual(piDirectorySkill.catalogIdentityPath, "$HOME/.pi/skills/foo", "Pi directory SKILL.md identity should use its containing directory.")
        try expectEqual(piDirectDocument.isCatalogedSkillIdentity, false, "Pi direct .md files should not be treated as cataloged skills.")
        try expectEqual(piDirectDocument.provenance.label, "Pi document (not cataloged)", "Pi direct .md label")
        try expectEqual(hermesSkill.provenance.label, "Hermes home/profile read-only", "Hermes home/profile roots should be explicit.")
        try expectEqual(hermesExternalSkill.provenance.rootKind, .external, "Hermes external dirs should be modeled as external roots.")
        try expectEqual(hermesExternalSkill.provenance.scopeKind, .external, "Hermes external dirs should not be treated as project scope.")
        try expectEqual(hermesExternalSkill.provenance.label, "Hermes explicit external read-only", "Hermes external dirs should retain read-only provenance.")
        try expectEqual(openClawSkill.provenance.label, "OpenClaw workspace read-only", "OpenClaw should present project rows as workspace read-only provenance.")
        try expectEqual(DisplayText.scope(for: openClawSkill), UIStrings.openClawWorkspaceScope, "OpenClaw project rows should display as workspace scope.")
    }

    private func privacyPathDisplayRedactsAndCollapsesLocalPaths() throws {
        let rawPath = "/" + "Users" + "/alice/example-project/.agents/skills/very-long-skill-name-with-extra-path-segments/SKILL.md"
        let redacted = DisplayText.privacyPath(rawPath, privacyModeEnabled: true)
        try expectFalse(redacted.contains("/" + "Users" + "/alice"), "Screenshot privacy mode should redact local macOS user paths.")
        try expectFalse(!redacted.contains("$HOME"), "Screenshot privacy mode should preserve useful home-root context.")
        try expectFalse(!redacted.contains("/.../"), "Long screenshot-safe paths should be collapsed by default.")

        let revealed = DisplayText.privacyPath(rawPath, privacyModeEnabled: true, revealFull: true)
        try expectEqual(revealed, rawPath, "Explicit reveal should show the original path without mutating the model value.")
    }

    private func privacyPathDisplayRedactsEmbeddedEvidencePaths() throws {
        let evidence = "session:evidence source=/" + "Users" + "/alice/example-project/.agents/skills/review/SKILL.md"
        try expectEqual(DisplayText.isLikelyPath(evidence), true, "Evidence strings with embedded local paths should use privacy rendering.")

        let redacted = DisplayText.privacyPath(evidence, privacyModeEnabled: true)
        try expectFalse(redacted.contains("/" + "Users" + "/alice"), "Embedded evidence paths should redact local macOS user paths.")
        try expectFalse(!redacted.contains("$HOME"), "Embedded evidence paths should preserve useful redacted home context.")

        let tempEvidence = "capture=/" + "private" + "/" + "var" + "/folders/ab/cd/ef/T/completed.png"
        let redactedTemp = DisplayText.privacyPath(tempEvidence, privacyModeEnabled: true)
        try expectFalse(redactedTemp.contains("/" + "private" + "/var/folders"), "Private temp evidence paths should redact as a single temp placeholder.")
        try expectFalse(!redactedTemp.contains("<temp>/T/completed.png"), "Private temp evidence paths should retain useful screenshot filename context.")
    }

    private func skillIdentitySummaryAndDedupeExplanationAreStable() throws {
        let native = Self.identityRecord(
            id: "native",
            agent: "opencode",
            scope: "agent-project",
            path: "/repo//.opencode/skills/Foo/SKILL.md",
            definitionId: "Shared.Skill",
            name: "Foo"
        )
        let compatibility = Self.identityRecord(
            id: "compatibility",
            agent: "opencode",
            scope: "agent-project",
            path: "/repo/.claude/skills/foo/SKILL.md",
            definitionId: "shared.skill",
            name: "Foo"
        )
        let summary = native.identitySummary
        try expectEqual(summary.title, "Foo", "Identity summary should expose a stable display title.")
        try expectEqual(summary.identityKey, "definition:shared.skill", "Identity key should prefer canonical definition ID.")
        try expectEqual(summary.sourceKey, "opencode|agent-project|/repo/.opencode/skills/foo", "Source key should be canonical and deterministic.")
        try expectEqual(summary.catalogPath, "/repo/.opencode/skills/Foo", "Directory SKILL.md identity should use the containing directory.")
        try expectEqual(summary.provenanceLabel, "opencode native project", "Identity summary should carry provenance label.")

        let forward = native.dedupeExplanation(comparedWith: compatibility)
        let reverse = compatibility.dedupeExplanation(comparedWith: native)
        try expectEqual(forward.reason, .definitionId, "Dedupe should prefer definition ID matches.")
        try expectEqual(forward.summary, "Same definition ID: shared.skill", "Dedupe explanation should use canonical definition ID.")
        try expectEqual(forward, reverse, "Pairwise dedupe explanation should not depend on call order.")
    }

    private static func identityRecord(
        id: String = "identity",
        agent: String,
        scope: String,
        path: String,
        displayPath: String? = nil,
        definitionId: String = "identity.definition",
        name: String = "Identity",
        state: String = "loaded",
        enabled: Bool = true
    ) -> SkillRecord {
        SkillRecord(
            id: id,
            agent: agent,
            scope: scope,
            path: path,
            displayPath: displayPath ?? path,
            definitionId: definitionId,
            name: name,
            state: state,
            enabled: enabled
        )
    }

    private func filtered(
        searchText: String = "",
        agentFilter: SkillAgentFilter = .all,
        stateFilter: SkillStateFilter = .all,
        scopeFilter: SkillScopeFilter = .all,
        sortOrder: SkillSortOrder = .name,
        sortDirection: SkillSortDirection = .ascending
    ) -> [SkillRecord] {
        SkillListModel.filteredAndSorted(
            skills: Self.skills,
            findings: Self.findings,
            conflicts: Self.conflicts,
            searchText: searchText,
            agentFilter: agentFilter,
            stateFilter: stateFilter,
            scopeFilter: scopeFilter,
            sortOrder: sortOrder,
            sortDirection: sortDirection
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
