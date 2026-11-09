import XCTest
@testable import GlanceID

final class LivenessDetectorTests: XCTestCase {
    var detector: LivenessDetector!
    
    override func setUp() {
        super.setUp()
        detector = LivenessDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // Helper to generate simulated eyelid points
    // An eye with width 0.10 and height 0.035 -> Ratio ~0.35 (Wide Open)
    private func makeOpenEyePoints(centerX: CGFloat = 0.5, centerY: CGFloat = 0.5) -> [CGPoint] {
        return [
            CGPoint(x: centerX - 0.05, y: centerY),       // p1: outer corner
            CGPoint(x: centerX - 0.025, y: centerY + 0.0175), // p2: upper eyelid
            CGPoint(x: centerX + 0.025, y: centerY + 0.0175), // p3: upper eyelid
            CGPoint(x: centerX + 0.05, y: centerY),       // p4: inner corner
            CGPoint(x: centerX + 0.025, y: centerY - 0.0175), // p5: lower eyelid
            CGPoint(x: centerX - 0.025, y: centerY - 0.0175)  // p6: lower eyelid
        ]
    }
    
    // An eye with width 0.10 and height 0.008 -> Ratio ~0.08 (Blinking / Closed)
    private func makeClosedEyePoints(centerX: CGFloat = 0.5, centerY: CGFloat = 0.5) -> [CGPoint] {
        return [
            CGPoint(x: centerX - 0.05, y: centerY),
            CGPoint(x: centerX - 0.025, y: centerY + 0.004),
            CGPoint(x: centerX + 0.025, y: centerY + 0.004),
            CGPoint(x: centerX + 0.05, y: centerY),
            CGPoint(x: centerX + 0.025, y: centerY - 0.004),
            CGPoint(x: centerX - 0.025, y: centerY - 0.004)
        ]
    }
    
    func testInitialStateIsUnverified() {
        XCTAssertEqual(detector.state, .unverified)
        XCTAssertFalse(detector.isLivenessConfirmed)
    }
    
    func testOpenEyesRemainUnverifiedUntilBlink() {
        let left = makeOpenEyePoints(centerX: 0.4)
        let right = makeOpenEyePoints(centerX: 0.6)
        let nose = [CGPoint(x: 0.5, y: 0.5)]
        
        let passed = detector.processLandmarks(leftEye: left, rightEye: right, nose: nose)
        
        XCTAssertFalse(passed)
        XCTAssertFalse(detector.isLivenessConfirmed)
        if case .eyesOpen(let ear) = detector.state {
            XCTAssertGreaterThan(ear, 0.20)
        } else {
            XCTFail("Expected state to be .eyesOpen, got \(detector.state)")
        }
    }
    
    func testCompleteBlinkCycleConfirmsLiveness() {
        let leftOpen = makeOpenEyePoints(centerX: 0.4)
        let rightOpen = makeOpenEyePoints(centerX: 0.6)
        let nose = [CGPoint(x: 0.5, y: 0.5)]
        
        // Frame 1: Eyes open
        _ = detector.processLandmarks(leftEye: leftOpen, rightEye: rightOpen, nose: nose)
        XCTAssertFalse(detector.isLivenessConfirmed)
        
        // Frame 2: Eyes close (Blink)
        let leftClosed = makeClosedEyePoints(centerX: 0.4)
        let rightClosed = makeClosedEyePoints(centerX: 0.6)
        _ = detector.processLandmarks(leftEye: leftClosed, rightEye: rightClosed, nose: nose)
        XCTAssertEqual(detector.state, .blinkDetected)
        XCTAssertFalse(detector.isLivenessConfirmed)
        
        // Frame 3: Eyes re-open
        let passed = detector.processLandmarks(leftEye: leftOpen, rightEye: rightOpen, nose: nose)
        XCTAssertTrue(passed)
        XCTAssertTrue(detector.isLivenessConfirmed)
        XCTAssertEqual(detector.state, .passed)
    }
    
    func testZeroVarianceStaticPhotoTriggersSpoofDetection() {
        let left = makeOpenEyePoints(centerX: 0.4)
        let right = makeOpenEyePoints(centerX: 0.6)
        let staticNose = [CGPoint(x: 0.5, y: 0.5)]
        
        // Feed 25 consecutive identical frames with zero micro-motion and no blink
        for _ in 1...25 {
            _ = detector.processLandmarks(leftEye: left, rightEye: right, nose: staticNose)
        }
        
        if case .suspectStaticImage(let reason) = detector.state {
            XCTAssertTrue(reason.contains("Static image detected"))
        } else {
            XCTFail("Expected .suspectStaticImage due to zero coordinate variance, got \(detector.state)")
        }
        XCTAssertFalse(detector.isLivenessConfirmed)
    }
    
    func testResetClearsLivenessConfirmation() {
        let leftOpen = makeOpenEyePoints(centerX: 0.4)
        let rightOpen = makeOpenEyePoints(centerX: 0.6)
        let nose = [CGPoint(x: 0.5, y: 0.5)]
        
        // Trigger liveness pass
        _ = detector.processLandmarks(leftEye: leftOpen, rightEye: rightOpen, nose: nose)
        let leftClosed = makeClosedEyePoints(centerX: 0.4)
        let rightClosed = makeClosedEyePoints(centerX: 0.6)
        _ = detector.processLandmarks(leftEye: leftClosed, rightEye: rightClosed, nose: nose)
        _ = detector.processLandmarks(leftEye: leftOpen, rightEye: rightOpen, nose: nose)
        XCTAssertTrue(detector.isLivenessConfirmed)
        
        // Reset
        detector.reset()
        XCTAssertEqual(detector.state, .unverified)
        XCTAssertFalse(detector.isLivenessConfirmed)
    }
}
