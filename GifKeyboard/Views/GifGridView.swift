import SwiftUI

struct GifGridView: View {
    let entries: [GifEntry]
    let containerURL: URL

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(entries) { entry in
                    let thumbURL = containerURL.appendingPathComponent(entry.thumbnailPath)
                    AsyncImage(url: thumbURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(minHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }
}
