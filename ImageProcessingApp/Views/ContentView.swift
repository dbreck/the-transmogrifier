import AppKit
import ImageIO
import SwiftUI

@MainActor
struct ContentView: View {
  @StateObject private var fileSelectionVM = FileSelectionViewModel()
  @StateObject private var presetManager = PresetManager()
  @ObservedObject var historyManager: HistoryManager
  @StateObject private var processingSettingsVM = ProcessingSettingsViewModel()
  @State private var isProcessing = false
  @State private var progressText: String? = nil
  // Always-visible progress state
  @State private var progressValue: Double = 0.0  // 0.0 - 1.0
  // Processing task handle for cancellation
  @State private var processingTask: Task<Void, Never>? = nil
  @State private var processingControl: ProcessingControl? = nil
  @State private var isPaused = false
  @State private var processingIndicatorTask: Task<Void, Never>? = nil
  @State private var processingStartDate: Date? = nil
  @State private var processingElapsedTime: TimeInterval = 0
  @State private var processingThroughput: Double = 0
  @State private var processingETA: TimeInterval? = nil
  @State private var processingDotCount: Int = 1
  @State private var lastFailedFiles: [URL] = []
  @State private var hasConfiguredWindowSize = false

  @ObservedObject var fileOpener: OpenFilesDelegate
  @State private var handlingOpenRequest = false
  let appearanceManager: AppearanceManager

  init(
    appearanceManager: AppearanceManager, fileOpener: OpenFilesDelegate,
    historyManager: HistoryManager
  ) {
    self.historyManager = historyManager
    self.fileOpener = fileOpener
    self.appearanceManager = appearanceManager
  }

  @State private var batchID = UUID()
  @State private var selectedTab = 0
  @State private var isCancelling = false
  @State private var lastBatch: HistoryBatch?

  var body: some View {
    TabView(selection: $selectedTab) {
      HStack(alignment: .top, spacing: 16) {
        VStack(spacing: 12) {
          FileSelectionView(viewModel: fileSelectionVM)
            .fixedSize(horizontal: false, vertical: true)
            .disabled(isProcessing)
          if !fileSelectionVM.selectedFiles.isEmpty {
            TransmogrifierCard(title: "Preview", icon: "eye") {
              PreviewView(
                fileSelectionViewModel: fileSelectionVM,
                processingSettingsViewModel: processingSettingsVM
              )
              .frame(height: 280)
            }
          }
          SelectedFilesPanel(viewModel: fileSelectionVM).disabled(isProcessing)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        VStack(spacing: 12) {
          ScrollView {
            TransmogrifierCard(title: "Export settings", icon: "slider.horizontal.3") {
              ProcessingSettingsView(
                fileSelectionViewModel: fileSelectionVM,
                presetManager: presetManager, settingsViewModel: processingSettingsVM)
            }.disabled(isProcessing)
          }
          exportControls
        }.frame(width: 440)
      }.padding(16).background(Color.gray900)
        .tabItem { Label("Processing", systemImage: "photo.stack") }.tag(0)
      HistoryView(
        historyManager: historyManager, isProcessing: isProcessing,
        onReuse: { batch in reuse(batch) },
        onRun: { batch, failedOnly in rerun(batch, failedOnly: failedOnly) }
      )
      .padding(20).background(Color.gray900)
      .tabItem { Label("History", systemImage: "clock") }.tag(1)
    }
    .onAppear {
      configureWindowSizeIfNeeded()
      handleOpenRequest()
    }
    .onReceive(fileOpener.$pending) { requests in
      if !requests.isEmpty { Task { handleOpenRequest() } }
    }
    .onChange(of: isProcessing) { processing in
      if !processing { handleOpenRequest() }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenHelpWindow"))) {
      _ in openHelpWindow()
    }
    .focusedSceneValue(
      \.exportActions,
      ExportActions(
        canImport: !isProcessing,
        canProcess: selectedTab == 0 && !isProcessing && !fileSelectionVM.selectedFiles.isEmpty
          && processingSettingsVM.validationMessage == nil,
        addImages: {
          selectedTab = 0
          fileSelectionVM.selectFiles()
        },
        process: { processImages() })
    )
    .onDisappear {
      processingTask?.cancel()
      processingIndicatorTask?.cancel()
    }
  }

  private var exportControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(processingSettingsVM.destinationSummary).font(.caption).foregroundStyle(.secondary)
        .lineLimit(1).truncationMode(.middle)
      if isProcessing {
        ProgressView(value: progressValue).progressViewStyle(.linear)
        Text(isCancelling ? "Finishing active work and saving results…" : processingStatusText)
          .font(.caption)
      } else if let progressText {
        Text(progressText).font(.callout).textSelection(.enabled)
      }
      HStack(spacing: 12) {
        TransmogrifierButton(
          isCancelling ? "Cancelling…" : processingButtonTitle, icon: "bolt.fill"
        ) { processImages() }
        .disabled(
          isProcessing || fileSelectionVM.selectedFiles.isEmpty
            || processingSettingsVM.validationMessage != nil)
        if isProcessing {
          Button(isPaused ? "Resume" : "Pause") {
            isPaused.toggle()
            let paused = isPaused
            Task { await processingControl?.setPaused(paused) }
          }.disabled(isCancelling)
          Button("Cancel") {
            isCancelling = true
            processingTask?.cancel()
          }.disabled(isCancelling)
        } else if !lastFailedFiles.isEmpty {
          Button("Retry unfinished") { if let lastBatch { rerun(lastBatch, failedOnly: true) } }
        }
      }
    }.padding(14).background(Color.gray800).clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func processImages(inputFilesOverride: [URL]? = nil, onlyJobKeys: Set<String>? = nil) {
    guard !isProcessing else { return }
    if let message = processingSettingsVM.validationMessage {
      progressText = message
      return
    }
    let inputFiles = inputFilesOverride ?? fileSelectionVM.selectedFiles
    guard !inputFiles.isEmpty else { return }
    let settings = processingSettingsVM.getProcessingSettings()
    let saveAlongside = settings.saveAlongsideOriginals
    let outputFolder = saveAlongside ? nil : URL(fileURLWithPath: settings.outputFolder)
    guard
      let access = prepareSecurityScopedAccess(
        inputFiles: inputFiles, outputFolder: outputFolder, saveAlongside: saveAlongside)
    else { return }
    let relative = fileSelectionVM.relativeOutputSubfolderByFilePath
    let bookmarks = HistoryManager.bookmarks(
      for: fileSelectionVM.accessURLs + inputFiles + access + (outputFolder.map { [$0] } ?? []))
    let name =
      processingSettingsVM.selectedPreset.isEmpty
      ? (settings.exportOptions.isResponsive
        ? "Responsive image pack" : "\(settings.outputFormat) export")
      : processingSettingsVM.selectedPreset
    let id = UUID()
    batchID = id
    isProcessing = true
    isCancelling = false
    isPaused = false
    progressText = nil
    progressValue = 0
    lastFailedFiles = []
    let control = ProcessingControl()
    processingControl = control
    startProcessingIndicator()
    processingTask = Task {
      defer { Self.stopSecurityScopedAccess(for: access) }
      let results = await ImageProcessingEngine.shared.processImages(
        inputURLs: inputFiles,
        outputFolder: outputFolder, maxWidth: settings.maxWidth, maxHeight: settings.maxHeight,
        compressionQuality: settings.compressionLevel, outputFormat: settings.outputFormat,
        targetDPI: Double(settings.dpi), preserveFolderStructure: settings.preserveFolderStructure,
        collisionPolicy: settings.collisionPolicy, relativeOutputSubfolderByInputPath: relative,
        processingControl: control, exportOptions: settings.exportOptions, onlyJobKeys: onlyJobKeys
      ) { progress in
        Task { @MainActor in
          guard batchID == id, isProcessing, !isCancelling else { return }
          progressValue = progress.progressPercentage
          processingThroughput = progress.throughputFilesPerSecond
          processingETA = progress.estimatedTimeRemaining
        }
      }
      let cancelled = Task.isCancelled
      let records = results.map { result -> HistoryRecord in
        var record = HistoryRecord(
          inputFile: result.inputURL.path, outputFile: result.outputURL?.path,
          presetId: nil, fileSizeBefore: result.fileSizeBefore, fileSizeAfter: result.fileSizeAfter,
          processingTime: result.processingTime, success: result.success,
          errorMessage: result.error?.localizedDescription)
        record.skipped = result.skipped
        record.cancelled =
          result.error is CancellationError
          || (result.error as? ImageProcessingError).map {
            if case .cancelled = $0 { return true }
            return false
          } == true
        record.jobKey = result.jobKey
        record.pixelWidth = result.pixelWidth
        return record
      }
      let batch = HistoryBatch(
        name: name, settings: settings, inputFiles: inputFiles.map(\.path),
        relativeSubfolders: relative, bookmarks: bookmarks, records: records,
        wasCancelled: cancelled)
      lastBatch = batch
      historyManager.addBatch(batch)
      finishProcessingIndicator()
      lastFailedFiles = Array(Set(results.filter { !$0.success }.map(\.inputURL))).sorted {
        $0.path < $1.path
      }
      progressText =
        "\(cancelled ? "Cancelled. " : "")\(batch.statusSummary). See History for results."
      processingTask = nil
      processingControl = nil
      isProcessing = false
      isCancelling = false
      isPaused = false
    }
  }

  private func handleOpenRequest() {
    guard !isProcessing, !handlingOpenRequest else { return }
    handlingOpenRequest = true
    guard let urls = fileOpener.takeNext() else {
      handlingOpenRequest = false
      return
    }
    Task {
      selectedTab = 0
      await fileSelectionVM.importAndWait(urls, replaceExisting: true)
      let presetID = UserDefaults.standard.string(forKey: "QuickConvertPresetID") ?? ""
      if let preset = presetManager.presets.first(where: { $0.id.uuidString == presetID }) {
        processingSettingsVM.applyCustomPreset(preset)
        processImages()
      } else {
        progressText =
          "Images opened for review. Choose a Quick Convert preset in Advanced to convert future Dock drops automatically."
      }
      handlingOpenRequest = false
      if !isProcessing { handleOpenRequest() }
    }
  }

  private func reuse(_ batch: HistoryBatch) {
    guard !isProcessing, let settings = batch.settings else { return }
    processingSettingsVM.apply(settings)
    processingSettingsVM.selectedPreset = batch.name
    selectedTab = 0
  }

  private func rerun(_ batch: HistoryBatch, failedOnly: Bool) {
    guard !isProcessing else { return }
    reuse(batch)
    let paths = failedOnly ? Array(Set(batch.failed.map(\.inputFile))) : batch.inputFiles
    fileSelectionVM.restoreFiles(
      paths.map { URL(fileURLWithPath: $0) }, relativeSubfolders: batch.relativeSubfolders,
      accessURLs: HistoryManager.resolveBookmarks(batch.bookmarks))
    let missing = paths.filter { !FileManager.default.isReadableFile(atPath: $0) }
    guard missing.isEmpty else {
      progressText =
        "\(missing.count) original(s) are missing or need access. Add their source files or folders again, then export."
      return
    }
    let keys = failedOnly ? Set(batch.failed.compactMap(\.jobKey)) : nil
    processImages(onlyJobKeys: keys)
  }

  private var processingButtonTitle: String {
    if isProcessing {
      if isPaused { return "Processing (Paused)" }
      return "Processing\(animatedDots)"
    }
    return "Process Images"
  }

  private var processingStatusText: String {
    var details = ["time to convert: \(formattedElapsedTime)s"]
    if let processingETA, processingETA.isFinite {
      details.append("ETA: \(formattedTime(processingETA))s")
    }
    if processingThroughput > 0 {
      details.append(
        "\(processingThroughput.formatted(.number.precision(.fractionLength(2)))) files/s"
      )
    }
    let prefix = isPaused ? "Processing paused" : "Processing images\(animatedDots)"
    return "\(prefix) (\(details.joined(separator: ", ")))"
  }

  private var animatedDots: String {
    String(repeating: ".", count: max(1, processingDotCount))
  }

  private var formattedElapsedTime: String {
    let formatted = processingElapsedTime.formatted(.number.precision(.fractionLength(2)))
    return processingElapsedTime < 10 ? "0\(formatted)" : formatted
  }

  private func formattedTime(_ seconds: TimeInterval) -> String {
    let formatted = seconds.formatted(.number.precision(.fractionLength(2)))
    return seconds < 10 ? "0\(formatted)" : formatted
  }

  private func startProcessingIndicator() {
    processingIndicatorTask?.cancel()
    processingElapsedTime = 0
    processingDotCount = 1
    processingStartDate = Date()

    processingIndicatorTask = Task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard isProcessing else { continue }
        processingDotCount = processingDotCount == 3 ? 1 : (processingDotCount + 1)
        if let processingStartDate {
          processingElapsedTime = Date().timeIntervalSince(processingStartDate)
        }
      }
    }
  }

  private func finishProcessingIndicator() {
    if let processingStartDate {
      processingElapsedTime = Date().timeIntervalSince(processingStartDate)
    }
    processingStartDate = nil
    processingIndicatorTask?.cancel()
    processingIndicatorTask = nil
    processingDotCount = 1
    processingThroughput = 0
    processingETA = nil
  }

  private func openHelpWindow() {
    HelpWindowManager.shared.showHelpWindow()
  }

  private func configureWindowSizeIfNeeded() {
    guard !hasConfiguredWindowSize else { return }
    hasConfiguredWindowSize = true

    DispatchQueue.main.async {
      guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
      else { return }

      let minSize = NSSize(width: 1000, height: 680)
      window.minSize = minSize

      let targetSize = NSSize(width: 1180, height: 860)
      if !window.styleMask.contains(.fullScreen) {
        window.setContentSize(targetSize)
        window.center()
      }
    }
  }

  private func prepareSecurityScopedAccess(
    inputFiles: [URL],
    outputFolder: URL?,
    saveAlongside: Bool
  ) -> [URL]? {
    let parentFolders = Array(
      Set(inputFiles.map { $0.deletingLastPathComponent().standardizedFileURL }))

    var accessCandidates = inputFiles + fileSelectionVM.accessURLs
    if let outputFolder {
      accessCandidates.append(outputFolder)
    }
    if saveAlongside {
      accessCandidates.append(contentsOf: parentFolders)
    }

    var activeAccessURLs = Self.startSecurityScopedAccess(for: accessCandidates)
    guard saveAlongside else {
      guard let outputFolder, Self.canWrite(in: outputFolder) else {
        Self.stopSecurityScopedAccess(for: activeAccessURLs)
        progressText =
          "The output folder needs access. Choose it again using Browse, then save your preset to remember that access."
        return nil
      }
      return activeAccessURLs
    }

    let unwritableFolders = parentFolders.filter { !Self.canWrite(in: $0) }
    guard !unwritableFolders.isEmpty else {
      return activeAccessURLs
    }

    guard let grantedFolders = requestFolderAccess(for: unwritableFolders) else {
      Self.stopSecurityScopedAccess(for: activeAccessURLs)
      progressText =
        "Processing cancelled. Folder access is required to save alongside originals."
      return nil
    }

    let invalidFolders = unwritableFolders.filter { folder in
      !grantedFolders.contains(where: { granted in
        Self.containsDirectory(granted, candidate: folder)
      })
    }
    guard invalidFolders.isEmpty else {
      Self.stopSecurityScopedAccess(for: activeAccessURLs)
      progressText =
        "Processing cancelled. Access was not granted for all source folders."
      return nil
    }

    let grantedAccessURLs = Self.startSecurityScopedAccess(for: grantedFolders)
    activeAccessURLs.append(contentsOf: grantedAccessURLs)

    let remainingUnwritableFolders = parentFolders.filter { !Self.canWrite(in: $0) }
    guard remainingUnwritableFolders.isEmpty else {
      Self.stopSecurityScopedAccess(for: activeAccessURLs)
      progressText =
        "No files were written. macOS blocked folder writes; choose an output folder or re-grant access."
      return nil
    }

    return activeAccessURLs
  }

  private func requestFolderAccess(for folders: [URL]) -> [URL]? {
    let panel = NSOpenPanel()
    panel.title = "Grant Folder Access"
    panel.message =
      "To save alongside originals, select the source folder(s) containing your images."
    panel.prompt = "Grant Access"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = true
    panel.canCreateDirectories = false
    panel.directoryURL = folders.first

    guard panel.runModal() == .OK else { return nil }
    return panel.urls.map(\.standardizedFileURL)
  }

  private nonisolated static func startSecurityScopedAccess(for urls: [URL]) -> [URL] {
    var seenPaths: Set<String> = []
    var accessedURLs: [URL] = []
    for url in urls.map(\.standardizedFileURL) {
      guard seenPaths.insert(url.path).inserted else { continue }
      if url.startAccessingSecurityScopedResource() {
        accessedURLs.append(url)
      }
    }
    return accessedURLs
  }

  private nonisolated static func stopSecurityScopedAccess(for urls: [URL]) {
    var seenPaths: Set<String> = []
    for url in urls.map(\.standardizedFileURL) {
      guard seenPaths.insert(url.path).inserted else { continue }
      url.stopAccessingSecurityScopedResource()
    }
  }

  private nonisolated static func canWrite(in folder: URL) -> Bool {
    let fileManager = FileManager.default
    let probeURL = folder.appendingPathComponent(
      ".transmogrifier-write-check-\(UUID().uuidString)"
    )
    do {
      try Data().write(to: probeURL, options: .atomic)
      try fileManager.removeItem(at: probeURL)
      return true
    } catch {
      return false
    }
  }

  private nonisolated static func containsDirectory(_ parent: URL, candidate: URL) -> Bool {
    let parentPath = parent.standardizedFileURL.path
    let candidatePath = candidate.standardizedFileURL.path
    if parentPath == candidatePath {
      return true
    }
    let normalizedParentPath = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
    return candidatePath.hasPrefix(normalizedParentPath)
  }

  // (alert attached in body)
}

// MARK: - Selected Files Panel

struct SelectedFilesPanel: View {
  @ObservedObject var viewModel: FileSelectionViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
      HStack {
        Image(systemName: "doc.on.doc")
          .font(.system(size: 16))
          .foregroundColor(.white)

        Text("Selected Files (\(viewModel.selectedFiles.count))")
          .font(.cardTitle)
          .foregroundColor(.white)

        Spacer()

        if !viewModel.selectedFiles.isEmpty {
          Button("Clear") {
            clearAll()
          }
          .buttonStyle(.plain)
          .font(.caption)
          .padding(.horizontal, Spacing.sm)
          .padding(.vertical, Spacing.xs)
          .background(Color.gray700)
          .foregroundColor(.gray300)
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color.gray600, lineWidth: 1)
          )
          .cornerRadius(6)
        }
      }
      .padding(.horizontal, Spacing.md)
      .padding(.top, Spacing.md)

      if viewModel.selectedFiles.isEmpty {
        // Empty state
        VStack(spacing: Spacing.md) {
          Image(systemName: "photo.stack")
            .font(.system(size: 48))
            .foregroundColor(.gray400)

          Text("No files selected")
            .font(.label)
            .foregroundColor(.gray400)

          Text("Select images to see them here")
            .font(.caption)
            .foregroundColor(.gray400)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: Spacing.xs) {
            ForEach(viewModel.selectedFiles, id: \.self) { file in
              SelectedFileCard(
                file: file,
                isSelectedForPreview: file == viewModel.selectedFileForPreview,
                onSelectForPreview: {
                  viewModel.selectFileForPreview(file)
                },
                onRemove: {
                  removeFile(file)
                }
              )
            }
          }
          .padding(.horizontal, Spacing.sm)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.gray800)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.gray600, lineWidth: 1)
    )
  }

  private func removeFile(_ file: URL) {
    viewModel.removeFile(file)
  }

  private func clearAll() {
    viewModel.clearSelection()
  }
}

struct SelectedFileCard: View {
  let file: URL
  let isSelectedForPreview: Bool
  let onSelectForPreview: () -> Void
  let onRemove: () -> Void
  @State private var fileDetails: SelectedFileDetails? = nil

  var body: some View {
    HStack(spacing: Spacing.sm) {
      // Thumbnail placeholder
      Group {
        if let thumbnail = fileDetails?.thumbnailImage {
          Image(nsImage: thumbnail)
            .resizable()
            .scaledToFill()
        } else {
          Rectangle()
            .fill(.gray700)
            .overlay(
              Image(systemName: "photo")
                .foregroundColor(.gray400)
            )
        }
      }
      .frame(width: 48, height: 48)
      .cornerRadius(6)
      .clipped()

      // File info
      VStack(alignment: .leading, spacing: 2) {
        Text(file.lastPathComponent)
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(.white)
          .lineLimit(1)

        HStack(spacing: 4) {
          Text(file.pathExtension.uppercased())
            .font(.caption)
            .foregroundColor(.gray400)

          if let formattedSize = fileDetails?.formattedFileSize {
            Text("•")
              .foregroundColor(.gray400)
            Text(formattedSize)
              .font(.caption)
              .foregroundColor(.gray400)
          }

          if let dimensionsText = fileDetails?.dimensionsText {
            Text("•")
              .foregroundColor(.gray400)

            Text(dimensionsText)
              .font(.caption)
              .foregroundColor(.gray400)
          }
        }
      }

      Spacer()

      // Remove button
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.system(size: 16))
          .foregroundColor(.gray400)
      }
      .buttonStyle(PlainButtonStyle())
      .frame(width: 20, height: 20)
    }
    .padding(Spacing.sm)
    .background(isSelectedForPreview ? .blue900.opacity(0.5) : .gray700.opacity(0.5))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(isSelectedForPreview ? .blue600 : .clear, lineWidth: 1)
    )
    .onTapGesture {
      onSelectForPreview()
    }
    .task(id: file) {
      let details = await Task.detached(priority: .utility) {
        SelectedFileDetails.load(from: file)
      }.value
      await MainActor.run {
        self.fileDetails = details
      }
    }
  }
}

private struct SelectedFileDetails {
  let thumbnailImage: NSImage?
  let formattedFileSize: String?
  let dimensionsText: String?

  static func load(from fileURL: URL) -> SelectedFileDetails {
    let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil)
    let thumbnailImage = imageSource.flatMap { loadThumbnail(from: $0) }
    let formattedFileSize: String? = {
      guard
        let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[
          .size] as? Int64
      else { return nil }

      let formatter = ByteCountFormatter()
      formatter.allowedUnits = [.useKB, .useMB]
      formatter.countStyle = .file
      return formatter.string(fromByteCount: fileSize)
    }()

    let dimensionsText: String? = {
      guard
        let imageSource,
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
          as? [CFString: Any],
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
      else {
        return nil
      }
      return "\(width) × \(height)"
    }()

    return SelectedFileDetails(
      thumbnailImage: thumbnailImage,
      formattedFileSize: formattedFileSize,
      dimensionsText: dimensionsText
    )
  }

  private static func loadThumbnail(from source: CGImageSource) -> NSImage? {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCache: false,
      kCGImageSourceThumbnailMaxPixelSize: 96,
    ]
    guard let cgThumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else {
      return nil
    }
    return NSImage(
      cgImage: cgThumbnail,
      size: NSSize(width: cgThumbnail.width, height: cgThumbnail.height)
    )
  }
}

#Preview {
  ContentView(
    appearanceManager: AppearanceManager(), fileOpener: OpenFilesDelegate(),
    historyManager: HistoryManager())
}
