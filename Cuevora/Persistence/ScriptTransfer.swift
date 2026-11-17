import Foundation
import SwiftData

enum ScriptTransfer {
    static func portable(_ script: Script) -> PortableScript {
        let stored = script.snapshots.sorted { $0.createdAt > $1.createdAt }
        let revisions = stored.isEmpty
            ? script.revisions.map { PortableRevision(content: $0, timestamp: script.updatedAt) }
            : stored.map { PortableRevision(content: $0.content, timestamp: $0.createdAt) }
        return PortableScript(
            sourceID: script.identity.uuidString,
            title: script.title,
            content: script.content,
            tags: script.tags,
            markers: script.markers,
            highlights: script.highlights,
            createdAt: script.createdDate,
            updatedAt: script.updatedAt,
            revisions: revisions
        )
    }

    @discardableResult
    static func insert(_ portable: PortableScript, into context: ModelContext) -> Script {
        let script = Script()
        script.title = portable.title
        script.content = portable.content
        script.tags = portable.tags
        script.markers = portable.markers
        script.highlights = portable.highlights
        script.createdAt = portable.createdAt
        script.updatedAt = portable.updatedAt
        script.revisions = []
        context.insert(script)
        for revision in portable.revisions.sorted(by: { $0.timestamp > $1.timestamp }).prefix(BackupCodec.maxRevisions) {
            let snapshot = RevisionSnapshot(content: revision.content, createdAt: revision.timestamp)
            snapshot.script = script
            context.insert(snapshot)
        }
        return script
    }

    static func promoteLegacyRevisions(for script: Script, in context: ModelContext) {
        guard script.snapshots.isEmpty else { return }
        for content in script.revisions where !content.isEmpty {
            let snapshot = RevisionSnapshot(content: content, createdAt: script.updatedAt)
            snapshot.script = script
            context.insert(snapshot)
        }
    }

    static func rehearsalRecord(for script: Script, metrics: RehearsalMetrics, events: [TranscriptEvent], startedAt: Date, endedAt: Date) -> RehearsalRecord {
        let encoder = JSONEncoder()
        let metricsJSON = (try? encoder.encode(metrics)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let transcriptJSON = (try? encoder.encode(events)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let coverage = metrics.scriptCoverage.map { "\(Int(($0 * 100).rounded()))%" } ?? "unavailable"
        let pace = metrics.wordsPerMinute.map { "\($0) words per minute, estimated" } ?? "pace unavailable"
        let summary = "\(pace). Coverage \(coverage). \(metrics.longPauseCount) long pauses. \(metrics.fillerWordCount) filler matches. \(metrics.suggestions.joined(separator: " "))"
        return RehearsalRecord(
            scriptTitle: script.displayTitle,
            startedAt: startedAt,
            endedAt: endedAt,
            summary: summary,
            metricsJSON: metricsJSON,
            transcriptJSON: transcriptJSON,
            transcriptRetained: true
        )
    }

    static func portableRehearsal(_ record: RehearsalRecord) -> PortableRehearsal? {
        guard let metricsData = record.metricsJSON.data(using: .utf8),
              let metrics = try? JSONDecoder().decode(RehearsalMetrics.self, from: metricsData) else { return nil }
        let transcript = record.transcriptJSON.data(using: .utf8).flatMap { try? JSONDecoder().decode([TranscriptEvent].self, from: $0) } ?? []
        return PortableRehearsal(
            scriptSourceID: record.script?.identity.uuidString,
            scriptTitle: record.scriptTitle,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            metrics: metrics,
            transcript: record.transcriptRetained ? transcript : []
        )
    }
}

enum RecordingFiles {
    static func folder() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = base.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func url(for item: RecordingItem) throws -> URL {
        try folder().appendingPathComponent(item.fileName)
    }

    static func removeFile(named fileName: String) {
        guard let folder = try? folder() else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(fileName))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(fileName + ".writing"))
    }
}

enum ShortcutInbox {
    private static var url: URL? {
        guard let base = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return base.appendingPathComponent("shortcut-command.txt")
    }

    static func write(_ action: ShortcutAction) {
        guard let url else { return }
        try? Data(action.rawValue.utf8).write(to: url, options: .atomic)
    }

    static func consume() -> ShortcutAction? {
        guard let url, let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return ShortcutAction(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
