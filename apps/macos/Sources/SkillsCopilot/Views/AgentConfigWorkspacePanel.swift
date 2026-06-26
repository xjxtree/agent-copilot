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

    static func disabledSkills(for agent: SkillAgentFilter, store: SkillStore) -> [SkillRecord] {
        guard agent != .all else { return [] }
        return store.skills
            .filter { skill in
                skill.agent == agent.rawValue
                    && (!skill.enabled || skill.state.caseInsensitiveCompare("disabled") == .orderedSame)
            }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    static func disabledSkillNamesSummary(_ skills: [SkillRecord], limit: Int = 3) -> String {
        let names = skills.prefix(limit).map(\.name).joined(separator: ", ")
        let remaining = skills.count - min(skills.count, limit)
        guard remaining > 0 else { return names }
        return "\(names) · \(UIStrings.agentConfigDisabledSkillsMore(remaining))"
    }
}

struct AgentConfigDetailPanel: View {
    @EnvironmentObject private var store: SkillStore

    var body: some View {
        if let snapshot = store.selectedConfigSnapshot {
            AgentConfigSnapshotDetailPanel(snapshot: snapshot)
        } else {
            AgentConfigOverviewDetailPanel(selectedDocument: store.selectedConfigDocument)
        }
    }
}

private struct AgentConfigOverviewDetailPanel: View {
    @EnvironmentObject private var store: SkillStore
    let selectedDocument: ConfigDocumentRecord?

    @State private var draft = ""
    @State private var revealsSensitiveConfig = false

    private var capability: AdapterCapabilityRecord? {
        store.adapterCapabilities.first { $0.agent == store.agentFilter.rawValue }
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

    private var hasDraftChanges: Bool {
        draft != (store.claudeSettings?.content ?? "")
    }

    private var canSave: Bool {
        revealsSensitiveConfig && hasDraftChanges && validationMessage == nil && !store.isSavingSettings
    }

    private var displayedDraft: Binding<String> {
        Binding {
            revealsSensitiveConfig ? draft : ConfigContentRedactor.redactedForDisplay(draft)
        } set: { newValue in
            guard revealsSensitiveConfig else { return }
            draft = newValue
            store.clearSettingsFeedback()
        }
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
                            path: selectedDocument?.target ?? AgentConfigDisplay.targetPath(for: store.agentFilter, store: store),
                            font: .caption,
                            lineLimit: 1
                        )
                    }
                    Spacer()
                    Text(capability == nil ? UIStrings.notLoaded : UIStrings.supported)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.secondary.opacity(0.10), in: Capsule())
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

            if let selectedDocument {
                if isEditableClaudeGlobalDocument(selectedDocument) {
                    claudeCurrentConfigSection
                } else {
                    currentAgentConfigSection(documents: [selectedDocument])
                }
            } else if store.agentFilter == .claudeCode {
                claudeCurrentConfigSection
            } else {
                currentAgentConfigSection(documents: store.currentAgentConfigDocuments)
            }
        }
        .task(id: store.selectedAgentConfigRefreshKey) {
            await store.loadSelectedAgentConfigDataIfNeeded()
            if store.agentFilter == .claudeCode {
                resetDraftFromStore()
            }
        }
        .onChange(of: store.claudeSettings) { _ in
            if !hasDraftChanges {
                resetDraftFromStore()
            }
        }
    }

    private func currentAgentConfigSection(documents: [ConfigDocumentRecord]) -> some View {
        AgentCurrentConfigDocumentsSection(
            agent: store.agentFilter,
            documents: documents,
            isLoading: store.isLoadingAgentConfigDocuments,
            errorMessage: store.settingsErrorMessage,
            revealsSensitiveConfig: $revealsSensitiveConfig
        ) {
            Task {
                await store.loadCurrentAgentConfigDocuments(agent: store.agentFilter.rawValue)
            }
        }
    }

    private func isEditableClaudeGlobalDocument(_ document: ConfigDocumentRecord) -> Bool {
        document.agent == SkillAgentFilter.claudeCode.rawValue
            && document.scope.localizedCaseInsensitiveContains("global")
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

            if let validationMessage {
                ConfigInlineBanner(message: validationMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
            } else if hasDraftChanges {
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
                        await store.refreshSelectedAgentConfigData()
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
        revealsSensitiveConfig = false
    }
}

private struct AgentCurrentConfigDocumentsSection: View {
    let agent: SkillAgentFilter
    let documents: [ConfigDocumentRecord]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var revealsSensitiveConfig: Bool
    let reload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.currentConfigFile)
                        .font(.headline)
                    Text(UIStrings.agentConfigReadOnlyPreview(DisplayText.agent(agent.rawValue)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: reload) {
                    Label(UIStrings.reload, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
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
                        revealsSensitiveConfig ? UIStrings.agentConfigHideSensitive : UIStrings.agentConfigShowSensitiveValues,
                        systemImage: revealsSensitiveConfig ? "eye.slash" : "eye"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(documents.isEmpty)
            }

            if isLoading {
                Label(UIStrings.loading, systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                ConfigInlineBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
            }

            if documents.isEmpty && !isLoading && errorMessage == nil {
                Text(UIStrings.agentConfigNoReadableDocuments)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(documents, id: \.target) { document in
                    AgentCurrentConfigDocumentPane(
                        document: document,
                        revealsSensitiveConfig: revealsSensitiveConfig
                    )
                }
            }

            Label(
                UIStrings.agentConfigReadOnlyBoundary,
                systemImage: "lock.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }
}

private struct AgentCurrentConfigDocumentPane: View {
    let document: ConfigDocumentRecord
    let revealsSensitiveConfig: Bool

    private var displayedContent: String {
        let content = document.content.isEmpty ? UIStrings.emptyPlaceholder : document.content
        guard !revealsSensitiveConfig else { return content }
        return ConfigContentRedactor.redactedForDisplay(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    PrivacyPathText(path: document.target, font: .callout, lineLimit: 1)
                    HStack(spacing: 8) {
                        Text(DisplayText.scope(document.scope))
                        Text(document.format.uppercased())
                        Text(document.exists ? UIStrings.existingFile : UIStrings.willCreateFile)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView([.vertical, .horizontal]) {
                Text(displayedContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 180, maxHeight: 300)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
