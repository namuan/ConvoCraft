import Foundation

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval
    let isFinal: Bool
    
    init(id: UUID = UUID(), text: String, timestamp: TimeInterval, isFinal: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isFinal = isFinal
    }
}
