import XCTest
import Combine
@testable import GlanceID

final class AppStateTests: XCTestCase {
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        appState = nil
        super.tearDown()
    }
    
    func testCameraManagerChangesPropagateToAppState() {
        let expectation = expectation(description: "AppState objectWillChange should fire when cameraManager changes")
        
        appState.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
            
        // Trigger a change on cameraManager
        appState.cameraManager.isRunning = true
        
        waitForExpectations(timeout: 1.0)
    }
}

