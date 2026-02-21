import SwiftUI

struct SetupView: View {
    let onFolderSelected: (URL) -> Void
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("GifKeyboard")
                .font(.largeTitle.bold())

            Text("Choose the folder where you keep your GIFs. The app will sync from there automatically.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showingPicker = true
            } label: {
                Label("Choose GIF Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                step(number: 1, text: "Go to Settings > General > Keyboard > Keyboards > Add New Keyboard")
                step(number: 2, text: "Add \"GifKeyboard\" from the list")
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .sheet(isPresented: $showingPicker) {
            FolderPickerView(onFolderSelected: { url in
                showingPicker = false
                onFolderSelected(url)
            })
        }
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
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
