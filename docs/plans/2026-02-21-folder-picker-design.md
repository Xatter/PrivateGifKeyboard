# Folder Picker Design

**Date:** 2026-02-21

## Problem

The app previously used an app-specific iCloud container (`iCloud~com~extroverteddeveloper~GifKeyboard`) as the GIF source directory. This location is opaque to users — it doesn't appear as a normal folder in Finder's iCloud Drive sidebar without special steps. Users wanted to be able to open Finder, navigate to iCloud Drive, and drop GIFs into a visible folder.

## Solution

Replace the hardcoded ubiquity container path with a `UIDocumentPickerViewController` folder picker. The user picks any folder (iCloud Drive or otherwise) once during setup. The app stores a security-scoped bookmark in `UserDefaults` and uses it for all subsequent syncs.

## Architecture

### New file: `FolderPickerView.swift`
`UIViewControllerRepresentable` wrapping `UIDocumentPickerViewController` configured for `.folder` content type, single selection. Calls `onFolderSelected(URL)` when the user picks a folder.

### `AppViewModel` changes
- Remove `iCloudURL: URL?` (hardcoded ubiquity container path)
- Add `hasFolderSelected: Bool` — computed from presence of bookmark in `UserDefaults`
- Add `selectFolder(_ url: URL)` — starts security-scoped access, creates bookmark, saves to `UserDefaults`
- Add `resolvedFolderURL() -> URL?` — resolves bookmark, refreshes if stale
- `syncNow()` — resolves folder URL, calls `startAccessingSecurityScopedResource()` before sync, `stopAccessingSecurityScopedResource()` after
- Bookmark stored in standard `UserDefaults` (main app only; extension never needs source folder)

### `SetupView` changes
- Replace static iCloud-specific instructions with a "Choose GIF Folder" primary button
- Button presents `FolderPickerView` as a sheet
- On folder selection: calls `viewModel.selectFolder()` then `viewModel.completeSetup()`
- Retain "Add GifKeyboard in Settings" as an informational step below

### `ContentView` changes
- Gate on `viewModel.hasFolderSelected` instead of `viewModel.hasCompletedSetup`
- Existing `.task { await viewModel.syncNow() }` covers auto-sync on app open

### `GifKeyboardApp` background refresh
- Load bookmark from `UserDefaults`, resolve URL, use security-scoped access around sync

### Entitlements / Info.plist cleanup
- Remove `com.apple.developer.icloud-container-identifiers` from entitlements
- Remove `com.apple.developer.ubiquity-container-identifiers` from entitlements
- Remove `NSUbiquitousContainers` from `Info.plist`
- Keep `com.apple.security.application-groups` (still needed for keyboard extension sharing)

## Auto-sync
Sync runs automatically on app open via the existing `.task` modifier in `ContentView`. Background refresh also auto-syncs via `BGTaskScheduler`.
