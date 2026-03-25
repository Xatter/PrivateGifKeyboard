import SwiftUI

struct AnimatedGifView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> AnimatedGifImageView {
        let view = AnimatedGifImageView()
        view.contentMode = .scaleAspectFill
        return view
    }

    func updateUIView(_ uiView: AnimatedGifImageView, context: Context) {
        uiView.loadGif(from: url)
    }

    static func dismantleUIView(_ uiView: AnimatedGifImageView, coordinator: ()) {
        uiView.reset()
    }
}
