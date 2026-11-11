import XCTest
import Combine
@testable import GlanceID

final class FaceRecognitionTelemetryTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    func testTelemetryDefaults() {
        let appState = AppState()
        XCTAssertNil(appState.currentLandmarks)
        XCTAssertFalse(appState.isFaceTracked)
        XCTAssertEqual(appState.scanQuality, 0.0)
    }
    
    func testTelemetryForwardsEngineLandmarks() {
        let appState = AppState()
        let expectation = expectation(description: "Telemetry updates when engine produces landmarks")
        
        let sampleLandmarks = FaceLandmarkData(
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            roll: 0.0,
            yaw: 0.0,
            quality: 0.85,
            leftEye: [CGPoint(x: 0.35, y: 0.6)],
            rightEye: [CGPoint(x: 0.65, y: 0.6)],
            nose: [CGPoint(x: 0.5, y: 0.5)],
            lips: [CGPoint(x: 0.5, y: 0.3)],
            contour: []
        )
        
        appState.$currentLandmarks
            .compactMap { $0 }
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
            
        appState.engine.landmarkData = sampleLandmarks
        
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(appState.isFaceTracked)
        XCTAssertEqual(appState.scanQuality, 0.85)
        XCTAssertEqual(appState.currentLandmarks?.quality, 0.85)
    }
    
    func testTelemetryClearsWhenEngineResets() {
        let appState = AppState()
        let setExpectation = expectation(description: "Telemetry set")
        
        let sampleLandmarks = FaceLandmarkData(
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            roll: 0.0,
            yaw: 0.0,
            quality: 0.75,
            leftEye: [],
            rightEye: [],
            nose: [],
            lips: [],
            contour: []
        )
        
        appState.$isFaceTracked
            .filter { $0 == true }
            .first()
            .sink { _ in
                setExpectation.fulfill()
            }
            .store(in: &cancellables)
            
        appState.engine.landmarkData = sampleLandmarks
        wait(for: [setExpectation], timeout: 1.0)
        
        let resetExpectation = expectation(description: "Telemetry clears on reset")
        appState.$isFaceTracked
            .filter { $0 == false }
            .first()
            .sink { _ in
                resetExpectation.fulfill()
            }
            .store(in: &cancellables)
            
        appState.engine.reset()
        wait(for: [resetExpectation], timeout: 1.0)
        
        XCTAssertNil(appState.currentLandmarks)
        XCTAssertFalse(appState.isFaceTracked)
        XCTAssertEqual(appState.scanQuality, 0.0)
    }
    
    func testEngineHasMinimumAuthenticationDwellConfigured() {
        let engine = FaceRecognitionEngine()
        XCTAssertEqual(engine.minAuthenticationDwell, 0.35, accuracy: 0.001)
    }
    
    func testAuthenticationPacingTimestampRecorded() {
        let engine = FaceRecognitionEngine()
        XCTAssertNil(engine.authStartTime)
        XCTAssertNil(engine.faceAcquiredTime)
        
        let start = Date()
        engine.startAuthentication { _, _, _ in }
        
        XCTAssertNotNil(engine.authStartTime)
        if let authStartTime = engine.authStartTime {
            XCTAssertGreaterThanOrEqual(authStartTime, start)
        }
        
        engine.reset()
        XCTAssertNil(engine.authStartTime)
        XCTAssertNil(engine.faceAcquiredTime)
    }
}
