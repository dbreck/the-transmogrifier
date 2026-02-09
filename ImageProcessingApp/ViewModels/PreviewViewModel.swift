import AppKit
import ImageIO
import os
import SwiftUI

private let previewLog = OSLog(
    subsystem: "app.thetransmogrifier",
    category: "preview"
)

@MainActor
class PreviewViewModel: ObservableObject {
    @Published var originalImage: NSImage? = nil
    @Published var processedImage: NSImage? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var imageMetadata: ImageMetadata? = nil
    @Published var processedImageMetadata: ImageMetadata? = nil

    private var currentImageURL: URL? = nil
    // Cache for processed images
    private var processedImageCache: [String: NSImage] = [:]
    private var loadingTask: Task<Void, Never>? = nil
    private var previewTask: Task<Void, Never>? = nil

    private let webPDecodingSupported = PreviewViewModel.detectWebPDecodingSupport()
    private let webPEncodingSupported = ImageProcessingEngine.isWebPEncodingAvailable()

    /// Load an image for preview
    /// - Parameter url: URL of the image to load
    func loadImage(for url: URL) {
        loadingTask?.cancel()
        previewTask?.cancel()

        currentImageURL = url
        isLoading = true
        errorMessage = nil

        // Clear processed image when loading a new image
        processedImage = nil
        processedImageMetadata = nil

        loadingTask = Task.detached(priority: .userInitiated) { [url] in
            let signpostID = OSSignpostID(log: previewLog)
            os_signpost(
                .begin,
                log: previewLog,
                name: "LoadPreviewImage",
                signpostID: signpostID,
                "%{public}s",
                url.lastPathComponent
            )
            defer {
                os_signpost(
                    .end,
                    log: previewLog,
                    name: "LoadPreviewImage",
                    signpostID: signpostID
                )
            }

            do {
                // Load the original image
                guard let image = NSImage(contentsOf: url) else {
                    throw PreviewError.failedToLoadImage
                }

                // Get image metadata
                let metadata = Self.extractImageMetadata(from: url, image: image)

                // Update on main thread
                await MainActor.run { [weak self] in
                    guard let self, self.currentImageURL == url else { return }
                    self.originalImage = image
                    self.currentImageURL = url
                    self.imageMetadata = metadata
                    self.isLoading = false
                    self.loadingTask = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.currentImageURL == url else { return }
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.loadingTask = nil
                }
            }
        }
    }

    /// Process the current image with the specified parameters for preview
    /// - Parameters:
    ///   - maxWidth: Maximum width constraint
    ///   - maxHeight: Maximum height constraint
    ///   - compressionQuality: Compression quality
    ///   - outputFormat: Output format
    func processPreview(
        maxWidth: Int,
        maxHeight: Int,
        compressionQuality: Float,
        outputFormat: String,
        targetDPI: Double = 72.0
    ) {
        guard let url = currentImageURL else {
            errorMessage = PreviewError.failedToLoadImage.localizedDescription
            return
        }

        // Validate parameters
        if maxWidth < 0 || maxHeight < 0 || compressionQuality < 0 || compressionQuality > 1 {
            errorMessage = PreviewError.invalidParameters.localizedDescription
            return
        }

        // Generate cache key
        let cacheKey = generateCacheKey(
            url: url,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            compressionQuality: compressionQuality,
            outputFormat: outputFormat,
            targetDPI: targetDPI
        )

        // Check cache first
        if let cachedImage = getCachedProcessedImage(forKey: cacheKey) {
            var pixelSize = cachedImage.size
            if let rep = cachedImage.representations.first {
                pixelSize = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            }
            let estimatedFileSize: Int64 = 0
            processedImage = cachedImage
            processedImageMetadata = ImageMetadata(
                fileType: outputFormat.uppercased(),
                fileSize: estimatedFileSize,
                dimensions: pixelSize,
                dpi: targetDPI
            )
            return
        }

        isLoading = true
        errorMessage = nil

        previewTask?.cancel()
        let webPEncodingSupported = self.webPEncodingSupported
        let webPDecodingSupported = self.webPDecodingSupported
        previewTask = Task.detached(priority: .userInitiated) { [url, cacheKey] in
            let signpostID = OSSignpostID(log: previewLog)
            os_signpost(
                .begin,
                log: previewLog,
                name: "ProcessPreviewImage",
                signpostID: signpostID,
                "%{public}s",
                url.lastPathComponent
            )
            defer {
                os_signpost(
                    .end,
                    log: previewLog,
                    name: "ProcessPreviewImage",
                    signpostID: signpostID
                )
            }

            do {
                // Decide preview format considering runtime support
                var effectiveFormat = outputFormat
                if outputFormat.lowercased() == "webp"
                    && !(webPEncodingSupported && webPDecodingSupported)
                {
                    effectiveFormat = "jpg"
                }

                let engine = ImageProcessingEngine()

                // Process in-memory and decode from Data to avoid preview temp-file I/O.
                let imageData = try await engine.processImage(
                    inputURL: url,
                    outputURL: url,
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    compressionQuality: compressionQuality,
                    outputFormat: effectiveFormat,
                    targetDPI: targetDPI
                )
                os_signpost(
                    .event,
                    log: previewLog,
                    name: "PreviewEncodeComplete",
                    signpostID: signpostID,
                    "bytes=%{public}d",
                    imageData.count
                )

                // Load the processed image for display
                guard let nsImage = NSImage(data: imageData) else {
                    throw PreviewError.failedToProcessImage
                }

                // Calculate processed image metadata with actual file size
                let processedMetadata = Self.calculateProcessedImageMetadata(
                    image: nsImage,
                    outputFormat: outputFormat,  // show intended format
                    actualFileSize: Int64(imageData.count),
                    targetDPI: targetDPI
                )

                // Update on main thread
                await MainActor.run { [weak self] in
                    guard let self, self.currentImageURL == url else { return }
                    self.cacheProcessedImage(nsImage, forKey: cacheKey)
                    self.processedImage = nsImage
                    self.processedImageMetadata = processedMetadata
                    self.isLoading = false
                    self.previewTask = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.currentImageURL == url else { return }
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.previewTask = nil
                }
            }
        }
    }

    /// Clear the preview
    func clearPreview() {
        loadingTask?.cancel()
        previewTask?.cancel()
        originalImage = nil
        processedImage = nil
        currentImageURL = nil
        imageMetadata = nil
        processedImageMetadata = nil
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Generate a cache key for processed images
    /// - Parameters:
    ///   - url: URL of the input image
    ///   - maxWidth: Maximum width constraint
    ///   - maxHeight: Maximum height constraint
    ///   - compressionQuality: Compression quality
    ///   - outputFormat: Output format
    /// - Returns: Cache key string
    private func generateCacheKey(
        url: URL,
        maxWidth: Int,
        maxHeight: Int,
        compressionQuality: Float,
        outputFormat: String,
        targetDPI: Double
    ) -> String {
        return
            "\(url.absoluteString)_\(maxWidth)_\(maxHeight)_\(compressionQuality)_\(outputFormat)_\(targetDPI)"
    }

    /// Get a cached processed image
    /// - Parameter key: Cache key
    /// - Returns: Cached NSImage or nil
    private func getCachedProcessedImage(forKey key: String) -> NSImage? {
        // Class is @MainActor; reads occur on main actor
        return processedImageCache[key]
    }

    /// Cache a processed image
    /// - Parameters:
    ///   - image: NSImage to cache
    ///   - key: Cache key
    private func cacheProcessedImage(_ image: NSImage, forKey key: String) {
        processedImageCache[key] = image
    }

    /// Extract metadata from an image
    /// - Parameters:
    ///   - url: URL of the image file
    ///   - image: NSImage instance
    /// - Returns: ImageMetadata struct
    nonisolated private static func extractImageMetadata(from url: URL, image: NSImage) -> ImageMetadata {
        // Get file size
        let fileSize =
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        // Get file type
        let fileExtension = url.pathExtension.uppercased()
        let fileType = fileExtension.isEmpty ? "Unknown" : fileExtension

        // Get actual image dimensions from the image representations
        var actualDimensions = image.size
        if let representation = image.representations.first {
            actualDimensions = NSSize(
                width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        // Get DPI/Resolution from image properties with better error handling
        var dpi: Double = 72.0  // Default DPI
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                as? [String: Any]
        {

            // Try to get DPI from various possible keys
            if let dpiX = properties[kCGImagePropertyDPIWidth as String] as? Double {
                dpi = dpiX
            } else if let dpiY = properties[kCGImagePropertyDPIHeight as String] as? Double {
                dpi = dpiY
            }

        }

        return ImageMetadata(
            fileType: fileType,
            fileSize: fileSize,
            dimensions: actualDimensions,
            dpi: dpi
        )
    }

    /// Calculate metadata for processed image
    /// - Parameters:
    ///   - image: Processed NSImage
    ///   - outputFormat: Output format string
    ///   - actualFileSize: Actual file size from temp file
    ///   - targetDPI: Target DPI for the processed image
    /// - Returns: ImageMetadata for processed image
    nonisolated private static func calculateProcessedImageMetadata(
        image: NSImage,
        outputFormat: String,
        actualFileSize: Int64,
        targetDPI: Double
    ) -> ImageMetadata {
        // Use pixel dimensions from the representation to avoid 72/DPI scaling
        var dimensions = image.size
        if let rep = image.representations.first {
            dimensions = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }

        return ImageMetadata(
            fileType: outputFormat.uppercased(),
            fileSize: actualFileSize,
            dimensions: dimensions,
            dpi: targetDPI
        )
    }

    nonisolated private static func detectWebPDecodingSupport() -> Bool {
        if let types = CGImageSourceCopyTypeIdentifiers() as? [String] {
            return types.contains { $0.lowercased().contains("webp") }
        }
        return false
    }
}

// MARK: - Image Metadata

struct ImageMetadata {
    let fileType: String
    let fileSize: Int64
    let dimensions: NSSize
    let dpi: Double

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var dimensionsFormatted: String {
        return "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }

    var dpiFormatted: String {
        return "\(Int(dpi)) DPI"
    }
}

// MARK: - Error Types

enum PreviewError: Error, LocalizedError {
    case failedToLoadImage
    case failedToProcessImage
    case invalidParameters

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "Failed to load the image for preview"
        case .failedToProcessImage:
            return "Failed to process the image for preview"
        case .invalidParameters:
            return "Invalid processing parameters"
        }
    }
}
