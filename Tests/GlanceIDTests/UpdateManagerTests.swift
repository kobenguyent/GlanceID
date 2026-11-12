import XCTest
@testable import GlanceID

final class UpdateManagerTests: XCTestCase {
    
    func testSemanticVersionParsing() {
        let v1 = SemanticVersion(string: "v1.2.3")
        XCTAssertNotNil(v1)
        XCTAssertEqual(v1?.major, 1)
        XCTAssertEqual(v1?.minor, 2)
        XCTAssertEqual(v1?.patch, 3)
        XCTAssertNil(v1?.prerelease)
        
        let v2 = SemanticVersion(string: "2.4")
        XCTAssertNotNil(v2)
        XCTAssertEqual(v2?.major, 2)
        XCTAssertEqual(v2?.minor, 4)
        XCTAssertEqual(v2?.patch, 0)
        
        let vBeta = SemanticVersion(string: "v1.1.0-beta.1+build42")
        XCTAssertNotNil(vBeta)
        XCTAssertEqual(vBeta?.major, 1)
        XCTAssertEqual(vBeta?.minor, 1)
        XCTAssertEqual(vBeta?.patch, 0)
        XCTAssertEqual(vBeta?.prerelease, "beta.1")
        
        XCTAssertNil(SemanticVersion(string: ""))
        XCTAssertNil(SemanticVersion(string: "invalid-version"))
    }
    
    func testSemanticVersionComparison() {
        let v100 = SemanticVersion(string: "1.0.0")!
        let v100Tag = SemanticVersion(string: "v1.0.0")!
        let v101 = SemanticVersion(string: "1.0.1")!
        let v120 = SemanticVersion(string: "1.2.0")!
        let v1100 = SemanticVersion(string: "1.10.0")!
        let v200 = SemanticVersion(string: "2.0.0")!
        let v100Beta = SemanticVersion(string: "1.0.0-beta.1")!
        
        XCTAssertEqual(v100, v100Tag)
        XCTAssertLessThan(v100, v101)
        XCTAssertLessThan(v120, v1100)
        XCTAssertLessThan(v1100, v200)
        XCTAssertLessThan(v100Beta, v100)
    }
    
    func testGitHubReleaseDecodingAndPreferredAsset() throws {
        let json = """
        {
            "tag_name": "v1.2.0",
            "name": "GlanceID v1.2.0 — Multi-Monitor & Liveness",
            "body": "### What's New\\n- Multi-display lock screen\\n- EAR blink liveness check",
            "html_url": "https://github.com/kobenguyent/GlanceID/releases/tag/v1.2.0",
            "published_at": "2026-11-12T12:00:00Z",
            "prerelease": false,
            "draft": false,
            "assets": [
                {
                    "name": "GlanceID.zip",
                    "browser_download_url": "https://github.com/kobenguyent/GlanceID/releases/download/v1.2.0/GlanceID.zip",
                    "size": 344064,
                    "content_type": "application/zip"
                },
                {
                    "name": "GlanceID.dmg",
                    "browser_download_url": "https://github.com/kobenguyent/GlanceID/releases/download/v1.2.0/GlanceID.dmg",
                    "size": 677888,
                    "content_type": "application/x-apple-diskimage"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v1.2.0")
        XCTAssertEqual(release.cleanVersionString, "1.2.0")
        XCTAssertEqual(release.assets?.count, 2)
        // Should prefer .dmg over .zip
        XCTAssertEqual(release.preferredInstallerAsset?.name, "GlanceID.dmg")
    }
    
    func testEvaluateReleaseDetectsNewerVersion() {
        let release = GitHubRelease(
            tagName: "v1.3.0",
            name: "GlanceID 1.3.0",
            body: "Release notes",
            htmlUrl: "https://github.com/kobenguyent/GlanceID/releases/tag/v1.3.0",
            publishedAt: nil,
            prerelease: false,
            draft: false,
            assets: nil
        )
        
        let status = UpdateManager.evaluateRelease(release, currentVersion: "1.0.0")
        XCTAssertTrue(status.isUpdateAvailable)
        if case .updateAvailable(_, let current, let latest) = status {
            XCTAssertEqual(current, "1.0.0")
            XCTAssertEqual(latest, "1.3.0")
        } else {
            XCTFail("Expected .updateAvailable, got \(status)")
        }
    }
    
    func testEvaluateReleaseDetectsUpToDate() {
        let release = GitHubRelease(
            tagName: "v1.0.0",
            name: "GlanceID 1.0.0",
            body: nil,
            htmlUrl: "https://github.com/kobenguyent/GlanceID/releases/tag/v1.0.0",
            publishedAt: nil,
            prerelease: false,
            draft: false,
            assets: nil
        )
        
        let sameStatus = UpdateManager.evaluateRelease(release, currentVersion: "1.0.0")
        XCTAssertFalse(sameStatus.isUpdateAvailable)
        XCTAssertEqual(sameStatus, .upToDate(currentVersion: "1.0.0", latestVersion: "1.0.0"))
        
        let olderRemoteStatus = UpdateManager.evaluateRelease(release, currentVersion: "1.1.0")
        XCTAssertFalse(olderRemoteStatus.isUpdateAvailable)
        XCTAssertEqual(olderRemoteStatus, .upToDate(currentVersion: "1.1.0", latestVersion: "1.0.0"))
    }
}
