# Alternate App Icons Design

**Date:** 2026-02-22
**Status:** Approved

## Overview

Allow users to choose from 4 app icons (Icon 1 is the default). Icons are selected via a new Settings screen in the main app.

## Icon Assets

Source: 4 SVG files in the repo root (`Icon 1.svg` – `Icon 4.svg`).

Convert using `rsvg-convert` to PNG at:
- `120x120` (60pt @2x)
- `180x180` (60pt @3x)

Naming convention:
- Default: `AppIcon@2x.png`, `AppIcon@3x.png` (Icon 1)
- Alternates: `AppIcon2@2x.png`, `AppIcon2@3x.png` (Icon 2), etc.

All PNGs placed in `GifKeyboard/` so they are bundled in the app target.

The primary icon also needs a 1024x1024 PNG for the App Store marketing icon, placed in `Assets.xcassets/AppIcon.appiconset`.

## Info.plist Configuration

Declared in `project.yml` under the `GifKeyboard` target's `info.properties`:

```yaml
CFBundleIcons:
  CFBundlePrimaryIcon:
    CFBundleIconFiles:
      - AppIcon
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
```

## Settings UI

- Add a gear toolbar button to `ContentView` (primary action or trailing placement)
- New `SettingsView` presented as a sheet
- App Icon section: 2×2 grid of icon previews, each showing the icon image with its name
- Active icon gets a checkmark overlay
- Tapping calls `UIApplication.shared.setAlternateIconName(nil)` for default or `"AppIcon2"` etc. for alternates
- Icon images loaded from the bundle via `UIImage(named:)`

## Testing

- Unit test: verify icon name constants compile and are non-empty strings
- Manual: verify switching icons works on simulator and device
