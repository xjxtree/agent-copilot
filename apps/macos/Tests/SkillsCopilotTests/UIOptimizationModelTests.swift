import Foundation
@testable import SkillsCopilot

struct UIOptimizationModelTests {
    func run() throws {
        try sidebarSelectionUsesNativeMutedTreatment()
        try secondarySidebarListsUseGlobalTreatment()
        try skillListDensityMatchesOptimizationPlan()
        try emptyAgentSkillListsExplainAgentContext()
        try detailHeaderUsesCompactCopyableMetadata()
        try detailFeedbackUsesInlineToast()
        try settingsPreflightAndManagerSurfacesHaveStablePresentation()
        try skillManagerPreviewMetadataIsCompactAndActionSafe()
    }

    private func sidebarSelectionUsesNativeMutedTreatment() throws {
        try expectEqual(
            UIOptimizationPresentation.sidebarSelection.usesSaturatedAccentBackground,
            false,
            "Sidebar selection should avoid saturated accent backgrounds."
        )
        try expectEqual(
            UIOptimizationPresentation.sidebarSelection.usesWhiteSelectedText,
            false,
            "Sidebar selected rows should keep readable primary text instead of forcing white text."
        )
        try expectEqual(
            UIOptimizationPresentation.sidebarSelection.accentLineWidth,
            3,
            "Sidebar selected rows should use a 3pt brand accent line."
        )
    }

    private func secondarySidebarListsUseGlobalTreatment() throws {
        try expectEqual(
            UIOptimizationPresentation.sessionList.usesSingleLineFilterToolbar,
            true,
            "Session sidebar filters, search, and refresh should fit the unified toolbar model."
        )
        try expectEqual(
            UIOptimizationPresentation.sessionList.refreshUsesIconOnly,
            true,
            "Session refresh should use an icon-only toolbar action."
        )
        try expectEqual(
            UIOptimizationPresentation.configList.usesSingleLineFilterToolbar,
            true,
            "Config sidebar scope, search, and refresh should fit the unified toolbar model."
        )
        try expectEqual(
            UIOptimizationPresentation.configList.minimumSearchWidth,
            220,
            "Config search should keep the same minimum width as the optimized skill/session sidebars."
        )
        try expectEqual(
            UIOptimizationPresentation.configList.compactRowMaxHeight,
            44,
            "Config sidebar rows should stay in the compact global row-height range."
        )
    }

    private func skillListDensityMatchesOptimizationPlan() throws {
        try expectEqual(
            UIOptimizationPresentation.skillList.minimumSecondaryColumnWidth,
            360,
            "The middle skill list column should not collapse below the optimized minimum width."
        )
        try expectEqual(
            UIOptimizationPresentation.skillList.minimumSearchWidth,
            220,
            "Skill search should retain the proposed minimum width."
        )
        try expectEqual(
            UIOptimizationPresentation.skillList.compactRowMinHeight,
            36,
            "Compact skill rows should start at the proposed 36pt height."
        )
        try expectEqual(
            UIOptimizationPresentation.skillList.compactRowMaxHeight,
            40,
            "Compact skill rows should cap at the proposed 40pt height."
        )
        try expectEqual(
            UIOptimizationPresentation.skillList.usesSingleLineFilterToolbar,
            true,
            "Skill filters should be modeled as a single-line toolbar at regular widths."
        )
    }

    private func emptyAgentSkillListsExplainAgentContext() throws {
        let agentEmptyMessage = UIOptimizationPresentation.skillList.emptyFilteredMessage(
            agentFilter: .claudeCode,
            hasActiveProjectContext: false,
            hasActiveSearchOrFilter: false
        )

        try expectFalse(
            agentEmptyMessage == UIStrings.noSkillsMatchSearch,
            "An empty selected agent should not look like a failed search when no search or filters are active."
        )
        try expectEqual(
            agentEmptyMessage.contains(UIStrings.claudeCode),
            true,
            "The empty message should name the selected agent so users know the data is hidden by agent context."
        )

        try expectEqual(
            UIOptimizationPresentation.skillList.emptyFilteredMessage(
                agentFilter: .claudeCode,
                hasActiveProjectContext: false,
                hasActiveSearchOrFilter: true
            ),
            UIStrings.noSkillsMatchSearch,
            "Active search or filter criteria should still use the filtered-empty copy."
        )
    }

    private func detailHeaderUsesCompactCopyableMetadata() throws {
        try expectEqual(
            UIOptimizationPresentation.detailHeader.height,
            48,
            "The detail header should use the proposed compact 44-48pt range."
        )
        try expectEqual(
            UIOptimizationPresentation.detailHeader.definitionUsesMonospacedFont,
            true,
            "Definition hashes should use monospaced presentation."
        )
        try expectEqual(
            UIOptimizationPresentation.detailHeader.primaryToggleLivesInMenu,
            true,
            "Risky enable/disable actions should move out of the prominent blue primary button slot."
        )
    }

    private func detailFeedbackUsesInlineToast() throws {
        try expectEqual(
            UIOptimizationPresentation.detailFeedback.usesOverlayToast,
            true,
            "Detail feedback should render as a lightweight toast instead of a full-width content banner."
        )
        try expectEqual(
            UIOptimizationPresentation.detailFeedback.maximumWidth,
            420,
            "Detail feedback toasts should keep a compact readable width."
        )
    }

    private func settingsPreflightAndManagerSurfacesHaveStablePresentation() throws {
        try expectEqual(
            UIOptimizationPresentation.settings.minimumWidth,
            760,
            "Settings should keep the existing stable minimum window width."
        )
        try expectEqual(
            UIOptimizationPresentation.settings.usesUnifiedSectionHeaders,
            true,
            "Settings pages should share compact header and section presentation."
        )
        try expectEqual(
            UIOptimizationPresentation.taskPreflight.sheetMinimumWidth,
            950,
            "Task Preflight should retain the optimized two-column sheet width."
        )
        try expectEqual(
            UIOptimizationPresentation.taskPreflight.historyColumnWidth,
            270,
            "Task Preflight history should remain a stable right-side column."
        )
        try expectEqual(
            UIOptimizationPresentation.taskPreflight.fixedAgentChipWidth,
            96,
            "Task Preflight agent chips should use a fixed width so labels do not resize the row."
        )
        try expectEqual(
            UIOptimizationPresentation.taskPreflight.showsProviderUnavailableGate,
            true,
            "Task Preflight should explicitly gate provider-unavailable states before build actions."
        )
        try expectEqual(
            UIOptimizationPresentation.skillManager.usesSegmentedWorkflows,
            true,
            "Skill Manager should separate search/install, installed/update, and local library workflows."
        )
        try expectEqual(
            UIOptimizationPresentation.skillManager.targetsSummaryIsPinned,
            true,
            "Skill Manager targets and safety controls should stay above workflow content."
        )
        try expectEqual(
            UIOptimizationPresentation.skillManager.toolUnavailableDisablesExternalMutations,
            true,
            "External manager unavailable states should disable search/install/remove/update controls."
        )
        try expectEqual(
            UIOptimizationPresentation.skillManager.usesSurfaceLocalFeedback,
            true,
            "Skill Manager errors should stay scoped to the sheet instead of leaking into detail empty states."
        )
    }

    private func skillManagerPreviewMetadataIsCompactAndActionSafe() throws {
        let preview = SkillManagerCommandPreview(
            toolId: "npx-skills",
            operation: "install",
            command: ["/usr/local/bin/npx", "skills", "add", "demo/agent-skills"],
            cwd: "/tmp/project",
            env: [],
            requiresConfirmation: true,
            confirmed: false,
            networkRequired: true,
            networkAllowed: false,
            willRun: false,
            previewToken: "skill-manager:test",
            summary: "Install preview",
            risks: ["External manager writes selected targets."],
            source: "demo/agent-skills",
            skills: []
        )

        let rows = preview.compactMetadataRows
        try expectEqual(
            rows.map { $0.label },
            ["CWD", "Confirmed", "Network", "Token"],
            "Preview metadata should use a compact key-value row order."
        )
        try expectEqual(
            rows.filter { $0.isCopyable }.map { $0.label },
            ["CWD", "Token"],
            "Only path/token-like preview metadata should expose copy affordances."
        )
        try expectEqual(
            preview.requiresExplicitApplyConfirmation,
            true,
            "Write-capable manager operations should remain explicit-confirm before apply."
        )
    }
}
