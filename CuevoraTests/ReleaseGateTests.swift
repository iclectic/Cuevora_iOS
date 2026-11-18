import XCTest
@testable import CuevoraLogic

final class ReleaseGateTests: XCTestCase {
    func testTheBuildIsNotReadyToUploadAndDiagnosticsStayEmptyOfContent() {
        XCTAssertFalse(ReleaseClaims.readyToUpload)
        XCTAssertFalse(ReleaseClaims.collectsDiagnostics)
        XCTAssertFalse(ReleaseClaims.diagnosticMayIncludeScriptText)
        XCTAssertTrue(ReleaseClaims.thirdPartySDKs.isEmpty)
        XCTAssertFalse(IdentityPolicy.accountRequired)
        XCTAssertFalse(IdentityPolicy.signInAvailable)
        XCTAssertFalse(CloudSyncPolicy.enabled)
        XCTAssertFalse(CloudSyncPolicy.recordingsIncluded)
        XCTAssertFalse(SpeechLocalePolicy.usesServerRecognition)
        XCTAssertFalse(ShortcutPolicy.startsCamera)
        XCTAssertFalse(ShortcutPolicy.startsMicrophone)
        let report = ReleaseClaims.diagnostic(domain: "Cuevora", code: 1, scriptText: "private script text")
        XCTAssertFalse(report.values.contains("private script text"))
        XCTAssertEqual(report["code"], "1")
    }

    func testPrivacyManifestDeclaresOnlyTheDiskSpaceCheck() throws {
        let manifest = try String(contentsOf: repoFile("Cuevora/PrivacyInfo.xcprivacy"), encoding: .utf8)
        XCTAssertTrue(manifest.contains("<key>NSPrivacyTracking</key>\n\t<false/>"))
        XCTAssertTrue(manifest.contains("<key>NSPrivacyCollectedDataTypes</key>\n\t<array/>"))
        XCTAssertTrue(manifest.contains("NSPrivacyAccessedAPICategoryDiskSpace"))
        XCTAssertTrue(manifest.contains(ReleaseClaims.diskSpaceReason))
        XCTAssertFalse(manifest.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        XCTAssertFalse(manifest.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))
        XCTAssertFalse(manifest.contains("NSPrivacyCollectedDataTypeName"))
    }

    func testProjectIdentityAndPermissionCopyMatchTheInventory() throws {
        let project = try String(contentsOf: repoFile("Cuevora.xcodeproj/project.pbxproj"), encoding: .utf8)
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER = \(ReleaseClaims.bundleIdentifier);"))
        XCTAssertTrue(project.contains("MARKETING_VERSION = \(ReleaseClaims.marketingVersion);"))
        XCTAssertTrue(project.contains("CURRENT_PROJECT_VERSION = \(ReleaseClaims.buildNumber);"))
        XCTAssertTrue(project.contains("IPHONEOS_DEPLOYMENT_TARGET = 17.0;"))
        XCTAssertFalse(project.contains("DEVELOPMENT_TEAM"))
        let permissions = [
            "Cuevora uses the camera to preview and record video while you read. The script is not added to the video.",
            "Cuevora uses the microphone to record audio with your video, and for on-device voice commands when you turn them on.",
            "Cuevora adds a video to Photos only when you tap Save to Photos.",
            "Cuevora uses on-device speech recognition for optional voice commands and rehearsal estimates. Audio is not sent to Cuevora."
        ]
        for sentence in permissions {
            XCTAssertTrue(project.contains(sentence), sentence)
        }
    }

    private func repoFile(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
