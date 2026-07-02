import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import os
import SwiftUI
import UniformTypeIdentifiers

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
        targetDPI: Double = 72.0
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

        let imageData = try convertToOutputFormat(
            processedImage,
            format: outputFormat,
            compressionQuality: compressionQuality,
            targetDPI: targetDPI
        )
        os_signpost(
            .event,
            log: Self.processingLog,
            name: "EncodeComplete",
            signpostID: signpostID,
            "bytes=%{public}d",
            imageData.count
        )

        return imageData
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
        collisionPolicy: CollisionPolicy = .overwrite
    ) -> URL {
        let folder = destinationFolder(
            for: inputURL,
            outputFolder: outputFolder,
            preserveFolderStructure: preserveFolderStructure,
            relativeOutputSubfolder: relativeOutputSubfolder
        )
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        var candidate = folder
            .appendingPathComponent(baseName)
            .appendingPathExtension(format.lowercased())
        if candidate.standardizedFileURL == inputURL.standardizedFileURL {
            candidate = folder
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
        inputURLs: [URL],
        outputFolder: URL?,
        maxWidth: Int,
        maxHeight: Int,
        compressionQuality: Float,
        outputFormat: String,
        targetDPI: Double = 72.0,
        preserveFolderStructure: Bool = false,
        collisionPolicy: CollisionPolicy = .overwrite,
        relativeOutputSubfolderByInputPath: [String: String] = [:],
        processingControl: ProcessingControl? = nil,
        presetId: UUID? = nil,
        progressHandler: @escaping (BatchProgress) -> Void
    ) async -> [ImageProcessingResult] {
        guard !inputURLs.isEmpty else { return [] }
        let startTime = CFAbsoluteTimeGetCurrent()

        if let outputFolder, !FileManager.default.fileExists(atPath: outputFolder.path) {
            do {
                try FileManager.default.createDirectory(
                    at: outputFolder, withIntermediateDirectories: true)
            } catch {
                return inputURLs.map { url in
                    ImageProcessingResult(
                        inputURL: url,
                        outputURL: nil,
                        success: false,
                        skipped: false,
                        error: ImageProcessingError.invalidOutputPath,
                        fileSizeBefore: 0,
                        fileSizeAfter: 0,
                        processingTime: 0
                    )
                }
            }
        }

        let workQueue = ProcessingWorkQueue(urls: inputURLs)
        let outputReservations = OutputPathReservations()
        let progressTracker = ProcessingProgressTracker(
            totalFiles: inputURLs.count,
            startTime: startTime
        )
        let workerCount = Self.recommendedWorkerCount(for: inputURLs.count)

        let indexedResults = await withTaskGroup(of: [(Int, ImageProcessingResult)].self) { group in
            for _ in 0..<workerCount {
                group.addTask {
                    var workerResults: [(Int, ImageProcessingResult)] = []
                    while !Task.isCancelled {
                        if let processingControl {
                            await processingControl.waitIfPaused()
                        }
                        guard let workItem = await workQueue.next() else { break }
                        let result = await self.processSingleImage(
                            inputURL: workItem.url,
                            outputFolder: outputFolder,
                            maxWidth: maxWidth,
                            maxHeight: maxHeight,
                            compressionQuality: compressionQuality,
                            outputFormat: outputFormat,
                            targetDPI: targetDPI,
                            preserveFolderStructure: preserveFolderStructure,
                            relativeOutputSubfolder: relativeOutputSubfolderByInputPath[
                                workItem.url.path
                            ],
                            collisionPolicy: collisionPolicy,
                            outputReservations: outputReservations
                        )
                        workerResults.append((workItem.index, result))

                        let progress = await progressTracker.advance(
                            currentFileName: workItem.url.lastPathComponent)
                        await MainActor.run { progressHandler(progress) }
                    }
                    return workerResults
                }
            }

            var mergedResults: [(Int, ImageProcessingResult)] = []
            for await workerResults in group {
                mergedResults.append(contentsOf: workerResults)
            }
            return mergedResults
        }

        var results: [ImageProcessingResult] = Array(
            repeating: ImageProcessingResult(
                inputURL: URL(fileURLWithPath: ""),
                outputURL: nil,
                success: false,
                skipped: false,
                error: nil,
                fileSizeBefore: 0,
                fileSizeAfter: 0,
                processingTime: 0
            ),
            count: inputURLs.count
        )
        for (index, result) in indexedResults {
            results[index] = result
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let finalProgress = BatchProgress(
            currentFile: inputURLs.count,
            totalFiles: inputURLs.count,
            currentFileName: "Completed",
            totalTime: totalTime
        )
        await MainActor.run { progressHandler(finalProgress) }
        return results
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
        outputReservations: OutputPathReservations
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
                    collisionPolicy: .overwrite
                )
            }
            func makeOutputURL(for format: String) async -> URL {
                await outputReservations.claim(
                    baseOutputURL(for: format), collisionPolicy: collisionPolicy)
            }

            var attemptFormat = desiredFormat
            var outputURL = baseOutputURL(for: attemptFormat)
            if collisionPolicy == .skip && FileManager.default.fileExists(atPath: outputURL.path) {
                let fileEndTime = CFAbsoluteTimeGetCurrent()
                let inputSize = (try? FileManager.default.attributesOfItem(
                    atPath: inputURL.path)[.size] as? Int64) ?? 0
                let outputSize = (try? FileManager.default.attributesOfItem(
                    atPath: outputURL.path)[.size] as? Int64) ?? 0
                return ImageProcessingResult(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    success: true,
                    skipped: true,
                    error: nil,
                    fileSizeBefore: inputSize,
                    fileSizeAfter: outputSize,
                    processingTime: fileEndTime - fileStartTime
                )
            }
            outputURL = await outputReservations.claim(outputURL, collisionPolicy: collisionPolicy)
            var imageData: Data

            do {
                imageData = try await processImage(
                    inputURL: inputURL,
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
                    outputURL = await makeOutputURL(for: attemptFormat)
                    imageData = try await processImage(
                        inputURL: inputURL,
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
                try imageData.write(to: outputURL)
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
                processingTime: fileEndTime - fileStartTime
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

    private func convertToOutputFormat(
        _ image: CIImage,
        format: String,
        compressionQuality: Float,
        targetDPI: Double = 72.0
    ) throws -> Data {
        guard let cgImage = createCGImage(from: image) else {
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
    private var claimedPaths: Set<String> = []

    func claim(_ url: URL, collisionPolicy: CollisionPolicy) -> URL {
        var candidate = url
        if collisionPolicy == .rename || claimedPaths.contains(candidate.path) {
            candidate = ImageProcessingEngine.firstAvailableOutputURL(startingAt: url) { path in
                claimedPaths.contains(path) || FileManager.default.fileExists(atPath: path)
            }
        }
        claimedPaths.insert(candidate.path)
        return candidate
    }
}

private actor ProcessingWorkQueue {
    private let urls: [URL]
    private var nextIndex: Int = 0

    init(urls: [URL]) {
        self.urls = urls
    }

    func next() -> (index: Int, url: URL)? {
        guard nextIndex < urls.count else { return nil }
        defer { nextIndex += 1 }
        return (nextIndex, urls[nextIndex])
    }
}

actor ProcessingControl {
    private var paused = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func setPaused(_ paused: Bool) {
        self.paused = paused
        guard !paused else { return }
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    func waitIfPaused() async {
        guard paused else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
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
}
