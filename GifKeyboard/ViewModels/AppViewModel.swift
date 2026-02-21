import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {

    @Published var entries: [GifEntry] = []
    @Published var lastSynced: Date?
    @Published var isSyncing = false
    @Published var hasCompletedSetup: Bool

    @AppStorage("hasCompletedSetup") private var setupCompleted = false

    private let containerURL: URL
    private let iCloudURL: URL?

    init() {
        self.hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")

        self.containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gifkeyboard.shared"
        ) ?? FileManager.default.temporaryDirectory

        self.iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("GifKeyboard")

        loadIndex()
    }

    func completeSetup() {
        hasCompletedSetup = true
        setupCompleted = true
    }

    func syncNow() async {
        guard let sourceURL = iCloudURL else { return }

        isSyncing = true
        defer { isSyncing = false }

        let fm = FileManager.default
        try? fm.createDirectory(
            at: containerURL.appendingPathComponent("gifs"),
            withIntermediateDirectories: true)
        try? fm.createDirectory(
            at: containerURL.appendingPathComponent("thumbnails"),
            withIntermediateDirectories: true)

        let service = SyncService(
            sourceDirectory: sourceURL,
            containerDirectory: containerURL
        )

        do {
            _ = try service.sync()
            lastSynced = Date()
            loadIndex()
        } catch {
            print("Sync failed: \(error)")
        }
    }

    private func loadIndex() {
        let store = GifIndexStore(containerURL: containerURL)
        entries = (try? store.load()) ?? []
    }
}
