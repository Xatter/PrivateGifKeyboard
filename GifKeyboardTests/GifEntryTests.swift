import XCTest
@testable import GifKeyboard

final class GifEntryTests: XCTestCase {

    func testEncodeAndDecode() throws {
        let entry = GifEntry(
            filename: "mind-blown.gif",
            tags: ["reaction", "funny"],
            thumbnailPath: "thumbnails/mind-blown.jpg",
            gifPath: "gifs/mind-blown.gif",
            fileSize: 245760,
            dateAdded: Date(timeIntervalSince1970: 1000000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GifEntry.self, from: data)

        XCTAssertEqual(decoded.filename, "mind-blown.gif")
        XCTAssertEqual(decoded.tags, ["reaction", "funny"])
        XCTAssertEqual(decoded.thumbnailPath, "thumbnails/mind-blown.jpg")
        XCTAssertEqual(decoded.gifPath, "gifs/mind-blown.gif")
        XCTAssertEqual(decoded.fileSize, 245760)
        XCTAssertEqual(decoded.dateAdded, entry.dateAdded)
    }

    func testDecodeArray() throws {
        let json = """
        [
            {
                "filename": "a.gif",
                "tags": ["tag1"],
                "thumbnailPath": "thumbnails/a.jpg",
                "gifPath": "gifs/a.gif",
                "fileSize": 100,
                "dateAdded": "2026-02-20T12:00:00Z"
            },
            {
                "filename": "b.gif",
                "tags": [],
                "thumbnailPath": "thumbnails/b.jpg",
                "gifPath": "gifs/b.gif",
                "fileSize": 200,
                "dateAdded": "2026-02-19T12:00:00Z"
            }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([GifEntry].self, from: json)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].filename, "a.gif")
        XCTAssertEqual(entries[1].tags, [])
    }

    func testIdentity() {
        let entry = GifEntry(
            filename: "test.gif",
            tags: [],
            thumbnailPath: "thumbnails/test.jpg",
            gifPath: "gifs/test.gif",
            fileSize: 100,
            dateAdded: Date()
        )
        XCTAssertEqual(entry.id, "test.gif")
    }
}
