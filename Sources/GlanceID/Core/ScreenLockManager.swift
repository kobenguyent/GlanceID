import Foundation
import AppKit
import SwiftUI

final class ScreenLockManager: ObservableObject {
    static let shared = ScreenLockManager()
    
    @Published var isMacBookLocked: Bool = false
    private var lockWindow: NSWindow?
    private var appState: AppState?
    private var glanceTimeoutItem: DispatchWorkItem?
    
    private init() {
        setupSystemNotifications()
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
            // On display wake, run a quick 2-second glance scan
            self.triggerFaceIDUnlock()
        }
    }
    
    // MARK: - Lock Screen Presentation
    func lockMacBook() {
        guard !isMacBookLocked else { return }
        guard let appState = self.appState else { return }
        
        isMacBookLocked = true
        
        // Ensure camera is OFF on initial lock. Do not turn on camera until user interacts.
        appState.cameraManager.stop()
        appState.glyphState = .idle
        
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let window = NSWindow(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = false
        
        let lockView = FullscreenLockScreenView(
            appState: appState,
            onUnlockRequested: { [weak self] in
                self?.triggerFaceIDUnlock()
            },
            onPasswordUnlocked: { [weak self] in
                self?.unlockMacBook()
            }
        )
        
        window.contentView = NSHostingView(rootView: lockView)
        window.makeKeyAndOrderFront(nil)
        self.lockWindow = window
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func unlockMacBook() {
        guard isMacBookLocked else { return }
        
        glanceTimeoutItem?.cancel()
        glanceTimeoutItem = nil
        appState?.cameraManager.stop()
        appState?.engine.reset()
        
        if let window = lockWindow {
            window.orderOut(nil)
            self.lockWindow = nil
            self.isMacBookLocked = false
            self.appState?.glyphState = .idle
        } else {
            isMacBookLocked = false
        }
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
        
        appState.engine.startAuthentication(threshold: appState.threshold) { [weak self, weak appState] matched, dist, name in
            guard let self = self, let appState = appState, self.isMacBookLocked else { return }
            
            self.glanceTimeoutItem?.cancel()
            self.glanceTimeoutItem = nil
            
            // Immediately shut off camera
            appState.cameraManager.stop()
            
            if matched {
                appState.glyphState = .success
                appState.soundManager.playFaceIDSuccess()
                // FullscreenLockScreenView.onChange triggers the slide-up animation and calls unlockMacBook
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
