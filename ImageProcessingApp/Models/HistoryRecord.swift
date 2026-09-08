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
  var skipped: Bool? = nil
  var cancelled: Bool? = nil
  var jobKey: String? = nil
  var pixelWidth: Int? = nil

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
    Self.dateFormatter.string(from: processingDate)
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

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
  }()

  private static let fileSizeFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
  }()

  /// Format file size in human-readable format
  private func formatFileSize(_ size: Int64) -> String {
    Self.fileSizeFormatter.string(fromByteCount: size)
  }
}

struct HistoryBatch: Identifiable, Codable {
  var id = UUID()
  var date = Date()
  var name: String
  var settings: ProcessingSettings?
  var inputFiles: [String]
  var relativeSubfolders: [String: String]
  var bookmarks: [Data]
  var records: [HistoryRecord]
  var wasCancelled: Bool

  var written: [HistoryRecord] { records.filter { $0.success && $0.skipped != true } }
  var failed: [HistoryRecord] { records.filter { !$0.success } }
  var savedBytes: Int64 {
    // Count each source once even if it produced several variants.
    let sources = Dictionary(grouping: written, by: \.inputFile)
    return sources.values.reduce(0) { $0 + ($1.first?.fileSizeBefore ?? 0) }
      - written.reduce(0) { $0 + $1.fileSizeAfter }
  }
  var statusSummary: String {
    "\(written.count) written · \(records.filter { $0.skipped == true }.count) skipped · \(failed.count) unfinished"
  }
  var srcset: String {
    Dictionary(
      grouping: written.filter { $0.pixelWidth != nil && $0.outputFile != nil },
      by: { "\($0.inputFile)|\(URL(fileURLWithPath: $0.outputFile!).pathExtension)" }
    )
    .sorted { $0.key < $1.key }.map { _, records in
      records.sorted { ($0.pixelWidth ?? 0) < ($1.pixelWidth ?? 0) }.map { record in
        let name = URL(fileURLWithPath: record.outputFile!).lastPathComponent
        let safe =
          name.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed.subtracting(
              CharacterSet(charactersIn: ",;#?&\"'"))) ?? name
        return "\(safe) \(record.pixelWidth!)w"
      }.joined(separator: ",\n")
    }.joined(separator: "\n\n")
  }
}
