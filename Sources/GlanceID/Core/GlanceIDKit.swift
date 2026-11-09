import Foundation
import LocalAuthentication

/// GlanceIDKit: A drop-in biometric authentication replacement for Apple's LocalAuthentication (LAContext).
/// Developers can use GlanceIDContext identically to LAContext to add Face ID to any macOS app.
public final class GlanceIDContext {
    public var localizedCancelTitle: String?
    public var localizedFallbackTitle: String?
    
    public init() {}
    
    /// Checks if Face ID biometrics are enrolled and available on this Mac
    public func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer = nil) -> Bool {
        return BiometricStorage.shared.isEnrolled
    }
    
    /// Evaluates Face ID facial biometric policy with animated HUD and camera glance
    public func evaluatePolicy(
        _ policy: LAPolicy,
        localizedReason: String,
        reply: @escaping (Bool, Error?) -> Void
    ) {
        DispatchQueue.main.async {
            guard BiometricStorage.shared.isEnrolled else {
                let err = NSError(
                    domain: "com.glanceid.kit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No face enrolled in GlanceID."]
                )
                reply(false, err)
                return
            }
            
            // Present Face ID authentication HUD
            AppState.shared.triggerAuthentication {
                reply(true, nil)
            }
        }
    }
}
