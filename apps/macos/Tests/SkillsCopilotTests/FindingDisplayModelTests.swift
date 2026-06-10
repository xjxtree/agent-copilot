@testable import SkillsCopilot

struct FindingDisplayModelTests {
    func run() throws {
        try groupsSortBySeverityThenRule()
        try filtersBySeverityAndRule()
        try issueGroupsDeduplicateRepeatedScanEntries()
        try remediationUsesSuggestionThenRuleFallback()
        try permissionSummaryLabelsUnknownAndUndeclaredValues()
    }

    private func groupsSortBySeverityThenRule() throws {
        let groups = FindingDisplayModel.grouped(
            findings: Self.findings,
            severityFilter: FindingDisplayModel.allFilterValue,
            ruleFilter: FindingDisplayModel.allFilterValue
        )

        try expectEqual(groups.map(\.severityKey), ["error", "warning", "info"], "Severity groups should use stable priority order.")
        try expectEqual(
            groups.flatMap { $0.issues.map(\.representative.id) },
            ["error-frontmatter", "warning-frontmatter-new", "warning-path", "info-fingerprint"],
            "Finding issue groups should be sorted within severity groups by rule and recency."
        )
    }

    private func filtersBySeverityAndRule() throws {
        let warningGroups = FindingDisplayModel.grouped(
            findings: Self.findings,
            severityFilter: "warning",
            ruleFilter: FindingDisplayModel.allFilterValue
        )

        try expectEqual(warningGroups.map(\.severityKey), ["warning"], "Severity filter should keep one severity group.")
        try expectEqual(warningGroups.first?.issues.map(\.representative.id), ["warning-frontmatter-new", "warning-path"], "Severity filter should keep matching findings.")

        let ruleGroups = FindingDisplayModel.grouped(
            findings: Self.findings,
            severityFilter: FindingDisplayModel.allFilterValue,
            ruleFilter: "frontmatter.required-fields"
        )

        try expectEqual(ruleGroups.map(\.severityKey), ["error", "warning"], "Rule filter should preserve severity grouping.")
        try expectEqual(ruleGroups.flatMap { $0.issues.map(\.representative.id) }, ["error-frontmatter", "warning-frontmatter-new"], "Rule filter should keep matching rule IDs.")
    }

    private func issueGroupsDeduplicateRepeatedScanEntries() throws {
        let groups = FindingDisplayModel.issueGroups(
            findings: [
                Self.finding(
                    id: "duplicate-older",
                    instanceId: "alpha",
                    ruleId: "permissions.network-declared",
                    severity: "warning",
                    message: "Network permission missing",
                    createdAt: 10,
                    suggestion: "Declare network access."
                ),
                Self.finding(
                    id: "duplicate-newer",
                    instanceId: "beta",
                    ruleId: "permissions.network-declared",
                    severity: "warning",
                    message: "Network permission missing",
                    createdAt: 20,
                    suggestion: "Declare network access."
                ),
                Self.finding(
                    id: "distinct-message",
                    instanceId: "gamma",
                    ruleId: "permissions.network-declared",
                    severity: "warning",
                    message: "Different duplicate context",
                    createdAt: 30,
                    suggestion: "Declare network access."
                ),
            ],
            severityFilter: FindingDisplayModel.allFilterValue,
            ruleFilter: FindingDisplayModel.allFilterValue
        )

        try expectEqual(groups.count, 2, "Repeated scan entries with the same rule, severity, message, and remediation should collapse into one issue group.")
        let duplicateGroup = groups.first { $0.message == "Network permission missing" }
        try expectEqual(duplicateGroup?.entryCount, 2, "Issue groups should keep the raw scan entry count for impact context.")
        try expectEqual(duplicateGroup?.impactedInstanceCount, 2, "Issue groups should count impacted skill instances separately from scan entries.")
        try expectEqual(duplicateGroup?.representative.id, "duplicate-newer", "The newest finding should be the representative entry for a deduped issue group.")
    }

    private func remediationUsesSuggestionThenRuleFallback() throws {
        let suggested = Self.finding(
            id: "suggested",
            ruleId: "permissions.network-declared",
            severity: "warning",
            createdAt: 50,
            suggestion: "Declare network access in frontmatter."
        )
        try expectEqual(
            FindingDisplayModel.remediationText(for: suggested),
            "Declare network access in frontmatter.",
            "Finding-specific suggestions should remain authoritative."
        )

        let fallback = Self.finding(
            id: "fallback",
            ruleId: "permissions.network-declared",
            severity: "warning",
            createdAt: 60
        )
        try expectEqual(
            FindingDisplayModel.remediationText(for: fallback),
            UIStrings.remediationNetworkDeclared,
            "Known V2.8 rule IDs should get actionable remediation fallback text."
        )

        let generic = Self.finding(
            id: "generic",
            ruleId: "custom.rule",
            severity: "info",
            createdAt: 70
        )
        try expectEqual(
            FindingDisplayModel.remediationText(for: generic),
            UIStrings.findingRemediationFallback("custom.rule"),
            "Unknown rule IDs should still produce a concrete remediation prompt."
        )
    }

    private func permissionSummaryLabelsUnknownAndUndeclaredValues() throws {
        let undeclared = PermissionDisplayModel.summary(for: .object([:]))
        try expectEqual(
            undeclared.rows,
            [PermissionSummaryRow(label: UIStrings.permissions, value: UIStrings.permissionUndeclared)],
            "Empty permission payloads should be labeled as undeclared or unknown."
        )
        try expectEqual(undeclared.rawText, "{}", "Empty permission payload raw text should remain visible.")

        let summary = PermissionDisplayModel.summary(
            for: .object([
                "exec": .bool(true),
                "files": .array([]),
                "network": .string("ambient"),
                "requires_human": .bool(false),
                "tools": .array([.string("Read")]),
            ])
        )

        try expectEqual(
            summary.rows.map(\.value),
            [
                "Read",
                UIStrings.permissionNoneDeclared,
                UIStrings.permissionUnknownValue("ambient"),
                UIStrings.permissionRequested,
                UIStrings.permissionNotDeclaredRequired,
            ],
            "Permission summaries should preserve declarations without implying safe or unsafe status."
        )
        try expectEqual(
            summary.rawText,
            "{\"exec\": true, \"files\": [], \"network\": \"ambient\", \"requires_human\": false, \"tools\": [\"Read\"]}",
            "Permission raw text should use stable sorted keys for review."
        )
    }

    private static let findings: [RuleFindingRecord] = [
        finding(
            id: "warning-path",
            ruleId: "path.exists",
            severity: "warning",
            createdAt: 20
        ),
        finding(
            id: "info-fingerprint",
            ruleId: "fingerprint.changed",
            severity: "info",
            createdAt: 30
        ),
        finding(
            id: "warning-frontmatter-new",
            ruleId: "frontmatter.required-fields",
            severity: "warning",
            createdAt: 40
        ),
        finding(
            id: "error-frontmatter",
            ruleId: "frontmatter.required-fields",
            severity: "error",
            createdAt: 10
        ),
    ]

    private static func finding(
        id: String,
        instanceId: String = "alpha",
        ruleId: String,
        severity: String,
        message: String? = nil,
        createdAt: Int64,
        suggestion: String? = nil
    ) -> RuleFindingRecord {
        RuleFindingRecord(
            id: id,
            instanceId: instanceId,
            definitionId: nil,
            ruleId: ruleId,
            severity: severity,
            message: message ?? "Finding \(id)",
            suggestion: suggestion,
            createdAt: createdAt
        )
    }
}
