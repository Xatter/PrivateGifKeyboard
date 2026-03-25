import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class GifFrameExtractorTests: XCTestCase {

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

    // MARK: - Frame Count

    func testFrameCountReturnsCorrectCount() {
        let url = makeGif(frameCount: 5, delay: 0.1)
        XCTAssertEqual(GifFrameExtractor.frameCount(from: url), 5)
    }

    func testFrameCountReturnsSingleForOneFrame() {
        let url = makeGif(frameCount: 1, delay: 0.1)
        XCTAssertEqual(GifFrameExtractor.frameCount(from: url), 1)
    }

    func testFrameCountReturnsNilForInvalidURL() {
        let url = tempDir.appendingPathComponent("nonexistent.gif")
        XCTAssertNil(GifFrameExtractor.frameCount(from: url))
    }

    // MARK: - Frame Delays

    func testFrameDelaysReturnsCorrectDelays() {
        let url = makeGif(frameCount: 3, delay: 0.15)

        let delays = GifFrameExtractor.frameDelays(from: url)
        XCTAssertEqual(delays?.count, 3)
        for delay in delays ?? [] {
            XCTAssertEqual(delay, 0.15, accuracy: 0.001)
        }
    }

    func testZeroDelayIsClampedTo100ms() {
        let url = makeGif(frameCount: 2, delay: 0.0)

        let delays = GifFrameExtractor.frameDelays(from: url)
        XCTAssertEqual(delays?.count, 2)
        for delay in delays ?? [] {
            XCTAssertEqual(delay, 0.1, accuracy: 0.001)
        }
    }

    func testDelayAt10msIsClampedTo100ms() {
        let url = makeGif(frameCount: 2, delay: 0.01)

        let delays = GifFrameExtractor.frameDelays(from: url)
        for delay in delays ?? [] {
            XCTAssertEqual(delay, 0.1, accuracy: 0.001)
        }
    }

    func testDelayAt20msIsNotClamped() {
        let url = makeGif(frameCount: 2, delay: 0.02)

        let delays = GifFrameExtractor.frameDelays(from: url)
        for delay in delays ?? [] {
            XCTAssertEqual(delay, 0.02, accuracy: 0.001)
        }
    }

    func testFrameDelaysReturnsNilForInvalidURL() {
        let url = tempDir.appendingPathComponent("nonexistent.gif")
        XCTAssertNil(GifFrameExtractor.frameDelays(from: url))
    }

    // MARK: - Total Duration

    func testTotalDurationSumsAllFrameDelays() {
        let url = makeGif(frameCount: 4, delay: 0.25)

        let duration = GifFrameExtractor.totalDuration(from: url)
        XCTAssertEqual(duration ?? 0, 1.0, accuracy: 0.01)
    }

    func testTotalDurationReturnsNilForInvalidURL() {
        let url = tempDir.appendingPathComponent("nonexistent.gif")
        XCTAssertNil(GifFrameExtractor.totalDuration(from: url))
    }

    // MARK: - Helpers

    private func makeGif(frameCount: Int, delay: Double) -> URL {
        let url = tempDir.appendingPathComponent(UUID().uuidString + ".gif")

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else {
            XCTFail("Failed to create GIF destination")
            return url
        }

        let gifProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: delay,
            kCGImagePropertyGIFUnclampedDelayTime: delay
        ]] as CFDictionary

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        for i in 0..<frameCount {
            guard let context = CGContext(
                data: nil, width: 10, height: 10, bitsPerComponent: 8,
                bytesPerRow: 40, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            let gray = CGFloat(i) / CGFloat(max(1, frameCount))
            context.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1.0))
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))

            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }

        CGImageDestinationFinalize(destination)
        return url
    }
}
