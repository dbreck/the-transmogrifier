# Export workflows

Implemented on `codex/export-workflows`, September 8, 2026. This is an unreleased development update.

## Export behavior

- **Quality** directly controls the encoder. New settings start at 80%; existing presets retain their stored encoder quality. PNG is lossless and has no quality slider.
- **File-size limits** use decimal KB (200 KB = 200,000 bytes) and apply to each output. The encoder searches between the selected quality and the minimum quality, keeping only results within the budget. Dimensions remain governed by the explicit caps. An unreachable limit returns an error and writes no file for that output. PNG checks its lossless result against the limit.
- **Responsive packs** create WebP variants at up to eight widths, optionally with matching JPG files. Original orientation, maximum dimensions and no-upscale behavior determine actual widths. Duplicate capped sizes are exported once. Names require `{name}` and `{width}`; width describes the actual output.
- **Destinations** are explicit. Output-folder mode requires a folder and write access. Choose it through Browse and save the preset to retain its macOS permission. Beside-originals mode may request access to source folders. Existing originals are protected even with Overwrite, including paths resolving through symlinks; concurrently planned outputs reserve distinct names.
- **Cancellation** waits for workers to settle, retains completed files and records unstarted outputs. Retry unfinished uses those output identities instead of repeating successful variants. Pause waits asynchronously and cancellation also works while paused.

## Preview and interface

The preview refreshes after a short debounce when relevant settings or the selected file change. Its bounded cache stores the actual encoded byte count with the image. Request identities reject stale results, errors appear inline, and clearing the selection clears the preview. For packs, the preview represents the largest primary-format variant.

Compare provides a shared wipe, zoom, scrolling, 100% inspection and checkerboard/white/black backgrounds. The main window supports a 1000 × 680 content area, collapses the import region after selection, and keeps the export action visible while settings scroll. Keyboard actions: Command-O adds images, Command-Return exports, Shift-Command-R refreshes the preview.

## History, presets and Finder

History stores whole jobs with settings, source paths, relative folders, output results and access bookmarks. It supports search, Reveal outputs, Reuse settings, Run again, Retry unfinished and Copy srcset. Savings compare the sum of written outputs with each contributing source counted once. Srcset uses URL-escaped filenames and actual widths, with a separate block per original and format; supply the appropriate deployed path when integrating it into a website.

Legacy file history appears under Earlier conversions, with rerun disabled because old records did not retain settings. The original UserDefaults history remains available. New history is atomically written to Application Support/The Transmogrifier/history-v2.json once per batch. Retention is at most 100 jobs or approximately 10,000 output records, keeping the most recent job whole. A corrupted history file is preserved and a visible error prevents silent replacement.

Choose an optional Dock quick-convert preset in Advanced. Finder/Dock file-open requests use the saved recipe and destination; the default is Open for review. SwiftUI's URL callbacks collect a multi-file request into one queue entry. Built-in preset IDs are stable across launches. Moved or inaccessible folders require choosing them again. A selected preset's collision policy applies to automatic exports too.

## Verification completed

- Debug build with sandbox entitlements and a separate `app.thetransmogrifier.review` identity; unsigned Release build.
- Eleven integration-check groups in `scripts/check-export-workflows.sh`: actual WebP byte budgets, unreachable budgets and PNG, responsive dimensions/JPG/source protection, collision policies and precise retries, paused cancellation, mid-batch cancellation, preview cache/clear/stale results, old and new presets/input validation, file-opening queue/coalescing, duplicate basenames/orientation, and history migration/persistence/srcset.
- Native UI: six-output 640/1280/1920 WebP/JPG pack under a 200 KB per-file limit; history and folder access after restart; repeat job with Rename; comparison at 100%; explicit invalid destination and unreachable-budget feedback; minimum window layout with scrollable settings and visible export action.
- Finder Open With from a cold launch restored a saved preset and folder access, then wrote all six outputs successfully. This exercises the OS file-open route used by Dock drops; a physical drag onto the Dock icon was not separately tested.

The installed production application was not replaced. Test samples, exports and review-app preferences use a separate local environment.

## Before distribution

Perform the normal signed/notarized release procedure, supported-macOS and Intel smoke checks, and a large-photo memory/throughput check. No performance improvement percentage is claimed. AVIF, watch folders, CLI, crop/fill, explicit color/metadata policy and additional Finder/Shortcuts actions remain future work.
