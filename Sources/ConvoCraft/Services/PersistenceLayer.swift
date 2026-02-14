import Foundation

actor PersistenceLayer {
    private let fileManager = FileManager.default
    private let summariesDirectory: URL
    
    init() {
        // Get documents directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        summariesDirectory = documentsPath.appendingPathComponent("MeetingSummaries", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: summariesDirectory, withIntermediateDirectories: true)
    }
    
    func saveSummary(_ summary: MeetingSummary) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(summary)
        
        // Create filename from date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "meeting_\(formatter.string(from: summary.date)).json"
        
        let fileURL = summariesDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
    }
    
    func loadAllSummaries() async throws -> [MeetingSummary] {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: summariesDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        var summaries: [MeetingSummary] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for fileURL in fileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let summary = try decoder.decode(MeetingSummary.self, from: data)
                summaries.append(summary)
            } catch {
                print("Failed to load summary from \(fileURL): \(error)")
            }
        }
        
        return summaries.sorted { $0.date > $1.date }
    }
    
    func getSummariesDirectory() -> URL {
        return summariesDirectory
    }
    
    func deleteSummary(_ summary: MeetingSummary) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "meeting_\(formatter.string(from: summary.date)).json"
        
        let fileURL = summariesDirectory.appendingPathComponent(filename)
        try fileManager.removeItem(at: fileURL)
    }
    
    func deleteSummaries(_ summaries: [MeetingSummary]) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        for summary in summaries {
            let filename = "meeting_\(formatter.string(from: summary.date)).json"
            let fileURL = summariesDirectory.appendingPathComponent(filename)
            try fileManager.removeItem(at: fileURL)
        }
    }
}
