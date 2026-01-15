# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Transmogrifier is a native macOS batch image processor built with SwiftUI. It converts images between formats (WebP, JPG, PNG) with compression controls, preset management, and processing history. The repository also contains a marketing website.

## Build Commands

### macOS App (Xcode)
```bash
# Open project in Xcode
open ImageProcessingApp.xcodeproj

# Build from command line
xcodebuild -project ImageProcessingApp.xcodeproj -scheme "The Transmogrifier" -configuration Release build

# Create DMG for distribution (after building in Xcode)
./create-dmg-v1.0.1.sh
```

### Marketing Website (Astro)
```bash
cd website
npm install
npm run dev      # Start dev server at http://localhost:4321
npm run build    # Production build
npm run preview  # Preview production build
```

## Architecture

### SwiftUI App (`/ImageProcessingApp/`)

Organized by layer following MVVM pattern:

```
ImageProcessingApp/
├── App/                    # App entry point
│   └── ImageProcessingApp.swift
├── Views/                  # SwiftUI views
│   ├── ContentView.swift   # Main UI with TabView
│   ├── FileSelectionView.swift
│   ├── ProcessingSettingsView.swift
│   ├── PreviewView.swift
│   ├── HistoryView.swift
│   ├── HelpView.swift
│   └── OnboardingTourView.swift
├── ViewModels/             # MVVM view models
│   ├── FileSelectionViewModel.swift
│   ├── ProcessingSettingsViewModel.swift
│   └── PreviewViewModel.swift
├── Models/                 # Data models
│   ├── Preset.swift
│   └── HistoryRecord.swift
├── Services/               # Business logic
│   ├── ImageProcessingEngine.swift  # Core Image processing
│   ├── PresetManager.swift
│   ├── HistoryManager.swift
│   ├── AppearanceManager.swift
│   └── HelpWindowManager.swift
├── Design/                 # UI design system
│   ├── DesignSystem.swift  # Colors, typography, spacing
│   └── ImageProcessingAppStyleGuide.md
├── Content/                # Static content
│   └── HelpContent.swift
└── Resources/              # Assets and config
    ├── Assets.xcassets/
    ├── Preview Assets.xcassets/
    ├── Info.plist
    └── ImageProcessingApp.entitlements
```

**Core Processing:**
- `ImageProcessingEngine.swift` - Core Image-based processing, WebP encoding, batch operations
- Uses `CIContext` with software rendering for compatibility
- Supports: JPG, PNG, HEIC, TIFF, BMP, GIF, ICNS, ICO → WebP, JPG, PNG

### Website (`/website/`)

Astro static site with Tailwind CSS. Pages in `src/pages/`, layout in `src/layouts/BaseLayout.astro`.

## Design System

Colors must match the app exactly (defined in `Design/DesignSystem.swift` and `tailwind.config.mjs`):
- Background: `#1a1d29` (gray900)
- Cards: `#242938` (gray800)
- Primary Blue: `#4f7df7` (blue600)
- Text Secondary: `#9ca3af` (gray400)

See `ImageProcessingApp/Design/ImageProcessingAppStyleGuide.md` for full design specs.

## UI Features

- Dark mode only (forced via `.preferredColorScheme(.dark)`)
- Hidden title bar with compact toolbar style
- Onboarding tour available via Help menu → Show Tour

## Key Patterns

- All SwiftUI views use `@MainActor` for thread safety
- ViewModels are `@StateObject` with `@Published` properties
- Image processing is async with progress handlers
- App entry point: `TransmogrifierApp` in `App/ImageProcessingApp.swift`
- Help window opens via `NotificationCenter` notification pattern
