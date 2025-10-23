import SwiftUI
import UniformTypeIdentifiers

@MainActor
class FileSelectionViewModel: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var selectedFileForPreview: URL? = nil
    @Published var errorMessage: String? = nil
    
    /// Select files using a document picker
    func selectFiles() {
        Task {
            do {
                let files = try await selectFilesUsingDialog()
                selectedFiles = files
                // Auto-select first file for preview
                selectedFileForPreview = files.first
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Select output folder using a folder picker
    func selectOutputFolder() async -> URL? {
        do {
            return try await selectFolderUsingDialog()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// Validate if a file is a supported image format
    func validateImageFile(_ url: URL) -> Bool {
        let supportedTypes = [
            UTType.jpeg,
            UTType.png,
            UTType.bmp,
            UTType.gif,
            UTType.tiff,
            UTType.heic,
            UTType.icns,
            UTType.ico
        ]
        
        guard let fileType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        
        return supportedTypes.contains { fileType.conforms(to: $0) }
    }
    
    /// Validate all selected files
    func validateSelectedFiles() -> [URL] {
        return selectedFiles.filter { validateImageFile($0) }
    }
    
    /// Select a file for preview
    func selectFileForPreview(_ url: URL) {
        selectedFileForPreview = url
    }
    
    // MARK: - Private Methods
    
    /// Present file selection dialog
    private func selectFilesUsingDialog() async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.canCreateDirectories = true  // Enable "Create Folder" button
                panel.allowedContentTypes = [
                    .jpeg,
                    .png,
                    .bmp,
                    .gif,
                    .tiff,
                    .heic,
                    .icns,
                    .ico
                ]
                
                panel.begin { response in
                    if response == .OK {
                        // Validate selected files
                        let validFiles = panel.urls.filter { self.validateImageFile($0) }
                        if validFiles.isEmpty {
                            continuation.resume(throwing: NSError(domain: "FileSelectionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No valid image files selected"]))
                        } else {
                            continuation.resume(returning: validFiles)
                        }
                    } else {
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }
    
    /// Present folder selection dialog
    private func selectFolderUsingDialog() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = true  // Enable "Create Folder" button
                
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        // Check if we have write permissions to the folder
                        let fileManager = FileManager.default
                        let testFileURL = url.appendingPathComponent("test.tmp")
                        do {
                            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
                            try fileManager.removeItem(at: testFileURL)
                            continuation.resume(returning: url)
                        } catch let error as NSError {
                            if error.code == NSFileWriteNoPermissionError {
                                continuation.resume(throwing: NSError(domain: "FileSelectionError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Permission denied to write to selected folder"]))
                            } else {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        continuation.resume(throwing: NSError(domain: "FileSelectionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No folder selected"]))
                    }
                }
            }
        }
    }
}