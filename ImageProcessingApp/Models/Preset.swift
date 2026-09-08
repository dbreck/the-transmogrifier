import Foundation

struct Preset: Identifiable, Codable, Hashable {
  let id: UUID
  var name: String
  var dpi: Int
  var maxWidth: Int
  var maxHeight: Int
  var compressionLevel: Float
  var outputFormat: String
  var outputFolder: String
  var saveAlongsideOriginals: Bool
  var preserveFolderStructure: Bool
  var collisionPolicy: CollisionPolicy
  var exportOptions: ExportOptions
  var outputFolderBookmark: Data? = nil
  var createdAt: Date
  var updatedAt: Date
  var isDefault: Bool

  init(
    id: UUID = UUID(),
    name: String,
    dpi: Int,
    maxWidth: Int,
    maxHeight: Int,
    compressionLevel: Float,
    outputFormat: String,
    outputFolder: String,
    saveAlongsideOriginals: Bool = false,
    preserveFolderStructure: Bool = true,
    collisionPolicy: CollisionPolicy = .rename,
    isDefault: Bool = false,
    exportOptions: ExportOptions = ExportOptions()
  ) {
    self.exportOptions = exportOptions
    self.id = id
    self.name = name
    self.dpi = dpi
    self.maxWidth = maxWidth
    self.maxHeight = maxHeight
    self.compressionLevel = compressionLevel
    self.outputFormat = outputFormat
    self.outputFolder = outputFolder
    self.saveAlongsideOriginals = saveAlongsideOriginals
    self.preserveFolderStructure = preserveFolderStructure
    self.collisionPolicy = collisionPolicy
    self.isDefault = isDefault
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  // Backward-compatible decoding for older presets missing newer fields.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    dpi = try container.decode(Int.self, forKey: .dpi)
    maxWidth = try container.decode(Int.self, forKey: .maxWidth)
    maxHeight = try container.decode(Int.self, forKey: .maxHeight)
    compressionLevel = try container.decode(Float.self, forKey: .compressionLevel)
    outputFormat = try container.decode(String.self, forKey: .outputFormat)
    outputFolder = try container.decode(String.self, forKey: .outputFolder)
    saveAlongsideOriginals =
      try container.decodeIfPresent(Bool.self, forKey: .saveAlongsideOriginals) ?? false
    preserveFolderStructure =
      try container.decodeIfPresent(
        Bool.self, forKey: .preserveFolderStructure) ?? true
    collisionPolicy =
      try container.decodeIfPresent(
        CollisionPolicy.self, forKey: .collisionPolicy) ?? .rename
    exportOptions =
      try container.decodeIfPresent(ExportOptions.self, forKey: .exportOptions) ?? ExportOptions()
    outputFolderBookmark = try container.decodeIfPresent(Data.self, forKey: .outputFolderBookmark)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    isDefault = try container.decode(Bool.self, forKey: .isDefault)
  }

  mutating func update(
    name: String? = nil,
    dpi: Int? = nil,
    maxWidth: Int? = nil,
    maxHeight: Int? = nil,
    compressionLevel: Float? = nil,
    outputFormat: String? = nil,
    outputFolder: String? = nil,
    saveAlongsideOriginals: Bool? = nil,
    preserveFolderStructure: Bool? = nil,
    collisionPolicy: CollisionPolicy? = nil
  ) {
    if let name = name { self.name = name }
    if let dpi = dpi { self.dpi = dpi }
    if let maxWidth = maxWidth { self.maxWidth = maxWidth }
    if let maxHeight = maxHeight { self.maxHeight = maxHeight }
    if let compressionLevel = compressionLevel { self.compressionLevel = compressionLevel }
    if let outputFormat = outputFormat { self.outputFormat = outputFormat }
    if let outputFolder = outputFolder { self.outputFolder = outputFolder }
    if let saveAlongsideOriginals = saveAlongsideOriginals {
      self.saveAlongsideOriginals = saveAlongsideOriginals
    }
    if let preserveFolderStructure = preserveFolderStructure {
      self.preserveFolderStructure = preserveFolderStructure
    }
    if let collisionPolicy = collisionPolicy { self.collisionPolicy = collisionPolicy }
    self.updatedAt = Date()
  }
}

// Default presets
extension Preset {
  static let defaultPresets: [Preset] = [
    Preset(
      id: UUID(uuidString: "AA36B638-01B1-4891-94F1-555161B9DC01")!,
      name: "High Quality",
      dpi: 300,
      maxWidth: 0,
      maxHeight: 0,
      compressionLevel: 0.9,
      outputFormat: "WebP",
      outputFolder: "",
      saveAlongsideOriginals: true,
      isDefault: true
    ),
    Preset(
      id: UUID(uuidString: "AA36B638-01B1-4891-94F1-555161B9DC02")!,
      name: "Web Optimized",
      dpi: 72,
      maxWidth: 1920,
      maxHeight: 1080,
      compressionLevel: 0.8,
      outputFormat: "WebP",
      outputFolder: "",
      saveAlongsideOriginals: true,
      isDefault: true
    ),
    Preset(
      id: UUID(uuidString: "AA36B638-01B1-4891-94F1-555161B9DC03")!,
      name: "Social Media",
      dpi: 72,
      maxWidth: 1080,
      maxHeight: 1080,
      compressionLevel: 0.7,
      outputFormat: "JPG",
      outputFolder: "",
      saveAlongsideOriginals: true,
      isDefault: true
    ),
  ]
}

enum CollisionPolicy: String, CaseIterable, Codable, Hashable {
  case overwrite
  case skip
  case rename

  var label: String {
    switch self {
    case .overwrite:
      return "Overwrite"
    case .skip:
      return "Skip"
    case .rename:
      return "Rename"
    }
  }
}

struct ProcessingSettings: Codable, Equatable {
  let dpi: Int
  let maxWidth: Int
  let maxHeight: Int
  let compressionLevel: Float
  let outputFormat: String
  let outputFolder: String
  let saveAlongsideOriginals: Bool
  let preserveFolderStructure: Bool
  let collisionPolicy: CollisionPolicy
  var exportOptions = ExportOptions()
  var previewIdentity: String {
    "\(dpi)|\(maxWidth)|\(maxHeight)|\(compressionLevel)|\(outputFormat)|\(exportOptions.targetSizeKB ?? 0)|\(exportOptions.minimumQuality)|\(exportOptions.responsiveWidths)"
  }
}

/// Stored with presets and batches. Existing presets retain their encoder quality.
struct ExportOptions: Codable, Equatable, Hashable {
  var targetSizeKB: Int? = nil
  var minimumQuality: Float = 0.4
  var responsiveWidths: [Int] = []
  var includeJPEGFallback = false
  var namingTemplate = "{name}-{width}"

  var targetBytes: Int? { targetSizeKB.map { $0 * 1000 } }
  var isResponsive: Bool { !responsiveWidths.isEmpty }

  var validationMessage: String? {
    if let size = targetSizeKB, !(1...1_000_000).contains(size) {
      return "Enter a file-size limit between 1 and 1,000,000 KB."
    }
    if !(0...1).contains(minimumQuality) { return "Minimum quality must be between 0 and 100%." }
    if responsiveWidths.count > 8 || responsiveWidths.contains(where: { !(1...32768).contains($0) })
    {
      return "Enter up to eight widths between 1 and 32,768 pixels."
    }
    if isResponsive {
      if !namingTemplate.contains("{name}") || !namingTemplate.contains("{width}") {
        return "The filename template must contain {name} and {width}."
      }
      let remainder = namingTemplate.replacingOccurrences(of: "{name}", with: "")
        .replacingOccurrences(of: "{width}", with: "")
      if remainder.contains(where: { "/\\:{}".contains($0) || $0.isNewline || $0.asciiValue == 0 })
      {
        return "Use a filename, without folders or unsupported placeholders."
      }
    }
    return nil
  }
}
