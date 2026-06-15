import Foundation

enum ValidationWorkbenchBlockerCode: String, CaseIterable, Hashable, Identifiable {
    case lockedSession = "locked-session"
    case windowNotFound = "window-not-found"
    case noAXWindow = "no-ax-window"
    case computerUseTimeout = "computer-use-timeout"
    case remoteConnection = "remote-connection"
    case activationFailed = "activation-failed"
    case blackCapture = "black-capture"
    case flatCapture = "flat-capture"
    case transparentCapture = "transparent-capture"
    case invalidCapture = "invalid-capture"
    case screenRecordingPermission = "screen-recording-permission"
    case staleBundle = "stale-bundle"
    case toolLayerUnknown = "tool-layer-unknown"

    var id: String { rawValue }
}

enum ValidationWorkbenchSection: String, CaseIterable, Hashable, Identifiable {
    case sessionWindow = "session-window"
    case permissions
    case bundleFreshness = "bundle-freshness"
    case screenshotQuality = "screenshot-quality"
    case computerUseToolLayer = "computer-use-tool-layer"
    case evidenceStandards = "evidence-standards"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessionWindow:
            return "Session / Window"
        case .permissions:
            return "Permissions"
        case .bundleFreshness:
            return "Bundle freshness"
        case .screenshotQuality:
            return "Screenshot quality"
        case .computerUseToolLayer:
            return "Computer Use / tool layer"
        case .evidenceStandards:
            return "Evidence standards"
        }
    }

    var explanation: String {
        switch self {
        case .sessionWindow:
            return "Confirms the interactive macOS session, app activation, visible window, and AX window identity before accepting UI evidence."
        case .permissions:
            return "Confirms screenshot capture is authorized before app-window evidence is accepted."
        case .bundleFreshness:
            return "Confirms the launched app is the current workspace bundle and not an older same-bundle process."
        case .screenshotQuality:
            return "Rejects unreadable screenshots, including black, flat, transparent, or structurally invalid captures."
        case .computerUseToolLayer:
            return "Records Computer Use, remote connection, timeout, and unknown tool-layer failures as blockers."
        case .evidenceStandards:
            return "Keeps fixture smoke evidence separate from unlocked real-local Computer Use and app-window screenshot evidence."
        }
    }
}

enum ValidationWorkbenchSeverity: String, Hashable {
    case info
    case warning
    case blocker
}

enum ValidationWorkbenchStatus: String, Hashable {
    case blocked
    case required
    case supporting
}

struct ValidationWorkbenchSafety: Hashable {
    let providerCallsAllowed: Bool
    let writeActionsAllowed: Bool
    let scriptExecutionAllowed: Bool
    let credentialAccessAllowed: Bool
    let cloudSyncAllowed: Bool
    let telemetryAllowed: Bool
    let backgroundJobsAllowed: Bool
    let notes: [String]

    var allUnsafeCapabilitiesBlocked: Bool {
        !providerCallsAllowed
            && !writeActionsAllowed
            && !scriptExecutionAllowed
            && !credentialAccessAllowed
            && !cloudSyncAllowed
            && !telemetryAllowed
            && !backgroundJobsAllowed
    }

    init(
        providerCallsAllowed: Bool = false,
        writeActionsAllowed: Bool = false,
        scriptExecutionAllowed: Bool = false,
        credentialAccessAllowed: Bool = false,
        cloudSyncAllowed: Bool = false,
        telemetryAllowed: Bool = false,
        backgroundJobsAllowed: Bool = false,
        notes: [String] = [ValidationWorkbenchModel.readOnlySafetyNote]
    ) {
        self.providerCallsAllowed = providerCallsAllowed
        self.writeActionsAllowed = writeActionsAllowed
        self.scriptExecutionAllowed = scriptExecutionAllowed
        self.credentialAccessAllowed = credentialAccessAllowed
        self.cloudSyncAllowed = cloudSyncAllowed
        self.telemetryAllowed = telemetryAllowed
        self.backgroundJobsAllowed = backgroundJobsAllowed
        self.notes = notes
    }
}

struct ValidationWorkbenchRow: Hashable, Identifiable {
    let id: String
    let blockerCode: ValidationWorkbenchBlockerCode?
    let section: ValidationWorkbenchSection
    let severity: ValidationWorkbenchSeverity
    let status: ValidationWorkbenchStatus
    let title: String
    let explanation: String
    let nextAction: String
    let evidenceRequirement: String
    let safetyNote: String

    init(
        id: String? = nil,
        blockerCode: ValidationWorkbenchBlockerCode? = nil,
        section: ValidationWorkbenchSection,
        severity: ValidationWorkbenchSeverity,
        status: ValidationWorkbenchStatus,
        title: String,
        explanation: String,
        nextAction: String,
        evidenceRequirement: String,
        safetyNote: String = ValidationWorkbenchModel.readOnlySafetyNote
    ) {
        self.id = id ?? blockerCode?.rawValue ?? title
        self.blockerCode = blockerCode
        self.section = section
        self.severity = severity
        self.status = status
        self.title = title
        self.explanation = explanation
        self.nextAction = nextAction
        self.evidenceRequirement = evidenceRequirement
        self.safetyNote = safetyNote
    }
}

struct ValidationWorkbenchSectionModel: Hashable, Identifiable {
    var id: String { section.id }

    let section: ValidationWorkbenchSection
    let title: String
    let explanation: String
    let status: ValidationWorkbenchStatus
    let rows: [ValidationWorkbenchRow]

    var blockerCount: Int {
        rows.filter { $0.blockerCode != nil && $0.status == .blocked }.count
    }
}

struct ValidationWorkbenchSummary: Hashable {
    let status: ValidationWorkbenchStatus
    let sectionCount: Int
    let canonicalBlockerCount: Int
    let blockerCodes: [ValidationWorkbenchBlockerCode]
    let requiredEvidence: [String]
    let fixtureSmokeIsSubstitute: Bool
    let unlockedRealLocalComputerUseRequired: Bool
    let summaryText: String
    let safety: ValidationWorkbenchSafety
}

struct ValidationWorkbenchSnapshot: Hashable {
    let summary: ValidationWorkbenchSummary
    let sections: [ValidationWorkbenchSectionModel]

    var rows: [ValidationWorkbenchRow] {
        sections.flatMap(\.rows)
    }

    func row(for code: ValidationWorkbenchBlockerCode) -> ValidationWorkbenchRow? {
        rows.first { $0.blockerCode == code }
    }
}

enum ValidationWorkbenchModel {
    static let readOnlySafetyNote = "Read-only guidance only; it does not call providers, write files, execute scripts, read credentials, sync cloud data, emit telemetry, or start background jobs."

    static let requiredRealLocalEvidence = "Unlocked real-local Computer Use against the current app bundle plus an app-window screenshot that is nonblack, nonflat, nontransparent, and visually inspected."

    static let fixtureSmokeLimitation = "Fixture smoke may prove build/service health, but it cannot replace blocked real-local Computer Use or app-window screenshot evidence."

    static var canonicalSnapshot: ValidationWorkbenchSnapshot {
        let rows = canonicalRows + evidenceStandardRows
        let sections = ValidationWorkbenchSection.allCases.map { section in
            let sectionRows = rows.filter { $0.section == section }
            return ValidationWorkbenchSectionModel(
                section: section,
                title: section.title,
                explanation: section.explanation,
                status: sectionRows.contains { $0.status == .blocked } ? .blocked : .required,
                rows: sectionRows
            )
        }

        let blockerCodes = canonicalRows.compactMap(\.blockerCode)
        let summary = ValidationWorkbenchSummary(
            status: .required,
            sectionCount: sections.count,
            canonicalBlockerCount: blockerCodes.count,
            blockerCodes: blockerCodes,
            requiredEvidence: [requiredRealLocalEvidence],
            fixtureSmokeIsSubstitute: false,
            unlockedRealLocalComputerUseRequired: true,
            summaryText: "Real-local validation remains pending until unlocked Computer Use can target the current app window and produce acceptable app-window screenshot evidence. Fixture smoke is supporting evidence only.",
            safety: ValidationWorkbenchSafety()
        )
        return ValidationWorkbenchSnapshot(summary: summary, sections: sections)
    }

    static var canonicalRows: [ValidationWorkbenchRow] {
        ValidationWorkbenchBlockerCode.allCases.map(row)
    }

    static var evidenceStandardRows: [ValidationWorkbenchRow] {
        [
            ValidationWorkbenchRow(
                id: "real-local-computer-use-required",
                section: .evidenceStandards,
                severity: .blocker,
                status: .required,
                title: "Unlocked real-local Computer Use is required",
                explanation: fixtureSmokeLimitation,
                nextAction: "Run the real app in an unlocked interactive macOS session, target the current bundle/window, exercise the relevant UI, and capture app-window evidence.",
                evidenceRequirement: requiredRealLocalEvidence
            )
        ]
    }

    static func row(for code: ValidationWorkbenchBlockerCode) -> ValidationWorkbenchRow {
        switch code {
        case .lockedSession:
            return blockerRow(
                code,
                section: .sessionWindow,
                title: "macOS session is locked",
                explanation: "Window capture and Computer Use evidence are invalid while the interactive session is locked.",
                nextAction: "Unlock the macOS session and rerun Computer Use and app-window capture.",
                evidenceRequirement: "Record locked-session while blocked; completion still requires unlocked real-local Computer Use evidence."
            )
        case .windowNotFound:
            return blockerRow(
                code,
                section: .sessionWindow,
                title: "Target app window was not found",
                explanation: "CG window lookup could not find one visible SkillsCopilot window for the expected bundle path and PID, or multiple same-bundle windows made targeting ambiguous.",
                nextAction: "Relaunch the exact workspace bundle, close duplicate same-bundle windows, and retry exact PID/window targeting.",
                evidenceRequirement: "A resolved current-bundle PID, visible main window, and app-window screenshot are required."
            )
        case .noAXWindow:
            return blockerRow(
                code,
                section: .sessionWindow,
                title: "Accessibility window was not resolved",
                explanation: "The app may have a CG window, but AX did not expose a usable app window for interaction.",
                nextAction: "Confirm Accessibility permission, activate the exact app process, and retry AX/Computer Use window discovery.",
                evidenceRequirement: "A matching AX window for the targeted app process is required before UI interaction evidence is accepted."
            )
        case .computerUseTimeout:
            return blockerRow(
                code,
                section: .computerUseToolLayer,
                title: "Computer Use timed out",
                explanation: "Computer Use did not return usable app state or interaction evidence before its timeout.",
                nextAction: "Retry after confirming the session is unlocked, the app is active, and the target window is visible.",
                evidenceRequirement: "A completed Computer Use interaction against the real local app is required; timeout is only a blocker record."
            )
        case .remoteConnection:
            return blockerRow(
                code,
                section: .computerUseToolLayer,
                title: "Remote connection blocked UI automation",
                explanation: "Computer Use reported a remote connection condition that prevents trusted local app-window evidence.",
                nextAction: "Switch to a local interactive macOS session and rerun validation.",
                evidenceRequirement: "Validation evidence must come from the local app window, not a blocked remote-control state."
            )
        case .activationFailed:
            return blockerRow(
                code,
                section: .sessionWindow,
                title: "App activation failed",
                explanation: "The target process could not be activated before UI inspection or interaction.",
                nextAction: "Relaunch the exact app bundle, ensure it is foregroundable, and retry activation/window targeting.",
                evidenceRequirement: "The active app process must match the current bundle before interaction evidence is accepted."
            )
        case .blackCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: "Screenshot is black",
                explanation: "A black or near-black image cannot prove visible UI state.",
                nextAction: "Fix session, permission, or capture targeting issues and retake the app-window screenshot.",
                evidenceRequirement: "Accepted screenshots must show readable app UI and pass black-image rejection."
            )
        case .flatCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: "Screenshot has near-zero visual variance",
                explanation: "A flat or near-single-color capture cannot prove UI layout or interaction state.",
                nextAction: "Retake the app-window screenshot after confirming the window is visible and capture targets the app content.",
                evidenceRequirement: "Accepted screenshots must be nonflat and visually inspectable."
            )
        case .transparentCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: "Screenshot is mostly transparent",
                explanation: "A transparent capture is not usable app-window evidence.",
                nextAction: "Retry capture with a visible app window and valid Screen Recording permissions.",
                evidenceRequirement: "Accepted screenshots must contain opaque app UI content."
            )
        case .invalidCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: "Screenshot artifact is invalid",
                explanation: "The screenshot file is missing, too small, structurally invalid, or otherwise unreadable.",
                nextAction: "Regenerate the screenshot artifact and verify it before using it as evidence.",
                evidenceRequirement: "Accepted screenshot artifacts must be valid images with app-window dimensions."
            )
        case .screenRecordingPermission:
            return blockerRow(
                code,
                section: .permissions,
                title: "Screen Recording permission is missing",
                explanation: "macOS did not authorize the capture helper to create app-window image evidence.",
                nextAction: "Grant Screen Recording permission to the relevant terminal/runtime app, restart it if needed, and rerun capture.",
                evidenceRequirement: "A permission-valid capture that shows the app window is required."
            )
        case .staleBundle:
            return blockerRow(
                code,
                section: .bundleFreshness,
                title: "Running app bundle is stale",
                explanation: "The visible app is not the freshly built workspace bundle or is older than the source inputs.",
                nextAction: "Rebuild, stop stale same-bundle processes, launch the exact dist/SkillsCopilot.app path, and retry validation.",
                evidenceRequirement: "Evidence must identify the current workspace bundle path and matching process/window."
            )
        case .toolLayerUnknown:
            return blockerRow(
                code,
                section: .computerUseToolLayer,
                title: "Unknown tool-layer failure",
                explanation: "The validation tool returned an unclassified failure, so the app cannot treat the run as successful.",
                nextAction: "Capture the raw failure text, classify it if possible, and rerun with a known blocker or successful evidence path.",
                evidenceRequirement: "Unknown tool-layer failures must be recorded as blockers until a concrete successful real-local run is available."
            )
        }
    }

    private static func blockerRow(
        _ code: ValidationWorkbenchBlockerCode,
        section: ValidationWorkbenchSection,
        title: String,
        explanation: String,
        nextAction: String,
        evidenceRequirement: String
    ) -> ValidationWorkbenchRow {
        ValidationWorkbenchRow(
            blockerCode: code,
            section: section,
            severity: .blocker,
            status: .blocked,
            title: title,
            explanation: explanation,
            nextAction: nextAction,
            evidenceRequirement: evidenceRequirement
        )
    }
}
