import XCTest
@testable import GifKeyboard

final class GifSearchServiceTests: XCTestCase {

    let entries = [
        GifEntry(filename: "mind-blown.gif", tags: ["reaction", "funny"],
                 thumbnailPath: "", gifPath: "", fileSize: 100, dateAdded: Date()),
        GifEntry(filename: "thumbs-up.gif", tags: ["reaction", "approval"],
                 thumbnailPath: "", gifPath: "", fileSize: 200, dateAdded: Date()),
        GifEntry(filename: "cat-typing.gif", tags: ["animal", "funny"],
                 thumbnailPath: "", gifPath: "", fileSize: 300, dateAdded: Date()),
        GifEntry(filename: "deal-with-it.gif", tags: [],
                 thumbnailPath: "", gifPath: "", fileSize: 400, dateAdded: Date()),
    ]

    func testEmptyQueryReturnsAll() {
        let results = GifSearchService.filter(entries: entries, query: "")
        XCTAssertEqual(results.count, 4)
    }

    func testFilterByFilename() {
        let results = GifSearchService.filter(entries: entries, query: "cat")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].filename, "cat-typing.gif")
    }

    func testFilterByTag() {
        let results = GifSearchService.filter(entries: entries, query: "funny")
        XCTAssertEqual(results.count, 2)
    }

    func testFilterIsCaseInsensitive() {
        let results = GifSearchService.filter(entries: entries, query: "MIND")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].filename, "mind-blown.gif")
    }

    func testFilterByPartialTag() {
        let results = GifSearchService.filter(entries: entries, query: "react")
        XCTAssertEqual(results.count, 2)
    }

    func testFilterNoMatch() {
        let results = GifSearchService.filter(entries: entries, query: "zzzzz")
        XCTAssertEqual(results.count, 0)
    }

    func testFilterMatchesFilenameWithoutExtension() {
        let results = GifSearchService.filter(entries: entries, query: "deal")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].filename, "deal-with-it.gif")
    }
}
