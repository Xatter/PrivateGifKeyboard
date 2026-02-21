import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class GifPasteboardServiceTests: XCTestCase {

    var tempDir: URL!
    var testGifURL: URL!
    var testGifData: Data!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testGifURL = tempDir.appendingPathComponent("animated.gif")
        createTestGif(at: testGifURL, width: 100, height: 100, frameCount: 3)
        testGifData = try! Data(contentsOf: testGifURL)
    }

    override func tearDown() {
        UIPasteboard.general.items = []
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCopiesWithGifUTIType() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        XCTAssertTrue(
            pasteboard.contains(pasteboardTypes: [UTType.gif.identifier]),
            "Pasteboard should contain com.compuserve.gif type"
        )
    }

    func testPasteboardDataIsValidGif() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        guard let data = pasteboard.data(forPasteboardType: UTType.gif.identifier) else {
            XCTFail("No GIF data on pasteboard")
            return
        }

        // GIF magic bytes: GIF87a or GIF89a
        XCTAssertGreaterThanOrEqual(data.count, 6)
        XCTAssertEqual(data[0], 0x47) // G
        XCTAssertEqual(data[1], 0x49) // I
        XCTAssertEqual(data[2], 0x46) // F
        XCTAssertEqual(data[3], 0x38) // 8
        XCTAssertTrue(data[4] == 0x37 || data[4] == 0x39, "Version byte must be 7 or 9") // 7 or 9
        XCTAssertEqual(data[5], 0x61) // a
    }

    func testPasteboardDataContainsMultipleFrames() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        guard let data = pasteboard.data(forPasteboardType: UTType.gif.identifier) else {
            XCTFail("No GIF data on pasteboard")
            return
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            XCTFail("Could not create image source from pasteboard data")
            return
        }

        let frameCount = CGImageSourceGetCount(source)
        XCTAssertEqual(frameCount, 3, "Pasteboard GIF should preserve all 3 animation frames")
    }

    func testPasteboardDataIsByteIdenticalToSource() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        guard let data = pasteboard.data(forPasteboardType: UTType.gif.identifier) else {
            XCTFail("No GIF data on pasteboard")
            return
        }

        XCTAssertEqual(
            data, testGifData,
            "Pasteboard data must be byte-identical to source — no re-encoding allowed"
        )
    }

    func testDoesNotSetPNGType() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        let hasGIF = pasteboard.contains(pasteboardTypes: [UTType.gif.identifier])
        XCTAssertTrue(hasGIF, "Must have GIF type on pasteboard")
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

            let gray = CGFloat(i) / CGFloat(max(frameCount - 1, 1))
            context.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1.0))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }

        CGImageDestinationFinalize(destination)
    }
}
