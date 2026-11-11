import XCTest
import SwiftUI
@testable import GlanceID

final class FullscreenLockScreenViewTests: XCTestCase {
    func testLockScreenInstantiatesWithCentralScan() {
        let appState = AppState()
        let view = FullscreenLockScreenView(
            appState: appState,
            screen: nil,
            isPrimary: true,
            onUnlockRequested: {},
            onPasswordUnlocked: {}
        )
        XCTAssertNotNil(view)
    }

    func testLockScreenInstantiatesSecondaryScreen() {
        let appState = AppState()
        let view = FullscreenLockScreenView(
            appState: appState,
            screen: nil,
            isPrimary: false,
            onUnlockRequested: {},
            onPasswordUnlocked: {}
        )
        XCTAssertNotNil(view)
    }

    func testLockScreenWithScanningGlyphState() {
        let appState = AppState()
        appState.glyphState = .scanning
        let view = FullscreenLockScreenView(
            appState: appState,
            screen: nil,
            isPrimary: true,
            onUnlockRequested: {},
            onPasswordUnlocked: {}
        )
        XCTAssertNotNil(view)
    }

    func testLockScreenWithSuccessGlyphState() {
        let appState = AppState()
        appState.glyphState = .success
        let view = FullscreenLockScreenView(
            appState: appState,
            screen: nil,
            isPrimary: true,
            onUnlockRequested: {},
            onPasswordUnlocked: {}
        )
        XCTAssertNotNil(view)
    }

    func testLockScreenWithFailureGlyphState() {
        let appState = AppState()
        appState.glyphState = .failure
        let view = FullscreenLockScreenView(
            appState: appState,
            screen: nil,
            isPrimary: true,
            onUnlockRequested: {},
            onPasswordUnlocked: {}
        )
        XCTAssertNotNil(view)
    }

    func testAuthenticationViewWithHUDActive() {
        let appState = AppState()
        appState.isHUDActive = true
        appState.glyphState = .scanning
        let view = AuthenticationView(appState: appState)
        XCTAssertNotNil(view)
    }

    func testAuthenticationViewWithHUDInactive() {
        let appState = AppState()
        appState.isHUDActive = false
        let view = AuthenticationView(appState: appState)
        XCTAssertNotNil(view)
    }
}
