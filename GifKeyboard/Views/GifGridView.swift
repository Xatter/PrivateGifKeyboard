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
                    let gifURL = containerURL.appendingPathComponent(entry.gifPath)
                    AnimatedGifView(url: gifURL)
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }
}
