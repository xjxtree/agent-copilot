import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    min: CGFloat(UIOptimizationPresentation.skillList.minimumPrimaryColumnWidth),
                    ideal: CGFloat(UIOptimizationPresentation.skillList.idealPrimaryColumnWidth),
                    max: CGFloat(UIOptimizationPresentation.skillList.maximumPrimaryColumnWidth)
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
