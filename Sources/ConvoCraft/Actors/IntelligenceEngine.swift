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
        
        let recentText = segments.map { $0.text }.joined(separator: " ")
        logDebug("📝 Analyzing text (\(recentText.count) chars): \(recentText.prefix(100))...")
        
        let newInsights = await analyzeWithBestAvailableMethod(recentText)
        
        insights.append(contentsOf: newInsights)
        logSuccess("📊 Total insights stored: \(insights.count)")
        
        return newInsights
    }
    
    private func analyzeWithBestAvailableMethod(_ text: String) async -> [IntelligenceInsight] {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), let wrapper = foundationModelsWrapper as? FoundationModelsWrapper {
            return await analyzeWithFoundationModels(wrapper, text: text)
        }
        #endif
        
        let insights = await performNLPAnalysis(text)
        logInfo("✨ Found \(insights.count) insights from NLP analysis")
        return insights
    }
    
    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func analyzeWithFoundationModels(_ wrapper: FoundationModelsWrapper, text: String) async -> [IntelligenceInsight] {
        logDebug("🤖 Using Foundation Models for analysis...")
        do {
            let insights = try await wrapper.service.generateLiveInsights(from: text)
            logInfo("✨ Found \(insights.count) insights from Foundation Models")
            return insights
        } catch {
            logWarning("⚠️ Foundation Models unavailable: \(error.localizedDescription). Falling back to NLP analysis.")
            let insights = await performNLPAnalysis(text)
            logInfo("✨ Found \(insights.count) insights from NLP analysis (fallback)")
            return insights
        }
    }
    #endif
    
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
        for entity in entities.prefix(1) {
            let sentencesWithEntity = sentences.filter { $0.contains(entity) }
            let insightContent: String
            
            if let contextSentence = sentencesWithEntity.first {
                let context = String(contextSentence.prefix(80))
                let ellipsis = contextSentence.count > 80 ? "..." : ""
                insightContent = "Discussion about \(entity): \(context)\(ellipsis)"
            } else {
                insightContent = "Discussion involving: \(entity)"
            }
            
            detectedInsights.append(IntelligenceInsight(type: .idea, content: insightContent))
            logInfo("🏢 Found contextual entity insight: \(entity)")
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
        
        if let topTopic = topicCounts.first, topTopic.value >= 3 {
            logInfo("📌 Key topic: \(topTopic.key) (mentioned \(topTopic.value) times)")
            
            let sentencesWithTopic = sentences.filter { $0.lowercased().contains(topTopic.key.lowercased()) }
            let insightContent: String
            
            if let contextSentence = sentencesWithTopic.first {
                let context = String(contextSentence.prefix(80))
                let ellipsis = contextSentence.count > 80 ? "..." : ""
                insightContent = "Key discussion topic: \(topTopic.key) - \(context)\(ellipsis)"
            } else {
                insightContent = "Key topic: \(topTopic.key)"
            }
            
            detectedInsights.append(IntelligenceInsight(type: .idea, content: insightContent))
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
