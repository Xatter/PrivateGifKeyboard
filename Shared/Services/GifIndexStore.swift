import Foundation

final class GifIndexStore {

    private let indexURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(containerURL: URL) {
        self.indexURL = containerURL.appendingPathComponent("index.json")

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ entries: [GifEntry]) throws {
        let data = try encoder.encode(entries)
        try data.write(to: indexURL, options: .atomic)
    }

    func load() throws -> [GifEntry] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        let data = try Data(contentsOf: indexURL)
        return try decoder.decode([GifEntry].self, from: data)
    }
}
