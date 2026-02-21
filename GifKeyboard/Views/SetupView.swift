import SwiftUI

struct SetupView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("GifKeyboard")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 16) {
                step(number: 1, text: "Open Files app on your Mac or iPhone")
                step(number: 2, text: "In iCloud Drive, create a folder called \"GifKeyboard\"")
                step(number: 3, text: "Drop your GIF files into that folder")
                step(number: 4, text: "Go to Settings > General > Keyboard > Keyboards > Add New Keyboard and add GifKeyboard")
            }
            .padding()

            Spacer()

            Button("I've Done This \u{2014} Let's Go") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    private func step(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
            Text(text)
                .font(.body)
        }
    }
}
