import XCTest
import SwiftUI
@testable import GlanceID

final class CentralFaceIDScanViewTests: XCTestCase {
    func testCentralScanViewStateResolution() {
        let appState = AppState()
        let scanView = CentralFaceIDScanView(appState: appState, size: 150)
        XCTAssertNotNil(scanView)
        
        // Searching state when scanning and no face is tracked
        appState.glyphState = .scanning
        appState.isFaceTracked = false
        XCTAssertEqual(scanView.visualState, .searching)
        
        // Tracking state when face is tracked without liveness requirement
        appState.isFaceTracked = true
        appState.requireLiveness = false
        XCTAssertEqual(scanView.visualState, .tracking)
        
        // Liveness state when face is tracked and liveness challenge is active
        appState.requireLiveness = true
        XCTAssertEqual(scanView.visualState, .liveness)
        
        // Success state
        appState.glyphState = .success
        XCTAssertEqual(scanView.visualState, .success)
        
        // Failure state
        appState.glyphState = .failure
        XCTAssertEqual(scanView.visualState, .failure)
    }

    func testCaptionsForStates() {
        XCTAssertEqual(CentralFaceIDScanView.caption(for: .searching), "Looking for face...")
        XCTAssertEqual(CentralFaceIDScanView.caption(for: .tracking), "Face Captured • Verifying...")
        XCTAssertEqual(CentralFaceIDScanView.caption(for: .liveness), "Blink naturally to unlock")
        XCTAssertEqual(CentralFaceIDScanView.caption(for: .failure), "Position Face in Camera")
        XCTAssertFalse(CentralFaceIDScanView.caption(for: .success).isEmpty)
    }

    func testCustomSizeInitialization() {
        let appState = AppState()
        let scanView = CentralFaceIDScanView(appState: appState, size: 160)
        XCTAssertEqual(scanView.size, 160)
    }

    func testOverrideVisualState() {
        let appState = AppState()
        appState.glyphState = .scanning
        appState.isFaceTracked = false
        
        let overrideView = CentralFaceIDScanView(appState: appState, size: 150, overrideState: .tracking)
        XCTAssertEqual(overrideView.visualState, .tracking)
    }

    func testResolveStateWhenLivenessConfirmed() {
        let state = CentralFaceIDScanView.resolveState(
            glyphState: .scanning,
            isFaceTracked: true,
            requireLiveness: true,
            livenessConfirmed: true
        )
        XCTAssertEqual(state, .tracking)
    }

    func testIdleGlyphStateResolvesToSearching() {
        let state = CentralFaceIDScanView.resolveState(
            glyphState: .idle,
            isFaceTracked: false,
            requireLiveness: false
        )
        XCTAssertEqual(state, .searching)
    }
}
