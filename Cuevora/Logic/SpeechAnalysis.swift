import Foundation

public struct TranscriptEvent: Equatable, Codable {
    public var transcript: String
    public var confidence: Double
    public var isFinal: Bool
    public var timestamp: Double
    public var source: String

    public init(transcript: String, confidence: Double, isFinal: Bool, timestamp: Double, source: String) {
        self.transcript = transcript
        self.confidence = confidence
        self.isFinal = isFinal
        self.timestamp = timestamp
        self.source = source
    }
}

public enum VoiceCommand: String, Equatable {
    case play, pause, stop, faster, slower, reset, unknown
}

public enum VoiceCommands {
    /// Longer phrases are matched first so "go back" resets and "speed up" does not become "play" or "faster".
    private static let phrases: [(String, VoiceCommand)] = [
        ("speed up", .faster),
        ("slow down", .slower),
        ("go back", .reset),
        ("restart", .reset),
        ("resume", .play),
        ("faster", .faster),
        ("slower", .slower),
        ("quicker", .faster),
        ("begin", .play),
        ("start", .play),
        ("pause", .pause),
        ("reset", .reset),
        ("hold", .pause),
        ("wait", .pause),
        ("stop", .stop),
        ("play", .play),
        ("end", .stop),
        ("go", .play)
    ]

    private static let extras: Set<String> = ["please", "now", "cuevora"]

    public static func parse(_ transcript: String) -> VoiceCommand {
        let words = tokenize(transcript)
        guard !words.isEmpty, words.count <= 6 else { return .unknown }
        for (phrase, command) in phrases {
            let phraseWords = phrase.split(separator: " ").map(String.init)
            guard let start = range(of: phraseWords, in: words) else { continue }
            let outside = Array(words[..<start]) + Array(words[(start + phraseWords.count)...])
            if outside.allSatisfy({ extras.contains($0) }) { return command }
        }
        return .unknown
    }

    private static func tokenize(_ transcript: String) -> [String] {
        transcript.lowercased().split { !$0.isLetter }.map(String.init)
    }

    private static func range(of phrase: [String], in words: [String]) -> Int? {
        guard !phrase.isEmpty, phrase.count <= words.count else { return nil }
        for start in 0...(words.count - phrase.count) {
            if Array(words[start..<(start + phrase.count)]) == phrase { return start }
        }
        return nil
    }
}

public enum SpeechIntake {
    public static let minimumCommandConfidence = 0.5

    public static func command(transcript: String, confidence: Double, isFinal: Bool) -> VoiceCommand {
        guard isFinal, confidence >= minimumCommandConfidence else { return .unknown }
        return VoiceCommands.parse(transcript)
    }
}

public enum MicrophoneOwner: Equatable {
    case idle, speech, recording

    public static func request(_ requested: MicrophoneOwner, while current: MicrophoneOwner) -> MicrophoneOwner {
        switch requested {
        case .recording: .recording
        case .speech: current == .recording ? .recording : .speech
        case .idle: current == .recording ? .recording : .idle
        }
    }
}

public enum SpeechLocalePolicy {
    /// Locales named for a future device sample. Naming them is not a claim that they passed.
    public static let evaluationLocales = ["en-US", "en-GB"]
    public static let usesServerRecognition = false

    public static func listens(onDeviceSupported: Bool, recognizerAvailable: Bool) -> Bool {
        onDeviceSupported && recognizerAvailable
    }
}

public struct AdaptiveScrollResult: Equatable {
    public var speed: Double
    public var confidence: Double
    public var reason: Reason

    public enum Reason: String, Equatable {
        case adaptive
        case manualOverride = "manual-override"
        case staleTranscript = "stale-transcript"
        case insufficientTranscript = "insufficient-transcript"
    }
}

public enum AdaptiveScroll {
    public static func speed(
        baseSpeed: Double,
        targetWordsPerMinute: Double,
        events: [TranscriptEvent],
        now: Double,
        manualOverrideUntil: Double = 0,
        minimumSpeed: Double = 1,
        maximumSpeed: Double = 10,
        staleAfter: Double = 5000
    ) -> AdaptiveScrollResult {
        if manualOverrideUntil > now {
            return AdaptiveScrollResult(speed: baseSpeed, confidence: 0, reason: .manualOverride)
        }
        let finals = events
            .filter { $0.isFinal && $0.confidence >= 0.4 && !$0.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.timestamp < $1.timestamp }
        guard let last = finals.last, finals.count >= 2 else {
            return AdaptiveScrollResult(speed: baseSpeed, confidence: 0, reason: .insufficientTranscript)
        }
        if now - last.timestamp > staleAfter {
            return AdaptiveScrollResult(speed: baseSpeed, confidence: 0, reason: .staleTranscript)
        }
        let elapsedMinutes = (last.timestamp - finals[0].timestamp) / 60000
        let words = ReadTime.wordCount(finals.map(\.transcript).joined(separator: " "))
        if elapsedMinutes <= 0 || words < 3 || targetWordsPerMinute <= 0 {
            return AdaptiveScrollResult(speed: baseSpeed, confidence: 0, reason: .insufficientTranscript)
        }
        let spoken = Double(words) / elapsedMinutes
        let confidence = min(1, max(0, (Double(finals.count) / 4) * min(1, Double(words) / 12)))
        if confidence < 0.5 {
            return AdaptiveScrollResult(speed: baseSpeed, confidence: confidence, reason: .insufficientTranscript)
        }
        let target = min(maximumSpeed, max(minimumSpeed, baseSpeed * (spoken / targetWordsPerMinute)))
        let blended = baseSpeed + (target - baseSpeed) * 0.35
        let clamped = min(maximumSpeed, max(minimumSpeed, blended))
        return AdaptiveScrollResult(speed: (clamped * 100).rounded() / 100, confidence: confidence, reason: .adaptive)
    }
}

public struct RehearsalMetrics: Equatable, Codable {
    public var durationSeconds: Int
    public var transcriptWordCount: Int
    public var scriptWordCount: Int
    public var wordsPerMinute: Int?
    public var longPauseCount: Int
    public var fillerWordCount: Int
    public var scriptCoverage: Double?
    public var completionPercent: Int
    public var unavailableMetrics: [String]
    public var suggestions: [String]
    public var repeatedWordCount: Int

    private enum CodingKeys: String, CodingKey {
        case durationSeconds, transcriptWordCount, scriptWordCount, wordsPerMinute, longPauseCount
        case fillerWordCount, scriptCoverage, completionPercent, unavailableMetrics, suggestions, repeatedWordCount
    }

    public init(
        durationSeconds: Int,
        transcriptWordCount: Int,
        scriptWordCount: Int,
        wordsPerMinute: Int?,
        longPauseCount: Int,
        fillerWordCount: Int,
        scriptCoverage: Double?,
        completionPercent: Int,
        unavailableMetrics: [String],
        suggestions: [String],
        repeatedWordCount: Int = 0
    ) {
        self.durationSeconds = durationSeconds
        self.transcriptWordCount = transcriptWordCount
        self.scriptWordCount = scriptWordCount
        self.wordsPerMinute = wordsPerMinute
        self.longPauseCount = longPauseCount
        self.fillerWordCount = fillerWordCount
        self.scriptCoverage = scriptCoverage
        self.completionPercent = completionPercent
        self.unavailableMetrics = unavailableMetrics
        self.suggestions = suggestions
        self.repeatedWordCount = repeatedWordCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
        transcriptWordCount = try container.decodeIfPresent(Int.self, forKey: .transcriptWordCount) ?? 0
        scriptWordCount = try container.decodeIfPresent(Int.self, forKey: .scriptWordCount) ?? 0
        wordsPerMinute = try container.decodeIfPresent(Int.self, forKey: .wordsPerMinute)
        longPauseCount = try container.decodeIfPresent(Int.self, forKey: .longPauseCount) ?? 0
        fillerWordCount = try container.decodeIfPresent(Int.self, forKey: .fillerWordCount) ?? 0
        scriptCoverage = try container.decodeIfPresent(Double.self, forKey: .scriptCoverage)
        completionPercent = try container.decodeIfPresent(Int.self, forKey: .completionPercent) ?? 0
        unavailableMetrics = try container.decodeIfPresent([String].self, forKey: .unavailableMetrics) ?? []
        suggestions = try container.decodeIfPresent([String].self, forKey: .suggestions) ?? []
        repeatedWordCount = try container.decodeIfPresent(Int.self, forKey: .repeatedWordCount) ?? 0
    }
}

public enum RehearsalAnalysis {
    private static let fillerPatterns = [
        "\\bum+\\b", "\\buh+\\b", "\\ber+\\b", "\\bah+\\b", "\\blike\\b", "\\byou know\\b", "\\bi mean\\b", "\\bso\\b"
    ]

    public static func analyze(
        scriptContent: String,
        events: [TranscriptEvent],
        startedAt: Double,
        endedAt: Double,
        longPauseThreshold: Double = 2500
    ) -> RehearsalMetrics {
        let finals = events
            .filter { $0.isFinal && $0.confidence >= 0.4 && !$0.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.timestamp < $1.timestamp }
        let transcript = finals.map(\.transcript).joined(separator: " ")
        let transcriptWords = ReadTime.wordCount(transcript)
        let scriptWords = ReadTime.wordCount(scriptContent)
        let duration = max(0, Int(((endedAt - startedAt) / 1000).rounded()))
        var unavailable: [String] = []
        if finals.isEmpty { unavailable.append("Speech transcript") }
        let wordsPerMinute: Int? = transcriptWords > 0 && duration > 0
            ? Int((Double(transcriptWords) / Double(duration) * 60).rounded())
            : nil
        if wordsPerMinute == nil { unavailable.append("Words per minute") }
        let pauses = zip(finals, finals.dropFirst()).reduce(0) { count, pair in
            pair.1.timestamp - pair.0.timestamp >= longPauseThreshold ? count + 1 : count
        }
        let fillers = fillerPatterns.reduce(0) { $0 + matchCount(transcript, pattern: $1) }
        let repeats = repeatedWords(in: transcript)
        let coverage: Double? = scriptWords > 0 && transcriptWords > 0 ? min(1, Double(transcriptWords) / Double(scriptWords)) : nil
        if coverage == nil { unavailable.append("Script coverage") }
        let partial = RehearsalMetrics(
            durationSeconds: duration,
            transcriptWordCount: transcriptWords,
            scriptWordCount: scriptWords,
            wordsPerMinute: wordsPerMinute,
            longPauseCount: pauses,
            fillerWordCount: fillers,
            scriptCoverage: coverage,
            completionPercent: coverage == nil ? 0 : Int((coverage! * 100).rounded()),
            unavailableMetrics: unavailable,
            suggestions: [],
            repeatedWordCount: repeats
        )
        return RehearsalMetrics(
            durationSeconds: partial.durationSeconds,
            transcriptWordCount: partial.transcriptWordCount,
            scriptWordCount: partial.scriptWordCount,
            wordsPerMinute: partial.wordsPerMinute,
            longPauseCount: partial.longPauseCount,
            fillerWordCount: partial.fillerWordCount,
            scriptCoverage: partial.scriptCoverage,
            completionPercent: partial.completionPercent,
            unavailableMetrics: partial.unavailableMetrics,
            suggestions: suggestions(for: partial),
            repeatedWordCount: partial.repeatedWordCount
        )
    }

    private static func suggestions(for metrics: RehearsalMetrics) -> [String] {
        var lines: [String] = []
        if let pace = metrics.wordsPerMinute, pace > 175 {
            lines.append("Slow down slightly so key points have time to land.")
        }
        if let pace = metrics.wordsPerMinute, pace < 105, metrics.transcriptWordCount > 0 {
            lines.append("Increase pace or shorten pauses to keep delivery moving.")
        }
        if metrics.longPauseCount >= 3 {
            lines.append("Break long sections into shorter phrases to reduce pauses.")
        }
        if metrics.fillerWordCount >= 5 {
            lines.append("Practice replacing filler words with short silent pauses.")
        }
        if metrics.repeatedWordCount >= 3 {
            lines.append("Repeated words are an estimate. A cleaner pass may help if the same word is sticking.")
        }
        if let coverage = metrics.scriptCoverage, coverage < 0.75 {
            lines.append("Rehearse more of the script before recording a final take.")
        }
        if lines.isEmpty && metrics.unavailableMetrics.isEmpty {
            lines.append("Delivery looks steady. Try another pass and compare consistency.")
        }
        if lines.isEmpty {
            lines.append("Try another rehearsal with speech recognition available for fuller feedback.")
        }
        return lines
    }

    public static func repeatedWords(in transcript: String) -> Int {
        let words = transcript.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 1 }
        var count = 0
        var previous = ""
        for word in words {
            if word == previous { count += 1 }
            previous = word
        }
        return count
    }

    private static func matchCount(_ text: String, pattern: String) -> Int {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return expression.numberOfMatches(in: text, range: range)
    }
}

public enum SpeechPrivacy {
    public static let onDeviceNote = "Cuevora uses on-device speech recognition when this iPhone or iPad supports the selected language. Audio is not sent to a Cuevora server. If on-device recognition is unavailable, voice commands and adaptive speed stay off and the prompter keeps the speed you set."
    public static let retentionNote = "A rehearsal transcript is saved on this device only when you choose Save Report. Otherwise it is discarded when you leave rehearsal."
    public static let recordingContentionNote = "Voice recognition is turned off while recording so the microphone can be used for the video."
}

public struct SpeechGate: Equatable {
    public var onDeviceSupported: Bool
    public var permissionGranted: Bool
    public var recordingInProgress: Bool
    public var localeIdentifier: String
    public var recognizerAvailable: Bool
    public var networkReachable: Bool

    public init(onDeviceSupported: Bool, permissionGranted: Bool, recordingInProgress: Bool, localeIdentifier: String, recognizerAvailable: Bool = true, networkReachable: Bool = true) {
        self.onDeviceSupported = onDeviceSupported
        self.permissionGranted = permissionGranted
        self.recordingInProgress = recordingInProgress
        self.localeIdentifier = localeIdentifier
        self.recognizerAvailable = recognizerAvailable
        self.networkReachable = networkReachable
    }

    public var canListen: Bool {
        SpeechLocalePolicy.listens(onDeviceSupported: onDeviceSupported, recognizerAvailable: recognizerAvailable)
            && permissionGranted
            && !recordingInProgress
    }

    public var usesServerRecognition: Bool { SpeechLocalePolicy.usesServerRecognition }

    public var unavailableReason: String? {
        if recordingInProgress { return SpeechPrivacy.recordingContentionNote }
        if !permissionGranted { return "Speech recognition permission is off. You can keep prompting at a fixed speed." }
        if !recognizerAvailable { return "Speech recognition stopped. Cuevora did not switch to server recognition. You can keep using the speed control." }
        if !onDeviceSupported { return "On-device speech recognition is not available for \(localeIdentifier). Cuevora will not send audio to a server. Use the speed control instead." }
        return nil
    }
}
