import UIKit
import UniformTypeIdentifiers

enum GifPasteboardService {

    enum PasteboardError: Error {
        case fileNotFound
        case failedToReadData
    }

    static func copyGifToPasteboard(from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PasteboardError.fileNotFound
        }

        let data = try Data(contentsOf: url)

        // CRITICAL: Set raw GIF data directly with the GIF UTI type.
        // Do NOT use UIImage — it strips animation frames and re-encodes as PNG.
        UIPasteboard.general.setData(data, forPasteboardType: UTType.gif.identifier)
    }
}
