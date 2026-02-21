import Foundation

struct GifEntry: Codable, Identifiable, Equatable {
    var id: String { filename }
    let filename: String
    let tags: [String]
    let thumbnailPath: String
    let gifPath: String
    let fileSize: Int64
    let dateAdded: Date
}
