import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class ThumbnailGeneratorTests: XCTestCase {

    var tempDir: URL!
    var testGifURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testGifURL = tempDir.appendingPathComponent("test.gif")
        createTestGif(at: testGifURL, width: 200, height: 200, frameCount: 2)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testGeneratesThumbnailAsJPEG() throws {
        let outputURL = tempDir.appendingPathComponent("thumb.jpg")
        try ThumbnailGenerator.generateThumbnail(
            from: testGifURL, to: outputURL, maxPixelSize: 150
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let data = try Data(contentsOf: outputURL)
        // JPEG starts with FF D8
        XCTAssertEqual(data[0], 0xFF)
        XCTAssertEqual(data[1], 0xD8)
    }

    func testThumbnailIsScaledDown() throws {
        let outputURL = tempDir.appendingPathComponent("thumb.jpg")
        try ThumbnailGenerator.generateThumbnail(
            from: testGifURL, to: outputURL, maxPixelSize: 150
        )

        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            XCTFail("Could not read thumbnail")
            return
        }

        XCTAssertLessThanOrEqual(image.width, 150)
        XCTAssertLessThanOrEqual(image.height, 150)
    }

    func testThumbnailFromFirstFrameOnly() throws {
        let outputURL = tempDir.appendingPathComponent("thumb.jpg")
        try ThumbnailGenerator.generateThumbnail(
            from: testGifURL, to: outputURL, maxPixelSize: 150
        )

        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil) else {
            XCTFail("Could not read thumbnail")
            return
        }

        XCTAssertEqual(CGImageSourceGetCount(source), 1, "Thumbnail should have exactly 1 frame")
    }

    // MARK: - Helpers

    private func createTestGif(at url: URL, width: Int, height: Int, frameCount: Int) {
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
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            let gray = CGFloat(i) / CGFloat(frameCount)
            context.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1.0))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }

        CGImageDestinationFinalize(destination)
    }
}
