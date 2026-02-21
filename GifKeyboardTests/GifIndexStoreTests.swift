import XCTest
@testable import GifKeyboard

final class GifIndexStoreTests: XCTestCase {

    var tempDir: URL!
    var store: GifIndexStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = GifIndexStore(containerURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let entries = [
            GifEntry(filename: "a.gif", tags: ["funny"], thumbnailPath: "thumbnails/a.jpg",
                     gifPath: "gifs/a.gif", fileSize: 100,
                     dateAdded: Date(timeIntervalSince1970: 1000000))
        ]

        try store.save(entries)
        let loaded = try store.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].filename, "a.gif")
        XCTAssertEqual(loaded[0].tags, ["funny"])
    }

    func testLoadReturnsEmptyWhenNoFile() throws {
        let loaded = try store.load()
        XCTAssertEqual(loaded, [])
    }

    func testOverwritesExistingFile() throws {
        let first = [
            GifEntry(filename: "a.gif", tags: [], thumbnailPath: "", gifPath: "",
                     fileSize: 100, dateAdded: Date())
        ]
        try store.save(first)

        let second = [
            GifEntry(filename: "b.gif", tags: ["new"], thumbnailPath: "", gifPath: "",
                     fileSize: 200, dateAdded: Date())
        ]
        try store.save(second)

        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].filename, "b.gif")
    }
}
