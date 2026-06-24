import Foundation

struct AgentConfigTimelineModel: Hashable {
    static let visibleLimit = 5

    let agentTitle: String
    let isSpecificAgent: Bool
    let items: [AgentConfigTimelineItem]
    let hiddenCount: Int

    var summaryText: String {
        guard isSpecificAgent else {
            return UIStrings.agentConfigTimelineSelectAgent
        }
        if items.isEmpty {
            return UIStrings.agentConfigTimelineEmptySummary(agentTitle)
        }
        return UIStrings.agentConfigTimelineSummary(agentTitle, items.count + hiddenCount)
    }

    static func make(
        snapshots: [ConfigSnapshotRecord],
        agentFilter: SkillAgentFilter,
        limit: Int = visibleLimit
    ) -> AgentConfigTimelineModel {
        guard agentFilter != .all else {
            return AgentConfigTimelineModel(
                agentTitle: agentFilter.title,
                isSpecificAgent: false,
                items: [],
                hiddenCount: 0
            )
        }

        let filtered = snapshots
            .filter { $0.agent == agentFilter.rawValue }
            .sorted { $0.createdAt > $1.createdAt }
        let safeLimit = max(0, limit)
        let visible = Array(filtered.prefix(safeLimit))
        return AgentConfigTimelineModel(
            agentTitle: agentFilter.title,
            isSpecificAgent: true,
            items: visible.map(AgentConfigTimelineItem.init(snapshot:)),
            hiddenCount: max(0, filtered.count - visible.count)
        )
    }
}

struct AgentConfigTimelineItem: Identifiable, Hashable {
    let snapshot: ConfigSnapshotRecord
    let timeText: String
    let actionText: String
    let targetSummary: String
    let scopeText: String
    let statusText: String
    let capturedText: String

    var id: String { snapshot.id }

    init(snapshot: ConfigSnapshotRecord) {
        self.snapshot = snapshot
        timeText = DisplayText.timestamp(snapshot.createdAt)
        let trimmedReason = snapshot.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        actionText = trimmedReason.isEmpty ? UIStrings.agentConfigTimelineDefaultAction : trimmedReason
        targetSummary = Self.pathSummary(snapshot.target)
        scopeText = DisplayText.scope(snapshot.scope)
        statusText = UIStrings.agentConfigTimelineStatus
        capturedText = UIStrings.charactersCaptured(snapshot.content.count)
    }

    private static func pathSummary(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UIStrings.unknown }

        return DisplayText.configPathSummary(trimmed)
    }
}
