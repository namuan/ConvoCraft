import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

actor IntelligenceEngine {
    private(set) var insights: [IntelligenceInsight] = []
    
    #if canImport(NaturalLanguage)
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    #endif
    
    func analyzeTranscript(_ segments: [TranscriptSegment]) async -> [IntelligenceInsight] {
        logInfo("🧠 IntelligenceEngine.analyzeTranscript called with \(segments.count) segments")
        var newInsights: [IntelligenceInsight] = []
        
        // Combine recent segments into context
        let recentText = segments.map { $0.text }.joined(separator: " ")
        logDebug("📝 Analyzing text (\(recentText.count) chars): \(recentText.prefix(100))...")
        
        // Tier 1: Lightweight NLP analysis
        logDebug("🔍 Performing NLP analysis...")
        newInsights += await performNLPAnalysis(recentText)
        logInfo("✨ Found \(newInsights.count) insights from NLP analysis")
        
        // Store insights
        insights.append(contentsOf: newInsights)
        logSuccess("📊 Total insights stored: \(insights.count)")
        
        return newInsights
    }
    
    private func performNLPAnalysis(_ text: String) async -> [IntelligenceInsight] {
        logDebug("🔍 performNLPAnalysis: analyzing text...")
        var detectedInsights: [IntelligenceInsight] = []
        let lowercased = text.lowercased()
        
        // Detect uncertainty phrases
        let uncertaintyPhrases = ["maybe", "not sure", "perhaps", "might", "could be"]
        for phrase in uncertaintyPhrases {
            if lowercased.contains(phrase) {
                logInfo("🔍 Detected uncertainty phrase: \(phrase)")
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
                logInfo("🛠 Detected commitment phrase: \(phrase)")
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
                logWarning("⚠️ Detected risk phrase: \(phrase)")
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
                logInfo("📅 Detected timeline phrase: \(phrase)")
                detectedInsights.append(IntelligenceInsight(
                    type: .question,
                    content: "Timeline mentioned. Clarify specific dates and dependencies."
                ))
                break
            }
        }
        
        #if canImport(NaturalLanguage)
        // Extract named entities (only on macOS)
        logDebug("🏷 Extracting named entities...")
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        var entityCount = 0
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .organizationName || tag == .personalName {
                let entity = String(text[tokenRange])
                entityCount += 1
                logInfo("🏷 Found entity: \(entity) (type: \(tag?.rawValue ?? "unknown"))")
                detectedInsights.append(IntelligenceInsight(
                    type: .idea,
                    content: "Key entity mentioned: \(entity). Track involvement."
                ))
            }
            return true
        }
        logDebug("🏷 Total entities found: \(entityCount)")
        #endif
        
        logInfo("📊 Total insights before limiting: \(detectedInsights.count)")
        let limitedInsights = Array(detectedInsights.prefix(3))
        logInfo("✅ Returning \(limitedInsights.count) insights (limit: 3)")
        return limitedInsights // Limit to top 3 insights per analysis
    }
    
    func getAllInsights() -> [IntelligenceInsight] {
        return insights
    }
    
    func clearInsights() {
        insights.removeAll()
    }
}
