import AppKit
import SwiftUI

struct HistoryView: View {
  @ObservedObject var historyManager: HistoryManager
  var isProcessing = false
  var onReuse: (HistoryBatch) -> Void = { _ in }
  var onRun: (HistoryBatch, Bool) -> Void = { _, _ in }
  @State private var search = ""
  @State private var confirmsClear = false
  @State private var copiedBatch: UUID?

  private var matches: [HistoryBatch] {
    historyManager.batches.filter { batch in
      search.isEmpty || batch.name.localizedStandardContains(search)
        || batch.inputFiles.contains { $0.localizedStandardContains(search) }
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Recent jobs").font(.title2).bold()
        Spacer()
        TextField("Search jobs or filenames", text: $search).textFieldStyle(.roundedBorder).frame(
          width: 280)
        Button("Clear history…") { confirmsClear = true }.disabled(
          historyManager.batches.isEmpty || isProcessing)
      }
      if let error = historyManager.storageError {
        Text(error).foregroundStyle(.orange)
      }
      if matches.isEmpty {
        Text(
          search.isEmpty
            ? "Your exports will appear here, with settings you can reuse." : "No matching jobs."
        )
        .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 16) {
            ForEach(matches) { batch in
              VStack(alignment: .leading, spacing: 12) {
                HStack {
                  Text(batch.name).font(.headline)
                  if batch.wasCancelled { Text("Cancelled").foregroundStyle(.orange) }
                  Spacer()
                  Text(batch.date, style: .date).foregroundStyle(.secondary)
                  Text(batch.date, style: .time).foregroundStyle(.secondary)
                }
                Text(batch.statusSummary).font(.callout)
                if !batch.written.isEmpty {
                  Text(
                    "Written outputs: \(ByteCountFormatter.string(fromByteCount: batch.written.reduce(0) { $0 + $1.fileSizeAfter }, countStyle: .file)) · \(ByteCountFormatter.string(fromByteCount: abs(batch.savedBytes), countStyle: .file)) \(batch.savedBytes >= 0 ? "smaller than sources" : "larger than sources")"
                  )
                  .font(.caption).foregroundStyle(.secondary)
                }
                if let settings = batch.settings {
                  Text(
                    "\(settings.outputFormat) · \(Int((settings.compressionLevel * 100).rounded()))% quality · \(settings.saveAlongsideOriginals ? "Beside originals" : settings.outputFolder)"
                  )
                  .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack {
                  Button("Reveal outputs") { historyManager.reveal(batch) }.disabled(
                    !batch.records.contains { $0.outputFile != nil })
                  Button("Reuse settings") { onReuse(batch) }.disabled(
                    batch.settings == nil || isProcessing)
                  Button("Run again") { onRun(batch, false) }.disabled(
                    batch.settings == nil || isProcessing)
                  if !batch.failed.isEmpty {
                    Button("Retry unfinished (\(batch.failed.count))") { onRun(batch, true) }
                      .disabled(batch.settings == nil || isProcessing)
                  }
                  if batch.settings?.exportOptions.isResponsive == true && !batch.srcset.isEmpty {
                    Button(copiedBatch == batch.id ? "Copied" : "Copy srcset") {
                      NSPasteboard.general.clearContents()
                      NSPasteboard.general.setString(batch.srcset, forType: .string)
                      copiedBatch = batch.id
                    }
                  }
                }.buttonStyle(.bordered)
                DisclosureGroup("\(batch.records.count) output results") {
                  LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(batch.records) { record in
                      VStack(alignment: .leading, spacing: 4) {
                        HStack {
                          Text(
                            URL(fileURLWithPath: record.outputFile ?? record.inputFile)
                              .lastPathComponent)
                          Spacer()
                          Text(
                            record.cancelled == true
                              ? "Cancelled"
                              : record.skipped == true
                                ? "Skipped"
                                : record.success ? record.formattedFileSizeAfter : "Failed"
                          )
                          .foregroundStyle(record.success ? Color.secondary : Color.orange)
                        }
                        if let error = record.errorMessage {
                          Text(error).font(.caption).foregroundStyle(.orange)
                        }
                      }
                    }
                  }.padding(.top, 8)
                }
              }.padding(16).background(Color.gray800).clipShape(RoundedRectangle(cornerRadius: 10))
            }
          }
        }
      }
    }
    .alert("Clear processing history?", isPresented: $confirmsClear) {
      Button("Clear history", role: .destructive) { historyManager.clearHistory() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Removes job records only. Your original and exported files stay where they are.")
    }
  }
}
