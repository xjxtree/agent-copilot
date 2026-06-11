import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @State private var hasEditedDraft = false
    @State private var providerDraft = AIProviderSettingsDraft(status: .unavailable())
    @State private var hasEditedProviderDraft = false
    @State private var showsServiceDiagnostics = false

    private var validationMessage: String? {
        guard let data = draft.data(using: .utf8) else {
            return UIStrings.settingsInvalidUTF8
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var canSave: Bool {
        hasEditedDraft && validationMessage == nil && !store.isSavingSettings
    }

    private var providerValidationMessage: String? {
        providerDraft.validationMessage
    }

    private var providerActionsDisabled: Bool {
        store.isLoadingAIProvider || store.isSavingAIProvider || store.isTestingAIProvider || !store.aiProviderStatus.serviceAvailable
    }

    private var canSaveProvider: Bool {
        hasEditedProviderDraft && providerValidationMessage == nil && !providerActionsDisabled
    }

    private var canTestProvider: Bool {
        providerValidationMessage == nil
            && !providerActionsDisabled
            && !hasEditedProviderDraft
            && store.aiProviderStatus.activeProfile != nil
    }

    var body: some View {
        TabView {
            providerSection
                .tabItem {
                    Label(UIStrings.aiProviderSettings, systemImage: "key")
                }

            editorSection
                .tabItem {
                    Label(UIStrings.claudeSettings, systemImage: "curlybraces")
                }

            serviceSection
                .tabItem {
                    Label(UIStrings.service, systemImage: "wrench.and.screwdriver")
                }
        }
        .padding(20)
        .frame(minWidth: 760, idealWidth: 860, minHeight: 620, idealHeight: 680)
        .task {
            if store.status == nil {
                await store.reload()
            }
            await store.loadAIProviderStatus()
            await store.loadClaudeSettings()
            resetDraftFromStore()
            resetProviderDraftFromStore()
        }
        .onChange(of: store.claudeSettings) { _ in
            if !hasEditedDraft {
                resetDraftFromStore()
            }
        }
        .onChange(of: store.aiProviderStatus) { _ in
            if !hasEditedProviderDraft {
                resetProviderDraftFromStore()
            }
        }
        .onChange(of: providerDraft) { _ in
            hasEditedProviderDraft = providerDraft != AIProviderSettingsDraft(status: store.aiProviderStatus)
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }

    private var providerSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(UIStrings.aiProviderSettings)
                            .font(.headline)
                        Spacer()
                        Label(
                            store.aiProviderStatus.configured ? UIStrings.aiProviderConfigured : UIStrings.aiProviderUnconfigured,
                            systemImage: store.aiProviderStatus.configured ? "checkmark.circle" : "circle.dashed"
                        )
                        .foregroundStyle(store.aiProviderStatus.configured ? .green : .secondary)
                    }

                    Text(UIStrings.aiProviderBoundary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !store.aiProviderStatus.serviceAvailable {
                    SettingsBanner(message: store.aiProviderStatus.disabledReason ?? UIStrings.aiProviderUnavailable, systemImage: "exclamationmark.triangle.fill", color: .orange)
                }

                providerForm

                Text(UIStrings.aiProviderKeychainFirst)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let providerValidationMessage, hasEditedProviderDraft {
                    SettingsBanner(message: providerValidationMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
                }

                if let message = store.aiProviderMessage {
                    SettingsBanner(message: message, systemImage: "checkmark.circle.fill", color: .green)
                }

                if let error = store.aiProviderErrorMessage {
                    SettingsBanner(message: error, systemImage: "exclamationmark.triangle.fill", color: .red)
                }

                if store.isSavingAIProvider {
                    SettingsBanner(message: UIStrings.aiProviderSaving, systemImage: "hourglass", color: .secondary)
                } else if store.isTestingAIProvider {
                    SettingsBanner(message: UIStrings.aiProviderTesting, systemImage: "network", color: .secondary)
                }

                providerActions

                if let result = store.aiProviderTestResult {
                    providerTestResult(result)
                }

                Spacer(minLength: 0)
            }
            .padding(4)
        }
    }

    private var providerForm: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
            GridRow {
                Text(UIStrings.llmProvider)
                    .foregroundStyle(.secondary)
                Picker(UIStrings.llmProvider, selection: $providerDraft.kind) {
                    ForEach([AIProviderKind.openAICompatible, .claudeCompatible]) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            GridRow {
                Text(UIStrings.aiProviderEndpoint)
                    .foregroundStyle(.secondary)
                TextField("https://api.example.com/v1", text: $providerDraft.endpoint)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text(UIStrings.aiProviderModel)
                    .foregroundStyle(.secondary)
                TextField("model", text: $providerDraft.model)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text(UIStrings.aiProviderAPIVersion)
                    .foregroundStyle(.secondary)
                TextField("optional", text: $providerDraft.apiVersion)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text(UIStrings.aiProviderAPIKey)
                    .foregroundStyle(.secondary)
                SecureField(UIStrings.aiProviderAPIKeyPlaceholder, text: $providerDraft.apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text(UIStrings.aiProviderBudget)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    TextField(UIStrings.aiProviderMonthlyBudget, text: $providerDraft.monthlyBudgetUSD)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    TextField(UIStrings.aiProviderTokenLimit, text: $providerDraft.singleRequestTokenLimit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 190)
                }
            }

            SettingsMetadataRow(label: UIStrings.aiProviderStorage, value: store.aiProviderStatus.credentialStorage ?? UIStrings.notLoaded)
            SettingsMetadataRow(label: UIStrings.llmEnabled, value: store.aiProviderStatus.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled)
            if let disabledReason = store.aiProviderStatus.disabledReason, !disabledReason.isEmpty {
                SettingsMetadataRow(label: UIStrings.aiProviderUnconfigured, value: disabledReason)
            }
        }
    }

    private var providerActions: some View {
        HStack {
            Button {
                Task {
                    await store.loadAIProviderStatus()
                    resetProviderDraftFromStore()
                }
            } label: {
                Label(UIStrings.reload, systemImage: "arrow.clockwise")
            }
            .disabled(store.isLoadingAIProvider || store.isSavingAIProvider || store.isTestingAIProvider)

            Spacer()

            Button {
                Task {
                    _ = await store.testAIProviderConnection(draft: providerDraft)
                    providerDraft.apiKey = ""
                    resetProviderEditedState()
                }
            } label: {
                Label(UIStrings.aiProviderTest, systemImage: "network")
            }
            .disabled(!canTestProvider)

            Button {
                Task {
                    let saved = await store.saveAIProviderSettings(draft: providerDraft)
                    providerDraft.apiKey = ""
                    if saved {
                        await store.loadAIProviderStatus()
                        resetProviderDraftFromStore()
                    } else {
                        resetProviderEditedState()
                    }
                }
            } label: {
                Label(UIStrings.aiProviderSave, systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSaveProvider)
        }
    }

    private func providerTestResult(_ result: AIProviderTestResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(result.success ? .green : .orange)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                SettingsMetadataRow(label: UIStrings.aiProviderTestResult, value: result.status)
                if let audit = result.audit {
                    SettingsMetadataRow(label: UIStrings.aiProviderAuditMetadata, value: audit.auditID ?? UIStrings.unknown)
                    SettingsMetadataRow(label: UIStrings.llmProvider, value: audit.provider ?? UIStrings.unknown)
                    SettingsMetadataRow(label: UIStrings.llmModel, value: audit.model ?? UIStrings.unknown)
                    SettingsMetadataRow(label: UIStrings.aiProviderEndpoint, value: audit.endpoint ?? UIStrings.unknown)
                    SettingsMetadataRow(label: UIStrings.aiProviderAuditDuration, value: audit.durationMS.map { "\($0) ms" } ?? UIStrings.unknown)
                    SettingsMetadataRow(label: UIStrings.aiProviderAuditRedaction, value: audit.redactionApplied ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                    SettingsMetadataRow(label: UIStrings.aiProviderAuditPromptStored, value: audit.promptStored ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                    SettingsMetadataRow(label: UIStrings.aiProviderAuditResponseStored, value: audit.responseStored ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                    if let input = audit.inputTokens, let output = audit.outputTokens {
                        SettingsMetadataRow(label: UIStrings.llmTokens, value: "\(input) in / \(output) out")
                    }
                    if let cost = audit.estimatedCostUSD {
                        SettingsMetadataRow(label: UIStrings.llmCost, value: String(format: "$%.4f", cost))
                    }
                    if let errorCode = audit.errorCode {
                        SettingsMetadataRow(label: UIStrings.aiProviderAuditErrorCode, value: errorCode)
                    }
                } else {
                    SettingsMetadataRow(label: UIStrings.aiProviderAuditMetadata, value: UIStrings.aiProviderNoAudit)
                }
            }
        }
        .padding(.top, 4)
    }

    private var serviceSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DisclosureGroup(isExpanded: $showsServiceDiagnostics) {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        SettingsMetadataRow(label: UIStrings.version, value: store.status?.version ?? UIStrings.unknown)
                        SettingsMetadataRow(label: UIStrings.protocolLabel, value: "\(store.status?.protocolVersion ?? 0)")
                        SettingsMetadataRow(label: UIStrings.catalog, value: store.status?.catalogPath ?? UIStrings.notLoaded)
                        SettingsMetadataRow(label: UIStrings.userHome, value: store.status?.userHome ?? UIStrings.unknown)
                        SettingsMetadataRow(label: UIStrings.methods, value: "\(store.status?.supportedMethods.count ?? 0)")
                    }
                    .padding(.top, 8)
                } label: {
                    Label(UIStrings.text("settings.serviceDiagnostics", "Service Diagnostics"), systemImage: "wrench.and.screwdriver")
                        .font(.headline)
                }
                Spacer(minLength: 0)
            }
            .padding(4)
        }
    }

    private var editorSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UIStrings.claudeSettings)
                            .font(.headline)
                        Text(store.claudeSettings?.target ?? "~/.claude/settings.json")
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    if let settings = store.claudeSettings {
                        Label(settings.exists ? UIStrings.existingFile : UIStrings.willCreateFile, systemImage: settings.exists ? "doc.text" : "doc.badge.plus")
                            .foregroundStyle(.secondary)
                    }
                }

                TextEditor(text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 300)
                    .padding(6)
                    .adaptiveMaterialSurface()
                    .onChange(of: draft) { _ in
                        hasEditedDraft = draft != (store.claudeSettings?.content ?? "")
                    }

                if let validationMessage {
                    SettingsBanner(message: validationMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
                } else if hasEditedDraft {
                    SettingsBanner(message: UIStrings.jsonValidSettingsWrite, systemImage: "checkmark.circle.fill", color: .green)
                }

                if let message = store.settingsMessage {
                    SettingsBanner(message: message, systemImage: "checkmark.circle.fill", color: .green)
                }

                if let error = store.settingsErrorMessage {
                    SettingsBanner(message: error, systemImage: "exclamationmark.triangle.fill", color: .red)
                }

                HStack {
                    Button {
                        Task {
                            hasEditedDraft = false
                            await store.loadClaudeSettings()
                            resetDraftFromStore()
                        }
                    } label: {
                        Label(UIStrings.reload, systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isLoadingSettings || store.isSavingSettings)

                    Spacer()

                    Button {
                        Task {
                            let saved = await store.saveClaudeSettings(content: draft)
                            if saved {
                                hasEditedDraft = false
                                resetDraftFromStore()
                            }
                        }
                    } label: {
                        Label(UIStrings.save, systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
            }
            .padding(4)
        }
    }

    private func resetDraftFromStore() {
        draft = store.claudeSettings?.content ?? ""
        hasEditedDraft = false
    }

    private func resetProviderDraftFromStore() {
        providerDraft = AIProviderSettingsDraft(status: store.aiProviderStatus)
        hasEditedProviderDraft = false
    }

    private func resetProviderEditedState() {
        hasEditedProviderDraft = providerDraft != AIProviderSettingsDraft(status: store.aiProviderStatus)
    }
}

private struct SettingsMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}

private struct SettingsBanner: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .foregroundStyle(color)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
    }
}
