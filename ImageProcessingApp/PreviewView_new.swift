import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

struct PreviewView: View {
    @ObservedObject var fileSelectionViewModel: FileSelectionViewModel
    @StateObject private var previewViewModel = PreviewViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if previewViewModel.originalImage != nil || previewViewModel.processedImage != nil {
                // Before/After comparison in a compact grid
                HStack(spacing: Spacing.md) {
                    // Original image column
                    VStack(spacing: Spacing.xs) {
                        Text("Original")
                            .font(.caption)
                            .foregroundColor(.gray400)
                        
                        Group {
                            if let originalImage = previewViewModel.originalImage {
                                Image(nsImage: originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 120)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.gray600, lineWidth: 1)
                                    )
                            } else {
                                Rectangle()
                                    .fill(.gray700)
                                    .frame(height: 120)
                                    .cornerRadius(6)
                                    .overlay(
                                        Text("No image")
                                            .font(.caption)
                                            .foregroundColor(.gray500)
                                    )
                            }
                        }
                        
                        if let metadata = previewViewModel.imageMetadata {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(metadata.format) • \(metadata.fileSize)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                                Text("\(metadata.dimensions)")
                                    .font(.caption)
                                    .foregroundColor(.gray500)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Processed image column
                    VStack(spacing: Spacing.xs) {
                        Text("Processed")
                            .font(.caption)
                            .foregroundColor(.gray400)
                        
                        Group {
                            if let processedImage = previewViewModel.processedImage {
                                Image(nsImage: processedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 120)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.gray600, lineWidth: 1)
                                    )
                            } else {
                                Rectangle()
                                    .fill(.gray700.opacity(0.5))
                                    .frame(height: 120)
                                    .cornerRadius(6)
                                    .overlay(
                                        Text("No processed image yet")
                                            .font(.caption)
                                            .foregroundColor(.gray500)
                                    )
                            }
                        }
                        
                        HStack(spacing: Spacing.xs) {
                            Button("Clear Preview") {
                                previewViewModel.clearPreview()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 4)
                            .background(.gray700)
                            .foregroundColor(.gray300)
                            .cornerRadius(4)
                            .frame(maxWidth: .infinity)
                            
                            Button("Download") {
                                // TODO: Download processed image
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 4)
                            .background(previewViewModel.processedImage != nil ? .gray700 : .gray800)
                            .foregroundColor(previewViewModel.processedImage != nil ? .gray300 : .gray500)
                            .cornerRadius(4)
                            .frame(maxWidth: .infinity)
                            .disabled(previewViewModel.processedImage == nil)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if fileSelectionViewModel.selectedFileForPreview != nil {
                // Loading state
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
                // Empty state
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
    }
    
    private func processPreview() {
        previewViewModel.processPreview(
            maxWidth: 0,
            maxHeight: 0,
            compressionQuality: 0.8,
            outputFormat: "WebP",
            targetDPI: 72.0
        )
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

#Preview {
    PreviewView(fileSelectionViewModel: FileSelectionViewModel())
        .frame(width: 500)
        .background(.gray900)
}
