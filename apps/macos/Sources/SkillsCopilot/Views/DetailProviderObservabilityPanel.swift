import AppKit
import SwiftUI

struct ProviderObservabilityPanel: View {
    let result: ProviderObservabilityResult?
    let isLoading: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.providerObservabilityTitle, systemImage: "waveform.path.ecg.rectangle")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.providerObservabilityBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    onLoad()
                } label: {
                    Label(UIStrings.providerObservabilityAction, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
                .help(UIStrings.providerObservabilityBoundary)

                if isLoading {
                    Label(UIStrings.loading, systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let result {
                ProviderObservabilityResultView(result: result)
            } else {
                Label(UIStrings.providerObservabilityNoResult, systemImage: "info.circle")
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
}

struct ProviderObservabilityResultView: View {
    let result: ProviderObservabilityResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fallbackReason = result.fallbackReason, !fallbackReason.isEmpty {
                Label(fallbackReason, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.providerObservabilityCalls, value: "\(callCount)", systemImage: "network")
                SummaryChip(title: UIStrings.providerObservabilitySuccesses, value: "\(successCount)", systemImage: "checkmark.circle")
                SummaryChip(title: UIStrings.providerObservabilityFailures, value: "\(failureCount)", systemImage: "xmark.octagon")
                SummaryChip(title: UIStrings.providerObservabilityBlocked, value: "\(blockedCount)", systemImage: "nosign")
                SummaryChip(title: UIStrings.providerObservabilityEstimatedTokens, value: "\(estimatedTotalTokens)", systemImage: "sum")
                SummaryChip(title: UIStrings.providerObservabilityEstimatedCost, value: costLabel(result.summary.estimatedCostUSD), systemImage: "dollarsign.circle")
                SummaryChip(title: UIStrings.providerObservabilityDuration, value: durationLabel(result.summary.totalDurationMS), systemImage: "timer")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.routingAccuracyGeneratedBy, value: result.generatedBy)
                MetadataRow(label: UIStrings.providerObservabilityAppLocalOnly, value: result.appLocalOnly ? UIStrings.llmEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                MetadataRow(label: UIStrings.providerObservabilityMetadataRedacted, value: result.metadataRedacted ? UIStrings.llmEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                MetadataRow(label: UIStrings.providerObservabilityAverageDuration, value: durationLabel(result.summary.averageDurationMS))
                if let windowDays = result.filters.windowDays {
                    MetadataRow(label: UIStrings.routingAccuracyWindow, value: "\(windowDays)d")
                }
                if let limit = result.filters.limit {
                    MetadataRow(label: UIStrings.text("filter.limit", "Limit"), value: "\(limit)")
                }
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

            ProviderObservabilityDimensionList(title: UIStrings.providerObservabilityProviders, rows: result.providerRows, systemImage: "person.crop.circle.badge.checkmark")
            ProviderObservabilityDimensionList(title: UIStrings.providerObservabilityModels, rows: result.modelRows, systemImage: "cpu")
            ProviderObservabilityDimensionList(title: UIStrings.providerObservabilityDestinations, rows: result.destinationRows, systemImage: "network")
            ProviderObservabilityCallList(rows: result.callRows)
            ProviderObservabilityIssueList(title: UIStrings.providerObservabilityStatusRows, rows: result.statusRows, systemImage: "list.bullet.rectangle")
            ProviderObservabilityIssueList(title: UIStrings.providerObservabilityErrorRows, rows: result.errorRows, systemImage: "exclamationmark.triangle")
            ProviderObservabilityHintList(title: UIStrings.providerObservabilityBudgetHints, rows: result.budgetHints, systemImage: "gauge.with.dots.needle.67percent")
            ProviderObservabilityHintList(title: UIStrings.providerObservabilityUsageHints, rows: result.usageHints, systemImage: "chart.bar.xaxis")
            ProviderObservabilityHintList(title: UIStrings.providerObservabilityRetention, rows: result.retentionRows + result.cleanupRecommendationRows, systemImage: "archivebox")
            RoutingInlineList(title: UIStrings.knowledgeGapNotes, empty: UIStrings.routingAccuracyNoGaps, values: result.gapNotes, systemImage: "puzzlepiece.extension")
            RoutingInlineList(title: UIStrings.knowledgeBlockerNotes, empty: UIStrings.routingAccuracyNoBlockers, values: result.blockerNotes, systemImage: "exclamationmark.octagon")
            ProviderObservabilityEvidenceList(evidence: result.evidenceReferences)
            ProviderObservabilitySafetyList(safety: result.safetyFlags)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
    }

    private var callCount: Int {
        result.summary.callCount > 0 ? result.summary.callCount : result.callRows.count
    }

    private var successCount: Int {
        result.summary.successCount > 0 ? result.summary.successCount : result.callRows.filter { !$0.statusIsProblem }.count
    }

    private var failureCount: Int {
        result.summary.failureCount > 0 ? result.summary.failureCount : result.callRows.filter(\.statusIsProblem).count
    }

    private var blockedCount: Int {
        result.summary.blockedCount
    }

    private var estimatedTotalTokens: Int {
        result.summary.estimatedTotalTokens > 0 ? result.summary.estimatedTotalTokens : result.callRows.reduce(0) { $0 + $1.totalTokens }
    }

    private func promptRequestLabel(_ promptRequest: ProviderObservabilityPromptRequest) -> String {
        let state = promptRequest.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled
        let copy = promptRequest.copyOnly ? UIStrings.llmPromptCopyOnly : UIStrings.llmSkillAnalysisEnabledUnsafe
        let redaction = promptRequest.redacted ? UIStrings.aiProviderAuditRedaction : UIStrings.llmSkillAnalysisEnabledUnsafe
        return "\(promptRequest.requestKind) · \(state) · \(copy) · \(redaction)"
    }
}

struct ProviderObservabilityDimensionList: View {
    let title: String
    let rows: [ProviderObservabilityDimensionRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(rows.prefix(6)) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(row.label, systemImage: systemImage)
                                    .font(.callout.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(row.status)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                                MetadataRow(label: UIStrings.providerObservabilityCalls, value: "\(row.callCount)")
                                MetadataRow(label: UIStrings.providerObservabilitySuccesses, value: "\(row.successCount)")
                                MetadataRow(label: UIStrings.providerObservabilityFailures, value: "\(row.failureCount)")
                                MetadataRow(label: UIStrings.providerObservabilityBlocked, value: "\(row.blockedCount)")
                                MetadataRow(label: UIStrings.providerObservabilityEstimatedTokens, value: "\(row.estimatedTokens)")
                                MetadataRow(label: UIStrings.providerObservabilityEstimatedCost, value: costLabel(row.estimatedCostUSD))
                                MetadataRow(label: UIStrings.providerObservabilityAverageDuration, value: durationLabel(row.averageDurationMS))
                            }
                            RoutingInlineList(title: UIStrings.providerObservabilityNotes, empty: UIStrings.providerObservabilityNoRows, values: row.notes, systemImage: "info.circle")
                            RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

struct ProviderObservabilityCallList: View {
    let rows: [ProviderObservabilityCallRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.providerObservabilityRecentCalls)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoCalls)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(callTitle(row), systemImage: row.statusIsProblem ? "exclamationmark.triangle" : "checkmark.circle")
                                .font(.callout.bold())
                                .foregroundStyle(row.statusIsProblem ? .orange : .primary)
                            Spacer()
                            Text(row.status)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                            MetadataRow(label: UIStrings.llmProvider, value: row.provider)
                            MetadataRow(label: UIStrings.llmModel, value: row.model)
                            MetadataRow(label: UIStrings.llmPromptDestination, value: row.destinationHost)
                            MetadataRow(label: UIStrings.providerObservabilityDuration, value: durationLabel(row.durationMS))
                            MetadataRow(label: UIStrings.providerObservabilityEstimatedTokens, value: UIStrings.llmTokenSummary(input: row.inputTokens, output: row.outputTokens, total: row.totalTokens))
                            MetadataRow(label: UIStrings.providerObservabilityEstimatedCost, value: costLabel(row.estimatedCostUSD))
                            MetadataRow(label: UIStrings.llmPromptCopyOnly, value: row.copyOnly ? UIStrings.llmEnabled : UIStrings.llmSkillAnalysisEnabledUnsafe)
                            MetadataRow(label: UIStrings.skillQualityProviderNotSent, value: row.providerRequestSent ? UIStrings.llmSkillAnalysisEnabledUnsafe : UIStrings.llmDisabled)
                        }
                        if let error = errorText(row), !error.isEmpty {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .textSelection(.enabled)
                        }
                        if !row.detail.isEmpty {
                            PrivacyEvidenceText(value: row.detail, font: .caption, lineLimit: nil)
                        }
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

    private func callTitle(_ row: ProviderObservabilityCallRow) -> String {
        let action = row.requestKind == UIStrings.unknown ? row.action : row.requestKind
        return action.isEmpty ? row.id : action
    }

    private func errorText(_ row: ProviderObservabilityCallRow) -> String? {
        if let code = row.errorCode, let message = row.errorMessage, !message.isEmpty {
            return "\(code): \(message)"
        }
        return row.errorMessage ?? row.errorCode
    }
}

struct ProviderObservabilityIssueList: View {
    let title: String
    let rows: [ProviderObservabilityIssueRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(row.title, systemImage: systemImage)
                                .font(.callout.bold())
                            Spacer()
                            Text(row.severity)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                            MetadataRow(label: UIStrings.aiProviderTestResult, value: row.status)
                            MetadataRow(label: UIStrings.providerObservabilityCalls, value: "\(row.count)")
                            if let provider = row.provider, !provider.isEmpty {
                                MetadataRow(label: UIStrings.llmProvider, value: provider)
                            }
                            if let model = row.model, !model.isEmpty {
                                MetadataRow(label: UIStrings.llmModel, value: model)
                            }
                            if let destinationHost = row.destinationHost, !destinationHost.isEmpty {
                                MetadataRow(label: UIStrings.llmPromptDestination, value: destinationHost)
                            }
                        }
                        if !row.detail.isEmpty {
                            PrivacyEvidenceText(value: row.detail, font: .caption, lineLimit: nil)
                        }
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct ProviderObservabilityHintList: View {
    let title: String
    let rows: [ProviderObservabilityHintRow]
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(UIStrings.providerObservabilityNoRows)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(row.title, systemImage: systemImage)
                                .font(.callout.bold())
                            Spacer()
                            Text(row.severity)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                            if let value = row.value, !value.isEmpty {
                                MetadataRow(label: UIStrings.text("value", "Value"), value: value)
                            }
                            if let threshold = row.threshold, !threshold.isEmpty {
                                MetadataRow(label: UIStrings.providerObservabilityThreshold, value: threshold)
                            }
                        }
                        if !row.detail.isEmpty {
                            PrivacyEvidenceText(value: row.detail, font: .caption, lineLimit: nil)
                        }
                        if let recommendation = row.recommendation, !recommendation.isEmpty {
                            Label(recommendation, systemImage: "arrow.right.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        RoutingInlineList(title: UIStrings.crossAgentReadinessEvidence, empty: UIStrings.crossAgentReadinessNoEvidence, values: row.evidenceRefs, systemImage: "checklist")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct ProviderObservabilityEvidenceList: View {
    let evidence: [ProviderObservabilityEvidenceReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.crossAgentReadinessEvidence)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if evidence.isEmpty {
                Text(UIStrings.crossAgentReadinessNoEvidence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evidence.prefix(8)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(item.title, systemImage: "checklist")
                            .font(.callout)
                        PrivacyEvidenceText(value: item.detail, font: .caption, lineLimit: nil)
                        HStack(spacing: 8) {
                            if let source = item.source, !source.isEmpty {
                                PrivacyEvidenceText(value: source, font: .caption2, lineLimit: 1)
                            }
                            if let agent = item.agent, !agent.isEmpty {
                                Text(DisplayText.agent(agent))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct ProviderObservabilitySafetyList: View {
    let safety: ProviderObservabilitySafety

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.knowledgeSafetyFlags)
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

func durationLabel(_ durationMS: Int?) -> String {
    guard let durationMS, durationMS > 0 else { return UIStrings.unknown }
    if durationMS >= 1_000 {
        let seconds = Double(durationMS) / 1_000.0
        return "\(seconds.formatted(.number.precision(.fractionLength(1))))s"
    }
    return "\(durationMS) ms"
}

func costLabel(_ cost: Double?) -> String {
    guard let cost else { return UIStrings.unknown }
    return UIStrings.llmEstimatedCost(cost)
}
