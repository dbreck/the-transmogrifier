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

    func validateOutputFolder() -> Bool {
        return !outputFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func getProcessingSettings() -> ProcessingSettings? {
        guard validateOutputFolder() else {
            return nil
        }

        return ProcessingSettings(
            dpi: Int16(targetResolution) ?? 72,
            maxWidth: Int16(maxWidth) ?? 0,
            maxHeight: Int16(maxHeight) ?? 0,
            // Map UI compression% (higher = more compression) to encoder quality (lower = more compression)
            compressionLevel: Float(1.0 - (compression / 100.0)),
            outputFormat: outputFormat,
            outputFolder: outputFolder
        )
    }

    // New: Preview settings do not require an output folder
    func getProcessingSettingsForPreview() -> ProcessingSettings {
        return ProcessingSettings(
            dpi: Int16(targetResolution) ?? 72,
            maxWidth: Int16(maxWidth) ?? 0,
            maxHeight: Int16(maxHeight) ?? 0,
            compressionLevel: Float(1.0 - (compression / 100.0)),
            outputFormat: outputFormat,
            outputFolder: outputFolder  // not used by preview
        )
    }

    func applyPreset(_ presetName: String) {
        switch presetName {
        case "High Quality":
            targetResolution = "300"
            // High quality => low compression amount
            compression = 10.0
            outputFormat = "PNG"
        case "Web Optimized":
            targetResolution = "72"
            // Medium quality => medium compression amount
            compression = 25.0
            outputFormat = "JPG"
            maxWidth = "1920"
        case "Print Ready":
            targetResolution = "300"
            compression = 15.0
            outputFormat = "PNG"
        default:
            break
        }
    }

    func applyCustomPreset(_ preset: Preset) {
        targetResolution = "\(preset.dpi)"
        maxWidth = preset.maxWidth == 0 ? "" : "\(preset.maxWidth)"
        maxHeight = preset.maxHeight == 0 ? "" : "\(preset.maxHeight)"
        // Preset stores encoder quality [0..1]; UI shows compression amount [%]
        compression = Double((1.0 - preset.compressionLevel) * 100)
        outputFormat = preset.outputFormat
        outputFolder = preset.outputFolder
    }
}
