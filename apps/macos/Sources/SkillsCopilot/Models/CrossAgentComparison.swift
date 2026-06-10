import Foundation

struct CrossAgentComparisonResult: Decodable, Hashable {
    let summary: CrossAgentComparisonSummary
    let groups: [CrossAgentComparisonGroup]
    let readOnly: Bool
    let fallbackReason: String?

    enum CodingKeys: String, CodingKey {
        case summary
        case groups
        case comparisons
        case items
        case readOnly = "read_only"
        case readonly
        case writesAllowed = "writes_allowed"
        case writeActionsAvailable = "write_actions_available"
        case fallbackReason = "fallback_reason"
        case unavailableReason = "unavailable_reason"
        case reason
        case totalCount = "total_count"
        case groupCount = "group_count"
        case comparisonCount = "comparison_count"
        case agentCount = "agent_count"
        case comparedAgentCount = "compared_agent_count"
        case selectedGroupCount = "selected_group_count"
    }

    init(
        summary: CrossAgentComparisonSummary,
        groups: [CrossAgentComparisonGroup],
        readOnly: Bool = true,
        fallbackReason: String? = nil
    ) {
        self.summary = summary
        self.groups = groups
        self.readOnly = readOnly
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let values = try? decoder.singleValueContainer(),
           let decodedGroups = try? values.decode([CrossAgentComparisonGroup].self) {
            groups = decodedGroups.sortedForDisplay()
            summary = CrossAgentComparisonSummary(groups: groups)
            readOnly = true
            fallbackReason = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = (try container.decodeIfPresent([CrossAgentComparisonGroup].self, forKey: .groups)
            ?? container.decodeIfPresent([CrossAgentComparisonGroup].self, forKey: .comparisons)
            ?? container.decodeIfPresent([CrossAgentComparisonGroup].self, forKey: .items)
            ?? [])
            .sortedForDisplay()
        summary = try container.decodeIfPresent(CrossAgentComparisonSummary.self, forKey: .summary)
            ?? CrossAgentComparisonSummary(
                totalCount: try container.decodeIfPresent(Int.self, forKey: .totalCount)
                    ?? container.decodeIfPresent(Int.self, forKey: .groupCount)
                    ?? container.decodeIfPresent(Int.self, forKey: .comparisonCount)
                    ?? groups.count,
                agentCount: try container.decodeIfPresent(Int.self, forKey: .agentCount)
                    ?? container.decodeIfPresent(Int.self, forKey: .comparedAgentCount)
                    ?? CrossAgentComparisonSummary(groups: groups).agentCount,
                selectedGroupCount: try container.decodeIfPresent(Int.self, forKey: .selectedGroupCount)
                    ?? groups.filter(\.referencesSelectedSkill).count,
                riskCount: groups.filter(\.hasRisk).count,
                writableMismatchCount: groups.filter(\.hasWritableMismatch).count,
                enabledMismatchCount: groups.filter(\.hasEnabledMismatch).count
            )
        let writesAllowed = try container.decodeIfPresent(Bool.self, forKey: .writesAllowed)
            ?? container.decodeIfPresent(Bool.self, forKey: .writeActionsAvailable)
            ?? false
        readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly)
            ?? container.decodeIfPresent(Bool.self, forKey: .readonly)
            ?? !writesAllowed
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .unavailableReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    func group(for skill: SkillRecord) -> CrossAgentComparisonGroup? {
        groups.first { group in
            group.members.contains { $0.instanceID == skill.id }
        } ?? groups.first { group in
            group.title.caseInsensitiveCompare(skill.name) == .orderedSame
        }
    }

    static func emptyFallback(reason: String? = nil) -> CrossAgentComparisonResult {
        CrossAgentComparisonResult(
            summary: .empty,
            groups: [],
            readOnly: true,
            fallbackReason: reason
        )
    }

    static func local(
        skills: [SkillRecord],
        findings: [RuleFindingRecord],
        capabilities: [AdapterCapabilityRecord],
        agentFilter: SkillAgentFilter,
        reason: String? = nil
    ) -> CrossAgentComparisonResult {
        let visibleSkills = skills.filter { skill in
            agentFilter == .all || skill.agent == agentFilter.rawValue
                || skills.contains { candidate in
                    candidate.id != skill.id
                        && candidate.normalizedComparisonName == skill.normalizedComparisonName
                        && candidate.agent == agentFilter.rawValue
                }
        }
        let findingsByInstance = Dictionary(grouping: findings.compactMap { finding -> (String, RuleFindingRecord)? in
            guard let instanceID = finding.instanceId else { return nil }
            return (instanceID, finding)
        }, by: \.0).mapValues { values in values.map { $0.1 } }
        let capabilityByAgent = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.agent, $0) })
        let grouped = Dictionary(grouping: visibleSkills, by: \.comparisonGroupKey)
        let groups = grouped.values.compactMap { members -> CrossAgentComparisonGroup? in
            let agents = Set(members.map(\.agent))
            guard members.count > 1, agents.count > 1 else { return nil }
            return CrossAgentComparisonGroup.local(
                skills: members,
                findingsByInstance: findingsByInstance,
                capabilityByAgent: capabilityByAgent
            )
        }.sortedForDisplay()
        return CrossAgentComparisonResult(
            summary: CrossAgentComparisonSummary(groups: groups),
            groups: groups,
            readOnly: true,
            fallbackReason: reason
        )
    }
}

struct CrossAgentComparisonSummary: Decodable, Hashable {
    let totalCount: Int
    let agentCount: Int
    let selectedGroupCount: Int
    let riskCount: Int
    let writableMismatchCount: Int
    let enabledMismatchCount: Int

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case groupCount = "group_count"
        case comparisonCount = "comparison_count"
        case agentCount = "agent_count"
        case comparedAgentCount = "compared_agent_count"
        case selectedGroupCount = "selected_group_count"
        case selectedCount = "selected_count"
        case riskCount = "risk_count"
        case riskyCount = "risky_count"
        case writableMismatchCount = "writable_mismatch_count"
        case capabilityMismatchCount = "capability_mismatch_count"
        case enabledMismatchCount = "enabled_mismatch_count"
        case stateMismatchCount = "state_mismatch_count"
    }

    static let empty = CrossAgentComparisonSummary(
        totalCount: 0,
        agentCount: 0,
        selectedGroupCount: 0,
        riskCount: 0,
        writableMismatchCount: 0,
        enabledMismatchCount: 0
    )

    init(
        totalCount: Int,
        agentCount: Int,
        selectedGroupCount: Int,
        riskCount: Int,
        writableMismatchCount: Int,
        enabledMismatchCount: Int
    ) {
        self.totalCount = totalCount
        self.agentCount = agentCount
        self.selectedGroupCount = selectedGroupCount
        self.riskCount = riskCount
        self.writableMismatchCount = writableMismatchCount
        self.enabledMismatchCount = enabledMismatchCount
    }

    init(groups: [CrossAgentComparisonGroup]) {
        self.init(
            totalCount: groups.count,
            agentCount: Set(groups.flatMap { $0.members.map(\.agent) }).count,
            selectedGroupCount: groups.filter(\.referencesSelectedSkill).count,
            riskCount: groups.filter(\.hasRisk).count,
            writableMismatchCount: groups.filter(\.hasWritableMismatch).count,
            enabledMismatchCount: groups.filter(\.hasEnabledMismatch).count
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
            ?? container.decodeIfPresent(Int.self, forKey: .groupCount)
            ?? container.decodeIfPresent(Int.self, forKey: .comparisonCount)
            ?? 0
        agentCount = try container.decodeIfPresent(Int.self, forKey: .agentCount)
            ?? container.decodeIfPresent(Int.self, forKey: .comparedAgentCount)
            ?? 0
        selectedGroupCount = try container.decodeIfPresent(Int.self, forKey: .selectedGroupCount)
            ?? container.decodeIfPresent(Int.self, forKey: .selectedCount)
            ?? 0
        riskCount = try container.decodeIfPresent(Int.self, forKey: .riskCount)
            ?? container.decodeIfPresent(Int.self, forKey: .riskyCount)
            ?? 0
        writableMismatchCount = try container.decodeIfPresent(Int.self, forKey: .writableMismatchCount)
            ?? container.decodeIfPresent(Int.self, forKey: .capabilityMismatchCount)
            ?? 0
        enabledMismatchCount = try container.decodeIfPresent(Int.self, forKey: .enabledMismatchCount)
            ?? container.decodeIfPresent(Int.self, forKey: .stateMismatchCount)
            ?? 0
    }
}

struct CrossAgentComparisonGroup: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let matchKind: String
    let riskLevel: String
    let members: [CrossAgentComparisonMember]
    let differences: [String]
    let selectedInstanceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case title
        case name
        case skillName = "skill_name"
        case canonicalName = "canonical_name"
        case matchKind = "match_kind"
        case reason
        case kind
        case type
        case riskLevel = "risk_level"
        case severity
        case priority
        case members
        case instances
        case skills
        case skillInstances = "skill_instances"
        case differences
        case diffSummary = "diff_summary"
        case summary
        case selectedInstanceIDs = "selected_instance_ids"
        case instanceIDs = "instance_ids"
    }

    var referencesSelectedSkill: Bool {
        !selectedInstanceIDs.isEmpty
    }

    var hasRisk: Bool {
        members.contains { $0.findingCount > 0 || $0.riskFindingCount > 0 }
            || ["critical", "high", "error", "warning"].contains(riskLevel.lowercased())
    }

    var hasWritableMismatch: Bool {
        Set(members.map(\.writableCapability)).count > 1
    }

    var hasEnabledMismatch: Bool {
        Set(members.map(\.enabled)).count > 1
    }

    init(
        id: String,
        title: String,
        matchKind: String,
        riskLevel: String,
        members: [CrossAgentComparisonMember],
        differences: [String],
        selectedInstanceIDs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.matchKind = matchKind
        self.riskLevel = riskLevel
        self.members = members
        self.differences = differences
        self.selectedInstanceIDs = selectedInstanceIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        members = try container.decodeIfPresent([CrossAgentComparisonMember].self, forKey: .members)
            ?? container.decodeIfPresent([CrossAgentComparisonMember].self, forKey: .instances)
            ?? container.decodeIfPresent([CrossAgentComparisonMember].self, forKey: .skills)
            ?? container.decodeIfPresent([CrossAgentComparisonMember].self, forKey: .skillInstances)
            ?? []
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .skillName)
            ?? container.decodeIfPresent(String.self, forKey: .canonicalName)
            ?? members.first?.name
            ?? UIStrings.crossAgentComparisonUntitled
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .groupID)
            ?? "comparison-\(title.normalizedComparisonToken)-\(members.map(\.instanceID).sorted().joined(separator: "-"))"
        matchKind = try container.decodeIfPresent(String.self, forKey: .matchKind)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? UIStrings.crossAgentComparisonMatchName
        riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel)
            ?? container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .priority)
            ?? "info"
        if let values = try container.decodeIfPresent([String].self, forKey: .differences) {
            differences = values
        } else if let value = try container.decodeIfPresent(String.self, forKey: .diffSummary)
            ?? container.decodeIfPresent(String.self, forKey: .summary) {
            differences = value.isEmpty ? [] : [value]
        } else {
            differences = []
        }
        selectedInstanceIDs = try container.decodeIfPresent([String].self, forKey: .selectedInstanceIDs)
            ?? container.decodeIfPresent([String].self, forKey: .instanceIDs)
            ?? []
    }

    static func local(
        skills: [SkillRecord],
        findingsByInstance: [String: [RuleFindingRecord]],
        capabilityByAgent: [String: AdapterCapabilityRecord]
    ) -> CrossAgentComparisonGroup {
        let sortedSkills = skills.sorted { lhs, rhs in
            if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
                return lhs.agent < rhs.agent
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        let members = sortedSkills.map { skill in
            CrossAgentComparisonMember.local(
                skill: skill,
                findings: findingsByInstance[skill.id] ?? [],
                capability: capabilityByAgent[skill.agent]
            )
        }
        let title = sortedSkills.first?.name.nonEmptyComparisonText
            ?? sortedSkills.first?.definitionId.nonEmptyComparisonText
            ?? UIStrings.crossAgentComparisonUntitled
        let group = CrossAgentComparisonGroup(
            id: "local-\(sortedSkills.first?.comparisonGroupKey ?? title.normalizedComparisonToken)",
            title: title,
            matchKind: sortedSkills.hasDefinitionMismatch ? UIStrings.crossAgentComparisonMatchSimilarName : UIStrings.crossAgentComparisonMatchName,
            riskLevel: members.contains { $0.findingCount > 0 } ? "warning" : "info",
            members: members,
            differences: localDifferences(for: members)
        )
        return group
    }

    private static func localDifferences(for members: [CrossAgentComparisonMember]) -> [String] {
        var values: [String] = []
        if Set(members.map(\.enabled)).count > 1 {
            values.append(UIStrings.crossAgentComparisonDifferenceEnabled)
        }
        if Set(members.map(\.writableCapability)).count > 1 {
            values.append(UIStrings.crossAgentComparisonDifferenceWritable)
        }
        if Set(members.map(\.sourceRoot)).count > 1 {
            values.append(UIStrings.crossAgentComparisonDifferenceSource)
        }
        if Set(members.map(\.findingCount)).count > 1 {
            values.append(UIStrings.crossAgentComparisonDifferenceFindings)
        }
        if Set(members.map(\.definitionID)).count > 1 {
            values.append(UIStrings.crossAgentComparisonDifferenceDefinition)
        }
        return values
    }
}

struct CrossAgentComparisonMember: Decodable, Identifiable, Hashable {
    let instanceID: String
    let name: String
    let agent: String
    let state: String
    let enabled: Bool
    let scope: String
    let sourceRoot: String
    let displayPath: String
    let definitionID: String
    let writableCapability: Bool
    let writableReason: String?
    let findingCount: Int
    let riskFindingCount: Int
    let differences: [String]

    var id: String { instanceID }

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case instanceId = "instanceId"
        case skillID = "skill_id"
        case id
        case name
        case skillName = "skill_name"
        case agent
        case state
        case status
        case enabled
        case scope
        case sourceScope = "source_scope"
        case sourceRoot = "source_root"
        case root
        case rootKind = "root_kind"
        case provenanceRoot = "provenance_root"
        case displayPath = "display_path"
        case path
        case source
        case sourcePath = "source_path"
        case definitionID = "definition_id"
        case definitionId = "definitionId"
        case writableCapability = "writable_capability"
        case writable
        case canWrite = "can_write"
        case writesAllowed = "writes_allowed"
        case configWritable = "config_writable"
        case capability
        case writableReason = "writable_reason"
        case blocker
        case reason
        case findingCount = "finding_count"
        case findings
        case riskFindingCount = "risk_finding_count"
        case riskyFindingCount = "risky_finding_count"
        case differences
        case diffSummary = "diff_summary"
    }

    init(
        instanceID: String,
        name: String,
        agent: String,
        state: String,
        enabled: Bool,
        scope: String,
        sourceRoot: String,
        displayPath: String,
        definitionID: String,
        writableCapability: Bool,
        writableReason: String?,
        findingCount: Int,
        riskFindingCount: Int,
        differences: [String]
    ) {
        self.instanceID = instanceID
        self.name = name
        self.agent = agent
        self.state = state
        self.enabled = enabled
        self.scope = scope
        self.sourceRoot = sourceRoot
        self.displayPath = displayPath
        self.definitionID = definitionID
        self.writableCapability = writableCapability
        self.writableReason = writableReason
        self.findingCount = findingCount
        self.riskFindingCount = riskFindingCount
        self.differences = differences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = try container.decodeIfPresent(String.self, forKey: .instanceID)
            ?? container.decodeIfPresent(String.self, forKey: .instanceId)
            ?? container.decodeIfPresent(String.self, forKey: .skillID)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .skillName)
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent) ?? UIStrings.unknown
        state = try container.decodeIfPresent(String.self, forKey: .state)
            ?? container.decodeIfPresent(String.self, forKey: .status)
            ?? UIStrings.stateUnknown
        enabled = try container.decodeFlexibleBool(
            keys: [.enabled],
            defaultValue: false
        )
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
            ?? container.decodeIfPresent(String.self, forKey: .sourceScope)
            ?? UIStrings.unknown
        sourceRoot = try container.decodeIfPresent(String.self, forKey: .sourceRoot)
            ?? container.decodeIfPresent(String.self, forKey: .root)
            ?? container.decodeIfPresent(String.self, forKey: .rootKind)
            ?? container.decodeIfPresent(String.self, forKey: .provenanceRoot)
            ?? UIStrings.unknown
        displayPath = try container.decodeIfPresent(String.self, forKey: .displayPath)
            ?? container.decodeIfPresent(String.self, forKey: .path)
            ?? container.decodeIfPresent(String.self, forKey: .source)
            ?? container.decodeIfPresent(String.self, forKey: .sourcePath)
            ?? ""
        definitionID = try container.decodeIfPresent(String.self, forKey: .definitionID)
            ?? container.decodeIfPresent(String.self, forKey: .definitionId)
            ?? ""
        writableCapability = try container.decodeFlexibleBool(
            keys: [.writableCapability, .writable, .canWrite, .writesAllowed, .configWritable, .capability],
            defaultValue: false
        )
        writableReason = try container.decodeIfPresent(String.self, forKey: .writableReason)
            ?? container.decodeIfPresent(String.self, forKey: .blocker)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
        findingCount = try container.decodeIfPresent(Int.self, forKey: .findingCount)
            ?? container.decodeIfPresent(Int.self, forKey: .findings)
            ?? 0
        riskFindingCount = try container.decodeIfPresent(Int.self, forKey: .riskFindingCount)
            ?? container.decodeIfPresent(Int.self, forKey: .riskyFindingCount)
            ?? 0
        if let values = try container.decodeIfPresent([String].self, forKey: .differences) {
            differences = values
        } else if let value = try container.decodeIfPresent(String.self, forKey: .diffSummary) {
            differences = value.isEmpty ? [] : [value]
        } else {
            differences = []
        }
    }

    static func local(
        skill: SkillRecord,
        findings: [RuleFindingRecord],
        capability: AdapterCapabilityRecord?
    ) -> CrossAgentComparisonMember {
        let writable = capability.map { $0.writable.supported && $0.configToggle.supported } ?? false
        let reason = capability.flatMap { capability in
            if !capability.writable.supported {
                return capability.writable.reason
            }
            if !capability.configToggle.supported {
                return capability.configToggle.reason
            }
            return nil
        }
        return CrossAgentComparisonMember(
            instanceID: skill.id,
            name: skill.name,
            agent: skill.agent,
            state: skill.state,
            enabled: skill.enabled,
            scope: skill.scope,
            sourceRoot: skill.provenance.label,
            displayPath: skill.displayPath,
            definitionID: skill.definitionId,
            writableCapability: writable,
            writableReason: reason,
            findingCount: findings.count,
            riskFindingCount: findings.filter { finding in
                ["error", "warning"].contains(finding.severity.lowercased())
            }.count,
            differences: []
        )
    }
}

private extension Array where Element == CrossAgentComparisonGroup {
    func sortedForDisplay() -> [CrossAgentComparisonGroup] {
        sorted { lhs, rhs in
            if lhs.hasRisk != rhs.hasRisk {
                return lhs.hasRisk && !rhs.hasRisk
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension Array where Element == SkillRecord {
    var hasDefinitionMismatch: Bool {
        Set(map { $0.definitionId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count > 1
    }
}

private extension SkillRecord {
    var comparisonGroupKey: String {
        let name = normalizedComparisonName
        if !name.isEmpty {
            return "name:\(name)"
        }
        let definition = definitionId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !definition.isEmpty {
            return "definition:\(definition)"
        }
        return "path:\(path.normalizedComparisonToken)"
    }

    var normalizedComparisonName: String {
        name.normalizedComparisonToken
    }
}

private extension String {
    var normalizedComparisonToken: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    var nonEmptyComparisonText: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBool(keys: [Key], defaultValue: Bool) throws -> Bool {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "yes", "supported", "enabled", "writable", "1"].contains(normalized) {
                    return true
                }
                if ["false", "no", "unsupported", "disabled", "read-only", "readonly", "0"].contains(normalized) {
                    return false
                }
            }
            if let value = try? decodeIfPresent(AdapterFeatureCapability.self, forKey: key) {
                return value.supported
            }
        }
        return defaultValue
    }
}
