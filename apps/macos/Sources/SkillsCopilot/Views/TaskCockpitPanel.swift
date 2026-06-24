import Foundation
import SwiftUI

struct TaskPreflightPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Label(UIStrings.taskCockpitTitle, systemImage: "checklist")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(UIStrings.done) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            HStack(alignment: .top, spacing: 12) {
                ScrollView {
                    TaskCockpitPanel(
                        taskText: $store.taskCockpitText,
                        currentTaskText: store.selectedTaskCockpitInput,
                        result: store.taskCockpitResult,
                        isBuilding: store.isBuildingTaskCockpit,
                        operationState: store.taskCockpitOperationState,
                        onBuild: {
                            Task {
                                await store.buildTaskCockpit()
                            }
                        },
                        onCancel: {
                            store.cancelTaskCockpitBuild()
                        }
                    )
                }
                .frame(minWidth: 640, maxWidth: .infinity)

                TaskPreflightHistoryPanel(
                    records: store.taskCockpitHistory,
                    selectedID: store.selectedTaskCockpitHistoryID,
                    onSelect: { record in
                        store.selectTaskCockpitHistoryRecord(record)
                    }
                )
                .frame(width: 270)
            }
        }
        .padding(16)
        .frame(minWidth: 950, idealWidth: 1_020, minHeight: 620, alignment: .topLeading)
    }
}

private struct TaskPreflightHistoryPanel: View {
    let records: [TaskCockpitHistoryRecord]
    let selectedID: TaskCockpitHistoryRecord.ID?
    let onSelect: (TaskCockpitHistoryRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.text("taskCockpit.history.title", "History"), systemImage: "clock.arrow.circlepath")
                .font(.headline)

            if records.isEmpty {
                Text(UIStrings.text("taskCockpit.history.empty", "No task preflight history yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(records) { record in
                            TaskPreflightHistoryRow(
                                record: record,
                                isSelected: record.id == selectedID,
                                onSelect: {
                                    onSelect(record)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .adaptiveMaterialSurface()
    }
}

private struct TaskPreflightHistoryRow: View {
    let record: TaskCockpitHistoryRecord
    let isSelected: Bool
    let onSelect: () -> Void

    private var model: TaskCockpitDecisionModel {
        TaskCockpitDecisionModel(result: record.result)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: model.verdict.systemImage)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : model.verdict.tint)
                    Text(record.displayTask)
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(2)
                }

                Text(Self.dateFormatter.string(from: record.createdAt))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.verdict.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.86) : model.verdict.tint)
                        .lineLimit(1)
                    Text(model.recommendationLine)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.74) : .secondary)
                        .lineLimit(2)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(record.displayTask)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

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
                Label(UIStrings.taskCockpitTitle, systemImage: "checklist")
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

            VStack(alignment: .trailing, spacing: 8) {
                TaskInputTextEditor(
                    text: $taskText,
                    placeholder: UIStrings.taskCockpitTaskPlaceholder
                )
                .frame(maxWidth: .infinity)

                buildButton
            }

            if isBuilding || result == nil {
                TaskCockpitOperationStatusView(
                    state: operationState,
                    isBuilding: isBuilding,
                    onCancel: onCancel,
                    onRetry: onBuild
                )
            }

            if let result {
                TaskCockpitResultView(
                    result: result,
                    operationState: operationState,
                    isBuilding: isBuilding
                )
            } else if !isBuilding {
                Label(UIStrings.taskCockpitNoResult, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.taskCockpitReadOnlyFootnote, systemImage: "nosign")
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
        operationState.canRetry ? "arrow.clockwise" : "checklist"
    }

    private var buildButton: some View {
        Button {
            onBuild()
        } label: {
            Label(actionTitle, systemImage: actionSystemImage)
                .frame(minWidth: 132)
        }
        .controlSize(.regular)
        .buttonStyle(.borderedProminent)
        .disabled(isBuilding || !inputModel.canSubmit)
        .help(UIStrings.taskCockpitBoundary)
        .accessibilityIdentifier(AppAccessibilityID.taskCockpitBuildButton)
        .accessibilityLabel(actionTitle)
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
    let operationState: TaskCockpitOperationState
    let isBuilding: Bool
    @State private var diagnosticsExpanded = false

    private var model: TaskCockpitDecisionModel {
        TaskCockpitDecisionModel(result: result)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TaskCockpitDecisionSummaryCard(model: model)

            DisclosureGroup(isExpanded: $diagnosticsExpanded) {
                TaskCockpitTechnicalDiagnosticsView(
                    result: result,
                    operationState: operationState,
                    isBuilding: isBuilding
                )
                .padding(.top, 8)
            } label: {
                Label(UIStrings.taskCockpitDiagnosticsTitle, systemImage: "stethoscope")
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.taskCockpitResult)
        .accessibilityLabel(UIStrings.taskCockpitTitle)
    }
}

private enum TaskCockpitVerdict {
    case ready
    case needsReview
    case blocked
    case unavailable

    var title: String {
        switch self {
        case .ready:
            return UIStrings.taskCockpitVerdictReady
        case .needsReview:
            return UIStrings.taskCockpitVerdictNeedsReview
        case .blocked:
            return UIStrings.taskCockpitVerdictBlocked
        case .unavailable:
            return UIStrings.taskCockpitVerdictUnavailable
        }
    }

    var message: String {
        switch self {
        case .ready:
            return UIStrings.taskCockpitVerdictReadyMessage
        case .needsReview:
            return UIStrings.taskCockpitVerdictNeedsReviewMessage
        case .blocked:
            return UIStrings.taskCockpitVerdictBlockedMessage
        case .unavailable:
            return UIStrings.taskCockpitVerdictUnavailableMessage
        }
    }

    var systemImage: String {
        switch self {
        case .ready:
            return "checkmark.seal"
        case .needsReview:
            return "exclamationmark.triangle"
        case .blocked:
            return "octagon"
        case .unavailable:
            return "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .ready:
            return .green
        case .needsReview:
            return .orange
        case .blocked:
            return .red
        case .unavailable:
            return .gray
        }
    }
}

private struct TaskCockpitDecisionModel {
    let result: TaskCockpitResult

    var verdict: TaskCockpitVerdict {
        if result.isUnavailable {
            return .unavailable
        }
        if userBlockerCount > 0 || scoreIsBlocked(readinessScore) {
            return .blocked
        }
        if gapCount > 0 || scoreNeedsReview(readinessScore) || scoreNeedsReview(routingScore) {
            return .needsReview
        }
        return .ready
    }

    var taskLabel: String {
        if !result.filters.taskText.isEmpty {
            return result.filters.taskText
        }
        if !result.summary.taskText.isEmpty {
            return result.summary.taskText
        }
        return UIStrings.unknown
    }

    var hasReliableRecommendation: Bool {
        switch verdict {
        case .ready, .needsReview:
            return recommendedAgent != UIStrings.unknown || recommendedSkill != UIStrings.unknown
        case .blocked, .unavailable:
            return false
        }
    }

    var recommendationLine: String {
        hasReliableRecommendation
            ? "\(recommendedAgent) · \(recommendedSkill)"
            : UIStrings.taskCockpitNoReliableRecommendation
    }

    var recommendedAgent: String {
        let raw = result.summary.recommendedAgent ?? topRoute?.agent ?? topSkill?.agent ?? topAgent?.agent
        return raw.map(DisplayText.agent) ?? UIStrings.unknown
    }

    var recommendedSkill: String {
        result.summary.recommendedSkillName
            ?? topRoute?.skill?.name
            ?? topSkill?.skill?.name
            ?? topSkill?.title
            ?? topRoute?.title
            ?? UIStrings.unknown
    }

    var readinessScore: Int? {
        result.summary.readinessScore ?? topRoute?.readinessScore ?? topSkill?.readinessScore
    }

    var routingScore: Int? {
        result.summary.routingScore ?? topRoute?.routingScore ?? topSkill?.routingScore ?? topRoute?.score
    }

    var routeCount: Int {
        max(result.summary.routeCandidateCount, result.routeCandidates.count)
    }

    var skillCount: Int {
        max(result.summary.skillCandidateCount, result.skillCandidates.count)
    }

    var gapCount: Int {
        result.gapRows.isEmpty ? result.summary.gapCount : result.gapRows.count
    }

    var userBlockerCount: Int {
        if result.blockerRows.isEmpty {
            return result.summary.blockerCount
        }
        return userBlockerRows.count
    }

    var showsPartialNotice: Bool {
        result.recoveryDiagnosticReason != nil && !result.isUnavailable
    }

    var reasons: [String] {
        var values: [String] = []
        values.append(result.summary.summaryText)
        if let topRoute {
            values.append(topRoute.summary)
            values.append(contentsOf: topRoute.reasons)
        }
        values.append(contentsOf: result.readinessSignals.map(\.detail))
        values.append(contentsOf: result.agentCandidates.prefix(1).flatMap(\.reasons))
        return Self.uniqueMeaningful(values)
    }

    var attentionRows: [TaskCockpitContextRow] {
        Array((userBlockerRows + result.gapRows).prefix(3))
    }

    var keyReasons: [String] {
        var values = attentionRows.flatMap { row -> [String] in
            [
                Self.displayText(row.title),
                Self.displayText(row.detail)
            ].compactMap(\.self)
        }
        values.append(contentsOf: reasons)
        return Array(Self.uniqueMeaningful(values).prefix(3))
    }

    var nextStep: String {
        switch verdict {
        case .ready:
            return UIStrings.taskCockpitNextStepReady
        case .needsReview:
            return UIStrings.taskCockpitNextStepNeedsReview
        case .blocked:
            return UIStrings.taskCockpitNextStepBlocked
        case .unavailable:
            return UIStrings.taskCockpitNextStepUnavailable
        }
    }

    private var topRoute: TaskCockpitCandidateRow? {
        result.routeCandidates.first
    }

    private var topSkill: TaskCockpitCandidateRow? {
        result.skillCandidates.first
    }

    private var topAgent: TaskCockpitCandidateRow? {
        result.agentCandidates.first
    }

    private var userBlockerRows: [TaskCockpitContextRow] {
        result.blockerRows.filter { row in
            !Self.isInternalBoundary(row.title) && !Self.isInternalBoundary(row.detail)
        }
    }

    private func scoreIsBlocked(_ score: Int?) -> Bool {
        guard let score else { return false }
        return score < 40
    }

    private func scoreNeedsReview(_ score: Int?) -> Bool {
        guard let score else { return false }
        return score < 70
    }

    private static func uniqueMeaningful(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let display = displayText(trimmed) else { continue }
            guard seen.insert(display.lowercased()).inserted else { continue }
            result.append(display)
        }
        return result
    }

    fileprivate static func displayText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isInternalBoundary(trimmed) else { return nil }

        let normalized = trimmed.lowercased()
        if normalized.contains("task readiness is blocked") {
            return UIStrings.taskCockpitReasonReadinessBlocked
        }
        if normalized.contains("routing confidence is blocked") {
            return UIStrings.taskCockpitReasonRoutingBlocked
        }
        if normalized.contains("task wording did not clearly map") {
            return UIStrings.taskCockpitReasonTaskWordingWeak
        }
        if normalized.contains("permissions.exec-needs-human") {
            return UIStrings.taskCockpitReasonExecNeedsHuman
        }
        if normalized.contains("permissions.network-declared") {
            return UIStrings.taskCockpitReasonNetworkDeclared
        }
        if normalized.contains("close or overlapping alternatives") {
            return UIStrings.taskCockpitReasonRouteAmbiguous
        }
        if normalized.contains("duplicate_name") || normalized.contains("cross-agent analysis") {
            return UIStrings.taskCockpitReasonCrossAgentDuplicate
        }
        if normalized.contains("task fit is weak") {
            return UIStrings.taskCockpitReasonTaskFitWeak
        }
        return trimmed
    }

    fileprivate static func isInternalBoundary(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("no apply path")
            || normalized.contains("read-only")
            || normalized.contains("readonly")
            || normalized.contains("provider not sent")
            || normalized.contains("task cockpit combined")
            || normalized.contains("evaluated the top")
            || normalized.contains("skipped by the cockpit request filters")
            || normalized.contains("session review row")
            || normalized.contains("provider observability row")
            || normalized.contains("provider-observability context was skipped")
            || normalized.contains("remediation context was skipped")
            || normalized.contains("session-review context was skipped")
            || normalized.contains("remediation next step")
            || normalized.contains("write action")
            || normalized.contains("script execution")
            || normalized.contains("snapshot")
            || normalized.contains("telemetry")
            || normalized.contains("cockpit only")
            || normalized.contains("仅预览")
            || normalized.contains("只读")
            || normalized.contains("未启动提供方")
            || normalized.contains("不会发送提供方")
            || normalized.contains("不暴露应用")
    }
}

private struct TaskCockpitScorePill: View {
    let label: String
    let score: Int?

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(score.map(String.init) ?? UIStrings.unknown)
                .font(.callout.monospacedDigit().bold())
        }
        .frame(minWidth: 58, alignment: .trailing)
    }
}

private struct TaskCockpitDecisionSummaryCard: View {
    let model: TaskCockpitDecisionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.verdict.systemImage)
                    .font(.title3)
                    .foregroundStyle(model.verdict.tint)
                    .frame(width: 26, alignment: .center)

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.verdict.title)
                        .font(.headline)
                    Text(model.verdict.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TaskCockpitScorePill(label: UIStrings.taskCockpitReadinessShort, score: model.readinessScore)
                    TaskCockpitScorePill(label: UIStrings.taskCockpitRoutingShort, score: model.routingScore)
                }
            }

            if model.showsPartialNotice {
                Label(UIStrings.taskCockpitPartialNotice, systemImage: "info.circle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if model.hasReliableRecommendation {
                DetailMetricGrid(maxColumns: 2, minColumnWidth: 220, spacing: 8) {
                    SummaryChip(title: UIStrings.taskCockpitRecommendedAgent, value: model.recommendedAgent, systemImage: "person.crop.circle", valueLineLimit: 1)
                    SummaryChip(title: UIStrings.taskCockpitRecommendedSkill, value: model.recommendedSkill, systemImage: "doc.text", valueLineLimit: 1)
                }
            } else {
                Label(UIStrings.taskCockpitNoReliableRecommendation, systemImage: "hand.raised")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !model.keyReasons.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label(UIStrings.taskCockpitReasonsTitle, systemImage: "text.bubble")
                        .font(.callout.bold())

                    ForEach(Array(model.keyReasons.enumerated()), id: \.offset) { _, reason in
                        PrivacyEvidenceLabel(value: reason, systemImage: reasonSystemImage, font: .callout, lineLimit: 2)
                    }
                }
            }

            Label(model.nextStep, systemImage: "arrow.forward.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.verdict.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.verdict.title)
        .accessibilityValue(model.verdict.message)
    }

    private var reasonSystemImage: String {
        switch model.verdict {
        case .ready:
            return "checkmark.circle"
        case .needsReview:
            return "exclamationmark.triangle"
        case .blocked:
            return "exclamationmark.circle"
        case .unavailable:
            return "questionmark.circle"
        }
    }
}

private struct TaskCockpitTechnicalDiagnosticsView: View {
    let result: TaskCockpitResult
    let operationState: TaskCockpitOperationState
    let isBuilding: Bool

    private var taskLabel: String {
        if !result.filters.taskText.isEmpty {
            return result.filters.taskText
        }
        if !result.summary.taskText.isEmpty {
            return result.summary.taskText
        }
        return UIStrings.unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.taskCockpitDiagnosticsSummary)
                .font(.callout)
                .foregroundStyle(.secondary)

            TaskCockpitStageProgressView(
                state: operationState,
                isBuilding: isBuilding,
                result: result
            )

            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                PrivacyEvidenceLabel(value: fallbackReason, systemImage: "info.circle", font: .callout, lineLimit: 3)
            }

            DetailMetricGrid {
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

            TaskCockpitContextList(title: UIStrings.taskCockpitSections, empty: UIStrings.taskCockpitNoRows, rows: result.cockpitSections, systemImage: "checklist")
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
