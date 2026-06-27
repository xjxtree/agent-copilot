import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.defaultLanguage.rawValue
    @AppStorage(DisplayText.screenshotPrivacyModeStorageKey) private var screenshotPrivacyModeEnabled = true
    @State private var providerDraft = AIProviderSettingsDraft(status: .unavailable())
    @State private var hasEditedProviderDraft = false
    @State private var showsServiceDiagnostics = false

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

    private var selectedLanguage: Binding<AppLanguage> {
        Binding {
            AppLanguage.fromStorage(appLanguageRawValue)
        } set: { language in
            appLanguageRawValue = language.rawValue
            UIStrings.use(language)
        }
    }

    var body: some View {
        TabView {
            languageSection
                .tabItem {
                    Label(UIStrings.languageSettings, systemImage: "globe")
                }

            providerSection
                .tabItem {
                    Label(UIStrings.aiProviderSettings, systemImage: "key")
                }

            ScrollView {
                ProviderObservabilitySettingsPanel()
            }
            .tabItem {
                Label(UIStrings.providerObservabilityTitle, systemImage: "waveform.path.ecg.rectangle")
            }

            serviceSection
                .tabItem {
                    Label(UIStrings.service, systemImage: "wrench.and.screwdriver")
                }
        }
        .padding(20)
        .frame(
            minWidth: CGFloat(UIOptimizationPresentation.settings.minimumWidth),
            idealWidth: CGFloat(UIOptimizationPresentation.settings.idealWidth),
            minHeight: CGFloat(UIOptimizationPresentation.settings.minimumHeight),
            idealHeight: CGFloat(UIOptimizationPresentation.settings.idealHeight)
        )
        .task {
            if store.status == nil {
                await store.reload()
            }
            await store.loadAIProviderStatus()
            if store.providerObservabilityResult == nil {
                await store.loadProviderObservability()
            }
            resetProviderDraftFromStore()
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

    private var languageSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPageHeader(
                    title: UIStrings.languageSettings,
                    systemImage: "globe",
                    boundary: UIStrings.languageBoundary,
                    badge: UIStrings.text("settings.localOnly", "App-local")
                )

                SettingsSectionCard(
                    title: UIStrings.text("settings.preferences", "Preferences"),
                    systemImage: "slider.horizontal.3"
                ) {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                        GridRow {
                            Text(UIStrings.languageSelection)
                                .foregroundStyle(.secondary)
                            Picker(UIStrings.languageSelection, selection: selectedLanguage) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.title).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                        }

                        GridRow {
                            Text(UIStrings.privacyScreenshotMode)
                                .foregroundStyle(.secondary)
                            Toggle(UIStrings.privacyScreenshotMode, isOn: $screenshotPrivacyModeEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }

                    Text(UIStrings.privacyScreenshotBoundary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SettingsBanner(message: UIStrings.languageAppliesImmediately, systemImage: "checkmark.circle.fill", color: .green)

                Spacer(minLength: 0)
            }
            .padding(4)
        }
    }

    private var providerSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPageHeader(
                    title: UIStrings.aiProviderSettings,
                    systemImage: "key",
                    boundary: UIStrings.aiProviderBoundary,
                    badge: store.aiProviderStatus.configured ? UIStrings.aiProviderConfigured : UIStrings.aiProviderUnconfigured,
                    badgeSystemImage: store.aiProviderStatus.configured ? "checkmark.circle" : "circle.dashed",
                    badgeTint: store.aiProviderStatus.configured ? .green : .secondary
                )

                if !store.aiProviderStatus.serviceAvailable {
                    SettingsBanner(
                        message: UIStrings.localizedServiceMessage(store.aiProviderStatus.disabledReason ?? UIStrings.aiProviderUnavailable),
                        systemImage: "exclamationmark.triangle.fill",
                        color: .orange
                    )
                }

                SettingsSectionCard(title: UIStrings.text("settings.aiProvider.connection", "Connection"), systemImage: "network") {
                    providerConnectionForm
                }

                SettingsSectionCard(title: UIStrings.text("settings.aiProvider.limits", "Limits"), systemImage: "gauge.with.dots.needle.67percent") {
                    providerLimitsForm
                }

                SettingsSectionCard(title: UIStrings.text("settings.aiProvider.credentialSafety", "Credential Safety"), systemImage: "lock.shield") {
                    providerCredentialSafety
                }

                if let providerValidationMessage, hasEditedProviderDraft {
                    SettingsBanner(message: providerValidationMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
                }

                if let message = store.aiProviderMessage {
                    SettingsBanner(message: UIStrings.localizedServiceMessage(message), systemImage: "checkmark.circle.fill", color: .green)
                }

                if let error = store.aiProviderErrorMessage {
                    SettingsBanner(message: UIStrings.localizedServiceMessage(error), systemImage: "exclamationmark.triangle.fill", color: .red)
                }

                if store.isSavingAIProvider {
                    SettingsBanner(message: UIStrings.aiProviderSaving, systemImage: "hourglass", color: .secondary)
                } else if store.isTestingAIProvider {
                    SettingsBanner(message: UIStrings.aiProviderTesting, systemImage: "network", color: .secondary)
                }

                SettingsSectionCard(title: UIStrings.text("settings.actions", "Actions"), systemImage: "command") {
                    providerActions
                }

                if let result = store.aiProviderTestResult {
                    SettingsSectionCard(title: UIStrings.aiProviderTestResult, systemImage: "checkmark.seal") {
                        providerTestResult(result)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(4)
        }
    }

    private var providerConnectionForm: some View {
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
                TextField(UIStrings.aiProviderEndpointPlaceholder, text: $providerDraft.endpoint)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text(UIStrings.aiProviderModel)
                    .foregroundStyle(.secondary)
                TextField(UIStrings.aiProviderModelPlaceholder, text: $providerDraft.model)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text(UIStrings.aiProviderAPIVersion)
                    .foregroundStyle(.secondary)
                TextField(UIStrings.aiProviderOptionalPlaceholder, text: $providerDraft.apiVersion)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text(UIStrings.aiProviderAPIKey)
                    .foregroundStyle(.secondary)
                SecureField(UIStrings.aiProviderAPIKeyPlaceholder, text: $providerDraft.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var providerLimitsForm: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
            GridRow {
                Text(UIStrings.aiProviderMonthlyBudget)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    TextField(UIStrings.aiProviderMonthlyBudgetPlaceholder, text: $providerDraft.monthlyBudgetUSD)
                        .textFieldStyle(.roundedBorder)
                    Text(UIStrings.aiProviderMonthlyBudgetHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GridRow {
                Text(UIStrings.aiProviderTokenLimit)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    TextField(UIStrings.aiProviderTokenLimitPlaceholder, text: $providerDraft.singleRequestTokenLimit)
                        .textFieldStyle(.roundedBorder)
                    Text(UIStrings.aiProviderTokenLimitHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var providerCredentialSafety: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(UIStrings.aiProviderKeychainFirst)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                SettingsMetadataRow(label: UIStrings.aiProviderStorage, value: store.aiProviderStatus.credentialStorage ?? UIStrings.notLoaded)
                SettingsMetadataRow(label: UIStrings.llmEnabled, value: store.aiProviderStatus.enabled ? UIStrings.llmEnabled : UIStrings.llmDisabled)
                if let disabledReason = store.aiProviderStatus.disabledReason, !disabledReason.isEmpty {
                    SettingsMetadataRow(label: UIStrings.aiProviderUnconfigured, value: UIStrings.localizedServiceMessage(disabledReason))
                }
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
            Label(UIStrings.localizedServiceMessage(result.message), systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
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
                SettingsPageHeader(
                    title: UIStrings.service,
                    systemImage: "wrench.and.screwdriver",
                    boundary: UIStrings.text(
                        "settings.service.boundary",
                        "Review local sidecar health and privacy-safe diagnostics. This page does not write configuration or call providers."
                    ),
                    badge: UIStrings.text("settings.advanced", "Advanced"),
                    badgeSystemImage: "gearshape"
                )

                DetailMetricGrid(maxColumns: 3, minColumnWidth: 150) {
                    SummaryChip(title: UIStrings.version, value: store.status?.version ?? UIStrings.unknown, systemImage: "number")
                    SummaryChip(title: UIStrings.protocolLabel, value: "\(store.status?.protocolVersion ?? 0)", systemImage: "point.3.connected.trianglepath.dotted")
                    SummaryChip(title: UIStrings.methods, value: "\(store.status?.supportedMethods.count ?? 0)", systemImage: "list.bullet.rectangle")
                }

                DisclosureGroup(isExpanded: $showsServiceDiagnostics) {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        SettingsMetadataRow(label: UIStrings.version, value: store.status?.version ?? UIStrings.unknown)
                        SettingsMetadataRow(label: UIStrings.protocolLabel, value: "\(store.status?.protocolVersion ?? 0)")
                        PrivacyPathRow(label: UIStrings.catalog, path: store.status?.catalogPath ?? UIStrings.notLoaded)
                        PrivacyPathRow(label: UIStrings.userHome, path: store.status?.userHome ?? UIStrings.unknown)
                        SettingsMetadataRow(label: UIStrings.methods, value: "\(store.status?.supportedMethods.count ?? 0)")
                    }
                    .padding(.top, 8)
                } label: {
                    Label(UIStrings.text("settings.serviceDiagnostics", "Service Diagnostics"), systemImage: "wrench.and.screwdriver")
                        .font(.headline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveMaterialSurface()
                Spacer(minLength: 0)
            }
            .padding(4)
        }
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

private struct SettingsPageHeader: View {
    let title: String
    let systemImage: String
    let boundary: String
    var badge: String? = nil
    var badgeSystemImage = "lock.shield"
    var badgeTint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                if let badge {
                    Label(badge, systemImage: badgeSystemImage)
                        .font(.caption.bold())
                        .foregroundStyle(badgeTint)
                }
            }
            Text(boundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct SettingsBanner: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .foregroundStyle(color)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3)
                    .clipShape(Capsule())
            }
    }
}
