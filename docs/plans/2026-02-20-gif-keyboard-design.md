# GifKeyboard Design

A privacy-first iOS GIF keyboard with zero network access. GIFs are managed via an iCloud Drive folder and searched by filename and macOS Finder tags.

## Architecture

Two targets in one Xcode project:

- **GifKeyboard (iOS App)** — Companion app that syncs GIFs from iCloud Drive to a shared App Group container. Generates thumbnails. Extracts and indexes Finder tags.
- **GifKeyboardExtension (Custom Keyboard Extension)** — Reads thumbnails and metadata from the App Group container. Displays a searchable grid. On selection, copies the full GIF to the pasteboard.

### Data Flow

```
iCloud Drive folder ("GifKeyboard/")
        │
        ▼
  Companion App (sync)
   ├── reads GIF files
   ├── extracts Finder tags (tagNamesKey or getxattr fallback)
   ├── generates thumbnail (first frame, scaled down)
   └── writes to App Group shared container:
        ├── thumbnails/
        ├── gifs/
        └── index.json
        │
        ▼
  Keyboard Extension (read-only)
   ├── reads index.json + thumbnails for grid
   ├── search filters by filename + tags
   └── copies selected full GIF to UIPasteboard
```

## Data Model

`index.json` in the App Group container:

```json
[
  {
    "filename": "mind-blown.gif",
    "tags": ["reaction", "funny"],
    "thumbnailPath": "thumbnails/mind-blown.jpg",
    "gifPath": "gifs/mind-blown.gif",
    "fileSize": 245760,
    "dateAdded": "2026-02-20T12:00:00Z"
  }
]
```

- Thumbnails: JPEG of first frame, ~150px wide
- Search: case-insensitive substring match against filename and tags
- No database — JSON is sufficient for a personal collection

## Companion App

### Screens

- **Main screen**: Sync status (last synced, GIF count), manual "Sync Now" button, preview grid
- **Setup screen** (first launch): Requests iCloud access, explains folder location, walks through enabling the keyboard in Settings

### Sync Logic

- Runs on app launch and via `BGAppRefreshTask`
- Enumerates iCloud Drive `GifKeyboard/` folder
- For each GIF:
  - Skips if already indexed (matched by filename + file size)
  - Extracts Finder tags via `URLResourceKey.tagNamesKey`, fallback to `getxattr` for `com.apple.metadata:_kMDItemUserTags`
  - Generates JPEG thumbnail from first frame via `CGImageSourceCreateThumbnailAtPixelSize`
  - Copies full GIF to App Group `gifs/` directory
- Removes index entries for GIFs no longer in iCloud folder
- Writes updated `index.json`
- No network calls

## Keyboard Extension

### Layout

- Search bar at top — filters by filename and tags
- Scrollable grid below — 3-4 columns, sorted by most recently added
- Tap to copy full GIF to `UIPasteboard.general` with `com.compuserve.gif` UTI

### Constraints

- ~30MB memory limit; thumbnails keep usage well under this
- `RequestsOpenAccess = false` — no network, no tracking
- Loads index.json into memory on keyboard open
- GIF-only — no text keyboard, users switch back for typing

### Privacy Guarantees

- No recents/favorites tracking
- No analytics
- No network access
- No keylogging

## Technology

- Swift + SwiftUI
- iOS deployment target: current (iOS 17+)

## Testing Strategy

- **Sync logic**: Mock iCloud folder with known GIFs, verify index.json correctness, thumbnail creation, deletion detection
- **Tag extraction**: Verify Finder tags are read correctly, test `getxattr` fallback path
- **Search filtering**: Filename and tag matching, case insensitivity, partial matches
- **Pasteboard format**:
  - Data written with `com.compuserve.gif` UTI type
  - GIF data is valid (starts with `GIF89a` magic bytes, contains multiple frames)
  - Data round-trips correctly (write to pasteboard, read back, verify byte-identical)
  - No unintended type conversions (raw `Data`, not re-encoded via `UIImage`)
- **Companion app UI**: Sync button triggers sync, setup flow works
- **Keyboard extension**: Manual testing for grid display, search, pasteboard copy
