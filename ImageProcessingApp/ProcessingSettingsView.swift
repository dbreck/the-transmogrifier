import SwiftUI

struct ProcessingSettings {
    let dpi: Int16
    let maxWidth: Int16
    let maxHeight: Int16
    let compressionLevel: Float
    let outputFormat: String
    let outputFolder: String
}

struct ProcessingSettingsView: View {
    @ObservedObject var fileSelectionViewModel: FileSelectionViewModel
    @ObservedObject var presetManager: PresetManager
    @ObservedObject var settingsViewModel: ProcessingSettingsViewModel

    @State private var newPresetName: String = ""
    @State private var showingSavePresetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Top Row: Resolution, Max Width, Max Height, Output Format (4 columns)
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Resolution (DPI)")
                        .font(.label)
                        .foregroundColor(.gray400)
                    TransmogrifierTextField(
                        placeholder: "72", text: $settingsViewModel.targetResolution)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Max Width")
                        .font(.label)
                        .foregroundColor(.gray400)
                    TransmogrifierTextField(placeholder: "Auto", text: $settingsViewModel.maxWidth)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Max Height")
                        .font(.label)
                        .foregroundColor(.gray400)
                    TransmogrifierTextField(placeholder: "Auto", text: $settingsViewModel.maxHeight)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Output Format")
                        .font(.label)
                        .foregroundColor(.gray400)
                    Picker("Format", selection: $settingsViewModel.outputFormat) {
                        Text("JPG").tag("JPG")
                        Text("PNG").tag("PNG")
                        Text("WebP").tag("WebP")
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)
                    if settingsViewModel.outputFormat == "WebP"
                        && !ImageProcessingEngine.isWebPEncodingAvailable()
                    {
                        Text("WebP not supported on this macOS. Will fall back to JPG.")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Compression Slider
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Compression: \(Int(settingsViewModel.compression))%")
                    .font(.label)
                    .foregroundColor(.gray400)

                Slider(value: $settingsViewModel.compression, in: 0...100, step: 1)
                    .tint(.blue600)
            }

            // Bottom Row: Output Folder and Presets (2 columns)
            HStack(spacing: Spacing.lg) {
                // Output Folder
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Output Folder")
                        .font(.label)
                        .foregroundColor(.gray400)

                    HStack(spacing: Spacing.xs) {
                        TransmogrifierTextField(
                            placeholder: "Choose folder...", text: $settingsViewModel.outputFolder
                        )
                        .frame(maxWidth: .infinity)

                        TransmogrifierButton("Browse", style: .secondary) {
                            selectOutputFolder()
                        }
                        .frame(width: 120)
                    }
                }
                .frame(maxWidth: .infinity)

                // Presets
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Presets")
                        .font(.label)
                        .foregroundColor(.gray400)

                    HStack(spacing: Spacing.xs) {
                        Menu {
                            Button("High Quality") {
                                settingsViewModel.selectedPreset = "High Quality"
                                settingsViewModel.applyPreset("High Quality")
                            }
                            Button("Web Optimized") {
                                settingsViewModel.selectedPreset = "Web Optimized"
                                settingsViewModel.applyPreset("Web Optimized")
                            }
                            Button("Print Ready") {
                                settingsViewModel.selectedPreset = "Print Ready"
                                settingsViewModel.applyPreset("Print Ready")
                            }

                            if !presetManager.presets.isEmpty {
                                Divider()
                                ForEach(presetManager.presets, id: \.name) { preset in
                                    Button(preset.name) {
                                        settingsViewModel.selectedPreset = preset.name
                                        settingsViewModel.applyCustomPreset(preset)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(
                                    settingsViewModel.selectedPreset.isEmpty
                                        ? "Choose preset..." : settingsViewModel.selectedPreset
                                )
                                .foregroundColor(
                                    settingsViewModel.selectedPreset.isEmpty ? .gray400 : .white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray400)
                                    .font(.caption)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(.gray700)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6).stroke(.gray600, lineWidth: 1)
                            )
                            .cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(maxWidth: .infinity)

                        TransmogrifierButton(
                            "Apply",
                            style: settingsViewModel.selectedPreset.isEmpty ? .secondary : .primary
                        ) {
                            if !settingsViewModel.selectedPreset.isEmpty {
                                if let preset = presetManager.presets.first(where: {
                                    $0.name == settingsViewModel.selectedPreset
                                }) {
                                    settingsViewModel.applyCustomPreset(preset)
                                } else {
                                    settingsViewModel.applyPreset(settingsViewModel.selectedPreset)
                                }
                            }
                        }
                        .frame(width: 120)
                        .disabled(settingsViewModel.selectedPreset.isEmpty)

                        TransmogrifierButton("Save", style: .secondary) {
                            showingSavePresetAlert = true
                        }
                        .frame(width: 120)
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
            .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newPresetName = ""
            }
        } message: {
            Text("Enter a name for this preset")
        }
    }

    private func selectOutputFolder() {
        Task {
            let folderURL = await fileSelectionViewModel.selectOutputFolder()
            if let folderURL = folderURL {
                settingsViewModel.outputFolder = folderURL.path
            }
        }
    }

    private func savePreset() {
        let trimmedName = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let preset = Preset(
            name: trimmedName,
            dpi: Int16(settingsViewModel.targetResolution) ?? 72,
            maxWidth: Int16(settingsViewModel.maxWidth) ?? 0,
            maxHeight: Int16(settingsViewModel.maxHeight) ?? 0,
            // Store encoder quality [0..1]
            compressionLevel: Float(1.0 - (settingsViewModel.compression / 100.0)),
            outputFormat: settingsViewModel.outputFormat,
            outputFolder: settingsViewModel.outputFolder
        )

        presetManager.presets.append(preset)
        presetManager.savePresets()
        newPresetName = ""
    }
}

#Preview {
    ProcessingSettingsView(
        fileSelectionViewModel: FileSelectionViewModel(),
        presetManager: PresetManager(),
        settingsViewModel: ProcessingSettingsViewModel()
    )
    .frame(width: 400)
    .background(.gray900)
}
