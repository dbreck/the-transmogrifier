import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import os

#if canImport(libwebp)
  import libwebp
#endif

final class ImageProcessingEngine {
  /// The engine is stateless apart from its CIContexts (which are thread-safe),
  /// so one shared instance avoids rebuilding contexts for every run.
  static let shared = ImageProcessingEngine()

  private static let processingLog = OSLog(
    subsystem: "app.thetransmogrifier",
    category: "image-processing"
  )

  // Use GPU rendering by default and fall back to software when needed.
  private let primaryCIContext: CIContext = {
    let opts: [CIContextOption: Any] = [
      .useSoftwareRenderer: false
    ]
    return CIContext(options: opts)
  }()

  private let fallbackCIContext: CIContext = {
    let opts: [CIContextOption: Any] = [
      .useSoftwareRenderer: true
    ]
    return CIContext(options: opts)
  }()

  // MARK: - Capabilities

  private static let cachedWebPEncodingAvailability: Bool = {
    #if canImport(libwebp)
      return true
    #else
      let candidates: [CFString] = [
        (UTType(filenameExtension: "webp")?.identifier as CFString?) ?? "" as CFString,
        "org.webmproject.webp" as CFString,
        "public.webp" as CFString,
      ].filter { ($0 as String).isEmpty == false }
      for type in candidates {
        let dummy = NSMutableData()
        if CGImageDestinationCreateWithData(dummy, type, 1, nil) != nil { return true }
      }
      return false
    #endif
  }()

  static func isWebPEncodingAvailable() -> Bool {
    cachedWebPEncodingAvailability
  }

  // MARK: - Public API

  func processImage(
    inputURL: URL,
    maxWidth: Int,
    maxHeight: Int,
    compressionQuality: Float,
    outputFormat: String,
    targetDPI: Double = 72.0,
    targetBytes: Int? = nil,
    minimumQuality: Float = 0.4
  ) async throws -> Data {
    let signpostID = OSSignpostID(log: Self.processingLog)
    os_signpost(
      .begin,
      log: Self.processingLog,
      name: "ProcessImageCore",
      signpostID: signpostID,
      "%{public}s",
      inputURL.lastPathComponent
    )
    defer {
      os_signpost(
        .end,
        log: Self.processingLog,
        name: "ProcessImageCore",
        signpostID: signpostID
      )
    }

    try Task.checkCancellation()
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
      throw ImageProcessingError.failedToLoadImage
    }
    guard let image = CIImage(contentsOf: inputURL, options: [.applyOrientationProperty: true])
    else {
      throw ImageProcessingError.failedToLoadImage
    }
    guard image.extent.width > 0 && image.extent.height > 0 else {
      throw ImageProcessingError.corruptedImageFile
    }
    os_signpost(.event, log: Self.processingLog, name: "DecodeComplete", signpostID: signpostID)

    let processedImage = applyTransformations(
      to: image,
      maxWidth: maxWidth,
      maxHeight: maxHeight
    )
    os_signpost(
      .event,
      log: Self.processingLog,
      name: "TransformComplete",
      signpostID: signpostID
    )

    guard let cgImage = createCGImage(from: processedImage) else {
      throw ImageProcessingError.failedToCreateCGImage
    }
    func encode(_ quality: Float) throws -> Data {
      try Task.checkCancellation()
      return try self.encode(
        cgImage: cgImage, format: outputFormat, quality: quality, dpi: targetDPI)
    }
    let upperQuality = max(0, min(1, compressionQuality))
    let initial = try encode(upperQuality)
    guard let targetBytes, initial.count > targetBytes else { return initial }
    guard outputFormat.uppercased() != "PNG" else {
      throw ImageProcessingError.targetSizeUnreachable(
        actualBytes: initial.count, limitBytes: targetBytes)
    }
    let floor = max(0, min(upperQuality, minimumQuality))
    var best = try encode(floor)
    guard best.count <= targetBytes else {
      throw ImageProcessingError.targetSizeUnreachable(
        actualBytes: best.count, limitBytes: targetBytes)
    }
    var low = floor
    var high = upperQuality
    // Keep only encoded candidates whose actual byte count meets the budget.
    for _ in 0..<8 {
      let midpoint = (low + high) / 2
      let candidate = try encode(midpoint)
      if candidate.count <= targetBytes {
        best = candidate
        low = midpoint
      } else {
        high = midpoint
      }
    }
    return best
  }

  private func encode(cgImage: CGImage, format: String, quality: Float, dpi: Double) throws -> Data
  {
    switch format.uppercased() {
    case "JPG", "JPEG":
      return try convertToJPG(cgImage: cgImage, compressionQuality: quality, targetDPI: dpi)
    case "PNG": return try convertToPNG(cgImage: cgImage, targetDPI: dpi)
    case "WEBP":
      return try convertToWebP(cgImage: cgImage, compressionQuality: quality, targetDPI: dpi)
    default: throw ImageProcessingError.unsupportedOutputFormat
    }
  }

  /// Compute the output URL for a given input file, output folder, and format.
  /// When `outputFolder` is `nil` the file is placed alongside the original.
  /// Appends `_converted` when the output would overwrite the input (e.g. PNG→PNG).
  static func outputURL(
    for inputURL: URL,
    outputFolder: URL?,
    format: String,
    preserveFolderStructure: Bool = false,
    relativeOutputSubfolder: String? = nil,
    collisionPolicy: CollisionPolicy = .overwrite,
    outputName: String? = nil
  ) -> URL {
    let folder = destinationFolder(
      for: inputURL,
      outputFolder: outputFolder,
      preserveFolderStructure: preserveFolderStructure,
      relativeOutputSubfolder: relativeOutputSubfolder
    )
    let baseName = outputName ?? inputURL.deletingPathExtension().lastPathComponent
    var candidate =
      folder
      .appendingPathComponent(baseName)
      .appendingPathExtension(format.lowercased())
    if candidate.standardizedFileURL == inputURL.standardizedFileURL {
      candidate =
        folder
        .appendingPathComponent(baseName + "_converted")
        .appendingPathExtension(format.lowercased())
    }

    if collisionPolicy == .rename {
      candidate = firstAvailableOutputURL(startingAt: candidate) {
        FileManager.default.fileExists(atPath: $0)
      }
    }
    return candidate
  }

  private static func destinationFolder(
    for inputURL: URL,
    outputFolder: URL?,
    preserveFolderStructure: Bool,
    relativeOutputSubfolder: String?
  ) -> URL {
    guard let outputFolder else {
      return inputURL.deletingLastPathComponent()
    }
    guard preserveFolderStructure, let relativeOutputSubfolder, !relativeOutputSubfolder.isEmpty
    else {
      return outputFolder
    }
    return outputFolder.appendingPathComponent(relativeOutputSubfolder, isDirectory: true)
  }

  fileprivate static func firstAvailableOutputURL(
    startingAt url: URL,
    isTaken: (String) -> Bool
  ) -> URL {
    if !isTaken(url.path) {
      return url
    }

    let directory = url.deletingLastPathComponent()
    let ext = url.pathExtension
    let baseName = url.deletingPathExtension().lastPathComponent
    var counter = 1
    while true {
      let candidateName = "\(baseName)_\(counter)"
      let candidate = directory.appendingPathComponent(candidateName).appendingPathExtension(ext)
      if !isTaken(candidate.path) {
        return candidate
      }
      counter += 1
    }
  }

  func processImages(
    inputURLs: [URL], outputFolder: URL?, maxWidth: Int, maxHeight: Int,
    compressionQuality: Float, outputFormat: String, targetDPI: Double = 72,
    preserveFolderStructure: Bool = false, collisionPolicy: CollisionPolicy = .rename,
    relativeOutputSubfolderByInputPath: [String: String] = [:],
    processingControl: ProcessingControl? = nil,
    exportOptions: ExportOptions = ExportOptions(), onlyJobKeys: Set<String>? = nil,
    progressHandler: @escaping (BatchProgress) -> Void
  ) async -> [ImageProcessingResult] {
    let start = CFAbsoluteTimeGetCurrent()
    let jobs = Self.exportJobs(
      inputURLs: inputURLs, maxWidth: maxWidth, maxHeight: maxHeight,
      format: outputFormat, options: exportOptions
    )
    .filter { onlyJobKeys == nil || onlyJobKeys!.contains($0.key) }
    guard !jobs.isEmpty else { return [] }
    let queue = ProcessingWorkQueue(jobs: jobs)
    // Reserve source paths too: a variant name must never overwrite another input.
    let reservations = OutputPathReservations(
      protectedPaths: Set(inputURLs.map { $0.resolvingSymlinksInPath().standardizedFileURL.path }))
    let tracker = ProcessingProgressTracker(totalFiles: jobs.count, startTime: start)
    let indexed = await withTaskGroup(of: [(Int, ImageProcessingResult)].self) { group in
      for _ in 0..<Self.recommendedWorkerCount(for: jobs.count) {
        group.addTask {
          var results: [(Int, ImageProcessingResult)] = []
          while !Task.isCancelled {
            do { try await processingControl?.waitIfPaused() } catch { break }
            guard !Task.isCancelled, let item = await queue.next() else { break }
            var result = await self.processSingleImage(
              inputURL: item.job.url, outputFolder: outputFolder,
              maxWidth: item.job.width, maxHeight: item.job.height,
              compressionQuality: compressionQuality, outputFormat: item.job.format,
              targetDPI: targetDPI, preserveFolderStructure: preserveFolderStructure,
              relativeOutputSubfolder: relativeOutputSubfolderByInputPath[item.job.url.path],
              collisionPolicy: collisionPolicy, outputReservations: reservations,
              outputName: item.job.outputName, exportOptions: exportOptions)
            result.jobKey = item.job.key
            results.append((item.index, result))
            let progress = await tracker.advance(currentFileName: item.job.url.lastPathComponent)
            await MainActor.run { progressHandler(progress) }
          }
          return results
        }
      }
      var results: [(Int, ImageProcessingResult)] = []
      for await part in group { results.append(contentsOf: part) }
      return results
    }
    var results = jobs.map { job in
      ImageProcessingResult(
        inputURL: job.url, outputURL: nil, success: false, skipped: false,
        error: ImageProcessingError.cancelled, fileSizeBefore: 0, fileSizeAfter: 0,
        processingTime: 0, jobKey: job.key)
    }
    for (index, result) in indexed { results[index] = result }
    return results
  }

  static func exportJobs(
    inputURLs: [URL], maxWidth: Int, maxHeight: Int,
    format: String, options: ExportOptions
  ) -> [ExportJob] {
    inputURLs.flatMap { url -> [ExportJob] in
      guard options.isResponsive else {
        return [
          ExportJob(url: url, width: maxWidth, height: maxHeight, format: format, outputName: nil)
        ]
      }
      let dimensions = pixelDimensions(at: url)
      var emitted = Set<String>()
      return options.responsiveWidths.sorted().flatMap { width -> [ExportJob] in
        let cap = maxWidth > 0 ? min(width, maxWidth) : width
        let ratio = min(
          1, Double(cap) / Double(max(1, dimensions.width)),
          maxHeight > 0 ? Double(maxHeight) / Double(max(1, dimensions.height)) : 1)
        let actualWidth = max(1, Int((Double(dimensions.width) * ratio).rounded(.down)))
        let name = options.namingTemplate.replacingOccurrences(
          of: "{name}", with: url.deletingPathExtension().lastPathComponent
        )
        .replacingOccurrences(of: "{width}", with: String(actualWidth))
        let formats = options.includeJPEGFallback ? [format, "JPG"] : [format]
        return formats.compactMap { format in
          guard emitted.insert("\(actualWidth)-\(format.uppercased())").inserted else { return nil }
          return ExportJob(
            url: url, width: actualWidth, height: 0, format: format, outputName: name)
        }
      }
    }
  }

  static func pixelDimensions(at url: URL) -> (width: Int, height: Int) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { return (1, 1) }
    let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
    return (5...8).contains(orientation) ? (height, width) : (width, height)
  }

  // MARK: - Private

  private static func recommendedWorkerCount(for fileCount: Int) -> Int {
    let cpuCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
    let cappedByCPU = max(1, min(4, cpuCount))
    return min(fileCount, cappedByCPU)
  }

  private func processSingleImage(
    inputURL: URL,
    outputFolder: URL?,
    maxWidth: Int,
    maxHeight: Int,
    compressionQuality: Float,
    outputFormat: String,
    targetDPI: Double,
    preserveFolderStructure: Bool,
    relativeOutputSubfolder: String?,
    collisionPolicy: CollisionPolicy,
    outputReservations: OutputPathReservations,
    outputName: String?,
    exportOptions: ExportOptions
  ) async -> ImageProcessingResult {
    let signpostID = OSSignpostID(log: Self.processingLog)
    os_signpost(
      .begin,
      log: Self.processingLog,
      name: "ProcessSingleImage",
      signpostID: signpostID,
      "%{public}s",
      inputURL.lastPathComponent
    )
    defer {
      os_signpost(
        .end,
        log: Self.processingLog,
        name: "ProcessSingleImage",
        signpostID: signpostID
      )
    }

    if Task.isCancelled {
      return ImageProcessingResult(
        inputURL: inputURL,
        outputURL: nil,
        success: false,
        skipped: false,
        error: ImageProcessingError.cancelled,
        fileSizeBefore: 0,
        fileSizeAfter: 0,
        processingTime: 0
      )
    }

    let fileStartTime = CFAbsoluteTimeGetCurrent()
    do {
      let desiredFormat = outputFormat.uppercased()
      // Rename-uniquing is handled atomically by outputReservations, so the
      // base candidate is always computed without it.
      func baseOutputURL(for format: String) -> URL {
        ImageProcessingEngine.outputURL(
          for: inputURL,
          outputFolder: outputFolder,
          format: format,
          preserveFolderStructure: preserveFolderStructure,
          relativeOutputSubfolder: relativeOutputSubfolder,
          collisionPolicy: .overwrite,
          outputName: outputName
        )
      }
      var outputURL = baseOutputURL(for: desiredFormat)
      outputURL = await outputReservations.claim(outputURL, collisionPolicy: collisionPolicy)
      if collisionPolicy == .skip && FileManager.default.fileExists(atPath: outputURL.path) {
        return ImageProcessingResult(
          inputURL: inputURL, outputURL: outputURL, success: true,
          skipped: true, error: nil, fileSizeBefore: 0, fileSizeAfter: 0,
          processingTime: CFAbsoluteTimeGetCurrent() - fileStartTime)
      }
      let imageData = try await processImage(
        inputURL: inputURL, maxWidth: maxWidth,
        maxHeight: maxHeight, compressionQuality: compressionQuality, outputFormat: desiredFormat,
        targetDPI: targetDPI, targetBytes: exportOptions.targetBytes,
        minimumQuality: exportOptions.minimumQuality)
      try Task.checkCancellation()

      let folder = outputURL.deletingLastPathComponent()
      if !FileManager.default.fileExists(atPath: folder.path) {
        do {
          try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
          )
        } catch {
          throw ImageProcessingError.invalidOutputPath
        }
      }

      do {
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: folder.path)
        if let free = attrs[.systemFreeSize] as? NSNumber,
          free.int64Value < Int64(imageData.count)
        {
          throw ImageProcessingError.diskFull
        }
      } catch {
        // Ignore disk check lookup errors and proceed to write attempt.
      }

      do {
        try Task.checkCancellation()
        try imageData.write(to: outputURL, options: .atomic)
      } catch let error as NSError {
        if error.code == NSFileWriteNoPermissionError {
          throw ImageProcessingError.permissionDenied
        }
        if error.code == NSFileWriteOutOfSpaceError {
          throw ImageProcessingError.diskFull
        }
        throw error
      }
      os_signpost(.event, log: Self.processingLog, name: "WriteComplete", signpostID: signpostID)

      let fileEndTime = CFAbsoluteTimeGetCurrent()
      return ImageProcessingResult(
        inputURL: inputURL,
        outputURL: outputURL,
        success: true,
        skipped: false,
        error: nil,
        fileSizeBefore: (try? FileManager.default.attributesOfItem(
          atPath: inputURL.path)[.size] as? Int64) ?? 0,
        fileSizeAfter: Int64(imageData.count),
        processingTime: fileEndTime - fileStartTime,
        pixelWidth: Self.pixelDimensions(at: outputURL).width
      )
    } catch {
      let fileEndTime = CFAbsoluteTimeGetCurrent()
      return ImageProcessingResult(
        inputURL: inputURL,
        outputURL: nil,
        success: false,
        skipped: false,
        error: error,
        fileSizeBefore: 0,
        fileSizeAfter: 0,
        processingTime: fileEndTime - fileStartTime
      )
    }
  }

  func applyTransformations(
    to image: CIImage,
    maxWidth: Int,
    maxHeight: Int
  ) -> CIImage {
    var result = image
    if maxWidth > 0 || maxHeight > 0 {
      let originalExtent = image.extent
      let originalWidth = originalExtent.width
      let originalHeight = originalExtent.height
      var targetWidth = originalWidth
      var targetHeight = originalHeight
      // Max dimensions are a cap: never scale up images that already fit.
      if maxWidth > 0 && maxHeight > 0 {
        let widthRatio = CGFloat(maxWidth) / originalWidth
        let heightRatio = CGFloat(maxHeight) / originalHeight
        let ratio = min(widthRatio, heightRatio, 1.0)
        targetWidth = originalWidth * ratio
        targetHeight = originalHeight * ratio
      } else if maxWidth > 0 {
        let ratio = min(CGFloat(maxWidth) / originalWidth, 1.0)
        targetWidth = originalWidth * ratio
        targetHeight = originalHeight * ratio
      } else if maxHeight > 0 {
        let ratio = min(CGFloat(maxHeight) / originalHeight, 1.0)
        targetWidth = originalWidth * ratio
        targetHeight = originalHeight * ratio
      }
      let scaleX = targetWidth / originalWidth
      let scaleY = targetHeight / originalHeight
      result = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
    return result
  }

  private func createCGImage(from image: CIImage) -> CGImage? {
    if let imageFromPrimary = primaryCIContext.createCGImage(image, from: image.extent) {
      return imageFromPrimary
    }
    return fallbackCIContext.createCGImage(image, from: image.extent)
  }

  private func convertToJPG(
    cgImage: CGImage,
    compressionQuality: Float,
    targetDPI: Double = 72.0
  ) throws -> Data {
    let mutableData = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        mutableData, UTType.jpeg.identifier as CFString, 1, nil)
    else {
      throw ImageProcessingError.failedToCreateJPG
    }
    let properties: [CFString: Any] = [
      kCGImagePropertyDPIWidth: targetDPI,
      kCGImagePropertyDPIHeight: targetDPI,
      kCGImagePropertyJFIFDictionary: [
        kCGImagePropertyJFIFXDensity: targetDPI,
        kCGImagePropertyJFIFYDensity: targetDPI,
        kCGImagePropertyJFIFDensityUnit: 1,
      ],
      kCGImageDestinationLossyCompressionQuality: compressionQuality,
    ]
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw ImageProcessingError.failedToCreateJPG
    }
    return mutableData as Data
  }

  private func convertToPNG(
    cgImage: CGImage,
    targetDPI: Double = 72.0
  ) throws -> Data {
    let mutableData = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        mutableData, UTType.png.identifier as CFString, 1, nil)
    else {
      throw ImageProcessingError.unsupportedOutputFormat
    }
    let properties: [CFString: Any] = [
      kCGImagePropertyDPIWidth: targetDPI,
      kCGImagePropertyDPIHeight: targetDPI,
    ]
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw ImageProcessingError.unsupportedOutputFormat
    }
    return mutableData as Data
  }

  private func convertToWebP(
    cgImage: CGImage,
    compressionQuality: Float,
    targetDPI: Double = 72.0
  ) throws -> Data {
    #if canImport(libwebp)
      if let data = try? encodeWebPUsingLibWebP(cgImage: cgImage, quality: compressionQuality) {
        return data
      }
    #endif
    let candidates: [CFString] = [
      (UTType(filenameExtension: "webp")?.identifier as CFString?) ?? "" as CFString,
      "org.webmproject.webp" as CFString,
      "public.webp" as CFString,
    ].filter { ($0 as String).isEmpty == false }
    var lastError: Error = ImageProcessingError.unsupportedOutputFormat
    for type in candidates {
      let data = NSMutableData()
      if let dest = CGImageDestinationCreateWithData(data, type, 1, nil) {
        let props: [CFString: Any] = [
          kCGImageDestinationLossyCompressionQuality: compressionQuality,
          kCGImagePropertyDPIWidth: targetDPI,
          kCGImagePropertyDPIHeight: targetDPI,
        ]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        if CGImageDestinationFinalize(dest) {
          return data as Data
        } else {
          lastError = ImageProcessingError.failedToCreateWebP
        }
      } else {
        lastError = ImageProcessingError.unsupportedOutputFormat
      }
    }
    throw lastError
  }

  #if canImport(libwebp)
    private func encodeWebPUsingLibWebP(cgImage: CGImage, quality: Float) throws -> Data {
      let width = cgImage.width
      let height = cgImage.height
      let bytesPerPixel = 4
      let bytesPerRow = width * bytesPerPixel
      let bufferSize = bytesPerRow * height
      var rgba = [UInt8](repeating: 0, count: bufferSize)
      guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
      else {
        throw ImageProcessingError.failedToCreateCGImage
      }
      let q = max(0, min(1, quality)) * 100.0
      // The CGContext keeps using the buffer after init, so the pointer must
      // stay valid for the context's whole lifetime.
      return try rgba.withUnsafeMutableBytes { buffer -> Data in
        guard
          let baseAddress = buffer.baseAddress,
          let ctx = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              | CGBitmapInfo.byteOrder32Big.rawValue
          )
        else { throw ImageProcessingError.failedToCreateCGImage }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var outputPtr: UnsafeMutablePointer<UInt8>? = nil
        let outSize = WebPEncodeRGBA(
          baseAddress.assumingMemoryBound(to: UInt8.self),
          Int32(width), Int32(height), Int32(bytesPerRow), q, &outputPtr)
        guard outSize > 0, let outputPtr else {
          throw ImageProcessingError.failedToCreateWebP
        }
        defer { WebPFree(outputPtr) }
        return Data(bytes: outputPtr, count: Int(outSize))
      }
    }
  #endif
}

/// Reserves output paths for a batch so concurrent workers never write the same
/// file, even when different inputs map to the same output name (e.g. two
/// folders flattened into one destination both containing "photo.png").
private actor OutputPathReservations {
  private var claimedPaths: Set<String>
  init(protectedPaths: Set<String>) { claimedPaths = protectedPaths }
  func claim(_ url: URL, collisionPolicy: CollisionPolicy) -> URL {
    var candidate = url
    if collisionPolicy == .rename
      || claimedPaths.contains(candidate.resolvingSymlinksInPath().standardizedFileURL.path)
    {
      candidate = ImageProcessingEngine.firstAvailableOutputURL(startingAt: url) { path in
        claimedPaths.contains(
          URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path)
          || FileManager.default.fileExists(atPath: path)
      }
    }
    claimedPaths.insert(candidate.resolvingSymlinksInPath().standardizedFileURL.path)
    return candidate
  }
}

struct ExportJob {
  let url: URL
  let width: Int
  let height: Int
  let format: String
  let outputName: String?
  var key: String { "\(url.path)|\(width)|\(height)|\(format.uppercased())" }
}

private actor ProcessingWorkQueue {
  private let jobs: [ExportJob]
  private var nextIndex = 0
  init(jobs: [ExportJob]) { self.jobs = jobs }
  func next() -> (index: Int, job: ExportJob)? {
    guard nextIndex < jobs.count else { return nil }
    defer { nextIndex += 1 }
    return (nextIndex, jobs[nextIndex])
  }
}

actor ProcessingControl {
  private var paused = false
  func setPaused(_ paused: Bool) { self.paused = paused }
  func waitIfPaused() async throws {
    while paused { try await Task.sleep(nanoseconds: 100_000_000) }
    try Task.checkCancellation()
  }
}

private actor ProcessingProgressTracker {
  private let totalFiles: Int
  private let startTime: CFAbsoluteTime
  private var processedFiles: Int = 0

  init(totalFiles: Int, startTime: CFAbsoluteTime) {
    self.totalFiles = totalFiles
    self.startTime = startTime
  }

  func advance(currentFileName: String) -> BatchProgress {
    processedFiles += 1
    let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
    return BatchProgress(
      currentFile: min(processedFiles, totalFiles),
      totalFiles: totalFiles,
      currentFileName: currentFileName,
      elapsedTime: elapsedTime
    )
  }
}

// MARK: - Error Types

enum ImageProcessingError: Error, LocalizedError {
  case failedToLoadImage
  case failedToCreateCGImage
  case unsupportedOutputFormat
  case failedToCreateJPG
  case failedToCreateWebP
  case invalidOutputPath
  case diskFull
  case permissionDenied
  case corruptedImageFile
  case unsupportedColorProfile
  case cancelled
  case targetSizeUnreachable(actualBytes: Int, limitBytes: Int)

  var errorDescription: String? {
    switch self {
    case .failedToLoadImage: return "Failed to load the image file"
    case .failedToCreateCGImage: return "Failed to create CGImage from CIImage"
    case .unsupportedOutputFormat: return "Unsupported output format"
    case .failedToCreateJPG: return "Failed to create JPG image"
    case .failedToCreateWebP: return "Failed to create WebP image"
    case .invalidOutputPath: return "Invalid output path"
    case .diskFull: return "Disk is full"
    case .permissionDenied: return "Permission denied"
    case .corruptedImageFile: return "Corrupted image file"
    case .unsupportedColorProfile: return "Unsupported color profile"
    case .targetSizeUnreachable(let actual, let limit):
      return
        "Cannot meet \(limit / 1000) KB at these dimensions and minimum quality (smallest tested: \((actual + 999) / 1000) KB). Lower dimensions or minimum quality, or raise the limit. No file written."
    case .cancelled: return "Processing was cancelled"
    }
  }
}

// MARK: - Progress Types

struct BatchProgress {
  let currentFile: Int
  let totalFiles: Int
  let currentFileName: String
  let elapsedTime: Double
  let totalTime: Double?

  init(
    currentFile: Int,
    totalFiles: Int,
    currentFileName: String,
    elapsedTime: Double = 0,
    totalTime: Double? = nil
  ) {
    self.currentFile = currentFile
    self.totalFiles = totalFiles
    self.currentFileName = currentFileName
    self.elapsedTime = elapsedTime
    self.totalTime = totalTime
  }

  var progressPercentage: Double { Double(currentFile) / Double(totalFiles) }
  var throughputFilesPerSecond: Double {
    guard elapsedTime > 0 else { return 0 }
    return Double(currentFile) / elapsedTime
  }
  var remainingFiles: Int { max(0, totalFiles - currentFile) }
  var estimatedTimeRemaining: Double? {
    let throughput = throughputFilesPerSecond
    guard throughput > 0, remainingFiles > 0 else { return nil }
    return Double(remainingFiles) / throughput
  }

  var progressText: String {
    if let totalTime = totalTime {
      return
        "\(currentFile)/\(totalFiles) - \(currentFileName) (Total time: \(String(format: "%.2f", totalTime))s)"
    } else {
      return "\(currentFile)/\(totalFiles) - \(currentFileName)"
    }
  }
}

// MARK: - Result Types

struct ImageProcessingResult {
  let inputURL: URL
  let outputURL: URL?
  let success: Bool
  let skipped: Bool
  let error: Error?
  let fileSizeBefore: Int64
  let fileSizeAfter: Int64
  let processingTime: Double
  var jobKey: String = ""
  var pixelWidth: Int? = nil
}
