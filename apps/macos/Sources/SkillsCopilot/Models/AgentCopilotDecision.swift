import Foundation

enum AgentCopilotDecisionTarget: String, CaseIterable, Hashable {
    case taskCockpit
    case review
    case guidedCleanup
    case providerObservability
}

enum AgentCopilotDecisionPriority: Int, CaseIterable, Comparable, Hashable {
    case watch = 0
    case low = 100
    case medium = 200
    case high = 300
    case critical = 400

    static func < (lhs: AgentCopilotDecisionPriority, rhs: AgentCopilotDecisionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct AgentCopilotDecisionItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let status: String
    let systemImage: String
    let priority: AgentCopilotDecisionPriority
    let impactScore: Int
    let evidenceRefs: [String]
    let target: AgentCopilotDecisionTarget

    var hasEvidence: Bool {
        !evidenceRefs.isEmpty
    }
}

typealias AgentDecisionItem = AgentCopilotDecisionItem

enum AgentCopilotDecisionModel {
    static func sorted(_ items: [AgentCopilotDecisionItem]) -> [AgentCopilotDecisionItem] {
        items.sorted { left, right in
            if left.priority != right.priority {
                return left.priority > right.priority
            }
            if left.impactScore != right.impactScore {
                return left.impactScore > right.impactScore
            }
            if left.evidenceRefs.count != right.evidenceRefs.count {
                return left.evidenceRefs.count > right.evidenceRefs.count
            }
            return left.id.localizedStandardCompare(right.id) == .orderedAscending
        }
    }

    static func refs(_ values: String?...) -> [String] {
        values.compactMap { value in
            let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return normalized.isEmpty ? nil : normalized
        }
    }
}
