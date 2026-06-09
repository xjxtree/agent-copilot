import Foundation

enum SkillStateFilter: String, CaseIterable, Identifiable {
    case all
    case enabled
    case disabled
    case broken
    case missing
    case shadowed
    case unknown
    case withFindings
    case withConflicts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return UIStrings.text("filter.all", "All")
        case .enabled:
            return UIStrings.text("filter.enabled", "Enabled")
        case .disabled:
            return UIStrings.text("filter.disabled", "Disabled")
        case .broken:
            return UIStrings.stateBroken
        case .missing:
            return UIStrings.stateMissing
        case .shadowed:
            return UIStrings.stateShadowed
        case .unknown:
            return UIStrings.stateUnknown
        case .withFindings:
            return UIStrings.findings
        case .withConflicts:
            return UIStrings.conflicts
        }
    }
}

enum SkillAgentFilter: String, CaseIterable, Identifiable {
    case all
    case claudeCode = "claude-code"
    case codex
    case opencode

    var id: String { rawValue }

    static let managementCases: [SkillAgentFilter] = [.claudeCode, .codex, .opencode]

    var title: String {
        switch self {
        case .all:
            return UIStrings.text("filter.all", "All")
        case .claudeCode:
            return UIStrings.claudeCode
        case .codex:
            return UIStrings.codex
        case .opencode:
            return UIStrings.opencode
        }
    }

    func includes(_ skill: SkillRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .claudeCode, .codex, .opencode:
            return skill.agent == rawValue
        }
    }
}

enum SkillSortOrder: String, CaseIterable, Identifiable {
    case name
    case scope
    case state
    case path

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            return UIStrings.text("sort.name", "Name")
        case .scope:
            return UIStrings.scope
        case .state:
            return UIStrings.state
        case .path:
            return UIStrings.text("sort.path", "Path")
        }
    }
}

struct SkillAgentGroup: Identifiable, Hashable {
    let agent: String
    let title: String
    let skills: [SkillRecord]

    var id: String { agent }
}

enum SkillListModel {
    static func filteredAndSorted(
        skills: [SkillRecord],
        findings: [RuleFindingRecord],
        conflicts: [ConflictGroupRecord],
        searchText: String,
        agentFilter: SkillAgentFilter,
        stateFilter: SkillStateFilter,
        sortOrder: SkillSortOrder
    ) -> [SkillRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let findingInstanceIDs = Set(findings.compactMap(\.instanceId))
        let findingDefinitionIDs = Set(findings.compactMap(\.definitionId))
        let conflictDefinitionIDs = Set(conflicts.map(\.definitionId))
        let conflictInstanceIDs = Set(conflicts.flatMap(\.instanceIds))
        let searched = query.isEmpty
            ? skills
            : skills.filter { skill in
                skill.name.localizedCaseInsensitiveContains(query)
                    || skill.definitionId.localizedCaseInsensitiveContains(query)
                    || skill.displayPath.localizedCaseInsensitiveContains(query)
                    || agentSearchText(for: skill.agent).localizedCaseInsensitiveContains(query)
            }
        let filtered = searched.filter { skill in
            guard agentFilter.includes(skill) else {
                return false
            }
            switch stateFilter {
            case .all:
                return true
            case .enabled:
                return DisplayText.statusKind(skill.state, enabled: skill.enabled) == .enabled
            case .disabled:
                return DisplayText.statusKind(skill.state, enabled: skill.enabled) == .disabled
            case .broken:
                return DisplayText.statusKind(skill.state, enabled: skill.enabled) == .broken
            case .missing:
                return DisplayText.statusKind(skill.state, enabled: skill.enabled) == .missing
            case .shadowed:
                return DisplayText.statusKind(skill.state, enabled: skill.enabled) == .shadowed
            case .unknown:
                return DisplayText.statusKind(skill.state, enabled: skill.enabled) == .unknown
            case .withFindings:
                return findingInstanceIDs.contains(skill.id) || findingDefinitionIDs.contains(skill.definitionId)
            case .withConflicts:
                return conflictDefinitionIDs.contains(skill.definitionId) || conflictInstanceIDs.contains(skill.id)
            }
        }
        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .name:
                return compare(lhs.name, rhs.name)
            case .scope:
                if lhs.scope != rhs.scope {
                    return compare(lhs.scope, rhs.scope)
                }
                return compare(lhs.name, rhs.name)
            case .state:
                let lhsRank = DisplayText.stateSortRank(lhs.state, enabled: lhs.enabled)
                let rhsRank = DisplayText.stateSortRank(rhs.state, enabled: rhs.enabled)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                let lhsState = DisplayText.state(lhs.state, enabled: lhs.enabled)
                let rhsState = DisplayText.state(rhs.state, enabled: rhs.enabled)
                if lhsState != rhsState { return compare(lhsState, rhsState) }
                return compare(lhs.name, rhs.name)
            case .path:
                return compare(lhs.displayPath, rhs.displayPath)
            }
        }
    }

    static func groupedByAgent(_ skills: [SkillRecord]) -> [SkillAgentGroup] {
        let grouped = Dictionary(grouping: skills, by: \.agent)
        return grouped
            .map { agent, skills in
                SkillAgentGroup(agent: agent, title: DisplayText.agent(agent), skills: skills)
            }
            .sorted { lhs, rhs in
                let lhsRank = agentRank(lhs.agent)
                let rhsRank = agentRank(rhs.agent)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return compare(lhs.title, rhs.title)
            }
    }

    private static func compare(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private static func agentRank(_ agent: String) -> Int {
        switch agent {
        case SkillAgentFilter.claudeCode.rawValue:
            return 0
        case SkillAgentFilter.codex.rawValue:
            return 1
        case SkillAgentFilter.opencode.rawValue:
            return 2
        default:
            return 3
        }
    }

    private static func agentSearchText(for agent: String) -> String {
        var aliases = [agent, DisplayText.agent(agent)]
        switch agent {
        case SkillAgentFilter.claudeCode.rawValue:
            aliases.append("claude")
        case SkillAgentFilter.opencode.rawValue:
            aliases.append("open code")
        default:
            break
        }
        return aliases.joined(separator: " ")
    }
}
