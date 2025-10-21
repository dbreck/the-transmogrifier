import Foundation

@MainActor
class PresetManager: ObservableObject {
    @Published var presets: [Preset] = []
    @Published var selectedPreset: Preset?
    
    private let userDefaults = UserDefaults.standard
    private let presetsKey = "SavedPresets"
    
    init() {
        loadPresets()
        // DEBUG LOG: Initialize with first preset to avoid nil selection
        if !presets.isEmpty {
            selectedPreset = presets.first
        }
    }
    
    /// Load presets from storage
    func loadPresets() {
        // Start with default presets
        presets = Preset.defaultPresets
        
        // Load user presets from UserDefaults
        if let data = userDefaults.data(forKey: presetsKey),
           let userPresets = try? JSONDecoder().decode([Preset].self, from: data) {
            // Add user presets, avoiding duplicates
            for preset in userPresets {
                if !presets.contains(where: { $0.id == preset.id }) {
                    presets.append(preset)
                }
            }
        }
    }
    
    /// Save presets to storage
    func savePresets() {
        // Filter out default presets as they're hardcoded
        let userPresets = presets.filter { !$0.isDefault }
        
        if let data = try? JSONEncoder().encode(userPresets) {
            userDefaults.set(data, forKey: presetsKey)
        }
    }
    
    /// Save a new preset
    /// - Parameter preset: The preset to save
    func savePreset(_ preset: Preset) {
        // Check if preset already exists
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            // Update existing preset
            presets[index] = preset
        } else {
            // Add new preset
            presets.append(preset)
        }
        
        // Save to storage
        savePresets()
    }
    
    /// Delete a preset
    /// - Parameter preset: The preset to delete
    func deletePreset(_ preset: Preset) {
        // Don't allow deletion of default presets
        guard !preset.isDefault else { return }
        
        presets.removeAll { $0.id == preset.id }
        savePresets()
        
        // Clear selection if it was the deleted preset
        if selectedPreset?.id == preset.id {
            selectedPreset = nil
        }
    }
    
    /// Apply a preset to update UI parameters
    /// - Parameter preset: The preset to apply
    func applyPreset(_ preset: Preset) {
        selectedPreset = preset
    }
}