import CoreFoundation
import Foundation

public struct PortableRevision: Equatable, Codable {
    public var content: String
    public var timestamp: Date

    public init(content: String, timestamp: Date) {
        self.content = content
        self.timestamp = timestamp
    }
}

public struct PortableScript: Equatable, Codable {
    public var sourceID: String?
    public var title: String
    public var content: String
    public var tags: [String]
    public var markers: [Int]
    public var highlights: [Int]
    public var createdAt: Date
    public var updatedAt: Date
    public var revisions: [PortableRevision]

    public init(
        sourceID: String? = nil,
        title: String,
        content: String,
        tags: [String],
        markers: [Int] = [],
        highlights: [Int] = [],
        createdAt: Date,
        updatedAt: Date,
        revisions: [PortableRevision] = []
    ) {
        self.sourceID = sourceID
        self.title = title
        self.content = content
        self.tags = tags
        self.markers = markers
        self.highlights = highlights
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revisions = revisions
    }
}

public struct PortableSettings: Equatable, Codable {
    public var colorMode: String
    public var defaultTheme: String
    public var defaultSpeed: Double
    public var defaultFontSize: Double
    public var defaultLineSpacing: Double
    public var wordsPerMinute: Int
    public var keepScreenAwake: Bool
    public var mirrorMode: Bool
    public var countdownDuration: Int
    public var focusLineEnabled: Bool
    public var hapticsEnabled: Bool
    public var gestureControlsEnabled: Bool
    public var voiceControlsEnabled: Bool
    public var adaptiveScrollEnabled: Bool
    public var accessibilityProfile: String
    public var recordingQuality: String
    public var onboardingComplete: Bool

    public init(
        colorMode: String = "system",
        defaultTheme: String = "dark",
        defaultSpeed: Double = 3,
        defaultFontSize: Double = 32,
        defaultLineSpacing: Double = 1.6,
        wordsPerMinute: Int = 140,
        keepScreenAwake: Bool = true,
        mirrorMode: Bool = false,
        countdownDuration: Int = 3,
        focusLineEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        gestureControlsEnabled: Bool = true,
        voiceControlsEnabled: Bool = false,
        adaptiveScrollEnabled: Bool = false,
        accessibilityProfile: String = "default",
        recordingQuality: String = "high",
        onboardingComplete: Bool = false
    ) {
        self.colorMode = colorMode
        self.defaultTheme = defaultTheme
        self.defaultSpeed = defaultSpeed
        self.defaultFontSize = defaultFontSize
        self.defaultLineSpacing = defaultLineSpacing
        self.wordsPerMinute = wordsPerMinute
        self.keepScreenAwake = keepScreenAwake
        self.mirrorMode = mirrorMode
        self.countdownDuration = countdownDuration
        self.focusLineEnabled = focusLineEnabled
        self.hapticsEnabled = hapticsEnabled
        self.gestureControlsEnabled = gestureControlsEnabled
        self.voiceControlsEnabled = voiceControlsEnabled
        self.adaptiveScrollEnabled = adaptiveScrollEnabled
        self.accessibilityProfile = accessibilityProfile
        self.recordingQuality = recordingQuality
        self.onboardingComplete = onboardingComplete
    }
}

public struct PortableRehearsal: Equatable, Codable {
    public var scriptSourceID: String?
    public var scriptTitle: String
    public var startedAt: Date
    public var endedAt: Date
    public var metrics: RehearsalMetrics
    public var transcript: [TranscriptEvent]

    public init(scriptSourceID: String?, scriptTitle: String, startedAt: Date, endedAt: Date, metrics: RehearsalMetrics, transcript: [TranscriptEvent]) {
        self.scriptSourceID = scriptSourceID
        self.scriptTitle = scriptTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.metrics = metrics
        self.transcript = transcript
    }
}

public struct BackupDocumentModel: Equatable {
    public var source: Source
    public var scripts: [PortableScript]
    public var settings: PortableSettings?
    public var rehearsals: [PortableRehearsal]
    public var notices: [String]

    public enum Source: String, Equatable {
        case iosVersion1 = "cuevora-ios-v1"
        case iosVersion2 = "cuevora-ios-v2"
        case androidVersion1 = "cuevora-android-v1"
    }

    public init(source: Source, scripts: [PortableScript], settings: PortableSettings?, rehearsals: [PortableRehearsal], notices: [String]) {
        self.source = source
        self.scripts = scripts
        self.settings = settings
        self.rehearsals = rehearsals
        self.notices = notices
    }
}

public enum BackupCodecError: Error, Equatable {
    case malformed
    case unsupportedVersion
    case tooLarge
    case invalidContent(String)
}

public enum BackupCodec {
    public static let maxBytes = 10_000_000
    public static let maxScripts = 10_000
    public static let maxTitleLength = 10_000
    public static let maxContentLength = 2_000_000
    public static let maxTags = 1_000
    public static let maxRevisions = 10
    public static let formatIdentifier = "cuevora-ios"

    public static func encode(scripts: [PortableScript], settings: PortableSettings, rehearsals: [PortableRehearsal], exportedAt: Date = Date()) throws -> Data {
        let checked = try validate(scripts: scripts)
        let payload: [String: Any] = [
            "format": formatIdentifier,
            "version": 2,
            "exportedAt": milliseconds(exportedAt),
            "includesRecordings": false,
            "scripts": checked.map(encodeScript),
            "settings": encodeSettings(settings),
            "rehearsalSessions": rehearsals.map(encodeRehearsal)
        ]
        guard JSONSerialization.isValidJSONObject(payload), let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            throw BackupCodecError.malformed
        }
        if data.count > maxBytes { throw BackupCodecError.tooLarge }
        return data
    }

    public static func decode(_ data: Data) throws -> BackupDocumentModel {
        if data.count > maxBytes { throw BackupCodecError.tooLarge }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupCodecError.malformed
        }
        guard let scriptsValue = root["scripts"] as? [Any] else { throw BackupCodecError.malformed }
        if scriptsValue.count > maxScripts { throw BackupCodecError.invalidContent("Too many scripts.") }

        let format = root["format"] as? String
        let version = integer(root["version"])
        if format == formatIdentifier {
            guard version == 2 else { throw BackupCodecError.unsupportedVersion }
            return try decodeIOSVersion2(root, scriptsValue: scriptsValue)
        }
        if looksLikeAndroid(root, scriptsValue: scriptsValue) {
            guard version == 1 else { throw BackupCodecError.unsupportedVersion }
            return try decodeAndroid(root, scriptsValue: scriptsValue)
        }
        guard version == 1 else { throw BackupCodecError.unsupportedVersion }
        return try decodeIOSVersion1(scriptsValue)
    }

    private static func decodeIOSVersion2(_ root: [String: Any], scriptsValue: [Any]) throws -> BackupDocumentModel {
        var notices = ["Recordings are not included in this backup."]
        if root["includesRecordings"] as? Bool == true {
            notices.append("This file says it includes recordings, but Cuevora iOS backups do not restore video.")
        }
        let scripts = try scripts(fromIOSObjects: scriptsValue, notices: &notices)
        return BackupDocumentModel(
            source: .iosVersion2,
            scripts: scripts,
            settings: settings(from: root["settings"], notices: &notices),
            rehearsals: rehearsals(from: root["rehearsalSessions"], notices: &notices),
            notices: notices
        )
    }

    private static func decodeIOSVersion1(_ scriptsValue: [Any]) throws -> BackupDocumentModel {
        let notices = ["Imported an earlier Cuevora iOS backup. Recordings were not part of that file."]
        var scripts: [PortableScript] = []
        for value in scriptsValue {
            guard let object = value as? [String: Any] else { throw BackupCodecError.invalidContent("A script entry was not an object.") }
            let title = limitedTitle(object["title"] as? String)
            let content = try limitedContent(object["content"] as? String ?? "")
            let tags = tags(from: object["tags"])
            let updated = referenceDate(object["updatedAt"]) ?? Date()
            let revisionStrings = (object["revisions"] as? [Any] ?? []).compactMap { $0 as? String }
            if revisionStrings.count > maxRevisions { throw BackupCodecError.invalidContent("A script has more than \(maxRevisions) revisions.") }
            let revisions = revisionStrings.prefix(maxRevisions).map { PortableRevision(content: String($0.prefix(maxContentLength)), timestamp: updated) }
            scripts.append(PortableScript(title: title, content: content, tags: tags, createdAt: updated, updatedAt: updated, revisions: Array(revisions)))
        }
        return BackupDocumentModel(source: .iosVersion1, scripts: scripts, settings: nil, rehearsals: [], notices: notices)
    }

    private static func decodeAndroid(_ root: [String: Any], scriptsValue: [Any]) throws -> BackupDocumentModel {
        var notices = [
            "Imported a Cuevora Android backup (schema version 1). Video recordings are not in this file.",
            "Markers and highlights are kept with each script."
        ]
        var scriptsByID: [String: PortableScript] = [:]
        var ordered: [PortableScript] = []
        var seenIDs = Set<String>()
        for value in scriptsValue {
            guard let object = value as? [String: Any] else { throw BackupCodecError.invalidContent("A script entry was not an object.") }
            if object["id"] as? String == nil { throw BackupCodecError.invalidContent("An Android script is missing an id.") }
            let sourceID = object["id"] as? String
            if let sourceID {
                if seenIDs.contains(sourceID) {
                    notices.append("Duplicate script id \(sourceID) was imported as a separate copy.")
                }
                seenIDs.insert(sourceID)
            }
            let created = unixDate(object["createdAt"]) ?? Date()
            let updated = unixDate(object["updatedAt"]) ?? created
            if object["createdAt"] != nil && unixDate(object["createdAt"]) == nil {
                notices.append("A script timestamp could not be read and was replaced with the import time.")
            }
            let script = PortableScript(
                sourceID: sourceID,
                title: limitedTitle(object["title"] as? String),
                content: try limitedContent(object["content"] as? String ?? ""),
                tags: tags(from: object["tags"]),
                markers: integers(object["markers"]),
                highlights: integers(object["highlights"]),
                createdAt: created,
                updatedAt: updated,
                revisions: []
            )
            ordered.append(script)
            if let sourceID, scriptsByID[sourceID] == nil { scriptsByID[sourceID] = script }
            reportUnknownKeys(object, known: ["id", "title", "content", "tags", "createdAt", "updatedAt", "markers", "highlights"], label: "script", notices: &notices)
        }
        if let revisions = root["revisions"] as? [Any] {
            var grouped: [String: [PortableRevision]] = [:]
            for value in revisions {
                guard let object = value as? [String: Any],
                      let scriptID = object["scriptId"] as? String,
                      scriptsByID[scriptID] != nil else {
                    notices.append("A revision did not match an imported script and was skipped.")
                    continue
                }
                let content = String(((object["content"] as? String) ?? "").prefix(maxContentLength))
                let timestamp = unixDate(object["timestamp"]) ?? Date()
                grouped[scriptID, default: []].append(PortableRevision(content: content, timestamp: timestamp))
            }
            ordered = ordered.map { script in
                guard let sourceID = script.sourceID, var revisions = grouped[sourceID] else { return script }
                revisions.sort { $0.timestamp > $1.timestamp }
                if revisions.count > maxRevisions {
                    notices.append("Only the newest \(maxRevisions) revisions were kept for one script.")
                    revisions = Array(revisions.prefix(maxRevisions))
                }
                var copy = script
                copy.revisions = revisions
                return copy
            }
        }
        if root["settings"] != nil {
            notices.append("Android settings that Cuevora iOS understands can be applied with this import. Analytics preferences are ignored because this app does not collect analytics.")
        }
        reportUnknownKeys(root, known: ["version", "scripts", "revisions", "settings", "rehearsalSessions", "exportedAt"], label: "backup", notices: &notices)
        return BackupDocumentModel(
            source: .androidVersion1,
            scripts: ordered,
            settings: settings(from: root["settings"], notices: &notices),
            rehearsals: rehearsals(from: root["rehearsalSessions"], notices: &notices),
            notices: unique(notices)
        )
    }

    private static func scripts(fromIOSObjects values: [Any], notices: inout [String]) throws -> [PortableScript] {
        try values.map { value in
            guard let object = value as? [String: Any] else { throw BackupCodecError.invalidContent("A script entry was not an object.") }
            let revisionValues = object["revisions"] as? [Any] ?? []
            if revisionValues.count > maxRevisions { throw BackupCodecError.invalidContent("A script has more than \(maxRevisions) revisions.") }
            let revisions: [PortableRevision] = try revisionValues.map { item in
                guard let revision = item as? [String: Any] else { throw BackupCodecError.invalidContent("A revision was not an object.") }
                return PortableRevision(
                    content: try limitedContent((revision["content"] as? String) ?? ""),
                    timestamp: unixDate(revision["timestamp"]) ?? Date()
                )
            }
            return PortableScript(
                sourceID: object["id"] as? String,
                title: limitedTitle(object["title"] as? String),
                content: try limitedContent(object["content"] as? String ?? ""),
                tags: tags(from: object["tags"]),
                markers: integers(object["markers"]),
                highlights: integers(object["highlights"]),
                createdAt: unixDate(object["createdAt"]) ?? Date(),
                updatedAt: unixDate(object["updatedAt"]) ?? Date(),
                revisions: revisions
            )
        }
    }

    private static func settings(from value: Any?, notices: inout [String]) -> PortableSettings? {
        guard let object = value as? [String: Any] else { return nil }
        var settings = PortableSettings()
        if let mode = object["colorMode"] as? String, ["system", "light", "dark"].contains(mode) { settings.colorMode = mode }
        if let theme = object["defaultTheme"] as? String, PromptTheme(rawValue: theme) != nil { settings.defaultTheme = theme }
        if let speed = number(object["defaultSpeed"]) { settings.defaultSpeed = min(10, max(1, speed)) }
        if let size = number(object["defaultFontSize"]) { settings.defaultFontSize = min(72, max(16, size)) }
        if let spacing = number(object["defaultLineSpacing"]) { settings.defaultLineSpacing = min(3, max(1, spacing)) }
        if let wpm = integer(object["wpm"]) { settings.wordsPerMinute = min(400, max(40, wpm)) }
        if let awake = object["keepScreenAwake"] as? Bool { settings.keepScreenAwake = awake }
        if let mirror = object["mirrorMode"] as? Bool { settings.mirrorMode = mirror }
        if let countdown = integer(object["countdownDuration"]), [0, 3, 5, 10].contains(countdown) { settings.countdownDuration = countdown }
        if let focus = object["focusLineEnabled"] as? Bool { settings.focusLineEnabled = focus }
        if let haptics = object["hapticsEnabled"] as? Bool { settings.hapticsEnabled = haptics }
        if let gestures = object["gestureControlsEnabled"] as? Bool { settings.gestureControlsEnabled = gestures }
        if let voice = object["voiceControlsEnabled"] as? Bool { settings.voiceControlsEnabled = voice }
        if let adaptive = object["adaptiveScrollEnabled"] as? Bool { settings.adaptiveScrollEnabled = adaptive }
        if let profile = object["accessibilityProfile"] as? String, ReadingProfile(rawValue: profile) != nil {
            settings.accessibilityProfile = profile
        }
        if let quality = object["recordingQuality"] as? String, ["standard", "high"].contains(quality) { settings.recordingQuality = quality }
        if let onboarding = object["onboardingComplete"] as? Bool { settings.onboardingComplete = onboarding }
        if object["analyticsOptIn"] != nil {
            notices.append("The analytics preference was not imported. This iOS app does not collect analytics.")
        }
        reportUnknownKeys(object, known: [
            "defaultTheme", "defaultSpeed", "defaultFontSize", "defaultLineSpacing", "wpm", "keepScreenAwake",
            "analyticsOptIn", "onboardingComplete", "mirrorMode", "countdownDuration", "focusLineEnabled", "colorMode",
            "hapticsEnabled", "gestureControlsEnabled", "voiceControlsEnabled", "adaptiveScrollEnabled",
            "accessibilityProfile", "recordingQuality"
        ], label: "settings", notices: &notices)
        return settings
    }

    private static func rehearsals(from value: Any?, notices: inout [String]) -> [PortableRehearsal] {
        guard let values = value as? [Any] else { return [] }
        return values.compactMap { item in
            guard let object = item as? [String: Any], let metrics = object["metrics"] as? [String: Any] else {
                notices.append("A rehearsal session was skipped because its metrics were missing.")
                return nil
            }
            let transcript = (object["transcriptEvents"] as? [Any] ?? []).compactMap(transcriptEvent)
            if let raw = object["transcriptEvents"] as? [Any], transcript.count != raw.count {
                notices.append("Some transcript events were skipped because they were incomplete.")
            }
            let parsed = RehearsalMetrics(
                durationSeconds: integer(metrics["durationSeconds"]) ?? 0,
                transcriptWordCount: integer(metrics["transcriptWordCount"]) ?? 0,
                scriptWordCount: integer(metrics["scriptWordCount"]) ?? 0,
                wordsPerMinute: integer(metrics["wordsPerMinute"]),
                longPauseCount: integer(metrics["longPauseCount"]) ?? 0,
                fillerWordCount: integer(metrics["fillerWordCount"]) ?? 0,
                scriptCoverage: number(metrics["scriptCoverage"]),
                completionPercent: integer(metrics["completionPercent"]) ?? 0,
                unavailableMetrics: (metrics["unavailableMetrics"] as? [Any] ?? []).compactMap { $0 as? String },
                suggestions: (metrics["suggestions"] as? [Any] ?? []).compactMap { $0 as? String }
            )
            return PortableRehearsal(
                scriptSourceID: object["scriptId"] as? String,
                scriptTitle: (object["scriptTitle"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled Script",
                startedAt: unixDate(object["startedAt"]) ?? Date(),
                endedAt: unixDate(object["endedAt"]) ?? Date(),
                metrics: parsed,
                transcript: transcript
            )
        }
    }

    private static func transcriptEvent(_ value: Any) -> TranscriptEvent? {
        guard let object = value as? [String: Any], let transcript = object["transcript"] as? String, object["timestamp"] != nil else { return nil }
        return TranscriptEvent(
            transcript: transcript,
            confidence: number(object["confidence"]) ?? 0,
            isFinal: object["isFinal"] as? Bool ?? true,
            timestamp: number(object["timestamp"]) ?? 0,
            source: object["source"] as? String ?? "imported"
        )
    }

    private static func looksLikeAndroid(_ root: [String: Any], scriptsValue: [Any]) -> Bool {
        if root["exportedAt"] != nil || root["rehearsalSessions"] != nil || root["revisions"] != nil { return true }
        return scriptsValue.contains { value in
            guard let object = value as? [String: Any] else { return false }
            return object["createdAt"] != nil || object["markers"] != nil || object["id"] != nil
        }
    }

    private static func validate(scripts: [PortableScript]) throws -> [PortableScript] {
        if scripts.count > maxScripts { throw BackupCodecError.invalidContent("Too many scripts.") }
        return try scripts.map { script in
            var copy = script
            copy.title = limitedTitle(script.title)
            copy.content = try limitedContent(script.content)
            copy.tags = Array(script.tags.prefix(maxTags))
            copy.revisions = Array(script.revisions.sorted { $0.timestamp > $1.timestamp }.prefix(maxRevisions))
            return copy
        }
    }

    private static func encodeScript(_ script: PortableScript) -> [String: Any] {
        [
            "id": script.sourceID ?? UUID().uuidString,
            "title": script.title,
            "content": script.content,
            "tags": script.tags,
            "markers": script.markers,
            "highlights": script.highlights,
            "createdAt": milliseconds(script.createdAt),
            "updatedAt": milliseconds(script.updatedAt),
            "revisions": script.revisions.map { ["content": $0.content, "timestamp": milliseconds($0.timestamp)] }
        ]
    }

    private static func encodeSettings(_ settings: PortableSettings) -> [String: Any] {
        [
            "colorMode": settings.colorMode,
            "defaultTheme": settings.defaultTheme,
            "defaultSpeed": settings.defaultSpeed,
            "defaultFontSize": settings.defaultFontSize,
            "defaultLineSpacing": settings.defaultLineSpacing,
            "wpm": settings.wordsPerMinute,
            "keepScreenAwake": settings.keepScreenAwake,
            "mirrorMode": settings.mirrorMode,
            "countdownDuration": settings.countdownDuration,
            "focusLineEnabled": settings.focusLineEnabled,
            "hapticsEnabled": settings.hapticsEnabled,
            "gestureControlsEnabled": settings.gestureControlsEnabled,
            "voiceControlsEnabled": settings.voiceControlsEnabled,
            "adaptiveScrollEnabled": settings.adaptiveScrollEnabled,
            "accessibilityProfile": settings.accessibilityProfile,
            "recordingQuality": settings.recordingQuality,
            "onboardingComplete": settings.onboardingComplete
        ]
    }

    private static func encodeRehearsal(_ session: PortableRehearsal) -> [String: Any] {
        [
            "scriptId": session.scriptSourceID ?? "",
            "scriptTitle": session.scriptTitle,
            "startedAt": milliseconds(session.startedAt),
            "endedAt": milliseconds(session.endedAt),
            "transcriptEvents": session.transcript.map {
                ["transcript": $0.transcript, "confidence": $0.confidence, "isFinal": $0.isFinal, "timestamp": $0.timestamp, "source": $0.source]
            },
            "metrics": [
                "durationSeconds": session.metrics.durationSeconds,
                "transcriptWordCount": session.metrics.transcriptWordCount,
                "scriptWordCount": session.metrics.scriptWordCount,
                "wordsPerMinute": (session.metrics.wordsPerMinute ?? NSNull()) as Any,
                "longPauseCount": session.metrics.longPauseCount,
                "fillerWordCount": session.metrics.fillerWordCount,
                "scriptCoverage": (session.metrics.scriptCoverage ?? NSNull()) as Any,
                "completionPercent": session.metrics.completionPercent,
                "unavailableMetrics": session.metrics.unavailableMetrics,
                "suggestions": session.metrics.suggestions
            ]
        ]
    }

    private static func limitedTitle(_ title: String?) -> String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? "Untitled Script" : trimmed
        return String(value.prefix(maxTitleLength))
    }

    private static func limitedContent(_ content: String) throws -> String {
        if content.count > maxContentLength { throw BackupCodecError.invalidContent("A script is longer than \(maxContentLength) characters.") }
        return content
    }

    private static func tags(from value: Any?) -> [String] {
        guard let values = value as? [Any] else { return [] }
        let tags = values.compactMap { $0 as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Array(tags.prefix(maxTags))
    }

    private static func integers(_ value: Any?) -> [Int] {
        (value as? [Any] ?? []).compactMap(integer)
    }

    private static func isJSONBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let value, !isJSONBoolean(value) else { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        guard let value, !isJSONBoolean(value) else { return nil }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private static func unixDate(_ value: Any?) -> Date? {
        guard let number = number(value) else { return nil }
        if number >= 10_000_000_000 { return Date(timeIntervalSince1970: number / 1000) }
        return nil
    }

    private static func referenceDate(_ value: Any?) -> Date? {
        guard let number = number(value) else { return nil }
        return Date(timeIntervalSinceReferenceDate: number)
    }

    private static func milliseconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }

    private static func reportUnknownKeys(_ object: [String: Any], known: [String], label: String, notices: inout [String]) {
        let unknown = object.keys.filter { !known.contains($0) }.sorted()
        if !unknown.isEmpty {
            notices.append("Unsupported \(label) fields were ignored: \(unknown.joined(separator: ", ")).")
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted         }
    }
}
