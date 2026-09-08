import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct ExportWorkflowChecks {
  static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
      throw NSError(domain: "ExportChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
  }
  static func makeImage(at url: URL, width: Int = 800, height: Int = 500) throws {
    var seed: UInt32 = 12345
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      seed = seed &* 1_664_525 &+ 1_013_904_223
      pixels[offset] = UInt8(truncatingIfNeeded: seed >> 16)
      pixels[offset + 1] = UInt8(truncatingIfNeeded: offset / 100)
      pixels[offset + 2] = UInt8(truncatingIfNeeded: offset / 300)
    }
    let data = Data(pixels)
    let provider = CGDataProvider(data: data as CFData)!
    let image = CGImage(
      width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
      decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    try check(CGImageDestinationFinalize(destination), "Create fixture")
  }
  @MainActor
  static func main() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "transmogrifier-checks-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("sample.png")
    try makeImage(at: input)
    let engine = ImageProcessingEngine.shared
    try check(
      ImageProcessingEngine.isWebPEncodingAvailable(), "Tests must use the bundled WebP encoder")
    let high = try await engine.processImage(
      inputURL: input, maxWidth: 0, maxHeight: 0, compressionQuality: 0.9, outputFormat: "WebP")
    let low = try await engine.processImage(
      inputURL: input, maxWidth: 0, maxHeight: 0, compressionQuality: 0.4, outputFormat: "WebP")
    let budget = (high.count + low.count) / 2
    let bounded = try await engine.processImage(
      inputURL: input, maxWidth: 0, maxHeight: 0,
      compressionQuality: 0.9, outputFormat: "WebP", targetBytes: budget, minimumQuality: 0.4)
    try check(bounded.count <= budget && bounded.count > 0, "Actual encoded bytes must meet target")
    print("PASS target-size WebP encoding")

    let impossible = await engine.processImages(
      inputURLs: [input], outputFolder: root.appendingPathComponent("impossible"),
      maxWidth: 0, maxHeight: 0, compressionQuality: 0.9, outputFormat: "WebP",
      exportOptions: ExportOptions(targetSizeKB: 1), progressHandler: { _ in })
    try check(
      impossible.count == 1 && !impossible[0].success && impossible[0].outputURL == nil,
      "Unreachable target must fail without writing")
    try check(
      !FileManager.default.fileExists(
        atPath: root.appendingPathComponent("impossible/sample.webp").path),
      "Impossible target wrote a file")
    do {
      _ = try await engine.processImage(
        inputURL: input, maxWidth: 0, maxHeight: 0,
        compressionQuality: 0.8, outputFormat: "PNG", targetBytes: 1000)
      throw NSError(domain: "PNG target unexpectedly passed", code: 1)
    } catch ImageProcessingError.targetSizeUnreachable {}
    print("PASS unreachable budgets and PNG lossless limits")

    let options = ExportOptions(
      responsiveWidths: [320, 640, 1280, 1920], includeJPEGFallback: true)
    let pack = await engine.processImages(
      inputURLs: [input], outputFolder: root.appendingPathComponent("pack"),
      maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
      exportOptions: options, progressHandler: { _ in })
    try check(
      pack.count == 6 && pack.allSatisfy(\.success),
      "Responsive pack must deduplicate capped widths and include fallback")
    try check(
      Set(pack.compactMap(\.pixelWidth)) == [320, 640, 800],
      "Responsive output widths or no-upscale behavior incorrect")
    for result in pack {
      try check(
        result.outputURL!.lastPathComponent.contains("-\(result.pixelWidth!)"),
        "Filename width must match encoded pixels")
    }
    let originalData = try Data(contentsOf: input)
    let sourceAlias = root.appendingPathComponent("sample-640.webp")
    try high.write(to: sourceAlias)
    let protected = await engine.processImages(
      inputURLs: [input, sourceAlias], outputFolder: root,
      maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
      collisionPolicy: .overwrite,
      exportOptions: ExportOptions(responsiveWidths: [640]), progressHandler: { _ in })
    try check(protected.allSatisfy(\.success), "Protected-source pack failed")
    let protectedData = try Data(contentsOf: sourceAlias)
    try check(protectedData == high, "A responsive filename overwrote another original")
    let preservedData = try Data(contentsOf: input)
    try check(preservedData == originalData, "Original was modified")
    print("PASS responsive widths, JPEG fallback, source protection")

    let skipped = await engine.processImages(
      inputURLs: [input], outputFolder: root.appendingPathComponent("pack"),
      maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
      collisionPolicy: .skip,
      exportOptions: options, progressHandler: { _ in })
    try check(skipped.allSatisfy(\.skipped), "Skip must apply to every variant")
    let singleKey = pack[0].jobKey
    let retried = await engine.processImages(
      inputURLs: [input], outputFolder: root.appendingPathComponent("retry"),
      maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
      exportOptions: options,
      onlyJobKeys: [singleKey], progressHandler: { _ in })
    try check(
      retried.count == 1 && retried[0].jobKey == singleKey && retried[0].success,
      "Retry must only run selected variants")
    print("PASS skip policy and precise variant retries")

    let control = ProcessingControl()
    await control.setPaused(true)
    let task = Task {
      await engine.processImages(
        inputURLs: [input], outputFolder: root.appendingPathComponent("cancelled"),
        maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
        processingControl: control,
        exportOptions: options, progressHandler: { _ in })
    }
    try await Task.sleep(nanoseconds: 100_000_000)
    task.cancel()
    let cancelled = await task.value
    try check(
      cancelled.count == 6
        && cancelled.allSatisfy { !$0.success && $0.inputURL == input && !$0.jobKey.isEmpty },
      "Cancelled jobs need original identity and must finish while paused")
    print("PASS cancellation while paused and unfinished job identity")

    var cancellationInputs: [URL] = []
    for index in 0..<16 {
      let url = root.appendingPathComponent("cancel-input-\(index).png")
      try FileManager.default.copyItem(at: input, to: url)
      cancellationInputs.append(url)
    }
    var activeTask: Task<[ImageProcessingResult], Never>?
    activeTask = Task {
      await engine.processImages(
        inputURLs: cancellationInputs, outputFolder: root.appendingPathComponent("partial"),
        maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
        progressHandler: { _ in activeTask?.cancel() })
    }
    let partial = await activeTask!.value
    try check(
      partial.count == 16 && partial.contains(where: \.success)
        && partial.contains(where: { !$0.success }),
      "Cancelling an active batch must retain completed results and mark unfinished ones")
    for result in partial where result.success {
      try check(
        FileManager.default.fileExists(atPath: result.outputURL!.path),
        "Completed output disappeared on cancellation")
    }
    print("PASS completed outputs retained on mid-batch cancellation")

    let viewModel = ProcessingSettingsViewModel()
    try check(viewModel.quality == 80, "Fresh install quality")
    viewModel.saveAlongsideOriginals = false
    try check(
      viewModel.validationMessage != nil, "Empty output folder must not silently save alongside")
    viewModel.saveAlongsideOriginals = true
    let settings = viewModel.getProcessingSettings()
    let preview = PreviewViewModel()
    await preview.refresh(url: input, settings: settings, validationMessage: nil, debounce: false)
    let firstSize = preview.processedImageMetadata?.fileSize
    await preview.refresh(url: input, settings: settings, validationMessage: nil, debounce: false)
    try check(
      firstSize != nil && firstSize! > 0 && preview.processedImageMetadata?.fileSize == firstSize,
      "Cached preview lost metadata")
    await preview.refresh(url: nil, settings: settings, validationMessage: nil)
    try check(
      preview.originalImage == nil && preview.processedImage == nil && !preview.isLoading,
      "Cleared selection left stale preview")
    let old = Task { await preview.refresh(url: input, settings: settings, validationMessage: nil) }
    while !preview.isLoading { await Task.yield() }
    await preview.refresh(url: nil, settings: settings, validationMessage: nil)
    await old.value
    try check(preview.processedImage == nil, "Older async preview replaced cleared selection")
    print("PASS cached preview size, clear selection and stale result rejection")

    var legacy = Preset.defaultPresets[1]
    legacy.compressionLevel = 0.7
    var json =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
    json.removeValue(forKey: "exportOptions")
    let decoded = try JSONDecoder().decode(
      Preset.self, from: JSONSerialization.data(withJSONObject: json))
    viewModel.applyCustomPreset(decoded)
    try check(
      abs(viewModel.quality - 70) < 0.01 && !viewModel.createsResponsivePack,
      "Legacy preset changed quality")
    viewModel.createsResponsivePack = true
    viewModel.usesTargetSize = true
    let roundTrip = try JSONDecoder().decode(
      Preset.self, from: JSONEncoder().encode(viewModel.makePreset(name: "Pack")))
    try check(
      roundTrip.exportOptions.responsiveWidths == [640, 1280, 1920]
        && roundTrip.exportOptions.targetSizeKB == 200, "New preset options did not round-trip")
    viewModel.namingTemplate = "../{name}-{width}"
    try check(viewModel.validationMessage != nil, "Unsafe naming template accepted")
    print("PASS legacy presets, recipe persistence and input validation")

    let opener = OpenFilesDelegate()
    opener.enqueue([input])
    opener.enqueue([sourceAlias])
    try check(
      opener.takeNext() == [input] && opener.takeNext() == [sourceAlias]
        && opener.takeNext() == nil, "Dock requests must be claimed once in order")
    opener.receive(input)
    opener.receive(sourceAlias)
    opener.receive(input)
    try await Task.sleep(nanoseconds: 300_000_000)
    try check(
      opener.takeNext() == [input, sourceAlias] && opener.takeNext() == nil,
      "SwiftUI file callbacks must become one deduplicated batch")
    try check(
      Preset.defaultPresets.map(\.id) == Preset.defaultPresets.map(\.id),
      "Quick Convert built-in IDs must survive reloading")
    print("PASS Dock request queue and stable preset identifiers")

    // Same basenames from different directories cannot race even with overwrite enabled.
    let otherFolder = root.appendingPathComponent("other")
    try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)
    let duplicate = otherFolder.appendingPathComponent("sample.png")
    try makeImage(at: duplicate, width: 600, height: 400)
    let collisions = await engine.processImages(
      inputURLs: [input, duplicate], outputFolder: root.appendingPathComponent("collisions"),
      maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
      collisionPolicy: .overwrite, progressHandler: { _ in })
    try check(
      collisions.count == 2 && collisions.allSatisfy(\.success)
        && Set(collisions.compactMap(\.outputURL)).count == 2,
      "Concurrent duplicate basenames collided")
    let portraitData = NSMutableData()
    let orientationDestination = CGImageDestinationCreateWithData(
      portraitData, UTType.jpeg.identifier as CFString, 1, nil)!
    let fixtureSource = CGImageSourceCreateWithURL(input as CFURL, nil)!
    CGImageDestinationAddImage(
      orientationDestination, CGImageSourceCreateImageAtIndex(fixtureSource, 0, nil)!,
      [kCGImagePropertyOrientation: 6] as CFDictionary)
    try check(CGImageDestinationFinalize(orientationDestination), "Orientation fixture")
    let portraitURL = root.appendingPathComponent("portrait.jpg")
    try (portraitData as Data).write(to: portraitURL)
    let portrait = await engine.processImages(
      inputURLs: [portraitURL], outputFolder: root.appendingPathComponent("portrait-pack"),
      maxWidth: 0, maxHeight: 0, compressionQuality: 0.8, outputFormat: "WebP",
      exportOptions: ExportOptions(responsiveWidths: [320, 640]), progressHandler: { _ in })
    try check(
      Set(portrait.compactMap(\.pixelWidth)) == [320, 500],
      "EXIF orientation was ignored in variant sizing")
    print("PASS duplicate basename races and oriented responsive exports")

    let suite = "app.thetransmogrifier.checks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let record = HistoryRecord(
      inputFile: input.path, outputFile: nil, presetId: nil,
      fileSizeBefore: 100, fileSizeAfter: 0, processingTime: 0, success: false,
      errorMessage: "Example")
    defaults.set(try JSONEncoder().encode([record]), forKey: "ProcessingHistory")
    let historyURL = root.appendingPathComponent("history/jobs.json")
    let history = HistoryManager(fileURL: historyURL, defaults: defaults)
    try check(
      history.batches.count == 1 && history.batches[0].records.count == 1, "Legacy history lost")
    let records = pack.map { result -> HistoryRecord in
      var record = HistoryRecord(
        inputFile: input.path, outputFile: result.outputURL?.path, presetId: nil,
        fileSizeBefore: result.fileSizeBefore, fileSizeAfter: result.fileSizeAfter,
        processingTime: result.processingTime, success: true)
      record.jobKey = result.jobKey
      record.pixelWidth = result.pixelWidth
      return record
    }
    let batch = HistoryBatch(
      name: "Test pack", settings: settings, inputFiles: [input.path],
      relativeSubfolders: [:], bookmarks: [], records: records, wasCancelled: false)
    history.addBatch(batch)
    let reloaded = HistoryManager(fileURL: historyURL, defaults: defaults)
    try check(
      reloaded.batches.count == 2 && reloaded.batches[0].records.count == 6,
      "Batch history failed persistence")
    try check(
      reloaded.batches[0].srcset.contains("sample-640.webp 640w"),
      "srcset missing actual output name and width")
    print("PASS history migration, batch persistence and srcset")
    print("All export workflow checks passed.")
  }
}
