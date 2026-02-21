import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {

    @Published var entries: [GifEntry] = []
    @Published var lastSynced: Date?
    @Published var isSyncing = false
    @Published var syncStatus: String?
    @Published private(set) var hasFolderSelected: Bool = false

    static let bookmarkKey = "selectedFolderBookmark"

    private let containerURL: URL

    init() {
        self.containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.extroverteddeveloper.GifKeyboard.shared"
        ) ?? FileManager.default.temporaryDirectory

        hasFolderSelected = UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil

        loadIndex()
    }

    // MARK: - Folder selection

    func selectFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let bookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        hasFolderSelected = true
    }

    private func resolvedFolderURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
            }
        }
        return url
    }

    // MARK: - Sync

    func syncNow() async {
        guard let sourceURL = resolvedFolderURL() else {
            syncStatus = "No folder selected — tap the folder icon to choose one"
            return
        }
        guard sourceURL.startAccessingSecurityScopedResource() else {
            syncStatus = "Error: Lost access to folder. Please select it again."
            return
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        isSyncing = true
        defer { isSyncing = false }

        let fm = FileManager.default
        try? fm.createDirectory(at: containerURL.appendingPathComponent("gifs"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: containerURL.appendingPathComponent("thumbnails"), withIntermediateDirectories: true)

        let service = SyncService(sourceDirectory: sourceURL, containerDirectory: containerURL)
        do {
            let result = try service.sync()
            lastSynced = Date()
            loadIndex()
            syncStatus = "Synced: +\(result.added) added, \(result.removed) removed, \(entries.count) total"
        } catch {
            syncStatus = "Sync error: \(error)"
        }
    }

    private func loadIndex() {
        let store = GifIndexStore(containerURL: containerURL)
        entries = (try? store.load()) ?? []
    }
}
