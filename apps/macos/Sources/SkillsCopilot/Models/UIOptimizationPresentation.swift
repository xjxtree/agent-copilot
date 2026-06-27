import Foundation

enum UIOptimizationPresentation {
    static let sidebarSelection = SidebarSelectionPresentation()
    static let sessionList = SidebarSecondaryListPresentation()
    static let configList = SidebarSecondaryListPresentation()
    static let skillList = SkillListPresentation()
    static let detailHeader = DetailHeaderPresentation()
    static let detailFeedback = DetailFeedbackPresentation()
    static let settings = SettingsPresentation()
    static let taskPreflight = TaskPreflightPresentation()
    static let skillManager = SkillManagerPresentation()
}

struct SidebarSelectionPresentation: Equatable {
    let usesSaturatedAccentBackground = false
    let usesWhiteSelectedText = false
    let accentLineWidth = 3
    let rowCornerRadius = 7
}

struct SidebarSecondaryListPresentation: Equatable {
    let minimumSearchWidth = 220
    let compactRowMinHeight = 40
    let compactRowMaxHeight = 44
    let usesSingleLineFilterToolbar = true
    let refreshUsesIconOnly = true
}

struct SkillListPresentation: Equatable {
    let minimumPrimaryColumnWidth = 220
    let idealPrimaryColumnWidth = 260
    let maximumPrimaryColumnWidth = 320
    let minimumSecondaryColumnWidth = 360
    let idealSecondaryColumnWidth = 400
    let maximumSecondaryColumnWidth = 520
    let minimumSearchWidth = 220
    let compactRowMinHeight = 36
    let compactRowMaxHeight = 40
    let usesSingleLineFilterToolbar = true

    func emptyFilteredMessage(
        agentFilter: SkillAgentFilter,
        hasActiveProjectContext: Bool,
        hasActiveSearchOrFilter: Bool
    ) -> String {
        if hasActiveSearchOrFilter {
            if agentFilter == .codex {
                return UIStrings.noCodexSkillsMessage
            }
            if agentFilter == .openclaw {
                return UIStrings.noOpenClawWorkspaceSkillsMessage
            }
            return UIStrings.noSkillsMatchSearch
        }

        if agentFilter == .codex, !hasActiveProjectContext {
            return UIStrings.noCodexProjectMessage
        }
        if agentFilter == .openclaw {
            return UIStrings.noOpenClawWorkspaceSkillsMessage
        }
        if agentFilter == .all {
            return hasActiveProjectContext ? UIStrings.noSkillsInCatalog : UIStrings.noProjectSkillsMessage
        }
        return UIStrings.noAgentSkillsMessage(agentFilter.title)
    }
}

struct DetailHeaderPresentation: Equatable {
    let height = 48
    let definitionUsesMonospacedFont = true
    let primaryToggleLivesInMenu = true
    let metadataLabelWidth = 82
    let metadataRowHeight = 30
}

struct DetailFeedbackPresentation: Equatable {
    let usesOverlayToast = true
    let maximumWidth = 420
    let cornerRadius = 8
}

struct SettingsPresentation: Equatable {
    let minimumWidth = 760
    let idealWidth = 860
    let minimumHeight = 620
    let idealHeight = 680
    let usesUnifiedSectionHeaders = true
    let sectionCornerRadius = 8
}

struct TaskPreflightPresentation: Equatable {
    let sheetMinimumWidth = 950
    let sheetIdealWidth = 1_020
    let sheetMinimumHeight = 620
    let historyColumnWidth = 270
    let fixedAgentChipWidth = 96
    let showsProviderUnavailableGate = true
}

struct SkillManagerPresentation: Equatable {
    let sheetMinimumWidth = 900
    let sheetIdealWidth = 980
    let sheetMinimumHeight = 680
    let sheetIdealHeight = 760
    let usesSegmentedWorkflows = true
    let targetsSummaryIsPinned = true
    let toolUnavailableDisablesExternalMutations = true
    let usesSurfaceLocalFeedback = true
}

struct CompactMetadataRow: Identifiable, Hashable {
    let label: String
    let value: String
    var systemImage: String? = nil
    var isCopyable = false

    var id: String {
        "\(label)-\(value)-\(systemImage ?? "")-\(isCopyable)"
    }
}
