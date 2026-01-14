import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if canImport(libwebp)
    import libwebp
#endif

class ImageProcessingEngine: ObservableObject {
    // Prefer a CPU-based CIContext to avoid Metal cache issues on some systems
    private let ciContext: CIContext = {
        let opts: [CIContextOption: Any] = [
            .useSoftwareRenderer: true
        ]
        return CIContext(options: opts)
    }()

    // MARK: - Capabilities

    static func isWebPEncodingAvailable() -> Bool {
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
    }

    // MARK: - Public API

    func processImage(
        inputURL: URL,
        outputURL: URL,
        maxWidth: Int,
        maxHeight: Int,
        compressionQuality: Float,
        outputFormat: String,
        targetDPI: Double = 72.0
    ) async throws -> Data {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ImageProcessingError.failedToLoadImage
        }
        guard let image = CIImage(contentsOf: inputURL) else {
            throw ImageProcessingError.failedToLoadImage
        }
        guard image.extent.width > 0 && image.extent.height > 0 else {
            throw ImageProcessingError.corruptedImageFile
        }

        let processedImage = applyTransformations(
            to: image,
            maxWidth: maxWidth,
            maxHeight: maxHeight
        )

        let imageData = try convertToOutputFormat(
            processedImage,
            format: outputFormat,
            compressionQuality: compressionQuality,
            targetDPI: targetDPI
        )

        return imageData
    }

    func processImages(
        inputURLs: [URL],
        outputFolder: URL,
        maxWidth: Int,
        maxHeight: Int,
        compressionQuality: Float,
        outputFormat: String,
        targetDPI: Double = 72.0,
        presetId: UUID? = nil,
        progressHandler: @escaping (BatchProgress) -> Void
    ) async -> [ImageProcessingResult] {
        let startTime = CFAbsoluteTimeGetCurrent()

        if !FileManager.default.fileExists(atPath: outputFolder.path) {
            do {
                try FileManager.default.createDirectory(
                    at: outputFolder, withIntermediateDirectories: true)
            } catch {
                return inputURLs.map { url in
                    ImageProcessingResult(
                        inputURL: url,
                        outputURL: nil,
                        success: false,
                        error: ImageProcessingError.invalidOutputPath,
                        fileSizeBefore: 0,
                        fileSizeAfter: 0,
                        processingTime: 0
                    )
                }
            }
        }

        let results = await withTaskGroup(of: (Int, ImageProcessingResult).self) { group in
            var results: [ImageProcessingResult] = Array(
                repeating: ImageProcessingResult(
                    inputURL: URL(fileURLWithPath: ""),
                    outputURL: nil,
                    success: false,
                    error: nil,
                    fileSizeBefore: 0,
                    fileSizeAfter: 0,
                    processingTime: 0
                ), count: inputURLs.count)

            for (index, inputURL) in inputURLs.enumerated() {
                group.addTask {
                    let fileStartTime = CFAbsoluteTimeGetCurrent()
                    do {
                        let desiredFormat = outputFormat.uppercased()
                        func makeOutputURL(for format: String) -> URL {
                            outputFolder
                                .appendingPathComponent(
                                    inputURL.deletingPathExtension().lastPathComponent
                                )
                                .appendingPathExtension(format.lowercased())
                        }

                        var attemptFormat = desiredFormat
                        var outputURL = makeOutputURL(for: attemptFormat)
                        var imageData: Data

                        do {
                            imageData = try await self.processImage(
                                inputURL: inputURL,
                                outputURL: outputURL,
                                maxWidth: maxWidth,
                                maxHeight: maxHeight,
                                compressionQuality: compressionQuality,
                                outputFormat: attemptFormat,
                                targetDPI: targetDPI
                            )
                        } catch {
                            if desiredFormat == "WEBP",
                                case ImageProcessingError.unsupportedOutputFormat = error
                            {
                                attemptFormat = "JPG"
                                outputURL = makeOutputURL(for: attemptFormat)
                                imageData = try await self.processImage(
                                    inputURL: inputURL,
                                    outputURL: outputURL,
                                    maxWidth: maxWidth,
                                    maxHeight: maxHeight,
                                    compressionQuality: compressionQuality,
                                    outputFormat: attemptFormat,
                                    targetDPI: targetDPI
                                )
                            } else {
                                throw error
                            }
                        }

                        let folder = outputURL.deletingLastPathComponent()
                        guard FileManager.default.fileExists(atPath: folder.path) else {
                            throw ImageProcessingError.invalidOutputPath
                        }

                        do {
                            let attrs = try FileManager.default.attributesOfFileSystem(
                                forPath: folder.path)
                            if let free = attrs[.systemFreeSize] as? NSNumber,
                                free.int64Value < Int64(imageData.count)
                            {
                                throw ImageProcessingError.diskFull
                            }
                        } catch {
                            // ignore disk check errors
                        }

                        do { try imageData.write(to: outputURL) } catch let error as NSError {
                            if error.code == NSFileWriteNoPermissionError {
                                throw ImageProcessingError.permissionDenied
                            }
                            if error.code == NSFileWriteOutOfSpaceError {
                                throw ImageProcessingError.diskFull
                            }
                            throw error
                        }

                        let fileEndTime = CFAbsoluteTimeGetCurrent()
                        let fileProcessingTime = fileEndTime - fileStartTime

                        let result = ImageProcessingResult(
                            inputURL: inputURL,
                            outputURL: outputURL,
                            success: true,
                            error: nil,
                            fileSizeBefore: (try? FileManager.default.attributesOfItem(
                                atPath: inputURL.path)[.size] as? Int64) ?? 0,
                            fileSizeAfter: Int64(imageData.count),
                            processingTime: fileProcessingTime
                        )

                        let progress = BatchProgress(
                            currentFile: index + 1,
                            totalFiles: inputURLs.count,
                            currentFileName: inputURL.lastPathComponent
                        )
                        DispatchQueue.main.async { progressHandler(progress) }

                        return (index, result)
                    } catch {
                        let fileEndTime = CFAbsoluteTimeGetCurrent()
                        let result = ImageProcessingResult(
                            inputURL: inputURL,
                            outputURL: nil,
                            success: false,
                            error: error,
                            fileSizeBefore: 0,
                            fileSizeAfter: 0,
                            processingTime: fileEndTime - fileStartTime
                        )
                        let progress = BatchProgress(
                            currentFile: index + 1,
                            totalFiles: inputURLs.count,
                            currentFileName: inputURL.lastPathComponent
                        )
                        DispatchQueue.main.async { progressHandler(progress) }
                        return (index, result)
                    }
                }
            }

            for await (i, r) in group { results[i] = r }
            return results
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let finalProgress = BatchProgress(
            currentFile: inputURLs.count,
            totalFiles: inputURLs.count,
            currentFileName: "Completed",
            totalTime: totalTime
        )
        DispatchQueue.main.async { progressHandler(finalProgress) }
        return results
    }

    // MARK: - Private

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
            if maxWidth > 0 && maxHeight > 0 {
                let widthRatio = CGFloat(maxWidth) / originalWidth
                let heightRatio = CGFloat(maxHeight) / originalHeight
                let ratio = min(widthRatio, heightRatio)
                targetWidth = originalWidth * ratio
                targetHeight = originalHeight * ratio
            } else if maxWidth > 0 {
                let ratio = CGFloat(maxWidth) / originalWidth
                targetWidth = CGFloat(maxWidth)
                targetHeight = originalHeight * ratio
            } else if maxHeight > 0 {
                let ratio = CGFloat(maxHeight) / originalHeight
                targetWidth = originalWidth * ratio
                targetHeight = CGFloat(maxHeight)
            }
            let scaleX = targetWidth / originalWidth
            let scaleY = targetHeight / originalHeight
            result = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }
        return result
    }

    private func convertToOutputFormat(
        _ image: CIImage,
        format: String,
        compressionQuality: Float,
        targetDPI: Double = 72.0
    ) throws -> Data {
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            throw ImageProcessingError.failedToCreateCGImage
        }
        switch format.uppercased() {
        case "JPG", "JPEG":
            return try convertToJPG(
                cgImage: cgImage, compressionQuality: compressionQuality, targetDPI: targetDPI)
        case "PNG":
            return try convertToPNG(cgImage: cgImage, targetDPI: targetDPI)
        case "WEBP":
            return try convertToWebP(
                cgImage: cgImage, compressionQuality: compressionQuality, targetDPI: targetDPI)
        default:
            throw ImageProcessingError.unsupportedOutputFormat
        }
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
            if let data = try? encodeWebPUsingLibWebP(cgImage: cgImage, quality: compressionQuality)
            {
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
            guard
                let ctx = CGContext(
                    data: &rgba,
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
            let q = max(0, min(1, quality)) * 100.0
            let outSize = WebPEncodeRGBA(
                &rgba, Int32(width), Int32(height), Int32(bytesPerRow), q, &outputPtr)
            guard outSize > 0, let outputPtr else { throw ImageProcessingError.failedToCreateWebP }
            let data = Data(bytes: outputPtr, count: Int(outSize))
            WebPFree(outputPtr)
            return data
        }
    #endif
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
        }
    }
}

// MARK: - Progress Types

struct BatchProgress {
    let currentFile: Int
    let totalFiles: Int
    let currentFileName: String
    let totalTime: Double?

    init(currentFile: Int, totalFiles: Int, currentFileName: String, totalTime: Double? = nil) {
        self.currentFile = currentFile
        self.totalFiles = totalFiles
        self.currentFileName = currentFileName
        self.totalTime = totalTime
    }

    var progressPercentage: Double { Double(currentFile) / Double(totalFiles) }

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
    let error: Error?
    let fileSizeBefore: Int64
    let fileSizeAfter: Int64
    let processingTime: Double
}
