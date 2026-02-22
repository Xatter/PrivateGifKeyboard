# Alternate App Icons Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to pick from 4 app icons (Icon 1 default, Icons 2–4 as alternates) via a new Settings screen.

**Architecture:** SVGs converted to PNGs via rsvg-convert; primary icon in Assets.xcassets for App Store; alternate icon PNGs bundled directly in GifKeyboard/; CFBundleAlternateIcons declared in project.yml; SettingsView added with icon grid; gear toolbar button in ContentView opens it as a sheet.

**Tech Stack:** Swift, SwiftUI, UIKit (`UIApplication.setAlternateIconName`), XcodeGen (`project.yml`), rsvg-convert (Homebrew)

---

## Task 1: Install rsvg-convert

**Files:**
- No file changes — tool install only

**Step 1: Check if rsvg-convert is installed**

```bash
which rsvg-convert
```

Expected: a path, or "not found"

**Step 2: Install if missing**

```bash
brew install librsvg
```

Expected: installs successfully, `rsvg-convert --version` works

---

## Task 2: Convert SVGs to PNGs

The SVG source files are in the repo root. We need:
- 1024×1024 for Icon 1 only (App Store marketing icon in xcassets)
- 120×120 (@2x) and 180×180 (@3x) for all 4 icons (bundled for picker display and alternate icon switching)

**Files:**
- Create: `GifKeyboard/AppIcon@2x.png` (Icon 1, 120×120)
- Create: `GifKeyboard/AppIcon@3x.png` (Icon 1, 180×180)
- Create: `GifKeyboard/AppIcon2@2x.png` (Icon 2, 120×120)
- Create: `GifKeyboard/AppIcon2@3x.png` (Icon 2, 180×180)
- Create: `GifKeyboard/AppIcon3@2x.png` (Icon 3, 120×120)
- Create: `GifKeyboard/AppIcon3@3x.png` (Icon 3, 180×180)
- Create: `GifKeyboard/AppIcon4@2x.png` (Icon 4, 120×120)
- Create: `GifKeyboard/AppIcon4@3x.png` (Icon 4, 180×180)
- Create: `GifKeyboard/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (Icon 1, 1024×1024)

**Step 1: Generate all PNGs**

Run from repo root:

```bash
rsvg-convert -w 120 -h 120 "Icon 1.svg" -o "GifKeyboard/AppIcon@2x.png"
rsvg-convert -w 180 -h 180 "Icon 1.svg" -o "GifKeyboard/AppIcon@3x.png"
rsvg-convert -w 120 -h 120 "Icon 2.svg" -o "GifKeyboard/AppIcon2@2x.png"
rsvg-convert -w 180 -h 180 "Icon 2.svg" -o "GifKeyboard/AppIcon2@3x.png"
rsvg-convert -w 120 -h 120 "Icon 3.svg" -o "GifKeyboard/AppIcon3@2x.png"
rsvg-convert -w 180 -h 180 "Icon 3.svg" -o "GifKeyboard/AppIcon3@3x.png"
rsvg-convert -w 120 -h 120 "Icon 4.svg" -o "GifKeyboard/AppIcon4@2x.png"
rsvg-convert -w 180 -h 180 "Icon 4.svg" -o "GifKeyboard/AppIcon4@3x.png"
mkdir -p "GifKeyboard/Assets.xcassets/AppIcon.appiconset"
rsvg-convert -w 1024 -h 1024 "Icon 1.svg" -o "GifKeyboard/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
```

Expected: 9 PNG files created with no errors

**Step 2: Verify file sizes look correct**

```bash
ls -lh GifKeyboard/AppIcon*.png GifKeyboard/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

Expected: @2x files ~few KB, @3x ~few KB, 1024 ~tens to hundreds KB

---

## Task 3: Create Assets.xcassets

**Files:**
- Create: `GifKeyboard/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `GifKeyboard/Assets.xcassets/Contents.json`

**Step 1: Write the AppIcon Contents.json**

Create `GifKeyboard/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images": [
    {
      "filename": "AppIcon-1024.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Step 2: Write the top-level xcassets Contents.json**

Create `GifKeyboard/Assets.xcassets/Contents.json`:

```json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

---

## Task 4: Update project.yml

**Files:**
- Modify: `project.yml`

Add `ASSETCATALOG_COMPILER_APPICON_NAME` to the GifKeyboard target settings, and add `CFBundleAlternateIcons` to its info properties.

**Step 1: Update project.yml**

In `project.yml`, under the `GifKeyboard` target, update `settings.base` and `info.properties`:

```yaml
  GifKeyboard:
    type: application
    platform: iOS
    sources:
      - GifKeyboard
      - Shared
    entitlements:
      path: GifKeyboard/GifKeyboard.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.gifkeyboard.shared
        com.apple.developer.icloud-container-identifiers:
          - iCloud.com.gifkeyboard.app
        com.apple.developer.ubiquity-container-identifiers:
          - iCloud.com.gifkeyboard.app
    info:
      path: GifKeyboard/Info.plist
      properties:
        BGTaskSchedulerPermittedIdentifiers:
          - com.gifkeyboard.app.refresh
        NSUbiquitousContainers:
          iCloud.com.gifkeyboard.app:
            NSUbiquitousContainerIsDocumentScopePublic: true
            NSUbiquitousContainerSupportedFolderLevels: One
            NSUbiquitousContainerName: GifKeyboard
        CFBundleAlternateIcons:
          AppIcon2:
            CFBundleIconFiles:
              - AppIcon2
          AppIcon3:
            CFBundleIconFiles:
              - AppIcon3
          AppIcon4:
            CFBundleIconFiles:
              - AppIcon4
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.gifkeyboard.app
        INFOPLIST_FILE: GifKeyboard/Info.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

**Step 2: Regenerate Xcode project**

```bash
cd /Users/xatter/code/GifKeyboard && xcodegen generate
```

Expected: `✓ Generated project at GifKeyboard.xcodeproj`

---

## Task 5: Create AppIconOption enum

This is the model that drives the picker. Keep it in the app target so it's testable.

**Files:**
- Create: `GifKeyboard/AppIconOption.swift`
- Create: `GifKeyboardTests/AppIconOptionTests.swift`

**Step 1: Write the failing test**

Create `GifKeyboardTests/AppIconOptionTests.swift`:

```swift
import XCTest
@testable import GifKeyboard

final class AppIconOptionTests: XCTestCase {

    func test_allCasesHaveNonEmptyNames() {
        for option in AppIconOption.allCases {
            XCTAssertFalse(option.rawValue.isEmpty, "\(option) has empty rawValue")
            XCTAssertFalse(option.displayName.isEmpty, "\(option) has empty displayName")
        }
    }

    func test_defaultHasNilAlternateIconName() {
        XCTAssertNil(AppIconOption.default.alternateIconName)
    }

    func test_nonDefaultCasesHaveNonNilAlternateIconName() {
        let alternates = AppIconOption.allCases.filter { $0 != .default }
        XCTAssertFalse(alternates.isEmpty)
        for option in alternates {
            XCTAssertNotNil(option.alternateIconName, "\(option) should have an alternateIconName")
            XCTAssertEqual(option.alternateIconName, option.rawValue)
        }
    }

    func test_fourOptionsExist() {
        XCTAssertEqual(AppIconOption.allCases.count, 4)
    }
}
```

**Step 2: Run the test to confirm it fails**

```bash
cd /Users/xatter/code/GifKeyboard && xcodebuild test -scheme GifKeyboard -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GifKeyboardTests/AppIconOptionTests 2>&1 | tail -20
```

Expected: build error — `AppIconOption` not defined

**Step 3: Create AppIconOption.swift**

Create `GifKeyboard/AppIconOption.swift`:

```swift
import Foundation

enum AppIconOption: String, CaseIterable {
    case `default` = "AppIcon"
    case icon2 = "AppIcon2"
    case icon3 = "AppIcon3"
    case icon4 = "AppIcon4"

    var displayName: String {
        switch self {
        case .default: return "Icon 1"
        case .icon2:   return "Icon 2"
        case .icon3:   return "Icon 3"
        case .icon4:   return "Icon 4"
        }
    }

    /// The name passed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` means reset to the primary icon.
    var alternateIconName: String? {
        self == .default ? nil : rawValue
    }
}
```

**Step 4: Run the test to confirm it passes**

```bash
cd /Users/xatter/code/GifKeyboard && xcodebuild test -scheme GifKeyboard -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GifKeyboardTests/AppIconOptionTests 2>&1 | tail -20
```

Expected: `TEST SUCCEEDED`

**Step 5: Commit**

```bash
git add GifKeyboard/AppIconOption.swift GifKeyboardTests/AppIconOptionTests.swift
git commit -m "feat: add AppIconOption enum with tests"
```

---

## Task 6: Create SettingsView

**Files:**
- Create: `GifKeyboard/Views/SettingsView.swift`

**Step 1: Create SettingsView.swift**

```swift
import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var currentIcon: AppIconOption = .default

    var body: some View {
        NavigationStack {
            List {
                Section("App Icon") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80))],
                        spacing: 16
                    ) {
                        ForEach(AppIconOption.allCases, id: \.self) { option in
                            IconCell(option: option, isSelected: currentIcon == option) {
                                setIcon(option)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadCurrentIcon() }
        }
    }

    private func loadCurrentIcon() {
        let name = UIApplication.shared.alternateIconName
        currentIcon = AppIconOption.allCases.first { $0.alternateIconName == name } ?? .default
    }

    private func setIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            if error == nil {
                currentIcon = option
            }
        }
    }
}

private struct IconCell: View {
    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    iconImage
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 13))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .blue)
                            .offset(x: 4, y: 4)
                    }
                }
                Text(option.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconImage: some View {
        if let uiImage = UIImage(named: option.rawValue) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.gray.opacity(0.3))
        }
    }
}
```

**Step 2: Build to confirm it compiles**

```bash
cd /Users/xatter/code/GifKeyboard && xcodebuild build -scheme GifKeyboard -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add GifKeyboard/Views/SettingsView.swift
git commit -m "feat: add SettingsView with icon picker"
```

---

## Task 7: Add Settings button to ContentView

**Files:**
- Modify: `GifKeyboard/ContentView.swift`

**Step 1: Update ContentView.swift**

Add `@State private var showingSettings = false` and a toolbar gear button. The full updated file:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var showingSettings = false

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
                                forSecurityApplicationGroupIdentifier: "group.com.gifkeyboard.shared"
                            ) ?? FileManager.default.temporaryDirectory
                        )
                    }
                }
                .navigationTitle("GifKeyboard")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                await viewModel.syncNow()
            }
        }
    }
}
```

**Step 2: Build and run all tests**

```bash
cd /Users/xatter/code/GifKeyboard && xcodebuild test -scheme GifKeyboard -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```

Expected: `TEST SUCCEEDED`

**Step 3: Commit**

```bash
git add GifKeyboard/ContentView.swift
git commit -m "feat: add settings toolbar button opening icon picker"
```

---

## Task 8: Commit assets

**Step 1: Stage and commit all PNG and xcassets files**

```bash
git add GifKeyboard/AppIcon*.png GifKeyboard/Assets.xcassets project.yml GifKeyboard.xcodeproj
git commit -m "feat: add app icon assets and configure alternate icons"
```

---

## Manual Verification

1. Build and run on a simulator (iPhone 16)
2. Navigate past setup to the main GIF grid view
3. Tap the gear icon → Settings sheet appears
4. 4 icon options are shown as a grid with previews
5. Icon 1 has a checkmark (it's the default)
6. Tap Icon 2 → iOS prompts "Change App Icon?" → confirm → checkmark moves to Icon 2
7. Press home, confirm home screen shows Icon 2
8. Return to Settings, switch back to Icon 1
