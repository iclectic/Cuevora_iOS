import XCTest
@testable import CuevoraLogic

final class RecordingStateTests: XCTestCase {
    func testPermissionDenialAndLowStorageDoNotStart() {
        let denied = RecordingReducer.reduce(phase: .idle, action: .requestStart(
            countdown: 3,
            permissions: CapturePermissions(camera: .denied, microphone: .granted),
            freeBytes: 900_000_000,
            thermalSerious: false
        ))
        XCTAssertEqual(denied.phase, .failed("Camera or microphone access is off. You can allow both in Settings and try again. Nothing was recorded."))
        let full = RecordingReducer.reduce(phase: .idle, action: .requestStart(
            countdown: 0,
            permissions: CapturePermissions(camera: .granted, microphone: .granted),
            freeBytes: 1_000,
            thermalSerious: false
        ))
        if case .failed(let message) = full.phase {
            XCTAssertTrue(message.contains("storage"))
        } else {
            XCTFail("Expected a storage failure")
        }
    }

    func testInterruptionFinalizesAPartialTakeAndShareFailureKeepsIt() {
        let interrupted = RecordingReducer.reduce(phase: .recording, action: .interrupted("Phone call"))
        XCTAssertEqual(interrupted.phase, .stopping(partial: true))
        XCTAssertTrue(interrupted.finalizePartial)
        XCTAssertFalse(interrupted.deleteFile)
        let ready = RecordingReducer.reduce(phase: interrupted.phase, action: .fileReady(partial: true))
        XCTAssertEqual(ready.phase, .preview(partial: true))
        let shared = RecordingReducer.reduce(phase: ready.phase, action: .shareFailed)
        XCTAssertEqual(shared.phase, .preview(partial: true))
        XCTAssertFalse(shared.deleteFile)
        XCTAssertTrue(shared.message?.contains("still on this device") == true)
    }

    func testBackgroundAndCameraSwitchRules() {
        let background = RecordingReducer.reduce(phase: .recording, action: .backgrounded)
        XCTAssertEqual(background.phase, .stopping(partial: true))
        let countdown = RecordingReducer.reduce(phase: .countdown(3), action: .backgrounded)
        XCTAssertEqual(countdown.phase, .idle)
        let blocked = RecordingReducer.reduce(phase: .recording, action: .switchCamera)
        XCTAssertFalse(blocked.allowCameraSwitch)
        XCTAssertEqual(blocked.phase, .recording)
        let allowed = RecordingReducer.reduce(phase: .preview(partial: false), action: .switchCamera)
        XCTAssertTrue(allowed.allowCameraSwitch)
    }

    func testRecoveryFailureDoesNotInventAFile() {
        let failed = RecordingReducer.reduce(phase: .stopping(partial: true), action: .fileFailed("unreadable"))
        if case .failed(let message) = failed.phase {
            XCTAssertTrue(message.contains("could not be recovered"))
        } else {
            XCTFail("Expected recovery failure")
        }
        XCTAssertFalse(failed.deleteFile)
    }
}
