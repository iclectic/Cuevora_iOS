import XCTest
@testable import CuevoraLogic

final class BackupTests: XCTestCase {
    func testAndroidFixturePreservesContentAndReportsLosses() throws {
        let data = try fixture("android-backup-v1")
        let document = try BackupCodec.decode(data)
        XCTAssertEqual(document.source, .androidVersion1)
        XCTAssertEqual(document.scripts.count, 2)
        XCTAssertEqual(document.scripts[0].content, "Hello café 🎬\nSecond line\nThird line")
        XCTAssertEqual(document.scripts[0].markers, [0, 2])
        XCTAssertEqual(document.scripts[0].highlights, [1])
        XCTAssertEqual(document.scripts[0].tags, ["video"])
        XCTAssertEqual(document.scripts[0].revisions.map(\.content), ["Hello"])
        XCTAssertEqual(document.scripts[1].title, "Duplicate id")
        XCTAssertEqual(document.settings?.defaultTheme, "studio")
        XCTAssertEqual(document.settings?.countdownDuration, 5)
        XCTAssertEqual(document.settings?.accessibilityProfile, "calm-focus")
        XCTAssertTrue(document.notices.contains { $0.contains("Duplicate script id") })
        XCTAssertTrue(document.notices.contains { $0.contains("analytics") })
        XCTAssertTrue(document.notices.contains { $0.contains("futureSetting") })
        XCTAssertTrue(document.notices.contains { $0.contains("unknownField") })
        XCTAssertTrue(document.notices.contains { $0.contains("did not match") })
        XCTAssertTrue(document.notices.contains { $0.contains("Recordings") || $0.contains("recordings") })
    }

    func testIOSBackupRoundTrip() throws {
        let script = PortableScript(
            sourceID: "ios-1",
            title: "Notes",
            content: "مرحبا\nLine",
            tags: ["draft"],
            markers: [1],
            highlights: [0],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            revisions: [PortableRevision(content: "old", timestamp: Date(timeIntervalSince1970: 1_699_000_000))]
        )
        let settings = PortableSettings(defaultTheme: "light", wordsPerMinute: 160)
        let data = try BackupCodec.encode(scripts: [script], settings: settings, rehearsals: [])
        let document = try BackupCodec.decode(data)
        XCTAssertEqual(document.source, .iosVersion2)
        XCTAssertEqual(document.scripts, [script])
        XCTAssertEqual(document.settings?.defaultTheme, "light")
        XCTAssertEqual(document.settings?.wordsPerMinute, 160)
        XCTAssertTrue(document.notices.contains { $0.contains("Recordings") })
    }

    func testLegacyIOSBackup() throws {
        let json = """
        {"version":1,"scripts":[{"title":"","content":"Kept","tags":["a"],"revisions":["previous"],"updatedAt":750000000}]}
        """.data(using: .utf8)!
        let document = try BackupCodec.decode(json)
        XCTAssertEqual(document.source, .iosVersion1)
        XCTAssertEqual(document.scripts[0].title, "Untitled Script")
        XCTAssertEqual(document.scripts[0].revisions.map(\.content), ["previous"])
        XCTAssertEqual(document.scripts[0].updatedAt, Date(timeIntervalSinceReferenceDate: 750_000_000))
    }

    func testRejectedFilesDoNotProduceADocument() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("[]".utf8))) { error in
            XCTAssertEqual(error as? BackupCodecError, .malformed)
        }
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"version":9,"scripts":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? BackupCodecError, .unsupportedVersion)
        }
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"format":"cuevora-ios","version":1,"scripts":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? BackupCodecError, .unsupportedVersion)
        }
        XCTAssertThrowsError(try BackupCodec.decode(Data(count: BackupCodec.maxBytes + 1))) { error in
            XCTAssertEqual(error as? BackupCodecError, .tooLarge)
        }
    }

    func testEmptyAndLongText() throws {
        let empty = try BackupCodec.decode(Data(#"{"version":1,"scripts":[{"title":"Empty","content":"","tags":[],"revisions":[],"updatedAt":1}]}"#.utf8))
        XCTAssertEqual(empty.scripts[0].content, "")
        var long = PortableScript(title: "Long", content: String(repeating: "a", count: BackupCodec.maxContentLength + 1), tags: [], createdAt: Date(), updatedAt: Date())
        XCTAssertThrowsError(try BackupCodec.encode(scripts: [long], settings: PortableSettings(), rehearsals: []))
        long.content = String(repeating: "b", count: 100)
        XCTAssertEqual(try BackupCodec.decode(try BackupCodec.encode(scripts: [long], settings: PortableSettings(), rehearsals: [])).scripts[0].content, long.content)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
