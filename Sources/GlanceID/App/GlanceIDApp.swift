import SwiftUI

@main
struct GlanceIDApp: App {
    @StateObject private var appState = AppState.shared
    
    init() {
        if CommandLine.arguments.contains("--verify") {
            let exitCode = CLIAuthRunner.run()
            exit(exitCode)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .frame(minWidth: 780, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandMenu("GlanceID") {
                Button("Lock MacBook Screen (⌥⌘L)") {
                    ScreenLockManager.shared.lockMacBook()
                }
                .keyboardShortcut("l", modifiers: [.option, .command])
            }
        }
        
        MenuBarExtra("GlanceID", systemImage: "faceid") {
            Button("Lock MacBook Screen (⌥⌘L)") {
                ScreenLockManager.shared.lockMacBook()
            }
            .keyboardShortcut("l", modifiers: [.option, .command])
            
            Divider()
            
            Button("Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where !(window is NSPanel) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            Divider()
            
            Button("Quit GlanceID") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            List(AppTab.allCases, selection: $appState.selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch appState.selectedTab {
            case .simulator:
                AuthenticationView(appState: appState)
            case .lockScreen:
                LockScreenHubView(appState: appState)
            case .scanner:
                ScannerView(appState: appState)
            case .enrollment:
                EnrollmentView(appState: appState)
            case .vault:
                VaultView(appState: appState)
            case .settings:
                SettingsView(appState: appState)
            }
        }
    }
}
