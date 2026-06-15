import SwiftUI

struct TaskCockpitPanel: View {
    @Binding var taskText: String
    let currentTaskText: String
    let result: TaskCockpitResult?
    let isBuilding: Bool
    let operationState: TaskCockpitOperationState
    let onBuild: () -> Void
    let onCancel: () -> Void

    private var inputModel: TaskInputModel {
        TaskInputModel(rawText: taskText)
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

            HStack(alignment: .top, spacing: 10) {
                TaskInputTextEditor(
                    text: $taskText,
                    placeholder: UIStrings.taskCockpitTaskPlaceholder
                )

                Button {
                    onBuild()
                } label: {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .disabled(isBuilding || !inputModel.canSubmit)
                .help(UIStrings.taskCockpitBoundary)
                .accessibilityIdentifier(AppAccessibilityID.taskCockpitBuildButton)
                .accessibilityLabel(actionTitle)
            }

            TaskCockpitOperationStatusView(
                state: operationState,
                isBuilding: isBuilding,
                onCancel: onCancel,
                onRetry: onBuild
            )

            TaskCockpitStageProgressView(
                state: operationState,
                isBuilding: isBuilding,
                result: result
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.taskCockpitPanel)
        .accessibilityLabel(UIStrings.taskCockpitTitle)
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
                        .accessibilityIdentifier(AppAccessibilityID.taskCockpitCancelButton)
                        .accessibilityLabel(UIStrings.cancel)
                    }
                    if state.canRetry {
                        Button {
                            onRetry()
                        } label: {
                            Label(UIStrings.taskCockpitRetry, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier(AppAccessibilityID.taskCockpitRetryButton)
                        .accessibilityLabel(UIStrings.taskCockpitRetry)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.26), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AppAccessibilityID.taskCockpitStatus)
                .accessibilityLabel(statusMessage(now: context.date))
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

private struct TaskCockpitStageProgressView: View {
    let state: TaskCockpitOperationState
    let isBuilding: Bool
    let result: TaskCockpitResult?

    var body: some View {
        if shouldRender {
            TimelineView(.periodic(from: state.startedAt ?? Date(), by: 1)) { context in
                let snapshot = TaskCockpitProgressSnapshot(
                    operationState: state,
                    result: result,
                    now: context.date
                )
                content(snapshot: snapshot)
            }
        }
    }

    private var shouldRender: Bool {
        isBuilding || result != nil || state.phase != .idle
    }

    private var blockerCount: Int {
        guard let result else { return 0 }
        return max(result.summary.blockerCount, result.blockerRows.count, result.aggregation?.blockerCodes.count ?? 0)
    }

    private func content(snapshot: TaskCockpitProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(UIStrings.taskCockpitProgressTitle, systemImage: "list.bullet.clipboard")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                ForEach(indicators(snapshot: snapshot)) { indicator in
                    Label(indicator.title, systemImage: indicator.systemImage)
                        .font(.caption2.bold())
                        .foregroundStyle(indicator.foregroundStyle)
                        .lineLimit(1)
                }
            }

            ProgressView(value: snapshot.estimatedProgress)
                .controlSize(.small)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(snapshot.stageRows) { row in
                    TaskCockpitStageTile(row: row)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.taskCockpitStageProgress)
        .accessibilityLabel(UIStrings.taskCockpitProgressTitle)
        .accessibilityValue(accessibilitySummary(snapshot: snapshot))
    }

    private func indicators(snapshot: TaskCockpitProgressSnapshot) -> [TaskCockpitStageIndicator] {
        var rows: [TaskCockpitStageIndicator] = []
        if state.startedAt != nil || isBuilding {
            rows.append(
                TaskCockpitStageIndicator(
                    id: "elapsed",
                    title: UIStrings.taskCockpitElapsedSeconds(snapshot.elapsedSeconds),
                    systemImage: "timer",
                    foregroundStyle: AnyShapeStyle(.secondary)
                )
            )
        }
        if hasFallbackIndicator(snapshot: snapshot) {
            rows.append(
                TaskCockpitStageIndicator(
                    id: "fallback",
                    title: UIStrings.taskCockpitProgressFallback,
                    systemImage: "exclamationmark.triangle",
                    foregroundStyle: AnyShapeStyle(.secondary)
                )
            )
        }
        if blockerCount > 0 {
            rows.append(
                TaskCockpitStageIndicator(
                    id: "blocked",
                    title: UIStrings.taskCockpitProgressBlocked(blockerCount),
                    systemImage: "exclamationmark.octagon",
                    foregroundStyle: AnyShapeStyle(.orange)
                )
            )
        }
        if state.phase == .timedOut || result?.aggregation?.timedOut == true {
            rows.append(
                TaskCockpitStageIndicator(
                    id: "timedOut",
                    title: UIStrings.taskCockpitProgressTimedOut,
                    systemImage: "clock.badge.exclamationmark",
                    foregroundStyle: AnyShapeStyle(.orange)
                )
            )
        }
        return rows
    }

    private func hasFallbackIndicator(snapshot: TaskCockpitProgressSnapshot) -> Bool {
        snapshot.stageRows.contains { row in
            row.state == .fallback || row.state == .unavailable
        } || result?.aggregation?.partial == true || result?.aggregation?.fallbackUsed == true
    }

    private func accessibilitySummary(snapshot: TaskCockpitProgressSnapshot) -> String {
        let stageSummary = snapshot.stageRows
            .map { "\($0.title): \(TaskCockpitStageTile.stateTitle($0.state))" }
            .joined(separator: ", ")
        let indicatorSummary = indicators(snapshot: snapshot)
            .map(\.title)
            .joined(separator: ", ")
        guard !indicatorSummary.isEmpty else { return stageSummary }
        return "\(indicatorSummary). \(stageSummary)"
    }
}

private struct TaskCockpitStageIndicator: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let foregroundStyle: AnyShapeStyle
}

private struct TaskCockpitStageTile: View {
    let row: TaskCockpitProgressRow

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: stageSystemImage(row.stage))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.caption.bold())
                    .lineLimit(1)
                Label(Self.stateTitle(row.state), systemImage: stateSystemImage(row.state))
                    .font(.caption2)
                    .foregroundStyle(stateForegroundStyle(row.state))
                    .lineLimit(1)
                if !row.detail.isEmpty {
                    PrivacyEvidenceText(value: row.detail, font: .caption2, lineLimit: 2)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if row.count > 0 {
                    Text("\(row.count)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let score = row.score {
                    Text("\(score)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(minHeight: 68, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.title)
        .accessibilityValue(accessibilityValue)
    }

    static func stateTitle(_ state: TaskCockpitProgressState) -> String {
        switch state {
        case .idle, .queued:
            return UIStrings.taskCockpitProgressPending
        case .active:
            return UIStrings.taskCockpitProgressChecking
        case .completed:
            return UIStrings.taskCockpitProgressReady
        case .empty:
            return UIStrings.taskCockpitProgressNoRows
        case .fallback:
            return UIStrings.taskCockpitProgressPartial
        case .skipped:
            return UIStrings.taskCockpitProgressSkipped
        case .unavailable:
            return UIStrings.taskCockpitProgressUnavailable
        case .timedOut:
            return UIStrings.taskCockpitProgressTimedOut
        case .cancelled:
            return UIStrings.taskCockpitProgressCancelled
        case .failed:
            return UIStrings.taskCockpitProgressFailed
        }
    }

    private var accessibilityValue: String {
        var parts = [Self.stateTitle(row.state)]
        if row.count > 0 {
            parts.append(UIStrings.taskCockpitProgressRows(row.count))
        }
        if !row.detail.isEmpty {
            parts.append(row.detail)
        }
        return parts.joined(separator: ". ")
    }

    private func stageSystemImage(_ stage: TaskCockpitProgressStage) -> String {
        switch stage {
        case .readiness:
            return "gauge.medium"
        case .routing:
            return "point.3.connected.trianglepath.dotted"
        case .crossAgent:
            return "person.3"
        case .remediation:
            return "wrench.and.screwdriver"
        case .batchReview:
            return "checklist"
        case .provider:
            return "network"
        case .session:
            return "text.bubble"
        }
    }

    private func stateSystemImage(_ state: TaskCockpitProgressState) -> String {
        switch state {
        case .idle, .queued:
            return "circle"
        case .active:
            return "hourglass"
        case .completed:
            return "checkmark.circle"
        case .empty:
            return "minus.circle"
        case .fallback:
            return "exclamationmark.triangle"
        case .skipped:
            return "forward.circle"
        case .unavailable, .failed:
            return "exclamationmark.octagon"
        case .timedOut:
            return "clock.badge.exclamationmark"
        case .cancelled:
            return "xmark.circle"
        }
    }

    private func stateForegroundStyle(_ state: TaskCockpitProgressState) -> AnyShapeStyle {
        switch state {
        case .active:
            return AnyShapeStyle(.primary)
        case .unavailable, .timedOut, .failed:
            return AnyShapeStyle(.orange)
        case .idle, .queued, .completed, .empty, .fallback, .skipped, .cancelled:
            return AnyShapeStyle(.secondary)
        }
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.taskCockpitResult)
        .accessibilityLabel(UIStrings.taskCockpitTitle)
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
                                PrivacyEvidenceText(value: row.summary, font: .caption, lineLimit: 3)
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
                                PrivacyEvidenceText(value: source, font: .caption2, lineLimit: 1)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        if !row.detail.isEmpty {
                            PrivacyEvidenceText(value: row.detail, font: .caption, lineLimit: nil)
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
            HStack(spacing: 6) {
                Text(UIStrings.crossAgentReadinessEvidence)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if !evidence.isEmpty {
                    DenseCountBadge(count: evidence.count)
                }
            }
            if evidence.isEmpty {
                Text(UIStrings.crossAgentReadinessNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                DenseDisclosureList(evidence, visibleLimit: 6, spacing: 6) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        HStack(spacing: 8) {
                            if let agent = item.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                            if let source = item.source, !source.isEmpty {
                                PrivacyEvidenceText(value: source, font: .caption2, lineLimit: 1)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        PrivacyEvidenceText(value: item.detail, font: .caption, lineLimit: nil)
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
                DenseDisclosureList(safety.notes, visibleLimit: 4, spacing: 4) { note in
                    PrivacyEvidenceLabel(value: note, systemImage: "info.circle", font: .caption, lineLimit: 2)
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
