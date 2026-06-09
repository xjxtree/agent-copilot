import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SkillsCopilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = SkillStore(service: ServiceClient())

    var body: some Scene {
        WindowGroup(UIStrings.appTitle) {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 600)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(UIStrings.menuScanSkills) {
                    Task { await store.scanAll() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.isRefreshBusy)

                Button(UIStrings.menuReloadSkills) {
                    Task { await store.reload() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.isRefreshBusy)
            }

            CommandMenu(UIStrings.menuSkills) {
                Button(UIStrings.menuShowOverview) {
                    store.selectedDetailSection = .overview
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button(UIStrings.menuShowFindings) {
                    store.selectedDetailSection = .findings
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button(UIStrings.menuShowConflicts) {
                    store.selectedDetailSection = .conflicts
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button(UIStrings.menuShowSnapshots) {
                    store.selectedDetailSection = .snapshots
                }
                .keyboardShortcut("4", modifiers: [.command])

                Divider()

                Button(UIStrings.menuClearSearch) {
                    store.searchText = ""
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
