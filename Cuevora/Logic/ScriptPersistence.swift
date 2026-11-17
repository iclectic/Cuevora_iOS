import Foundation

/// The writing draft behind the editor. Rapid edits stay in `content` until the debounce
/// elapses, and a failed save leaves that text in place for another attempt.
public struct ScriptDraft: Equatable {
    public static let debounce: TimeInterval = 0.7

    public enum Status: Equatable {
        case saved
        case saving
        case notSaved
    }

    public var title: String
    public var tagText: String
    public var content: String
    public var savedContent: String
    public var revisions: [PortableRevision]
    public var status: Status
    public var lastChange: Date?

    public init(title: String, tagText: String, content: String, savedContent: String, revisions: [PortableRevision] = [], status: Status = .saved, lastChange: Date? = nil) {
        self.title = title
        self.tagText = tagText
        self.content = content
        self.savedContent = savedContent
        self.revisions = revisions.sorted { $0.timestamp > $1.timestamp }
        self.status = status
        self.lastChange = lastChange
    }

    public static func tags(in text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    public mutating func change(at date: Date) {
        lastChange = date
        status = .saving
    }

    public func isReady(at date: Date) -> Bool {
        guard status == .saving, let lastChange else { return false }
        return date.timeIntervalSince(lastChange) >= Self.debounce
    }

    /// Records the previously saved text as one revision and marks the draft saved.
    @discardableResult
    public mutating func succeed(at date: Date) -> PortableRevision? {
        var added: PortableRevision?
        if savedContent != content && !savedContent.isEmpty {
            added = PortableRevision(content: savedContent, timestamp: date)
            revisions.append(added!)
            revisions.sort { $0.timestamp > $1.timestamp }
            if revisions.count > BackupCodec.maxRevisions {
                revisions = Array(revisions.prefix(BackupCodec.maxRevisions))
            }
        }
        savedContent = content
        status = .saved
        lastChange = nil
        return added
    }

    public mutating func fail() {
        status = .notSaved
    }
}

public struct StoredScript: Equatable, Identifiable {
    public var id: String
    public var script: PortableScript
    public var readingProgress: Double
    public var pinned: Bool

    public init(id: String, script: PortableScript, readingProgress: Double = 0, pinned: Bool = false) {
        self.id = id
        self.script = script
        self.readingProgress = readingProgress
        self.pinned = pinned
    }
}

public enum ImportChoice: Equatable {
    case cancelled
    case copy
    case merge
    case replace
}

/// Script library decisions that do not touch the database. A choice returns a new value,
/// so cancelling or rejecting a file leaves the caller's copy unchanged.
public struct ScriptLibrary: Equatable {
    public var scripts: [StoredScript]
    public var recordingIDs: [String]
    public var deleted: StoredScript?
    public var resume: PromptSession?

    public init(scripts: [StoredScript] = [], recordingIDs: [String] = [], deleted: StoredScript? = nil, resume: PromptSession? = nil) {
        self.scripts = scripts
        self.recordingIDs = recordingIDs
        self.deleted = deleted
        self.resume = resume
    }

    public func creating(title: String, content: String, tags: [String], at date: Date) -> ScriptLibrary {
        let id = UUID().uuidString
        let script = PortableScript(sourceID: id, title: title, content: content, tags: tags, createdAt: date, updatedAt: date)
        var copy = self
        copy.scripts.insert(StoredScript(id: id, script: script), at: 0)
        return copy
    }

    public func deleting(id: String) -> ScriptLibrary {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return self }
        var copy = self
        copy.deleted = scripts[index]
        copy.scripts.remove(at: index)
        if copy.resume?.scriptID == id { copy.resume = nil }
        return copy
    }

    public func undoingDelete() -> ScriptLibrary {
        guard let deleted else { return self }
        var copy = self
        if !copy.scripts.contains(where: { $0.id == deleted.id }) {
            copy.scripts.insert(deleted, at: 0)
        }
        copy.deleted = nil
        return copy
    }

    public func remembering(scriptID: String, progress: Double) -> ScriptLibrary {
        guard let index = scripts.firstIndex(where: { $0.id == scriptID }) else { return self }
        var copy = self
        let clamped = min(1, max(0, progress))
        copy.scripts[index].readingProgress = clamped
        copy.resume = PromptSession(scriptID: scriptID, progress: clamped)
        return copy
    }

    public func resumedScript() -> StoredScript? {
        guard let resume else { return nil }
        return scripts.first { $0.id == resume.scriptID }
    }

    public func choosing(_ choice: ImportChoice, document: BackupDocumentModel) -> ScriptLibrary {
        switch choice {
        case .cancelled:
            return self
        case .copy:
            var copy = self
            for incoming in document.scripts {
                copy.scripts.append(adopted(incoming, keepSourceID: false))
            }
            return copy
        case .merge:
            return integrating(document.scripts, droppingUnmatched: false)
        case .replace:
            return integrating(document.scripts, droppingUnmatched: true)
        }
    }

    private func integrating(_ incomingScripts: [PortableScript], droppingUnmatched: Bool) -> ScriptLibrary {
        var copy = self
        if droppingUnmatched { copy.deleted = nil }
        var next = droppingUnmatched ? [] : scripts
        var usedSources = Set<String>()
        var usedIDs = Set<String>()
        for incoming in incomingScripts {
            if let source = incoming.sourceID, !usedSources.contains(source),
               let existing = match(source, usedIDs: usedIDs) {
                usedSources.insert(source)
                usedIDs.insert(existing.id)
                let revised = revised(existing, with: incoming, source: source)
                if droppingUnmatched {
                    next.append(revised)
                } else if let index = next.firstIndex(where: { $0.id == existing.id }) {
                    next[index] = revised
                }
            } else {
                let keepSource = incoming.sourceID.map { !usedSources.contains($0) } ?? false
                let created = adopted(incoming, keepSourceID: keepSource)
                if keepSource, let source = incoming.sourceID { usedSources.insert(source) }
                usedIDs.insert(created.id)
                next.append(created)
            }
        }
        copy.scripts = next
        if let resume, !next.contains(where: { $0.id == resume.scriptID }) {
            copy.resume = nil
        }
        return copy
    }

    private func match(_ source: String, usedIDs: Set<String>) -> StoredScript? {
        scripts.first { stored in
            !usedIDs.contains(stored.id) && (stored.id == source || stored.script.sourceID == source)
        }
    }

    private func revised(_ existing: StoredScript, with incoming: PortableScript, source: String) -> StoredScript {
        var stored = existing
        var updated = incoming
        updated.sourceID = existing.script.sourceID ?? source
        stored.script = updated
        stored.readingProgress = existing.readingProgress
        stored.pinned = existing.pinned
        return stored
    }

    private func adopted(_ incoming: PortableScript, keepSourceID: Bool) -> StoredScript {
        let generated = UUID().uuidString
        var copy = incoming
        if keepSourceID, let sourceID = incoming.sourceID, !sourceID.isEmpty {
            copy.sourceID = sourceID
            if let uuid = UUID(uuidString: sourceID) {
                return StoredScript(id: uuid.uuidString, script: copy)
            }
            return StoredScript(id: generated, script: copy)
        }
        copy.sourceID = generated
        return StoredScript(id: generated, script: copy)
    }
}
