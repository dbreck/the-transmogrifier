import SwiftUI
import AppKit

@MainActor
struct ContentView: View {
    @StateObject private var fileSelectionVM = FileSelectionViewModel()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var processingSettingsVM = ProcessingSettingsViewModel()
    @State private var showingOutputFolderAlert = false
    @State private var isProcessing = false
    @State private var progressText: String? = nil
    // Always-visible progress state
    @State private var progressValue: Double = 0.0  // 0.0 - 1.0
    @State private var progressPercentText: String = "0%"
    @State private var progressOpacity: Double = 1.0
    @State private var progressResetWorkItem: DispatchWorkItem? = nil
    // Overwrite warning
    @State private var showingOverwriteAlert = false
    @State private var overwriteConflictCount = 0
    // Onboarding tour
    @State private var showingOnboardingTour = false

    let appearanceManager: AppearanceManager

    init(appearanceManager: AppearanceManager) {
        self.appearanceManager = appearanceManager
    }

    var body: some View {
        TabView {
            // Main processing view - 3 column grid
            HStack(spacing: Spacing.lg) {
                // Left 2/3: File Selection, Preview, Processing Parameters, and Controls
                VStack(spacing: Spacing.lg) {
                    // Top Row: File Selection + Preview (side by side)
                    HStack(spacing: Spacing.lg) {
                        // File Selection (1/2 of left area)
                        TransmogrifierCard(title: "File Selection", icon: "square.and.arrow.up") {
                            FileSelectionView(viewModel: fileSelectionVM)
                                .frame(height: 180)
                        }
                        .frame(maxWidth: .infinity)

                        // Preview (1/2 of left area)
                        TransmogrifierCard(title: "Preview", icon: "eye") {
                            PreviewView(
                                fileSelectionViewModel: fileSelectionVM,
                                processingSettingsViewModel: processingSettingsVM
                            )
                            .frame(height: 180)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 280)

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
                                if let progressText = progressText {
                                    Text(progressText)
                                        .font(.caption)
                                        .foregroundColor(.gray400)
                                }
                            }
                            HStack(spacing: Spacing.md) {
                                TransmogrifierButton(
                                    isProcessing ? "Processing…" : "Process Images",
                                    icon: "bolt.fill"
                                ) {
                                    processImages()
                                }
                                .disabled(fileSelectionVM.selectedFiles.isEmpty || isProcessing)
                                .frame(maxWidth: .infinity)

                                Button("Cancel") {
                                    // TODO: hook up cancellation
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(Color.gray700)
                                .foregroundColor(.gray300)
                                .cornerRadius(6)
                                .disabled(true)
                            }
                        }
                    }
                    .padding(.top, 0)
                }
                .frame(maxWidth: .infinity)

                // Right 1/3: Selected Files (Full Height)
                SelectedFilesPanel(viewModel: fileSelectionVM)
                    .frame(width: 380)
            }
            .padding(Spacing.lg)
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
        .onboardingTour(isPresented: $showingOnboardingTour)
        .onAppear {
            presetManager.loadPresets()

            // Show tour on first launch
            if !UserDefaults.standard.bool(forKey: "hasShownOnboardingTour") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingOnboardingTour = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleDarkMode")))
        { _ in
            appearanceManager.toggleColorScheme()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowOnboardingTour")))
        { _ in
            showingOnboardingTour = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenHelpWindow")))
        { _ in
            openHelpWindow()
        }
        .alert("Output Folder Required", isPresented: $showingOutputFolderAlert) {
            Button("OK") {}
        } message: {
            Text("Please select an output folder before processing images.")
        }
        .alert("Overwrite existing files?", isPresented: $showingOverwriteAlert) {
            Button("Cancel", role: .cancel) { showingOverwriteAlert = false }
            Button("Overwrite", role: .destructive) {
                showingOverwriteAlert = false
                processImages(confirmedOverwrite: true)
            }
        } message: {
            Text(
                "This will overwrite \(overwriteConflictCount) existing file(s) in the output folder."
            )
        }
    }

    private func processImages(confirmedOverwrite: Bool = false) {
        guard !fileSelectionVM.selectedFiles.isEmpty else { return }

        guard let settings = processingSettingsVM.getProcessingSettings() else {
            showingOutputFolderAlert = true
            return
        }

        // Check for existing files that would be overwritten (warn once per run)
        let inputFiles = fileSelectionVM.selectedFiles
        let outputFolder = URL(fileURLWithPath: settings.outputFolder)
        let desiredFormat = settings.outputFormat.uppercased()
        func outURL(for format: String, inputURL: URL) -> URL {
            outputFolder
                .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
                .appendingPathExtension(format.lowercased())
        }
        let conflicts = inputFiles.filter {
            FileManager.default.fileExists(atPath: outURL(for: desiredFormat, inputURL: $0).path)
        }
        if !confirmedOverwrite && !conflicts.isEmpty {
            overwriteConflictCount = conflicts.count
            showingOverwriteAlert = true
            return
        }

        // Reset state and cancel any pending auto-reset
        progressResetWorkItem?.cancel()
        progressResetWorkItem = nil
        isProcessing = true
        progressText = nil
        withAnimation(.easeInOut(duration: 0.2)) { progressValue = 0.0 }
        progressPercentText = "0%"
        progressOpacity = 1.0
        let engine = ImageProcessingEngine()

        Task {
            let results = await engine.processImages(
                inputURLs: inputFiles,
                outputFolder: outputFolder,
                maxWidth: Int(settings.maxWidth),
                maxHeight: Int(settings.maxHeight),
                compressionQuality: settings.compressionLevel,
                outputFormat: settings.outputFormat,
                targetDPI: Double(settings.dpi)
            ) { progress in
                Task { @MainActor in
                    self.progressText = progress.progressText
                    // Update progress bar (0.0 to 1.0)
                    let clamped = min(1.0, max(0.0, progress.progressPercentage))
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.progressValue = clamped
                    }
                    self.progressPercentText = "\(Int(clamped * 100))%"
                    self.progressOpacity = 1.0
                }
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
                self.isProcessing = false
                withAnimation(.easeInOut(duration: 0.25)) { self.progressValue = 1.0 }
                self.progressPercentText = "100%"  // flash 100%
                // Show Done! after a brief flash
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.progressPercentText = "Done!"
                }
                // Auto-reset after 5 seconds: fade and animate bar back to 0, then restore 0%
                let work = DispatchWorkItem {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        self.progressOpacity = 0.0
                        self.progressValue = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                        self.progressPercentText = "0%"
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.progressOpacity = 1.0
                        }
                    }
                }
                self.progressResetWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)

                let successCount = results.filter { $0.success }.count
                let failureCount = results.count - successCount
                if successCount == 0 {
                    self.progressText =
                        "No files were written. Check output folder permissions and format support."
                } else if failureCount > 0 {
                    self.progressText = "Processed \(successCount) file(s), \(failureCount) failed."
                } else {
                    self.progressText = "Processed \(successCount) file(s) to \(outputFolder.path)."
                }
            }
        }
    }

    private func openHelpWindow() {
        HelpWindowManager.shared.showHelpWindow()
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
        viewModel.selectedFiles.removeAll { $0 == file }
        if viewModel.selectedFileForPreview == file {
            viewModel.selectedFileForPreview = viewModel.selectedFiles.first
        }
    }

    private func clearAll() {
        viewModel.selectedFiles.removeAll()
        viewModel.selectedFileForPreview = nil
        viewModel.errorMessage = nil
    }
}

struct SelectedFileCard: View {
    let file: URL
    let isSelectedForPreview: Bool
    let onSelectForPreview: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Thumbnail placeholder
            AsyncImage(url: file) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(.gray700)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray500)
                    )
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

                    if let fileSize = try? FileManager.default.attributesOfItem(atPath: file.path)[
                        .size] as? Int64
                    {
                        let formattedSize = {
                            let formatter = ByteCountFormatter()
                            formatter.allowedUnits = [.useKB, .useMB]
                            formatter.countStyle = .file
                            return formatter.string(fromByteCount: fileSize)
                        }()

                        Text("•")
                            .foregroundColor(.gray500)
                        Text(formattedSize)
                            .font(.caption)
                            .foregroundColor(.gray400)
                    }

                    if let image = NSImage(contentsOf: file) {
                        Text("•")
                            .foregroundColor(.gray500)

                        Text("\(Int(image.size.width)) × \(Int(image.size.height))")
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
    }
}

#Preview {
    ContentView(appearanceManager: AppearanceManager())
}
