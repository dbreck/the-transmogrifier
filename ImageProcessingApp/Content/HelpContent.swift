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
    HelpTopic(
      title: "Quick Start Guide", category: .gettingStarted,
      content: """
        # Quick Start
        1. Add images or folders with Browse Files, drag and drop, or ⌘O.
        2. Select an image in Selected Files for an automatic preview.
        3. Choose format, maximum pixel dimensions and Quality in the right panel.
        4. Optionally enable a file-size limit or responsive image pack.
        5. Choose Beside originals or Output folder. An empty output folder cannot export.
        6. Click Process Images or press ⌘Return.
        7. Open History for results, output locations and reusable jobs.

        Folder recursion is opt-in. Add more files without replacing your selection. Max dimensions never enlarge smaller originals.
        """, icon: "star.fill", keywords: ["quick start guide"]),
    HelpTopic(
      title: "Quality and File-Size Limits", category: .features,
      content: """
        # Quality and File-Size Limits
        Higher Quality means less visual loss and usually larger files. The default is 80%. Existing presets keep their previous encoder quality.

        PNG is lossless and does not use the Quality slider.

        Enable **Keep each image under a file-size limit**, enter a limit in KB (1 KB = 1,000 bytes), and set a minimum quality for JPG or WebP. The app tests encoded sizes between your minimum and selected quality. It keeps your dimensions; if no tested result meets the budget, it reports the image without writing an output.

        Raise the budget, lower the maximum dimensions, or lower your minimum quality to retry. A size target also applies separately to each responsive variant and JPG fallback.
        """, icon: "slider.horizontal.3", keywords: ["quality and file-size limits"]),
    HelpTopic(
      title: "Responsive Image Packs", category: .features,
      content: """
        # Responsive Image Packs
        Enable **Create a responsive image pack** to export several WebP sizes together. Enter widths separated by commas, for example 640, 1280, 1920. You can specify up to eight sizes.

        The maximum width and height still act as caps. Smaller originals are never enlarged, and repeated capped sizes are exported once. Filename widths describe actual output pixels.

        Use **{name}** and **{width}** in a filename template such as {name}-{width}. Folder paths are not allowed in templates. Enable **Include JPG fallbacks** for a JPG at each size.

        After export, History offers **Copy srcset**. Each source/format group is separated by a blank line. Filenames are relative to the uploaded image folder; adjust URLs to match your website.
        """, icon: "photo.stack", keywords: ["responsive image packs"]),
    HelpTopic(
      title: "Preview and Comparison", category: .features,
      content: """
        # Live Preview
        Select an image, then change dimensions, format, quality or a file-size target. Preview updates automatically after a short pause and reports the actual encoded file size. For a responsive pack, it shows the largest primary-format variant.

        Click **Compare** for a shared canvas. Drag the comparison slider to reveal Original or Export. Both images share zoom and scroll position. Use Fit, 100%, zoom controls and checkerboard/white/black backgrounds to inspect details and transparency.

        Press ⇧⌘R to refresh. Errors appear in the preview. Clearing the file selection clears the preview as well.
        """, icon: "eye.fill", keywords: ["preview and comparison"]),
    HelpTopic(
      title: "Presets and Dock Quick Convert", category: .features,
      content: """
        # Presets and Dock Quick Convert
        Set your format, quality, dimensions, optional size limit/pack and destination, then click **Save…**. Selecting a saved preset applies it immediately. Saving with an existing custom name updates that preset.

        To convert by dropping files or folders onto the app icon, select a saved preset in **Advanced → Dock quick convert**. Future Dock drops use that preset's settings, destination and collision rules automatically. With **Open for review** selected, files are imported without conversion.

        Source-folder access may be requested by macOS for exports beside originals. Output-folder access is saved with custom presets when available. If files have moved or permissions were revoked, choose the folder again.
        """, icon: "star.square.fill", keywords: ["presets and dock quick convert"]),
    HelpTopic(
      title: "Batch History and Recovery", category: .features,
      content: """
        # Batch History
        History groups exports into jobs with their settings, source files and output results. Search by job or filename.

        - **Reveal outputs** opens the available files in Finder.
        - **Reuse settings** loads the recipe without running it.
        - **Run again** loads sources and reruns the saved recipe.
        - **Retry unfinished** runs failed/cancelled variants only, using the original job's settings.
        - **Copy srcset** copies responsive output filenames and actual widths.

        Cancel waits for active workers to finish safely. Completed files are recorded; unstarted outputs remain marked cancelled. The original files are preserved.

        Up to 100 recent jobs are kept, bounded to 10,000 results while retaining the newest whole job. Older per-file history appears under Earlier conversions and cannot be rerun because it did not save settings. Clearing history removes job records only, after confirmation.
        """, icon: "clock.fill", keywords: ["batch history and recovery"]),
    HelpTopic(
      title: "Formats and Dimensions", category: .reference,
      content: """
        # Formats and Dimensions
        Inputs include JPG, PNG, WebP, HEIC/HEIF, TIFF, BMP, GIF, ICNS and ICO, subject to macOS decoder support. Exports are WebP, JPG and PNG. Animated inputs are treated as still images; animation is not preserved.

        Max width and height fit an image inside those bounds while keeping its proportions. They do not crop to an exact square. Smaller originals are not enlarged.

        DPI is in Advanced. Pixel dimensions control image size on the web. DPI metadata support varies by output format.

        PNG supports transparency. JPG cannot preserve transparency. Inspect transparent artwork in Compare before exporting.
        """, icon: "doc.fill", keywords: ["formats and dimensions"]),
    HelpTopic(
      title: "Destinations and Existing Files", category: .troubleshooting,
      content: """
        # Destinations and Existing Files
        Choose **Beside originals** to save next to each source, or **Output folder** and Browse to choose a destination. The selected destination is shown above the export button.

        Advanced offers Rename (default), Skip, or Overwrite. Source files are protected even if an output filename matches another input. Concurrent outputs in one job receive unique names. Preserve source folder structure keeps relative subfolders when exporting imported folders to a destination.

        If macOS asks for access, select the source folder(s) containing your images. If an output is missing or a saved path is no longer accessible, choose that location again. Failures are reported per output in History.
        """, icon: "folder.fill", keywords: ["destinations and existing files"]),
  ]
  static func search(_ query: String) -> [HelpTopic] {
    guard !query.isEmpty else { return allTopics }
    return allTopics.filter { topic in
      topic.title.localizedStandardContains(query) || topic.content.localizedStandardContains(query)
        || topic.keywords.contains { $0.localizedStandardContains(query) }
    }
  }
  static func topics(for category: HelpCategory) -> [HelpTopic] {
    allTopics.filter { $0.category == category }
  }
}
