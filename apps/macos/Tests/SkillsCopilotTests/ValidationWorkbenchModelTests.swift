import Foundation
@testable import SkillsCopilot

struct ValidationWorkbenchModelTests {
    func run() throws {
        try coversCanonicalV272BlockerCodes()
        try groupsRowsIntoWorkbenchSections()
        try keepsSafetyNotesAndFlagsReadOnly()
        try requiresUnlockedRealLocalComputerUseEvidence()
    }

    private func coversCanonicalV272BlockerCodes() throws {
        let expectedCodes = [
            "locked-session",
            "window-not-found",
            "no-ax-window",
            "computer-use-timeout",
            "remote-connection",
            "activation-failed",
            "black-capture",
            "flat-capture",
            "transparent-capture",
            "invalid-capture",
            "screen-recording-permission",
            "stale-bundle",
            "tool-layer-unknown"
        ]

        let enumCodes = ValidationWorkbenchBlockerCode.allCases.map(\.rawValue)
        let rowCodes = ValidationWorkbenchModel.canonicalRows.compactMap(\.blockerCode).map(\.rawValue)
        let summaryCodes = ValidationWorkbenchModel.canonicalSnapshot.summary.blockerCodes.map(\.rawValue)

        try expectEqual(enumCodes, expectedCodes, "Validation workbench should mirror the V2.72 canonical blocker code order.")
        try expectEqual(rowCodes, expectedCodes, "Validation workbench rows should cover every canonical blocker exactly once.")
        try expectEqual(summaryCodes, expectedCodes, "Validation workbench summary should expose every canonical blocker code.")
        try expectEqual(ValidationWorkbenchModel.canonicalSnapshot.summary.canonicalBlockerCount, expectedCodes.count, "Summary blocker count should match canonical code coverage.")
    }

    private func groupsRowsIntoWorkbenchSections() throws {
        let snapshot = ValidationWorkbenchModel.canonicalSnapshot
        let sectionIDs = snapshot.sections.map { $0.section.rawValue }

        try expectEqual(sectionIDs, ValidationWorkbenchSection.allCases.map(\.rawValue), "Workbench sections should keep deterministic ordering.")
        try expectEqual(snapshot.summary.sectionCount, ValidationWorkbenchSection.allCases.count, "Summary should count every workbench section.")

        for section in ValidationWorkbenchSection.allCases {
            guard let model = snapshot.sections.first(where: { $0.section == section }) else {
                throw NativeModelTestFailure(description: "Missing validation workbench section \(section.rawValue).")
            }
            try expectEqual(model.rows.isEmpty, false, "Validation workbench section \(section.rawValue) should contain rows.")
        }

        try expectEqual(snapshot.row(for: .lockedSession)?.section, .sessionWindow, "locked-session should be in the Session / Window group.")
        try expectEqual(snapshot.row(for: .windowNotFound)?.section, .sessionWindow, "window-not-found should be in the Session / Window group.")
        try expectEqual(snapshot.row(for: .noAXWindow)?.section, .sessionWindow, "no-ax-window should be in the Session / Window group.")
        try expectEqual(snapshot.row(for: .activationFailed)?.section, .sessionWindow, "activation-failed should be in the Session / Window group.")
        try expectEqual(snapshot.row(for: .screenRecordingPermission)?.section, .permissions, "screen-recording-permission should be in the Permissions group.")
        try expectEqual(snapshot.row(for: .staleBundle)?.section, .bundleFreshness, "stale-bundle should be in the Bundle freshness group.")
        try expectEqual(snapshot.row(for: .blackCapture)?.section, .screenshotQuality, "black-capture should be in the Screenshot quality group.")
        try expectEqual(snapshot.row(for: .flatCapture)?.section, .screenshotQuality, "flat-capture should be in the Screenshot quality group.")
        try expectEqual(snapshot.row(for: .transparentCapture)?.section, .screenshotQuality, "transparent-capture should be in the Screenshot quality group.")
        try expectEqual(snapshot.row(for: .invalidCapture)?.section, .screenshotQuality, "invalid-capture should be in the Screenshot quality group.")
        try expectEqual(snapshot.row(for: .computerUseTimeout)?.section, .computerUseToolLayer, "computer-use-timeout should be in the Computer Use / tool layer group.")
        try expectEqual(snapshot.row(for: .remoteConnection)?.section, .computerUseToolLayer, "remote-connection should be in the Computer Use / tool layer group.")
        try expectEqual(snapshot.row(for: .toolLayerUnknown)?.section, .computerUseToolLayer, "tool-layer-unknown should be in the Computer Use / tool layer group.")
    }

    private func keepsSafetyNotesAndFlagsReadOnly() throws {
        let snapshot = ValidationWorkbenchModel.canonicalSnapshot
        let safety = snapshot.summary.safety

        try expectEqual(safety.allUnsafeCapabilitiesBlocked, true, "Validation workbench safety should block every unsafe capability.")
        try expectFalse(safety.providerCallsAllowed, "Validation workbench must not allow provider calls.")
        try expectFalse(safety.writeActionsAllowed, "Validation workbench must not allow write actions.")
        try expectFalse(safety.scriptExecutionAllowed, "Validation workbench must not allow script execution.")
        try expectFalse(safety.credentialAccessAllowed, "Validation workbench must not allow credential access.")
        try expectFalse(safety.cloudSyncAllowed, "Validation workbench must not allow cloud sync.")
        try expectFalse(safety.telemetryAllowed, "Validation workbench must not allow telemetry.")
        try expectFalse(safety.backgroundJobsAllowed, "Validation workbench must not allow hidden background jobs.")

        for row in snapshot.rows {
            try expectContains(row.safetyNote, "does not call providers", "Every validation workbench row should state the read-only provider boundary.")
            try expectContains(row.safetyNote, "write files", "Every validation workbench row should state the no-write boundary.")
            try expectContains(row.safetyNote, "execute scripts", "Every validation workbench row should state the no-script boundary.")
            try expectContains(row.safetyNote, "read credentials", "Every validation workbench row should state the no-credential boundary.")
            try expectContains(row.safetyNote, "sync cloud data", "Every validation workbench row should state the no-cloud boundary.")
            try expectContains(row.safetyNote, "emit telemetry", "Every validation workbench row should state the no-telemetry boundary.")
            try expectContains(row.safetyNote, "start background jobs", "Every validation workbench row should state the no-background-job boundary.")
        }
    }

    private func requiresUnlockedRealLocalComputerUseEvidence() throws {
        let snapshot = ValidationWorkbenchModel.canonicalSnapshot
        let summary = snapshot.summary

        try expectEqual(summary.status, .required, "Validation workbench should keep real-local evidence as required.")
        try expectEqual(summary.fixtureSmokeIsSubstitute, false, "Fixture smoke must not be marked as a substitute for real-local evidence.")
        try expectEqual(summary.unlockedRealLocalComputerUseRequired, true, "Unlocked real-local Computer Use should be required.")
        try expectContains(summary.summaryText, "Computer Use", "Summary should name Computer Use as required evidence.")
        try expectContains(summary.summaryText, "Fixture smoke is supporting evidence only", "Summary should keep fixture smoke supporting-only.")
        try expectContains(summary.requiredEvidence.first, "Unlocked real-local Computer Use", "Required evidence should name unlocked real-local Computer Use.")

        let evidenceRows = snapshot.sections.first { $0.section == .evidenceStandards }?.rows ?? []
        let requiredRows = evidenceRows.filter { $0.status == .required }
        try expectEqual(requiredRows.count, 1, "Evidence standards should include a required real-local row.")
        try expectContains(requiredRows.first?.explanation, "cannot replace blocked real-local Computer Use", "Evidence standard should reject fixture replacement.")
    }
}
