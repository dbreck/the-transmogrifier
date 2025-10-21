import Foundation

// DEBUG LOG: Adding Hashable conformance to fix Picker errors
struct Preset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var dpi: Int16
    var maxWidth: Int16
    var maxHeight: Int16
    var compressionLevel: Float
    var outputFormat: String
    var outputFolder: String
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        dpi: Int16,
        maxWidth: Int16,
        maxHeight: Int16,
        compressionLevel: Float,
        outputFormat: String,
        outputFolder: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.dpi = dpi
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.compressionLevel = compressionLevel
        self.outputFormat = outputFormat
        self.outputFolder = outputFolder
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func update(
        name: String? = nil,
        dpi: Int16? = nil,
        maxWidth: Int16? = nil,
        maxHeight: Int16? = nil,
        compressionLevel: Float? = nil,
        outputFormat: String? = nil,
        outputFolder: String? = nil
    ) {
        if let name = name { self.name = name }
        if let dpi = dpi { self.dpi = dpi }
        if let maxWidth = maxWidth { self.maxWidth = maxWidth }
        if let maxHeight = maxHeight { self.maxHeight = maxHeight }
        if let compressionLevel = compressionLevel { self.compressionLevel = compressionLevel }
        if let outputFormat = outputFormat { self.outputFormat = outputFormat }
        if let outputFolder = outputFolder { self.outputFolder = outputFolder }
        self.updatedAt = Date()
    }
}

// Default presets
extension Preset {
    static let defaultPresets: [Preset] = [
        Preset(
            name: "High Quality",
            dpi: 300,
            maxWidth: 0,
            maxHeight: 0,
            compressionLevel: 0.9,
            outputFormat: "WebP",
            outputFolder: "",
            isDefault: true
        ),
        Preset(
            name: "Web Optimized",
            dpi: 72,
            maxWidth: 1920,
            maxHeight: 1080,
            compressionLevel: 0.8,
            outputFormat: "WebP",
            outputFolder: "",
            isDefault: true
        ),
        Preset(
            name: "Social Media",
            dpi: 72,
            maxWidth: 1080,
            maxHeight: 1080,
            compressionLevel: 0.7,
            outputFormat: "JPG",
            outputFolder: "",
            isDefault: true
        )
    ]
}