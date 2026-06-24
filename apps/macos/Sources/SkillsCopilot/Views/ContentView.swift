import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
        } content: {
            SecondarySidebarView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 430)
        } detail: {
            DetailView(skill: store.selectedSkill)
        }
        .task {
            if store.status == nil && store.skills.isEmpty {
                await store.reload()
            }
        }
        .task(id: store.selectedAgentLocalSessionRefreshKey) {
            await store.refreshSelectedAgentLocalSessions()
        }
        .onChange(of: store.selectedSkillID) { _ in
            Task { await store.loadSelectedDetail() }
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
        .accessibilityIdentifier(AppAccessibilityID.mainContent)
        .accessibilityLabel(UIStrings.appWindowTitle)
    }
}
