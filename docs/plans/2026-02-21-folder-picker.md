# Folder Picker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the hardcoded iCloud container path with a `UIDocumentPickerViewController` that lets users pick any folder (e.g. iCloud Drive > GifKeyboard) and persists a security-scoped bookmark for future syncs.

**Architecture:** A new `FolderPickerView` (UIViewControllerRepresentable) wraps UIDocumentPickerViewController. `AppViewModel` stores a security-scoped bookmark in UserDefaults and resolves it at sync time. `SetupView` gains a "Choose GIF Folder" button as its primary action; setup completes automatically when a folder is picked.

**Tech Stack:** SwiftUI, UIKit (UIDocumentPickerViewController), Foundation (URL bookmark data), BackgroundTasks

---

### Task 1: Create FolderPickerView

**Files:**
- Create: `GifKeyboard/Views/FolderPickerView.swift`

**Step 1: Create the file**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct FolderPickerView: UIViewControllerRepresentable {
    let onFolderSelected: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFolderSelected: onFolderSelected) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFolderSelected: (URL) -> Void
        init(onFolderSelected: @escaping (URL) -> Void) { self.onFolderSelected = onFolderSelected }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onFolderSelected(url)
        }
    }
}
```

**Step 2: Build to verify it compiles**

In Xcode: Cmd+B. Expected: no errors.

**Step 3: Commit**

```bash
git add GifKeyboard/Views/FolderPickerView.swift
git commit -m "feat: add FolderPickerView wrapping UIDocumentPickerViewController"
```

---

### Task 2: Rewrite AppViewModel with bookmark-based folder management

**Files:**
- Modify: `GifKeyboard/ViewModels/AppViewModel.swift`

Replace the entire file with:

```swift
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {

    @Published var entries: [GifEntry] = []
    @Published var lastSynced: Date?
    @Published var isSyncing = false
    @Published var syncStatus: String?

    private static let bookmarkKey = "selectedFolderBookmark"

    private let containerURL: URL

    var hasFolderSelected: Bool {
        UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil
    }

    init() {
        self.containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.extroverteddeveloper.GifKeyboard.shared"
        ) ?? FileManager.default.temporaryDirectory

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
```

**Step 2: Build to verify it compiles**

Cmd+B. Expected: no errors.

**Step 3: Commit**

```bash
git add GifKeyboard/ViewModels/AppViewModel.swift
git commit -m "feat: replace iCloud container path with security-scoped bookmark in AppViewModel"
```

---

### Task 3: Rewrite SetupView with folder picker button

**Files:**
- Modify: `GifKeyboard/Views/SetupView.swift`

Replace the entire file with:

```swift
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
```

**Step 2: Build to verify it compiles**

Cmd+B. Expected: no errors.

**Step 3: Commit**

```bash
git add GifKeyboard/Views/SetupView.swift
git commit -m "feat: replace static setup instructions with folder picker button"
```

---

### Task 4: Update ContentView to use hasFolderSelected

**Files:**
- Modify: `GifKeyboard/ContentView.swift`

**Step 1: Replace the setup gate and SetupView call**

Change line 7-10 from:
```swift
if !viewModel.hasCompletedSetup {
    SetupView {
        viewModel.completeSetup()
    }
```
to:
```swift
if !viewModel.hasFolderSelected {
    SetupView { url in
        viewModel.selectFolder(url)
    }
```

**Step 2: Update the empty state description**

Change line 18 from:
```swift
description: Text("Add GIF files to the GifKeyboard folder in iCloud Drive, then tap Sync.")
```
to:
```swift
description: Text("Add GIF files to your chosen folder, then tap Sync.")
```

**Step 3: Build to verify it compiles**

Cmd+B. Expected: no errors.

**Step 4: Commit**

```bash
git add GifKeyboard/ContentView.swift
git commit -m "feat: gate ContentView on hasFolderSelected, wire up selectFolder"
```

---

### Task 5: Update background refresh in GifKeyboardApp

**Files:**
- Modify: `GifKeyboard/GifKeyboardApp.swift`

**Step 1: Replace handleBackgroundRefresh**

Replace lines 33-59 with:

```swift
static func handleBackgroundRefresh(task: BGAppRefreshTask) {
    scheduleBackgroundRefresh()

    let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.extroverteddeveloper.GifKeyboard.shared"
    ) ?? FileManager.default.temporaryDirectory

    let bookmarkKey = "selectedFolderBookmark"
    guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
        task.setTaskCompleted(success: false)
        return
    }
    var isStale = false
    guard let sourceURL = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
          sourceURL.startAccessingSecurityScopedResource() else {
        task.setTaskCompleted(success: false)
        return
    }
    defer { sourceURL.stopAccessingSecurityScopedResource() }

    let syncService = SyncService(sourceDirectory: sourceURL, containerDirectory: containerURL)
    task.expirationHandler = {}
    do {
        _ = try syncService.sync()
        task.setTaskCompleted(success: true)
    } catch {
        task.setTaskCompleted(success: false)
    }
}
```

**Step 2: Build to verify it compiles**

Cmd+B. Expected: no errors.

**Step 3: Commit**

```bash
git add GifKeyboard/GifKeyboardApp.swift
git commit -m "feat: use security-scoped bookmark in background refresh"
```

---

### Task 6: Clean up iCloud entitlements and Info.plist

**Files:**
- Modify: `GifKeyboard/GifKeyboard.entitlements`
- Modify: `GifKeyboard/Info.plist`

**Step 1: Remove iCloud keys from entitlements**

Replace `GifKeyboard/GifKeyboard.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.extroverteddeveloper.GifKeyboard.shared</string>
	</array>
</dict>
</plist>
```

**Step 2: Remove NSUbiquitousContainers from Info.plist**

Remove the entire `NSUbiquitousContainers` dict block (lines 25-36), leaving `BGTaskSchedulerPermittedIdentifiers` and the `CFBundle*` keys intact.

**Step 3: Build to verify it compiles**

Cmd+B. Expected: no errors.

**Step 4: Commit**

```bash
git add GifKeyboard/GifKeyboard.entitlements GifKeyboard/Info.plist
git commit -m "chore: remove unused iCloud container entitlements and NSUbiquitousContainers"
```
