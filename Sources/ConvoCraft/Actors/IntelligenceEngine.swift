import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

#if canImport(FoundationModels)
@available(macOS 26.0, *)
class FoundationModelsWrapper {
    let service = FoundationModelsService()
}
#endif

actor IntelligenceEngine {
    private(set) var insights: [IntelligenceInsight] = []
    
    #if canImport(NaturalLanguage)
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    #endif
    
    #if canImport(FoundationModels)
    private var foundationModelsWrapper: Any?
    
    init() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            foundationModelsWrapper = FoundationModelsWrapper()
        }
        #endif
    }
    #endif
    
    func analyzeTranscript(_ segments: [TranscriptSegment]) async -> [IntelligenceInsight] {
        logInfo("🧠 IntelligenceEngine.analyzeTranscript called with \(segments.count) segments")
        var newInsights: [IntelligenceInsight] = []
        
        // Combine recent segments into context
        let recentText = segments.map { $0.text }.joined(separator: " ")
        logDebug("📝 Analyzing text (\(recentText.count) chars): \(recentText.prefix(100))...")
        
        // Tier 1: Try Foundation Models first (if available)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), let wrapper = foundationModelsWrapper as? FoundationModelsWrapper {
            logDebug("🤖 Using Foundation Models for analysis...")
            do {
                newInsights = try await wrapper.service.generateLiveInsights(from: recentText)
                logInfo("✨ Found \(newInsights.count) insights from Foundation Models")
            } catch {
                logWarning("⚠️ Foundation Models unavailable: \(error.localizedDescription). Falling back to NLP analysis.")
                newInsights = await performNLPAnalysis(recentText)
                logInfo("✨ Found \(newInsights.count) insights from NLP analysis (fallback)")
            }
        } else {
            // Fallback to NLP for older macOS versions
            newInsights = await performNLPAnalysis(recentText)
            logInfo("✨ Found \(newInsights.count) insights from NLP analysis")
        }
        #else
        // Fallback to NLP if Foundation Models not available
        newInsights = await performNLPAnalysis(recentText)
        logInfo("✨ Found \(newInsights.count) insights from NLP analysis")
        #endif
        
        // Store insights
        insights.append(contentsOf: newInsights)
        logSuccess("📊 Total insights stored: \(insights.count)")
        
        return newInsights
    }
    
    private func performNLPAnalysis(_ text: String) async -> [IntelligenceInsight] {
        logDebug("🔍 performNLPAnalysis: analyzing text...")
        var detectedInsights: [IntelligenceInsight] = []
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logWarning("⚠️ Empty text, skipping analysis")
            return []
        }
        
        #if canImport(NaturalLanguage)
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        
        // 3. Analyze sentences for questions and statements (moved early for context)
        logDebug("❓ Analyzing sentence structure...")
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 1. Extract named entities (people, organizations)
        logDebug("🏷 Extracting named entities...")
        var entities: Set<String> = []
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .organizationName {
                let entity = String(text[tokenRange])
                entities.insert(entity)
                logInfo("🏢 Found organization: \(entity)")
            } else if tag == .personalName {
                let entity = String(text[tokenRange])
                entities.insert(entity)
                logInfo("👤 Found person: \(entity)")
            } else if tag == .placeName {
                let entity = String(text[tokenRange])
                entities.insert(entity)
                logInfo("📍 Found place: \(entity)")
            }
            return true
        }
        
        // Generate meaningful insights from entities (with context)
        for entity in entities.prefix(1) { // Limit to 1 entity insight to avoid duplication
            // Find sentences containing this entity to provide context
            let sentencesWithEntity = sentences.filter { $0.contains(entity) }
            if let contextSentence = sentencesWithEntity.first {
                let context = String(contextSentence.prefix(80))
                let insightContent = "Discussion about \(entity): \(context)\(contextSentence.count > 80 ? "..." : "")"
                detectedInsights.append(IntelligenceInsight(
                    type: .idea,
                    content: insightContent
                ))
                logInfo("🏢 Found contextual entity insight: \(entity)")
            } else {
                detectedInsights.append(IntelligenceInsight(
                    type: .idea,
                    content: "Discussion involving: \(entity)"
                ))
            }
        }
        
        // 2. Extract meaningful topics with context
        logDebug("📝 Extracting key topics...")
        var nouns: [String] = []
        var verbs: [String] = []
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange]).trimmingCharacters(in: .punctuationCharacters)
            
            if tag == .noun && word.count > 4 {
                nouns.append(word)
            } else if tag == .verb && word.count > 3 {
                verbs.append(word)
            }
            return true
        }
        
        // Get most common nouns as topics with minimum frequency
        let topicCounts = Dictionary(grouping: nouns, by: { $0.lowercased() })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        if let topTopic = topicCounts.first, topTopic.value >= 3 { // Require more frequent mentions
            logInfo("📌 Key topic: \(topTopic.key) (mentioned \(topTopic.value) times)")
            
            // Find context for the topic
            let sentencesWithTopic = sentences.filter { $0.lowercased().contains(topTopic.key.lowercased()) }
            if let contextSentence = sentencesWithTopic.first {
                let context = String(contextSentence.prefix(80))
                let insightContent = "Key discussion topic: \(topTopic.key) - \(context)\(contextSentence.count > 80 ? "..." : "")"
                detectedInsights.append(IntelligenceInsight(
                    type: .idea,
                    content: insightContent
                ))
            } else {
                // Fallback to basic topic insight if no context found
                detectedInsights.append(IntelligenceInsight(
                    type: .idea,
                    content: "Key topic: \(topTopic.key)"
                ))
            }
        }
        
        let questions = sentences.filter { $0.last == "?" || $0.lowercased().hasPrefix("what") || 
                                           $0.lowercased().hasPrefix("how") || $0.lowercased().hasPrefix("why") }
        
        if !questions.isEmpty {
            logInfo("❓ Found \(questions.count) question(s)")
            if let firstQuestion = questions.first {
                let preview = String(firstQuestion.prefix(60))
                detectedInsights.append(IntelligenceInsight(
                    type: .question,
                    content: "Question raised: \(preview)\(firstQuestion.count > 60 ? "..." : "")"
                ))
            }
        }
        

        
        #endif
        
        logInfo("📊 Total insights before limiting: \(detectedInsights.count)")
        let limitedInsights = Array(detectedInsights.prefix(3))
        logInfo("✅ Returning \(limitedInsights.count) insights (limit: 3)")
        return limitedInsights
    }
    
    func getAllInsights() -> [IntelligenceInsight] {
        return insights
    }
    
    func clearInsights() {
        insights.removeAll()
    }
}
