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
    let sourceText: String?
    let timestamp: TimeInterval
    
    init(id: UUID = UUID(), type: InsightType, content: String, sourceText: String? = nil, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.type = type
        self.content = content
        self.sourceText = sourceText
        self.timestamp = timestamp
    }
}
