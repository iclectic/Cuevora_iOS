import Foundation
import SwiftData

@Model
final class Script {
    var uuid: UUID?
    var title: String
    var content: String
    var createdAt: Date?
    var updatedAt: Date
    var tags: [String]
    var markers: [Int]
    var highlights: [Int]
    var readingProgress: Double = 0
    var pinned: Bool = false
    /// Stable id from this device or from a backup. Android ids are not UUIDs, so they live here.
    var externalID: String = ""
    /// Earlier builds stored revision text without timestamps. New saves use `snapshots`.
    var revisions: [String]
    @Relationship(deleteRule: .cascade, inverse: \RevisionSnapshot.script)
    var snapshots: [RevisionSnapshot]
    @Relationship(deleteRule: .nullify, inverse: \RehearsalRecord.script)
    var rehearsals: [RehearsalRecord]
    @Relationship(deleteRule: .nullify, inverse: \RecordingItem.script)
    var recordings: [RecordingItem]

    init() {
        let identifier = UUID()
        uuid = identifier
        title = "Untitled Script"
        content = ""
        createdAt = .now
        updatedAt = .now
        tags = []
        markers = []
        highlights = []
        readingProgress = 0
        pinned = false
        externalID = identifier.uuidString
        revisions = []
        snapshots = []
        rehearsals = []
        recordings = []
    }

    var identity: UUID {
        if let uuid { return uuid }
        let created = UUID()
        uuid = created
        return created
    }

    var createdDate: Date { createdAt ?? updatedAt }

    var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Script" : title }
}

@Model
final class RevisionSnapshot {
    var content: String
    var createdAt: Date
    var script: Script?

    init(content: String, createdAt: Date = .now) {
        self.content = content
        self.createdAt = createdAt
    }
}

@Model
final class RehearsalRecord {
    var scriptTitle: String
    var startedAt: Date
    var endedAt: Date
    var summary: String
    var metricsJSON: String
    var transcriptJSON: String
    var transcriptRetained: Bool
    var script: Script?

    init(scriptTitle: String, startedAt: Date, endedAt: Date, summary: String, metricsJSON: String, transcriptJSON: String, transcriptRetained: Bool) {
        self.scriptTitle = scriptTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.summary = summary
        self.metricsJSON = metricsJSON
        self.transcriptJSON = transcriptJSON
        self.transcriptRetained = transcriptRetained
    }
}

@Model
final class RecordingItem {
    var fileName: String
    var scriptTitle: String
    var createdAt: Date
    var duration: Double
    var partial: Bool
    var recoverable: Bool
    var script: Script?

    init(fileName: String, scriptTitle: String, createdAt: Date = .now, duration: Double, partial: Bool, recoverable: Bool = true) {
        self.fileName = fileName
        self.scriptTitle = scriptTitle
        self.createdAt = createdAt
        self.duration = duration
        self.partial = partial
        self.recoverable = recoverable
    }
}

@Model
final class AppPreferences {
    var singleton: String
    var colorMode: String
    var defaultTheme: String
    var defaultSpeed: Double
    var defaultFontSize: Double
    var defaultLineSpacing: Double
    var wordsPerMinute: Int
    var keepScreenAwake: Bool
    var mirrorMode: Bool
    var countdownDuration: Int
    var focusLineEnabled: Bool
    var hapticsEnabled: Bool
    var gestureControlsEnabled: Bool
    var voiceControlsEnabled: Bool
    var adaptiveScrollEnabled: Bool
    var accessibilityProfile: String
    var recordingQuality: String
    var onboardingComplete: Bool
    var lastScriptUUID: UUID?
    var lastProgress: Double
    var sortOrder: Int
    var compactList: Bool
    var selectedTag: String?

    init() {
        let defaults = PortableSettings()
        singleton = "settings"
        colorMode = defaults.colorMode
        defaultTheme = defaults.defaultTheme
        defaultSpeed = defaults.defaultSpeed
        defaultFontSize = defaults.defaultFontSize
        defaultLineSpacing = defaults.defaultLineSpacing
        wordsPerMinute = defaults.wordsPerMinute
        keepScreenAwake = defaults.keepScreenAwake
        mirrorMode = defaults.mirrorMode
        countdownDuration = defaults.countdownDuration
        focusLineEnabled = defaults.focusLineEnabled
        hapticsEnabled = defaults.hapticsEnabled
        gestureControlsEnabled = defaults.gestureControlsEnabled
        voiceControlsEnabled = defaults.voiceControlsEnabled
        adaptiveScrollEnabled = defaults.adaptiveScrollEnabled
        accessibilityProfile = defaults.accessibilityProfile
        recordingQuality = defaults.recordingQuality
        onboardingComplete = defaults.onboardingComplete
        lastProgress = 0
        sortOrder = 0
        compactList = false
    }

    var profile: ReadingProfile { ReadingProfile(rawValue: accessibilityProfile) ?? .default }
    var theme: PromptTheme { PromptTheme(rawValue: defaultTheme) ?? .dark }

    func portable() -> PortableSettings {
        PortableSettings(
            colorMode: colorMode,
            defaultTheme: defaultTheme,
            defaultSpeed: defaultSpeed,
            defaultFontSize: defaultFontSize,
            defaultLineSpacing: defaultLineSpacing,
            wordsPerMinute: wordsPerMinute,
            keepScreenAwake: keepScreenAwake,
            mirrorMode: mirrorMode,
            countdownDuration: countdownDuration,
            focusLineEnabled: focusLineEnabled,
            hapticsEnabled: hapticsEnabled,
            gestureControlsEnabled: gestureControlsEnabled,
            voiceControlsEnabled: voiceControlsEnabled,
            adaptiveScrollEnabled: adaptiveScrollEnabled,
            accessibilityProfile: accessibilityProfile,
            recordingQuality: recordingQuality,
            onboardingComplete: onboardingComplete
        )
    }

    func apply(_ settings: PortableSettings) {
        colorMode = settings.colorMode
        defaultTheme = settings.defaultTheme
        defaultSpeed = settings.defaultSpeed
        defaultFontSize = settings.defaultFontSize
        defaultLineSpacing = settings.defaultLineSpacing
        wordsPerMinute = settings.wordsPerMinute
        keepScreenAwake = settings.keepScreenAwake
        mirrorMode = settings.mirrorMode
        countdownDuration = settings.countdownDuration
        focusLineEnabled = settings.focusLineEnabled
        hapticsEnabled = settings.hapticsEnabled
        gestureControlsEnabled = settings.gestureControlsEnabled
        voiceControlsEnabled = settings.voiceControlsEnabled
        adaptiveScrollEnabled = settings.adaptiveScrollEnabled
        accessibilityProfile = settings.accessibilityProfile
        recordingQuality = settings.recordingQuality
        onboardingComplete = settings.onboardingComplete
    }
}
