import Foundation
import AppKit
import SwiftUI

final class ScreenLockManager: ObservableObject {
    static let shared = ScreenLockManager()
    
    @Published var isMacBookLocked: Bool = false
    private var lockWindow: NSWindow?
    private var appState: AppState?
    
    private init() {
        setupSystemNotifications()
    }
    
    func configure(with appState: AppState) {
        self.appState = appState
    }
    
    private func setupSystemNotifications() {
        // Observe real macOS lock screen events
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
        DispatchQueue.main.async {
            print("[GlanceID] Real macOS screen locked event detected.")
        }
    }
    
    @objc private func handleScreenUnlocked() {
        DispatchQueue.main.async {
            print("[GlanceID] Real macOS screen unlocked event detected.")
            if self.isMacBookLocked {
                self.unlockMacBook()
            }
        }
    }
    
    @objc private func handleDisplayWake() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isMacBookLocked else { return }
            print("[GlanceID] Screen woke up. Triggering Face ID glance...")
            self.triggerFaceIDUnlock()
        }
    }
    
    // MARK: - Lock Screen Presentation
    func lockMacBook() {
        guard !isMacBookLocked else { return }
        guard let appState = self.appState else { return }
        
        isMacBookLocked = true
        
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
        
        // Bring to front and immediately initiate Face ID glance
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.triggerFaceIDUnlock()
        }
    }
    
    func unlockMacBook() {
        guard isMacBookLocked else { return }
        
        // Smooth slide up & fade out animation
        if let window = lockWindow {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                window.orderOut(nil)
                self?.lockWindow = nil
                self?.isMacBookLocked = false
                self?.appState?.cameraManager.stop()
            })
        } else {
            isMacBookLocked = false
        }
    }
    
    func triggerFaceIDUnlock() {
        guard let appState = self.appState, isMacBookLocked else { return }
        
        appState.triggerAuthentication { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self?.unlockMacBook()
            }
        }
    }
}
