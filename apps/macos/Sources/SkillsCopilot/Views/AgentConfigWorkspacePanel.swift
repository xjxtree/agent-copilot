import SwiftUI

@MainActor
enum AgentConfigDisplay {
    static func targetPath(for agent: SkillAgentFilter, store: SkillStore) -> String {
        switch agent {
        case .claudeCode:
            return store.claudeSettings?.target ?? "~/.claude/settings.json"
        case .codex:
            return "~/.codex/config.toml"
        case .opencode:
            return "~/.config/opencode/opencode.json"
        case .pi:
            return "~/.pi/agent/settings.json / <project>/.pi/settings.json"
        case .hermes:
            return "~/.hermes/config.yaml"
        case .openclaw:
            return "~/.openclaw/openclaw.json"
        case .all:
            return UIStrings.unknown
        }
    }

    static func shortTargetPath(for agent: SkillAgentFilter, store: SkillStore) -> String {
        pathSummary(targetPath(for: agent, store: store))
    }

    static func pathSummary(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UIStrings.unknown }
        return DisplayText.configPathSummary(trimmed)
    }

    static func supportText(_ capability: AdapterFeatureCapability?) -> String {
        capability?.supported == true ? UIStrings.supported : UIStrings.notSupported
    }

    static func supportSymbol(_ capability: AdapterFeatureCapability?) -> String {
        capability?.supported == true ? "checkmark.circle.fill" : "minus.circle"
    }

    static func supportColor(_ capability: AdapterFeatureCapability?) -> Color {
        capability?.supported == true ? .green : .secondary
    }
}

struct AgentConfigDetailPanel: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        if let snapshot = store.selectedConfigSnapshot {
            AgentConfigSnapshotDetailPanel(snapshot: snapshot)
        } else {
            AgentConfigOverviewDetailPanel()
        }
    }
}

private struct AgentConfigOverviewDetailPanel: View {
    @EnvironmentObject private var store: SkillStore
    @State private var draft = ""
    @State private var hasEditedDraft = false
    @State private var revealsSensitiveConfig = false

    private var capability: AdapterCapabilityRecord? {
        store.adapterCapabilities.first { $0.agent == store.agentFilter.rawValue }
    }

    private var selectedSnapshots: [ConfigSnapshotRecord] {
        store.agentConfigSnapshots
            .filter { $0.agent == store.agentFilter.rawValue }
            .sorted { $0.createdAt > $1.createdAt }
    }

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
        revealsSensitiveConfig && hasEditedDraft && validationMessage == nil && !store.isSavingSettings
    }

    private var displayedDraft: Binding<String> {
        if revealsSensitiveConfig {
            return $draft
        }
        return .constant(ConfigContentRedactor.redactedForDisplay(draft))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    AgentConfigAgentIcon(filter: store.agentFilter)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UIStrings.agentConfigSettings)
                            .font(.title2.bold())
                        Text(DisplayText.agent(store.agentFilter.rawValue))
                            .font(.headline)
                        PrivacyPathText(
                            path: AgentConfigDisplay.targetPath(for: store.agentFilter, store: store),
                            font: .caption,
                            lineLimit: 1
                        )
                    }
                    Spacer()
                    Text(capability?.status ?? UIStrings.notLoaded)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.secondary.opacity(0.10), in: Capsule())
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    AgentConfigCapabilityCard(title: UIStrings.scan, capability: capability?.scan, systemImage: "magnifyingglass")
                    AgentConfigCapabilityCard(title: UIStrings.projectScan, capability: capability?.projectScan, systemImage: "folder")
                    AgentConfigCapabilityCard(title: UIStrings.configToggle, capability: capability?.configToggle, systemImage: "switch.2")
                    AgentConfigCapabilityCard(title: UIStrings.configSnapshot, capability: capability?.configSnapshot, systemImage: "clock.arrow.circlepath")
                    AgentConfigCapabilityCard(title: UIStrings.writableConfig, capability: capability?.writable, systemImage: "lock.open")
                    SummaryChip(
                        title: UIStrings.agentConfigSettingsHistory,
                        value: String(selectedSnapshots.count),
                        systemImage: "clock.arrow.circlepath"
                    )
                }

                if let blockers = capability?.blockers, !blockers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(UIStrings.agentConfigBlockedScope)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(blockers.prefix(4), id: \.self) { blocker in
                            Label(blocker, systemImage: "minus.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            if store.agentFilter == .claudeCode {
                claudeCurrentConfigSection
            } else {
                Label(
                    UIStrings.agentConfigRawEditorBoundary(DisplayText.agent(store.agentFilter.rawValue)),
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveMaterialSurface()
            }
        }
        .task(id: store.agentFilter.rawValue) {
            await store.loadAgentConfigSnapshots(agent: store.agentFilter.rawValue)
            if store.agentFilter == .claudeCode {
                await store.loadClaudeSettings()
                resetDraftFromStore()
            }
        }
        .onChange(of: store.claudeSettings) { _ in
            if !hasEditedDraft {
                resetDraftFromStore()
            }
        }
    }

    private var claudeCurrentConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.currentConfigFile)
                        .font(.headline)
                    PrivacyPathText(
                        path: store.claudeSettings?.target ?? "~/.claude/settings.json",
                        font: .callout,
                        lineLimit: 1
                    )
                }
                Spacer()
                if let settings = store.claudeSettings {
                    Label(
                        settings.exists ? UIStrings.existingFile : UIStrings.willCreateFile,
                        systemImage: settings.exists ? "doc.text" : "doc.badge.plus"
                    )
                    .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label(
                    revealsSensitiveConfig ? UIStrings.agentConfigSensitiveValuesVisible : UIStrings.agentConfigSensitiveValuesHidden,
                    systemImage: revealsSensitiveConfig ? "eye" : "eye.slash"
                )
                    .font(.caption)
                    .foregroundStyle(revealsSensitiveConfig ? Color.orange : Color.secondary)
                Spacer()
                Button {
                    revealsSensitiveConfig.toggle()
                } label: {
                    Label(
                        revealsSensitiveConfig ? UIStrings.agentConfigHideSensitive : UIStrings.agentConfigShowSensitive,
                        systemImage: revealsSensitiveConfig ? "eye.slash" : "eye"
                    )
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: displayedDraft)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 280)
                .padding(6)
                .adaptiveMaterialSurface()
                .disabled(!revealsSensitiveConfig)
                .onChange(of: draft) { _ in
                    hasEditedDraft = draft != (store.claudeSettings?.content ?? "")
                }

            if let validationMessage {
                ConfigInlineBanner(message: validationMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
            } else if hasEditedDraft {
                ConfigInlineBanner(message: UIStrings.jsonValidSettingsWrite, systemImage: "checkmark.circle.fill", color: .green)
            }

            if let message = store.settingsMessage {
                ConfigInlineBanner(message: message, systemImage: "checkmark.circle.fill", color: .green)
            }

            if let error = store.settingsErrorMessage {
                ConfigInlineBanner(message: error, systemImage: "exclamationmark.triangle.fill", color: .red)
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
                            await store.loadAgentConfigSnapshots(agent: store.agentFilter.rawValue)
                        }
                    }
                } label: {
                    Label(UIStrings.save, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(!canSave)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private func resetDraftFromStore() {
        draft = store.claudeSettings?.content ?? ""
        hasEditedDraft = false
        revealsSensitiveConfig = false
    }
}

private struct AgentConfigSnapshotDetailPanel: View {
    @EnvironmentObject private var store: SkillStore
    let snapshot: ConfigSnapshotRecord

    @State private var preview: SnapshotRollbackPreviewRecord?
    @State private var previewError: String?
    @State private var snapshotToRollback: ConfigSnapshotRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UIStrings.snapshotPreview)
                            .font(.title2.bold())
                        Text(snapshot.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UIStrings.agentConfigTimelineDefaultAction : snapshot.reason)
                            .font(.headline)
                        PrivacyPathText(path: snapshot.target, font: .caption, lineLimit: 1)
                    }
                    Spacer()
                    Button {
                        loadPreview()
                    } label: {
                        Label(UIStrings.previewDiff, systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(store.isWriting)

                    Button(role: .destructive) {
                        snapshotToRollback = snapshot
                    } label: {
                        Label(UIStrings.rollback, systemImage: "arrow.uturn.backward")
                    }
                    .disabled(store.isWriting)
                }

                DetailMetricGrid {
                    SummaryChip(title: UIStrings.agent, value: DisplayText.agent(snapshot.agent), systemImage: "person.crop.circle")
                    SummaryChip(title: UIStrings.scope, value: DisplayText.scope(snapshot.scope), systemImage: "folder")
                    SummaryChip(title: UIStrings.target, value: AgentConfigDisplay.pathSummary(snapshot.target), systemImage: "scope")
                    SummaryChip(title: UIStrings.text("history.created", "Created"), value: DisplayText.timestamp(snapshot.createdAt), systemImage: "calendar")
                    SummaryChip(title: UIStrings.text("history.characters", "Captured"), value: UIStrings.charactersCaptured(snapshot.content.count), systemImage: "textformat.size")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()

            if let previewError {
                ErrorBanner(message: previewError)
            }

            if let preview {
                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        preview.changed ? UIStrings.currentDiffersFromSnapshot : UIStrings.currentMatchesSnapshot,
                        systemImage: preview.changed ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .foregroundStyle(preview.changed ? .orange : .green)

                    if let readError = preview.currentReadError {
                        ErrorBanner(message: readError)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            SnapshotTextPane(
                                title: UIStrings.current,
                                content: preview.currentContent.isEmpty ? UIStrings.emptyPlaceholder : preview.currentContent
                            )
                            SnapshotTextPane(
                                title: UIStrings.snapshot,
                                content: preview.snapshot.content.isEmpty ? UIStrings.emptyPlaceholder : preview.snapshot.content
                            )
                        }
                        .frame(minHeight: 420)

                        VStack(alignment: .leading, spacing: 12) {
                            SnapshotTextPane(
                                title: UIStrings.current,
                                content: preview.currentContent.isEmpty ? UIStrings.emptyPlaceholder : preview.currentContent
                            )
                            SnapshotTextPane(
                                title: UIStrings.snapshot,
                                content: preview.snapshot.content.isEmpty ? UIStrings.emptyPlaceholder : preview.snapshot.content
                            )
                        }
                        .frame(minHeight: 520)
                    }
                }
            } else {
                SnapshotTextPane(
                    title: UIStrings.snapshot,
                    content: snapshot.content.isEmpty ? UIStrings.emptyPlaceholder : snapshot.content
                )
                .frame(minHeight: 360)
            }
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
                guard let snapshotID = snapshotToRollback?.id else { return }
                Task { await store.rollbackSnapshot(snapshotID: snapshotID) }
                snapshotToRollback = nil
            }
            Button(UIStrings.cancel, role: .cancel) {
                snapshotToRollback = nil
            }
        } message: {
            Text(UIStrings.agentConfigTimelineRollbackConfirm(
                AgentConfigDisplay.pathSummary(snapshotToRollback?.target ?? "")
            ))
        }
    }

    private func loadPreview() {
        previewError = nil
        Task {
            do {
                preview = try await store.previewRollback(snapshotID: snapshot.id)
            } catch {
                previewError = error.localizedDescription
            }
        }
    }
}

private struct AgentConfigCapabilityCard: View {
    let title: String
    let capability: AdapterFeatureCapability?
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AgentConfigDisplay.supportColor(capability))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(AgentConfigDisplay.supportText(capability))
                    .font(.callout.bold())
                Text(capability?.status ?? UIStrings.notLoaded)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .help(capability?.reason ?? capability?.status ?? "")
    }
}

private struct AgentConfigAgentIcon: View {
    let filter: SkillAgentFilter

    var body: some View {
        ZStack {
            if let image = AgentIconProvider.image(for: filter) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 36, height: 36)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct ConfigInlineBanner: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
