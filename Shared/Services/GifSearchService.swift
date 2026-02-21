import Foundation

enum GifSearchService {

    static func filter(entries: [GifEntry], query: String) -> [GifEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }

        let lowered = trimmed.lowercased()
        return entries.filter { entry in
            if entry.filename.lowercased().contains(lowered) {
                return true
            }
            return entry.tags.contains { $0.lowercased().contains(lowered) }
        }
    }
}
