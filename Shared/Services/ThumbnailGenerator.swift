import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ThumbnailGenerator {

    enum ThumbnailError: Error {
        case failedToCreateImageSource
        case failedToCreateThumbnail
        case failedToCreateDestination
        case failedToFinalize
    }

    static func generateThumbnail(from sourceURL: URL, to destinationURL: URL, maxPixelSize: Int) throws {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ThumbnailError.failedToCreateImageSource
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        // Extract only the first frame
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ThumbnailError.failedToCreateThumbnail
        }

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw ThumbnailError.failedToCreateDestination
        }

        let jpegOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ]

        CGImageDestinationAddImage(destination, thumbnail, jpegOptions as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailError.failedToFinalize
        }
    }
}
