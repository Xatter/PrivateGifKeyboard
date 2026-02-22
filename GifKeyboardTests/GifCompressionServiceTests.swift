import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class GifCompressionServiceTests: XCTestCase {

    // MARK: - Threshold

    func testReturnsNilWhenBelowThreshold() {
        let data = makeGif(width: 10, height: 10, frameCount: 2)
        let result = GifCompressionService.compress(data: data, threshold: data.count + 1)
        XCTAssertNil(result)
    }

    func testReturnsDataWhenAboveThreshold() {
        let data = makeGif(width: 100, height: 100, frameCount: 3)
        let result = GifCompressionService.compress(data: data, threshold: 0)
        XCTAssertNotNil(result)
    }

    // MARK: - Output validity

    func testCompressedOutputIsValidGIF() {
        let data = makeGif(width: 100, height: 100, frameCount: 3)
        guard let result = GifCompressionService.compress(data: data, threshold: 0) else {
            return XCTFail("Expected non-nil result")
        }
        // GIF magic bytes: G I F
        XCTAssertEqual(result[0], 0x47)
        XCTAssertEqual(result[1], 0x49)
        XCTAssertEqual(result[2], 0x46)
    }

    func testFrameCountIsPreserved() {
        let data = makeGif(width: 100, height: 100, frameCount: 4)
        guard let result = GifCompressionService.compress(data: data, threshold: 0) else {
            return XCTFail("Expected non-nil result")
        }
        guard let source = CGImageSourceCreateWithData(result as CFData, nil) else {
            return XCTFail("Could not create image source from result")
        }
        XCTAssertEqual(CGImageSourceGetCount(source), 4)
    }

    func testDelayTimesArePreserved() {
        let delay = 0.15
        let data = makeGif(width: 100, height: 100, frameCount: 2, delayTime: delay)
        guard let result = GifCompressionService.compress(data: data, threshold: 0) else {
            return XCTFail("Expected non-nil result")
        }
        guard let source = CGImageSourceCreateWithData(result as CFData, nil) else {
            return XCTFail("Could not create image source from result")
        }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let gifDict = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let resultDelay = gifDict?[kCGImagePropertyGIFDelayTime] as? Double
        XCTAssertEqual(resultDelay ?? 0, delay, accuracy: 0.01)
    }

    func testCompressedDimensionsAreSmallerThanOriginal() {
        let data = makeGif(width: 100, height: 100, frameCount: 2)
        // target = 25% of original → scale ≈ 0.5 → dimensions ~50x50
        guard let result = GifCompressionService.compress(
            data: data, threshold: 0, target: data.count / 4
        ) else {
            return XCTFail("Expected non-nil result")
        }
        guard let source = CGImageSourceCreateWithData(result as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return XCTFail("Could not read compressed GIF")
        }
        XCTAssertLessThan(image.width, 100)
        XCTAssertLessThan(image.height, 100)
    }

    // MARK: - Helpers

    private func makeGif(width: Int, height: Int, frameCount: Int, delayTime: Double = 0.1) -> Data {
        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return Data() }

        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)

        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: delayTime
        ]] as CFDictionary

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        for i in 0..<frameCount {
            guard let ctx = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            let v = CGFloat(i) / CGFloat(max(frameCount - 1, 1))
            ctx.setFillColor(CGColor(red: v, green: 1 - v, blue: 0.5, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            if let img = ctx.makeImage() {
                CGImageDestinationAddImage(destination, img, frameProperties)
            }
        }
        CGImageDestinationFinalize(destination)
        return outputData as Data
    }
}
