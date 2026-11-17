import XCTest
@testable import CuevoraLogic

final class PlayerJourneyTests: XCTestCase {
    func testCountdownCanBeCancelledAndSpeedCanChangeWhileItRuns() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = PlayerSession(speed: 3, countdownLength: 3)
        session.toggle(at: start)
        XCTAssertEqual(session.phase, .counting(3))
        XCTAssertFalse(session.awake)
        XCTAssertFalse(session.acceptsFrame())

        session.setSpeed(8)
        session.advanceCountdown(to: start.addingTimeInterval(1.1))
        XCTAssertEqual(session.phase, .counting(2))
        XCTAssertEqual(session.speed, 8)

        session.pause()
        session.advanceCountdown(to: start.addingTimeInterval(5))
        XCTAssertEqual(session.phase, .paused)
        XCTAssertNil(session.countdownValue)
    }

    func testPlayPauseBackgroundAndEndDoNotMoveWhilePaused() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = PlayerSession(countdownLength: 0, keepScreenAwake: true)
        session.toggle(at: start)
        XCTAssertEqual(session.phase, .playing)
        XCTAssertTrue(session.awake)
        XCTAssertTrue(session.acceptsFrame())

        var engine = PlaybackEngine(speed: session.speed)
        engine.maximumOffset = 10_000
        engine.play()
        engine.advance(delta: 0.016)
        XCTAssertEqual(engine.offset, 3 * 20 * 0.016, accuracy: 0.001)
        engine.advance(delta: 0.5)
        XCTAssertEqual(engine.offset, 3 * 20 * 0.116, accuracy: 0.001)
        XCTAssertEqual(PlayerSession.clampedDelta(-2), 0, accuracy: 0.001)

        session.adjustSpeed(by: 0.5)
        XCTAssertEqual(session.phase, .playing)
        XCTAssertEqual(session.speed, 3.5)

        session.enterBackground()
        XCTAssertEqual(session.phase, .paused)
        XCTAssertFalse(session.awake)
        XCTAssertFalse(session.acceptsFrame())
        engine.pause()
        let parked = engine.offset
        engine.advance(delta: 1)
        XCTAssertEqual(engine.offset, parked, accuracy: 0.001)

        engine.play()
        engine.seek(toProgress: 1)
        var completed = false
        completed = engine.advance(delta: 0.016) || completed
        XCTAssertTrue(completed)
        session.finish()
        XCTAssertEqual(session.phase, .finished)
        XCTAssertFalse(session.awake)
    }

    func testKeyboardMirrorFocusResetAndLargerType() {
        var session = PlayerSession(countdownLength: 0)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.toggle(at: start)
        session.perform(.faster, at: start)
        XCTAssertEqual(session.speed, 3.5)
        XCTAssertEqual(session.phase, .playing)
        session.perform(.mirror, at: start)
        session.perform(.focus, at: start)
        XCTAssertTrue(session.mirror)
        XCTAssertFalse(session.focus)
        session.perform(.reset, at: start)
        XCTAssertEqual(session.phase, .ready)

        XCTAssertEqual(PlayerSession.Key(named: "space"), .togglePlay)
        XCTAssertEqual(PlayerSession.Key(named: "left"), .back)
        XCTAssertEqual(PlayerSession.Key(named: "escape"), .close)
        XCTAssertNil(PlayerSession.Key(named: "x"))

        XCTAssertEqual(PromptTypography.fontSize(base: 18, profile: .default, accessibilitySize: true), 44)
        XCTAssertEqual(PromptTypography.lineSpacing(base: 1.6, profile: .dyslexia), 1.92)
    }

    func testRotationKeepsTheReadingPositionAndTextShapesStayIntact() {
        var engine = PlaybackEngine(speed: 4)
        engine.maximumOffset = 400
        engine.seek(toProgress: 0.5)
        engine.setMaximumOffset(900, preservingProgress: true)
        XCTAssertEqual(engine.progress, 0.5, accuracy: 0.001)

        let oneLine = PromptText.lines(content: "Hello", markers: [], highlights: [])
        XCTAssertEqual(oneLine.map(\.text), ["Hello"])

        let long = PromptText.lines(content: Array(repeating: "Line", count: 40).joined(separator: "\n"), markers: [3], highlights: [0])
        XCTAssertEqual(long.count, 40)
        XCTAssertTrue(long[0].highlighted)
        XCTAssertTrue(long[3].sectionBreak)

        let mixed = PromptText.lines(content: "Hello\nשלום\ncafé 🎬", markers: [], highlights: [])
        XCTAssertEqual(mixed.map(\.text), ["Hello", "שלום", "café 🎬"])

        let empty = PromptText.lines(content: "", markers: [], highlights: [])
        XCTAssertEqual(empty.first?.text, "This script is empty.")
    }
}
