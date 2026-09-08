import AppKit
import ImageIO
import SwiftUI

@MainActor
final class PreviewViewModel: ObservableObject {
  @Published private(set) var originalImage: NSImage?
  @Published private(set) var processedImage: NSImage?
  @Published private(set) var imageMetadata: ImageMetadata?
  @Published private(set) var processedImageMetadata: ImageMetadata?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  private var requestID = UUID()
  private let cache = NSCache<NSString, CachedPreview>()

  init() {
    cache.countLimit = 3
    cache.totalCostLimit = 96 * 1024 * 1024
  }

  func clearPreview() {
    requestID = UUID()
    originalImage = nil
    processedImage = nil
    imageMetadata = nil
    processedImageMetadata = nil
    errorMessage = nil
    isLoading = false
  }

  /// Called by the view's identity-bound task: selection/settings changes cancel old work.
  func refresh(
    url: URL?, settings: ProcessingSettings, validationMessage: String?, debounce: Bool = true
  ) async {
    clearPreview()
    guard let url else { return }
    if let validationMessage {
      errorMessage = validationMessage
      return
    }
    let id = requestID
    isLoading = true
    do {
      if debounce { try await Task.sleep(nanoseconds: 300_000_000) }
      try Task.checkCancellation()
      let key = try await Task.detached(priority: .userInitiated) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let resource = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return
          "\(url.path)|\(resource.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(resource.fileSize ?? 0)|\(settings.previewIdentity)"
      }.value
      try Task.checkCancellation()
      guard requestID == id else { return }
      if let cached = cache.object(forKey: key as NSString) {
        publish(cached)
        return
      }
      // Decode and encode off the UI actor. Cancellation is explicitly forwarded to this worker.
      let worker = Task.detached(priority: .userInitiated) { () throws -> CachedPreview in
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try await Self.render(url: url, settings: settings, key: key)
      }
      let result = try await withTaskCancellationHandler(
        operation: { try await worker.value }, onCancel: { worker.cancel() })
      try Task.checkCancellation()
      guard requestID == id else { return }
      // Cache both the encoded size and image; a repeat can never report a synthetic zero.
      cache.setObject(result, forKey: result.key as NSString, cost: result.cost)
      publish(result)
    } catch {
      guard requestID == id else { return }
      isLoading = false
      if !(error is CancellationError) { errorMessage = error.localizedDescription }
    }
  }

  private func publish(_ result: CachedPreview) {
    originalImage = result.original
    processedImage = result.processed
    imageMetadata = result.originalMetadata
    processedImageMetadata = result.processedMetadata
    isLoading = false
  }

  private nonisolated static func render(url: URL, settings: ProcessingSettings, key: String)
    async throws -> CachedPreview
  {
    try Task.checkCancellation()
    guard let original = NSImage(contentsOf: url) else {
      throw ImageProcessingError.failedToLoadImage
    }
    let dimensions = ImageProcessingEngine.pixelDimensions(at: url)
    let jobs = ImageProcessingEngine.exportJobs(
      inputURLs: [url], maxWidth: settings.maxWidth,
      maxHeight: settings.maxHeight, format: settings.outputFormat,
      options: settings.exportOptions)
    // The largest WebP variant represents a responsive pack in the preview.
    let job = jobs.last(where: { $0.format == settings.outputFormat }) ?? jobs[0]
    let data = try await ImageProcessingEngine.shared.processImage(
      inputURL: url, maxWidth: job.width,
      maxHeight: job.height, compressionQuality: settings.compressionLevel,
      outputFormat: job.format,
      targetDPI: Double(settings.dpi), targetBytes: settings.exportOptions.targetBytes,
      minimumQuality: settings.exportOptions.minimumQuality)
    try Task.checkCancellation()
    guard let processed = NSImage(data: data),
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      throw ImageProcessingError.failedToLoadImage
    }
    return CachedPreview(
      key: key, original: original, processed: processed,
      originalMetadata: ImageMetadata(
        fileType: url.pathExtension.uppercased(),
        fileSize: Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0),
        dimensions: NSSize(width: dimensions.width, height: dimensions.height), dpi: 72),
      processedMetadata: ImageMetadata(
        fileType: job.format.uppercased(), fileSize: Int64(data.count),
        dimensions: NSSize(width: width, height: height), dpi: Double(settings.dpi)))
  }
}

private final class CachedPreview {
  let key: String
  let original: NSImage
  let processed: NSImage
  let originalMetadata: ImageMetadata
  let processedMetadata: ImageMetadata
  var cost: Int {
    Int(
      originalMetadata.dimensions.width * originalMetadata.dimensions.height + processedMetadata
        .dimensions.width * processedMetadata.dimensions.height) * 4
  }
  init(
    key: String, original: NSImage, processed: NSImage, originalMetadata: ImageMetadata,
    processedMetadata: ImageMetadata
  ) {
    self.key = key
    self.original = original
    self.processed = processed
    self.originalMetadata = originalMetadata
    self.processedMetadata = processedMetadata
  }
}

struct ImageMetadata {
  let fileType: String
  let fileSize: Int64
  let dimensions: NSSize
  let dpi: Double
  var fileSizeFormatted: String {
    ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
  }
  var dimensionsFormatted: String { "\(Int(dimensions.width)) × \(Int(dimensions.height))" }
  var dpiFormatted: String { "\(Int(dpi)) DPI" }
}
