import Foundation

enum SkillStateFilter: String, CaseIterable, Identifiable {
    case all
    case needsTriage
    case brokenOrMissing
    case risky
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
        case .needsTriage:
            return UIStrings.text("filter.needsTriage", "Needs Triage")
        case .brokenOrMissing:
            return UIStrings.text("filter.brokenOrMissing", "Broken / Missing")
        case .risky:
            return UIStrings.text("filter.risky", "Risky")
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
    case pi
    case hermes
    case openclaw

    var id: String { rawValue }

    static let managementCases: [SkillAgentFilter] = [
        .claudeCode,
        .codex,
        .opencode,
        .pi,
        .hermes,
        .openclaw
    ]

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
        case .pi:
            return UIStrings.pi
        case .hermes:
            return UIStrings.hermes
        case .openclaw:
            return UIStrings.openclaw
        }
    }

    func includes(_ skill: SkillRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .claudeCode, .codex, .opencode, .pi, .hermes, .openclaw:
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
        let riskyFindingInstanceIDs = Set(findings.filter(Self.isRiskFinding).compactMap(\.instanceId))
        let conflictInstanceIDs = Set(conflicts.flatMap(\.instanceIds))
        let sameAgentConflictInstanceIDs = sameAgentConflictInstanceIDs(skills: skills, conflicts: conflicts)
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
            case .needsTriage:
                let status = DisplayText.statusKind(skill.state, enabled: skill.enabled)
                return findingInstanceIDs.contains(skill.id)
                    || sameAgentConflictInstanceIDs.contains(skill.id)
                    || status == .broken
                    || status == .missing
                    || status == .unknown
            case .brokenOrMissing:
                let status = DisplayText.statusKind(skill.state, enabled: skill.enabled)
                return status == .broken || status == .missing
            case .risky:
                return riskyFindingInstanceIDs.contains(skill.id)
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
                return findingInstanceIDs.contains(skill.id)
            case .withConflicts:
                return conflictInstanceIDs.contains(skill.id)
                    && sameAgentConflictInstanceIDs.contains(skill.id)
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
        case SkillAgentFilter.pi.rawValue:
            return 3
        case SkillAgentFilter.hermes.rawValue:
            return 4
        case SkillAgentFilter.openclaw.rawValue:
            return 5
        default:
            return 6
        }
    }

    private static func agentSearchText(for agent: String) -> String {
        var aliases = [agent, DisplayText.agent(agent)]
        switch agent {
        case SkillAgentFilter.claudeCode.rawValue:
            aliases.append("claude")
        case SkillAgentFilter.opencode.rawValue:
            aliases.append("open code")
        case SkillAgentFilter.pi.rawValue:
            aliases.append("pi coding agent")
        case SkillAgentFilter.openclaw.rawValue:
            aliases.append("open claw")
        default:
            break
        }
        return aliases.joined(separator: " ")
    }

    private static func isRiskFinding(_ finding: RuleFindingRecord) -> Bool {
        finding.isRiskCategoryFinding
    }

    private static func sameAgentConflictInstanceIDs(
        skills: [SkillRecord],
        conflicts: [ConflictGroupRecord]
    ) -> Set<String> {
        let agentBySkillID = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0.agent) })
        var ids = Set<String>()
        for conflict in conflicts {
            let groupedIDs = Dictionary(grouping: conflict.instanceIds) { instanceID in
                agentBySkillID[instanceID]
            }
            for (agent, instanceIDs) in groupedIDs where agent != nil && instanceIDs.count > 1 {
                ids.formUnion(instanceIDs)
            }
        }
        return ids
    }
}
