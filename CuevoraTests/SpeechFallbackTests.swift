import XCTest
@testable import CuevoraLogic

final class SpeechFallbackTests: XCTestCase {
    func testCommandsPreferLongerPhrasesAndIgnoreSilence() {
        XCTAssertEqual(VoiceCommands.parse("please go back"), .reset)
        XCTAssertEqual(VoiceCommands.parse("speed up now"), .faster)
        XCTAssertEqual(VoiceCommands.parse("slow down"), .slower)
        XCTAssertEqual(VoiceCommands.parse("  "), .unknown)
        XCTAssertEqual(VoiceCommands.parse("play"), .play)
    }

    func testSpeechStaysManualWhenOnDeviceRecognitionIsUnavailable() {
        let unsupported = SpeechGate(onDeviceSupported: false, permissionGranted: true, recordingInProgress: false, localeIdentifier: "en-US")
        XCTAssertFalse(unsupported.canListen)
        XCTAssertTrue(unsupported.unavailableReason?.contains("will not send audio") == true)
        let denied = SpeechGate(onDeviceSupported: true, permissionGranted: false, recordingInProgress: false, localeIdentifier: "en-US")
        XCTAssertFalse(denied.canListen)
        let busy = SpeechGate(onDeviceSupported: true, permissionGranted: true, recordingInProgress: true, localeIdentifier: "en-US")
        XCTAssertFalse(busy.canListen)
        XCTAssertTrue(busy.unavailableReason?.contains("recording") == true)
        let ready = SpeechGate(onDeviceSupported: true, permissionGranted: true, recordingInProgress: false, localeIdentifier: "en-US")
        XCTAssertTrue(ready.canListen)
        XCTAssertNil(ready.unavailableReason)
    }

    func testAdaptiveSpeedFallsBackToTheFixedSpeed() {
        let stale = AdaptiveScroll.speed(baseSpeed: 5, targetWordsPerMinute: 140, events: [
            event("one two three four", 0), event("five six seven eight", 1000)
        ], now: 20_000)
        XCTAssertEqual(stale.reason, .staleTranscript)
        XCTAssertEqual(stale.speed, 5)
        let override = AdaptiveScroll.speed(baseSpeed: 5, targetWordsPerMinute: 140, events: [
            event("one two three four", 0), event("five six seven eight", 1000)
        ], now: 2000, manualOverrideUntil: 5000)
        XCTAssertEqual(override.reason, .manualOverride)
        let faster = AdaptiveScroll.speed(baseSpeed: 4, targetWordsPerMinute: 120, events: [
            event("one two three four", 0),
            event("five six seven eight", 1000),
            event("nine ten eleven twelve", 2000),
            event("thirteen fourteen fifteen sixteen", 3000)
        ], now: 4000)
        XCTAssertEqual(faster.reason, .adaptive)
        XCTAssertGreaterThan(faster.speed, 4)
    }

    func testRehearsalMetricsMatchTheReferenceCases() {
        let metrics = RehearsalAnalysis.analyze(
            scriptContent: "one two three four five six seven eight nine ten",
            events: [event("one two um three", 1000), event("four five like six", 5000), event("seven eight", 7000)],
            startedAt: 0,
            endedAt: 10_000
        )
        XCTAssertEqual(metrics.wordsPerMinute, 60)
        XCTAssertEqual(metrics.longPauseCount, 1)
        XCTAssertEqual(metrics.fillerWordCount, 2)
        XCTAssertEqual(metrics.scriptCoverage, 1)
        let empty = RehearsalAnalysis.analyze(scriptContent: "one two three", events: [], startedAt: 0, endedAt: 5_000)
        XCTAssertNil(empty.wordsPerMinute)
        XCTAssertTrue(empty.unavailableMetrics.contains("Speech transcript"))
        XCTAssertTrue(empty.suggestions[0].contains("speech recognition"))
        let noisy = RehearsalAnalysis.analyze(
            scriptContent: "one two three four five",
            events: [
                event("one two", 1000),
                TranscriptEvent(transcript: "two two two", confidence: 0.1, isFinal: true, timestamp: 2000, source: "test"),
                event("three four five", 3000)
            ],
            startedAt: 0,
            endedAt: 4_000
        )
        XCTAssertEqual(noisy.repeatedWordCount, 0)
        XCTAssertEqual(RehearsalAnalysis.repeatedWords(in: "go go go back back"), 3)
    }

    private func event(_ transcript: String, _ timestamp: Double) -> TranscriptEvent {
        TranscriptEvent(transcript: transcript, confidence: 0.9, isFinal: true, timestamp: timestamp, source: "test")
    }
}
