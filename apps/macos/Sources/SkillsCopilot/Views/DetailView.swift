import SwiftUI

enum DetailSection: String, CaseIterable, Identifiable {
    case overview
    case findings
    case conflicts
    case history
    case analysis

    var id: String { rawValue }

    static var visibleCases: [DetailSection] {
        Self.allCases
    }

    var title: String {
        switch self {
        case .overview:
            return UIStrings.overview
        case .findings:
            return UIStrings.findings
        case .conflicts:
            return UIStrings.conflicts
        case .history:
            return UIStrings.text("detail.history", "History")
        case .analysis:
            return UIStrings.text("detail.analysis", "Analysis")
        }
    }
}

struct DetailView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let skill: SkillRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let error = store.errorMessage {
                    ErrorBanner(message: error)
                }

                if let message = store.lastMutationMessage {
                    SuccessBanner(message: message)
                }

                if let skill {
                    let selectedFindingGroups = FindingDisplayModel.issueGroups(
                        findings: store.selectedFindings,
                        severityFilter: FindingDisplayModel.allFilterValue,
                        ruleFilter: FindingDisplayModel.allFilterValue
                    )
                    HeaderView(
                        skill: skill,
                        detail: store.selectedSkillDetail,
                        findingCount: selectedFindingGroups.count,
                        conflictCount: store.selectedConflicts.count,
                        isWriting: store.isWriting,
                        llmStatus: store.llmStatus,
                        adapterCapability: store.adapterCapabilities.first { $0.agent == skill.agent },
                        onSelectSection: { section in
                            store.selectedDetailSection = section
                        },
                        onToggle: { on in
                            Task { await store.toggleSelectedSkill(on: on) }
                        }
                    )

                    DetailSectionSwitcher(selection: $store.selectedDetailSection)

                    switch store.selectedDetailSection {
                    case .overview:
                        VStack(alignment: .leading, spacing: 16) {
                            SkillSummaryCard(
                                skill: skill,
                                detail: store.selectedSkillDetail,
                                scriptPreview: store.scriptExecutionPreview(for: skill),
                                isLoading: store.isLoadingDetail
                            )

                            DisclosureGroup {
                                SkillDetailCard(
                                    skill: skill,
                                    detail: store.selectedSkillDetail,
                                    isLoading: store.isLoadingDetail
                                )
                                .padding(.top, 12)
                            } label: {
                                Label(UIStrings.text("detail.rawDetails", "Raw Catalog Details"), systemImage: "doc.text.magnifyingglass")
                                    .font(.headline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .adaptiveMaterialSurface()

                            if DisplayText.isToolGlobal(skill) {
                                ToolGlobalPreviewCard(skill: skill)
                            }
                        }
                    case .findings:
                        FindingsSection(skill: skill, findings: store.selectedFindings)
                    case .conflicts:
                        ConflictsSection(
                            conflicts: store.selectedConflicts,
                            selectedSkillID: skill.id,
                            currentAgentSkillIDs: Set(store.skills.filter { $0.agent == skill.agent }.map(\.id))
                        )
                    case .history:
                        HistorySection(
                            events: store.selectedSkillEvents,
                            isLoading: store.isLoadingSelectedSkillEvents
                        )
                    case .analysis:
                        AnalysisSection(
                            skill: skill,
                            llmStatus: store.llmStatus,
                            isPreparing: { action in store.isPreparingLLMAction(action) },
                            result: { action in store.llmPrepareResult(for: action) },
                            onPrepare: { action in
                                Task {
                                    switch action {
                                    case .analyze:
                                        await store.prepareAnalyzeLLM()
                                    case .recommend:
                                        await store.prepareRecommendLLM()
                                    case .explainConflict:
                                        await store.prepareExplainConflictLLM()
                                    case .draftFrontmatter:
                                        await store.prepareDraftFrontmatterLLM()
                                    }
                                }
                            },
                            scriptPreview: store.scriptExecutionPreview(for: skill),
                            isPreviewingScript: store.isPreviewingScriptExecution(for: skill),
                            onPreviewScript: {
                                Task {
                                    await store.previewScriptExecutionSafety(for: skill)
                                }
                            }
                        )
                    }
                } else {
                    EmptyDetailView()
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(skill?.name ?? UIStrings.appTitle)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }
}

private struct SkillSummaryCard: View {
    let skill: SkillRecord
    let detail: SkillDetailRecord?
    let scriptPreview: ScriptExecutionPreview?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.text("detail.diagnosticOverview", "Diagnostic Overview"), systemImage: "stethoscope")
                    .font(.headline)
                Spacer()
                if isLoading {
                    Label(UIStrings.loadingSkillDetail, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(summaryText)
                .font(.callout)
                .foregroundStyle(summaryText == UIStrings.noDescription ? .secondary : .primary)
                .lineLimit(nil)
                .textSelection(.enabled)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.source, value: skill.displayPath, systemImage: "doc")
                SummaryChip(title: UIStrings.scope, value: DisplayText.scope(skill.scope), systemImage: "folder")
                SummaryChip(title: UIStrings.state, value: DisplayText.state(skill.state, enabled: skill.enabled), systemImage: DisplayText.stateSystemImage(skill.state, enabled: skill.enabled))
                SummaryChip(title: UIStrings.text("detail.enabled", "Enabled"), value: skill.enabled ? UIStrings.stateEnabled : UIStrings.stateDisabled, systemImage: skill.enabled ? "checkmark.circle" : "pause.circle")
            }

            OverviewRiskPanel(
                permissionSummary: PermissionDisplayModel.summary(for: detail?.permissions ?? .null),
                scriptPreview: scriptPreview
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var summaryText: String {
        guard let description = detail?.description.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty else {
            return UIStrings.noDescription
        }
        return description
    }
}

private struct OverviewRiskPanel: View {
    let permissionSummary: PermissionSummary
    let scriptPreview: ScriptExecutionPreview?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.text("detail.permissionScriptRisk", "Permissions & script risk"), systemImage: "shield.lefthalf.filled")
                    .font(.subheadline.bold())
                Spacer()
                Label(scriptState, systemImage: scriptPreview == nil ? "nosign" : "checkmark.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(permissionSummary.rows.prefix(5)) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(row.value)
                            .font(.caption.bold())
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Text(permissionSummary.note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    private var scriptState: String {
        if let preview = scriptPreview {
            return preview.executionAllowed ? UIStrings.executionBlocked : UIStrings.scriptExecutionPreviewOnly
        }
        return UIStrings.scriptExecutionPreviewOnly
    }
}

private struct DetailSectionSwitcher: View {
    @Binding var selection: DetailSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UIStrings.detailSection)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Picker(UIStrings.detailSection, selection: $selection) {
                ForEach(DetailSection.visibleCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SummaryChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AnalysisSection: View {
    let skill: SkillRecord
    let llmStatus: LLMStatus
    let isPreparing: (LLMAction) -> Bool
    let result: (LLMAction) -> LLMPrepareResult?
    let onPrepare: (LLMAction) -> Void
    let scriptPreview: ScriptExecutionPreview?
    let isPreviewingScript: Bool
    let onPreviewScript: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label(UIStrings.text("analysis.workbench", "Read-only analysis workbench"), systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                Text(UIStrings.text("analysis.workbench.summary", "Use offline/AI-assisted review to understand purpose, risk, findings, and cross-agent duplicate/source-overlap signals. This panel does not write config, modify skills, or execute scripts."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label(UIStrings.text("analysis.crossAgentNote", "Cross-agent duplicates and source overlap live here as analysis insights; same-agent runtime/name collisions remain in Conflicts."), systemImage: "rectangle.3.group.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            LLMAssistPanel(
                status: llmStatus,
                isPreparing: isPreparing,
                result: result,
                onPrepare: onPrepare
            )

            ScriptExecutionSafetyCard(
                skill: skill,
                preview: scriptPreview,
                isPreviewing: isPreviewingScript,
                onPreview: onPreviewScript
            )
        }
    }

}

private struct LLMAssistPanel: View {
    let status: LLMStatus
    let isPreparing: (LLMAction) -> Bool
    let result: (LLMAction) -> LLMPrepareResult?
    let onPrepare: (LLMAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.llmAssist, systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Label(
                    status.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled,
                    systemImage: status.enabled ? "checkmark.circle" : "nosign"
                )
                .font(.caption.bold())
                .foregroundStyle(status.enabled ? .green : .secondary)
            }

            if let disabledReason = status.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if status.enabled {
                Text(UIStrings.llmPreparePrompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(LLMAction.allCases) { action in
                    Button {
                        onPrepare(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .disabled(isPreparing(action))
                    .help(status.enabled ? action.title : UIStrings.llmReviewNoActions)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(LLMAction.allCases) { action in
                    if isPreparing(action) {
                        Label(UIStrings.llmPreparing, systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    } else if let result = result(action) {
                        LLMPrepareResultView(result: result)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct LLMPrepareResultView: View {
    let result: LLMPrepareResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(result.action.title, systemImage: result.enabled ? "checkmark.circle" : "nosign")
                .font(.subheadline.bold())
                .foregroundStyle(result.enabled ? .primary : .secondary)

            if let disabledReason = result.disabledReason, !disabledReason.isEmpty {
                Text(disabledReason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                if let provider = result.provider, !provider.isEmpty {
                    MetadataRow(label: UIStrings.llmProvider, value: provider)
                }
                if let model = result.model, !model.isEmpty {
                    MetadataRow(label: UIStrings.llmModel, value: model)
                }
                if let estimate = result.estimate {
                    MetadataRow(
                        label: UIStrings.llmTokens,
                        value: UIStrings.llmTokenSummary(
                            input: estimate.inputTokens,
                            output: estimate.outputTokens,
                            total: estimate.totalTokens
                        )
                    )
                    if let cost = estimate.estimatedCostUSD {
                        MetadataRow(label: UIStrings.llmCost, value: UIStrings.llmEstimatedCost(cost))
                    }
                }
            }

            if let reviewPreview = result.reviewPreview {
                LLMReviewPreviewView(preview: reviewPreview)
            }

            if result.confirmationRequired {
                Label(UIStrings.llmConfirmationRequired, systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if result.action == .draftFrontmatter {
                Label(UIStrings.llmDraftCopyRequired, systemImage: "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct LLMReviewPreviewView: View {
    let preview: LLMReviewPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.llmReviewPreview, systemImage: "eye")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            MetadataRow(label: UIStrings.llmReviewPurpose, value: preview.purpose)
            MetadataRow(label: UIStrings.llmReviewRisk, value: "\(preview.risk.level): \(preview.risk.summary)")
            MetadataRow(label: UIStrings.llmReviewCrossAgentFit, value: preview.crossAgentFit.summary)
            MetadataRow(label: UIStrings.llmReviewRedaction, value: redactionSummary)

            VStack(alignment: .leading, spacing: 5) {
                Text(UIStrings.llmReviewSignals)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.risk.signals.isEmpty {
                    Text(UIStrings.llmReviewNoSignals)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.risk.signals, id: \.self) { signal in
                        Label(signal, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(UIStrings.llmReviewFindings)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.findingExplanations.isEmpty {
                    Text(UIStrings.llmReviewNoFindings)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.findingExplanations) { finding in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(finding.severity) · \(finding.ruleID)")
                                .font(.callout.bold())
                            Text(finding.explanation)
                                .foregroundStyle(.secondary)
                            if let nextStep = finding.suggestedNextStep, !nextStep.isEmpty {
                                Text(nextStep)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Label(UIStrings.llmReviewNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var redactionSummary: String {
        "body=\(preview.redaction.skillBodyReturned ? "returned" : "hidden"), paths=\(preview.redaction.pathsReturned ? "returned" : "hidden"), credentials=\(preview.redaction.credentialsReturned ? "returned" : "hidden")"
    }
}

private extension LLMAction {
    var title: String {
        switch self {
        case .analyze:
            return UIStrings.llmAnalyze
        case .recommend:
            return UIStrings.llmRecommend
        case .explainConflict:
            return UIStrings.llmExplainConflict
        case .draftFrontmatter:
            return UIStrings.llmDraftFrontmatter
        }
    }

    var systemImage: String {
        switch self {
        case .analyze:
            return "text.magnifyingglass"
        case .recommend:
            return "wand.and.stars"
        case .explainConflict:
            return "exclamationmark.bubble"
        case .draftFrontmatter:
            return "doc.badge.plus"
        }
    }
}

private struct ScriptExecutionSafetyCard: View {
    let skill: SkillRecord
    let preview: ScriptExecutionPreview?
    let isPreviewing: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.scriptExecutionSafety, systemImage: "lock.shield")
                    .font(.headline)
                Spacer()
                Label(UIStrings.scriptExecutionPreviewOnly, systemImage: "eye")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(preview?.summary ?? UIStrings.scriptExecutionPreviewSummary)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    onPreview()
                } label: {
                    Label(UIStrings.previewGate, systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isPreviewing)
                .help(UIStrings.scriptExecutionBlockedNote)

                Button {
                } label: {
                    Label(UIStrings.executionBlocked, systemImage: "nosign")
                }
                .disabled(true)
                .help(UIStrings.scriptExecutionBlockedNote)
            }

            if isPreviewing {
                Label(UIStrings.loading, systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }

            if let preview {
                ScriptExecutionPreviewView(preview: preview)
            } else {
                Label(UIStrings.scriptExecutionBlockedNote, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct ScriptExecutionPreviewView: View {
    let preview: ScriptExecutionPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(statusTitle, systemImage: statusImage)
                .font(.subheadline.bold())
                .foregroundStyle(preview.executionAllowed ? .orange : .secondary)

            if let reason = preview.disabledReason, !reason.isEmpty {
                Text(reason)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                MetadataRow(label: UIStrings.scriptExecutionAuditStatus, value: UIStrings.scriptExecutionAuditStatusTitle(preview.auditStatus))
                MetadataRow(label: UIStrings.scriptExecutionAuditID, value: preview.auditID?.nonEmpty ?? UIStrings.scriptExecutionNoAudit)
                MetadataRow(label: UIStrings.scriptExecutionCWD, value: preview.scope.cwd?.nonEmpty ?? UIStrings.permissionUndeclared)
                MetadataRow(label: UIStrings.scriptExecutionNetwork, value: preview.scope.network?.nonEmpty ?? UIStrings.permissionUndeclared)
                MetadataRow(label: UIStrings.scriptExecutionEnv, value: formattedEnv)
                MetadataRow(label: UIStrings.scriptExecutionFiles, value: formattedFiles)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(UIStrings.scriptExecutionCommand, systemImage: "terminal")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(commandPreview)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(UIStrings.scriptExecutionRisks, systemImage: "exclamationmark.triangle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if preview.risks.isEmpty {
                    Text(UIStrings.scriptExecutionNoRisks)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.risks, id: \.self) { risk in
                        Label(risk, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if preview.confirmationRequired {
                Label(UIStrings.scriptExecutionConfirmationRequired, systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(UIStrings.scriptExecutionBlockedNote, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var statusTitle: String {
        preview.executionAllowed ? UIStrings.executionBlocked : UIStrings.scriptExecutionPreviewOnly
    }

    private var statusImage: String {
        preview.executionAllowed ? "exclamationmark.triangle" : "nosign"
    }

    private var commandPreview: String {
        let command = preview.commandPreview
            .map { part in part.replacingOccurrences(of: "\n", with: "\\n") }
            .joined(separator: " ")
        return command.isEmpty ? UIStrings.scriptExecutionNoCommand : command
    }

    private var formattedEnv: String {
        guard !preview.scope.env.isEmpty else {
            return UIStrings.scriptExecutionEnvEmpty
        }
        return preview.scope.env.keys.sorted().map { key in
            "\(key)=\(preview.scope.env[key] ?? "")"
        }.joined(separator: ", ")
    }

    private var formattedFiles: String {
        preview.scope.files.isEmpty ? UIStrings.scriptExecutionFilesEmpty : preview.scope.files.joined(separator: ", ")
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension JSONValue {
    func boolValue(forAnyKey keys: [String]) -> Bool? {
        guard case .object(let object) = self else { return nil }
        for key in keys {
            if let payloadValue = object[key], case .bool(let value) = payloadValue {
                return value
            }
        }
        return nil
    }

    var compactDisplayString: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let object):
            return object.keys.sorted().map { key in
                "\(key)=\(object[key]?.compactDisplayString ?? "")"
            }.joined(separator: ", ")
        case .array(let values):
            return values.map(\.compactDisplayString).joined(separator: ", ")
        case .null:
            return ""
        }
    }
}

private struct HeaderView: View {
    let skill: SkillRecord
    let detail: SkillDetailRecord?
    let findingCount: Int
    let conflictCount: Int
    let isWriting: Bool
    let llmStatus: LLMStatus
    let adapterCapability: AdapterCapabilityRecord?
    let onSelectSection: (DetailSection) -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        let disabledReason = toggleDisabledReason
        let isEffectivelyEnabled = DisplayText.statusKind(skill.state, enabled: skill.enabled) == .enabled

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(skill.name)
                        .font(.largeTitle.bold())
                    Text(skill.definitionId)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Label(
                        DisplayText.isToolGlobal(skill) ? UIStrings.readOnlyPreview : DisplayText.state(skill.state, enabled: skill.enabled),
                        systemImage: DisplayText.isToolGlobal(skill) ? "eye" : DisplayText.stateSystemImage(skill.state, enabled: skill.enabled)
                    )
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(DisplayText.isToolGlobal(skill) ? .secondary : DisplayText.stateColor(skill.state, enabled: skill.enabled))

                    if DisplayText.isReadOnlyPreview(skill) {
                        Label(DisplayText.isToolGlobal(skill) ? UIStrings.readOnlyPreview : UIStrings.readOnly, systemImage: "lock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .help(disabledReason ?? UIStrings.readOnly)
                    }

                    Button {
                        onToggle(!isEffectivelyEnabled)
                    } label: {
                    Label(
                        isEffectivelyEnabled ? UIStrings.disable : UIStrings.enable,
                        systemImage: isEffectivelyEnabled ? "pause.circle" : "play.circle"
                    )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(disabledReason != nil)
                    .help(disabledReason ?? "")
                    .accessibilityHint(disabledReason ?? "")
                }
            }

            if let disabledReason {
                Label(disabledReason, systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], alignment: .leading, spacing: 10) {
                SummaryChip(title: UIStrings.agent, value: DisplayText.agent(skill.agent), systemImage: "person.crop.circle")
                SummaryChip(title: UIStrings.scope, value: DisplayText.scope(skill.scope), systemImage: "folder")
                SummaryChip(title: UIStrings.state, value: DisplayText.state(skill.state, enabled: skill.enabled), systemImage: DisplayText.stateSystemImage(skill.state, enabled: skill.enabled))
                CountBadge(
                    label: UIStrings.text("detail.issueGroups", "Issue groups"),
                    value: findingCount,
                    systemImage: "exclamationmark.triangle",
                    tint: .orange,
                    action: { onSelectSection(.findings) }
                )
                CountBadge(
                    label: UIStrings.text("detail.sameAgentConflicts", "Same-agent conflicts"),
                    value: conflictCount,
                    systemImage: "rectangle.2.swap",
                    tint: .red,
                    action: { onSelectSection(.conflicts) }
                )
                SummaryChip(title: UIStrings.text("detail.riskAnalysis", "Risk / analysis"), value: riskAnalysisStatus, systemImage: riskAnalysisImage)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var toggleDisabledReason: String? {
        let catalogReason = DisplayText.toggleDisabledReason(for: skill, isWriting: isWriting)
        guard !isWriting, let adapterCapability, !adapterCapability.configToggle.supported else {
            return catalogReason
        }
        return adapterCapability.configToggle.reason ?? catalogReason ?? UIStrings.readOnlyAdapterStatus(adapterCapability.displayName)
    }

    private var riskAnalysisStatus: String {
        if findingCount > 0 || conflictCount > 0 {
            return UIStrings.text("detail.reviewQueued", "Review queued")
        }
        if permissionRiskCount > 0 {
            return UIStrings.text("detail.riskDeclared", "Risk declared")
        }
        return llmStatus.enabled ? UIStrings.text("detail.aiReady", "AI ready") : UIStrings.text("detail.offlineReady", "Offline ready")
    }

    private var riskAnalysisImage: String {
        if findingCount > 0 || conflictCount > 0 || permissionRiskCount > 0 {
            return "exclamationmark.triangle"
        }
        return llmStatus.enabled ? "sparkles" : "checkmark.seal"
    }

    private var permissionRiskCount: Int {
        guard let detail, case .object(let object) = detail.permissions else {
            return 0
        }
        var count = 0
        if case .bool(true)? = object["exec"] {
            count += 1
        }
        if case .string(let network)? = object["network"], network == "full" {
            count += 1
        }
        return count
    }
}

private struct RecentActivityCard: View {
    let events: [SkillEventRecord]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.recentActivity, systemImage: "clock.badge")
                    .font(.headline)
                Spacer()
                if isLoading {
                    Label(UIStrings.loadingRecentActivity, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if events.isEmpty {
                Text(isLoading ? UIStrings.loadingRecentActivity : UIStrings.noRecentActivity)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { event in
                        SkillActivityRow(event: event)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct HistorySection: View {
    let events: [SkillEventRecord]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label(UIStrings.text("history.activity", "Configuration activity"), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Text(UIStrings.text("history.activity.summary", "History shows lightweight enable, disable, and config-action events that the service already records. Skill-content snapshots are intentionally not shown here."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            RecentActivityCard(events: events, isLoading: isLoading)
        }
    }
}

private struct SkillActivityRow: View {
    let event: SkillEventRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "switch.2")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(activityTitle)
                    .font(.subheadline.bold())
                Text(DisplayText.timestamp(event.occurredAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let payloadSummary {
                    Text(payloadSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var activityTitle: String {
        if let enabled = event.payload.boolValue(forAnyKey: ["on", "enabled"]) {
            return UIStrings.activityToggleState(enabled: enabled)
        }
        return event.kind
    }

    private var payloadSummary: String? {
        let summary = event.payload.compactDisplayString
        return summary.isEmpty ? nil : "\(UIStrings.activityPayload): \(summary)"
    }
}

private struct CountBadge: View {
    let label: String
    let value: Int
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(value > 0 ? tint : .secondary)
                Text("\(value)")
                    .font(.headline)
                    .foregroundStyle(value > 0 ? .primary : .secondary)
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .adaptiveMaterialSurface()
        }
        .buttonStyle(.plain)
        .help(UIStrings.text("detail.countBadge.help", "Show \(label)"))
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(UIStrings.noSkillSelected)
                .font(.title2.bold())
            Text(UIStrings.noSkillSelectedMessage)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SkillDetailCard: View {
    let skill: SkillRecord
    let detail: SkillDetailRecord?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                MetadataRow(label: UIStrings.definition, value: skill.definitionId)
                MetadataRow(label: UIStrings.catalogID, value: skill.id)
                MetadataRow(label: UIStrings.source, value: skill.displayPath)
                if DisplayText.isToolGlobal(skill) {
                    MetadataRow(label: UIStrings.access, value: UIStrings.toolGlobalAccessStatus(DisplayText.agent(skill.agent)))
                }
                if DisplayText.isReadOnlyAdapter(skill.agent) {
                    MetadataRow(label: UIStrings.access, value: UIStrings.readOnlyAdapterStatus(DisplayText.agent(skill.agent)))
                }
                if let detail {
                    MetadataRow(label: UIStrings.fingerprint, value: detail.fingerprint)
                    MetadataRow(label: UIStrings.description, value: detail.description.isEmpty ? UIStrings.noDescription : detail.description)
                }
            }

            if isLoading {
                ProgressView(UIStrings.loadingSkillDetail)
            }

            if let detail {
                PermissionSummaryCard(summary: PermissionDisplayModel.summary(for: detail.permissions))

                if !detail.frontmatterRaw.isEmpty {
                    TextBlock(title: UIStrings.frontmatter, content: detail.frontmatterRaw)
                }
                if !detail.body.isEmpty {
                    TextBlock(title: UIStrings.body, content: detail.body)
                }
            }

            Text(UIStrings.connectedProtocolNote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveMaterialSurface()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToolGlobalPreviewCard: View {
    @EnvironmentObject private var store: SkillStore
    let skill: SkillRecord
    @State private var target: ToolInstallTarget = .claudeCode
    @State private var preview: ToolGlobalInstallPreview?
    @State private var isPreviewing = false
    @State private var isConfirming = false

    var body: some View {
        let targets = ToolInstallTarget.supportedTargets(from: store.adapterCapabilities)
        let selectedTarget = targets.contains(target) ? target : (targets.first ?? target)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.toolGlobalPreviewTitle, systemImage: "shippingbox")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.toolGlobalPreviewNote)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Picker(UIStrings.toolGlobalTargetAgent, selection: $target) {
                    ForEach(targets) { target in
                        Text(target.title).tag(target)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Button {
                    Task {
                        isPreviewing = true
                        defer { isPreviewing = false }
                        preview = await store.previewToolInstall(skill: skill, target: selectedTarget)
                    }
                } label: {
                    Label(UIStrings.installToAgent, systemImage: "square.and.arrow.down")
                }
                .disabled(store.isRefreshBusy || isPreviewing || targets.isEmpty)
                .help(UIStrings.toolGlobalInstallConfirmation(skill.name, selectedTarget.title))
            }
        }
        .onAppear {
            if let first = targets.first, !targets.contains(target) {
                target = first
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
        .sheet(item: $preview) { preview in
            ToolGlobalInstallPreviewSheet(
                preview: preview,
                isConfirming: isConfirming,
                onConfirm: {
                    Task {
                        isConfirming = true
                        defer { isConfirming = false }
                        if let result = await store.confirmToolInstall(skill: skill, target: preview.target) {
                            self.preview = result
                        }
                    }
                }
            )
        }
    }
}

private struct ToolGlobalInstallPreviewSheet: View {
    let preview: ToolGlobalInstallPreview
    let isConfirming: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.toolGlobalInstallPreviewTitle)
                        .font(.title2.bold())
                    Text(preview.summary)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(UIStrings.done) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                MetadataRow(label: UIStrings.source, value: preview.sourcePath)
                MetadataRow(label: UIStrings.toolGlobalTargetAgent, value: preview.target.title)
                if let targetPath = preview.targetPath {
                    MetadataRow(label: UIStrings.target, value: targetPath)
                }
            }

            Label(preview.confirmationMessage, systemImage: "checkmark.shield")
                .foregroundStyle(.secondary)

            if !preview.risks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(preview.risks, id: \.self) { risk in
                        Label(risk, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Label(UIStrings.toolGlobalInstallReady, systemImage: "checkmark.shield")
                .foregroundStyle(preview.wrote ? .green : .secondary)

            HStack {
                Spacer()
                Button(UIStrings.cancel) {
                    dismiss()
                }
                Button(preview.wrote ? UIStrings.done : UIStrings.confirmInstall) {
                    if preview.wrote {
                        dismiss()
                    } else {
                        onConfirm()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .disabled((!preview.writeBackEnabled && !preview.wrote) || isConfirming)
                    .help(UIStrings.toolGlobalInstallReady)
            }
        }
        .padding(24)
        .frame(width: 720, height: 420)
    }
}

struct FindingSeverityGroup: Identifiable, Equatable {
    let severityKey: String
    let issues: [FindingIssueGroup]

    var id: String { severityKey }

    var title: String {
        FindingDisplayModel.severityTitle(severityKey)
    }
}

struct FindingIssueGroup: Identifiable, Equatable {
    let severityKey: String
    let ruleId: String
    let message: String
    let remediation: String
    let findings: [RuleFindingRecord]

    var id: String {
        [severityKey, ruleId, message, remediation].joined(separator: "\u{1F}")
    }

    var representative: RuleFindingRecord {
        findings[0]
    }

    var impactedInstanceCount: Int {
        let ids = Set(findings.compactMap(\.instanceId))
        return max(ids.count, findings.isEmpty ? 0 : 1)
    }

    var entryCount: Int {
        findings.count
    }
}

private struct FindingIssueKey: Hashable {
    let severityKey: String
    let ruleId: String
    let message: String
    let remediation: String
}

enum FindingDisplayModel {
    static let allFilterValue = "__all__"

    static func severityOptions(for findings: [RuleFindingRecord]) -> [String] {
        sortedSeverities(Set(findings.map { severityKey($0.severity) }))
    }

    static func ruleIDOptions(for findings: [RuleFindingRecord]) -> [String] {
        Array(Set(findings.map(\.ruleId)))
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
    }

    static func filtered(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [RuleFindingRecord] {
        findings.filter { finding in
            let matchesSeverity = severityFilter == allFilterValue || severityKey(finding.severity) == severityFilter
            let matchesRule = ruleFilter == allFilterValue || finding.ruleId == ruleFilter
            return matchesSeverity && matchesRule
        }
    }

    static func grouped(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [FindingSeverityGroup] {
        let visibleIssues = issueGroups(
            findings: findings,
            severityFilter: severityFilter,
            ruleFilter: ruleFilter
        )
        let grouped = Dictionary(grouping: visibleIssues, by: \.severityKey)

        return sortedSeverities(Set(grouped.keys)).map { severityKey in
            FindingSeverityGroup(
                severityKey: severityKey,
                issues: grouped[severityKey] ?? []
            )
        }
    }

    static func issueGroups(
        findings: [RuleFindingRecord],
        severityFilter: String,
        ruleFilter: String
    ) -> [FindingIssueGroup] {
        let visibleFindings = filtered(findings: findings, severityFilter: severityFilter, ruleFilter: ruleFilter)
        let grouped = Dictionary(grouping: visibleFindings) { finding in
            FindingIssueKey(
                severityKey: severityKey(finding.severity),
                ruleId: normalizedText(finding.ruleId),
                message: normalizedText(finding.message),
                remediation: normalizedText(remediationText(for: finding))
            )
        }
        return grouped.map { key, findings in
            FindingIssueGroup(
                severityKey: key.severityKey,
                ruleId: key.ruleId,
                message: key.message,
                remediation: key.remediation,
                findings: sortedFindings(findings)
            )
        }
        .sorted(by: compareIssueGroups)
    }

    static func remediationText(for finding: RuleFindingRecord) -> String {
        if let suggestion = finding.suggestion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !suggestion.isEmpty {
            return suggestion
        }

        switch finding.ruleId {
        case "frontmatter.required-fields":
            return UIStrings.remediationFrontmatterRequired
        case "frontmatter.tools-not-empty":
            return UIStrings.remediationToolsNotEmpty
        case "path.exists":
            return UIStrings.remediationPathExists
        case "fingerprint.changed":
            return UIStrings.remediationFingerprintChanged
        case "permissions.network-declared":
            return UIStrings.remediationNetworkDeclared
        case "permissions.exec-needs-human":
            return UIStrings.remediationExecNeedsHuman
        case "dependency.unknown":
            return UIStrings.remediationDependencyUnknown
        default:
            return UIStrings.findingRemediationFallback(finding.ruleId)
        }
    }

    static func severityTitle(_ severityKey: String) -> String {
        if severityKey == "unknown" {
            return UIStrings.unknown.uppercased()
        }
        return severityKey.uppercased()
    }

    static func severityKey(_ severity: String) -> String {
        let normalized = severity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? "unknown" : normalized
    }

    private static func sortedSeverities(_ severities: Set<String>) -> [String] {
        severities.sorted { lhs, rhs in
            let lhsRank = severityRank(lhs)
            let rhsRank = severityRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private static func sortedFindings(_ findings: [RuleFindingRecord]) -> [RuleFindingRecord] {
        findings.sorted { lhs, rhs in
            if lhs.ruleId != rhs.ruleId {
                return lhs.ruleId.localizedStandardCompare(rhs.ruleId) == .orderedAscending
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private static func compareIssueGroups(_ lhs: FindingIssueGroup, _ rhs: FindingIssueGroup) -> Bool {
        let lhsRank = severityRank(lhs.severityKey)
        let rhsRank = severityRank(rhs.severityKey)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        if lhs.ruleId != rhs.ruleId {
            return lhs.ruleId.localizedStandardCompare(rhs.ruleId) == .orderedAscending
        }
        let lhsCreatedAt = lhs.representative.createdAt
        let rhsCreatedAt = rhs.representative.createdAt
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt > rhsCreatedAt
        }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }

    private static func normalizedText(_ text: String) -> String {
        let collapsed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? UIStrings.emptyPlaceholder : collapsed
    }

    private static func severityRank(_ severityKey: String) -> Int {
        switch severityKey {
        case "critical":
            return 0
        case "error":
            return 1
        case "warning", "warn":
            return 2
        case "info", "notice":
            return 3
        default:
            return 10
        }
    }
}

struct PermissionSummaryRow: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String { label }
}

struct PermissionSummary: Equatable {
    let rows: [PermissionSummaryRow]
    let note: String
    let rawText: String
}

enum PermissionDisplayModel {
    static func summary(for permissions: JSONValue) -> PermissionSummary {
        let rawText = rawDescription(permissions)

        guard case .object(let object) = permissions, !object.isEmpty else {
            return PermissionSummary(
                rows: [
                    PermissionSummaryRow(label: UIStrings.permissions, value: UIStrings.permissionUndeclared)
                ],
                note: UIStrings.permissionUndeclaredNote,
                rawText: rawText
            )
        }

        return PermissionSummary(
            rows: [
                PermissionSummaryRow(label: UIStrings.permissionTools, value: stringArrayValue(object["tools"])),
                PermissionSummaryRow(label: UIStrings.permissionFiles, value: stringArrayValue(object["files"])),
                PermissionSummaryRow(label: UIStrings.permissionNetwork, value: networkValue(object["network"])),
                PermissionSummaryRow(label: UIStrings.permissionExec, value: boolValue(object["exec"], trueText: UIStrings.permissionRequested, falseText: UIStrings.permissionNotRequested)),
                PermissionSummaryRow(label: UIStrings.permissionHumanReview, value: boolValue(object["requires_human"], trueText: UIStrings.permissionRequired, falseText: UIStrings.permissionNotDeclaredRequired)),
            ],
            note: UIStrings.permissionDeclarationNote,
            rawText: rawText
        )
    }

    private static func stringArrayValue(_ value: JSONValue?) -> String {
        guard let value else {
            return UIStrings.permissionUndeclared
        }
        guard case .array(let items) = value else {
            return UIStrings.permissionUnknownPayload
        }

        let strings = items.compactMap { item -> String? in
            guard case .string(let text) = item else {
                return nil
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        if strings.count != items.count {
            return UIStrings.permissionUnknownPayload
        }
        return strings.isEmpty ? UIStrings.permissionNoneDeclared : strings.joined(separator: ", ")
    }

    private static func networkValue(_ value: JSONValue?) -> String {
        guard let value else {
            return UIStrings.permissionUndeclared
        }
        guard case .string(let text) = value else {
            return UIStrings.permissionUnknownPayload
        }

        switch text {
        case "none":
            return UIStrings.permissionNoneDeclared
        case "read-only":
            return UIStrings.permissionNetworkReadOnly
        case "full":
            return UIStrings.permissionNetworkFull
        default:
            return UIStrings.permissionUnknownValue(text)
        }
    }

    private static func boolValue(_ value: JSONValue?, trueText: String, falseText: String) -> String {
        guard let value else {
            return UIStrings.permissionUndeclared
        }
        guard case .bool(let bool) = value else {
            return UIStrings.permissionUnknownPayload
        }
        return bool ? trueText : falseText
    }

    private static func rawDescription(_ value: JSONValue) -> String {
        switch value {
        case .string(let text):
            return "\"\(escaped(text))\""
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .object(let object):
            let fields = object.keys.sorted().map { key in
                "\"\(escaped(key))\": \(rawDescription(object[key] ?? .null))"
            }
            return "{\(fields.joined(separator: ", "))}"
        case .array(let values):
            return "[\(values.map(rawDescription).joined(separator: ", "))]"
        case .null:
            return "null"
        }
    }

    private static func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

private struct FindingsSection: View {
    let skill: SkillRecord
    let findings: [RuleFindingRecord]
    @State private var severityFilter = FindingDisplayModel.allFilterValue
    @State private var ruleFilter = FindingDisplayModel.allFilterValue

    private var severityOptions: [String] {
        FindingDisplayModel.severityOptions(for: findings)
    }

    private var ruleIDOptions: [String] {
        FindingDisplayModel.ruleIDOptions(for: findings)
    }

    private var visibleGroups: [FindingSeverityGroup] {
        FindingDisplayModel.grouped(
            findings: findings,
            severityFilter: severityFilter,
            ruleFilter: ruleFilter
        )
    }

    private var visibleIssueCount: Int {
        visibleGroups.reduce(0) { $0 + $1.issues.count }
    }

    private var visibleEntryCount: Int {
        visibleGroups.reduce(0) { total, severityGroup in
            total + severityGroup.issues.reduce(0) { $0 + $1.entryCount }
        }
    }

    private var totalIssueCount: Int {
        FindingDisplayModel.issueGroups(
            findings: findings,
            severityFilter: FindingDisplayModel.allFilterValue,
            ruleFilter: FindingDisplayModel.allFilterValue
        ).count
    }

    private var visibleImpactedCount: Int {
        let ids = Set(FindingDisplayModel.filtered(
            findings: findings,
            severityFilter: severityFilter,
            ruleFilter: ruleFilter
        ).compactMap(\.instanceId))
        return max(ids.count, visibleEntryCount == 0 ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if findings.isEmpty {
                EmptyState(
                    title: UIStrings.noFindings,
                    systemImage: "checkmark.seal",
                    message: UIStrings.noFindingsForSkillMessage(DisplayText.agent(skill.agent))
                )
            } else {
                FindingsSummaryStrip(
                    visibleIssueCount: visibleIssueCount,
                    totalIssueCount: totalIssueCount,
                    visibleEntryCount: visibleEntryCount,
                    visibleImpactedCount: visibleImpactedCount
                )

                findingFilters

                if visibleGroups.isEmpty {
                    EmptyState(
                        title: UIStrings.noMatchingFindings,
                        systemImage: "line.3.horizontal.decrease.circle",
                        message: UIStrings.noMatchingFindingsMessage
                    )
                } else {
                    ForEach(visibleGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            FindingSeverityHeader(group: group)

                            ForEach(group.issues) { issue in
                                FindingIssueCard(issue: issue, severityTitle: group.title)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .onChange(of: findings) { _ in
            clampFilters()
        }
    }

    private var findingFilters: some View {
        HStack(spacing: 10) {
            Picker(UIStrings.findingSeverityFilter, selection: $severityFilter) {
                Text(UIStrings.allSeverities).tag(FindingDisplayModel.allFilterValue)
                ForEach(severityOptions, id: \.self) { severity in
                    Text(FindingDisplayModel.severityTitle(severity)).tag(severity)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170)
            .help(UIStrings.findingSeverityFilter)

            Picker(UIStrings.findingRuleFilter, selection: $ruleFilter) {
                Text(UIStrings.allRuleIDs).tag(FindingDisplayModel.allFilterValue)
                ForEach(ruleIDOptions, id: \.self) { ruleID in
                    Text(ruleID).tag(ruleID)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 260)
            .help(UIStrings.findingRuleFilter)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(UIStrings.visibleFindingGroupsSummary(visibleIssueCount, totalIssueCount, visibleEntryCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(UIStrings.findingScopeSummary(skill.name, DisplayText.agent(skill.agent)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clampFilters() {
        if severityFilter != FindingDisplayModel.allFilterValue && !severityOptions.contains(severityFilter) {
            severityFilter = FindingDisplayModel.allFilterValue
        }
        if ruleFilter != FindingDisplayModel.allFilterValue && !ruleIDOptions.contains(ruleFilter) {
            ruleFilter = FindingDisplayModel.allFilterValue
        }
    }
}

private struct FindingsSummaryStrip: View {
    let visibleIssueCount: Int
    let totalIssueCount: Int
    let visibleEntryCount: Int
    let visibleImpactedCount: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], alignment: .leading, spacing: 10) {
            SummaryChip(title: UIStrings.text("findings.summary.issueGroups", "Issue groups"), value: "\(visibleIssueCount) / \(totalIssueCount)", systemImage: "rectangle.stack.badge.exclamationmark")
            SummaryChip(title: UIStrings.text("findings.summary.impacted", "Impacted"), value: "\(visibleImpactedCount)", systemImage: "target")
            SummaryChip(title: UIStrings.text("findings.summary.entries", "Scan entries"), value: "\(visibleEntryCount)", systemImage: "list.bullet.rectangle")
            SummaryChip(title: UIStrings.findingRemediation, value: UIStrings.text("findings.summary.remediation", "Grouped below"), systemImage: "wrench.and.screwdriver")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct FindingIssueCard: View {
    let issue: FindingIssueGroup
    let severityTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(issue.ruleId, systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Spacer()
                Text(UIStrings.findingIssueImpact(issue.impactedInstanceCount, issue.entryCount))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.35), in: Capsule())
                Text(severityTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(issue.message)

            VStack(alignment: .leading, spacing: 5) {
                Label(UIStrings.findingRemediation, systemImage: "wrench.and.screwdriver")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Text(issue.remediation)
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct FindingSeverityHeader: View {
    let group: FindingSeverityGroup

    var body: some View {
        HStack(spacing: 8) {
            Label(group.title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            Text(UIStrings.findingSeverityGroupCount(group.issues.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private var systemImage: String {
        switch group.severityKey {
        case "critical", "error":
            return "xmark.octagon"
        case "warning", "warn":
            return "exclamationmark.triangle"
        case "info", "notice":
            return "info.circle"
        default:
            return "questionmark.circle"
        }
    }

    private var tint: Color {
        switch group.severityKey {
        case "critical", "error":
            return .red
        case "warning", "warn":
            return .orange
        case "info", "notice":
            return .blue
        default:
            return .secondary
        }
    }
}

private struct PermissionSummaryCard: View {
    let summary: PermissionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(UIStrings.permissions, systemImage: "hand.raised")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                ForEach(summary.rows) { row in
                    MetadataRow(label: row.label, value: row.value)
                }
            }

            Text(summary.note)
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(UIStrings.permissionRaw)
                    .font(.subheadline.bold())
                Text(summary.rawText)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct ConflictsSection: View {
    let conflicts: [ConflictGroupRecord]
    let selectedSkillID: String
    let currentAgentSkillIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label(UIStrings.text("conflicts.sameAgentWorkbench", "Same-agent conflict workbench"), systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.headline)
                Text(UIStrings.text("conflicts.sameAgentExplanation", "Conflicts only include current-agent runtime/name collisions. Cross-agent duplicate names and source overlap are analysis insights, so they are reviewed from the Analysis tab instead of inflating conflict counts."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            if conflicts.isEmpty {
                EmptyState(title: UIStrings.noConflicts, systemImage: "checkmark.circle", message: UIStrings.noConflictsMessage)
            } else {
                ForEach(conflicts) { conflict in
                    let currentAgentInstanceIDs = conflict.instanceIds.filter { currentAgentSkillIDs.contains($0) }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(conflict.reason)
                                .font(.headline)
                            Spacer()
                            Text(UIStrings.text("conflicts.currentAgentOnlyBadge", "current agent only"))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.35), in: Capsule())
                        }
                        MetadataLine(label: UIStrings.definition, value: conflict.definitionId)
                        MetadataLine(label: UIStrings.winner, value: conflict.winnerId ?? UIStrings.none)
                        Text(UIStrings.instances)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(currentAgentInstanceIDs, id: \.self) { instanceID in
                            Label(
                                instanceID == selectedSkillID ? "\(instanceID) · selected" : instanceID,
                                systemImage: instanceID == selectedSkillID ? "target" : "circle"
                            )
                            .font(.caption)
                            .textSelection(.enabled)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .adaptiveMaterialSurface()
                }
            }
        }
    }
}

struct AgentConfigHistorySection: View {
    let snapshots: [ConfigSnapshotRecord]
    let isWriting: Bool
    let onPreview: (String) async throws -> SnapshotRollbackPreviewRecord
    let onRollback: (String) async -> Void
    @State private var preview: SnapshotRollbackPreviewRecord?
    @State private var previewError: String?
    @State private var snapshotToRollback: ConfigSnapshotRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let previewError {
                ErrorBanner(message: previewError)
            }

            if snapshots.isEmpty {
                EmptyState(title: UIStrings.noSnapshots, systemImage: "clock.badge.questionmark", message: UIStrings.noSnapshotsMessage)
            } else {
                ForEach(snapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(snapshot.reason)
                                        .font(.headline)
                                    Text(DisplayText.timestamp(snapshot.createdAt))
                                        .foregroundStyle(.secondary)
                                }
                                MetadataLine(label: UIStrings.target, value: snapshot.target)
                                MetadataLine(label: UIStrings.scope, value: DisplayText.scope(snapshot.scope))
                                Text(UIStrings.charactersCaptured(snapshot.content.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    loadPreview(snapshot.id)
                                } label: {
                                    Label(UIStrings.preview, systemImage: "eye")
                                }
                                .disabled(isWriting)

                                Button(role: .destructive) {
                                    snapshotToRollback = snapshot
                                } label: {
                                    Label(UIStrings.rollback, systemImage: "arrow.uturn.backward")
                                }
                                .disabled(isWriting)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .adaptiveMaterialSurface()
                }
            }
        }
        .sheet(item: $preview) { preview in
            SnapshotPreviewSheet(preview: preview)
        }
        .confirmationDialog(
            UIStrings.rollbackSnapshotQuestion,
            isPresented: Binding(
                get: { snapshotToRollback != nil },
                set: { isPresented in
                    if !isPresented {
                        snapshotToRollback = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(UIStrings.rollback, role: .destructive) {
                if let snapshotID = snapshotToRollback?.id {
                    Task { await onRollback(snapshotID) }
                }
                snapshotToRollback = nil
            }
            Button(UIStrings.cancel, role: .cancel) {
                snapshotToRollback = nil
            }
        } message: {
            Text(snapshotToRollback?.target ?? "")
        }
    }

    private func loadPreview(_ snapshotID: String) {
        previewError = nil
        Task {
            do {
                preview = try await onPreview(snapshotID)
            } catch {
                previewError = error.localizedDescription
            }
        }
    }
}

private struct SnapshotPreviewSheet: View {
    let preview: SnapshotRollbackPreviewRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.snapshotPreview)
                        .font(.title2.bold())
                    Text(preview.snapshot.target)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button(UIStrings.done) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Label(
                preview.changed ? UIStrings.currentDiffersFromSnapshot : UIStrings.currentMatchesSnapshot,
                systemImage: preview.changed ? "exclamationmark.triangle" : "checkmark.circle"
            )
            .foregroundStyle(preview.changed ? .orange : .green)

            if let readError = preview.currentReadError {
                ErrorBanner(message: readError)
            }

            HStack(alignment: .top, spacing: 14) {
                SnapshotTextPane(title: UIStrings.current, content: preview.currentContent.isEmpty ? UIStrings.emptyPlaceholder : preview.currentContent)
                SnapshotTextPane(title: UIStrings.snapshot, content: preview.snapshot.content.isEmpty ? UIStrings.emptyPlaceholder : preview.snapshot.content)
            }
            .frame(minHeight: 420)
        }
        .padding(24)
        .frame(width: 980, height: 680)
    }
}

private struct SnapshotTextPane: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ScrollView([.vertical, .horizontal]) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct TextBlock: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

private struct MetadataLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

private struct EmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: 900, minHeight: 220)
        .adaptiveMaterialSurface()
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
    }
}

private struct SuccessBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
    }
}
