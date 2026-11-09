import Foundation
import SwiftUI
import Combine

enum AppTab: String, CaseIterable, Identifiable {
    case simulator = "Face ID HUD"
    case lockScreen = "Lock MacBook"
    case scanner = "Neural Scanner"
    case enrollment = "Enroll Face"
    case vault = "Protected Vault"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .simulator: return "faceid"
        case .lockScreen: return "laptopcomputer.and.arrow.down"
        case .scanner: return "viewfinder"
        case .enrollment: return "person.badge.plus"
        case .vault: return "lock.shield"
        case .settings: return "gearshape"
        }
    }
}

final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var selectedTab: AppTab = .simulator
    
    // Services
    let cameraManager = CameraManager()
    let engine = FaceRecognitionEngine()
    let soundManager = SoundManager.shared
    let storage = BiometricStorage.shared
    
    // Authentication HUD state
    @Published var isHUDActive: Bool = false
    @Published var glyphState: GlyphState = .idle
    @Published var hudTitle: String = "GlanceID"
    @Published var hudSubtitle: String = "Simulating Face ID on macOS"
    
    // Biometric Profile & Settings
    @Published var isEnrolled: Bool = false
    @Published var enrolledName: String = ""
    @Published var enrolledDate: Date? = nil
    @Published var threshold: Float = 0.42
    @Published var isCameraMirrored: Bool = true
    @Published var requireLiveness: Bool = false
    
    // Vault State
    @Published var isVaultUnlocked: Bool = false
    @Published var lastUnlockTime: Date? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Connect camera frames to face recognition engine
        cameraManager.frameDelegate = engine
        
        // Forward camera manager updates so views observing AppState receive camera state changes
        cameraManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        loadEnrolledProfile()
        ScreenLockManager.shared.configure(with: self)
        
        // Listen to engine state updates
        engine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleEngineState(state)
            }
            .store(in: &cancellables)
            
        // Manage camera power lifecycle across tabs: only keep camera active when needed
        $selectedTab
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTab in
                guard let self = self else { return }
                if newTab != .scanner && newTab != .enrollment && !self.isHUDActive {
                    self.cameraManager.stop()
                    self.engine.reset()
                }
            }
            .store(in: &cancellables)
            
        // Proactively verify camera access permission without turning the camera on
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            NSApplication.shared.activate(ignoringOtherApps: true)
            self?.cameraManager.requestAccess()
        }
    }
    
    func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func loadEnrolledProfile() {
        if let stored = storage.loadProfile() {
            self.isEnrolled = true
            self.enrolledName = stored.profile.userName
            self.enrolledDate = stored.profile.enrolledAt
            self.threshold = stored.profile.threshold
        } else {
            self.isEnrolled = false
            self.enrolledName = ""
            self.enrolledDate = nil
        }
    }
    
    // MARK: - Face ID Authentication Trigger
    func triggerAuthentication(onSuccess: (() -> Void)? = nil) {
        guard !isHUDActive else { return }
        
        guard isEnrolled else {
            isHUDActive = true
            glyphState = .failure
            hudTitle = "No Face Enrolled"
            hudSubtitle = "Please enroll your face first."
            soundManager.playFaceIDFailure()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                withAnimation {
                    self?.isHUDActive = false
                    self?.glyphState = .idle
                    self?.selectedTab = .enrollment
                }
            }
            return
        }
        
        isHUDActive = true
        glyphState = .scanning
        hudTitle = "GlanceID"
        hudSubtitle = requireLiveness ? "Glance at camera & blink..." : "Glance at your Mac camera..."
        
        cameraManager.start()
        
        // Timeout if no face found after 9 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) { [weak self] in
            guard let self = self, self.isHUDActive, self.glyphState == .scanning else { return }
            self.handleAuthenticationFailure(message: "Face ID Timed Out")
        }
        
        engine.startAuthentication(threshold: threshold, requireLiveness: requireLiveness) { [weak self] success, distance, userName in
            guard let self = self else { return }
            
            // Immediately shut off camera as soon as verification completes
            self.cameraManager.stop()
            
            if success {
                self.glyphState = .success
                self.hudTitle = "Welcome, \(userName ?? "User")"
                self.hudSubtitle = String(format: "Match Confirmed (dist: %.2f)", distance)
                self.soundManager.playFaceIDSuccess()
                self.isVaultUnlocked = true
                self.lastUnlockTime = Date()
                onSuccess?()
                
                // Auto dismiss HUD after brief celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation {
                        self.isHUDActive = false
                        self.glyphState = .idle
                    }
                }
            } else {
                self.handleAuthenticationFailure(message: "Face Not Recognized")
            }
        }
    }
    
    func cancelAuthentication() {
        cameraManager.stop()
        isHUDActive = false
        glyphState = .idle
        engine.reset()
    }
    
    private func handleAuthenticationFailure(message: String) {
        cameraManager.stop()
        self.glyphState = .failure
        self.hudTitle = "Try Again"
        self.hudSubtitle = message
        self.soundManager.playFaceIDFailure()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            withAnimation {
                self?.isHUDActive = false
                self?.glyphState = .idle
                self?.engine.reset()
            }
        }
    }
    
    // MARK: - Enrollment
    func enrollUser(name: String, completion: @escaping (Bool, String) -> Void) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            completion(false, "Please provide a valid name.")
            return
        }
        
        cameraManager.start()
        engine.startEnrollment { [weak self] result in
            guard let self = self else { return }
            self.cameraManager.stop()
            switch result {
            case .success(let observation):
                do {
                    try self.storage.saveProfile(userName: cleanName, observation: observation, threshold: self.threshold)
                    self.loadEnrolledProfile()
                    self.soundManager.playFaceIDSuccess()
                    completion(true, "Face profile saved successfully!")
                } catch {
                    completion(false, "Storage error: \(error.localizedDescription)")
                }
            case .failure(let error):
                self.soundManager.playFaceIDFailure()
                completion(false, error.localizedDescription)
            }
        }
    }
    
    func resetBiometrics() {
        storage.deleteProfile()
        loadEnrolledProfile()
        isVaultUnlocked = false
        engine.reset()
    }
    
    private func handleEngineState(_ state: RecognitionState) {
        switch state {
        case .searching:
            if isHUDActive && glyphState == .scanning {
                hudSubtitle = "Detecting face..."
            }
        case .tracking(let quality):
            if isHUDActive && glyphState == .scanning {
                if quality < 0.4 {
                    hudSubtitle = "Position face in good lighting"
                } else {
                    hudSubtitle = "Analyzing facial geometry..."
                }
            }
        case .analyzing:
            if isHUDActive && glyphState == .scanning {
                hudSubtitle = requireLiveness ? "Face matched! Blink to confirm..." : "Analyzing facial geometry..."
            }
        case .authenticated, .unrecognized, .idle, .noFaceDetected:
            break
        }
    }
}
