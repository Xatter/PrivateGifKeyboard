# GIF Compression Design

**Date:** 2026-02-22
**Status:** Approved

## Problem

Large GIFs (>1 MB) sent via the keyboard appear as file attachments in iMessage rather than inline animated GIFs. iMessage treats large pasted GIFs as files when sending.

## Solution

Pre-compress oversized GIFs at sync time in the companion app, so the keyboard always reads a size-optimised copy from the container. Zero latency at copy time. Quality is maximised because compression runs with no time pressure.

## Architecture

- New `GifCompressionService` in `Shared/Services/`
- `SyncService` calls it after copying each GIF to the container
- If over threshold, the container copy is overwritten with the compressed version **in place**
- `GifEntry`, `GifPasteboardService`, and the keyboard extension need no changes
- `GifEntry.fileSize` stores the post-compression size

## GifCompressionService

**Threshold:** 1 MB (1,000,000 bytes) — GIFs under this are untouched.
**Target size:** 800 KB (800,000 bytes) — leaves headroom below iMessage's inline limit.

### Algorithm (single-pass spatial downscale via ImageIO)

1. Check file size — return `nil` if under threshold (no-op)
2. Calculate scale factor: `sqrt(800_000 / fileSize)` — adaptive per-GIF
3. Read all frames + per-frame delay times via `CGImageSource`
4. Scale each frame via `CGContext` to `floor(width * scale) × floor(height * scale)`
5. Re-encode to GIF data via `CGImageDestination` preserving all frame delay times
6. Return compressed `Data`

For a 1.9 MB GIF: scale ≈ 0.65× (65% of dimensions, 42% of pixels), targeting ~800 KB.
All frames and timing are preserved — only pixel dimensions change.

### Signature

```swift
enum GifCompressionService {
    static func compress(data: Data) -> Data?
}
```

Returns `nil` if the GIF is under threshold or if compression fails.

## SyncService Changes

After `fileManager.copyItem(at:to:)`:
1. Read the copied file's data
2. Call `GifCompressionService.compress(data:)`
3. If non-nil, overwrite `destGifURL` with compressed data
4. Use post-compression file size when constructing `GifEntry`

On any compression error: log and continue with original file (never drop the GIF).

## Error Handling

- Compression failure → keep original uncompressed file, continue sync
- Corrupt GIF frames → skip compression, keep original
- Memory pressure → Swift will throw; catch and keep original

## Testing

- GIF over 1 MB is compressed to under 1 MB
- GIF under 1 MB is returned unchanged (`nil`)
- Frame count is preserved after compression
- Per-frame delay times are preserved after compression
- Compressed output is valid GIF data (decodable via `CGImageSource`)
- `SyncService` stores post-compression `fileSize` in `GifEntry`
