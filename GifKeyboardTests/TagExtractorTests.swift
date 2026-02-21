import XCTest
@testable import GifKeyboard

final class TagExtractorTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testExtractTagsFromExtendedAttribute() throws {
        let fileURL = tempDir.appendingPathComponent("test.gif")
        try Data([0x47, 0x49, 0x46]).write(to: fileURL)

        let tags = ["reaction", "funny"]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: tags, format: .binary, options: 0
        )
        let result = fileURL.withUnsafeFileSystemRepresentation { path in
            plistData.withUnsafeBytes { bytes in
                setxattr(path, "com.apple.metadata:_kMDItemUserTags", bytes.baseAddress, bytes.count, 0, 0)
            }
        }
        XCTAssertEqual(result, 0, "setxattr should succeed")

        let extracted = TagExtractor.extractTags(from: fileURL)
        XCTAssertEqual(Set(extracted), Set(["reaction", "funny"]))
    }

    func testExtractTagsReturnsEmptyForUntaggedFile() throws {
        let fileURL = tempDir.appendingPathComponent("untagged.gif")
        try Data([0x47, 0x49, 0x46]).write(to: fileURL)

        let extracted = TagExtractor.extractTags(from: fileURL)
        XCTAssertEqual(extracted, [])
    }

    func testExtractTagsStripsFinderColorSuffix() throws {
        let fileURL = tempDir.appendingPathComponent("colored.gif")
        try Data([0x47, 0x49, 0x46]).write(to: fileURL)

        let tags = ["reaction\n2", "funny\n0"]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: tags, format: .binary, options: 0
        )
        fileURL.withUnsafeFileSystemRepresentation { path in
            plistData.withUnsafeBytes { bytes in
                _ = setxattr(path, "com.apple.metadata:_kMDItemUserTags", bytes.baseAddress, bytes.count, 0, 0)
            }
        }

        let extracted = TagExtractor.extractTags(from: fileURL)
        XCTAssertEqual(Set(extracted), Set(["reaction", "funny"]))
    }
}
