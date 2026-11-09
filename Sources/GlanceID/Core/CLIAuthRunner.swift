import Foundation
import AVFoundation

final class CLIAuthRunner {
    static func run() -> Int32 {
        let storage = BiometricStorage.shared
        guard let stored = storage.loadProfile() else {
            fputs("[GlanceID] Error: No enrolled biometric profile found. Open GlanceID to enroll your face.\n", stderr)
            return 1
        }
        
        fputs("[GlanceID] Face ID: Glancing at camera...\n", stdout)
        
        let camera = CameraManager()
        let engine = FaceRecognitionEngine()
        camera.frameDelegate = engine
        
        let sema = DispatchSemaphore(value: 0)
        var authSuccess = false
        
        engine.startAuthentication(threshold: stored.profile.threshold) { matched, dist, name in
            camera.stop()
            if matched {
                fputs("[GlanceID] Face ID Matched: \(name ?? "User") (confidence distance: \(String(format: "%.3f", dist)))\n", stdout)
                SoundManager.shared.playFaceIDSuccess()
                authSuccess = true
            } else {
                fputs("[GlanceID] Face ID Failed: Face not recognized.\n", stderr)
                SoundManager.shared.playFaceIDFailure()
            }
            sema.signal()
        }
        
        camera.start()
        
        // Wait up to 5 seconds for glance recognition
        let timeout = sema.wait(timeout: .now() + 5.0)
        camera.stop()
        
        if timeout == .timedOut {
            fputs("[GlanceID] Face ID Timed out.\n", stderr)
            return 1
        }
        
        return authSuccess ? 0 : 1
    }
}
