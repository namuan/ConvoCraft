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
    
    private func splitIntoSentences(_ text: String) -> [String] {
        #if canImport(NaturalLanguage)
        // Use NLTokenizer for robust sentence tokenization when available
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespaces)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        
        return sentences
        #else
        // Fallback implementation for non-macOS platforms
        // Split on period, question mark, or exclamation point followed by whitespace or end
        let pattern = #"[.!?](?:\s+|$)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        guard let regex = regex else {
            return text.components(separatedBy: ". ").filter { !$0.isEmpty }
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        var sentences: [String] = []
        var lastIndex = 0
        
        for match in matches {
            let range = match.range
            let sentence = nsString.substring(with: NSRange(location: lastIndex, length: range.location - lastIndex + 1))
            sentences.append(sentence.trimmingCharacters(in: .whitespaces))
            lastIndex = range.location + range.length
        }
        
        if lastIndex < nsString.length {
            let remaining = nsString.substring(from: lastIndex)
            let trimmed = remaining.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                sentences.append(trimmed)
            }
        }
        
        return sentences.filter { !$0.isEmpty }
        #endif
    }
    
    private func generateExtractiveSummary(from text: String) -> String {
        guard !text.isEmpty else { return "No transcript available." }
        
        let sentences = splitIntoSentences(text)
        let summaryLength = min(3, sentences.count)
        let summarySentences = sentences.prefix(summaryLength).joined(separator: " ")
        
        return summarySentences.isEmpty ? "Summary unavailable." : summarySentences
    }
    
    private func extractActionItems(from text: String) -> [String] {
        var actionItems: [String] = []
        
        // Look for action-oriented phrases
        let actionPhrases = [
            "need to", "should", "must", "will do", "action item",
            "follow up", "task", "todo", "to do"
        ]
        
        let sentences = splitIntoSentences(text)
        for sentence in sentences {
            let lowerSentence = sentence.lowercased()
            for phrase in actionPhrases {
                if lowerSentence.contains(phrase) {
                    actionItems.append(sentence)
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
        
        let sentences = splitIntoSentences(text)
        for sentence in sentences {
            let lowerSentence = sentence.lowercased()
            for phrase in decisionPhrases {
                if lowerSentence.contains(phrase) {
                    decisions.append(sentence)
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
