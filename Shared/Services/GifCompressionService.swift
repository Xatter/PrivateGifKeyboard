import Foundation
import ImageIO
import UniformTypeIdentifiers

enum GifCompressionService {

    /// GIFs larger than this (bytes) will be compressed.
    static let defaultThreshold = 1_000_000  // 1 MB

    /// Target size in bytes after compression.
    static let defaultTarget = 800_000  // 800 KB

    /// Returns compressed GIF data, or nil if the input is already under `threshold`.
    /// Falls back to nil on any decode/encode failure (caller keeps the original).
    static func compress(
        data: Data,
        threshold: Int = defaultThreshold,
        target: Int = defaultTarget
    ) -> Data? {
        guard data.count > threshold else { return nil }

        // Never upscale — only downscale to reach the target size.
        let scale = min(1.0, sqrt(Double(target) / Double(data.count)))

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        guard let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let newWidth  = max(1, Int(floor(Double(firstFrame.width)  * scale)))
        let newHeight = max(1, Int(floor(Double(firstFrame.height) * scale)))

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return nil }

        // Preserve loop count
        if let sourceProps = CGImageSourceCopyProperties(source, nil) {
            CGImageDestinationSetProperties(destination, sourceProps)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        for i in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }

            // Preserve per-frame delay — read unclamped first, fall back to clamped
            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gifDict = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gifDict?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                     ?? gifDict?[kCGImagePropertyGIFDelayTime] as? Double
                     ?? 0.1

            guard let ctx = CGContext(
                data: nil, width: newWidth, height: newHeight,
                bitsPerComponent: 8, bytesPerRow: newWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            ctx.draw(frame, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

            guard let scaled = ctx.makeImage() else { continue }

            CGImageDestinationAddImage(destination, scaled, [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay
                ]
            ] as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputData as Data
    }
}
