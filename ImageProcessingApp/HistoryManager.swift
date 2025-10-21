import Foundation

@MainActor
class HistoryManager: ObservableObject {
    @Published var historyRecords: [HistoryRecord] = []
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "ProcessingHistory"
    
    init() {
        loadHistory()
    }
    
    /// Load history records from storage
    func loadHistory() {
        if let data = userDefaults.data(forKey: historyKey),
           let records = try? JSONDecoder().decode([HistoryRecord].self, from: data) {
            historyRecords = records
        }
    }
    
    /// Save history records to storage
    func saveHistory() {
        if let data = try? JSONEncoder().encode(historyRecords) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    /// Add a new history record
    /// - Parameter record: The history record to add
    func addRecord(_ record: HistoryRecord) {
        historyRecords.insert(record, at: 0)
        
        // Limit to 100 records to prevent excessive storage
        if historyRecords.count > 100 {
            historyRecords = Array(historyRecords.prefix(100))
        }
        
        saveHistory()
    }
    
    /// Delete a history record
    /// - Parameter record: The history record to delete
    func deleteRecord(_ record: HistoryRecord) {
        historyRecords.removeAll { $0.id == record.id }
        saveHistory()
    }
    
    /// Clear all history records
    func clearHistory() {
        historyRecords.removeAll()
        saveHistory()
    }
    
    /// Get history records for a specific preset
    /// - Parameter presetId: The preset ID to filter by
    /// - Returns: Array of history records for the preset
    func getRecords(for presetId: UUID) -> [HistoryRecord] {
        return historyRecords.filter { $0.presetId == presetId }
    }
    
    /// Get recent history records
    /// - Parameter limit: Maximum number of records to return
    /// - Returns: Array of recent history records
    func getRecentRecords(limit: Int = 10) -> [HistoryRecord] {
        return Array(historyRecords.prefix(limit))
    }
}