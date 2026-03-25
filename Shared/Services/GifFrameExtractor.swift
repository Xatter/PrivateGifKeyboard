import Foundation
import ImageIO

enum GifFrameExtractor {

    /// Read frame delays from a GIF file without decoding pixel data.
    /// Returns nil if the URL can't be read as an image source.
    static func frameDelays(from url: URL) -> [Double]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return frameDelays(from: source)
    }

    /// Read frame delays from an existing CGImageSource.
    static func frameDelays(from source: CGImageSource) -> [Double] {
        let count = CGImageSourceGetCount(source)
        return (0..<count).map { frameDelay(at: $0, source: source) }
    }

    /// Read the delay for a single frame.
    /// Returns 0.1 if properties are missing. Clamps delays < 11ms to 100ms.
    static func frameDelay(at index: Int, source: CGImageSource) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifDict = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let delay = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                  ?? gifDict[kCGImagePropertyGIFDelayTime] as? Double
                  ?? 0.1
        // Very small delays (< 11ms) are browser-era defaults meaning "as fast as possible".
        // Clamp to 100ms for reasonable playback.
        return delay < 0.011 ? 0.1 : delay
    }

    /// Number of frames in the GIF. Returns nil if the URL can't be read.
    static func frameCount(from url: URL) -> Int? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceGetCount(source)
    }

    /// Total duration of all frames combined. Returns nil if the URL can't be read.
    static func totalDuration(from url: URL) -> Double? {
        guard let delays = frameDelays(from: url) else { return nil }
        return delays.reduce(0, +)
    }
}
