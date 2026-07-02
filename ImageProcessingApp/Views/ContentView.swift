import SwiftUI
import AppKit
import ImageIO

@MainActor
struct ContentView: View {
    @StateObject private var fileSelectionVM = FileSelectionViewModel()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var processingSettingsVM = ProcessingSettingsViewModel()
    @State private var isProcessing = false
    @State private var progressText: String? = nil
    // Always-visible progress state
    @State private var progressValue: Double = 0.0  // 0.0 - 1.0
    @State private var progressPercentText: String = "0%"
    @State private var progressOpacity: Double = 1.0
    @State private var progressResetTask: Task<Void, Never>? = nil
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

    let appearanceManager: AppearanceManager

    init(appearanceManager: AppearanceManager) {
        self.appearanceManager = appearanceManager
    }

    var body: some View {
        TabView {
            // Main processing view - 3 column grid
            HStack(alignment: .top, spacing: Spacing.md) {
                // Left 2/3: File Selection, Preview, Processing Parameters, and Controls
                VStack(spacing: Spacing.md) {
                    // Top Row: File Selection + Preview (side by side)
                    HStack(alignment: .top, spacing: Spacing.md) {
                        // File Selection (1/2 of left area)
                        TransmogrifierCard(title: "File Selection", icon: "square.and.arrow.up") {
                            FileSelectionView(viewModel: fileSelectionVM)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                        // Preview (1/2 of left area)
                        TransmogrifierCard(title: "Preview", icon: "eye") {
                            PreviewView(
                                fileSelectionViewModel: fileSelectionVM,
                                processingSettingsViewModel: processingSettingsVM
                            )
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(height: 332, alignment: .top)

                    // Processing Parameters
                    TransmogrifierCard(title: "Processing Parameters", icon: "gearshape") {
                        ProcessingSettingsView(
                            fileSelectionViewModel: fileSelectionVM,
                            presetManager: presetManager,
                            settingsViewModel: processingSettingsVM
                        )
                    }

                    // Processing Controls
                    TransmogrifierCard(title: "", icon: "") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            // Always-visible progress indicator placeholder
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: Spacing.sm) {
                                    ProgressView(value: progressValue, total: 1.0)
                                        .progressViewStyle(.linear)
                                        .frame(maxWidth: .infinity)
                                    Text(progressPercentText)
                                        .font(.caption)
                                        .foregroundColor(.gray400)
                                        .frame(width: 40, alignment: .trailing)
                                        .opacity(progressOpacity)
                                }
                                if isProcessing {
                                    Text(processingStatusText)
                                        .font(.caption)
                                        .foregroundColor(.gray400)
                                } else if let progressText = progressText {
                                    Text(progressText)
                                        .font(.caption)
                                        .foregroundColor(.gray400)
                                }
                            }
                            HStack(spacing: Spacing.md) {
                                TransmogrifierButton(
                                    processingButtonTitle,
                                    icon: "bolt.fill"
                                ) {
                                    processImages()
                                }
                                .disabled(fileSelectionVM.selectedFiles.isEmpty || isProcessing)
                                .frame(maxWidth: .infinity)

                                Button(isPaused ? "Resume" : "Pause") {
                                    guard let processingControl else { return }
                                    isPaused.toggle()
                                    Task {
                                        await processingControl.setPaused(isPaused)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(Color.gray700)
                                .foregroundColor(.gray300)
                                .cornerRadius(6)
                                .disabled(!isProcessing)

                                Button("Cancel") {
                                    if let processingControl {
                                        Task { await processingControl.setPaused(false) }
                                    }
                                    processingTask?.cancel()
                                    processingTask = nil
                                    isProcessing = false
                                    isPaused = false
                                    processingControl = nil
                                    finishProcessingIndicator()
                                    progressText =
                                        "Processing cancelled (time to convert: \(formattedElapsedTime))."
                                    progressPercentText = "Cancelled"
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(Color.gray700)
                                .foregroundColor(.gray300)
                                .cornerRadius(6)
                                .disabled(!isProcessing)
                            }

                            if !isProcessing, !lastFailedFiles.isEmpty {
                                TransmogrifierButton(
                                    "Retry Failed (\(lastFailedFiles.count))",
                                    style: .secondary
                                ) {
                                    processImages(inputFilesOverride: lastFailedFiles)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.top, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Right 1/3: Selected Files (Full Height)
                SelectedFilesPanel(viewModel: fileSelectionVM)
                    .frame(width: 340)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(Spacing.md)
            .background(.gray900)
            .tabItem {
                Image(systemName: "photo.stack")
                Text("Processing")
            }

            // History view
            VStack {
                HistoryView(historyManager: historyManager)
                    .padding(Spacing.lg)

                Spacer()
            }
            .background(.gray900)
            .tabItem {
                Image(systemName: "clock")
                Text("History")
            }
        }
        .background(.gray900)
        .onAppear {
            configureWindowSizeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleDarkMode")))
        { _ in
            appearanceManager.toggleColorScheme()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenHelpWindow")))
        { _ in
            openHelpWindow()
        }
    }

    private func processImages(inputFilesOverride: [URL]? = nil) {
        let inputFiles = inputFilesOverride ?? fileSelectionVM.selectedFiles
        guard !inputFiles.isEmpty else { return }

        let settings = processingSettingsVM.getProcessingSettings()
        let outputFolderPath = settings.outputFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let saveAlongside = processingSettingsVM.effectivelySavesAlongsideOriginals
        let outputFolder: URL? = saveAlongside ? nil : URL(fileURLWithPath: outputFolderPath)
        guard
            let securityScopedURLs = prepareSecurityScopedAccess(
                inputFiles: inputFiles,
                outputFolder: outputFolder,
                saveAlongside: saveAlongside
            )
        else {
            return
        }
        let relativeOutputSubfolderByInputPath = Dictionary(
            uniqueKeysWithValues: inputFiles.compactMap { inputFile -> (String, String)? in
                guard let relativeSubfolder = fileSelectionVM.relativeOutputSubfolder(for: inputFile)
                else {
                    return nil
                }
                return (inputFile.path, relativeSubfolder)
            })

        // Reset state and cancel any pending auto-reset.
        progressResetTask?.cancel()
        progressResetTask = nil
        isProcessing = true
        isPaused = false
        progressText = nil
        lastFailedFiles = []
        withAnimation(.easeInOut(duration: 0.2)) { progressValue = 0.0 }
        progressPercentText = "0%"
        progressOpacity = 1.0
        processingThroughput = 0
        processingETA = nil
        startProcessingIndicator()
        let engine = ImageProcessingEngine.shared
        let control = ProcessingControl()
        processingControl = control

        processingTask = Task {
            defer { Self.stopSecurityScopedAccess(for: securityScopedURLs) }
            let results = await engine.processImages(
                inputURLs: inputFiles,
                outputFolder: outputFolder,
                maxWidth: Int(settings.maxWidth),
                maxHeight: Int(settings.maxHeight),
                compressionQuality: settings.compressionLevel,
                outputFormat: settings.outputFormat,
                targetDPI: Double(settings.dpi),
                preserveFolderStructure: settings.preserveFolderStructure,
                collisionPolicy: settings.collisionPolicy,
                relativeOutputSubfolderByInputPath: relativeOutputSubfolderByInputPath,
                processingControl: control
            ) { progress in
                Task { @MainActor in
                    // Update progress bar (0.0 to 1.0)
                    let clamped = min(1.0, max(0.0, progress.progressPercentage))
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.progressValue = clamped
                    }
                    self.progressPercentText = "\(Int(clamped * 100))%"
                    self.progressOpacity = 1.0
                    self.processingElapsedTime = progress.elapsedTime
                    self.processingThroughput = progress.throughputFilesPerSecond
                    self.processingETA = progress.estimatedTimeRemaining
                }
            }

            if Task.isCancelled {
                await MainActor.run {
                    self.processingTask = nil
                    self.isProcessing = false
                    self.isPaused = false
                    self.processingControl = nil
                    self.finishProcessingIndicator()
                    self.progressText =
                        "Processing cancelled (time to convert: \(self.formattedElapsedTime))."
                    self.progressPercentText = "Cancelled"
                }
                return
            }

            // Record history
            for result in results {
                let record = HistoryRecord(
                    inputFile: result.inputURL.path,
                    outputFile: result.outputURL?.path,
                    presetId: nil,
                    fileSizeBefore: result.fileSizeBefore,
                    fileSizeAfter: result.fileSizeAfter,
                    processingTime: result.processingTime,
                    success: result.success,
                    errorMessage: result.error?.localizedDescription
                )
                historyManager.addRecord(record)
            }

            await MainActor.run {
                self.processingTask = nil
                self.isProcessing = false
                self.isPaused = false
                self.processingControl = nil
                self.finishProcessingIndicator()
                withAnimation(.easeInOut(duration: 0.25)) { self.progressValue = 1.0 }
                self.progressPercentText = "100%"  // flash 100%
                // Flash Done!, then auto-reset after 5 seconds: fade the bar back
                // to 0 and restore the 0% label.
                self.progressResetTask = Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    self.progressPercentText = "Done!"

                    try? await Task.sleep(nanoseconds: 4_650_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        self.progressOpacity = 0.0
                        self.progressValue = 0.0
                    }

                    try? await Task.sleep(nanoseconds: 650_000_000)
                    guard !Task.isCancelled else { return }
                    self.progressPercentText = "0%"
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.progressOpacity = 1.0
                    }
                }

                let successCount = results.filter { $0.success }.count
                let skippedCount = results.filter { $0.skipped }.count
                let failureCount = results.count - successCount
                let permissionDeniedCount = results.filter {
                    if let processingError = $0.error as? ImageProcessingError,
                        case .permissionDenied = processingError
                    {
                        return true
                    }
                    return false
                }.count
                self.lastFailedFiles = results
                    .filter { !$0.success }
                    .map(\.inputURL)
                if successCount == 0 {
                    if saveAlongside, permissionDeniedCount > 0 {
                        self.progressText =
                            "No files were written. Grant folder access for alongside saves or choose an output folder."
                    } else {
                        self.progressText =
                            "No files were written. Check permissions and format support."
                    }
                } else if failureCount > 0 {
                    self.progressText =
                        "Processed \(successCount) file(s), \(failureCount) failed, \(skippedCount) skipped."
                } else {
                    if saveAlongside {
                        self.progressText =
                            "Processed \(successCount) file(s) alongside originals (\(skippedCount) skipped)."
                    } else {
                        self.progressText =
                            "Processed \(successCount) file(s) to \(outputFolder?.path ?? "") (\(skippedCount) skipped)."
                    }
                }
            }
        }
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

            let minSize = NSSize(width: 1280, height: 768)
            window.minSize = minSize

            let targetSize = NSSize(width: 1500, height: 900)
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

        var accessCandidates = inputFiles
        if let outputFolder {
            accessCandidates.append(outputFolder)
        }
        if saveAlongside {
            accessCandidates.append(contentsOf: parentFolders)
        }

        var activeAccessURLs = Self.startSecurityScopedAccess(for: accessCandidates)
        guard saveAlongside else {
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
                        .foregroundColor(.gray500)

                    Text("No files selected")
                        .font(.label)
                        .foregroundColor(.gray400)

                    Text("Select images to see them here")
                        .font(.caption)
                        .foregroundColor(.gray500)
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
                                .foregroundColor(.gray500)
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
                            .foregroundColor(.gray500)
                        Text(formattedSize)
                            .font(.caption)
                            .foregroundColor(.gray400)
                    }

                    if let dimensionsText = fileDetails?.dimensionsText {
                        Text("•")
                            .foregroundColor(.gray500)

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
        guard let cgThumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(
            cgImage: cgThumbnail,
            size: NSSize(width: cgThumbnail.width, height: cgThumbnail.height)
        )
    }
}

#Preview {
    ContentView(appearanceManager: AppearanceManager())
}
