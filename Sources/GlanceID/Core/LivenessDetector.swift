import Foundation
import CoreGraphics
import Vision

public enum LivenessState: Equatable {
    case unverified
    case eyesOpen(ear: Float)
    case blinkDetected
    case passed
    case suspectStaticImage(reason: String)
}

final class LivenessDetector: ObservableObject {
    @Published var state: LivenessState = .unverified
    @Published var isLivenessConfirmed: Bool = false
    
    // History buffer for detecting blink transitions
    private var earHistory: [Float] = []
    private var landmarkPointsHistory: [CGPoint] = []
    private var hasSeenEyeClosed = false
    private let historyLimit = 30
    
    // Eye openness ratio thresholds (height / width)
    private let eyeOpenThreshold: Float = 0.19
    private let eyeClosedThreshold: Float = 0.12
    
    func reset() {
        state = .unverified
        isLivenessConfirmed = false
        earHistory.removeAll()
        landmarkPointsHistory.removeAll()
        hasSeenEyeClosed = false
    }
    
    /// Evaluates facial landmarks to verify natural human liveness (blink & micro-movements)
    func processLandmarks(leftEye: [CGPoint], rightEye: [CGPoint], nose: [CGPoint]) -> Bool {
        guard !leftEye.isEmpty, !rightEye.isEmpty else {
            return false
        }
        
        let leftRatio = computeEyeOpennessRatio(points: leftEye)
        let rightRatio = computeEyeOpennessRatio(points: rightEye)
        let avgRatio = (leftRatio + rightRatio) / 2.0
        
        earHistory.append(avgRatio)
        if earHistory.count > historyLimit {
            earHistory.removeFirst()
        }
        
        // Track nose landmark to measure micro-movement variance
        if let noseTip = nose.first {
            landmarkPointsHistory.append(noseTip)
            if landmarkPointsHistory.count > historyLimit {
                landmarkPointsHistory.removeFirst()
            }
        }
        
        // 1. Detect dynamic eye state transition: Open -> Closed (Blink) -> Open
        if avgRatio < eyeClosedThreshold {
            hasSeenEyeClosed = true
            state = .blinkDetected
        } else if avgRatio > eyeOpenThreshold && hasSeenEyeClosed {
            // A complete natural human blink cycle has occurred!
            isLivenessConfirmed = true
            state = .passed
            return true
        }
        
        // 2. Check for suspicious zero-variance static photo
        if landmarkPointsHistory.count >= 20 {
            let movementVariance = computeMotionVariance()
            if movementVariance < 0.0000005 && !hasSeenEyeClosed {
                // Static printed photo held rigidly in front of webcam with zero natural head tremor
                state = .suspectStaticImage(reason: "Static image detected (zero micro-motion)")
                return false
            }
        }
        
        if isLivenessConfirmed {
            state = .passed
            return true
        } else {
            state = .eyesOpen(ear: avgRatio)
            return false
        }
    }
    
    /// Computes eye openness ratio using both landmark bounding box and Euclidean distances
    private func computeEyeOpennessRatio(points: [CGPoint]) -> Float {
        guard points.count >= 4 else { return 0.25 }
        
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        
        for pt in points {
            minX = min(minX, pt.x)
            maxX = max(maxX, pt.x)
            minY = min(minY, pt.y)
            maxY = max(maxY, pt.y)
        }
        
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0.0001 else { return 0.25 }
        
        return Float(height / width)
    }
    
    private func computeMotionVariance() -> Float {
        guard landmarkPointsHistory.count > 1 else { return 1.0 }
        let xs = landmarkPointsHistory.map { $0.x }
        let mean = xs.reduce(0, +) / CGFloat(xs.count)
        let sumSquared = xs.reduce(0) { $0 + pow($1 - mean, 2) }
        return Float(sumSquared / CGFloat(xs.count))
    }
}
