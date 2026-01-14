import SwiftUI
import UniformTypeIdentifiers
import AppKit
struct FileSelectionView: View {
    @ObservedObject var viewModel: FileSelectionViewModel
    
    @State private var isDragTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Drag and drop zone
            VStack(spacing: Spacing.md) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 48))
                    .foregroundColor(.gray500)
                
                VStack(spacing: Spacing.xs) {
                    Text("Drag and drop images or folders here")
                        .font(.label)
                        .foregroundColor(.white)

                    Text("Or click to browse your files")
                        .font(.caption)
                        .foregroundColor(.gray400)
                }
                
                TransmogrifierButton("Browse Files", style: .secondary) {
                    viewModel.selectFiles()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(.gray800)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDragTargeted ? Color.blue600 : Color.gray600,
                        style: StrokeStyle(lineWidth: isDragTargeted ? 2 : 1, dash: [5])
                    )
            )
            .shadow(color: isDragTargeted ? Color.blue600.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 0)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.selectFiles() }
            .onDrop(of: [UTType.fileURL, UTType.image, UTType.folder], isTargeted: $isDragTargeted) { providers in
                var accepted = false
                for p in providers {
                    if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
                        p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        accepted = true
                    }
                }
                if accepted {
                    handleDroppedFiles(providers)
                }
                return accepted
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red500)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red500)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background(.red500.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
    
    private func handleDroppedFiles(_ providers: [NSItemProvider]) {
        for provider in providers {
            // 1) Try in-place file URL first (Finder drops)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    let url = (item as? URL) ?? (item as? NSURL as URL?) ?? {
                        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                        if let path = item as? String { return URL(fileURLWithPath: path) }
                        return nil
                    }()
                    if let url = url { self.addIfValid(url) }
                }
                continue
            }

            // 2) Try in-place image file representation
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, inPlace, error in
                    if let url = url { self.addIfValid(url) }
                    else {
                        // 3) Fallback: load raw image data and persist to a temp file
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                            guard let data = data else { return }
                            let ext = self.preferredExtension(for: provider) ?? "png"
                            let tmpURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension(ext)
                            do {
                                try data.write(to: tmpURL)
                                self.addIfValid(tmpURL)
                            } catch {
                                // Ignore write failures
                            }
                        }
                    }
                }
                continue
            }

            // 4) Fallback: older path (URL object)
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url { self.addIfValid(url) }
                }
            }
        }
    }

    private func preferredExtension(for provider: NSItemProvider) -> String? {
        for id in provider.registeredTypeIdentifiers {
            if let ut = UTType(id), ut.conforms(to: .image), let ext = ut.preferredFilenameExtension {
                return ext
            }
        }
        return nil
    }

    private func addIfValid(_ url: URL) {
        DispatchQueue.main.async {
            var isDirectory: ObjCBool = false

            // Check if it's a directory
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                // It's a folder - recursively find all image files
                self.addImagesFromFolder(url)
            } else {
                // It's a file - validate and add it
                if viewModel.validateImageFile(url) {
                    if !viewModel.selectedFiles.contains(url) {
                        viewModel.selectedFiles.append(url)
                    }
                    if viewModel.selectedFileForPreview == nil {
                        viewModel.selectedFileForPreview = url
                    }
                }
            }
        }
    }

    private func addImagesFromFolder(_ folderURL: URL) {
        let fileManager = FileManager.default

        // Supported image extensions
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp"]

        // Get all files recursively
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var addedCount = 0

        for case let fileURL as URL in enumerator {
            // Check if it's a regular file (not a directory)
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }

            // Check if it has an image extension
            let fileExtension = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(fileExtension) {
                if viewModel.validateImageFile(fileURL) {
                    if !viewModel.selectedFiles.contains(fileURL) {
                        viewModel.selectedFiles.append(fileURL)
                        addedCount += 1

                        // Set first valid image as preview
                        if viewModel.selectedFileForPreview == nil {
                            viewModel.selectedFileForPreview = fileURL
                        }
                    }
                }
            }
        }

        print("Added \(addedCount) images from folder: \(folderURL.lastPathComponent)")
    }
}

struct FileListItem: View {
    let fileName: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "photo")
                .font(.caption)
                .foregroundColor(.gray500)
                .frame(width: 16)
            
            Text(fileName)
                .font(.body)
                .foregroundColor(isSelected ? .white : .gray300)
                .lineLimit(1)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue600)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(isSelected ? .gray700 : .clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    FileSelectionView(viewModel: FileSelectionViewModel())
        .frame(width: 320)
        .background(.gray900)
}
