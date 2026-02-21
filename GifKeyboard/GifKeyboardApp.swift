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
        scheduleBackgroundRefresh() // Reschedule for next time

        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.extroverteddeveloper.GifKeyboard.shared"
        ) ?? FileManager.default.temporaryDirectory

        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("GifKeyboard") else {
            task.setTaskCompleted(success: false)
            return
        }

        let syncService = SyncService(
            sourceDirectory: iCloudURL,
            containerDirectory: containerURL
        )

        task.expirationHandler = { }

        do {
            _ = try syncService.sync()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
}
