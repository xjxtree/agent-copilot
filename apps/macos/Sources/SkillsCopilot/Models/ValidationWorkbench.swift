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
            return UIStrings.validationWorkbenchSectionSessionWindowTitle
        case .permissions:
            return UIStrings.validationWorkbenchSectionPermissionsTitle
        case .bundleFreshness:
            return UIStrings.validationWorkbenchSectionBundleFreshnessTitle
        case .screenshotQuality:
            return UIStrings.validationWorkbenchSectionScreenshotQualityTitle
        case .computerUseToolLayer:
            return UIStrings.validationWorkbenchSectionComputerUseToolLayerTitle
        case .evidenceStandards:
            return UIStrings.validationWorkbenchSectionEvidenceStandardsTitle
        }
    }

    var explanation: String {
        switch self {
        case .sessionWindow:
            return UIStrings.validationWorkbenchSectionSessionWindowExplanation
        case .permissions:
            return UIStrings.validationWorkbenchSectionPermissionsExplanation
        case .bundleFreshness:
            return UIStrings.validationWorkbenchSectionBundleFreshnessExplanation
        case .screenshotQuality:
            return UIStrings.validationWorkbenchSectionScreenshotQualityExplanation
        case .computerUseToolLayer:
            return UIStrings.validationWorkbenchSectionComputerUseToolLayerExplanation
        case .evidenceStandards:
            return UIStrings.validationWorkbenchSectionEvidenceStandardsExplanation
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
    static var readOnlySafetyNote: String { UIStrings.validationWorkbenchReadOnlySafetyNote }

    static var requiredRealLocalEvidence: String { UIStrings.validationWorkbenchRequiredRealLocalEvidence }

    static var fixtureSmokeLimitation: String { UIStrings.validationWorkbenchFixtureSmokeLimitation }

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
            summaryText: UIStrings.validationWorkbenchSummaryText,
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
                title: UIStrings.validationWorkbenchEvidenceRequiredTitle,
                explanation: fixtureSmokeLimitation,
                nextAction: UIStrings.validationWorkbenchEvidenceRequiredAction,
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
                title: UIStrings.validationWorkbenchLockedSessionTitle,
                explanation: UIStrings.validationWorkbenchLockedSessionSummary,
                nextAction: UIStrings.validationWorkbenchLockedSessionAction,
                evidenceRequirement: UIStrings.validationWorkbenchLockedSessionEvidence
            )
        case .windowNotFound:
            return blockerRow(
                code,
                section: .sessionWindow,
                title: UIStrings.validationWorkbenchWindowNotFoundTitle,
                explanation: UIStrings.validationWorkbenchWindowNotFoundSummary,
                nextAction: UIStrings.validationWorkbenchWindowNotFoundAction,
                evidenceRequirement: UIStrings.validationWorkbenchWindowNotFoundEvidence
            )
        case .noAXWindow:
            return blockerRow(
                code,
                section: .sessionWindow,
                title: UIStrings.validationWorkbenchNoAXWindowTitle,
                explanation: UIStrings.validationWorkbenchNoAXWindowSummary,
                nextAction: UIStrings.validationWorkbenchNoAXWindowAction,
                evidenceRequirement: UIStrings.validationWorkbenchNoAXWindowEvidence
            )
        case .computerUseTimeout:
            return blockerRow(
                code,
                section: .computerUseToolLayer,
                title: UIStrings.validationWorkbenchComputerUseTimeoutTitle,
                explanation: UIStrings.validationWorkbenchComputerUseTimeoutSummary,
                nextAction: UIStrings.validationWorkbenchComputerUseTimeoutAction,
                evidenceRequirement: UIStrings.validationWorkbenchComputerUseTimeoutEvidence
            )
        case .remoteConnection:
            return blockerRow(
                code,
                section: .computerUseToolLayer,
                title: UIStrings.validationWorkbenchRemoteConnectionTitle,
                explanation: UIStrings.validationWorkbenchRemoteConnectionSummary,
                nextAction: UIStrings.validationWorkbenchRemoteConnectionAction,
                evidenceRequirement: UIStrings.validationWorkbenchRemoteConnectionEvidence
            )
        case .activationFailed:
            return blockerRow(
                code,
                section: .sessionWindow,
                title: UIStrings.validationWorkbenchActivationFailedTitle,
                explanation: UIStrings.validationWorkbenchActivationFailedSummary,
                nextAction: UIStrings.validationWorkbenchActivationFailedAction,
                evidenceRequirement: UIStrings.validationWorkbenchActivationFailedEvidence
            )
        case .blackCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: UIStrings.validationWorkbenchBlackCaptureTitle,
                explanation: UIStrings.validationWorkbenchBlackCaptureSummary,
                nextAction: UIStrings.validationWorkbenchBlackCaptureAction,
                evidenceRequirement: UIStrings.validationWorkbenchBlackCaptureEvidence
            )
        case .flatCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: UIStrings.validationWorkbenchFlatCaptureTitle,
                explanation: UIStrings.validationWorkbenchFlatCaptureSummary,
                nextAction: UIStrings.validationWorkbenchFlatCaptureAction,
                evidenceRequirement: UIStrings.validationWorkbenchFlatCaptureEvidence
            )
        case .transparentCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: UIStrings.validationWorkbenchTransparentCaptureTitle,
                explanation: UIStrings.validationWorkbenchTransparentCaptureSummary,
                nextAction: UIStrings.validationWorkbenchTransparentCaptureAction,
                evidenceRequirement: UIStrings.validationWorkbenchTransparentCaptureEvidence
            )
        case .invalidCapture:
            return blockerRow(
                code,
                section: .screenshotQuality,
                title: UIStrings.validationWorkbenchInvalidCaptureTitle,
                explanation: UIStrings.validationWorkbenchInvalidCaptureSummary,
                nextAction: UIStrings.validationWorkbenchInvalidCaptureAction,
                evidenceRequirement: UIStrings.validationWorkbenchInvalidCaptureEvidence
            )
        case .screenRecordingPermission:
            return blockerRow(
                code,
                section: .permissions,
                title: UIStrings.validationWorkbenchScreenRecordingTitle,
                explanation: UIStrings.validationWorkbenchScreenRecordingSummary,
                nextAction: UIStrings.validationWorkbenchScreenRecordingAction,
                evidenceRequirement: UIStrings.validationWorkbenchScreenRecordingEvidence
            )
        case .staleBundle:
            return blockerRow(
                code,
                section: .bundleFreshness,
                title: UIStrings.validationWorkbenchStaleBundleTitle,
                explanation: UIStrings.validationWorkbenchStaleBundleSummary,
                nextAction: UIStrings.validationWorkbenchStaleBundleAction,
                evidenceRequirement: UIStrings.validationWorkbenchStaleBundleEvidence
            )
        case .toolLayerUnknown:
            return blockerRow(
                code,
                section: .computerUseToolLayer,
                title: UIStrings.validationWorkbenchToolLayerUnknownTitle,
                explanation: UIStrings.validationWorkbenchToolLayerUnknownSummary,
                nextAction: UIStrings.validationWorkbenchToolLayerUnknownAction,
                evidenceRequirement: UIStrings.validationWorkbenchToolLayerUnknownEvidence
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
