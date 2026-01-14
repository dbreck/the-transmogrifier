import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct PreviewView: View {
    @ObservedObject var fileSelectionViewModel: FileSelectionViewModel
    @ObservedObject var processingSettingsViewModel: ProcessingSettingsViewModel
    @StateObject private var previewViewModel = PreviewViewModel()
    @State private var isPreviewing = false
    @State private var showEnlargedPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if previewViewModel.originalImage != nil || previewViewModel.processedImage != nil {
                HStack(spacing: Spacing.md) {
                    // Compute a consistent preview size based on the original's aspect ratio
                    let targetHeight: CGFloat = 120
                    let targetWidth: CGFloat = {
                        if let img = previewViewModel.originalImage {
                            let rep = img.representations.first
                            let w = CGFloat(rep?.pixelsWide ?? Int(img.size.width))
                            let h = CGFloat(rep?.pixelsHigh ?? Int(img.size.height))
                            guard w > 0 && h > 0 else { return 180 }
                            return targetHeight * (w / h)
                        }
                        return 180
                    }()
                    // Original
                    VStack(spacing: Spacing.xs) {
                        Text("Original")
                            .font(.caption)
                            .foregroundColor(.gray400)
                        Group {
                            if let originalImage = previewViewModel.originalImage {
                                Image(nsImage: originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: targetWidth, height: targetHeight)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6).stroke(
                                            .gray600, lineWidth: 1))
                            } else {
                                Rectangle()
                                    .fill(.gray700)
                                    .frame(width: targetWidth, height: targetHeight)
                                    .cornerRadius(6)
                                    .overlay(
                                        Text("No image").font(.caption).foregroundColor(.gray500))
                            }
                        }
                        if let metadata = previewViewModel.imageMetadata {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(metadata.fileType) • \(metadata.fileSizeFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                                Text("\(metadata.dimensionsFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                                Text(metadata.dpiFormatted)
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Center Process button styled like redesign
                    VStack(spacing: 4) {
                        Button(action: processPreview) {
                            ZStack {
                                // Expand hit area to full bounds
                                Color.clear
                                if isPreviewing {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            .background(.clear)
                            .foregroundColor(.gray300)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.gray600, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(
                            fileSelectionViewModel.selectedFileForPreview == nil || isPreviewing)
                        Text("Process")
                            .font(.caption)
                            .foregroundColor(.gray500)
                    }
                    .frame(width: 48)

                    // Processed
                    VStack(spacing: Spacing.xs) {
                        Text("Processed")
                            .font(.caption)
                            .foregroundColor(.gray400)
                        Group {
                            if let processedImage = previewViewModel.processedImage {
                                Button(action: { showEnlargedPreview = true }) {
                                    ZStack {
                                        Image(nsImage: processedImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: targetWidth, height: targetHeight)

                                        // Magnifying glass overlay
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.6))
                                                .frame(width: 36, height: 36)

                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        .opacity(0.9)
                                    }
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6).stroke(
                                            .gray600, lineWidth: 1))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onHover { isHovering in
                                    if isHovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            } else {
                                Rectangle()
                                    .fill(.gray700.opacity(0.5))
                                    .frame(width: targetWidth, height: targetHeight)
                                    .cornerRadius(6)
                                    .overlay(
                                        Text("No processed image yet")
                                            .font(.caption)
                                            .foregroundColor(.gray500)
                                    )
                            }
                        }
                        if let pmeta = previewViewModel.processedImageMetadata {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(pmeta.fileType) • \(pmeta.fileSizeFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                                Text("\(pmeta.dimensionsFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                                Text(pmeta.dpiFormatted)
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // Full-width Clear Preview button, Download removed
                        Button("Clear Preview") { previewViewModel.clearPreview() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 4)
                            .background(.gray700)
                            .foregroundColor(.gray300)
                            .cornerRadius(4)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if fileSelectionViewModel.selectedFileForPreview != nil {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundColor(.white)
                    Text("Loading preview...")
                        .font(.label)
                        .foregroundColor(.gray400)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "eye")
                        .font(.system(size: 32))
                        .foregroundColor(.gray500)
                    Text("No image selected")
                        .font(.caption)
                        .foregroundColor(.gray500)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(.gray800)
                .cornerRadius(6)
            }
        }
        .onChange(of: fileSelectionViewModel.selectedFileForPreview) { selectedFile in
            if let selectedFile = selectedFile {
                previewViewModel.loadImage(for: selectedFile)
            }
        }
        .onAppear {
            if let selected = fileSelectionViewModel.selectedFileForPreview,
                previewViewModel.originalImage == nil
            {
                previewViewModel.loadImage(for: selected)
            }
        }
        .background(
            Group {
                if showEnlargedPreview, let processedImage = previewViewModel.processedImage {
                    EnlargedPreviewWindow(image: processedImage, isPresented: $showEnlargedPreview)
                }
            }
        )
    }

    private func processPreview() {
        isPreviewing = true
        // Use preview-friendly settings (no output folder requirement)
        let settings = processingSettingsViewModel.getProcessingSettingsForPreview()
        guard fileSelectionViewModel.selectedFileForPreview != nil else {
            isPreviewing = false
            return
        }
        previewViewModel.processPreview(
            maxWidth: Int(settings.maxWidth),
            maxHeight: Int(settings.maxHeight),
            compressionQuality: settings.compressionLevel,
            outputFormat: settings.outputFormat,
            targetDPI: Double(settings.dpi)
        )
        // Turn off spinner when model updates processedImage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.isPreviewing = false }
    }
}

struct PreviewImageCard: View {
    let title: String
    let image: NSImage?
    let metadata: ImageMetadata?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.label)
                .foregroundColor(.gray300)

            Group {
                if let image = image {
                    LazyImage(image: image)
                        .frame(maxWidth: 240, maxHeight: 240)
                } else {
                    Rectangle()
                        .fill(.gray700)
                        .frame(width: 240, height: 240)
                        .overlay(
                            VStack(spacing: Spacing.xs) {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.gray500)

                                Text("No Image")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                            }
                        )
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.gray600, lineWidth: 1)
            )

            if let metadata = metadata {
                VStack(alignment: .leading, spacing: 2) {
                    MetadataRow(label: "Format", value: metadata.fileType)
                    MetadataRow(label: "Size", value: metadata.fileSizeFormatted)
                    MetadataRow(label: "Dimensions", value: metadata.dimensionsFormatted)
                    MetadataRow(label: "DPI", value: metadata.dpiFormatted)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(.gray800)
                .cornerRadius(6)
            } else if image != nil {
                Text("Processing...")
                    .font(.caption)
                    .foregroundColor(.gray500)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(.gray800)
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: 240)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray500)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.gray300)
        }
    }
}

struct LazyImage: View {
    let image: NSImage
    @State private var loadedImage: NSImage?

    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                Image(nsImage: loadedImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .foregroundColor(.white)
                    .onAppear {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let loaded = image
                            DispatchQueue.main.async {
                                self.loadedImage = loaded
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Enlarged Preview Window

struct EnlargedPreviewWindow: NSViewRepresentable {
    let image: NSImage
    @Binding var isPresented: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.showWindow(image: image)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if !isPresented {
            context.coordinator.closeWindow()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject {
        @Binding var isPresented: Bool
        var window: NSWindow?

        init(isPresented: Binding<Bool>) {
            self._isPresented = isPresented
            super.init()
        }

        func showWindow(image: NSImage) {
            guard window == nil else { return }

            let contentView = EnlargedPreviewView(
                image: image,
                onClose: { [weak self] in
                    self?.closeWindow()
                }
            )

            let hostingController = NSHostingController(rootView: contentView)

            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.backgroundColor = NSColor.black.withAlphaComponent(0.95)
            newWindow.setContentSize(NSSize(width: 1000, height: 700))
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.level = .floating

            newWindow.delegate = self

            self.window = newWindow
            newWindow.makeKeyAndOrderFront(nil)
        }

        func closeWindow() {
            window?.close()
            window = nil
            isPresented = false
        }
    }
}

extension EnlargedPreviewWindow.Coordinator: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isPresented = false
        window = nil
    }
}

// MARK: - Enlarged Preview View

struct EnlargedPreviewView: View {
    let image: NSImage
    let onClose: () -> Void

    @State private var zoomScale: CGFloat = 1.0
    @State private var lastMagnification: CGFloat = 1.0
    @State private var scrollViewProxy: ScrollViewProxy?

    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 6.0

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 0) {
                // Top bar with close button and zoom controls
                HStack {
                    Spacer()

                    // Zoom controls
                    HStack(spacing: Spacing.sm) {
                        // Zoom out button
                        Button(action: { zoomOut() }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(.gray300)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(.gray800)
                        .cornerRadius(6)
                        .disabled(zoomScale <= minZoom)

                        // Zoom percentage
                        Text("\(Int(zoomScale * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray300)
                            .frame(minWidth: 50)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 6)
                            .background(.gray800)
                            .cornerRadius(6)

                        // Zoom in button
                        Button(action: { zoomIn() }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(.gray300)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(.gray800)
                        .cornerRadius(6)
                        .disabled(zoomScale >= maxZoom)

                        // Reset zoom button
                        Button(action: { resetZoom() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                                .foregroundColor(.gray300)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(.gray800)
                        .cornerRadius(6)
                    }

                    Spacer()

                    // Close button
                    Button(action: { onClose() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray300)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(.gray800)
                    .cornerRadius(6)
                }
                .padding(Spacing.lg)

                // Scrollable image container
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack {
                            // Center the image in the available space
                            Color.clear
                                .frame(
                                    width: max(geometry.size.width, geometry.size.width * 0.9 * zoomScale),
                                    height: max(geometry.size.height, geometry.size.height * 0.9 * zoomScale)
                                )

                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: geometry.size.width * 0.9 * zoomScale,
                                    height: geometry.size.height * 0.9 * zoomScale
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastMagnification
                                lastMagnification = value
                                let newScale = zoomScale * delta
                                zoomScale = min(max(newScale, minZoom), maxZoom)
                            }
                            .onEnded { _ in
                                lastMagnification = 1.0
                            }
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .onAppear {
            // Set initial zoom to fit the image in the window
            resetZoom()
        }
    }

    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = min(zoomScale * 1.2, maxZoom)
        }
    }

    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = max(zoomScale / 1.2, minZoom)
        }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = 1.0
        }
    }
}

#Preview {
    PreviewView(
        fileSelectionViewModel: FileSelectionViewModel(),
        processingSettingsViewModel: ProcessingSettingsViewModel()
    )
    .frame(width: 500)
    .background(.gray900)
}
