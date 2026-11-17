import XCTest
@testable import CuevoraLogic

final class PersistenceTests: XCTestCase {
    func testRevisionHistoryIsCappedAtTenNewestSnapshots() throws {
        let revisions = (0..<12).map {
            PortableRevision(content: "revision \($0)", timestamp: Date(timeIntervalSince1970: Double($0 + 1_700_000_000)))
        }
        let script = PortableScript(title: "History", content: "current", tags: ["one", "two"], createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_020), revisions: revisions)
        let decoded = try BackupCodec.decode(try BackupCodec.encode(scripts: [script], settings: PortableSettings(), rehearsals: []))
        XCTAssertEqual(decoded.scripts[0].revisions.count, 10)
        XCTAssertEqual(decoded.scripts[0].revisions.first?.content, "revision 11")
        XCTAssertFalse(decoded.scripts[0].revisions.contains { $0.content == "revision 0" })
    }

    func testUnicodeEmptyAndWhitespaceScriptsStayIntact() throws {
        let scripts = [
            PortableScript(title: "  ", content: "", tags: [" ", "tag"], createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            PortableScript(title: "עברית", content: "שורה\n🙂", tags: [], createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        ]
        let decoded = try BackupCodec.decode(try BackupCodec.encode(scripts: scripts, settings: PortableSettings(), rehearsals: []))
        XCTAssertEqual(decoded.scripts[0].title, "Untitled Script")
        XCTAssertEqual(decoded.scripts[0].content, "")
        XCTAssertEqual(decoded.scripts[0].tags, ["tag"])
        XCTAssertEqual(decoded.scripts[1].content, "שורה\n🙂")
    }
}
