import Foundation
import SwiftUI

enum SkillStatusKind: Int {
    case broken
    case missing
    case disabled
    case enabled
    case shadowed
    case unknown
}

enum DisplayText {
    private static let snapshotDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func scope(_ value: String) -> String {
        switch value {
        case "agent-global":
            return UIStrings.text("scope.agentGlobal", "Agent Global")
        case "agent-project":
            return UIStrings.text("scope.project", "Project")
        case "tool-global":
            return UIStrings.text("scope.toolGlobal", "Tool Global")
        default:
            return value
        }
    }

    static func agent(_ value: String) -> String {
        switch value {
        case "claude-code":
            return UIStrings.claudeCode
        case "codex":
            return UIStrings.codex
        case "opencode":
            return UIStrings.opencode
        default:
            return value
        }
    }

    static func state(_ value: String, enabled: Bool) -> String {
        switch statusKind(value, enabled: enabled) {
        case .enabled:
            return UIStrings.stateEnabled
        case .disabled:
            return UIStrings.stateDisabled
        case .broken:
            return UIStrings.stateBroken
        case .missing:
            return UIStrings.stateMissing
        case .shadowed:
            return UIStrings.stateShadowed
        case .unknown:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return UIStrings.stateUnknown
            }
            return UIStrings.stateUnknownValue(trimmed)
        }
    }

    static func statusKind(_ value: String, enabled: Bool) -> SkillStatusKind {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "broken":
            return .broken
        case "missing":
            return .missing
        case "disabled":
            return .disabled
        case "loaded":
            return enabled ? .enabled : .disabled
        case "shadowed":
            return .shadowed
        default:
            return .unknown
        }
    }

    static func stateSortRank(_ value: String, enabled: Bool) -> Int {
        statusKind(value, enabled: enabled).rawValue
    }

    static func stateSystemImage(_ value: String, enabled: Bool) -> String {
        switch statusKind(value, enabled: enabled) {
        case .enabled:
            return "checkmark.circle.fill"
        case .disabled:
            return "pause.circle"
        case .broken:
            return "exclamationmark.triangle.fill"
        case .missing:
            return "questionmark.folder.fill"
        case .shadowed:
            return "rectangle.stack.badge.minus"
        case .unknown:
            return "questionmark.circle"
        }
    }

    static func stateColor(_ value: String, enabled: Bool) -> Color {
        switch statusKind(value, enabled: enabled) {
        case .enabled:
            return .green
        case .disabled:
            return .secondary
        case .broken:
            return .red
        case .missing:
            return .orange
        case .shadowed:
            return .purple
        case .unknown:
            return .secondary
        }
    }

    static func toggleDisabledReason(for skill: SkillRecord, isWriting: Bool) -> String? {
        if isWriting {
            return UIStrings.toggleUnavailableBusy
        }

        switch statusKind(skill.state, enabled: skill.enabled) {
        case .enabled, .disabled:
            break
        case .broken:
            return UIStrings.toggleUnavailableBroken
        case .missing:
            return UIStrings.toggleUnavailableMissing
        case .shadowed:
            return UIStrings.toggleUnavailableShadowed
        case .unknown:
            return UIStrings.toggleUnavailableUnknown
        }

        if isToolGlobal(skill) {
            return UIStrings.toggleUnavailableToolGlobal
        }

        if isReadOnlyAdapter(skill.agent) {
            return UIStrings.toggleUnavailableReadOnlyAdapter(agent(skill.agent))
        }

        return nil
    }

    static func isReadOnlyAdapter(_ agent: String) -> Bool {
        agent != "claude-code" && agent != "codex"
    }

    static func isToolGlobal(_ skill: SkillRecord) -> Bool {
        skill.scope == "tool-global"
    }

    static func isReadOnlyPreview(_ skill: SkillRecord) -> Bool {
        isToolGlobal(skill) || isReadOnlyAdapter(skill.agent)
    }

    static func timestamp(_ milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
        return snapshotDateFormatter.string(from: date)
    }
}
