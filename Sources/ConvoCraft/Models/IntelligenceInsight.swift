import Foundation

enum InsightType: String, Codable {
    case question
    case idea
    case risk
}

struct IntelligenceInsight: Identifiable, Codable, Hashable {
    let id: UUID
    let type: InsightType
    let content: String
    let timestamp: TimeInterval
    
    init(id: UUID = UUID(), type: InsightType, content: String, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.type = type
        self.content = content
        self.timestamp = timestamp
    }
}
