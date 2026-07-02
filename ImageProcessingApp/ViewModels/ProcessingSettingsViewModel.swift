import SwiftUI

// Ensure model types are visible to this file
// (ProcessingSettings is declared in ProcessingSettingsView.swift in this project)

@MainActor
class ProcessingSettingsViewModel: ObservableObject {
    @Published var targetResolution: String = "72"
    @Published var maxWidth: String = ""
    @Published var maxHeight: String = ""
    @Published var compression: Double = 80.0
    @Published var outputFormat: String = "WebP"
    @Published var outputFolder: String = ""
    @Published var selectedPreset: String = ""
    @Published var saveAlongsideOriginals: Bool = false
    @Published var preserveFolderStructure: Bool = true
    @Published var collisionPolicy: CollisionPolicy = .rename

    var hasExplicitOutputFolder: Bool {
        !outputFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Treat an empty output folder as "save alongside originals".
    var effectivelySavesAlongsideOriginals: Bool {
        saveAlongsideOriginals || !hasExplicitOutputFolder
    }

    func getProcessingSettings() -> ProcessingSettings {
        ProcessingSettings(
            dpi: Int(targetResolution) ?? 72,
            maxWidth: Int(maxWidth) ?? 0,
            maxHeight: Int(maxHeight) ?? 0,
            // Map UI compression% (higher = more compression) to encoder quality (lower = more compression)
            compressionLevel: Float(1.0 - (compression / 100.0)),
            outputFormat: outputFormat,
            outputFolder: outputFolder,
            saveAlongsideOriginals: saveAlongsideOriginals,
            preserveFolderStructure: preserveFolderStructure,
            collisionPolicy: collisionPolicy
        )
    }

    // New: Preview settings do not require an output folder
    func getProcessingSettingsForPreview() -> ProcessingSettings {
        return ProcessingSettings(
            dpi: Int(targetResolution) ?? 72,
            maxWidth: Int(maxWidth) ?? 0,
            maxHeight: Int(maxHeight) ?? 0,
            compressionLevel: Float(1.0 - (compression / 100.0)),
            outputFormat: outputFormat,
            outputFolder: outputFolder,  // not used by preview
            saveAlongsideOriginals: saveAlongsideOriginals,
            preserveFolderStructure: preserveFolderStructure,
            collisionPolicy: collisionPolicy
        )
    }

    func applyCustomPreset(_ preset: Preset) {
        targetResolution = "\(preset.dpi)"
        maxWidth = preset.maxWidth == 0 ? "" : "\(preset.maxWidth)"
        maxHeight = preset.maxHeight == 0 ? "" : "\(preset.maxHeight)"
        // Preset stores encoder quality [0..1]; UI shows compression amount [%]
        compression = Double((1.0 - preset.compressionLevel) * 100)
        outputFormat = preset.outputFormat
        outputFolder = preset.outputFolder
        saveAlongsideOriginals = preset.saveAlongsideOriginals
        preserveFolderStructure = preset.preserveFolderStructure
        collisionPolicy = preset.collisionPolicy
    }
}
