import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SkillStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            DetailView(skill: store.selectedSkill)
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: UIStrings.searchPrompt)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.scanAll() }
                } label: {
                    Label(UIStrings.scan, systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isRefreshBusy)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.reload() }
                } label: {
                    Label(UIStrings.reload, systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshBusy)
            }
        }
        .task {
            if store.status == nil && store.skills.isEmpty {
                await store.reload()
            }
        }
        .onChange(of: store.selectedSkillID) { _ in
            Task { await store.loadSelectedDetail() }
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }
}
