import XCTest
@testable import CuevoraLogic

final class ScriptJourneyTests: XCTestCase {
    func testRapidEditsSaveOnceAndAFailedSaveKeepsTheDraft() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var draft = ScriptDraft(title: "Hello", tagText: " one, , two ", content: "Hello", savedContent: "Hello")
        draft.content = "H"
        draft.change(at: start)
        draft.content = "He"
        draft.change(at: start.addingTimeInterval(0.2))
        draft.content = "שורה 🙂"
        draft.change(at: start.addingTimeInterval(0.4))

        XCTAssertFalse(draft.isReady(at: start.addingTimeInterval(0.9)))
        XCTAssertTrue(draft.isReady(at: start.addingTimeInterval(1.2)))
        XCTAssertEqual(draft.succeed(at: start.addingTimeInterval(1.2))?.content, "Hello")
        XCTAssertEqual(draft.savedContent, "שורה 🙂")
        XCTAssertEqual(draft.revisions.map(\.content), ["Hello"])
        XCTAssertEqual(ScriptDraft.tags(in: draft.tagText), ["one", "two"])

        draft.content = "still typing"
        draft.change(at: start.addingTimeInterval(2))
        draft.fail()
        XCTAssertEqual(draft.status, .notSaved)
        XCTAssertEqual(draft.content, "still typing")
        XCTAssertEqual(draft.savedContent, "שורה 🙂")

        draft.succeed(at: start.addingTimeInterval(3))
        XCTAssertEqual(draft.status, .saved)
        XCTAssertEqual(draft.savedContent, "still typing")
        XCTAssertEqual(draft.revisions.first?.content, "שורה 🙂")
    }

    func testEmptyTextAndTwelveEditsKeepTheNewestTenRevisions() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var draft = ScriptDraft(title: " ", tagText: "", content: "", savedContent: "")
        XCTAssertNil(draft.succeed(at: start))
        XCTAssertEqual(draft.savedContent, "")
        XCTAssertTrue(draft.revisions.isEmpty)

        draft.content = "0"
        draft.savedContent = "0"
        for step in 1...12 {
            draft.content = "\(step)"
            draft.succeed(at: start.addingTimeInterval(Double(step)))
        }
        XCTAssertEqual(draft.revisions.count, 10)
        XCTAssertEqual(draft.revisions.first?.content, "11")
        XCTAssertFalse(draft.revisions.contains { $0.content == "0" })
        XCTAssertEqual(draft.savedContent, "12")
    }

    func testDeleteUndoResumeAndRejectedImportLeaveTheLibraryUntouched() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let kept = "22222222-2222-2222-2222-222222222222"
        var library = ScriptLibrary(recordingIDs: ["take.mov"])
            .creating(title: "Launch", content: "Hello", tags: ["video"], at: start)
        let createdID = try XCTUnwrap(library.scripts.first?.id)
        library = library.remembering(scriptID: createdID, progress: 1.4)
        library.scripts.append(StoredScript(
            id: kept,
            script: PortableScript(sourceID: kept, title: "Local", content: "Keep me", tags: [], createdAt: start, updatedAt: start),
            readingProgress: 0.2,
            pinned: true
        ))

        let resumed = library.resumedScript()
        XCTAssertEqual(resumed?.id, createdID)
        XCTAssertEqual(resumed?.readingProgress, 1)

        let removed = library.deleting(id: createdID)
        XCTAssertNil(removed.resumedScript())
        XCTAssertEqual(removed.recordingIDs, ["take.mov"])
        let restored = removed.undoingDelete()
        XCTAssertEqual(restored.scripts.first { $0.id == createdID }?.script.content, "Hello")
        XCTAssertEqual(restored.scripts.first { $0.id == createdID }?.readingProgress, 1)
        XCTAssertEqual(restored.recordingIDs, ["take.mov"])

        let beforeRejection = restored
        XCTAssertThrowsError(try BackupCodec.decode(Data("[]".utf8)))
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"version":9,"scripts":[]}"#.utf8)))
        XCTAssertThrowsError(try BackupCodec.decode(Data(count: BackupCodec.maxBytes + 1)))
        XCTAssertEqual(beforeRejection, restored)
    }

    func testMergeReplaceCopyAndCancelKeepRecordings() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let localID = "11111111-1111-1111-1111-111111111111"
        let otherID = "22222222-2222-2222-2222-222222222222"
        let local = StoredScript(
            id: localID,
            script: PortableScript(sourceID: localID, title: "Old", content: "On device", tags: ["local"], createdAt: start, updatedAt: start),
            readingProgress: 0.4,
            pinned: true
        )
        let other = StoredScript(
            id: otherID,
            script: PortableScript(sourceID: otherID, title: "Notes", content: "Stay", tags: [], createdAt: start, updatedAt: start)
        )
        let library = ScriptLibrary(scripts: [local, other], recordingIDs: ["take.mov"], resume: PromptSession(scriptID: otherID, progress: 0.2))
        let document = BackupDocumentModel(
            source: .iosVersion2,
            scripts: [
                PortableScript(sourceID: localID, title: "Old", content: "From backup", tags: ["local"], createdAt: start, updatedAt: start.addingTimeInterval(5)),
                PortableScript(sourceID: "android-script-1", title: "Launch", content: "Hello café 🎬", tags: [], createdAt: start, updatedAt: start),
                PortableScript(sourceID: "android-script-1", title: "Duplicate id", content: "Second copy", tags: [], createdAt: start, updatedAt: start)
            ],
            settings: nil,
            rehearsals: [],
            notices: []
        )

        XCTAssertEqual(library.choosing(.cancelled, document: document), library)

        let merged = library.choosing(.merge, document: document)
        XCTAssertEqual(merged.recordingIDs, ["take.mov"])
        XCTAssertEqual(merged.scripts.first { $0.id == localID }?.script.content, "From backup")
        XCTAssertEqual(merged.scripts.first { $0.id == localID }?.readingProgress, 0.4)
        XCTAssertEqual(merged.scripts.first { $0.id == localID }?.pinned, true)
        XCTAssertEqual(merged.scripts.first { $0.id == otherID }?.script.content, "Stay")
        XCTAssertEqual(merged.resume?.scriptID, otherID)
        let android = try XCTUnwrap(merged.scripts.first { $0.script.sourceID == "android-script-1" })
        XCTAssertEqual(android.script.content, "Hello café 🎬")
        let duplicate = try XCTUnwrap(merged.scripts.first { $0.script.content == "Second copy" })
        XCTAssertNotEqual(duplicate.script.sourceID, "android-script-1")
        XCTAssertEqual(merged.scripts.count, 4)

        let replaced = library.choosing(.replace, document: document)
        XCTAssertEqual(replaced.recordingIDs, ["take.mov"])
        XCTAssertNil(replaced.scripts.first { $0.id == otherID })
        XCTAssertNil(replaced.resume)
        XCTAssertEqual(replaced.scripts.first { $0.id == localID }?.readingProgress, 0.4)
        XCTAssertEqual(replaced.scripts.count, 3)

        let copied = library.choosing(.copy, document: document)
        XCTAssertEqual(copied.scripts.first { $0.id == localID }?.script.content, "On device")
        XCTAssertEqual(copied.scripts.first { $0.id == otherID }?.script.content, "Stay")
        XCTAssertEqual(copied.scripts.count, 5)
        XCTAssertEqual(copied.recordingIDs, ["take.mov"])
        XCTAssertTrue(copied.scripts.filter { $0.id != localID && $0.id != otherID }.allSatisfy { $0.script.sourceID == $0.id })
    }
}
