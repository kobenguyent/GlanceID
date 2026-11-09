import XCTest
@testable import GlanceID

final class FaceRecognitionEngineTests: XCTestCase {
    var engine: FaceRecognitionEngine!
    
    override func setUp() {
        super.setUp()
        engine = FaceRecognitionEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    func testInitialStateIsIdle() {
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.landmarkData)
        XCTAssertNil(engine.lastDistance)
        XCTAssertFalse(engine.isAuthenticating)
        XCTAssertFalse(engine.isEnrolling)
    }
    
    func testStartAuthenticationSetsSearchingState() {
        engine.startAuthentication(threshold: 0.38, requireLiveness: true) { _, _, _ in }
        
        XCTAssertTrue(engine.isAuthenticating)
        XCTAssertEqual(engine.state, .searching)
        XCTAssertTrue(engine.requireLiveness)
    }
    
    func testResetRestoresDefaultState() {
        engine.startAuthentication(threshold: 0.35, requireLiveness: true) { _, _, _ in }
        XCTAssertTrue(engine.isAuthenticating)
        
        engine.reset()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertFalse(engine.isAuthenticating)
        XCTAssertNil(engine.landmarkData)
        XCTAssertNil(engine.lastDistance)
    }
    
    func testLastDistanceCanBePublishedAndReset() {
        engine.lastDistance = 0.285
        XCTAssertEqual(engine.lastDistance, 0.285)
        
        engine.reset()
        XCTAssertNil(engine.lastDistance)
    }
}
