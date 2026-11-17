import XCTest
@testable import CuevoraLogic

final class AppleIntegrationTests: XCTestCase {
    func testShortcutsDoNotStartCapture() {
        XCTAssertFalse(ShortcutPolicy.startsCamera)
        XCTAssertFalse(ShortcutPolicy.startsMicrophone)
        XCTAssertEqual(ShortcutPolicy.actions, [.createScript, .openMostRecent])
    }

    func testIdentityStaysOptionalAndLocal() {
        XCTAssertFalse(IdentityPolicy.signInAvailable)
        XCTAssertFalse(IdentityPolicy.accountRequired)
        XCTAssertFalse(IdentityPolicy.syncsScripts)
        XCTAssertTrue(IdentityPolicy.deletionDetail.contains("this device"))
    }
}

final class SyncTests: XCTestCase {
    func testCloudSyncIsOffAndExcludesRecordings() {
        XCTAssertFalse(CloudSyncPolicy.enabled)
        XCTAssertFalse(CloudSyncPolicy.recordingsIncluded)
        XCTAssertTrue(CloudSyncPolicy.consentRequiredBeforeEnable)
        XCTAssertTrue(CloudSyncPolicy.explanation.contains("not turned on"))
        XCTAssertTrue(CloudSyncPolicy.explanation.contains("Recordings would stay local"))
    }

    func testSessionProgressIsClamped() {
        XCTAssertEqual(PromptSession(scriptID: "a", progress: 4).progress, 1)
        XCTAssertEqual(PromptSession(scriptID: "a", progress: -2).progress, 0)
    }
}
