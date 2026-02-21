import Foundation

final class SyncService {

    struct SyncResult {
        let added: Int
        let removed: Int
    }

    private let sourceDirectory: URL
    private let containerDirectory: URL
    private let indexStore: GifIndexStore
    private let fileManager = FileManager.default

    init(sourceDirectory: URL, containerDirectory: URL) {
        self.sourceDirectory = sourceDirectory
        self.containerDirectory = containerDirectory
        self.indexStore = GifIndexStore(containerURL: containerDirectory)
    }

    func sync() throws -> SyncResult {
        var existing = try indexStore.load()
        let existingFilenames = Set(existing.map(\.filename))

        // Enumerate source directory for .gif files
        var resourceKeys: [URLResourceKey] = [.fileSizeKey]
        #if os(macOS)
        resourceKeys.append(.tagNamesKey)
        #endif
        let sourceFiles = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "gif" }

        let sourceFilenames = Set(sourceFiles.map(\.lastPathComponent))

        // Add new GIFs
        var addedCount = 0
        for fileURL in sourceFiles {
            let filename = fileURL.lastPathComponent
            guard !existingFilenames.contains(filename) else { continue }

            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resourceValues.fileSize ?? 0)

            // Extract tags
            let tags = TagExtractor.extractTags(from: fileURL)

            // Copy GIF to container
            let destGifURL = containerDirectory
                .appendingPathComponent("gifs")
                .appendingPathComponent(filename)
            try fileManager.copyItem(at: fileURL, to: destGifURL)

            // Generate thumbnail
            let thumbFilename = filename.replacingOccurrences(
                of: ".gif", with: ".jpg", options: .caseInsensitive)
            let destThumbURL = containerDirectory
                .appendingPathComponent("thumbnails")
                .appendingPathComponent(thumbFilename)
            try ThumbnailGenerator.generateThumbnail(
                from: fileURL, to: destThumbURL, maxPixelSize: 150)

            let entry = GifEntry(
                filename: filename,
                tags: tags,
                thumbnailPath: "thumbnails/\(thumbFilename)",
                gifPath: "gifs/\(filename)",
                fileSize: fileSize,
                dateAdded: Date()
            )
            existing.append(entry)
            addedCount += 1
        }

        // Remove deleted GIFs
        var removedCount = 0
        existing.removeAll { entry in
            if !sourceFilenames.contains(entry.filename) {
                let gifURL = containerDirectory.appendingPathComponent(entry.gifPath)
                let thumbURL = containerDirectory.appendingPathComponent(entry.thumbnailPath)
                try? fileManager.removeItem(at: gifURL)
                try? fileManager.removeItem(at: thumbURL)
                removedCount += 1
                return true
            }
            return false
        }

        try indexStore.save(existing)

        return SyncResult(added: addedCount, removed: removedCount)
    }
}
