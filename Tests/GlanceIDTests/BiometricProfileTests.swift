import XCTest
@testable import GlanceID

final class BiometricProfileTests: XCTestCase {
    
    func testBiometricProfileCodableRoundtrip() throws {
        let dummyData = "mock-feature-print-data".data(using: .utf8)!
        let originalDate = Date(timeIntervalSince1970: 1700000000) // Deterministic timestamp
        
        let profile = BiometricProfile(
            userName: "Alice Developer",
            enrolledAt: originalDate,
            featurePrintData: dummyData,
            threshold: 0.42
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedData = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedProfile = try decoder.decode(BiometricProfile.self, from: encodedData)
        
        XCTAssertEqual(decodedProfile.userName, "Alice Developer")
        XCTAssertEqual(decodedProfile.threshold, 0.42, accuracy: 0.001)
        XCTAssertEqual(decodedProfile.featurePrintData, dummyData)
        XCTAssertEqual(
            Int(decodedProfile.enrolledAt.timeIntervalSince1970),
            Int(originalDate.timeIntervalSince1970)
        )
    }
    
    func testThresholdBoundaryChecks() {
        var profile = BiometricProfile(
            userName: "Bob",
            enrolledAt: Date(),
            featurePrintData: Data(),
            threshold: 0.35
        )
        
        XCTAssertEqual(profile.threshold, 0.35)
        profile.threshold = 0.48
        XCTAssertEqual(profile.threshold, 0.48)
    }
}
