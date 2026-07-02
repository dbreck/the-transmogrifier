import SwiftUI
import UniformTypeIdentifiers
import AppKit

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

struct ProcessingSettings {
    let dpi: Int
    let maxWidth: Int
    let maxHeight: Int
    let compressionLevel: Float
    let outputFormat: String
    let outputFolder: String
    let saveAlongsideOriginals: Bool
    let preserveFolderStructure: Bool
    let collisionPolicy: CollisionPolicy
}

struct ProcessingSettingsView: View {
    @ObservedObject var fileSelectionViewModel: FileSelectionViewModel
    @ObservedObject var presetManager: PresetManager
    @ObservedObject var settingsViewModel: ProcessingSettingsViewModel

    @State private var newPresetName: String = ""
    @State private var showingSavePresetAlert = false
    @State private var isWebPEncodingAvailable = ImageProcessingEngine.isWebPEncodingAvailable()
    @State private var quickPresetDropTarget: QuickPreset? = nil

    private var destinationSelection: Binding<Bool> {
        Binding(
            get: { !settingsViewModel.saveAlongsideOriginals },
            set: { settingsViewModel.saveAlongsideOriginals = !$0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Row 1: Core size and format controls
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
                        && !isWebPEncodingAvailable
                    {
                        Text("WebP not supported on this macOS. Will fall back to JPG.")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Row 2: Compression and quick presets side by side
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Compression: \(Int(settingsViewModel.compression))%")
                        .font(.label)
                        .foregroundColor(.gray400)

                    Slider(value: $settingsViewModel.compression, in: 0...100, step: 1)
                        .tint(.blue600)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Quick Presets")
                        .font(.label)
                        .foregroundColor(.gray400)

                    HStack(spacing: Spacing.xs) {
                        ForEach(QuickPreset.allCases, id: \.self) { preset in
                            QuickPresetChip(
                                title: preset.title,
                                subtitle: preset.subtitle,
                                isDropTarget: quickPresetDropTarget == preset,
                                onSelect: { applyQuickPreset(preset) },
                                onDrop: { providers in
                                    applyQuickPreset(preset)
                                    return handleQuickPresetDrop(providers, preset: preset)
                                },
                                onDropTargetChanged: { isTargeted in
                                    quickPresetDropTarget = isTargeted ? preset : nil
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Row 3: Destination, collision policy, and presets in one horizontal band
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Destination")
                        .font(.label)
                        .foregroundColor(.gray400)

                    Picker("Destination", selection: destinationSelection) {
                        Text("Output folder").tag(true)
                        Text("Same folder").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .colorScheme(.dark)

                    if !settingsViewModel.saveAlongsideOriginals {
                        HStack(spacing: Spacing.xs) {
                            TransmogrifierTextField(
                                placeholder: "Choose folder...", text: $settingsViewModel.outputFolder
                            )
                            .frame(maxWidth: .infinity)

                            TransmogrifierButton("Browse", style: .secondary) {
                                selectOutputFolder()
                            }
                            .frame(width: 104)
                        }
                    }

                    Toggle(isOn: $settingsViewModel.preserveFolderStructure) {
                        Text("Preserve source folder structure")
                            .font(.caption)
                            .foregroundColor(.gray400)
                    }
                    .toggleStyle(.switch)
                    .tint(.blue600)
                    .disabled(settingsViewModel.saveAlongsideOriginals)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("If File Exists")
                        .font(.label)
                        .foregroundColor(.gray400)

                    Picker("", selection: $settingsViewModel.collisionPolicy) {
                        ForEach(CollisionPolicy.allCases, id: \.self) { policy in
                            Text(policy.label).tag(policy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .colorScheme(.dark)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Presets")
                        .font(.label)
                        .foregroundColor(.gray400)

                    HStack(spacing: Spacing.xs) {
                        Menu {
                            ForEach(presetManager.presets) { preset in
                                Button(preset.name) {
                                    settingsViewModel.selectedPreset = preset.name
                                    settingsViewModel.applyCustomPreset(preset)
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
                            if let preset = presetManager.presets.first(where: {
                                $0.name == settingsViewModel.selectedPreset
                            }) {
                                settingsViewModel.applyCustomPreset(preset)
                            }
                        }
                        .frame(width: 88)
                        .disabled(settingsViewModel.selectedPreset.isEmpty)

                        TransmogrifierButton("Save", style: .secondary) {
                            showingSavePresetAlert = true
                        }
                        .frame(width: 88)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if settingsViewModel.saveAlongsideOriginals {
                Text("Files save next to originals. Switch Destination to Output folder for a custom path.")
                    .font(.caption)
                    .foregroundColor(.gray500)
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

        // Saving under an existing user preset's name updates it in place.
        let existing = presetManager.presets.first {
            $0.name == trimmedName && !$0.isDefault
        }
        let preset = Preset(
            id: existing?.id ?? UUID(),
            name: trimmedName,
            dpi: Int(settingsViewModel.targetResolution) ?? 72,
            maxWidth: Int(settingsViewModel.maxWidth) ?? 0,
            maxHeight: Int(settingsViewModel.maxHeight) ?? 0,
            // Store encoder quality [0..1]
            compressionLevel: Float(1.0 - (settingsViewModel.compression / 100.0)),
            outputFormat: settingsViewModel.outputFormat,
            outputFolder: settingsViewModel.outputFolder,
            saveAlongsideOriginals: settingsViewModel.saveAlongsideOriginals,
            preserveFolderStructure: settingsViewModel.preserveFolderStructure,
            collisionPolicy: settingsViewModel.collisionPolicy
        )

        presetManager.savePreset(preset)
        newPresetName = ""
    }

    private enum QuickPreset: CaseIterable {
        case web
        case social
        case retina

        var title: String {
            switch self {
            case .web: return "Web"
            case .social: return "Social"
            case .retina: return "Retina"
            }
        }

        var subtitle: String {
            switch self {
            case .web: return "WebP • 1920w"
            case .social: return "JPG • 1080"
            case .retina: return "PNG • Hi-res"
            }
        }
    }

    private func applyQuickPreset(_ preset: QuickPreset) {
        switch preset {
        case .web:
            settingsViewModel.targetResolution = "72"
            settingsViewModel.maxWidth = "1920"
            settingsViewModel.maxHeight = ""
            settingsViewModel.outputFormat = "WebP"
            settingsViewModel.compression = 30
        case .social:
            settingsViewModel.targetResolution = "72"
            settingsViewModel.maxWidth = "1080"
            settingsViewModel.maxHeight = "1080"
            settingsViewModel.outputFormat = "JPG"
            settingsViewModel.compression = 35
        case .retina:
            settingsViewModel.targetResolution = "144"
            settingsViewModel.maxWidth = "3840"
            settingsViewModel.maxHeight = ""
            settingsViewModel.outputFormat = "PNG"
            settingsViewModel.compression = 10
        }
    }

    private func handleQuickPresetDrop(_ providers: [NSItemProvider], preset: QuickPreset) -> Bool {
        var accepted = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                    item,
                    _ in
                    let url = (item as? URL) ?? (item as? NSURL as URL?) ?? {
                        if let data = item as? Data {
                            return URL(dataRepresentation: data, relativeTo: nil)
                        }
                        if let path = item as? String { return URL(fileURLWithPath: path) }
                        return nil
                    }()
                    guard let url else { return }
                    Task { @MainActor in
                        fileSelectionViewModel.importURLs([url], replaceExisting: false)
                    }
                }
            }
        }

        return accepted
    }
}

private struct QuickPresetChip: View {
    let title: String
    let subtitle: String
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool
    let onDropTargetChanged: (Bool) -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.label)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray400)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isDropTarget ? .blue900.opacity(0.6) : .gray700)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isDropTarget ? .blue600 : .gray600, lineWidth: 1)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onDrop(
            of: [UTType.fileURL, UTType.image, UTType.folder],
            isTargeted: Binding(
                get: { isDropTarget },
                set: { onDropTargetChanged($0) }
            ),
            perform: onDrop
        )
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
