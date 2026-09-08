#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
review_build="${TRANSMOGRIFIER_CHECK_BUILD:-/tmp/transmogrifier-review-build}"
if [[ ! -f "$review_build/Build/Products/Debug/libwebp.o" ]]; then
  xcodebuild -project ImageProcessingApp.xcodeproj -scheme 'The Transmogrifier' -configuration Debug -derivedDataPath "$review_build" CODE_SIGNING_ALLOWED=NO build > /tmp/transmogrifier-check-build.log 2>&1
fi
xcrun swiftc -parse-as-library -swift-version 5 -O \
  -Xcc "-fmodule-map-file=$review_build/Build/Intermediates.noindex/GeneratedModuleMaps/libwebp.modulemap" \
  -I "$review_build/SourcePackages/checkouts/libwebp-Xcode/include" \
  "$review_build/Build/Products/Debug/libwebp.o" \
  ImageProcessingApp/Models/Preset.swift ImageProcessingApp/Models/HistoryRecord.swift \
  ImageProcessingApp/Services/ImageProcessingEngine.swift ImageProcessingApp/Services/HistoryManager.swift \
  ImageProcessingApp/ViewModels/ProcessingSettingsViewModel.swift ImageProcessingApp/ViewModels/PreviewViewModel.swift \
  ImageProcessingApp/ViewModels/FileSelectionViewModel.swift Tests/ExportWorkflowChecks.swift -o "$review_build/export-workflow-checks"
"$review_build/export-workflow-checks"
