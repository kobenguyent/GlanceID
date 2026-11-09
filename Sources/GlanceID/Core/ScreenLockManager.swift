import Foundation
import AppKit
import SwiftUI

final class ScreenLockManager: ObservableObject {
    static let shared = ScreenLockManager()
    
    @Published var isMacBookLocked: Bool = false
    private var lockWindows: [NSWindow] = []
    private var appState: AppState?
    private var glanceTimeoutItem: DispatchWorkItem?
    
    private init() {
        setupSystemNotifications()
        setupGlobalHotkey()
    }
    
    private func setupGlobalHotkey() {
        // Global hotkey: Option + Command + L (⌥⌘L) locks screen from any application
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.option, .command]) && event.charactersIgnoringModifiers?.lowercased() == "l" {
                DispatchQueue.main.async {
                    self?.lockMacBook()
                }
            }
        }
    }
    
    func configure(with appState: AppState) {
        self.appState = appState
    }
    
    private func setupSystemNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDisplayWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        // Listen to display connect/disconnect or arrangement changes to adapt multi-screen coverage
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func handleScreenLocked() {
        DispatchQueue.main.async { [weak self] in
            // When real screen is locked, ensure camera is OFF
            self?.appState?.cameraManager.stop()
        }
    }
    
    @objc private func handleScreenUnlocked() {
        DispatchQueue.main.async { [weak self] in
            if self?.isMacBookLocked == true {
                self?.unlockMacBook()
            }
        }
    }
    
    @objc private func handleDisplayWake() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isMacBookLocked else { return }
            // On display wake, run a quick glance scan
            self.triggerFaceIDUnlock()
        }
    }
    
    @objc private func handleScreenParametersChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isMacBookLocked else { return }
            // Displays plugged/unplugged or resolutions changed while locked: re-cover all screens
            self.recreateLockWindows()
        }
    }
    
    // MARK: - Multi-Screen Lock Presentation
    func lockMacBook() {
        guard !isMacBookLocked else { return }
        guard let appState = self.appState else { return }
        
        isMacBookLocked = true
        
        // Ensure camera is OFF on initial lock. Do not turn on camera until user interacts.
        appState.cameraManager.stop()
        appState.glyphState = .idle
        
        // Reload wallpapers for all attached displays
        WallpaperProvider.shared.reloadWallpaper()
        
        recreateLockWindows()
    }
    
    private func recreateLockWindows() {
        guard let appState = self.appState else { return }
        
        // Order out and clean any previous windows
        for window in lockWindows {
            window.orderOut(nil)
        }
        lockWindows.removeAll()
        
        // Query all attached monitors
        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        let primaryScreen = NSScreen.main ?? screens.first
        
        for screen in screens {
            let isPrimary = (screen == primaryScreen)
            let window = createLockWindow(for: screen, isPrimary: isPrimary, appState: appState)
            lockWindows.append(window)
        }
        
        // Display all lock windows across every connected monitor at screensaver level
        for window in lockWindows {
            window.orderFrontRegardless()
        }
        
        // Focus the primary screen window for keyboard and password input
        if let primaryWindow = lockWindows.first(where: { ($0.screen ?? NSScreen.main) == primaryScreen }) {
            primaryWindow.makeKeyAndOrderFront(nil)
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func createLockWindow(for screen: NSScreen, isPrimary: Bool, appState: AppState) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.setFrame(screen.frame, display: true)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.backgroundColor = .black
        
        let lockView = FullscreenLockScreenView(
            appState: appState,
            screen: screen,
            isPrimary: isPrimary,
            onUnlockRequested: { [weak self] in
                self?.triggerFaceIDUnlock()
            },
            onPasswordUnlocked: { [weak self] in
                self?.unlockMacBook()
            }
        )
        
        window.contentView = NSHostingView(rootView: lockView)
        return window
    }
    
    func unlockMacBook() {
        guard isMacBookLocked else { return }
        
        glanceTimeoutItem?.cancel()
        glanceTimeoutItem = nil
        appState?.cameraManager.stop()
        appState?.engine.reset()
        
        for window in lockWindows {
            window.orderOut(nil)
        }
        lockWindows.removeAll()
        
        isMacBookLocked = false
        appState?.glyphState = .idle
    }
    
    /// Bounded Face ID glance: runs camera for max 2.5 seconds, then immediately cuts camera power
    func triggerFaceIDUnlock() {
        guard let appState = self.appState, isMacBookLocked else { return }
        guard appState.isEnrolled else { return }
        guard !appState.cameraManager.isRunning else { return }
        
        appState.glyphState = .scanning
        appState.cameraManager.start()
        
        // Safety timeout: automatically kill camera after 2.5 seconds if no match
        let timeoutItem = DispatchWorkItem { [weak self, weak appState] in
            guard let self = self, let appState = appState, self.isMacBookLocked else { return }
            if appState.glyphState == .scanning {
                appState.cameraManager.stop()
                appState.engine.reset()
                appState.glyphState = .failure
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if self.isMacBookLocked && appState.glyphState == .failure {
                        appState.glyphState = .idle
                    }
                }
            }
        }
        self.glanceTimeoutItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: timeoutItem)
        
        appState.engine.startAuthentication(threshold: appState.threshold, requireLiveness: appState.requireLiveness) { [weak self, weak appState] matched, dist, name in
            guard let self = self, let appState = appState, self.isMacBookLocked else { return }
            
            self.glanceTimeoutItem?.cancel()
            self.glanceTimeoutItem = nil
            
            // Immediately shut off camera
            appState.cameraManager.stop()
            
            if matched {
                appState.glyphState = .success
                appState.soundManager.playFaceIDSuccess()
                // FullscreenLockScreenView.onChange triggers the synchronized slide-up animation across all screens
            } else {
                appState.glyphState = .failure
                appState.soundManager.playFaceIDFailure()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if self.isMacBookLocked {
                        appState.glyphState = .idle
                    }
                }
            }
        }
    }
}
