import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import SwiftUI

@MainActor
class PreviewViewModel: ObservableObject {
    @Published var originalImage: NSImage? = nil
    @Published var processedImage: NSImage? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var imageMetadata: ImageMetadata? = nil
    @Published var processedImageMetadata: ImageMetadata? = nil

    private var currentImageURL: URL? = nil
    private let engine = ImageProcessingEngine()

    // Cache for processed images
    private var processedImageCache: [String: NSImage] = [:]

    /// Load an image for preview
    /// - Parameter url: URL of the image to load
    func loadImage(for url: URL) {
        isLoading = true
        errorMessage = nil

        // Clear processed image when loading a new image
        processedImage = nil

        Task {
            do {
                // Load the original image
                guard let image = NSImage(contentsOf: url) else {
                    throw PreviewError.failedToLoadImage
                }

                // Get image metadata
                let metadata = self.extractImageMetadata(from: url, image: image)

                // Update on main thread
                await MainActor.run {
                    self.originalImage = image
                    self.currentImageURL = url
                    self.imageMetadata = metadata
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
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

        Task {
            do {
                // Decide preview format considering runtime support
                var effectiveFormat = outputFormat
                if outputFormat.lowercased() == "webp"
                    && (!supportsWebPEncoding() || !supportsWebPDecoding())
                {
                    effectiveFormat = "jpg"
                }

                let tempURL = createTempURL(for: effectiveFormat)

                // Use the engine to process and save to temp file
                let imageData = try await engine.processImage(
                    inputURL: url,
                    outputURL: tempURL,
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    compressionQuality: compressionQuality,
                    outputFormat: effectiveFormat,
                    targetDPI: targetDPI
                )

                // Write to temp file to get actual file size
                try imageData.write(to: tempURL)

                // Load the processed image for display
                guard let nsImage = NSImage(contentsOf: tempURL) else {
                    throw PreviewError.failedToProcessImage
                }

                // Get actual file size from temp file
                let actualFileSize =
                    (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size]
                        as? Int64) ?? 0

                // Calculate processed image metadata with actual file size
                let processedMetadata = self.calculateProcessedImageMetadata(
                    image: nsImage,
                    outputFormat: outputFormat,  // show intended format
                    actualFileSize: actualFileSize,
                    targetDPI: targetDPI
                )

                // Cache the processed image
                cacheProcessedImage(nsImage, forKey: cacheKey)

                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)

                // Update on main thread
                await MainActor.run {
                    self.processedImage = nsImage
                    self.processedImageMetadata = processedMetadata
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    /// Clear the preview
    func clearPreview() {
        originalImage = nil
        processedImage = nil
        currentImageURL = nil
        imageMetadata = nil
        processedImageMetadata = nil
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Process an image for preview (without saving to disk)
    /// - Parameters:
    ///   - inputURL: URL of the input image
    ///   - maxWidth: Maximum width constraint
    ///   - maxHeight: Maximum height constraint
    ///   - compressionQuality: Compression quality
    ///   - outputFormat: Output format
    /// - Returns: Processed CIImage
    private func processImageForPreview(
        inputURL: URL,
        maxWidth: Int,
        maxHeight: Int,
        compressionQuality: Float,
        outputFormat: String
    ) async throws -> CIImage {
        // Load the image
        guard let image = CIImage(contentsOf: inputURL) else {
            throw PreviewError.failedToLoadImage
        }

        // Apply transformations
        let processedImage = engine.applyTransformations(
            to: image,
            maxWidth: maxWidth,
            maxHeight: maxHeight
        )

        return processedImage
    }

    /// Convert CIImage to NSImage
    /// - Parameter ciImage: Input CIImage
    /// - Returns: NSImage representation
    private func convertCIImageToNSImage(_ ciImage: CIImage) -> NSImage {
        // Use a software CIContext to avoid Metal when rendering previews
        let context = CIContext(options: [.useSoftwareRenderer: true])

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return NSImage(size: NSSize(width: 100, height: 100))
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

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
        // Ensure mutation happens on the main actor to satisfy isolation
        Task { @MainActor in
            self.processedImageCache[key] = image
        }
    }

    /// Extract metadata from an image
    /// - Parameters:
    ///   - url: URL of the image file
    ///   - image: NSImage instance
    /// - Returns: ImageMetadata struct
    private func extractImageMetadata(from url: URL, image: NSImage) -> ImageMetadata {
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

            // Debug: Print all available properties to understand what's available
            print("DEBUG: Image properties for \(url.lastPathComponent):")
            for (key, value) in properties {
                print("  \(key): \(value)")
            }
        }

        print(
            "DEBUG: Extracted metadata - Size: \(actualDimensions), DPI: \(dpi), FileSize: \(fileSize)"
        )

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
    private func calculateProcessedImageMetadata(
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

    /// Create a temporary URL for processing
    /// - Parameter outputFormat: Output format string
    /// - Returns: Temporary file URL
    private func createTempURL(for outputFormat: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        // Use provided extension verbatim
        let ext = outputFormat.lowercased()
        let fileName = "preview_temp.\(ext)"
        return tempDir.appendingPathComponent(fileName)
    }

    /// Returns true if the current system can decode WebP via ImageIO/NSImage
    private func supportsWebPDecoding() -> Bool {
        if let types = CGImageSourceCopyTypeIdentifiers() as? [String] {
            return types.contains { $0.lowercased().contains("webp") }
        }
        return false
    }

    /// Returns true if the current system can encode WebP via ImageIO
    private func supportsWebPEncoding() -> Bool {
        if let types = CGImageDestinationCopyTypeIdentifiers() as? [String] {
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
