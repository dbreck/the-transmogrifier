import Foundation

struct HistoryRecord: Identifiable, Codable {
    let id: UUID
    let inputFile: String
    let outputFile: String?
    let presetId: UUID?
    let processingDate: Date
    let fileSizeBefore: Int64
    let fileSizeAfter: Int64
    let processingTime: Double
    let success: Bool
    let errorMessage: String?
    
    init(
        id: UUID = UUID(),
        inputFile: String,
        outputFile: String?,
        presetId: UUID?,
        processingDate: Date = Date(),
        fileSizeBefore: Int64,
        fileSizeAfter: Int64,
        processingTime: Double,
        success: Bool,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.inputFile = inputFile
        self.outputFile = outputFile
        self.presetId = presetId
        self.processingDate = processingDate
        self.fileSizeBefore = fileSizeBefore
        self.fileSizeAfter = fileSizeAfter
        self.processingTime = processingTime
        self.success = success
        self.errorMessage = errorMessage
    }
    
    /// Calculate the percentage reduction in file size
    var sizeReductionPercentage: Double {
        guard fileSizeBefore > 0 else { return 0 }
        let reduction = Double(fileSizeBefore - fileSizeAfter) / Double(fileSizeBefore) * 100
        return reduction
    }
    
    /// Format the processing date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: processingDate)
    }
    
    /// Format the file sizes for display
    var formattedFileSizeBefore: String {
        return formatFileSize(fileSizeBefore)
    }
    
    var formattedFileSizeAfter: String {
        return formatFileSize(fileSizeAfter)
    }
    
    /// Format processing time for display
    var formattedProcessingTime: String {
        return String(format: "%.2f seconds", processingTime)
    }
    
    // MARK: - Private Methods
    
    /// Format file size in human-readable format
    private func formatFileSize(_ size: Int64) -> String {
        let sizes = ["B", "KB", "MB", "GB"]
        var sizeDouble = Double(size)
        var index = 0
        
        while sizeDouble >= 1024 && index < sizes.count - 1 {
            sizeDouble /= 1024
            index += 1
        }
        
        return String(format: "%.1f %@", sizeDouble, sizes[index])
    }
}