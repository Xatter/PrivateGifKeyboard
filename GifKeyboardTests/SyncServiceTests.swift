import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class SyncServiceTests: XCTestCase {

    var sourceDir: URL!
    var containerDir: URL!
    var syncService: SyncService!

    override func setUp() {
        super.setUp()
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        sourceDir = base.appendingPathComponent("icloud")
        containerDir = base.appendingPathComponent("container")

        try! FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(
            at: containerDir.appendingPathComponent("gifs"), withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(
            at: containerDir.appendingPathComponent("thumbnails"), withIntermediateDirectories: true)

        syncService = SyncService(
            sourceDirectory: sourceDir,
            containerDirectory: containerDir
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: sourceDir.deletingLastPathComponent())
        super.tearDown()
    }

    func testSyncAddsNewGifs() throws {
        createTestGif(at: sourceDir.appendingPathComponent("hello.gif"))

        let result = try syncService.sync()

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.removed, 0)

        let store = GifIndexStore(containerURL: containerDir)
        let entries = try store.load()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].filename, "hello.gif")

        // Verify files were copied
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("gifs/hello.gif").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("thumbnails/hello.jpg").path))
    }

    func testSyncSkipsExistingGifs() throws {
        createTestGif(at: sourceDir.appendingPathComponent("hello.gif"))
        _ = try syncService.sync()

        let result = try syncService.sync()
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.removed, 0)
    }

    func testSyncRemovesDeletedGifs() throws {
        createTestGif(at: sourceDir.appendingPathComponent("hello.gif"))
        _ = try syncService.sync()

        try FileManager.default.removeItem(at: sourceDir.appendingPathComponent("hello.gif"))

        let result = try syncService.sync()
        XCTAssertEqual(result.removed, 1)

        let store = GifIndexStore(containerURL: containerDir)
        let entries = try store.load()
        XCTAssertEqual(entries.count, 0)

        // Verify files were cleaned up
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("gifs/hello.gif").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("thumbnails/hello.jpg").path))
    }

    func testSyncIgnoresNonGifFiles() throws {
        try "not a gif".data(using: .utf8)!
            .write(to: sourceDir.appendingPathComponent("readme.txt"))
        createTestGif(at: sourceDir.appendingPathComponent("real.gif"))

        let result = try syncService.sync()
        XCTAssertEqual(result.added, 1)

        let store = GifIndexStore(containerURL: containerDir)
        let entries = try store.load()
        XCTAssertEqual(entries[0].filename, "real.gif")
    }


    func testSyncStoresFileSizeMatchingContainerFile() throws {
        createTestGif(at: sourceDir.appendingPathComponent("test.gif"))

        _ = try syncService.sync()

        let store = GifIndexStore(containerURL: containerDir)
        let entries = try store.load()
        XCTAssertEqual(entries.count, 1)

        let containerGifURL = containerDir.appendingPathComponent("gifs/test.gif")
        let attrs = try FileManager.default.attributesOfItem(atPath: containerGifURL.path)
        let actualSize = attrs[.size] as? Int64 ?? 0
        XCTAssertEqual(entries[0].fileSize, actualSize)
    }

    // MARK: - Helpers

    private func createTestGif(at url: URL, frameCount: Int = 2) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return }

        let gifProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 0.1
        ]] as CFDictionary

        for i in 0..<frameCount {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil, width: 50, height: 50, bitsPerComponent: 8,
                bytesPerRow: 200, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            let v = CGFloat(i) / CGFloat(max(frameCount - 1, 1))
            context.setFillColor(CGColor(red: v, green: v, blue: v, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }
        CGImageDestinationFinalize(destination)
    }
}
