# The Transmogrifier

**Stop wasting hours converting Figma exports.** Batch-process images to WebP in seconds—no subscriptions, no cloud uploads, just fast local processing.

[![Download](https://img.shields.io/badge/Download-v1.0.1-blue?style=for-the-badge&logo=apple)](https://github.com/dbreck/the-transmogrifier/releases/download/v1.0.1/The.Transmogrifier.1.0.1.dmg)
[![Latest Release](https://img.shields.io/github/v/release/dbreck/the-transmogrifier?style=for-the-badge)](https://github.com/dbreck/the-transmogrifier/releases/latest)

![macOS](https://img.shields.io/badge/macOS-11.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## The Problem

You export beautiful designs from Figma as PNG or JPG. Then you're stuck:
- **Figma doesn't support WebP export** (even though it's the best format for web performance)
- **Manual conversion tools are slow and repetitive**—one image at a time, every single time
- **Your website loads slowly** because you're using bloated PNGs instead of optimized WebP files
- **You waste 15+ minutes per project** doing mindless image processing

**This shouldn't be this hard.** Image optimization should take seconds, not hours.

---

## The Solution

**The Transmogrifier** is a native macOS batch image processor built for designers and developers who need speed without complexity.

### What It Does
✅ **Converts any image format to WebP, JPG, or PNG**—including HEIC, TIFFs, ICNs, and more
✅ **Batch processes entire folders**—drag, drop, done
✅ **Preview before processing**—see compression quality before committing
✅ **Save workflow presets**—"Figma to WebP", "Social Media", "Client XYZ"
✅ **Track file size savings**—see exactly how much space you've saved
✅ **100% local processing**—no cloud uploads, no subscriptions, no internet required

### Why It Works
- **Native macOS app** built with SwiftUI—fast, familiar, no Electron bloat
- **Hardware-accelerated** using Core Image—processes 50+ images in seconds
- **Zero learning curve**—if you've used macOS, you already know how to use this

---

## Your 3-Step Workflow

1. **Drag in your images** (or folders)
2. **Choose format & compression** (or pick a preset)
3. **Click Process Images**

That's it. Your optimized images are ready for upload.

---

## Built for Real Workflows

### Figma → WebP (The #1 Use Case)
Figma still doesn't export to WebP. We do.

**Before:** Export PNG from Figma → Open online converter → Upload images → Wait → Download → Repeat for next batch  
**After:** Export PNG from Figma → Drag to Transmogrifier → Done

**Result:** 25-35% smaller files, same quality. Faster websites, better SEO, happier users.

### Other Common Workflows
- **Web optimization:** Batch-compress hero images to < 200 KB
- **Social media prep:** Resize 50 images to 1080×1080 for Instagram
- **Client deliverables:** Convert TIFFs to web-ready formats
- **Screenshot management:** Compress and resize Retina screenshots

---

## What Happens If You Don't Fix This?

Every day you manually convert images:
- **Your websites load slower** than competitors (Google penalizes slow sites)
- **You waste billable hours** on repetitive tasks
- **Your clients get bloated files** instead of optimized assets
- **You're stuck in outdated workflows** while others automate

**Time is money.** Automate this.

---

## What Success Looks Like

After using The Transmogrifier:
- ✅ **Your Figma-to-web workflow takes 30 seconds instead of 15 minutes**
- ✅ **Your websites load 25-35% faster** with WebP images
- ✅ **You never manually convert images again**—just drag, process, deploy
- ✅ **Your clients see faster page loads and better performance metrics**
- ✅ **You reclaim hours per week** for actual design work

**From tedious busywork → to automated efficiency.**

---

## Features

### Batch Processing
- Drag folders of images and process them all at once
- Supports: JPG, PNG, HEIC, TIFF, BMP, GIF, ICNS, ICO
- Outputs: WebP, JPG, PNG

### Smart Compression
- Visual slider for quality vs. file size
- Preview before/after with file size comparison
- Click preview to inspect full-size quality

### Preset Management
- Save your favorite settings as presets
- Built-in presets: High Quality, Web Optimized, Social Media
- Output folder path saved with preset

### Processing History
- See every file processed with before/after sizes
- Track file size savings across all batches
- Identify failed conversions with error messages

### Native macOS Experience
- SwiftUI interface with dark mode
- Hardware-accelerated processing
- No Electron, no web wrappers, just fast native code

---

## Tech Stack

- **Language:** Swift 5+
- **Framework:** SwiftUI (native macOS)
- **Architecture:** MVVM with ViewModels
- **Image Processing:** Core Image + custom engine
- **State Management:** @StateObject, @Published, ObservableObject
- **Minimum macOS:** 11.0 (Big Sur)

---

## Installation

### Download the App

**[⬇️ Download The Transmogrifier v1.0.1 (DMG)](https://github.com/dbreck/the-transmogrifier/releases/download/v1.0.1/The.Transmogrifier.1.0.1.dmg)**

Or [view all releases](https://github.com/dbreck/the-transmogrifier/releases)

### Install
1. Download and open the DMG
2. Drag **The Transmogrifier** to your **Applications** folder
3. Launch from Applications

### First Launch (macOS Security)
If macOS blocks the app with "can't be opened because it is from an unidentified developer":

1. **Control-click** (or right-click) the app in Applications
2. Select **Open** from the menu
3. Click **Open** in the security dialog
4. The app will now launch normally (you only need to do this once)

Alternatively, you can go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Build from Source
```bash
git clone https://github.com/dbreck/the-transmogrifier.git
cd the-transmogrifier
open ImageProcessingApp.xcodeproj
```

Build in Xcode (⌘+B) and run.

---

## Usage

### Quick Start
1. Launch The Transmogrifier
2. Drag images or folders onto the **File Selection** area
3. Choose output format (WebP, JPG, PNG)
4. Adjust compression slider (start at 70%)
5. Click **Browse** to select output folder
6. Click **Process Images**

### Creating a Preset
1. Set your desired format, dimensions, compression
2. Select output folder
3. Click **Save** next to Presets dropdown
4. Name your preset (e.g., "Figma to WebP")
5. Next time, just select the preset and process

### Testing Compression Quality
1. Select an image from the **Selected Files** panel
2. Adjust settings
3. Click the **Process arrow** in Preview panel
4. Click the **preview image** to open full-size
5. Zoom in (⌘+) to inspect quality
6. Adjust and retest until perfect

---

## Project Structure

```
/ImageProcessingApp/              # SwiftUI source files
  ├── ImageProcessingApp.swift    # App entry point
  ├── ContentView.swift            # Main UI
  ├── ImageProcessingEngine.swift # Core processing logic
  ├── PresetManager.swift          # Preset save/load
  ├── HistoryManager.swift         # Processing history
  └── ...
/ImageProcessingApp.xcodeproj/    # Xcode project config
/art/                              # App icon & assets
/DMG/                              # DMG build artifacts
/scripts/                          # Build & packaging scripts
```

---

## Roadmap

- [ ] Batch rename output files
- [ ] Custom output naming templates
- [ ] AVIF format support
- [ ] Image metadata preservation options
- [ ] Keyboard shortcuts for processing
- [ ] Watch folder for auto-processing
- [ ] CLI version for automation

---

## Contributing

Pull requests welcome! If you're building features, check the [Style Guide](ImageProcessingApp/ImageProcessingAppStyleGuide.md) first.

### Development Setup
1. Clone the repo
2. Open in Xcode 13+
3. Build and run (⌘+R)

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Questions?

Having issues? [Open an issue](https://github.com/dbreck/the-transmogrifier/issues) and let's fix it.

---

**Stop fighting with image converters. Start shipping faster websites.**  
[Download The Transmogrifier](https://github.com/dbreck/the-transmogrifier/releases/latest) • [View Documentation](#usage) • [Report Issues](https://github.com/dbreck/the-transmogrifier/issues)
