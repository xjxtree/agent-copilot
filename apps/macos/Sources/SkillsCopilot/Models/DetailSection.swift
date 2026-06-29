enum DetailSection: String, CaseIterable, Identifiable {
    case agentWorkspace
    case lineup
    case agentProfile
    case taskCockpit
    case skillManager
    case overview
    case cleanup
    case guidedCleanup
    case observability
    case findings
    case conflicts
    case history
    case analysis
    case metadata

    var id: String { rawValue }

    static var visibleCases: [DetailSection] {
        [.overview, .findings, .conflicts, .history, .analysis, .metadata]
    }

    static var primaryWorkCases: [DetailSection] {
        []
    }

    var requiresSelectedSkill: Bool {
        switch self {
        case .overview, .findings, .conflicts, .history, .metadata:
            return true
        case .agentWorkspace, .lineup, .agentProfile, .taskCockpit, .skillManager, .cleanup, .guidedCleanup, .observability, .analysis:
            return false
        }
    }

    var title: String {
        switch self {
        case .agentWorkspace:
            return UIStrings.text("detail.agentWorkspace", "Agent Workspace")
        case .lineup:
            return UIStrings.text("detail.lineup", "Lineup")
        case .agentProfile:
            return UIStrings.text("detail.agentProfile", "Agent Profile")
        case .taskCockpit:
            return UIStrings.taskCockpitTitle
        case .skillManager:
            return UIStrings.text("skillManager.title", "Skill Package Manager")
        case .overview:
            return UIStrings.overview
        case .cleanup:
            return UIStrings.cleanupQueue
        case .guidedCleanup:
            return UIStrings.guidedCleanupFlowTitle
        case .observability:
            return UIStrings.providerObservabilityTitle
        case .findings:
            return UIStrings.findings
        case .conflicts:
            return UIStrings.conflicts
        case .history:
            return UIStrings.text("detail.history", "History")
        case .analysis:
            return UIStrings.text("detail.analysisReview", "Smart Analysis")
        case .metadata:
            return UIStrings.text("detail.metadata", "Metadata")
        }
    }

    var systemImage: String {
        switch self {
        case .agentWorkspace:
            return "person.crop.square"
        case .lineup:
            return "rectangle.3.group"
        case .agentProfile:
            return "person.crop.rectangle.stack"
        case .taskCockpit:
            return "checklist"
        case .skillManager:
            return "shippingbox.and.arrow.backward"
        case .overview:
            return "chart.pie"
        case .cleanup:
            return "tray.full"
        case .guidedCleanup:
            return "sparkles.square.filled.on.square"
        case .observability:
            return "waveform.path.ecg.rectangle"
        case .findings:
            return "exclamationmark.triangle"
        case .conflicts:
            return "exclamationmark.triangle"
        case .history:
            return "clock.arrow.circlepath"
        case .analysis:
            return "sparkles"
        case .metadata:
            return "info.circle"
        }
    }

    var summary: String {
        switch self {
        case .agentWorkspace:
            return UIStrings.text("detail.section.agentWorkspace.summary", "Review the selected agent profile and task preflight from one workspace entry.")
        case .lineup:
            return UIStrings.text("detail.section.lineup.summary", "Review the whole agent lineup by readiness, risks, cleanup pressure, provider context, and evidence-backed next navigation.")
        case .agentProfile:
            return UIStrings.text("detail.section.agentProfile.summary", "Inspect one agent's capability, health, scan state, and related read-only work surfaces.")
        case .taskCockpit:
            return UIStrings.text("detail.section.taskCockpit.summary", "Check whether the current task can proceed, which agent/skill should handle it, why, and what must be fixed first.")
        case .skillManager:
            return UIStrings.text("detail.section.skillManager.summary", "Search, install, update, remove, and manage local skills through supported manager tools.")
        case .overview:
            return UIStrings.text("detail.section.overview.summary", "Inspect the selected skill metadata, permissions, provenance, and raw catalog details.")
        case .cleanup:
            return UIStrings.text("detail.section.cleanup.summary", "Cleanup Queue has been retired from the skill detail switcher; issue review now starts from Issues.")
        case .guidedCleanup:
            return UIStrings.text("detail.section.guidedCleanup.summary", "Plan guided cleanup steps and record app-local redacted step metadata without applying fixes or changing agent config.")
        case .observability:
            return UIStrings.text("detail.section.observability.summary", "Inspect redacted app-local provider call and prompt-run metadata without sending provider requests.")
        case .findings:
            return UIStrings.text("detail.section.findings.summary", "Explain selected-skill issues with rules, suggestions, and evidence.")
        case .conflicts:
            return UIStrings.text("detail.section.conflicts.summary", "Review same-agent conflicts that currently reference the selected skill.")
        case .history:
            return UIStrings.text("detail.section.history.summary", "Review selected-skill toggle and config history.")
        case .analysis:
            return UIStrings.text("detail.section.analysis.summary", "Use focused smart analysis panels for quality scoring, task fit, and routing.")
        case .metadata:
            return UIStrings.text("detail.section.metadata.summary", "Inspect raw catalog metadata, frontmatter, body excerpts, and adapter capability details.")
        }
    }

    var isAgentWorkspaceSurface: Bool {
        switch self {
        case .agentWorkspace, .lineup, .agentProfile, .taskCockpit:
            return true
        case .skillManager, .overview, .cleanup, .guidedCleanup, .observability, .findings, .conflicts, .history, .analysis, .metadata:
            return false
        }
    }
}
