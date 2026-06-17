import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainWindowCoordinator.activateApplication()
        DispatchQueue.main.async {
            MainWindowCoordinator.restoreMainWindow()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        MainWindowCoordinator.configureWindows(NSApp.windows)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DispatchQueue.main.async {
            MainWindowCoordinator.restoreMainWindow(in: sender)
        }
        return true
    }
}

@main
struct SkillsCopilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = SkillStore(service: ServiceClient())
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.defaultLanguage.rawValue

    var body: some Scene {
        let appLanguage = UIStrings.use(AppLanguage.fromStorage(appLanguageRawValue))

        WindowGroup(UIStrings.appWindowTitle) {
            ContentView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                .id(appLanguage.rawValue)
                .frame(minWidth: 920, minHeight: 600)
                .background(MainWindowConfigurator())
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
                Button(UIStrings.text("menu.showLineup", "Show Lineup")) {
                    store.selectedDetailSection = .lineup
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button(UIStrings.text("menu.showAgentProfile", "Show Agent Profile")) {
                    store.selectedDetailSection = .agentProfile
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button(UIStrings.menuShowTaskCockpit) {
                    store.selectedDetailSection = .taskCockpit
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button(UIStrings.menuShowOverview) {
                    store.selectedDetailSection = .overview
                }
                .keyboardShortcut("4", modifiers: [.command])

                Button(UIStrings.menuShowFindings) {
                    store.selectedDetailSection = .findings
                }
                .keyboardShortcut("5", modifiers: [.command])

                Button(UIStrings.menuShowConflicts) {
                    store.selectedDetailSection = .conflicts
                }
                .keyboardShortcut("6", modifiers: [.command])

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
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                .id(appLanguage.rawValue)
        }
    }
}
