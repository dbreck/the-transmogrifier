import SwiftUI
import UniformTypeIdentifiers

@MainActor
class FileSelectionViewModel: ObservableObject {
  struct ImportedImageFile: Hashable, Sendable {
    let url: URL
    let relativeOutputSubfolder: String?
  }

  @Published var selectedFiles: [URL] = []
  @Published var selectedFileForPreview: URL? = nil
  @Published var errorMessage: String? = nil
  @Published var includeSubfolders: Bool = false
  @Published private(set) var isSelectingFiles: Bool = false
  @Published private(set) var relativeOutputSubfolderByFilePath: [String: String] = [:]

  private var importGeneration = UUID()
  private(set) var accessURLs: [URL] = []
  private var activeAccessURLs: [URL] = []

  func retainAccess(to urls: [URL]) {
    for url in urls where !accessURLs.contains(url) {
      accessURLs.append(url)
      if url.startAccessingSecurityScopedResource() { activeAccessURLs.append(url) }
    }
  }
  func restoreFiles(_ urls: [URL], relativeSubfolders: [String: String], accessURLs: [URL]) {
    clearSelection()
    retainAccess(to: accessURLs)
    selectedFiles = urls
    relativeOutputSubfolderByFilePath = relativeSubfolders
    selectedFileForPreview = urls.first
  }

  /// Select files using a document picker
  func selectFiles() {
    guard !isSelectingFiles else { return }
    let shouldIncludeSubfolders = self.includeSubfolders
    let generation = importGeneration
    isSelectingFiles = true
    Task { @MainActor in
      defer { isSelectingFiles = false }
      do {
        let importedFiles = try await selectFilesUsingDialog(
          includeSubfolders: shouldIncludeSubfolders)
        guard generation == importGeneration else { return }
        if !importedFiles.isEmpty { applyImportedFiles(importedFiles, replaceExisting: false) }
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func importURLs(_ urls: [URL], replaceExisting: Bool = false, includeSubfolders: Bool? = nil) {
    Task {
      await importAndWait(
        urls, replaceExisting: replaceExisting, includeSubfolders: includeSubfolders)
    }
  }

  func importAndWait(_ urls: [URL], replaceExisting: Bool = false, includeSubfolders: Bool? = nil)
    async
  {
    if replaceExisting { clearSelection() }
    retainAccess(to: urls)
    let generation = importGeneration
    let shouldRecurse = includeSubfolders ?? self.includeSubfolders
    let importedFiles = await Task.detached(priority: .userInitiated) {
      Self.resolveSelectedURLs(urls, includeSubfolders: shouldRecurse)
    }.value
    guard generation == importGeneration, !Task.isCancelled else { return }
    applyImportedFiles(importedFiles, replaceExisting: false)
    if importedFiles.isEmpty { errorMessage = "No supported images found in this selection." }
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
    Self.isSupportedImageFile(url)
  }

  /// Validate all selected files
  func validateSelectedFiles() -> [URL] {
    return selectedFiles.filter { validateImageFile($0) }
  }

  func relativeOutputSubfolder(for fileURL: URL) -> String? {
    relativeOutputSubfolderByFilePath[fileURL.path]
  }

  /// Select a file for preview
  func selectFileForPreview(_ url: URL) {
    selectedFileForPreview = url
  }

  func removeFile(_ fileURL: URL) {
    selectedFiles.removeAll { $0 == fileURL }
    relativeOutputSubfolderByFilePath.removeValue(forKey: fileURL.path)
    if selectedFileForPreview == fileURL {
      selectedFileForPreview = selectedFiles.first
    }
  }

  func clearSelection() {
    importGeneration = UUID()
    activeAccessURLs.forEach { $0.stopAccessingSecurityScopedResource() }
    activeAccessURLs.removeAll()
    accessURLs.removeAll()
    selectedFiles.removeAll()
    selectedFileForPreview = nil
    errorMessage = nil
    relativeOutputSubfolderByFilePath.removeAll()
  }

  // MARK: - Private Methods
  nonisolated private static let supportedImageExtensions: Set<String> = [
    "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "icns", "ico",
  ]

  /// Present file selection dialog
  private func selectFilesUsingDialog(includeSubfolders: Bool) async throws -> [ImportedImageFile] {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.canCreateDirectories = true
    panel.allowedContentTypes = [
      .folder,
      .jpeg,
      .png,
      .bmp,
      .gif,
      .tiff,
      .heic,
      .webP,
      .icns,
      .ico,
    ]

    guard panel.runModal() == .OK else { return [] }

    let selectedURLs = panel.urls
    retainAccess(to: selectedURLs)
    let validFiles = await Task.detached(priority: .userInitiated) {
      Self.resolveSelectedURLs(selectedURLs, includeSubfolders: includeSubfolders)
    }.value

    if validFiles.isEmpty {
      throw NSError(
        domain: "FileSelectionError",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "No valid image files or folders selected"]
      )
    }
    return validFiles
  }

  /// Present folder selection dialog
  private func selectFolderUsingDialog() async throws -> URL {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true

    guard panel.runModal() == .OK, let url = panel.url else {
      throw NSError(
        domain: "FileSelectionError",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No folder selected"]
      )
    }

    retainAccess(to: [url])
    let fileManager = FileManager.default
    let probeURL = url.appendingPathComponent(
      ".transmogrifier-write-check-\(UUID().uuidString)"
    )
    do {
      try Data().write(to: probeURL, options: .atomic)
      try fileManager.removeItem(at: probeURL)
      return url
    } catch let error as NSError {
      if error.code == NSFileWriteNoPermissionError {
        throw NSError(
          domain: "FileSelectionError",
          code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Permission denied to write to selected folder"]
        )
      }
      throw error
    }
  }

  nonisolated private static func resolveSelectedURLs(
    _ selectedURLs: [URL],
    includeSubfolders: Bool
  ) -> [ImportedImageFile] {
    var seenPaths = Set<String>()
    var resolvedFiles: [ImportedImageFile] = []

    for url in selectedURLs {
      let candidateFiles: [ImportedImageFile]
      if isDirectory(url) {
        candidateFiles = imageFiles(in: url, includeSubfolders: includeSubfolders)
      } else if isSupportedImageFile(url) {
        candidateFiles = [ImportedImageFile(url: url, relativeOutputSubfolder: nil)]
      } else {
        candidateFiles = []
      }

      for imageFile in candidateFiles where !seenPaths.contains(imageFile.url.path) {
        seenPaths.insert(imageFile.url.path)
        resolvedFiles.append(imageFile)
      }
    }

    return resolvedFiles
  }

  nonisolated private static func imageFiles(
    in folderURL: URL,
    includeSubfolders: Bool
  ) -> [ImportedImageFile] {
    if includeSubfolders {
      guard
        let enumerator = FileManager.default.enumerator(
          at: folderURL,
          includingPropertiesForKeys: [.isRegularFileKey],
          options: [.skipsHiddenFiles]
        )
      else {
        return []
      }

      var files: [ImportedImageFile] = []
      for case let fileURL as URL in enumerator where isSupportedImageFile(fileURL) {
        files.append(
          ImportedImageFile(
            url: fileURL,
            relativeOutputSubfolder: relativeOutputSubfolder(
              for: fileURL,
              rootFolder: folderURL
            )
          ))
      }
      return files
    }

    guard
      let directChildren = try? FileManager.default.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    return directChildren.compactMap { fileURL in
      guard isSupportedImageFile(fileURL) else { return nil }
      return ImportedImageFile(
        url: fileURL,
        relativeOutputSubfolder: relativeOutputSubfolder(for: fileURL, rootFolder: folderURL)
      )
    }
  }

  nonisolated private static func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  nonisolated private static func isSupportedImageFile(_ url: URL) -> Bool {
    guard !isDirectory(url) else { return false }

    let extensionIsSupported = supportedImageExtensions.contains(url.pathExtension.lowercased())
    if extensionIsSupported {
      return true
    }

    guard let fileType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
      return false
    }

    let supportedTypes: [UTType] = [
      .jpeg, .png, .bmp, .gif, .tiff, .heic, .icns, .ico,
    ]
    return supportedTypes.contains { fileType.conforms(to: $0) }
  }

  nonisolated private static func relativeOutputSubfolder(
    for fileURL: URL,
    rootFolder: URL
  ) -> String? {
    let fileParent = fileURL.deletingLastPathComponent().standardizedFileURL
    let rootParent = rootFolder.deletingLastPathComponent().standardizedFileURL
    let rootParentPath = rootParent.path.hasSuffix("/") ? rootParent.path : rootParent.path + "/"
    guard fileParent.path.hasPrefix(rootParentPath) else { return nil }
    let relativePath = String(fileParent.path.dropFirst(rootParentPath.count))
    return relativePath.isEmpty ? nil : relativePath
  }

  private func applyImportedFiles(_ importedFiles: [ImportedImageFile], replaceExisting: Bool) {
    if replaceExisting {
      selectedFiles = importedFiles.map(\.url)
      relativeOutputSubfolderByFilePath = Dictionary(
        uniqueKeysWithValues: importedFiles.compactMap {
          guard let subfolder = $0.relativeOutputSubfolder else { return nil }
          return ($0.url.path, subfolder)
        })
      selectedFileForPreview = selectedFiles.first
      return
    }

    var existingFiles = Set(selectedFiles)
    var newFiles: [URL] = []
    for importedFile in importedFiles where !existingFiles.contains(importedFile.url) {
      existingFiles.insert(importedFile.url)
      newFiles.append(importedFile.url)
      if let relativeSubfolder = importedFile.relativeOutputSubfolder {
        relativeOutputSubfolderByFilePath[importedFile.url.path] = relativeSubfolder
      }
    }
    selectedFiles.append(contentsOf: newFiles)

    if selectedFileForPreview == nil {
      selectedFileForPreview = selectedFiles.first
    }
  }
}

/// Finder/Dock requests are claimed synchronously by one window, then imported asynchronously.
@MainActor
final class OpenFilesDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  @Published private(set) var pending: [[URL]] = []
  private var incoming: [URL] = []
  private var collectionTask: Task<Void, Never>?

  /// SwiftUI delivers a multi-file Finder request one URL at a time.
  func receive(_ url: URL) {
    guard url.isFileURL else { return }
    if !incoming.contains(url) { incoming.append(url) }
    collectionTask?.cancel()
    collectionTask = Task { [weak self] in
      do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return }
      guard let self = self else { return }
      let urls = self.incoming
      self.incoming.removeAll()
      self.enqueue(urls)
    }
  }
  func application(_ application: NSApplication, open urls: [URL]) {
    enqueue(urls)
  }
  func application(_ sender: NSApplication, openFiles filenames: [String]) {
    enqueue(filenames.map { URL(fileURLWithPath: $0) })
    sender.reply(toOpenOrPrint: .success)
  }
  func enqueue(_ urls: [URL]) {
    guard !urls.isEmpty else { return }
    pending.append(urls)
  }
  func takeNext() -> [URL]? {
    guard !pending.isEmpty else { return nil }
    return pending.removeFirst()
  }
}
