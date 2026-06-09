import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @State private var hasEditedDraft = false
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            editorSection
            Divider()
            serviceSection
        }
        .padding(24)
        .frame(minWidth: 760, idealWidth: 860, minHeight: 620, idealHeight: 680)
        .task {
            if store.status == nil {
                await store.reload()
            }
            await store.loadClaudeSettings()
            resetDraftFromStore()
        }
        .onChange(of: store.claudeSettings) { _ in
            if !hasEditedDraft {
                resetDraftFromStore()
            }
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }

    private var serviceSection: some View {
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
    }

    private var editorSection: some View {
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
    }

    private func resetDraftFromStore() {
        draft = store.claudeSettings?.content ?? ""
        hasEditedDraft = false
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
