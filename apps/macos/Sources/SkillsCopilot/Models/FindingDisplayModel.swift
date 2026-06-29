import Foundation

struct FindingSeverityGroup: Identifiable, Equatable {
    let severityKey: String
    let issues: [FindingIssueGroup]

    var id: String { severityKey }

    var title: String {
        FindingDisplayModel.severityTitle(severityKey)
    }
}

struct FindingIssueGroup: Identifiable, Equatable {
    let severityKey: String
    let ruleId: String
    let message: String
    let remediation: String
    let findings: [RuleFindingRecord]

    var id: String {
        [severityKey, ruleId, message, remediation].joined(separator: "\u{1F}")
    }

    var representative: RuleFindingRecord {
        findings[0]
    }

    var impactedInstanceCount: Int {
        let ids = Set(findings.compactMap(\.instanceId))
        return max(ids.count, findings.isEmpty ? 0 : 1)
    }

    var entryCount: Int {
        findings.count
    }

    var explanation: FindingExplanation {
        FindingExplanation(
            ruleId: ruleId,
            severity: severityKey,
            trigger: message,
            remediation: remediation,
            affectedInstanceCount: impactedInstanceCount,
            scanEntryCount: entryCount,
            ruleSource: FindingRuleSource.classify(ruleId: ruleId),
            ruleCategory: FindingRuleCategory.classify(ruleId: ruleId),
            isRiskCategoryFinding: FindingExplainabilityModel.isRiskCategoryRuleID(ruleId)
        )
    }

    var triageKeys: [String] {
        Array(Set(findings.map(\.triageKey).filter { !$0.isEmpty })).sorted()
    }

    var triageStatus: FindingTriageStatus {
        FindingTriageModel.groupStatus(for: findings.map(\.triageState))
    }

    func matchesTriageFilter(_ filter: FindingTriageFilter) -> Bool {
        findings.map(\.triageState).contains { filter.includes($0) }
    }

    var ruleSource: String {
        FindingDisplayModel.ruleSourceTitle(for: explanation.ruleSource)
    }

    var catalogTarget: String {
        FindingDisplayModel.catalogTargetSummary(for: representative)
    }

    var isRiskRelated: Bool {
        explanation.isRiskCategoryFinding
    }
}

struct FindingIssueKey: Hashable {
    let severityKey: String
    let ruleId: String
    let message: String
    let remediation: String
}

enum FindingDisplayModel {
    static let allFilterValue = "__all__"

    static func severityOptions(for findings: [RuleFindingRecord]) -> [String] {
        sortedSeverities(Set(findings.map { severityKey($0.severity) }))
    }

    static func ruleIDOptions(for findings: [RuleFindingRecord]) -> [String] {
        Array(Set(findings.map(\.ruleId)))
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
    }

    static func filtered(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [RuleFindingRecord] {
        findings.filter { finding in
            let matchesSeverity = severityFilter == allFilterValue || severityKey(finding.severity) == severityFilter
            let matchesRule = ruleFilter == allFilterValue || finding.ruleId == ruleFilter
            return matchesSeverity && matchesRule
        }
    }

    static func grouped(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [FindingSeverityGroup] {
        let visibleIssues = issueGroups(
            findings: findings,
            severityFilter: severityFilter,
            ruleFilter: ruleFilter
        )
        let grouped = Dictionary(grouping: visibleIssues, by: \.severityKey)

        return sortedSeverities(Set(grouped.keys)).map { severityKey in
            FindingSeverityGroup(
                severityKey: severityKey,
                issues: grouped[severityKey] ?? []
            )
        }
    }

    static func issueGroups(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [FindingIssueGroup] {
        let visibleFindings = filtered(findings: findings, severityFilter: severityFilter, ruleFilter: ruleFilter)
        let grouped = Dictionary(grouping: visibleFindings) { finding in
            FindingIssueKey(
                severityKey: severityKey(finding.severity),
                ruleId: normalizedText(finding.ruleId),
                message: normalizedText(finding.message),
                remediation: normalizedText(remediationText(for: finding))
            )
        }
        return grouped.map { key, findings in
            FindingIssueGroup(
                severityKey: key.severityKey,
                ruleId: key.ruleId,
                message: key.message,
                remediation: key.remediation,
                findings: sortedFindings(findings)
            )
        }
        .sorted(by: compareIssueGroups)
    }

    static func remediationText(for finding: RuleFindingRecord) -> String {
        if let suggestion = finding.suggestion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !suggestion.isEmpty {
            return suggestion
        }

        switch finding.ruleId {
        case "frontmatter.required-fields":
            return UIStrings.remediationFrontmatterRequired
        case "frontmatter.tools-not-empty":
            return UIStrings.remediationToolsNotEmpty
        case "path.exists":
            return UIStrings.remediationPathExists
        case "fingerprint.changed":
            return UIStrings.remediationFingerprintChanged
        case "permissions.network-declared":
            return UIStrings.remediationNetworkDeclared
        case "permissions.exec-needs-human":
            return UIStrings.remediationExecNeedsHuman
        case "dependency.unknown":
            return UIStrings.remediationDependencyUnknown
        default:
            return UIStrings.findingRemediationFallback(finding.ruleId)
        }
    }

    static func ruleSource(for ruleId: String) -> FindingRuleSource {
        FindingRuleSource.classify(ruleId: ruleId)
    }

    static func ruleCategory(for ruleId: String) -> FindingRuleCategory {
        FindingRuleCategory.classify(ruleId: ruleId)
    }

    static func isRiskCategoryRuleID(_ ruleId: String) -> Bool {
        FindingExplainabilityModel.isRiskCategoryRuleID(ruleId)
    }

    static func ruleSourceTitle(for source: FindingRuleSource) -> String {
        switch source {
        case .frontmatter:
            return UIStrings.findingSourceFrontmatter
        case .permissions:
            return UIStrings.findingSourcePermission
        case .script:
            return UIStrings.findingSourceScript
        case .dependency:
            return UIStrings.findingSourceDependency
        case .path:
            return UIStrings.findingSourcePath
        case .fingerprint:
            return UIStrings.findingSourceFingerprint
        case .name, .body, .custom:
            return UIStrings.findingSourceCatalog
        }
    }

    static func catalogTargetSummary(for finding: RuleFindingRecord) -> String {
        let definition = normalizedOptional(finding.definitionId)
        let instance = normalizedOptional(finding.instanceId)

        switch (definition, instance) {
        case (.some(let definition), .some(let instance)):
            return UIStrings.findingCatalogTarget(definition: definition, instance: instance)
        case (.some(let definition), .none):
            return UIStrings.findingCatalogDefinition(definition)
        case (.none, .some(let instance)):
            return UIStrings.findingCatalogInstance(instance)
        case (.none, .none):
            return UIStrings.findingNoCatalogTarget
        }
    }

    static func severityTitle(_ severityKey: String) -> String {
        if severityKey == "unknown" {
            return UIStrings.unknown.uppercased()
        }
        return severityKey.uppercased()
    }

    static func severityKey(_ severity: String) -> String {
        let normalized = severity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? "unknown" : normalized
    }

    private static func sortedSeverities(_ severities: Set<String>) -> [String] {
        severities.sorted { lhs, rhs in
            let lhsRank = severityRank(lhs)
            let rhsRank = severityRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private static func sortedFindings(_ findings: [RuleFindingRecord]) -> [RuleFindingRecord] {
        findings.sorted { lhs, rhs in
            if lhs.ruleId != rhs.ruleId {
                return lhs.ruleId.localizedStandardCompare(rhs.ruleId) == .orderedAscending
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private static func compareIssueGroups(_ lhs: FindingIssueGroup, _ rhs: FindingIssueGroup) -> Bool {
        let lhsRank = severityRank(lhs.severityKey)
        let rhsRank = severityRank(rhs.severityKey)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        if lhs.ruleId != rhs.ruleId {
            return lhs.ruleId.localizedStandardCompare(rhs.ruleId) == .orderedAscending
        }
        let lhsCreatedAt = lhs.representative.createdAt
        let rhsCreatedAt = rhs.representative.createdAt
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt > rhsCreatedAt
        }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }

    private static func normalizedText(_ text: String) -> String {
        let collapsed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? UIStrings.emptyPlaceholder : collapsed
    }

    private static func normalizedOptional(_ text: String?) -> String? {
        guard let text else {
            return nil
        }
        let normalized = normalizedText(text)
        return normalized == UIStrings.emptyPlaceholder ? nil : normalized
    }

    private static func severityRank(_ severityKey: String) -> Int {
        switch severityKey {
        case "critical":
            return 0
        case "error":
            return 1
        case "warning", "warn":
            return 2
        case "info", "notice":
            return 3
        default:
            return 10
        }
    }
}
