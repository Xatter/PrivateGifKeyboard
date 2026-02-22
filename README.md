# GifKeyboard

A privacy-first iOS GIF keyboard that reads from your iCloud Drive. Zero network access, zero tracking, zero data collection.

## Features

- 🔒 **100% Private** — No network code in the keyboard extension. Full access is required only to write GIFs to the system pasteboard, not for network access.
- 📁 **iCloud Drive Based** — Just drop GIFs into a folder, no server needed
- 🔍 **Smart Search** — Search by filename or macOS Finder tags
- ⚡ **Fast & Lightweight** — Thumbnails cached locally, ~30MB memory limit
- 🎨 **Animation Preserved** — GIFs paste correctly into iMessage, Threads, Twitter, etc.

## How It Works

1. You create a `GifKeyboard` folder in iCloud Drive
2. You add GIF files to that folder (on Mac or iPhone)
3. The companion app syncs GIFs to a local cache with thumbnails
4. The keyboard extension reads from the cache (no iCloud access needed during typing)
5. Tap a GIF to copy it to the pasteboard — it pastes as an animated GIF

## Setup

### Prerequisites

- iOS 17.0 or later
- Xcode 16.0 or later
- iCloud Drive enabled
- Development team for code signing

### Building & Installing

1. **Clone and open the project:**
   ```bash
   git clone https://github.com/Xatter/PrivateGifKeyboard.git
   cd PrivateGifKeyboard
   xcodegen generate
   open GifKeyboard.xcodeproj
   ```

2. **Set your development team:**
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Set your Team ID for both `GifKeyboard` and `GifKeyboardExtension` targets

3. **Build and deploy:**
   ```bash
   # Update DEVICE_UDID and TEAM_ID in deploy.sh first
   ./deploy.sh
   ```

   Or build for simulator:
   ```bash
   ./build.sh
   ```

### Adding GIFs

**On Mac:**

1. Open **Finder**
2. Go to **iCloud Drive** (in the sidebar)
3. Create a folder named `GifKeyboard`
4. Drop your GIF files into this folder
5. (Optional) Tag your GIFs with Finder tags like "reaction", "funny", "work"
   - Right-click a GIF → Tags → add tags
   - Tags become searchable in the keyboard

**On iPhone:**

1. Open the **Files** app
2. Tap **Browse** → **iCloud Drive**
3. Create a folder named `GifKeyboard` (tap the ••• menu → New Folder)
4. Add GIFs by:
   - Saving from Safari/Messages/etc. to Files → iCloud Drive/GifKeyboard
   - Using the share sheet from Photos → Save to Files → GifKeyboard
   - AirDrop from Mac → Save to iCloud Drive/GifKeyboard

### Enabling the Keyboard

1. Open the **GifKeyboard** app on your iPhone
2. Complete the setup walkthrough
3. Tap **Sync Now** to import your GIFs
4. Go to **Settings** → **General** → **Keyboard** → **Keyboards** → **Add New Keyboard**
5. Select **GifKeyboard**
6. (Optional) Tap **Edit** to reorder keyboards (put GifKeyboard near the top)

### Using the Keyboard

1. Open any app (Messages, Twitter, Threads, etc.)
2. Tap the 🌐 globe icon to switch to **GifKeyboard**
3. Search for a GIF or scroll through the grid
4. Tap a GIF to copy it
5. Tap the 🌐 globe icon to switch back to your regular keyboard
6. Paste (long-press text field → Paste)

## Project Structure

```
GifKeyboard/
├── GifKeyboard/                    # Companion app (SwiftUI)
│   ├── Views/                      # SetupView, GifGridView
│   ├── ViewModels/                 # AppViewModel
│   └── GifKeyboardApp.swift        # Entry point + background refresh
├── GifKeyboardExtension/           # Keyboard extension (UIKit)
│   └── KeyboardViewController.swift
├── Shared/                         # Code shared between app and extension
│   ├── Models/
│   │   └── GifEntry.swift          # Data model
│   └── Services/
│       ├── GifSearchService.swift  # Search filtering
│       ├── GifIndexStore.swift     # JSON persistence
│       ├── GifPasteboardService.swift  # Pasteboard copy
│       ├── SyncService.swift       # Sync orchestration
│       ├── TagExtractor.swift      # Finder tag extraction
│       └── ThumbnailGenerator.swift    # JPEG thumbnail generation
├── GifKeyboardTests/               # Unit tests (28 tests, all passing)
└── docs/plans/                     # Design and implementation docs
```

## Architecture

### Data Flow

```
macOS Finder tags → iCloud Drive/GifKeyboard/*.gif
                            ↓
                    (Companion App syncs)
                            ↓
            App Group Container (local cache)
            ├── gifs/           (full GIFs)
            ├── thumbnails/     (JPEG previews)
            └── index.json      (metadata + tags)
                            ↓
                    (Keyboard Extension reads)
                            ↓
                    Search & Display Grid
                            ↓
                    Tap → Copy to Pasteboard
```

### Privacy Guarantees

- **No network access** — Full access is requested only to write GIFs to `UIPasteboard.general`. The keyboard extension contains no network code.
- **No keylogging** — The keyboard never sees what you type in other apps
- **No analytics** — No telemetry, no crash reporting, no tracking
- **No recents tracking** — We don't log which GIFs you use
- **Local-only** — All data stays on your device and your iCloud

## Development

### Running Tests

```bash
./build.sh
```

Or manually:

```bash
xcodebuild test \
  -project GifKeyboard.xcodeproj \
  -scheme GifKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```

**Test Coverage:** 28 tests covering:
- JSON serialization (GifEntry model)
- Search filtering (filename + tag matching)
- Finder tag extraction (with color suffix stripping)
- Thumbnail generation (first frame, scaled JPEG)
- Pasteboard service (animation preservation, byte-identical round-trip)
- Index persistence (save/load, empty state handling)
- Sync service (add/remove/skip logic)

### Background Sync

The companion app registers a `BGAppRefreshTask` that runs approximately every hour (when the device is idle). This keeps the keyboard's GIF index up to date without requiring you to manually open the app.

To test background refresh in the simulator:
```bash
# Schedule a background task immediately
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.gifkeyboard.app.refresh"]
```

## Troubleshooting

**GIFs aren't showing up in the keyboard:**
- Open the GifKeyboard app and tap "Sync Now"
- Check that the `GifKeyboard` folder exists in iCloud Drive
- Make sure GIF files have the `.gif` extension (case-insensitive)

**Keyboard doesn't appear in Settings:**
- Rebuild and reinstall the app
- Make sure you selected a development team in Xcode signing settings

**GIFs paste as static images:**
- This shouldn't happen — our tests verify animation preservation
- If it does, please file an issue with the app you're pasting into

**Search isn't finding my GIFs:**
- Search matches filename (including extension) and Finder tags
- Try typing part of the filename without the extension
- Check that tags are set correctly in Finder (right-click → Tags)

## License

MIT License — see LICENSE file for details.

## Credits

Built with:
- Swift + SwiftUI (companion app)
- UIKit (keyboard extension)
- ImageIO framework (GIF handling)
- BackgroundTasks framework (automatic sync)
- XcodeGen (project generation)

Design philosophy: Privacy-first, local-first, no servers, no tracking.
