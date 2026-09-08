import AppKit
import Foundation

@MainActor
class HistoryManager: ObservableObject {
  @Published private(set) var batches: [HistoryBatch] = []
  @Published var storageError: String?
  private let fileURL: URL
  private var canSave = true
  private let defaults: UserDefaults

  init(fileURL: URL? = nil, defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.fileURL =
      fileURL
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("The Transmogrifier", isDirectory: true).appendingPathComponent(
        "history-v2.json")
    loadHistory()
  }
  func loadHistory() {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        batches = try JSONDecoder().decode([HistoryBatch].self, from: Data(contentsOf: fileURL))
      } catch {
        canSave = false
        storageError =
          "History could not be loaded. The existing file has been preserved: \(error.localizedDescription)"
      }
    } else if let data = defaults.data(forKey: "ProcessingHistory"),
      let records = try? JSONDecoder().decode([HistoryRecord].self, from: data), !records.isEmpty
    {
      batches = [
        HistoryBatch(
          name: "Earlier conversions", settings: nil,
          inputFiles: Array(Set(records.map(\.inputFile))).sorted(), relativeSubfolders: [:],
          bookmarks: [],
          records: records, wasCancelled: false)
      ]
    }
  }
  func addBatch(_ batch: HistoryBatch) {
    batches.insert(batch, at: 0)
    // Retain whole jobs, including a large most-recent job.
    while batches.count > 100
      || (batches.count > 1 && batches.reduce(0, { $0 + $1.records.count }) > 10_000)
    {
      batches.removeLast()
    }
    saveHistory()
  }
  func clearHistory() {
    batches.removeAll()
    canSave = true
    saveHistory()
  }
  private func saveHistory() {
    guard canSave else { return }
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(batches).write(to: fileURL, options: .atomic)
      storageError = nil
    } catch { storageError = "History could not be saved: \(error.localizedDescription)" }
  }
  static func bookmarks(for urls: [URL]) -> [Data] {
    Array(Set(urls)).compactMap {
      try? $0.bookmarkData(
        options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
  }
  static func resolveBookmarks(_ bookmarks: [Data]) -> [URL] {
    bookmarks.compactMap { data in
      var stale = false
      return try? URL(
        resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil,
        bookmarkDataIsStale: &stale)
    }
  }
  func reveal(_ batch: HistoryBatch) {
    let access = Self.resolveBookmarks(batch.bookmarks).filter {
      $0.startAccessingSecurityScopedResource()
    }
    defer { access.forEach { $0.stopAccessingSecurityScopedResource() } }
    let urls = batch.records.compactMap(\.outputFile).map { URL(fileURLWithPath: $0) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
    if urls.isEmpty {
      storageError = "The output files have moved or are no longer accessible."
    } else {
      NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
  }
}
