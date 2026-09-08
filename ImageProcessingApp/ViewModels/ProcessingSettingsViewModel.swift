import SwiftUI

@MainActor
class ProcessingSettingsViewModel: ObservableObject {
  @Published var targetResolution = "72"
  @Published var maxWidth = ""
  @Published var maxHeight = ""
  @Published var quality = 80.0
  @Published var outputFormat = "WebP"
  @Published var outputFolder = "" {
    didSet {
      if scopedOutputURL?.path != outputFolder { releaseOutputAccess() }
    }
  }
  private var scopedOutputURL: URL?
  private var outputAccessActive = false
  private var outputBookmark: Data?

  private func releaseOutputAccess() {
    if outputAccessActive { scopedOutputURL?.stopAccessingSecurityScopedResource() }
    scopedOutputURL = nil
    outputAccessActive = false
    outputBookmark = nil
  }
  func setOutputFolder(_ url: URL) {
    releaseOutputAccess()
    outputFolder = url.path
    scopedOutputURL = url
    outputAccessActive = url.startAccessingSecurityScopedResource()
    outputBookmark = try? url.bookmarkData(
      options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
  }

  @Published var selectedPreset = ""
  @Published var saveAlongsideOriginals = true
  @Published var preserveFolderStructure = true
  @Published var collisionPolicy: CollisionPolicy = .rename
  @Published var usesTargetSize = false
  @Published var targetSizeKB = "200"
  @Published var minimumQuality = 40.0
  @Published var createsResponsivePack = false
  @Published var responsiveWidths = "640, 1280, 1920"
  @Published var includeJPEGFallback = false
  @Published var namingTemplate = "{name}-{width}"

  var hasExplicitOutputFolder: Bool {
    !outputFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  var effectivelySavesAlongsideOriginals: Bool { saveAlongsideOriginals }
  var parsedWidths: [Int] {
    Array(
      Set(
        responsiveWidths.split(separator: ",").compactMap {
          Int($0.trimmingCharacters(in: .whitespaces))
        })
    ).sorted()
  }
  var options: ExportOptions {
    ExportOptions(
      targetSizeKB: usesTargetSize ? Int(targetSizeKB) : nil,
      minimumQuality: Float(minimumQuality / 100),
      responsiveWidths: createsResponsivePack ? parsedWidths : [],
      includeJPEGFallback: includeJPEGFallback, namingTemplate: namingTemplate)
  }
  var previewValidationMessage: String? {
    for (label, value) in [("width", maxWidth), ("height", maxHeight)] {
      if !value.isEmpty, Int(value).map({ (1...32768).contains($0) }) != true {
        return "Enter a \(label) between 1 and 32,768 pixels, or leave it empty for Auto."
      }
    }
    if Int(targetResolution).map({ (1...2400).contains($0) }) != true {
      return "Enter a DPI between 1 and 2,400."
    }
    if usesTargetSize {
      if Int(targetSizeKB) == nil { return "Enter a whole-number file-size limit in KB." }
      if outputFormat != "PNG" && minimumQuality > quality {
        return "Minimum quality must be at or below the selected quality."
      }
    }
    if createsResponsivePack {
      let parts = responsiveWidths.split(separator: ",", omittingEmptySubsequences: false)
      if parts.isEmpty
        || parts.contains(where: { Int($0.trimmingCharacters(in: .whitespaces)) == nil })
      {
        return "Enter widths separated by commas, for example 640, 1280, 1920."
      }
      if outputFormat != "WebP" { return "Responsive packs use WebP. Select WebP to continue." }
    }
    return options.validationMessage
  }
  var validationMessage: String? {
    if let message = previewValidationMessage { return message }
    if !saveAlongsideOriginals {
      if !hasExplicitOutputFolder { return "Choose an output folder before exporting." }
      if !outputFolder.hasPrefix("/") { return "Choose an absolute output-folder path." }
    }
    return nil
  }
  var destinationSummary: String {
    saveAlongsideOriginals
      ? "Save beside each original"
      : (hasExplicitOutputFolder ? outputFolder : "Choose an output folder")
  }
  func getProcessingSettings() -> ProcessingSettings {
    ProcessingSettings(
      dpi: Int(targetResolution) ?? 72, maxWidth: Int(maxWidth) ?? 0,
      maxHeight: Int(maxHeight) ?? 0, compressionLevel: Float(quality / 100),
      outputFormat: outputFormat, outputFolder: outputFolder,
      saveAlongsideOriginals: saveAlongsideOriginals,
      preserveFolderStructure: preserveFolderStructure, collisionPolicy: collisionPolicy,
      exportOptions: options)
  }
  func getProcessingSettingsForPreview() -> ProcessingSettings { getProcessingSettings() }
  func applyCustomPreset(_ preset: Preset) {
    selectedPreset = preset.name
    apply(
      ProcessingSettings(
        dpi: preset.dpi, maxWidth: preset.maxWidth, maxHeight: preset.maxHeight,
        compressionLevel: preset.compressionLevel, outputFormat: preset.outputFormat,
        outputFolder: preset.outputFolder, saveAlongsideOriginals: preset.saveAlongsideOriginals,
        preserveFolderStructure: preset.preserveFolderStructure,
        collisionPolicy: preset.collisionPolicy,
        exportOptions: preset.exportOptions))
    if let data = preset.outputFolderBookmark,
      let url = HistoryManager.resolveBookmarks([data]).first
    {
      setOutputFolder(url)
    }
  }
  func apply(_ settings: ProcessingSettings) {
    targetResolution = "\(settings.dpi)"
    maxWidth = settings.maxWidth == 0 ? "" : "\(settings.maxWidth)"
    maxHeight = settings.maxHeight == 0 ? "" : "\(settings.maxHeight)"
    quality = Double(settings.compressionLevel) * 100
    outputFormat = settings.outputFormat
    outputFolder = settings.outputFolder
    saveAlongsideOriginals = settings.saveAlongsideOriginals
    preserveFolderStructure = settings.preserveFolderStructure
    collisionPolicy = settings.collisionPolicy
    let options = settings.exportOptions
    usesTargetSize = options.targetSizeKB != nil
    targetSizeKB = "\(options.targetSizeKB ?? 200)"
    minimumQuality = Double(options.minimumQuality) * 100
    createsResponsivePack = options.isResponsive
    responsiveWidths = (options.isResponsive ? options.responsiveWidths : [640, 1280, 1920]).map(
      String.init
    ).joined(separator: ", ")
    includeJPEGFallback = options.includeJPEGFallback
    namingTemplate = options.namingTemplate
  }
  func makePreset(name: String, id: UUID = UUID()) -> Preset {
    let s = getProcessingSettings()
    var preset = Preset(
      id: id, name: name, dpi: s.dpi, maxWidth: s.maxWidth, maxHeight: s.maxHeight,
      compressionLevel: s.compressionLevel, outputFormat: s.outputFormat,
      outputFolder: s.outputFolder,
      saveAlongsideOriginals: s.saveAlongsideOriginals,
      preserveFolderStructure: s.preserveFolderStructure,
      collisionPolicy: s.collisionPolicy, exportOptions: s.exportOptions)
    preset.outputFolderBookmark = outputBookmark
    if preset.outputFolderBookmark == nil && !s.saveAlongsideOriginals && !s.outputFolder.isEmpty {
      preset.outputFolderBookmark = try? URL(fileURLWithPath: s.outputFolder).bookmarkData(
        options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
    return preset
  }
}
