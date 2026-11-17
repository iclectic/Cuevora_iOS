import XCTest
@testable import CuevoraLogic

final class PlaybackEngineTests: XCTestCase {
    func testFramePacingAndInterruptionClamp() {
        var engine = PlaybackEngine(speed: 2)
        engine.maximumOffset = 10_000
        engine.play()
        XCTAssertFalse(engine.advance(delta: 0.5))
        XCTAssertEqual(engine.offset, 2 * 20 * 0.1, accuracy: 0.001)
        let before = engine.offset
        engine.advance(delta: 5)
        XCTAssertEqual(engine.offset - before, 2 * 20 * 0.1, accuracy: 0.001)
    }

    func testSeekBoundariesAndCompletion() {
        var engine = PlaybackEngine(speed: 10)
        engine.maximumOffset = 100
        engine.seek(toProgress: 2)
        XCTAssertEqual(engine.progress, 1, accuracy: 0.001)
        engine.seek(toProgress: -1)
        XCTAssertEqual(engine.offset, 0, accuracy: 0.001)
        engine.play()
        var completed = false
        for _ in 0..<20 {
            completed = engine.advance(delta: 1) || completed
        }
        XCTAssertTrue(completed)
        XCTAssertFalse(engine.playing)
        XCTAssertEqual(engine.progress, 1, accuracy: 0.001)
    }

    func testLayoutChangePreservesReadingPosition() {
        var engine = PlaybackEngine()
        engine.maximumOffset = 200
        engine.seek(toProgress: 0.25)
        engine.setMaximumOffset(800, preservingProgress: true)
        XCTAssertEqual(engine.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(engine.offset, 200, accuracy: 0.001)
    }

    func testPauseDoesNotMoveAndResetClearsElapsed() {
        var engine = PlaybackEngine(speed: 5)
        engine.maximumOffset = 500
        engine.advance(delta: 1)
        XCTAssertEqual(engine.offset, 0, accuracy: 0.001)
        engine.play()
        engine.advance(delta: 0.05)
        engine.pause()
        let paused = engine.offset
        engine.advance(delta: 0.05)
        XCTAssertEqual(engine.offset, paused, accuracy: 0.001)
        engine.reset()
        XCTAssertEqual(engine.elapsed, 0, accuracy: 0.001)
        XCTAssertEqual(engine.progress, 0, accuracy: 0.001)
    }

    func testRemainingTimeIsLabeledByTheCallerAsAnEstimate() {
        var engine = PlaybackEngine(speed: 1)
        engine.maximumOffset = 200
        XCTAssertEqual(engine.estimatedRemainingSeconds, 10, accuracy: 0.001)
        XCTAssertEqual(ReadTime.clock(engine.estimatedRemainingSeconds), "0:10")
        XCTAssertEqual(ReadTime.wordCount("  Hello   café  "), 2)
        XCTAssertEqual(ReadTime.wordCount(""), 0)
        XCTAssertEqual(ReadTime.seconds(text: "one two", wordsPerMinute: 120), 1)
    }
}
