import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var globalSearchText = ""
    @State private var isSkillManagerSheetPresented = false

    var body: some View {
        ZStack {
            appShell
                .opacity(store.startupLoadingState == nil ? 1 : 0)
                .allowsHitTesting(store.startupLoadingState == nil)
                .accessibilityHidden(store.startupLoadingState != nil)

            if let state = store.startupLoadingState {
                AppStartupLoadingView(state: state)
                    .transition(.opacity)
            }
        }
        .task {
            await store.loadAppStartupDataIfNeeded()
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
        .accessibilityIdentifier(AppAccessibilityID.mainContent)
        .accessibilityLabel(UIStrings.appWindowTitle)
    }

    private var appShell: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(
                    min: CGFloat(UIOptimizationPresentation.sidebarShell.width),
                    ideal: CGFloat(UIOptimizationPresentation.sidebarShell.width),
                    max: CGFloat(UIOptimizationPresentation.sidebarShell.width)
                )
        } content: {
            SecondarySidebarView()
                .navigationSplitViewColumnWidth(
                    min: CGFloat(UIOptimizationPresentation.skillList.minimumSecondaryColumnWidth),
                    ideal: CGFloat(UIOptimizationPresentation.skillList.idealSecondaryColumnWidth),
                    max: CGFloat(UIOptimizationPresentation.skillList.maximumSecondaryColumnWidth)
                )
        } detail: {
            DetailView(skill: store.selectedSkill)
        }
        .task(id: store.selectedAgentLocalSessionRefreshKey) {
            guard store.hasCompletedStartupLoad else { return }
            await store.refreshSelectedAgentLocalSessionsIfNeeded()
        }
        .onChange(of: store.selectedSkillID) { _ in
            guard store.hasCompletedStartupLoad else { return }
            Task { await store.loadSelectedDetail() }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                AppBrandToolbarItem()
            }

            ToolbarItem(placement: .principal) {
                ToolbarContextSummary(
                    projectName: store.activeProjectContext?.name ?? UIStrings.text("project.globalRoots", "Global roots"),
                    projectPath: store.activeProjectContext?.rootPath,
                    agentTitle: store.agentFilter.title
                )
            }

            ToolbarItemGroup(placement: .automatic) {
                GlobalToolbarSearchField(
                    text: $globalSearchText,
                    placeholder: UIStrings.text("toolbar.globalSearch", "Search all"),
                    onSubmit: applyGlobalSearch
                )
                .frame(
                    minWidth: CGFloat(UIOptimizationPresentation.unifiedToolbar.minimumGlobalSearchWidth),
                    idealWidth: CGFloat(UIOptimizationPresentation.unifiedToolbar.idealGlobalSearchWidth)
                )

                Button {
                    isSkillManagerSheetPresented = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text(UIStrings.text("toolbar.new", "New"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(store.isRefreshBusy)

                Button {
                    NSApp.orderFrontStandardAboutPanel(nil)
                } label: {
                    Label(UIStrings.text("toolbar.help", "Help"), systemImage: "questionmark.circle")
                }
                .labelStyle(.iconOnly)
                .help(UIStrings.text("toolbar.help", "Help"))

                ToolbarSettingsControl()

                ToolbarAvatarView(title: store.agentFilter.title)
            }
        }
        .sheet(isPresented: $isSkillManagerSheetPresented) {
            SkillPackageManagerSheet()
                .environmentObject(store)
        }
    }

    private func applyGlobalSearch() {
        let query = globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch store.sidebarContentMode {
        case .skills:
            store.searchText = query
        case .sessions:
            store.localSessionSearchText = query
        case .config:
            store.configSidebarSearchText = query
        }
    }
}

private struct AppStartupLoadingView: View {
    let state: AppStartupLoadingState

    var body: some View {
        VStack(spacing: 14) {
            Text(state.message)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ProgressView(value: state.progress)
                .progressViewStyle(.linear)
                .frame(width: 320)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.message)
        .accessibilityValue("\(Int((state.progress * 100).rounded()))%")
    }
}

private struct AppBrandToolbarItem: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(UIStrings.appTitle)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(UIStrings.appTitle)
    }
}

private struct ToolbarContextSummary: View {
    let projectName: String
    let projectPath: String?
    let agentTitle: String

    var body: some View {
        VStack(spacing: 1) {
            Text(projectName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(contextSubtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(projectName), \(contextSubtitle)")
    }

    private var contextSubtitle: String {
        if let projectPath, !projectPath.isEmpty {
            return "\(agentTitle) · \(DisplayText.privacyPath(projectPath, privacyModeEnabled: true))"
        }
        return "\(agentTitle) · \(UIStrings.projectGlobalRootsOnly)"
    }
}

private struct GlobalToolbarSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .help(UIStrings.text("toolbar.globalSearch.help", "Search within the current list. Press Return to apply."))
    }
}

private struct ToolbarSettingsControl: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsLabel
            }
            .labelStyle(.iconOnly)
            .help(UIStrings.text("toolbar.settings", "Settings"))
        } else {
            Button(action: openSettingsFallback) {
                settingsLabel
            }
            .labelStyle(.iconOnly)
            .help(UIStrings.text("toolbar.settings", "Settings"))
        }
    }

    private var settingsLabel: some View {
        Label(UIStrings.text("toolbar.settings", "Settings"), systemImage: "gearshape")
    }

    private func openSettingsFallback() {
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

private struct ToolbarAvatarView: View {
    let title: String

    var body: some View {
        Text(initial)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 26, height: 26)
            .background(.thinMaterial, in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
            .help(title)
            .accessibilityLabel(UIStrings.text("toolbar.profile", "Profile"))
            .accessibilityValue(title)
    }

    private var initial: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "A"
    }
}
