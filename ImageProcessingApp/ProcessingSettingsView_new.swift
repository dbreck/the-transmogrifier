import SwiftUI

struct ProcessingSettingsView: View {
    @ObservedObject var fileSelectionViewModel: FileSelectionViewModel
    @ObservedObject var presetManager: PresetManager
    
    @State private var targetResolution: String = "72"
    @State private var maxWidth: String = ""
    @State private var maxHeight: String = ""
    @State private var compression: Double = 80.0
    @State private var outputFormat: String = "JPG"
    @State private var outputFolder: String = ""
    @State private var selectedPreset: String = ""
    @State private var newPresetName: String = ""
    @State private var showingSavePresetAlert = false
    @State private var showingOutputFolderAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Top Row: Resolution, Max Width, Max Height, Output Format (4 columns)
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Resolution (DPI)")
                        .font(.caption)
                        .foregroundColor(.gray400)
                    TransmogrifierTextField(placeholder: "72", text: $targetResolution)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Max Width")
                        .font(.caption)
                        .foregroundColor(.gray400)
                    TransmogrifierTextField(placeholder: "Auto", text: $maxWidth)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Max Height")
                        .font(.caption)
                        .foregroundColor(.gray400)
                    TransmogrifierTextField(placeholder: "Auto", text: $maxHeight)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Output Format")
                        .font(.caption)
                        .foregroundColor(.gray400)
                    Picker("Format", selection: $outputFormat) {
                        Text("JPG").tag("JPG")
                        Text("PNG").tag("PNG")
                        Text("WebP").tag("WebP")
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Compression Slider
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Compression: \(Int(compression))%")
                    .font(.caption)
                    .foregroundColor(.gray400)
                
                Slider(value: $compression, in: 0...100, step: 1)
                    .tint(.blue600)
            }
            
            // Bottom Row: Output Folder and Presets (2 columns)
            HStack(spacing: Spacing.lg) {
                // Output Folder
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Output Folder")
                        .font(.caption)
                        .foregroundColor(.gray400)
                    
                    HStack(spacing: Spacing.xs) {
                        TransmogrifierTextField(placeholder: "Choose folder...", text: $outputFolder)
                            .frame(maxWidth: .infinity)
                        
                        Button("Browse") {
                            showingOutputFolderAlert = true
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(.gray700)
                        .foregroundColor(.gray300)
                        .cornerRadius(6)
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Presets
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Presets")
                        .font(.caption)
                        .foregroundColor(.gray400)
                    
                    HStack(spacing: Spacing.xs) {
                        Menu {
                            Button("High Quality") { 
                                selectedPreset = "High Quality"
                                applyPreset("High Quality")
                            }
                            Button("Web Optimized") { 
                                selectedPreset = "Web Optimized"
                                applyPreset("Web Optimized")
                            }
                            Button("Print Ready") { 
                                selectedPreset = "Print Ready"
                                applyPreset("Print Ready")
                            }
                            
                            if !presetManager.presets.isEmpty {
                                Divider()
                                ForEach(presetManager.presets, id: \.name) { preset in
                                    Button(preset.name) {
                                        selectedPreset = preset.name
                                        applyCustomPreset(preset)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedPreset.isEmpty ? "Choose preset..." : selectedPreset)
                                    .foregroundColor(selectedPreset.isEmpty ? .gray500 : .white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray400)
                                    .font(.caption)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(.gray700)
                            .cornerRadius(6)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("Apply") {
                            if !selectedPreset.isEmpty {
                                if let preset = presetManager.presets.first(where: { $0.name == selectedPreset }) {
                                    applyCustomPreset(preset)
                                } else {
                                    applyPreset(selectedPreset)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(selectedPreset.isEmpty ? .gray800 : .blue600)
                        .foregroundColor(selectedPreset.isEmpty ? .gray500 : .white)
                        .cornerRadius(6)
                        .font(.caption)
                        .disabled(selectedPreset.isEmpty)
                        
                        Button("Save") {
                            showingSavePresetAlert = true
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(.gray700)
                        .foregroundColor(.gray300)
                        .cornerRadius(6)
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Save Preset", isPresented: $showingSavePresetAlert) {
            TextField("Preset name", text: $newPresetName)
            Button("Save") {
                savePreset()
                newPresetName = ""
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a name for this preset")
        }
        .alert("Output Folder Required", isPresented: $showingOutputFolderAlert) {
            Button("OK") { }
        } message: {
            Text("Please select an output folder for processed images")
        }
    }
    
    private func selectOutputFolder() {
        Task {
            let folderURL = await fileSelectionViewModel.selectOutputFolder()
            if let folderURL = folderURL {
                outputFolder = folderURL.path
            }
        }
    }
    
    private func savePreset() {
        guard !newPresetName.isEmpty else { return }
        
        let preset = Preset(
            name: newPresetName,
            dpi: Int16(targetResolution) ?? 72,
            maxWidth: Int16(maxWidth) ?? 0,
            maxHeight: Int16(maxHeight) ?? 0,
            compressionLevel: Float(compression / 100.0),
            outputFormat: outputFormat,
            outputFolder: outputFolder
        )
        
        presetManager.presets.append(preset)
        newPresetName = ""
    }
    
    private func applySelectedPreset() {
        guard !selectedPreset.isEmpty,
              let preset = presetManager.presets.first(where: { $0.id.uuidString == selectedPreset })
        else { return }
        
        targetResolution = "\(preset.dpi)"
        maxWidth = preset.maxWidth == 0 ? "" : "\(preset.maxWidth)"
        maxHeight = preset.maxHeight == 0 ? "" : "\(preset.maxHeight)"
        compression = Double(preset.compressionLevel * 100)
        outputFormat = preset.outputFormat
        outputFolder = preset.outputFolder
    }
    
    private func applyPreset(_ presetName: String) {
        switch presetName {
        case "High Quality":
            targetResolution = "300"
            compression = 95.0
            outputFormat = "PNG"
        case "Web Optimized":
            targetResolution = "72"
            compression = 75.0
            outputFormat = "JPG"
            maxWidth = "1920"
        case "Print Ready":
            targetResolution = "300"
            compression = 90.0
            outputFormat = "PNG"
        default:
            break
        }
    }
    
    private func applyCustomPreset(_ preset: Preset) {
        targetResolution = "\(preset.dpi)"
        maxWidth = preset.maxWidth == 0 ? "" : "\(preset.maxWidth)"
        maxHeight = preset.maxHeight == 0 ? "" : "\(preset.maxHeight)"
        compression = Double(preset.compressionLevel * 100)
        outputFormat = preset.outputFormat
        outputFolder = preset.outputFolder
    }
}

#Preview {
    ProcessingSettingsView(
        fileSelectionViewModel: FileSelectionViewModel(),
        presetManager: PresetManager()
    )
    .frame(width: 400)
    .background(.gray900)
}
