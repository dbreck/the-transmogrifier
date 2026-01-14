import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager: HistoryManager
    
    var body: some View {
        VStack {
            HStack {
                Text("Processing History")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button("Clear History") {
                    historyManager.clearHistory()
                }
                .disabled(historyManager.historyRecords.isEmpty)
            }
            .padding(.horizontal)
            
            if historyManager.historyRecords.isEmpty {
                VStack {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No processing history yet")
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(historyManager.historyRecords) { record in
                        HistoryRowView(record: record)
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        for index in offsets {
            historyManager.deleteRecord(historyManager.historyRecords[index])
        }
    }
}

struct HistoryRowView: View {
    let record: HistoryRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.inputFile.components(separatedBy: "/").last ?? record.inputFile)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Before: \(record.formattedFileSizeBefore)")
                        .font(.caption)
                    
                    Text("After: \(record.formattedFileSizeAfter)")
                        .font(.caption)
                    
                    Text("Reduction: \(String(format: "%.1f", record.sizeReductionPercentage))%")
                        .font(.caption)
                        .foregroundColor(record.sizeReductionPercentage > 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.formattedProcessingTime)
                        .font(.caption)
                    
                    if record.success {
                        Text("Success")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Failed")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if let errorMessage = record.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(historyManager: HistoryManager())
    }
}