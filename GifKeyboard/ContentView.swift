import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        if !viewModel.hasFolderSelected {
            SetupView { url in
                viewModel.selectFolder(url)
            }
        } else {
            NavigationStack {
                VStack(spacing: 0) {
                    if viewModel.entries.isEmpty {
                        ContentUnavailableView(
                            "No GIFs Yet",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Add GIF files to your chosen folder, then tap Sync.")
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
                    VStack(spacing: 4) {
                        if let status = viewModel.syncStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(status.hasPrefix("Error") || status.hasPrefix("Sync error") ? .red : .secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        if let lastSynced = viewModel.lastSynced {
                            Text("Last synced: \(lastSynced.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .task {
                await viewModel.syncNow()
            }
        }
    }
}
