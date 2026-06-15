import SwiftUI

struct TaskCockpitPanel: View {
    @Binding var taskText: String
    let currentTaskText: String
    let result: TaskCockpitResult?
    let isBuilding: Bool
    let operationState: TaskCockpitOperationState
    let onBuild: () -> Void
    let onCancel: () -> Void

    private var effectiveTaskText: String {
        let trimmed = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? currentTaskText : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.taskCockpitTitle, systemImage: "rectangle.grid.2x2")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.taskCockpitBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(UIStrings.taskCockpitTaskPlaceholder, text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .labelsHidden()

                Button {
                    onBuild()
                } label: {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .disabled(isBuilding || effectiveTaskText.isEmpty)
                .help(UIStrings.taskCockpitBoundary)
            }

            TaskCockpitOperationStatusView(
                state: operationState,
                isBuilding: isBuilding,
                onCancel: onCancel,
                onRetry: onBuild
            )

            if let result {
                TaskCockpitResultView(result: result)
            } else if !isBuilding {
                Label(UIStrings.taskCockpitNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var actionTitle: String {
        operationState.canRetry ? UIStrings.taskCockpitRetry : UIStrings.taskCockpitAction
    }

    private var actionSystemImage: String {
        operationState.canRetry ? "arrow.clockwise" : "rectangle.grid.2x2"
    }
}

private struct TaskCockpitOperationStatusView: View {
    let state: TaskCockpitOperationState
    let isBuilding: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        if state.phase != .idle && state.phase != .completed {
            TimelineView(.periodic(from: state.startedAt ?? Date(), by: 1)) { context in
                HStack(alignment: .top, spacing: 10) {
                    if state.phase == .preparing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Label(statusMessage(now: context.date), systemImage: systemImage)
                        .font(.callout)
                        .foregroundStyle(foregroundStyle)
                        .textSelection(.enabled)
                    Spacer(minLength: 8)
                    if state.canCancel && isBuilding {
                        Button {
                            onCancel()
                        } label: {
                            Label(UIStrings.cancel, systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if state.canRetry {
                        Button {
                            onRetry()
                        } label: {
                            Label(UIStrings.taskCockpitRetry, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.26), in: RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .bottomLeading) {
                    if state.phase == .preparing, state.timeoutSeconds > 0 {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(.secondary.opacity(0.35))
                                .frame(width: proxy.size.width * progress(now: context.date), height: 2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var systemImage: String {
        switch state.phase {
        case .idle, .completed:
            return "checkmark.circle"
        case .preparing:
            return "hourglass"
        case .fallback:
            return "exclamationmark.triangle"
        case .timedOut:
            return "clock.badge.exclamationmark"
        case .cancelled:
            return "xmark.circle"
        case .failed:
            return "exclamationmark.octagon"
        }
    }

    private var foregroundStyle: AnyShapeStyle {
        switch state.phase {
        case .timedOut, .failed:
            return AnyShapeStyle(.orange)
        case .fallback, .cancelled:
            return AnyShapeStyle(.secondary)
        case .idle, .preparing, .completed:
            return AnyShapeStyle(.secondary)
        }
    }

    private func statusMessage(now: Date) -> String {
        if state.phase == .preparing {
            return UIStrings.taskCockpitPreparingStatus(
                elapsedSeconds: state.elapsedSeconds(now: now),
                timeoutSeconds: state.timeoutSeconds
            )
        }
        if state.elapsedSeconds() > 0 {
            return "\(state.message) \(UIStrings.taskCockpitElapsedSeconds(state.elapsedSeconds()))"
        }
        return state.message
    }

    private func progress(now: Date) -> CGFloat {
        guard state.timeoutSeconds > 0 else { return 0 }
        return min(1, CGFloat(Double(state.elapsedSeconds(now: now)) / Double(state.timeoutSeconds)))
    }
}

private struct TaskCockpitResultView: View {
    let result: TaskCockpitResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.taskCockpitRoutes, value: "\(routeCount)", systemImage: "point.3.connected.trianglepath.dotted")
                SummaryChip(title: UIStrings.taskCockpitAgents, value: "\(agentCount)", systemImage: "person.3")
                SummaryChip(title: UIStrings.taskCockpitSkills, value: "\(skillCount)", systemImage: "doc.text")
                SummaryChip(title: UIStrings.taskCockpitReadinessSignals, value: "\(readinessSignalCount)", systemImage: "gauge.medium")
                SummaryChip(title: UIStrings.taskReadinessGaps, value: "\(gapCount)", systemImage: "puzzlepiece.extension")
                SummaryChip(title: UIStrings.taskReadinessBlockers, value: "\(blockerCount)", systemImage: "exclamationmark.octagon")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.routingAccuracyCatalog, value: result.catalogAvailable ? UIStrings.routingAccuracyAvailable : UIStrings.routingAccuracyUnavailableShort)
                MetadataRow(label: UIStrings.taskReadinessTask, value: taskLabel)
                MetadataRow(label: UIStrings.taskCockpitRecommendedAgent, value: result.summary.recommendedAgent.map(DisplayText.agent) ?? UIStrings.unknown)
                MetadataRow(label: UIStrings.taskCockpitRecommendedSkill, value: result.summary.recommendedSkillName ?? UIStrings.unknown)
                MetadataRow(label: UIStrings.crossAgentReadinessReadinessScore, value: result.summary.readinessScore.map(String.init) ?? UIStrings.unknown)
                MetadataRow(label: UIStrings.crossAgentReadinessRoutingScore, value: result.summary.routingScore.map(String.init) ?? UIStrings.unknown)
                if let promptRequest = result.promptRequest {
                    MetadataRow(label: UIStrings.routingAccuracyPromptRequest, value: promptRequestLabel(promptRequest))
                }
            }

            if !result.summary.summaryText.isEmpty {
                Text(result.summary.summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            TaskCockpitContextList(title: UIStrings.taskCockpitSections, empty: UIStrings.taskCockpitNoRows, rows: result.cockpitSections, systemImage: "rectangle.grid.2x2")
            TaskCockpitCandidateList(title: UIStrings.taskCockpitTasks, empty: UIStrings.taskCockpitNoRows, rows: result.taskRows, systemImage: "text.badge.checkmark")
            TaskCockpitCandidateList(title: UIStrings.taskCockpitRoutes, empty: UIStrings.taskCockpitNoRows, rows: result.routeCandidates, systemImage: "point.3.connected.trianglepath.dotted")
            TaskCockpitCandidateList(title: UIStrings.taskCockpitAgents, empty: UIStrings.taskCockpitNoRows, rows: result.agentCandidates, systemImage: "person.3")
            TaskCockpitCandidateList(title: UIStrings.taskCockpitSkills, empty: UIStrings.taskCockpitNoRows, rows: result.skillCandidates, systemImage: "doc.text")
            TaskCockpitContextList(title: UIStrings.taskCockpitReadinessSignals, empty: UIStrings.taskCockpitNoRows, rows: result.readinessSignals, systemImage: "gauge.medium")
            TaskCockpitContextList(title: UIStrings.taskCockpitSessionContext, empty: UIStrings.taskCockpitNoRows, rows: result.sessionReviewContext, systemImage: "text.bubble")
            TaskCockpitContextList(title: UIStrings.taskCockpitProviderContext, empty: UIStrings.taskCockpitNoRows, rows: result.providerObservabilityContext, systemImage: "network")
            TaskCockpitContextList(title: UIStrings.taskCockpitRemediationContext, empty: UIStrings.taskCockpitNoRows, rows: result.remediationContext, systemImage: "wrench.and.screwdriver")
            TaskCockpitContextList(title: UIStrings.taskReadinessGaps, empty: UIStrings.taskReadinessNoGaps, rows: result.gapRows, systemImage: "puzzlepiece.extension")
            TaskCockpitContextList(title: UIStrings.taskReadinessBlockers, empty: UIStrings.taskReadinessNoBlockers, rows: result.blockerRows, systemImage: "exclamationmark.octagon")
            TaskCockpitEvidenceList(evidence: result.evidenceReferences)
            TaskCockpitSafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var taskLabel: String {
        if !result.filters.taskText.isEmpty {
            return result.filters.taskText
        }
        if !result.summary.taskText.isEmpty {
            return result.summary.taskText
        }
        return UIStrings.unknown
    }

    private var routeCount: Int {
        result.summary.routeCandidateCount > 0 ? result.summary.routeCandidateCount : result.routeCandidates.count
    }

    private var agentCount: Int {
        result.summary.agentCandidateCount > 0 ? result.summary.agentCandidateCount : result.agentCandidates.count
    }

    private var skillCount: Int {
        result.summary.skillCandidateCount > 0 ? result.summary.skillCandidateCount : result.skillCandidates.count
    }

    private var readinessSignalCount: Int {
        result.summary.readinessSignalCount > 0 ? result.summary.readinessSignalCount : result.readinessSignals.count
    }

    private var gapCount: Int {
        result.summary.gapCount > 0 ? result.summary.gapCount : result.gapRows.count
    }

    private var blockerCount: Int {
        result.summary.blockerCount > 0 ? result.summary.blockerCount : result.blockerRows.count
    }

    private func promptRequestLabel(_ promptRequest: ProviderObservabilityPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy)"
    }
}

private struct TaskCockpitCandidateList: View {
    let title: String
    let empty: String
    let rows: [TaskCockpitCandidateRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(8)) { row in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(rowTitle(row), systemImage: systemImage)
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                if let score = row.routingScore ?? row.readinessScore ?? row.score {
                                    Text("\(score)")
                                        .font(.caption.monospacedDigit().bold())
                                }
                            }
                            HStack(spacing: 6) {
                                if let agent = row.agent, !agent.isEmpty {
                                    Text(DisplayText.agent(agent))
                                }
                                if let band = row.band, !band.isEmpty {
                                    Text(band)
                                }
                                if let status = row.status, !status.isEmpty {
                                    Text(status)
                                }
                            }
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                                MetadataRow(label: UIStrings.crossAgentReadinessReadinessScore, value: row.readinessScore.map(String.init) ?? UIStrings.unknown)
                                MetadataRow(label: UIStrings.crossAgentReadinessRoutingScore, value: row.routingScore.map(String.init) ?? UIStrings.unknown)
                                if let skill = row.skill {
                                    MetadataRow(label: UIStrings.crossAgentReadinessBestSkill, value: skill.name)
                                }
                            }

                            if !row.summary.isEmpty {
                                Text(row.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                            RoutingInlineList(title: UIStrings.crossAgentReadinessReasons, empty: UIStrings.crossAgentReadinessNoReasons, values: row.reasons, systemImage: "text.bubble")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                            RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: row.safetyFlags, systemImage: "checkmark.shield")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func rowTitle(_ row: TaskCockpitCandidateRow) -> String {
        if let rank = row.rank {
            return "#\(rank) \(row.title)"
        }
        return row.title
    }
}

private struct TaskCockpitContextList: View {
    let title: String
    let empty: String
    let rows: [TaskCockpitContextRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(6)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(row.title, systemImage: systemImage)
                                .font(.callout.bold())
                            Spacer()
                            if let count = row.count {
                                Text("\(count)")
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            if let agent = row.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                            if let status = row.status, !status.isEmpty {
                                Text(status)
                            }
                            if let severity = row.severity, !severity.isEmpty {
                                Text(severity)
                            }
                            if let source = row.source, !source.isEmpty {
                                Text(source)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        if !row.detail.isEmpty {
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                        RoutingInlineList(title: UIStrings.knowledgeSafetyFlags, empty: UIStrings.taskBenchmarkNoSafetyFlags, values: row.safetyFlags, systemImage: "checkmark.shield")
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

private struct TaskCockpitEvidenceList: View {
    let evidence: [ProviderObservabilityEvidenceReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(UIStrings.crossAgentReadinessEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.crossAgentReadinessNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(6)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        HStack(spacing: 8) {
                            if let agent = item.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                            if let source = item.source, !source.isEmpty {
                                Text(source)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct TaskCockpitSafetyList: View {
    let safety: ProviderObservabilitySafety

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.crossAgentReadinessSafetyFlags)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Label(
                safety.allReadOnlyFlagsClear ? UIStrings.routingAccuracySafetyClear : UIStrings.llmSkillAnalysisEnabledUnsafe,
                systemImage: safety.allReadOnlyFlagsClear ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SafetyPill(label: row.label, isBlocked: !row.isUnsafe)
                }
            }

            if !safety.notes.isEmpty {
                ForEach(safety.notes.prefix(4), id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rows: [(label: String, isUnsafe: Bool)] {
        [
            (UIStrings.skillQualityProviderNotSent, safety.providerRequestSent),
            (UIStrings.skillQualityWritesBlocked, safety.writeBackAllowed || safety.writeActionsAvailable),
            (UIStrings.skillQualityScriptsBlocked, safety.scriptExecutionAllowed || safety.executionActionsAvailable),
            (UIStrings.skillQualityMutationsBlocked, safety.configMutationAllowed || safety.snapshotCreated || safety.triageMutationAllowed),
            (UIStrings.skillQualityCredentialsBlocked, safety.credentialAccessed || safety.rawSecretReturned),
            (UIStrings.llmPromptRawPromptStored, safety.rawPromptPersisted),
            (UIStrings.llmPromptRawResponseStored, safety.rawResponsePersisted),
            (UIStrings.routingAccuracyRawTraceStored, safety.rawTracePersisted),
            (UIStrings.routingAccuracyCloudSync, safety.cloudSyncEnabled),
            (UIStrings.routingAccuracyTelemetry, safety.telemetryEnabled)
        ]
    }
}
