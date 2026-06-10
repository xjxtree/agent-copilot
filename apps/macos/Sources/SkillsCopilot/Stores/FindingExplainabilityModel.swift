import Foundation

enum FindingRuleSource: String, Equatable, Hashable {
    case frontmatter
    case permissions
    case script
    case dependency
    case path
    case fingerprint
    case name
    case body
    case custom

    static func classify(ruleId: String) -> FindingRuleSource {
        switch ruleNamespace(for: ruleId) {
        case "frontmatter":
            return .frontmatter
        case "permissions":
            return .permissions
        case "script":
            return .script
        case "dependency":
            return .dependency
        case "path":
            return .path
        case "fingerprint":
            return .fingerprint
        case "name":
            return .name
        case "body":
            return .body
        default:
            return .custom
        }
    }

    private static func ruleNamespace(for ruleId: String) -> String {
        let normalized = ruleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let namespace = normalized.split(separator: ".", maxSplits: 1).first else {
            return ""
        }
        return String(namespace)
    }
}

enum FindingRuleCategory: String, Equatable, Hashable {
    case metadata
    case permissions
    case script
    case dependency
    case filesystem
    case provenance
    case identity
    case content
    case custom

    static func classify(ruleId: String) -> FindingRuleCategory {
        switch FindingRuleSource.classify(ruleId: ruleId) {
        case .frontmatter:
            return .metadata
        case .permissions:
            return .permissions
        case .script:
            return .script
        case .dependency:
            return .dependency
        case .path:
            return .filesystem
        case .fingerprint:
            return .provenance
        case .name:
            return .identity
        case .body:
            return .content
        case .custom:
            return .custom
        }
    }
}

struct FindingExplanation: Equatable, Hashable {
    let ruleId: String
    let severity: String
    let trigger: String
    let remediation: String
    let affectedInstanceCount: Int
    let scanEntryCount: Int
    let ruleSource: FindingRuleSource
    let ruleCategory: FindingRuleCategory
    let isRiskCategoryFinding: Bool
}

enum FindingExplainabilityModel {
    static func isRiskCategoryRuleID(_ ruleId: String) -> Bool {
        switch ruleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "frontmatter.tools-not-empty",
             "permissions.network-declared",
             "permissions.exec-needs-human",
             "script.no-shebang",
             "dependency.unknown":
            return true
        default:
            return FindingRuleSource.classify(ruleId: ruleId) == .script
        }
    }
}

extension RuleFindingRecord {
    var ruleSource: FindingRuleSource {
        FindingRuleSource.classify(ruleId: ruleId)
    }

    var ruleCategory: FindingRuleCategory {
        FindingRuleCategory.classify(ruleId: ruleId)
    }

    var isRiskCategoryFinding: Bool {
        FindingExplainabilityModel.isRiskCategoryRuleID(ruleId)
    }
}
