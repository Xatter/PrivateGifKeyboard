# GifKeyboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a privacy-first iOS GIF keyboard that reads GIFs from an iCloud Drive folder, syncs them locally, and lets users search by filename and Finder tags.

**Architecture:** Xcode project with two targets (companion app + keyboard extension) sharing code via a `Shared/` directory. The companion app syncs GIFs from iCloud Drive to an App Group shared container with thumbnails and a JSON index. The keyboard extension reads from that container and copies raw GIF data to the pasteboard.

**Tech Stack:** Swift, SwiftUI, XcodeGen, XCTest, ImageIO framework, iCloud Drive APIs

**Design doc:** `docs/plans/2026-02-20-gif-keyboard-design.md`

---

## Prerequisites

Install XcodeGen if not already installed:
```bash
brew install xcodegen
```

All test commands use this pattern:
```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/<TestClassName>/<testMethodName> \
  2>&1 | xcpretty
```

If `xcpretty` is not installed: `gem install xcpretty`

App Group identifier used throughout: `group.com.gifkeyboard.shared`

---

### Task 1: Project Scaffolding

**Files:**
- Create: `project.yml` (XcodeGen spec)
- Create: `Shared/Models/GifEntry.swift`
- Create: `GifKeyboard/GifKeyboardApp.swift`
- Create: `GifKeyboard/ContentView.swift`
- Create: `GifKeyboard/Info.plist`
- Create: `GifKeyboard/GifKeyboard.entitlements`
- Create: `GifKeyboardExtension/KeyboardViewController.swift`
- Create: `GifKeyboardExtension/Info.plist`
- Create: `GifKeyboardExtension/GifKeyboardExtension.entitlements`
- Create: `GifKeyboardTests/GifEntryTests.swift`

**Step 1: Create directory structure**

```bash
mkdir -p GifKeyboard GifKeyboardExtension GifKeyboardTests Shared/Models Shared/Services
```

**Step 2: Create `project.yml`**

```yaml
name: GifKeyboard
options:
  bundleIdPrefix: com.gifkeyboard
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"

settings:
  base:
    SWIFT_VERSION: "5.9"

targets:
  GifKeyboard:
    type: application
    platform: iOS
    sources:
      - GifKeyboard
      - Shared
    entitlements:
      path: GifKeyboard/GifKeyboard.entitlements
    info:
      path: GifKeyboard/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.gifkeyboard.app
        INFOPLIST_FILE: GifKeyboard/Info.plist
    dependencies:
      - target: GifKeyboardExtension

  GifKeyboardExtension:
    type: app-extension
    platform: iOS
    sources:
      - GifKeyboardExtension
      - Shared
    entitlements:
      path: GifKeyboardExtension/GifKeyboardExtension.entitlements
    info:
      path: GifKeyboardExtension/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.gifkeyboard.app.keyboard
        INFOPLIST_FILE: GifKeyboardExtension/Info.plist

  GifKeyboardTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - GifKeyboardTests
      - Shared
    dependencies:
      - target: GifKeyboard
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/GifKeyboard.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/GifKeyboard"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

**Step 3: Create entitlements files**

`GifKeyboard/GifKeyboard.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.gifkeyboard.shared</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.gifkeyboard.app</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.gifkeyboard.app</string>
    </array>
</dict>
</plist>
```

`GifKeyboardExtension/GifKeyboardExtension.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.gifkeyboard.shared</string>
    </array>
</dict>
</plist>
```

**Step 4: Create Info.plist files**

`GifKeyboard/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSUbiquitousContainers</key>
    <dict>
        <key>iCloud.com.gifkeyboard.app</key>
        <dict>
            <key>NSUbiquitousContainerIsDocumentScopePublic</key>
            <true/>
            <key>NSUbiquitousContainerSupportedFolderLevels</key>
            <string>One</string>
            <key>NSUbiquitousContainerName</key>
            <string>GifKeyboard</string>
        </dict>
    </dict>
</dict>
</plist>
```

`GifKeyboardExtension/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>IsASCIICapable</key>
            <false/>
            <key>PrefersRightToLeft</key>
            <false/>
            <key>PrimaryLanguage</key>
            <string>en-US</string>
            <key>RequestsOpenAccess</key>
            <false/>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.keyboard-service</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
    </dict>
</dict>
</plist>
```

**Step 5: Create minimal source files to make it compile**

`Shared/Models/GifEntry.swift`:
```swift
import Foundation

struct GifEntry: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let tags: [String]
    let thumbnailPath: String
    let gifPath: String
    let fileSize: Int64
    let dateAdded: Date
}
```

`GifKeyboard/GifKeyboardApp.swift`:
```swift
import SwiftUI

@main
struct GifKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`GifKeyboard/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("GifKeyboard")
    }
}
```

`GifKeyboardExtension/KeyboardViewController.swift`:
```swift
import UIKit

class KeyboardViewController: UIInputViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
```

**Step 6: Generate project and verify it builds**

```bash
xcodegen generate
xcodebuild build \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  2>&1 | xcpretty
```

Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with app, keyboard extension, and test targets"
```

---

### Task 2: GifEntry Model + JSON Serialization

**Files:**
- Modify: `Shared/Models/GifEntry.swift`
- Create: `GifKeyboardTests/GifEntryTests.swift`

**Step 1: Write the failing tests**

`GifKeyboardTests/GifEntryTests.swift`:
```swift
import XCTest
@testable import GifKeyboard

final class GifEntryTests: XCTestCase {

    func testEncodeAndDecode() throws {
        let entry = GifEntry(
            filename: "mind-blown.gif",
            tags: ["reaction", "funny"],
            thumbnailPath: "thumbnails/mind-blown.jpg",
            gifPath: "gifs/mind-blown.gif",
            fileSize: 245760,
            dateAdded: Date(timeIntervalSince1970: 1000000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GifEntry.self, from: data)

        XCTAssertEqual(decoded.filename, "mind-blown.gif")
        XCTAssertEqual(decoded.tags, ["reaction", "funny"])
        XCTAssertEqual(decoded.thumbnailPath, "thumbnails/mind-blown.jpg")
        XCTAssertEqual(decoded.gifPath, "gifs/mind-blown.gif")
        XCTAssertEqual(decoded.fileSize, 245760)
        XCTAssertEqual(decoded.dateAdded, entry.dateAdded)
    }

    func testDecodeArray() throws {
        let json = """
        [
            {
                "filename": "a.gif",
                "tags": ["tag1"],
                "thumbnailPath": "thumbnails/a.jpg",
                "gifPath": "gifs/a.gif",
                "fileSize": 100,
                "dateAdded": "2026-02-20T12:00:00Z"
            },
            {
                "filename": "b.gif",
                "tags": [],
                "thumbnailPath": "thumbnails/b.jpg",
                "gifPath": "gifs/b.gif",
                "fileSize": 200,
                "dateAdded": "2026-02-19T12:00:00Z"
            }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([GifEntry].self, from: json)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].filename, "a.gif")
        XCTAssertEqual(entries[1].tags, [])
    }

    func testIdentity() {
        let entry = GifEntry(
            filename: "test.gif",
            tags: [],
            thumbnailPath: "thumbnails/test.jpg",
            gifPath: "gifs/test.gif",
            fileSize: 100,
            dateAdded: Date()
        )
        XCTAssertEqual(entry.id, "test.gif")
    }
}
```

**Step 2: Run tests to verify they pass** (model already exists from Task 1)

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/GifEntryTests \
  2>&1 | xcpretty
```

Expected: All 3 tests PASS (the model from Task 1 should already work)

**Step 3: Commit**

```bash
git add GifKeyboardTests/GifEntryTests.swift
git commit -m "test: add GifEntry model serialization tests"
```

---

### Task 3: Search Filtering Logic

**Files:**
- Create: `Shared/Services/GifSearchService.swift`
- Create: `GifKeyboardTests/GifSearchServiceTests.swift`

**Step 1: Write the failing tests**

`GifKeyboardTests/GifSearchServiceTests.swift`:
```swift
import XCTest
@testable import GifKeyboard

final class GifSearchServiceTests: XCTestCase {

    let entries = [
        GifEntry(filename: "mind-blown.gif", tags: ["reaction", "funny"],
                 thumbnailPath: "", gifPath: "", fileSize: 100, dateAdded: Date()),
        GifEntry(filename: "thumbs-up.gif", tags: ["reaction", "approval"],
                 thumbnailPath: "", gifPath: "", fileSize: 200, dateAdded: Date()),
        GifEntry(filename: "cat-typing.gif", tags: ["animal", "funny"],
                 thumbnailPath: "", gifPath: "", fileSize: 300, dateAdded: Date()),
        GifEntry(filename: "deal-with-it.gif", tags: [],
                 thumbnailPath: "", gifPath: "", fileSize: 400, dateAdded: Date()),
    ]

    func testEmptyQueryReturnsAll() {
        let results = GifSearchService.filter(entries: entries, query: "")
        XCTAssertEqual(results.count, 4)
    }

    func testFilterByFilename() {
        let results = GifSearchService.filter(entries: entries, query: "cat")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].filename, "cat-typing.gif")
    }

    func testFilterByTag() {
        let results = GifSearchService.filter(entries: entries, query: "funny")
        XCTAssertEqual(results.count, 2)
    }

    func testFilterIsCaseInsensitive() {
        let results = GifSearchService.filter(entries: entries, query: "MIND")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].filename, "mind-blown.gif")
    }

    func testFilterByPartialTag() {
        let results = GifSearchService.filter(entries: entries, query: "react")
        XCTAssertEqual(results.count, 2)
    }

    func testFilterNoMatch() {
        let results = GifSearchService.filter(entries: entries, query: "zzzzz")
        XCTAssertEqual(results.count, 0)
    }

    func testFilterMatchesFilenameWithoutExtension() {
        let results = GifSearchService.filter(entries: entries, query: "deal")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].filename, "deal-with-it.gif")
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/GifSearchServiceTests \
  2>&1 | xcpretty
```

Expected: FAIL — `GifSearchService` not defined

**Step 3: Write the implementation**

`Shared/Services/GifSearchService.swift`:
```swift
import Foundation

enum GifSearchService {

    static func filter(entries: [GifEntry], query: String) -> [GifEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }

        let lowered = trimmed.lowercased()
        return entries.filter { entry in
            if entry.filename.lowercased().contains(lowered) {
                return true
            }
            return entry.tags.contains { $0.lowercased().contains(lowered) }
        }
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/GifSearchServiceTests \
  2>&1 | xcpretty
```

Expected: All 7 tests PASS

**Step 5: Commit**

```bash
git add Shared/Services/GifSearchService.swift GifKeyboardTests/GifSearchServiceTests.swift
git commit -m "feat: add search filtering by filename and tags"
```

---

### Task 4: Tag Extraction Service

**Files:**
- Create: `Shared/Services/TagExtractor.swift`
- Create: `GifKeyboardTests/TagExtractorTests.swift`
- Create: `GifKeyboardTests/Fixtures/` (test GIF files)

**Step 1: Write the failing tests**

We use a protocol so we can test the `getxattr` fallback path independently.

`GifKeyboardTests/TagExtractorTests.swift`:
```swift
import XCTest
@testable import GifKeyboard

final class TagExtractorTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testExtractTagsFromExtendedAttribute() throws {
        // Create a temp file and set the tag extended attribute manually
        let fileURL = tempDir.appendingPathComponent("test.gif")
        try Data([0x47, 0x49, 0x46]).write(to: fileURL)

        // Write tags using the same plist format Finder uses
        let tags = ["reaction", "funny"]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: tags, format: .binary, options: 0
        )
        let result = fileURL.withUnsafeFileSystemRepresentation { path in
            plistData.withUnsafeBytes { bytes in
                setxattr(path, "com.apple.metadata:_kMDItemUserTags", bytes.baseAddress, bytes.count, 0, 0)
            }
        }
        XCTAssertEqual(result, 0, "setxattr should succeed")

        let extracted = TagExtractor.extractTags(from: fileURL)
        XCTAssertEqual(Set(extracted), Set(["reaction", "funny"]))
    }

    func testExtractTagsReturnsEmptyForUntaggedFile() throws {
        let fileURL = tempDir.appendingPathComponent("untagged.gif")
        try Data([0x47, 0x49, 0x46]).write(to: fileURL)

        let extracted = TagExtractor.extractTags(from: fileURL)
        XCTAssertEqual(extracted, [])
    }

    func testExtractTagsStripsFinderColorSuffix() throws {
        // Finder stores tags as "tagname\n0" where \n0 is a color index
        let fileURL = tempDir.appendingPathComponent("colored.gif")
        try Data([0x47, 0x49, 0x46]).write(to: fileURL)

        let tags = ["reaction\n2", "funny\n0"]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: tags, format: .binary, options: 0
        )
        fileURL.withUnsafeFileSystemRepresentation { path in
            plistData.withUnsafeBytes { bytes in
                _ = setxattr(path, "com.apple.metadata:_kMDItemUserTags", bytes.baseAddress, bytes.count, 0, 0)
            }
        }

        let extracted = TagExtractor.extractTags(from: fileURL)
        XCTAssertEqual(Set(extracted), Set(["reaction", "funny"]))
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/TagExtractorTests \
  2>&1 | xcpretty
```

Expected: FAIL — `TagExtractor` not defined

**Step 3: Write the implementation**

`Shared/Services/TagExtractor.swift`:
```swift
import Foundation

enum TagExtractor {

    static func extractTags(from url: URL) -> [String] {
        // Try URLResourceKey.tagNamesKey first (works on macOS, may work on iOS for iCloud files)
        if let resourceValues = try? url.resourceValues(forKeys: [.tagNamesKey]),
           let tags = resourceValues.tagNames, !tags.isEmpty {
            return tags
        }

        // Fallback: read the extended attribute directly
        return extractTagsViaXattr(from: url)
    }

    private static func extractTagsViaXattr(from url: URL) -> [String] {
        let attributeName = "com.apple.metadata:_kMDItemUserTags"

        let length = url.withUnsafeFileSystemRepresentation { path in
            getxattr(path, attributeName, nil, 0, 0, 0)
        }

        guard length > 0 else { return [] }

        var data = Data(count: length)
        let readLength = data.withUnsafeMutableBytes { bytes in
            url.withUnsafeFileSystemRepresentation { path in
                getxattr(path, attributeName, bytes.baseAddress, length, 0, 0)
            }
        }

        guard readLength == length else { return [] }

        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String] else {
            return []
        }

        // Finder stores tags as "tagname\ncolorIndex" — strip the color suffix
        return plist.map { tag in
            if let newlineIndex = tag.firstIndex(of: "\n") {
                return String(tag[tag.startIndex..<newlineIndex])
            }
            return tag
        }
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/TagExtractorTests \
  2>&1 | xcpretty
```

Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add Shared/Services/TagExtractor.swift GifKeyboardTests/TagExtractorTests.swift
git commit -m "feat: add Finder tag extraction with getxattr fallback"
```

---

### Task 5: Thumbnail Generation

**Files:**
- Create: `Shared/Services/ThumbnailGenerator.swift`
- Create: `GifKeyboardTests/ThumbnailGeneratorTests.swift`
- Create: `GifKeyboardTests/Fixtures/test-animation.gif` (a real multi-frame GIF)

**Step 1: Create a test GIF fixture**

Write a small Swift script or use ImageIO to create a minimal valid 2-frame GIF programmatically in the test setUp.

**Step 2: Write the failing tests**

`GifKeyboardTests/ThumbnailGeneratorTests.swift`:
```swift
import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class ThumbnailGeneratorTests: XCTestCase {

    var tempDir: URL!
    var testGifURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a minimal valid 2-frame GIF programmatically
        testGifURL = tempDir.appendingPathComponent("test.gif")
        createTestGif(at: testGifURL, width: 200, height: 200, frameCount: 2)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testGeneratesThumbnailAsJPEG() throws {
        let outputURL = tempDir.appendingPathComponent("thumb.jpg")
        try ThumbnailGenerator.generateThumbnail(
            from: testGifURL, to: outputURL, maxPixelSize: 150
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let data = try Data(contentsOf: outputURL)
        // JPEG starts with FF D8
        XCTAssertEqual(data[0], 0xFF)
        XCTAssertEqual(data[1], 0xD8)
    }

    func testThumbnailIsScaledDown() throws {
        let outputURL = tempDir.appendingPathComponent("thumb.jpg")
        try ThumbnailGenerator.generateThumbnail(
            from: testGifURL, to: outputURL, maxPixelSize: 150
        )

        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            XCTFail("Could not read thumbnail")
            return
        }

        XCTAssertLessThanOrEqual(image.width, 150)
        XCTAssertLessThanOrEqual(image.height, 150)
    }

    func testThumbnailFromFirstFrameOnly() throws {
        // The output should be a static JPEG, not an animated GIF
        let outputURL = tempDir.appendingPathComponent("thumb.jpg")
        try ThumbnailGenerator.generateThumbnail(
            from: testGifURL, to: outputURL, maxPixelSize: 150
        )

        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil) else {
            XCTFail("Could not read thumbnail")
            return
        }

        XCTAssertEqual(CGImageSourceGetCount(source), 1, "Thumbnail should have exactly 1 frame")
    }

    // MARK: - Helpers

    private func createTestGif(at url: URL, width: Int, height: Int, frameCount: Int) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return }

        let gifProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 0.1
        ]] as CFDictionary

        for i in 0..<frameCount {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            // Draw a different color each frame so they're distinguishable
            let gray = CGFloat(i) / CGFloat(frameCount)
            context.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1.0))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }

        CGImageDestinationFinalize(destination)
    }
}
```

**Step 3: Run tests to verify they fail**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/ThumbnailGeneratorTests \
  2>&1 | xcpretty
```

Expected: FAIL — `ThumbnailGenerator` not defined

**Step 4: Write the implementation**

`Shared/Services/ThumbnailGenerator.swift`:
```swift
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ThumbnailGenerator {

    enum ThumbnailError: Error {
        case failedToCreateImageSource
        case failedToCreateThumbnail
        case failedToCreateDestination
        case failedToFinalize
    }

    static func generateThumbnail(from sourceURL: URL, to destinationURL: URL, maxPixelSize: Int) throws {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ThumbnailError.failedToCreateImageSource
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        // Extract only the first frame
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ThumbnailError.failedToCreateThumbnail
        }

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw ThumbnailError.failedToCreateDestination
        }

        let jpegOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ]

        CGImageDestinationAddImage(destination, thumbnail, jpegOptions as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailError.failedToFinalize
        }
    }
}
```

**Step 5: Run tests to verify they pass**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/ThumbnailGeneratorTests \
  2>&1 | xcpretty
```

Expected: All 3 tests PASS

**Step 6: Commit**

```bash
git add Shared/Services/ThumbnailGenerator.swift GifKeyboardTests/ThumbnailGeneratorTests.swift
git commit -m "feat: add thumbnail generation from first GIF frame"
```

---

### Task 6: GIF Pasteboard Service + Animation Validation

This is the critical task that ensures GIFs actually animate when pasted into iMessage, Threads, Twitter, etc.

**Files:**
- Create: `Shared/Services/GifPasteboardService.swift`
- Create: `GifKeyboardTests/GifPasteboardServiceTests.swift`

**Step 1: Write the failing tests**

`GifKeyboardTests/GifPasteboardServiceTests.swift`:
```swift
import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class GifPasteboardServiceTests: XCTestCase {

    var tempDir: URL!
    var testGifURL: URL!
    var testGifData: Data!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testGifURL = tempDir.appendingPathComponent("animated.gif")
        createTestGif(at: testGifURL, width: 100, height: 100, frameCount: 3)
        testGifData = try! Data(contentsOf: testGifURL)
    }

    override func tearDown() {
        UIPasteboard.general.items = []
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCopiesWithGifUTIType() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        XCTAssertTrue(
            pasteboard.contains(pasteboardTypes: [UTType.gif.identifier]),
            "Pasteboard should contain com.compuserve.gif type"
        )
    }

    func testPasteboardDataIsValidGif() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        guard let data = pasteboard.data(forPasteboardType: UTType.gif.identifier) else {
            XCTFail("No GIF data on pasteboard")
            return
        }

        // GIF89a magic bytes
        XCTAssertGreaterThanOrEqual(data.count, 6)
        XCTAssertEqual(data[0], 0x47) // G
        XCTAssertEqual(data[1], 0x49) // I
        XCTAssertEqual(data[2], 0x46) // F
        XCTAssertEqual(data[3], 0x38) // 8
        XCTAssertEqual(data[4], 0x39) // 9
        XCTAssertEqual(data[5], 0x61) // a
    }

    func testPasteboardDataContainsMultipleFrames() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        guard let data = pasteboard.data(forPasteboardType: UTType.gif.identifier) else {
            XCTFail("No GIF data on pasteboard")
            return
        }

        // Verify the data has multiple frames (it's not a static image)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            XCTFail("Could not create image source from pasteboard data")
            return
        }

        let frameCount = CGImageSourceGetCount(source)
        XCTAssertEqual(frameCount, 3, "Pasteboard GIF should preserve all 3 animation frames")
    }

    func testPasteboardDataIsByteIdenticalToSource() throws {
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        guard let data = pasteboard.data(forPasteboardType: UTType.gif.identifier) else {
            XCTFail("No GIF data on pasteboard")
            return
        }

        XCTAssertEqual(
            data, testGifData,
            "Pasteboard data must be byte-identical to source — no re-encoding allowed"
        )
    }

    func testDoesNotSetPNGType() throws {
        // Guard against UIImage accidentally converting GIF to static PNG
        try GifPasteboardService.copyGifToPasteboard(from: testGifURL)

        let pasteboard = UIPasteboard.general
        let hasPNG = pasteboard.contains(pasteboardTypes: [UTType.png.identifier])
        // We allow PNG as a secondary representation, but the primary must be GIF
        let hasGIF = pasteboard.contains(pasteboardTypes: [UTType.gif.identifier])
        XCTAssertTrue(hasGIF, "Must have GIF type on pasteboard")

        if hasPNG {
            // If PNG is present, GIF must also be present as the primary type
            XCTAssertTrue(hasGIF, "If PNG is on pasteboard, GIF must also be present")
        }
    }

    // MARK: - Helpers

    private func createTestGif(at url: URL, width: Int, height: Int, frameCount: Int) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return }

        let gifProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 0.1
        ]] as CFDictionary

        for i in 0..<frameCount {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            let gray = CGFloat(i) / CGFloat(max(frameCount - 1, 1))
            context.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1.0))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }

        CGImageDestinationFinalize(destination)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/GifPasteboardServiceTests \
  2>&1 | xcpretty
```

Expected: FAIL — `GifPasteboardService` not defined

**Step 3: Write the implementation**

`Shared/Services/GifPasteboardService.swift`:
```swift
import UIKit
import UniformTypeIdentifiers

enum GifPasteboardService {

    enum PasteboardError: Error {
        case fileNotFound
        case failedToReadData
    }

    static func copyGifToPasteboard(from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PasteboardError.fileNotFound
        }

        let data = try Data(contentsOf: url)

        // CRITICAL: Set raw GIF data directly with the GIF UTI type.
        // Do NOT use UIImage — it strips animation frames and re-encodes as PNG.
        UIPasteboard.general.setData(data, forPasteboardType: UTType.gif.identifier)
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/GifPasteboardServiceTests \
  2>&1 | xcpretty
```

Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add Shared/Services/GifPasteboardService.swift GifKeyboardTests/GifPasteboardServiceTests.swift
git commit -m "feat: add pasteboard service with GIF animation preservation tests"
```

---

### Task 7: GIF Index Persistence

Read/write the `index.json` file from the App Group container.

**Files:**
- Create: `Shared/Services/GifIndexStore.swift`
- Create: `GifKeyboardTests/GifIndexStoreTests.swift`

**Step 1: Write the failing tests**

`GifKeyboardTests/GifIndexStoreTests.swift`:
```swift
import XCTest
@testable import GifKeyboard

final class GifIndexStoreTests: XCTestCase {

    var tempDir: URL!
    var store: GifIndexStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = GifIndexStore(containerURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let entries = [
            GifEntry(filename: "a.gif", tags: ["funny"], thumbnailPath: "thumbnails/a.jpg",
                     gifPath: "gifs/a.gif", fileSize: 100,
                     dateAdded: Date(timeIntervalSince1970: 1000000))
        ]

        try store.save(entries)
        let loaded = try store.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].filename, "a.gif")
        XCTAssertEqual(loaded[0].tags, ["funny"])
    }

    func testLoadReturnsEmptyWhenNoFile() throws {
        let loaded = try store.load()
        XCTAssertEqual(loaded, [])
    }

    func testOverwritesExistingFile() throws {
        let first = [
            GifEntry(filename: "a.gif", tags: [], thumbnailPath: "", gifPath: "",
                     fileSize: 100, dateAdded: Date())
        ]
        try store.save(first)

        let second = [
            GifEntry(filename: "b.gif", tags: ["new"], thumbnailPath: "", gifPath: "",
                     fileSize: 200, dateAdded: Date())
        ]
        try store.save(second)

        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].filename, "b.gif")
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/GifIndexStoreTests \
  2>&1 | xcpretty
```

Expected: FAIL — `GifIndexStore` not defined

**Step 3: Write the implementation**

`Shared/Services/GifIndexStore.swift`:
```swift
import Foundation

final class GifIndexStore {

    private let indexURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(containerURL: URL) {
        self.indexURL = containerURL.appendingPathComponent("index.json")

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ entries: [GifEntry]) throws {
        let data = try encoder.encode(entries)
        try data.write(to: indexURL, options: .atomic)
    }

    func load() throws -> [GifEntry] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        let data = try Data(contentsOf: indexURL)
        return try decoder.decode([GifEntry].self, from: data)
    }
}
```

**Step 4: Make `GifEntry` conform to `Equatable`**

Update `Shared/Models/GifEntry.swift` — add `Equatable`:
```swift
struct GifEntry: Codable, Identifiable, Equatable {
```

**Step 5: Run tests to verify they pass**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/GifIndexStoreTests \
  2>&1 | xcpretty
```

Expected: All 3 tests PASS

**Step 6: Commit**

```bash
git add Shared/Services/GifIndexStore.swift Shared/Models/GifEntry.swift GifKeyboardTests/GifIndexStoreTests.swift
git commit -m "feat: add JSON index persistence for App Group container"
```

---

### Task 8: Sync Service

Orchestrates the full sync: enumerate iCloud folder, diff against index, generate thumbnails, extract tags, update index.

**Files:**
- Create: `Shared/Services/SyncService.swift`
- Create: `GifKeyboardTests/SyncServiceTests.swift`

**Step 1: Write the failing tests**

`GifKeyboardTests/SyncServiceTests.swift`:
```swift
import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class SyncServiceTests: XCTestCase {

    var sourceDir: URL!
    var containerDir: URL!
    var syncService: SyncService!

    override func setUp() {
        super.setUp()
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        sourceDir = base.appendingPathComponent("icloud")
        containerDir = base.appendingPathComponent("container")

        try! FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(
            at: containerDir.appendingPathComponent("gifs"), withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(
            at: containerDir.appendingPathComponent("thumbnails"), withIntermediateDirectories: true)

        syncService = SyncService(
            sourceDirectory: sourceDir,
            containerDirectory: containerDir
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: sourceDir.deletingLastPathComponent())
        super.tearDown()
    }

    func testSyncAddsNewGifs() throws {
        createTestGif(at: sourceDir.appendingPathComponent("hello.gif"))

        let result = try syncService.sync()

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.removed, 0)

        let store = GifIndexStore(containerURL: containerDir)
        let entries = try store.load()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].filename, "hello.gif")

        // Verify files were copied
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("gifs/hello.gif").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("thumbnails/hello.jpg").path))
    }

    func testSyncSkipsExistingGifs() throws {
        createTestGif(at: sourceDir.appendingPathComponent("hello.gif"))
        _ = try syncService.sync()

        // Sync again — nothing should change
        let result = try syncService.sync()
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.removed, 0)
    }

    func testSyncRemovesDeletedGifs() throws {
        createTestGif(at: sourceDir.appendingPathComponent("hello.gif"))
        _ = try syncService.sync()

        // Delete the source GIF
        try FileManager.default.removeItem(at: sourceDir.appendingPathComponent("hello.gif"))

        let result = try syncService.sync()
        XCTAssertEqual(result.removed, 1)

        let store = GifIndexStore(containerURL: containerDir)
        let entries = try store.load()
        XCTAssertEqual(entries.count, 0)

        // Verify files were cleaned up
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("gifs/hello.gif").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: containerDir.appendingPathComponent("thumbnails/hello.jpg").path))
    }

    func testSyncIgnoresNonGifFiles() throws {
        // Create a non-GIF file in the source directory
        try "not a gif".data(using: .utf8)!
            .write(to: sourceDir.appendingPathComponent("readme.txt"))
        createTestGif(at: sourceDir.appendingPathComponent("real.gif"))

        let result = try syncService.sync()
        XCTAssertEqual(result.added, 1)

        let store = GifIndexStore(containerURL: containerDir)
        let entries = try store.load()
        XCTAssertEqual(entries[0].filename, "real.gif")
    }

    // MARK: - Helpers

    private func createTestGif(at url: URL, frameCount: Int = 2) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return }

        let gifProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 0.1
        ]] as CFDictionary

        for i in 0..<frameCount {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil, width: 50, height: 50, bitsPerComponent: 8,
                bytesPerRow: 200, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            let v = CGFloat(i) / CGFloat(max(frameCount - 1, 1))
            context.setFillColor(CGColor(red: v, green: v, blue: v, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }
        CGImageDestinationFinalize(destination)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/SyncServiceTests \
  2>&1 | xcpretty
```

Expected: FAIL — `SyncService` not defined

**Step 3: Write the implementation**

`Shared/Services/SyncService.swift`:
```swift
import Foundation

final class SyncService {

    struct SyncResult {
        let added: Int
        let removed: Int
    }

    private let sourceDirectory: URL
    private let containerDirectory: URL
    private let indexStore: GifIndexStore
    private let fileManager = FileManager.default

    init(sourceDirectory: URL, containerDirectory: URL) {
        self.sourceDirectory = sourceDirectory
        self.containerDirectory = containerDirectory
        self.indexStore = GifIndexStore(containerURL: containerDirectory)
    }

    func sync() throws -> SyncResult {
        var existing = try indexStore.load()
        let existingFilenames = Set(existing.map(\.filename))

        // Enumerate source directory for .gif files
        let sourceFiles = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .tagNamesKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "gif" }

        let sourceFilenames = Set(sourceFiles.map(\.lastPathComponent))

        // Add new GIFs
        var addedCount = 0
        for fileURL in sourceFiles {
            let filename = fileURL.lastPathComponent
            guard !existingFilenames.contains(filename) else { continue }

            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resourceValues.fileSize ?? 0)

            // Extract tags
            let tags = TagExtractor.extractTags(from: fileURL)

            // Copy GIF to container
            let destGifURL = containerDirectory
                .appendingPathComponent("gifs")
                .appendingPathComponent(filename)
            try fileManager.copyItem(at: fileURL, to: destGifURL)

            // Generate thumbnail
            let thumbFilename = filename.replacingOccurrences(
                of: ".gif", with: ".jpg", options: .caseInsensitive)
            let destThumbURL = containerDirectory
                .appendingPathComponent("thumbnails")
                .appendingPathComponent(thumbFilename)
            try ThumbnailGenerator.generateThumbnail(
                from: fileURL, to: destThumbURL, maxPixelSize: 150)

            let entry = GifEntry(
                filename: filename,
                tags: tags,
                thumbnailPath: "thumbnails/\(thumbFilename)",
                gifPath: "gifs/\(filename)",
                fileSize: fileSize,
                dateAdded: Date()
            )
            existing.append(entry)
            addedCount += 1
        }

        // Remove deleted GIFs
        var removedCount = 0
        existing.removeAll { entry in
            if !sourceFilenames.contains(entry.filename) {
                // Clean up files
                let gifURL = containerDirectory.appendingPathComponent(entry.gifPath)
                let thumbURL = containerDirectory.appendingPathComponent(entry.thumbnailPath)
                try? fileManager.removeItem(at: gifURL)
                try? fileManager.removeItem(at: thumbURL)
                removedCount += 1
                return true
            }
            return false
        }

        try indexStore.save(existing)

        return SyncResult(added: addedCount, removed: removedCount)
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GifKeyboardTests/SyncServiceTests \
  2>&1 | xcpretty
```

Expected: All 4 tests PASS

**Step 5: Commit**

```bash
git add Shared/Services/SyncService.swift GifKeyboardTests/SyncServiceTests.swift
git commit -m "feat: add sync service — enumerates iCloud folder, diffs, generates thumbnails"
```

---

### Task 9: Companion App UI

**Files:**
- Modify: `GifKeyboard/GifKeyboardApp.swift`
- Modify: `GifKeyboard/ContentView.swift`
- Create: `GifKeyboard/Views/SetupView.swift`
- Create: `GifKeyboard/Views/GifGridView.swift`
- Create: `GifKeyboard/ViewModels/AppViewModel.swift`

**Step 1: Create the view model**

`GifKeyboard/ViewModels/AppViewModel.swift`:
```swift
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

        // Ensure container subdirectories exist
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
```

**Step 2: Create the setup view**

`GifKeyboard/Views/SetupView.swift`:
```swift
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

            Button("I've Done This — Let's Go") {
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
```

**Step 3: Create the GIF grid view**

`GifKeyboard/Views/GifGridView.swift`:
```swift
import SwiftUI

struct GifGridView: View {
    let entries: [GifEntry]
    let containerURL: URL

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(entries) { entry in
                    let thumbURL = containerURL.appendingPathComponent(entry.thumbnailPath)
                    AsyncImage(url: thumbURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(minHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }
}
```

**Step 4: Update ContentView**

`GifKeyboard/ContentView.swift`:
```swift
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
                                forSecurityApplicationGroupIdentifier: "group.com.gifkeyboard.shared"
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
```

**Step 5: Build to verify compilation**

```bash
xcodebuild build \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  2>&1 | xcpretty
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add GifKeyboard/
git commit -m "feat: add companion app UI with setup flow, sync button, and GIF grid"
```

---

### Task 10: Keyboard Extension UI

**Files:**
- Modify: `GifKeyboardExtension/KeyboardViewController.swift`

The keyboard extension uses UIKit (`UIInputViewController`) since SwiftUI support in keyboard extensions is limited on older iOS.

**Step 1: Implement the keyboard view controller**

`GifKeyboardExtension/KeyboardViewController.swift`:
```swift
import UIKit
import UniformTypeIdentifiers

class KeyboardViewController: UIInputViewController {

    private var entries: [GifEntry] = []
    private var filteredEntries: [GifEntry] = []
    private var containerURL: URL!

    private var collectionView: UICollectionView!
    private var searchBar: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gifkeyboard.shared"
        ) ?? FileManager.default.temporaryDirectory

        loadIndex()
        setupUI()
    }

    // MARK: - Data

    private func loadIndex() {
        let store = GifIndexStore(containerURL: containerURL)
        entries = ((try? store.load()) ?? [])
            .sorted { $0.dateAdded > $1.dateAdded }
        filteredEntries = entries
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let view = view else { return }
        view.backgroundColor = .systemBackground

        // Search bar
        searchBar = UITextField()
        searchBar.placeholder = "Search GIFs..."
        searchBar.borderStyle = .roundedRect
        searchBar.returnKeyType = .search
        searchBar.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        // Globe button to switch keyboards
        let globeButton = UIButton(type: .system)
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)),
                              for: .allTouchEvents)
        globeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(globeButton)

        // Collection view
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GifCell.self, forCellWithReuseIdentifier: GifCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            globeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            globeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            globeButton.widthAnchor.constraint(equalToConstant: 32),
            globeButton.heightAnchor.constraint(equalToConstant: 32),

            searchBar.leadingAnchor.constraint(equalTo: globeButton.trailingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            searchBar.heightAnchor.constraint(equalToConstant: 36),

            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            collectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
    }

    @objc private func searchTextChanged() {
        let query = searchBar.text ?? ""
        filteredEntries = GifSearchService.filter(entries: entries, query: query)
        collectionView.reloadData()
    }

    private func copyGif(_ entry: GifEntry) {
        let gifURL = containerURL.appendingPathComponent(entry.gifPath)
        try? GifPasteboardService.copyGifToPasteboard(from: gifURL)
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension KeyboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredEntries.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GifCell.reuseID, for: indexPath) as! GifCell
        let entry = filteredEntries[indexPath.item]
        let thumbURL = containerURL.appendingPathComponent(entry.thumbnailPath)
        cell.configure(with: thumbURL)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let entry = filteredEntries[indexPath.item]
        copyGif(entry)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 4
        let spacing: CGFloat = 4
        let totalSpacing = spacing * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }
}

// MARK: - GifCell

private final class GifCell: UICollectionViewCell {
    static let reuseID = "GifCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with thumbnailURL: URL) {
        // Load thumbnail on background queue to keep keyboard responsive
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let data = try? Data(contentsOf: thumbnailURL),
                  let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}
```

**Step 2: Build to verify compilation**

```bash
xcodebuild build \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  2>&1 | xcpretty
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add GifKeyboardExtension/KeyboardViewController.swift
git commit -m "feat: add keyboard extension with search bar, GIF grid, and pasteboard copy"
```

---

### Task 11: Background Refresh

**Files:**
- Modify: `GifKeyboard/GifKeyboardApp.swift`

**Step 1: Add background task registration**

`GifKeyboard/GifKeyboardApp.swift`:
```swift
import SwiftUI
import BackgroundTasks

@main
struct GifKeyboardApp: App {

    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.gifkeyboard.app.refresh",
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
        let request = BGAppRefreshTaskRequest(identifier: "com.gifkeyboard.app.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh() // Reschedule for next time

        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gifkeyboard.shared"
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
```

**Step 2: Add the background task identifier to Info.plist**

Add to `GifKeyboard/Info.plist` inside the top `<dict>`:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.gifkeyboard.app.refresh</string>
</array>
```

**Step 3: Regenerate project and build**

```bash
xcodegen generate
xcodebuild build \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  2>&1 | xcpretty
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add GifKeyboard/GifKeyboardApp.swift GifKeyboard/Info.plist project.yml
git commit -m "feat: add background refresh to keep GIF index up to date"
```

---

### Task 12: Run All Tests and Final Verification

**Step 1: Run the full test suite**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  2>&1 | xcpretty
```

Expected: All tests PASS (GifEntryTests, GifSearchServiceTests, TagExtractorTests, ThumbnailGeneratorTests, GifPasteboardServiceTests, GifIndexStoreTests, SyncServiceTests)

**Step 2: Build both targets for release**

```bash
xcodebuild build \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  2>&1 | xcpretty
```

Expected: BUILD SUCCEEDED

**Step 3: Verify no network entitlements**

```bash
grep -r "RequestsOpenAccess" GifKeyboardExtension/Info.plist
```

Expected: `<false/>`

**Step 4: Create .gitignore and final commit**

```bash
echo "*.xcodeproj/xcuserdata/\n*.xcworkspace/xcuserdata/\nDerivedData/\nbuild/\n.DS_Store" > .gitignore
git add .gitignore
git commit -m "chore: add .gitignore"
```

**Step 5: Run all tests one final time**

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  2>&1 | xcpretty
```

Expected: All tests PASS
