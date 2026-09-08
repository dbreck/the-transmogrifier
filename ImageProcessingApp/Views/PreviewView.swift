import AppKit
import SwiftUI

struct PreviewView: View {
  @ObservedObject var fileSelectionViewModel: FileSelectionViewModel
  @ObservedObject var processingSettingsViewModel: ProcessingSettingsViewModel
  @StateObject private var model = PreviewViewModel()
  @State private var revision = 0
  @State private var showsComparison = false

  private var taskKey: String {
    "\(fileSelectionViewModel.selectedFileForPreview?.path ?? "")|\(processingSettingsViewModel.getProcessingSettings().previewIdentity)|\(processingSettingsViewModel.previewValidationMessage ?? "")|\(revision)"
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(
          processingSettingsViewModel.createsResponsivePack
            ? "Largest variant · live preview" : "Live preview"
        )
        .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button {
          revision += 1
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(fileSelectionViewModel.selectedFileForPreview == nil)
        Button("Compare") { showsComparison = true }
          .disabled(model.processedImage == nil)
      }
      if model.isLoading {
        ProgressView("Updating preview…").frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = model.errorMessage {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle").font(.title2)
          Text(error).multilineTextAlignment(.center)
          Button("Try again") { revision += 1 }
        }.foregroundStyle(.orange).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let original = model.originalImage, let processed = model.processedImage {
        HStack(spacing: 16) {
          imageCard("Original", image: original, metadata: model.imageMetadata)
          imageCard("Export", image: processed, metadata: model.processedImageMetadata)
        }
        if let before = model.imageMetadata, let after = model.processedImageMetadata {
          HStack {
            Text("\(before.fileSizeFormatted) → \(after.fileSizeFormatted)").fontWeight(.semibold)
            Spacer()
            if before.fileSize > 0 {
              Text("\(Int((1 - Double(after.fileSize) / Double(before.fileSize)) * 100))% smaller")
            }
          }.font(.callout)
        }
      } else {
        VStack(spacing: 12) {
          Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
          Text("Choose an image to compare your export")
        }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task(id: taskKey) {
      await model.refresh(
        url: fileSelectionViewModel.selectedFileForPreview,
        settings: processingSettingsViewModel.getProcessingSettings(),
        validationMessage: processingSettingsViewModel.previewValidationMessage)
    }
    .sheet(isPresented: $showsComparison) {
      if let original = model.originalImage, let processed = model.processedImage,
        let metadata = model.processedImageMetadata
      {
        ComparisonView(original: original, processed: processed, dimensions: metadata.dimensions)
      }
    }
  }
  private func imageCard(_ title: String, image: NSImage, metadata: ImageMetadata?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      Button {
        showsComparison = true
      } label: {
        Image(nsImage: image).resizable().scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(TransparencyGrid()).clipShape(RoundedRectangle(cornerRadius: 8))
      }.buttonStyle(.plain).accessibilityLabel("Compare \(title.lowercased()) image")
      if let metadata {
        Text(
          "\(metadata.fileType) · \(metadata.fileSizeFormatted) · \(metadata.dimensionsFormatted)"
        )
        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
    }.frame(maxWidth: .infinity)
  }
}

private struct TransparencyGrid: View {
  var body: some View {
    Canvas { context, size in
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.24)))
      for row in 0..<Int(ceil(size.height / 12)) {
        for column in 0..<Int(ceil(size.width / 12)) where (row + column).isMultiple(of: 2) {
          context.fill(
            Path(CGRect(x: column * 12, y: row * 12, width: 12, height: 12)),
            with: .color(Color(white: 0.34)))
        }
      }
    }
  }
}

private struct ComparisonView: View {
  let original: NSImage
  let processed: NSImage
  let dimensions: NSSize
  @Environment(\.dismiss) private var dismiss
  @State private var zoom = 1.0
  @State private var divider = 0.5
  @State private var background = "Checkerboard"
  @State private var fitsWindow = true
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Original / Export").font(.headline)
        Spacer()
        Picker("Background", selection: $background) {
          Text("Checkerboard").tag("Checkerboard")
          Text("White").tag("White")
          Text("Black").tag("Black")
        }.frame(width: 210)
        Button("Fit") { fitsWindow = true }
        Button("100%") {
          fitsWindow = false
          zoom = 1
        }
        Button {
          fitsWindow = false
          zoom = max(0.25, zoom / 1.5)
        } label: {
          Image(systemName: "minus.magnifyingglass")
        }.accessibilityLabel("Zoom out")
        Button {
          fitsWindow = false
          zoom = min(8, zoom * 1.5)
        } label: {
          Image(systemName: "plus.magnifyingglass")
        }.accessibilityLabel("Zoom in")
        Button("Done") { dismiss() }.keyboardShortcut(.escape, modifiers: [])
      }
      GeometryReader { geometry in
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let nativeWidth = dimensions.width / scale
        let nativeHeight = dimensions.height / scale
        let fit = min(geometry.size.width / nativeWidth, geometry.size.height / nativeHeight)
        let factor = fitsWindow ? fit : zoom
        let width = nativeWidth * factor
        let height = nativeHeight * factor
        ScrollView([.horizontal, .vertical]) {
          ZStack(alignment: .leading) {
            Group {
              if background == "Checkerboard" {
                TransparencyGrid()
              } else {
                background == "White" ? Color.white : Color.black
              }
            }
            Image(nsImage: processed).resizable().scaledToFit()
            Image(nsImage: original).resizable().scaledToFit()
              .mask(
                Rectangle().frame(width: width * divider).frame(
                  maxWidth: .infinity, alignment: .leading))
            Rectangle().fill(.white).frame(width: 2).offset(x: width * divider)
          }.frame(width: width, height: height)
            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
        }
      }
      HStack {
        Text("Original")
        Slider(value: $divider, in: 0...1).accessibilityLabel("Before and after comparison")
        Text("Export")
      }
      Text("Drag the comparison slider. Both images share the same zoom and scroll position.")
        .font(.caption).foregroundStyle(.secondary)
    }.padding(20).frame(minWidth: 780, idealWidth: 960, minHeight: 560, idealHeight: 680)
  }
}
