import Foundation

struct MeetingSummary: Codable, Hashable, Identifiable {
    var id: Date { date }
    let title: String
    let date: Date
    let duration: TimeInterval
    let summary: String
    let actionItems: [String]
    let keyDecisions: [String]
    let transcript: [TranscriptSegment]
    let insights: [IntelligenceInsight]
}
