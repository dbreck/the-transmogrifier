import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProcessingSettingsView: View {
  @ObservedObject var fileSelectionViewModel: FileSelectionViewModel
  @ObservedObject var presetManager: PresetManager
  @ObservedObject var settingsViewModel: ProcessingSettingsViewModel
  @State private var newPresetName = ""
  @State private var showingSavePresetAlert = false
  @State private var quickPresetDropTarget: QuickPreset?
  @State private var showsAdvanced = false
  @AppStorage("QuickConvertPresetID") private var quickConvertPresetID = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      presetControls
      Picker("Format", selection: $settingsViewModel.outputFormat) {
        Text("JPG").tag("JPG")
        Text("PNG").tag("PNG")
        Text("WebP").tag("WebP")
      }.pickerStyle(.segmented)
      HStack(alignment: .top, spacing: 16) {
        labeledField("Max width (px)", text: $settingsViewModel.maxWidth, placeholder: "Auto")
        labeledField("Max height (px)", text: $settingsViewModel.maxHeight, placeholder: "Auto")
      }
      if settingsViewModel.outputFormat == "PNG" {
        Label("PNG is lossless. Quality adjustments do not apply.", systemImage: "checkmark.seal")
          .font(.callout).foregroundStyle(.secondary)
      } else {
        VStack(spacing: 4) {
          HStack {
            Text("Quality: \(Int(settingsViewModel.quality.rounded()))%")
            Spacer()
            Text("Higher quality → larger files").foregroundStyle(.secondary)
          }.font(.callout)
          Slider(value: $settingsViewModel.quality, in: 0...100, step: 1).accessibilityLabel(
            "Export quality")
        }
      }
      Toggle("Keep each image under a file-size limit", isOn: $settingsViewModel.usesTargetSize)
      if settingsViewModel.usesTargetSize {
        HStack(spacing: 16) {
          labeledField("Limit (KB)", text: $settingsViewModel.targetSizeKB, placeholder: "200")
          if settingsViewModel.outputFormat != "PNG" {
            VStack(alignment: .leading) {
              Text("Minimum quality: \(Int(settingsViewModel.minimumQuality))%")
              Slider(value: $settingsViewModel.minimumQuality, in: 0...100, step: 1)
                .accessibilityLabel("Minimum quality")
            }.frame(maxWidth: .infinity)
          }
        }
        Text(
          "Dimensions stay within your caps. Images that cannot meet the limit are reported without writing a file."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      Toggle("Create a responsive image pack", isOn: $settingsViewModel.createsResponsivePack)
        .onChange(of: settingsViewModel.createsResponsivePack) { enabled in
          if enabled { settingsViewModel.outputFormat = "WebP" }
        }
      if settingsViewModel.createsResponsivePack {
        HStack(spacing: 16) {
          labeledField(
            "Widths (px)", text: $settingsViewModel.responsiveWidths, placeholder: "640, 1280, 1920"
          )
          labeledField(
            "Filename template", text: $settingsViewModel.namingTemplate,
            placeholder: "{name}-{width}")
        }
        Toggle("Include JPG fallbacks", isOn: $settingsViewModel.includeJPEGFallback)
        Text(
          "WebP variants use actual output widths. Smaller originals are never enlarged; duplicate sizes are exported once."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      HStack {
        Text("Save to").font(.callout)
        Picker("Destination", selection: $settingsViewModel.saveAlongsideOriginals) {
          Text("Beside originals").tag(true)
          Text("Output folder").tag(false)
        }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)
        Spacer()
      }
      if !settingsViewModel.saveAlongsideOriginals {
        HStack {
          TextField("Choose an output folder", text: $settingsViewModel.outputFolder)
            .textFieldStyle(.roundedBorder).accessibilityLabel("Output folder path")
          Button("Browse…", action: selectOutputFolder)
        }
      }
      DisclosureGroup("Advanced", isExpanded: $showsAdvanced) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 16) {
            labeledField(
              "Resolution (DPI)", text: $settingsViewModel.targetResolution, placeholder: "72")
            Picker("If a file exists", selection: $settingsViewModel.collisionPolicy) {
              ForEach(CollisionPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
            }.frame(maxWidth: .infinity)
          }
          Toggle(
            "Preserve source folder structure", isOn: $settingsViewModel.preserveFolderStructure
          )
          .disabled(settingsViewModel.saveAlongsideOriginals)
          Picker("Dock quick convert", selection: $quickConvertPresetID) {
            Text("Open for review").tag("")
            ForEach(presetManager.presets) { preset in Text(preset.name).tag(preset.id.uuidString) }
          }
          Text(
            "Drop files or folders onto the app icon. A selected preset converts them automatically using its saved destination and collision rules."
          )
          .font(.caption).foregroundStyle(.secondary)
        }.padding(.top, 10)
      }
      if let message = settingsViewModel.validationMessage {
        Label(message, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(
          .orange)
      }
    }
    .alert("Save Preset", isPresented: $showingSavePresetAlert) {
      TextField("Preset name", text: $newPresetName)
      Button("Save") {
        savePreset()
        newPresetName = ""
      }
      .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      Button("Cancel", role: .cancel) { newPresetName = "" }
    } message: {
      Text("Saves quality, dimensions, export options and destination together.")
    }
  }

  private var presetControls: some View {
    VStack(spacing: 10) {
      HStack(spacing: 8) {
        ForEach(QuickPreset.allCases, id: \.self) { preset in
          QuickPresetChip(
            title: preset.title, subtitle: preset.subtitle,
            isDropTarget: quickPresetDropTarget == preset,
            onSelect: { applyQuickPreset(preset) },
            onDrop: { providers in
              applyQuickPreset(preset)
              return handleQuickPresetDrop(providers, preset: preset)
            },
            onDropTargetChanged: { quickPresetDropTarget = $0 ? preset : nil })
        }
      }
      HStack {
        Menu(
          settingsViewModel.selectedPreset.isEmpty
            ? "Saved presets" : settingsViewModel.selectedPreset
        ) {
          ForEach(presetManager.presets) { preset in
            Button(preset.name) { settingsViewModel.applyCustomPreset(preset) }
          }
        }.frame(maxWidth: 180)
        Spacer()
        Button("Save…") { showingSavePresetAlert = true }.disabled(
          settingsViewModel.validationMessage != nil)
      }
    }
  }
  private func labeledField(_ title: String, text: Binding<String>, placeholder: String)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.callout)
      TextField(placeholder, text: text).textFieldStyle(.roundedBorder).accessibilityLabel(title)
    }.frame(maxWidth: .infinity)
  }

  private func selectOutputFolder() {
    Task {
      let folderURL = await fileSelectionViewModel.selectOutputFolder()
      if let folderURL = folderURL {
        settingsViewModel.setOutputFolder(folderURL)
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
    let preset = settingsViewModel.makePreset(name: trimmedName, id: existing?.id ?? UUID())

    presetManager.savePreset(preset)
    settingsViewModel.selectedPreset = trimmedName
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
    settingsViewModel.createsResponsivePack = false
    settingsViewModel.usesTargetSize = false
    settingsViewModel.selectedPreset = ""
    switch preset {
    case .web:
      settingsViewModel.targetResolution = "72"
      settingsViewModel.maxWidth = "1920"
      settingsViewModel.maxHeight = ""
      settingsViewModel.outputFormat = "WebP"
      settingsViewModel.quality = 70
    case .social:
      settingsViewModel.targetResolution = "72"
      settingsViewModel.maxWidth = "1080"
      settingsViewModel.maxHeight = "1080"
      settingsViewModel.outputFormat = "JPG"
      settingsViewModel.quality = 65
    case .retina:
      settingsViewModel.targetResolution = "144"
      settingsViewModel.maxWidth = "3840"
      settingsViewModel.maxHeight = ""
      settingsViewModel.outputFormat = "PNG"
      settingsViewModel.quality = 90
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
          let url =
            (item as? URL) ?? (item as? NSURL as URL?)
            ?? {
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
