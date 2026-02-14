import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

actor SummaryEngine {
    func generateSummary(
        from segments: [TranscriptSegment],
        insights: [IntelligenceInsight],
        duration: TimeInterval
    ) async -> MeetingSummary {
        let fullTranscript = segments.map { $0.text }.joined(separator: " ")
        
        // Generate summary using extractive approach
        let summary = generateExtractiveSummary(from: fullTranscript)
        
        // Extract action items
        let actionItems = extractActionItems(from: fullTranscript)
        
        // Extract key decisions
        let keyDecisions = extractKeyDecisions(from: fullTranscript)
        
        return MeetingSummary(
            title: "Meeting - \(formatDate(Date()))",
            date: Date(),
            duration: duration,
            summary: summary,
            actionItems: actionItems,
            keyDecisions: keyDecisions,
            transcript: segments,
            insights: insights
        )
    }
    
    private func generateExtractiveSummary(from text: String) -> String {
        guard !text.isEmpty else { return "No transcript available." }
        
        // Simple extractive summary: take first few sentences
        let sentences = text.components(separatedBy: ". ")
        let summaryLength = min(3, sentences.count)
        let summarySentences = sentences.prefix(summaryLength).joined(separator: ". ")
        
        return summarySentences.isEmpty ? "Summary unavailable." : summarySentences + "."
    }
    
    private func extractActionItems(from text: String) -> [String] {
        var actionItems: [String] = []
        let lowercased = text.lowercased()
        
        // Look for action-oriented phrases
        let actionPhrases = [
            "need to", "should", "must", "will do", "action item",
            "follow up", "task", "todo", "to do"
        ]
        
        let sentences = text.components(separatedBy: ".")
        for sentence in sentences {
            let lowerSentence = sentence.lowercased()
            for phrase in actionPhrases {
                if lowerSentence.contains(phrase) {
                    actionItems.append(sentence.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }
        
        return Array(actionItems.prefix(5)) // Limit to top 5
    }
    
    private func extractKeyDecisions(from text: String) -> [String] {
        var decisions: [String] = []
        
        // Look for decision-oriented phrases
        let decisionPhrases = [
            "decided", "agree", "approved", "confirmed", "committed",
            "going with", "final decision", "consensus"
        ]
        
        let sentences = text.components(separatedBy: ".")
        for sentence in sentences {
            let lowerSentence = sentence.lowercased()
            for phrase in decisionPhrases {
                if lowerSentence.contains(phrase) {
                    decisions.append(sentence.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }
        
        return Array(decisions.prefix(5)) // Limit to top 5
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
