# GIF Compression Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Pre-compress GIFs over 1 MB during sync so they display as inline animated GIFs in iMessage rather than file attachments.

**Architecture:** A new `GifCompressionService` uses `ImageIO` to spatially downscale oversized GIFs frame-by-frame, preserving all frames and timing. `SyncService` calls it after copying each GIF to the container, overwriting in place. No changes to `GifEntry`, the keyboard extension, or `GifPasteboardService`.

**Tech Stack:** Swift, ImageIO (`CGImageSource`, `CGImageDestination`, `CGContext`), XcodeGen (`project.yml` picks up new files automatically from folder sources)

---

### Task 1: Write failing tests for GifCompressionService

**Files:**
- Create: `GifKeyboardTests/GifCompressionServiceTests.swift`

**Step 1: Create the test file**

```swift
import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import GifKeyboard

final class GifCompressionServiceTests: XCTestCase {

    // MARK: - Threshold

    func testReturnsNilWhenBelowThreshold() {
        let data = makeGif(width: 10, height: 10, frameCount: 2)
        let result = GifCompressionService.compress(data: data, threshold: data.count + 1)
        XCTAssertNil(result)
    }

    func testReturnsDataWhenAboveThreshold() {
        let data = makeGif(width: 100, height: 100, frameCount: 3)
        let result = GifCompressionService.compress(data: data, threshold: 0)
        XCTAssertNotNil(result)
    }

    // MARK: - Output validity

    func testCompressedOutputIsValidGIF() {
        let data = makeGif(width: 100, height: 100, frameCount: 3)
        guard let result = GifCompressionService.compress(data: data, threshold: 0) else {
            return XCTFail("Expected non-nil result")
        }
        // GIF magic bytes: G I F
        XCTAssertEqual(result[0], 0x47)
        XCTAssertEqual(result[1], 0x49)
        XCTAssertEqual(result[2], 0x46)
    }

    func testFrameCountIsPreserved() {
        let data = makeGif(width: 100, height: 100, frameCount: 4)
        guard let result = GifCompressionService.compress(data: data, threshold: 0) else {
            return XCTFail("Expected non-nil result")
        }
        guard let source = CGImageSourceCreateWithData(result as CFData, nil) else {
            return XCTFail("Could not create image source from result")
        }
        XCTAssertEqual(CGImageSourceGetCount(source), 4)
    }

    func testDelayTimesArePreserved() {
        let delay = 0.15
        let data = makeGif(width: 100, height: 100, frameCount: 2, delayTime: delay)
        guard let result = GifCompressionService.compress(data: data, threshold: 0) else {
            return XCTFail("Expected non-nil result")
        }
        guard let source = CGImageSourceCreateWithData(result as CFData, nil) else {
            return XCTFail("Could not create image source from result")
        }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let gifDict = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let resultDelay = gifDict?[kCGImagePropertyGIFDelayTime] as? Double
        XCTAssertEqual(resultDelay ?? 0, delay, accuracy: 0.01)
    }

    func testCompressedDimensionsAreSmallerThanOriginal() {
        let data = makeGif(width: 100, height: 100, frameCount: 2)
        // target = 25% of original → scale ≈ 0.5 → dimensions ~50x50
        guard let result = GifCompressionService.compress(
            data: data, threshold: 0, target: data.count / 4
        ) else {
            return XCTFail("Expected non-nil result")
        }
        guard let source = CGImageSourceCreateWithData(result as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return XCTFail("Could not read compressed GIF")
        }
        XCTAssertLessThan(image.width, 100)
        XCTAssertLessThan(image.height, 100)
    }

    // MARK: - Helpers

    private func makeGif(width: Int, height: Int, frameCount: Int, delayTime: Double = 0.1) -> Data {
        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return Data() }

        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)

        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: delayTime
        ]] as CFDictionary

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        for i in 0..<frameCount {
            guard let ctx = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            let v = CGFloat(i) / CGFloat(max(frameCount - 1, 1))
            ctx.setFillColor(CGColor(red: v, green: 1 - v, blue: 0.5, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            if let img = ctx.makeImage() {
                CGImageDestinationAddImage(destination, img, frameProperties)
            }
        }
        CGImageDestinationFinalize(destination)
        return outputData as Data
    }
}
```

**Step 2: Run to verify tests fail**

```bash
./build.sh 2>&1 | grep -E "error:|GifCompressionService"
```
Expected: compile error — `GifCompressionService` not found.

---

### Task 2: Implement GifCompressionService

**Files:**
- Create: `Shared/Services/GifCompressionService.swift`

**Step 1: Create the implementation**

```swift
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum GifCompressionService {

    /// GIFs larger than this (bytes) will be compressed.
    static let defaultThreshold = 1_000_000  // 1 MB

    /// Target size in bytes after compression.
    static let defaultTarget = 800_000  // 800 KB

    /// Returns compressed GIF data, or nil if the input is already under `threshold`.
    /// Falls back to nil on any decode/encode failure (caller keeps the original).
    static func compress(
        data: Data,
        threshold: Int = defaultThreshold,
        target: Int = defaultTarget
    ) -> Data? {
        guard data.count > threshold else { return nil }

        let scale = sqrt(Double(target) / Double(data.count))

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        guard let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let newWidth  = max(1, Int(floor(Double(firstFrame.width)  * scale)))
        let newHeight = max(1, Int(floor(Double(firstFrame.height) * scale)))

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return nil }

        // Preserve loop count
        if let sourceProps = CGImageSourceCopyProperties(source, nil) {
            CGImageDestinationSetProperties(destination, sourceProps)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        for i in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }

            // Preserve per-frame delay
            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gifDict = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gifDict?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                     ?? gifDict?[kCGImagePropertyGIFDelayTime] as? Double
                     ?? 0.1

            guard let ctx = CGContext(
                data: nil, width: newWidth, height: newHeight,
                bitsPerComponent: 8, bytesPerRow: newWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            ctx.draw(frame, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

            guard let scaled = ctx.makeImage() else { continue }

            CGImageDestinationAddImage(destination, scaled, [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]
            ] as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputData as Data
    }
}
```

**Step 2: Run tests**

```bash
./build.sh 2>&1 | tail -20
```
Expected: all `GifCompressionServiceTests` pass.

**Step 3: Commit**

```bash
git add Shared/Services/GifCompressionService.swift GifKeyboardTests/GifCompressionServiceTests.swift
git commit -m "feat: add GifCompressionService to downscale large GIFs"
```

---

### Task 3: Integrate compression into SyncService

**Files:**
- Modify: `Shared/Services/SyncService.swift`

The change goes in the "Add new GIFs" loop, after `fileManager.copyItem` and before thumbnail generation.

**Step 1: Write the failing test first**

Add to `GifKeyboardTests/SyncServiceTests.swift` (inside the class, after `testSyncIgnoresNonGifFiles`):

```swift
func testSyncStoresFileSizeMatchingContainerFile() throws {
    createTestGif(at: sourceDir.appendingPathComponent("test.gif"))

    _ = try syncService.sync()

    let store = GifIndexStore(containerURL: containerDir)
    let entries = try store.load()
    XCTAssertEqual(entries.count, 1)

    let containerGifURL = containerDir.appendingPathComponent("gifs/test.gif")
    let attrs = try FileManager.default.attributesOfItem(atPath: containerGifURL.path)
    let actualSize = attrs[.size] as? Int64 ?? 0
    XCTAssertEqual(entries[0].fileSize, actualSize)
}
```

**Step 2: Run to verify it passes already (baseline)**

```bash
./build.sh 2>&1 | grep -E "testSyncStoresFileSize|PASS|FAIL"
```
Expected: PASS — this verifies the invariant we're about to maintain.

**Step 3: Modify SyncService.swift**

Replace the block starting at `let resourceValues` through the `GifEntry` initializer (lines ~44–78). Change:

```swift
let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
let fileSize = Int64(resourceValues.fileSize ?? 0)
```

to:

```swift
let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
let sourceFileSize = Int64(resourceValues.fileSize ?? 0)
```

Then, after `try fileManager.copyItem(at: fileURL, to: destGifURL)` (and before thumbnail generation), add:

```swift
// Compress large GIFs in place — fall back to original on any failure
var effectiveFileSize = sourceFileSize
if let gifData = try? Data(contentsOf: destGifURL),
   let compressed = GifCompressionService.compress(data: gifData) {
    if (try? compressed.write(to: destGifURL, options: .atomic)) != nil {
        effectiveFileSize = Int64(compressed.count)
    }
}
```

Then update the `GifEntry` initializer to use `effectiveFileSize`:

```swift
let entry = GifEntry(
    filename: filename,
    tags: tags,
    thumbnailPath: "thumbnails/\(thumbFilename)",
    gifPath: "gifs/\(filename)",
    fileSize: effectiveFileSize,
    dateAdded: Date()
)
```

**Step 4: Run all tests**

```bash
./build.sh 2>&1 | tail -30
```
Expected: all tests pass (28 existing + new compression tests).

**Step 5: Commit**

```bash
git add Shared/Services/SyncService.swift GifKeyboardTests/SyncServiceTests.swift
git commit -m "feat: compress large GIFs during sync to improve iMessage inline display"
```

---

### Task 4: Push and verify

**Step 1: Push to remote**

```bash
git push
```

**Step 2: Manual verification checklist**

- Open the GifKeyboard companion app → Tap "Sync Now"
- Find a GIF that was previously showing as a file in iMessage
- Check its file size in the GIF grid (should be smaller)
- Copy and paste into iMessage — should appear as inline animated GIF
