# The Transmogrifier

A native macOS app for preparing images for the web. Convert, resize and inspect images locally, then save repeatable export recipes.

[Download the current release](https://github.com/dbreck/the-transmogrifier/releases/latest) · [Website](https://thetransmogrifier.app)

Requires macOS 12 or later. Built with SwiftUI, Core Image, ImageIO and bundled libwebp.

## Version 1.2.0: export workflows

Version 1.2.0 adds repeatable export recipes and clearer output controls:

- Automatic before/after previews with accurate encoded sizes, shared zoom, a comparison slider and transparency backgrounds.
- A direct Quality slider. Existing saved presets retain their previous encoder quality; PNG remains lossless.
- Optional file-size limits with a minimum quality. Unreachable limits produce an actionable error without writing a file.
- Responsive WebP packs with custom widths, `{name}-{width}` naming and optional JPG fallbacks. Small images are not enlarged and duplicate capped sizes are exported once.
- Explicit destinations: beside originals or a chosen folder. No silent fallback from an empty output-folder field.
- Searchable batch history with saved settings, Reveal outputs, Reuse settings, Run again, retry unfinished outputs and Copy srcset.
- Keyboard shortcuts: **⌘O** add images, **⌘Return** process, **⇧⌘R** refresh preview.
- Optional Dock quick conversion using a designated saved preset. Without a designated preset, dropped files open for review.

Recursive folder imports remain opt-in. Folder preservation, overwrite/skip/rename, pause/resume and cancellation are supported. Completed outputs from cancelled jobs stay in History; unfinished variants can be retried separately.

## Typical workflow

1. Add images or folders. Select an image for a live preview.
2. Choose format, maximum pixel dimensions and quality in the right panel.
3. Optionally enable a size limit or responsive pack.
4. Select a destination and click **Process Images**.
5. Open **History** to inspect output results or reuse the job.

**Advanced** contains DPI, collision rules, folder preservation and the Dock quick-convert preset selector. Save a preset after choosing your intended destination. Folder permissions are retained using macOS security-scoped bookmarks where available; moved files or revoked permissions may require choosing their folder again.

## Build and verify

```sh
xcodebuild -project ImageProcessingApp.xcodeproj -scheme 'The Transmogrifier' -configuration Debug build
./scripts/check-export-workflows.sh
```

The check script builds the bundled encoder if needed, compiles a standalone Swift integration harness and runs against generated disposable fixtures. It checks actual byte limits, dimensions, collision protection, variant retries, cancellation, preview cache correctness, preset compatibility and history persistence.

See [export workflow notes](docs/export-workflows.md) for behavior, verification and remaining release checks. See [RELEASING.md](RELEASING.md) for distribution.

## Later candidates

AVIF, watch folders, a CLI, explicit metadata/color-profile controls, and exact crop/fill modes remain future work.
