import Foundation

struct MeetingSummary: Codable {
    let title: String
    let date: Date
    let duration: TimeInterval
    let summary: String
    let actionItems: [String]
    let keyDecisions: [String]
    let transcript: [TranscriptSegment]
    let insights: [IntelligenceInsight]
}
