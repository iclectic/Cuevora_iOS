import XCTest
@testable import CuevoraLogic

final class RecordingJourneyTests: XCTestCase {
    private let granted = CapturePermissions(camera: .granted, microphone: .granted)

    func testCountdownCancelAndBackgroundDoNotStartTheTake() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var clock = RecordingCountdown()
        clock.start(seconds: 3, at: start)
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(1.1)), .waiting(2))
        clock.cancel()
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(5)), .inactive)

        let counting = RecordingReducer.reduce(phase: .idle, action: .requestStart(
            countdown: 3, permissions: granted, freeBytes: 900_000_000, thermalSerious: false
        ))
        XCTAssertEqual(counting.phase, .countdown(3))
        let left = RecordingReducer.reduce(phase: counting.phase, action: .backgrounded)
        XCTAssertEqual(left.phase, .idle)
        let late = RecordingReducer.reduce(phase: left.phase, action: .countdownFinished)
        XCTAssertEqual(late.phase, .idle)

        let immediate = RecordingReducer.reduce(phase: .idle, action: .requestStart(
            countdown: 0, permissions: granted, freeBytes: 900_000_000, thermalSerious: false
        ))
        XCTAssertEqual(immediate.phase, .recording)
    }

    func testInterruptionsStopAndARouteChangeContinues() {
        let call = RecordingReducer.reduce(phase: .recording, action: .interrupted(CaptureInterruptionKind.audioInUse.message))
        XCTAssertEqual(call.phase, .stopping(partial: true))
        XCTAssertTrue(call.finalizePartial)
        XCTAssertFalse(call.deleteFile)
        XCTAssertEqual(CaptureInterruptionKind.multitasking.message, "The camera stopped during multitasking.")

        let route = RecordingReducer.reduce(phase: .recording, action: .audioRouteChanged)
        XCTAssertEqual(route.phase, .recording)
        XCTAssertFalse(route.finalizePartial)
        XCTAssertFalse(route.deleteFile)
        XCTAssertTrue(route.message?.contains("continues") == true)

        let full = RecordingReducer.reduce(phase: .recording, action: .storageLow)
        XCTAssertEqual(full.phase, .stopping(partial: true))
        XCTAssertTrue(full.finalizePartial)

        let warm = RecordingReducer.reduce(phase: .idle, action: .requestStart(
            countdown: 0, permissions: granted, freeBytes: 900_000_000, thermalSerious: true
        ))
        if case .failed(let message) = warm.phase {
            XCTAssertTrue(message.contains("warm"))
        } else {
            XCTFail("Expected thermal refusal")
        }
    }

    func testShareAndPhotosKeepTheOnlyTake() {
        let preview = RecordingPhase.preview(partial: false)
        for result in [ShareResult.cancelled, .failed, .finished] {
            let transition = RecordingReducer.reduce(phase: preview, action: result.action)
            XCTAssertFalse(transition.deleteFile)
            if case .preview = transition.phase {} else { XCTFail("Share changed the take") }
        }
        let cancelled = RecordingReducer.reduce(phase: preview, action: .shareCancelled)
        XCTAssertTrue(cancelled.message?.contains("still on this device") == true)

        for action in [RecordingAction.photosDenied, .photosFailed, .photosSaved] {
            let transition = RecordingReducer.reduce(phase: preview, action: action)
            XCTAssertFalse(transition.deleteFile)
            XCTAssertEqual(transition.phase, preview)
            XCTAssertTrue(transition.message?.contains("Cuevora") == true)
        }
    }

    func testRecoveryLayoutMirrorAndLibraryKeepTheOtherTakes() {
        let restored = TakeRecovery.decide(fileName: "take.mp4", playable: true, duration: 4.5)
        XCTAssertEqual(restored.phase, .preview(partial: true))
        XCTAssertTrue(restored.recoverable)
        XCTAssertFalse(RecordingReducer.reduce(phase: restored.phase, action: .shareFailed).deleteFile)

        let lost = TakeRecovery.decide(fileName: "broken.mp4", playable: false, duration: .nan)
        XCTAssertFalse(lost.recoverable)
        if case .failed(let message) = lost.phase {
            XCTAssertTrue(message.contains("still available"))
        } else {
            XCTFail("Expected a recovery failure that keeps the file")
        }

        XCTAssertEqual(PromptStage.stage(split: false, width: 400, height: 800, regularWidth: false), .overlay)
        XCTAssertEqual(PromptStage.stage(split: true, width: 400, height: 800, regularWidth: false), .splitStack(cameraFraction: 0.34))
        XCTAssertEqual(PromptStage.stage(split: true, width: 800, height: 400, regularWidth: false), .splitSide(cameraFraction: 0.42))
        XCTAssertEqual(PromptStage.stage(split: true, width: 400, height: 800, regularWidth: true), .splitSide(cameraFraction: 0.42))

        XCTAssertTrue(CaptureMirror.previewMirrored(frontCamera: true))
        XCTAssertFalse(CaptureMirror.previewMirrored(frontCamera: false))
        XCTAssertFalse(CaptureMirror.recordedFileMirrored)

        let kept = RecordingCatalog.keptNames(afterDeleting: "a.mp4", from: ["a.mp4", "b.mp4"])
        XCTAssertEqual(kept, ["b.mp4"])
        XCTAssertFalse(RecordingCatalog.shouldAdopt(fileName: "b.mp4", existing: kept))
        XCTAssertTrue(RecordingCatalog.shouldAdopt(fileName: "c.mp4", existing: kept))

        let missing = RecordingReducer.reduce(phase: .idle, action: .requestStart(
            countdown: 0,
            permissions: CapturePermissions(camera: .unavailable, microphone: .granted),
            freeBytes: 900_000_000,
            thermalSerious: false
        ))
        if case .failed = missing.phase {} else { XCTFail("Expected unavailable hardware") }
        let second = RecordingReducer.reduce(phase: .recording, action: .requestStart(
            countdown: 0, permissions: granted, freeBytes: 900_000_000, thermalSerious: false
        ))
        XCTAssertEqual(second.phase, .recording)
        XCTAssertFalse(RecordingReducer.reduce(phase: .countdown(2), action: .switchCamera).allowCameraSwitch)
    }
}
