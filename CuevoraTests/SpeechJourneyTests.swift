import XCTest
@testable import CuevoraLogic

final class SpeechJourneyTests: XCTestCase {
    func testOrdinarySpeechSilenceAndLowConfidenceDoNotCommand() {
        XCTAssertEqual(VoiceCommands.parse("I will play the role of Hamlet"), .unknown)
        XCTAssertEqual(VoiceCommands.parse("I like to play"), .unknown)
        XCTAssertEqual(SpeechIntake.command(transcript: "play", confidence: 0.2, isFinal: true), .unknown)
        XCTAssertEqual(SpeechIntake.command(transcript: "play", confidence: 0.9, isFinal: false), .unknown)
        XCTAssertEqual(SpeechIntake.command(transcript: "   ", confidence: 0.9, isFinal: true), .unknown)
        XCTAssertEqual(SpeechIntake.command(transcript: "please go back", confidence: 0.8, isFinal: true), .reset)
    }

    func testOfflineLossAndRecordingDoNotOpenAServerPath() {
        let offline = SpeechGate(onDeviceSupported: true, permissionGranted: true, recordingInProgress: false, localeIdentifier: "en-GB", networkReachable: false)
        XCTAssertTrue(offline.canListen)
        XCTAssertFalse(offline.usesServerRecognition)
        XCTAssertNil(offline.unavailableReason)

        let lost = SpeechGate(onDeviceSupported: true, permissionGranted: true, recordingInProgress: false, localeIdentifier: "en-US", recognizerAvailable: false)
        XCTAssertFalse(lost.canListen)
        XCTAssertTrue(lost.unavailableReason?.contains("did not switch to server") == true)

        let unsupported = SpeechGate(onDeviceSupported: false, permissionGranted: true, recordingInProgress: false, localeIdentifier: "fr-FR", networkReachable: true)
        XCTAssertFalse(unsupported.canListen)
        XCTAssertFalse(unsupported.usesServerRecognition)

        XCTAssertEqual(MicrophoneOwner.request(.speech, while: .recording), .recording)
        XCTAssertEqual(MicrophoneOwner.request(.recording, while: .speech), .recording)
        XCTAssertEqual(MicrophoneOwner.request(.idle, while: .recording), .recording)
        XCTAssertEqual(MicrophoneOwner.request(.speech, while: .idle), .speech)
        XCTAssertEqual(SpeechLocalePolicy.evaluationLocales, ["en-US", "en-GB"])
        XCTAssertFalse(SpeechLocalePolicy.usesServerRecognition)
    }

    func testSavedMetricsWithoutTheNewFieldStillDecode() throws {
        let legacy = """
        {"durationSeconds":4,"transcriptWordCount":3,"scriptWordCount":3,"wordsPerMinute":45,"longPauseCount":0,"fillerWordCount":0,"scriptCoverage":1,"completionPercent":100,"unavailableMetrics":[],"suggestions":["Delivery looks steady. Try another pass and compare consistency."]}
        """.data(using: .utf8)!
        let metrics = try JSONDecoder().decode(RehearsalMetrics.self, from: legacy)
        XCTAssertEqual(metrics.repeatedWordCount, 0)
        XCTAssertEqual(metrics.wordsPerMinute, 45)
    }
}
