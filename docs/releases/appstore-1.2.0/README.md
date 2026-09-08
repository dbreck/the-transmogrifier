# Mac App Store 1.2.0

App Store Connect app: `6758575017`

Bundle: `app.thetransmogrifier`

Team: `7DMXWUCLVN`

Version: **1.2.0 (6)**

Uploaded September 8, 2026 at 3:48 PM EDT.

Build ID: `db04dce4-44fc-4dd5-b940-e9a4d2ad0d8e`.

[App Store Connect](https://appstoreconnect.apple.com/apps/6758575017/distribution)

The universal arm64/x86_64 Release archive was created from `aa4d177`, with automatic signing and the existing sandbox entitlements. The application signature passed strict verification. Xcode accepted and uploaded the package using cloud-managed distribution signing. The build processed successfully and was selected for version 1.2.0. Encryption declaration: none of the listed proprietary or independently implemented standard encryption algorithms.

## Reproduce the archive and upload

Run from the repository root with the authorized Apple developer account signed into Xcode. Use a fresh archive path for future releases.

```sh
xcodebuild archive \
  -project ImageProcessingApp.xcodeproj \
  -scheme "The Transmogrifier" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/TheTransmogrifier-1.2.0-AppStore.xcarchive \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath build/TheTransmogrifier-1.2.0-AppStore.xcarchive \
  -exportOptionsPlist docs/releases/appstore-1.2.0/ExportOptions.plist \
  -exportPath build/AppStore-1.2.0 \
  -allowProvisioningUpdates
```

The second command uploads directly. Do not rerun it for the already uploaded build 6. Archives and distribution logs remain local; this directory contains no credentials or signing keys.

## Listing and screenshots

`metadata.json` preserves the English (U.S.) promotional text, description, release notes and reviewer instructions. Existing keywords, support/marketing URLs, review contact, pricing and ratings are retained. Release is automatic after approval, to all users immediately.

The two 1440 × 900 JPEG screenshots replace the four old-interface screenshots. Their layouts reuse the website's Instrument Serif/DM Sans typography and paper/ink/vermilion palette. Both include actual CUA captures from the isolated review app running the released export-workflow implementation. The botanical input and its provenance are recorded in `docs/design/2026-09-studio-website.md`.

To reproduce the artwork, serve the repository root locally, open the HTML files at a 1440 × 900 browser viewport, wait for fonts and images, and capture through CUA. The `app-*.jpg` files are unmodified native-window captures. The observed 2.2 MB to 67 KB result is specific to that sample image.

## Status

**Waiting for Review**, verified September 8, 2026 at 4:04 PM EDT.

Submission ID: `f788daca-06b7-40e6-ae1d-fa3de83c082d`.

[Review submission](https://appstoreconnect.apple.com/apps/6758575017/distribution/reviewsubmissions/details/f788daca-06b7-40e6-ae1d-fa3de83c082d)

Apple accepted both screenshots and version 1.2.0 (6). A stalled budget-screenshot placeholder was deleted and reuploaded through the native file picker before submission. Approval is pending; automatic release is enabled.
