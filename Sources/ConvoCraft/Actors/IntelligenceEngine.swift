import Foundation
import NaturalLanguage

actor IntelligenceEngine {
    private(set) var insights: [IntelligenceInsight] = []
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    
    func analyzeTranscript(_ segments: [TranscriptSegment]) async -> [IntelligenceInsight] {
        var newInsights: [IntelligenceInsight] = []
        
        // Combine recent segments into context
        let recentText = segments.map { $0.text }.joined(separator: " ")
        
        // Tier 1: Lightweight NLP analysis
        newInsights += await performNLPAnalysis(recentText)
        
        // Store insights
        insights.append(contentsOf: newInsights)
        
        return newInsights
    }
    
    private func performNLPAnalysis(_ text: String) async -> [IntelligenceInsight] {
        var detectedInsights: [IntelligenceInsight] = []
        let lowercased = text.lowercased()
        
        // Detect uncertainty phrases
        let uncertaintyPhrases = ["maybe", "not sure", "perhaps", "might", "could be"]
        for phrase in uncertaintyPhrases {
            if lowercased.contains(phrase) {
                detectedInsights.append(IntelligenceInsight(
                    type: .question,
                    content: "Clarify uncertainty: '\(phrase)' detected. Ask for confirmation."
                ))
                break
            }
        }
        
        // Detect commitment/action phrases
        let commitmentPhrases = ["we should", "need to", "must", "will do"]
        for phrase in commitmentPhrases {
            if lowercased.contains(phrase) {
                detectedInsights.append(IntelligenceInsight(
                    type: .idea,
                    content: "Action commitment detected. Consider adding to action items."
                ))
                break
            }
        }
        
        // Detect risk signals
        let riskPhrases = ["risk", "problem", "issue", "concern", "blocker", "challenge"]
        for phrase in riskPhrases {
            if lowercased.contains(phrase) {
                detectedInsights.append(IntelligenceInsight(
                    type: .risk,
                    content: "Risk signal: '\(phrase)' mentioned. Monitor for mitigation plans."
                ))
                break
            }
        }
        
        // Detect timeline/deadline mentions
        let timelinePhrases = ["deadline", "due date", "timeline", "schedule", "by next week"]
        for phrase in timelinePhrases {
            if lowercased.contains(phrase) {
                detectedInsights.append(IntelligenceInsight(
                    type: .question,
                    content: "Timeline mentioned. Clarify specific dates and dependencies."
                ))
                break
            }
        }
        
        // Extract named entities
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .organizationName || tag == .personalName {
                let entity = String(text[tokenRange])
                detectedInsights.append(IntelligenceInsight(
                    type: .idea,
                    content: "Key entity mentioned: \(entity). Track involvement."
                ))
            }
            return true
        }
        
        return Array(detectedInsights.prefix(3)) // Limit to top 3 insights per analysis
    }
    
    func getAllInsights() -> [IntelligenceInsight] {
        return insights
    }
    
    func clearInsights() {
        insights.removeAll()
    }
}
