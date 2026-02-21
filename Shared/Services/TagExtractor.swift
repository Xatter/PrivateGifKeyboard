import Foundation

enum TagExtractor {

    static func extractTags(from url: URL) -> [String] {
        #if os(macOS)
        // Try URLResourceKey.tagNamesKey first (macOS only)
        if let resourceValues = try? url.resourceValues(forKeys: [.tagNamesKey]),
           let tags = resourceValues.tagNames, !tags.isEmpty {
            return tags
        }
        #endif

        // Read the extended attribute directly (works on both macOS and iOS)
        return extractTagsViaXattr(from: url)
    }

    private static func extractTagsViaXattr(from url: URL) -> [String] {
        let attributeName = "com.apple.metadata:_kMDItemUserTags"

        let length = url.withUnsafeFileSystemRepresentation { path in
            getxattr(path, attributeName, nil, 0, 0, 0)
        }

        guard length > 0 else { return [] }

        var data = Data(count: length)
        let readLength = data.withUnsafeMutableBytes { bytes in
            url.withUnsafeFileSystemRepresentation { path in
                getxattr(path, attributeName, bytes.baseAddress, length, 0, 0)
            }
        }

        guard readLength == length else { return [] }

        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String] else {
            return []
        }

        // Finder stores tags as "tagname\ncolorIndex" — strip the color suffix
        return plist.map { tag in
            if let newlineIndex = tag.firstIndex(of: "\n") {
                return String(tag[tag.startIndex..<newlineIndex])
            }
            return tag
        }
    }
}
