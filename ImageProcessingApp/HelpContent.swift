import Foundation

struct HelpTopic: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let category: HelpCategory
    let content: String
    let icon: String
    let keywords: [String]
}

enum HelpCategory: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case features = "Features"
    case workflows = "Common Workflows"
    case troubleshooting = "Troubleshooting"
    case reference = "Reference"
}

struct HelpContent {
    static let allTopics: [HelpTopic] = [
        // MARK: - Getting Started
        HelpTopic(
            title: "Quick Start Guide",
            category: .gettingStarted,
            content: """
            # Quick Start Guide
            
            Get up and running with The Transmogrifier in seconds:
            
            1. **Add Images** - Drag and drop image files or folders onto the File Selection area, or click Browse Files
            2. **Preview** - Select any image from the Selected Files list to preview it
            3. **Adjust Settings** - Set your output format (JPG, PNG, WebP), dimensions, and compression
            4. **Test Compression** - Click the Process arrow in Preview to see the result, then click the preview image to zoom in and inspect quality
            5. **Choose Output** - Click Browse next to Output Folder to select where processed images will be saved
            6. **Save as Preset** (optional) - If you'll use these settings again, click Save to create a preset
            7. **Process All** - Click Process Images to convert all selected files
            8. **View History** - Switch to the History tab to see all your processed images with file size savings
            """,
            icon: "star.fill",
            keywords: ["quick", "start", "begin", "first", "getting started", "tutorial", "how to"]
        ),
        
        HelpTopic(
            title: "First-Time Walkthrough",
            category: .gettingStarted,
            content: """
            # First-Time Walkthrough
            
            When you first launch The Transmogrifier, you'll see an interactive tour highlighting each part of the interface. To see it again:
            
            1. Go to Help menu → Show Tour
            2. Follow the spotlight highlights that guide you through each section
            3. Press ESC or click outside the tour to exit at any time
            
            The tour covers all 8 steps of the image processing workflow.
            """,
            icon: "hand.point.up.left.fill",
            keywords: ["tour", "walkthrough", "tutorial", "onboarding", "first time", "guide"]
        ),
        
        // MARK: - Features
        HelpTopic(
            title: "Supported File Formats",
            category: .features,
            content: """
            # Supported File Formats
            
            ## Input Formats (What You Can Process)
            - JPEG / JPG
            - PNG
            - TIFF / TIF
            - BMP
            - GIF
            - ICNS (macOS icons)
            - ICO (Windows icons)
            
            ## Output Formats (What You Can Export)
            - **WebP** - Modern web format with excellent compression (best for web)
            - **JPG** - Universal format, smaller file sizes (good for photos)
            - **PNG** - Lossless format, supports transparency (best for graphics/logos)
            
            **Tip:** WebP typically produces 25-35% smaller files than JPG at the same quality level.
            """,
            icon: "doc.fill",
            keywords: ["formats", "file types", "webp", "jpg", "png", "jpeg", "tiff", "supported"]
        ),
        
        HelpTopic(
            title: "Understanding Compression",
            category: .features,
            content: """
            # Understanding the Compression Slider
            
            The compression slider controls file size vs. image quality:
            
            ## How It Works
            - **Drag LEFT** (0-20%) - Minimal compression, maximum quality, larger files
            - **Drag MIDDLE** (30-60%) - Balanced compression, good quality, reasonable file sizes
            - **Drag RIGHT** (70-100%) - Maximum compression, smaller files, visible quality loss
            
            ## Testing Compression
            1. Adjust the slider to your desired level
            2. Click the **Process arrow** in the Preview panel
            3. Click the **preview image** (magnifying glass appears) to open it full-size
            4. Zoom in to inspect quality
            5. Adjust slider and reprocess until you find the sweet spot
            
            ## Recommended Settings
            - **Web images:** 60-75% compression (WebP format)
            - **Photography:** 20-40% compression (JPG format)
            - **Graphics/logos with text:** 10-30% compression (PNG format)
            
            **Tip:** Start at 70% compression and work your way down only if you notice quality issues. Most web images look great at 70-80%.
            """,
            icon: "slider.horizontal.3",
            keywords: ["compression", "quality", "file size", "slider", "optimize", "compress"]
        ),
        
        HelpTopic(
            title: "Presets: Save Your Favorite Settings",
            category: .features,
            content: """
            # Working with Presets
            
            Presets let you save and reuse your favorite settings for common tasks.
            
            ## Built-in Presets
            - **High Quality** - 300 DPI, WebP format, minimal compression
            - **Web Optimized** - 72 DPI, 1920px wide, WebP format, balanced compression
            - **Social Media** - 72 DPI, 1080×1080px, JPG format, medium compression
            
            ## Creating Your Own Preset
            1. Set up your desired output format, dimensions, and compression
            2. Select an output folder (this will be remembered)
            3. Click **Save** button next to the Presets dropdown
            4. Enter a name for your preset
            5. Your preset now appears in the dropdown menu
            
            ## Using a Preset
            1. Click the **Presets dropdown**
            2. Select your preset
            3. All settings instantly update
            4. Your selected output folder is automatically restored
            
            **Tip:** Create presets for each client or project to speed up your workflow.
            """,
            icon: "star.square.fill",
            keywords: ["presets", "save", "settings", "favorites", "quick", "workflow"]
        ),
        
        HelpTopic(
            title: "Processing History",
            category: .features,
            content: """
            # Processing History
            
            The History tab keeps a complete record of all images you've processed.
            
            ## What's Tracked
            For each image, you'll see:
            - Original filename
            - File size before and after
            - Percentage reduction (in green or red)
            - Processing time
            - Success/failure status
            - Timestamp of when it was processed
            
            ## Using History
            - **Review savings** - See how much file size you've reduced across all images
            - **Track batches** - Identify which batch runs were most effective
            - **Troubleshoot** - If an image failed, see the error message
            
            ## Clearing History
            Click **Clear History** to remove all records. This doesn't delete your processed images, only the history log.
            
            **Tip:** History is stored locally and persists between app launches.
            """,
            icon: "clock.fill",
            keywords: ["history", "track", "record", "log", "processed", "savings"]
        ),
        
        HelpTopic(
            title: "Preview & Before/After Comparison",
            category: .features,
            content: """
            # Preview Panel
            
            The Preview panel lets you test settings on a single image before processing your entire batch.
            
            ## How to Use Preview
            1. Select an image from the **Selected Files** panel on the right
            2. Adjust your settings (format, dimensions, compression)
            3. Click the **Process arrow** between Original and Processed
            4. The processed version appears on the right
            
            ## Inspecting Quality
            - Click the **processed preview image** (magnifying glass icon appears)
            - Opens full-size in a new window
            - Use ⌘+ and ⌘- to zoom in/out
            - Check for compression artifacts or quality loss
            
            ## Reading the Details
            Below each preview, you'll see:
            - **Format** (e.g., TIFF, WEBP)
            - **File size** (e.g., 4.7 MB → 163 KB)
            - **Dimensions** (e.g., 1536 × 1024)
            - **DPI** (e.g., 72 DPI)
            
            **Tip:** Always preview at least one image before batch processing to ensure you're happy with the quality.
            """,
            icon: "eye.fill",
            keywords: ["preview", "before", "after", "compare", "test", "inspect", "quality"]
        ),
        
        // MARK: - Common Workflows
        HelpTopic(
            title: "Figma to WebP Workflow",
            category: .workflows,
            content: """
            # Converting Figma Exports to WebP
            
            This is the #1 use case The Transmogrifier was built for.
            
            ## The Problem
            Figma doesn't export to WebP format yet, forcing designers to export as JPG or PNG, then convert in separate tools.
            
            ## The Solution
            1. Export your designs from Figma as **PNG or JPG**
            2. In The Transmogrifier, set output format to **WebP**
            3. Set compression to **70-75%** (sweet spot for web)
            4. Set max width to **1920px** (or your site's content width)
            5. Save as preset: "**Figma to WebP**"
            6. Drag your Figma exports onto File Selection
            7. Click **Process Images**
            
            ## Why This Matters
            - WebP files are typically **25-35% smaller** than JPG at the same quality
            - Faster page loads = better SEO and user experience
            - All modern browsers support WebP
            
            **Tip:** Create a preset for each website project with the exact dimensions your CMS needs.
            """,
            icon: "paintbrush.fill",
            keywords: ["figma", "webp", "export", "design", "convert", "workflow", "web"]
        ),
        
        HelpTopic(
            title: "Bulk Image Optimization for Web",
            category: .workflows,
            content: """
            # Optimizing Images for Website Performance
            
            Speed up your website by batch-optimizing images.
            
            ## Step-by-Step
            1. Drag all website images into File Selection
            2. Choose output format:
               - **Photos:** WebP or JPG
               - **Graphics/logos:** WebP or PNG
            3. Set max width to your site's content width (typically 1920px)
            4. Set compression to **70-80%** for photos, **30-50%** for graphics
            5. Preview one image to check quality
            6. Process all images
            
            ## File Size Targets
            - Hero images: < 200 KB
            - Content images: < 100 KB
            - Thumbnails: < 50 KB
            
            ## Typical Results
            - **PNG → WebP:** 50-70% size reduction
            - **JPG → WebP:** 25-35% size reduction
            - **Large TIFF → WebP:** 80-95% size reduction
            
            **Tip:** Check History tab after processing to see your total file size savings.
            """,
            icon: "bolt.fill",
            keywords: ["optimize", "web", "performance", "speed", "compress", "website", "bulk"]
        ),
        
        HelpTopic(
            title: "Social Media Image Prep",
            category: .workflows,
            content: """
            # Preparing Images for Social Media
            
            Batch-resize and optimize images for Instagram, Facebook, Twitter, and LinkedIn.
            
            ## Use the Social Media Preset
            The built-in **Social Media** preset is configured for:
            - 1080×1080px (Instagram square format)
            - 72 DPI
            - JPG format
            - Medium compression
            
            ## Custom Social Media Sizes
            Create presets for each platform:
            
            **Instagram Feed**
            - 1080×1080px (square)
            - 1080×1350px (portrait)
            
            **Instagram Stories**
            - 1080×1920px
            
            **Facebook/Twitter**
            - 1200×630px (link previews)
            
            **LinkedIn**
            - 1200×627px (posts)
            
            ## Workflow
            1. Select the appropriate preset
            2. Drag in all your images
            3. Process Images
            4. Upload to social platform
            
            **Tip:** Keep compression at 60-70% for social media to maintain quality on high-res displays.
            """,
            icon: "photo.stack.fill",
            keywords: ["social media", "instagram", "facebook", "twitter", "linkedin", "resize", "square"]
        ),
        
        // MARK: - Troubleshooting
        HelpTopic(
            title: "No Files Selected",
            category: .troubleshooting,
            content: """
            # No Files Selected Error
            
            If you see "No files selected" when trying to process:
            
            ## Check These:
            1. **Did you add images?** Look at the Selected Files panel (right side) - does it show any files?
            2. **Supported format?** Only image files are accepted (see Supported File Formats)
            3. **Permissions?** If dragging from external drive or network location, check file permissions
            
            ## Solution
            - Click **Browse Files** and select images manually
            - Or drag valid image files directly onto the File Selection area
            
            **Tip:** You should see files appear in the Selected Files panel on the right as soon as you add them.
            """,
            icon: "exclamationmark.triangle.fill",
            keywords: ["error", "no files", "selected", "problem", "not working"]
        ),
        
        HelpTopic(
            title: "Output Folder Not Selected",
            category: .troubleshooting,
            content: """
            # Output Folder Required Error
            
            If you see "Please select an output folder" when trying to process:
            
            ## What's Happening
            The app needs to know where to save your processed images.
            
            ## Solution
            1. Look for the **Output Folder** section in Processing Parameters
            2. Click the **Browse** button
            3. Choose or create a folder
            4. Try processing again
            
            ## Tips
            - You can select your Desktop, Documents, or any folder you have access to
            - The app will remember your output folder choice
            - If you save this as a preset, the folder path is saved too
            
            **Tip:** Create a dedicated "Processed Images" folder on your Desktop for easy access.
            """,
            icon: "folder.badge.questionmark",
            keywords: ["output", "folder", "error", "save", "location", "destination"]
        ),
        
        HelpTopic(
            title: "Processing Failed",
            category: .troubleshooting,
            content: """
            # Processing Failed Errors
            
            If image processing fails, check the History tab for the specific error.
            
            ## Common Errors & Solutions
            
            **"Corrupted image file"**
            - The image file may be damaged
            - Try opening in Preview app to verify
            - Solution: Re-export or re-download the image
            
            **"Permission denied"**
            - Can't write to the output folder
            - Solution: Choose a different output folder or check folder permissions
            
            **"Disk full"**
            - Not enough space on your drive
            - Solution: Free up disk space or choose output folder on different drive
            
            **"Unsupported output format"**
            - WebP encoding may not be available on older macOS versions
            - Solution: Choose JPG or PNG format instead
            
            **"Failed to load image"**
            - File isn't a valid image or is corrupted
            - Solution: Verify the file opens in other apps
            
            ## Getting More Help
            Check the History tab for exact error messages, which will help diagnose the issue.
            """,
            icon: "xmark.octagon.fill",
            keywords: ["error", "failed", "processing", "problem", "corrupted", "permission", "disk full"]
        ),
        
        HelpTopic(
            title: "WebP Not Available",
            category: .troubleshooting,
            content: """
            # WebP Format Not Working
            
            If WebP output fails or isn't available:
            
            ## Possible Causes
            - Your macOS version may not have native WebP support
            - The app's WebP library may not be loaded
            
            ## What Happens
            The app will automatically fall back to JPG format if WebP encoding fails. You'll see this in the History tab.
            
            ## Solutions
            1. **Update macOS** - Newer versions have better WebP support
            2. **Use JPG or PNG** - Select these formats instead, which always work
            3. **Check History** - See if files were converted to JPG automatically
            
            ## JPG as Alternative
            - JPG format is universal and works everywhere
            - File sizes are about 25-35% larger than WebP
            - Still much smaller than PNG for photos
            
            **Note:** Most modern Macs running macOS 11 (Big Sur) or later support WebP natively.
            """,
            icon: "photo.badge.exclamationmark.fill",
            keywords: ["webp", "not working", "unsupported", "format", "error", "fallback", "jpg"]
        ),
        
        HelpTopic(
            title: "Quality Issues After Processing",
            category: .troubleshooting,
            content: """
            # Image Quality Problems
            
            If processed images look pixelated, blurry, or low quality:
            
            ## Adjust Compression
            The most common cause is compression set too high.
            
            1. Lower compression slider (drag left)
            2. Click Process arrow in Preview
            3. Click preview image to inspect full-size
            4. Repeat until quality looks good
            5. Reprocess all images with new settings
            
            ## Avoid Upscaling
            - Don't set Max Width/Height larger than original dimensions
            - Upscaling always reduces quality
            - Leave fields blank or set to "Auto" to maintain original size
            
            ## Format Choices Matter
            - **Photos with compression artifacts?** Use PNG or lower JPG compression
            - **Graphics/logos looking fuzzy?** Use PNG with minimal compression
            - **Text hard to read?** Use PNG format, not JPG
            
            ## Starting Points
            - **Photos:** 60-70% compression, WebP or JPG
            - **Graphics:** 20-30% compression, PNG
            - **Screenshots:** 40-50% compression, PNG
            
            **Remember:** Always preview before batch processing.
            """,
            icon: "sparkles",
            keywords: ["quality", "blurry", "pixelated", "fuzzy", "artifacts", "low quality", "bad"]
        ),
        
        // MARK: - Reference
        HelpTopic(
            title: "Keyboard Shortcuts",
            category: .reference,
            content: """
            # Keyboard Shortcuts
            
            Currently, there are no custom keyboard shortcuts beyond standard macOS shortcuts:
            
            ## Standard macOS Shortcuts
            - **⌘Q** - Quit The Transmogrifier
            - **⌘W** - Close window
            - **⌘M** - Minimize window
            - **⌘H** - Hide The Transmogrifier
            - **⌘?** - Open Help menu
            
            ## In Help Window
            - **⌘F** - Search help content
            - **ESC** - Close help window
            
            ## In Preview Window
            - **⌘+** - Zoom in
            - **⌘-** - Zoom out
            - **⌘0** - Reset zoom to 100%
            
            **Note:** Keyboard shortcuts for processing may be added in future versions.
            """,
            icon: "keyboard.fill",
            keywords: ["keyboard", "shortcuts", "keys", "commands", "hotkeys"]
        ),
        
        HelpTopic(
            title: "Performance Tips",
            category: .reference,
            content: """
            # Getting the Best Performance
            
            Tips to process images faster:
            
            ## Optimize Your Workflow
            1. **Process in batches** - 20-50 images at a time performs best
            2. **Close other apps** - Free up RAM and CPU
            3. **Use presets** - Avoid changing settings repeatedly
            4. **Choose WebP** - Faster to encode than PNG for photos
            
            ## File Size Considerations
            - Very large files (50+ MB) take longer to process
            - Resize before processing if you don't need full resolution
            - TIFF files are much slower than JPG/PNG
            
            ## What's Normal
            - **Small images (<5 MB):** < 0.5 seconds each
            - **Medium images (5-20 MB):** 0.5-2 seconds each
            - **Large images (20+ MB):** 2-10 seconds each
            
            ## Storage
            - Processing history is stored in UserDefaults
            - Presets are stored in UserDefaults
            - No temporary files are created
            
            **Tip:** Check the History tab to see actual processing times for your images.
            """,
            icon: "speedometer",
            keywords: ["performance", "speed", "slow", "fast", "optimize", "tips"]
        ),
        
        HelpTopic(
            title: "About The Transmogrifier",
            category: .reference,
            content: """
            # About The Transmogrifier
            
            A native macOS app for batch image processing, built for designers and web developers.
            
            ## What It Does
            - Convert images to WebP, JPG, or PNG
            - Batch resize and compress
            - Save presets for common workflows
            - Track processing history
            
            ## Built For
            - Web designers optimizing images for websites
            - Figma users who need WebP export
            - Photographers preparing images for web
            - Social media managers resizing image batches
            
            ## Technology
            - Native macOS app (SwiftUI)
            - Core Image processing engine
            - Hardware-accelerated when available
            - Supports macOS 11 (Big Sur) and later
            
            ## Privacy
            - All processing happens locally on your Mac
            - No data is sent to external servers
            - No analytics or tracking
            - No internet connection required
            
            ---
            
            Created by Danny Breckenridge
            © 2025 The Transmogrifier
            """,
            icon: "info.circle.fill",
            keywords: ["about", "info", "privacy", "version", "creator", "technology"]
        )
    ]
    
    // Helper methods for searching and filtering
    static func search(_ query: String) -> [HelpTopic] {
        guard !query.isEmpty else { return allTopics }
        
        let lowercased = query.lowercased()
        return allTopics.filter { topic in
            topic.title.lowercased().contains(lowercased) ||
            topic.content.lowercased().contains(lowercased) ||
            topic.keywords.contains { $0.lowercased().contains(lowercased) }
        }
    }
    
    static func topics(for category: HelpCategory) -> [HelpTopic] {
        allTopics.filter { $0.category == category }
    }
}
