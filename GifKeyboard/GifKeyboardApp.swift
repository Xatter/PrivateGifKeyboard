import SwiftUI
import BackgroundTasks

@main
struct GifKeyboardApp: App {

    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.extroverteddeveloper.GifKeyboard.refresh",
            using: nil
        ) { task in
            Self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification
                )) { _ in
                    Self.scheduleBackgroundRefresh()
                }
        }
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.extroverteddeveloper.GifKeyboard.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.extroverteddeveloper.GifKeyboard.shared"
        ) ?? FileManager.default.temporaryDirectory

        guard let data = UserDefaults.standard.data(forKey: AppViewModel.bookmarkKey) else {
            task.setTaskCompleted(success: false)
            return
        }
        var isStale = false
        guard let sourceURL = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
              sourceURL.startAccessingSecurityScopedResource() else {
            task.setTaskCompleted(success: false)
            return
        }
        if isStale {
            if let fresh = try? sourceURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: AppViewModel.bookmarkKey)
            }
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let syncService = SyncService(sourceDirectory: sourceURL, containerDirectory: containerURL)
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        do {
            _ = try syncService.sync()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
}
