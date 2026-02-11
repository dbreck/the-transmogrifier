# Performance Audit Notes (The Transmogrifier)

## Summary
- The slow “start processing” behavior is very likely a combination of Debug-build overhead and main-thread UI/image I/O.
- There are several real code-level bottlenecks that should be fixed regardless of build config.

## Findings (Ordered by Likely Impact)
1) **Forced software rendering for all processing**
- File: `ImageProcessingApp/Services/ImageProcessingEngine.swift`
- `CIContext` is created with `.useSoftwareRenderer = true` unconditionally.
- This disables GPU/Metal and can be dramatically slower for large images.

2) **Synchronous image decode and file metadata in SwiftUI view body**
- File: `ImageProcessingApp/Views/ContentView.swift`
- In `SelectedFileCard`, the body reads:
  - `NSImage(contentsOf:)`
  - `FileManager.default.attributesOfItem`
- SwiftUI re-renders frequently; this can repeatedly decode large images on the main thread and stall UI.

3) **Heavy work likely running on the main actor in preview pipeline**
- File: `ImageProcessingApp/ViewModels/PreviewViewModel.swift`
- The class is `@MainActor`. `Task { ... }` inherits the main actor, so:
  - `NSImage(contentsOf:)`
  - `engine.processImage`
  - disk writes
  - image decode
  can all execute on the main actor, causing UI stalls.

4) **Preview path does extra disk I/O**
- File: `ImageProcessingApp/ViewModels/PreviewViewModel.swift`
- `processPreview` writes `imageData` to a temp file, then reads it back with `NSImage(contentsOf:)`.
- Can be replaced with `NSImage(data:)` and `imageData.count` without disk I/O.

5) **Unbounded concurrency in batch processing**
- File: `ImageProcessingApp/Services/ImageProcessingEngine.swift`
- `withTaskGroup` spawns one task per file with no concurrency limit.
- On large batches this can saturate CPU/memory and slow overall throughput.

6) **WebP capability check in SwiftUI body**
- File: `ImageProcessingApp/Views/ProcessingSettingsView.swift`
- `ImageProcessingEngine.isWebPEncodingAvailable()` runs in the view body and can be called often.
- Cache this result once.

7) **Folder enumeration and selection updates on the main thread**
- File: `ImageProcessingApp/Views/FileSelectionView.swift`
- `addImagesFromFolder` enumerates on the main thread and updates `selectedFiles` inside the loop.
- This can stall UI and trigger many re-renders.

## Debug vs Release Notes
- Debug build uses `SWIFT_OPTIMIZATION_LEVEL = -Onone`, `GCC_OPTIMIZATION_LEVEL = 0`.
- Release build uses `-Owholemodule` and no debug Metal info.
- Debug (and any enabled sanitizers) can create large slowdowns in image-heavy workloads.
- File: `ImageProcessingApp.xcodeproj/project.pbxproj`

## Recommended First Checks
1) Run the same image through a Release build (or Archive) and compare timing.
2) Use Instruments (Time Profiler) or add signposts to measure decode/transform/encode/write times.
3) Fix the main-thread work in views and preview pipeline.

## Suggested Fixes (If You Want Me to Implement)
- Move metadata/thumbnail generation off the main thread and cache results.
- Remove disk I/O from preview (use `NSImage(data:)`, `imageData.count`).
- Use GPU `CIContext` by default with a fallback to software if needed.
- Add a concurrency limit to batch processing (e.g. max 2–4 tasks).

---

## Release Ops Note (2026-02-09)
- `master` was pushed with release commit: `347582f`
- Git tag and release published: `v1.1.0`
- Release URL: `https://github.com/dbreck/the-transmogrifier/releases/tag/v1.1.0`
- Current release DMG asset: `The.Transmogrifier.1.1.0.dmg`
- Current release DMG SHA256: `24b2afdcf92a44629494379bc4dca3ec461360fe3589e2bfd97eff258a99bd1f`

### Notarization Incident
- Multiple submissions are stuck in `In Progress` far longer than normal:
  - `8c3aa64a-0720-43ec-9ad2-4446b344864d` (The.Transmogrifier.1.1.0.dmg)
  - `44f12813-61a4-43f8-91a5-e5d6927d94a4` (The.Transmogrifier.1.1.0.dmg)
  - older ScreenShawty submission IDs are also stuck
- Apple Developer System Status feed reports no active event for "Developer ID Notary Service".
- Support escalation was sent to Apple Developer Support on 2026-02-09.

### Next Action
- As soon as any submission flips to `Accepted`:
  1. Staple the ticket to `The.Transmogrifier.1.1.0.dmg`
  2. Validate stapling
  3. Re-upload notarized DMG to `v1.1.0` GitHub release

---

## Release Ops Note (2026-02-11)
- Added UX behavior change: default `includeSubfolders` is now OFF.
  - Commit: `c5187f8` (`Default include-subfolders toggle to off`)
- Cut and published release `v1.1.1`.
  - Release commit: `6897660` (`Release 1.1.1`)
  - Release URL: `https://github.com/dbreck/the-transmogrifier/releases/tag/v1.1.1`
  - DMG asset: `The.Transmogrifier.1.1.1.dmg`
  - DMG SHA256: `379ccd7aeeb943ed8a69677b1808c6e90cf9deba97649afd8b36a653aebee34d`
- Notarization completed successfully.
  - Submission ID: `caebaeae-2c4b-41ff-9374-50da37621ac4`
  - Status: `Accepted`
  - Stapling/validation: succeeded
- Local app install updated to `/Applications/The Transmogrifier.app` version `1.1.1` build `4`.
- App Store Connect ops:
  - Apps Agreement issue was resolved by account holder.
  - Uploaded archive `build/TheTransmogrifier-1.1.1.xcarchive` to App Store Connect (upload succeeded; processing started).
  - User then submitted the new version for review in App Store Connect.
- Screenshot compliance note:
  - App Store rejected `1400x900` screenshots (invalid size).
  - Generated valid `1440x900` variants at:
    - `Screenshots/1.1.1/appstore-1440x900/`
