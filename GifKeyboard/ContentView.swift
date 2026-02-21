import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        if !viewModel.hasCompletedSetup {
            SetupView {
                viewModel.completeSetup()
            }
        } else {
            NavigationStack {
                VStack(spacing: 0) {
                    if viewModel.entries.isEmpty {
                        ContentUnavailableView(
                            "No GIFs Yet",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Add GIF files to the GifKeyboard folder in iCloud Drive, then tap Sync.")
                        )
                    } else {
                        GifGridView(
                            entries: viewModel.entries,
                            containerURL: FileManager.default.containerURL(
                                forSecurityApplicationGroupIdentifier: "group.com.extroverteddeveloper.GifKeyboard.shared"
                            ) ?? FileManager.default.temporaryDirectory
                        )
                    }
                }
                .navigationTitle("GifKeyboard")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await viewModel.syncNow() }
                        } label: {
                            if viewModel.isSyncing {
                                ProgressView()
                            } else {
                                Label("Sync", systemImage: "arrow.trianglehead.2.clockwise")
                            }
                        }
                        .disabled(viewModel.isSyncing)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if let lastSynced = viewModel.lastSynced {
                        Text("Last synced: \(lastSynced.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                }
            }
            .task {
                await viewModel.syncNow()
            }
        }
    }
}
