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
        
        let sentences = extractSentences(from: recentText)
        let lastSentences = Array(sentences.suffix(3)).joined(separator: ". ")
        let textToAnalyze = lastSentences.isEmpty ? recentText : lastSentences
        
        logDebug("📝 Analyzing last \(min(3, sentences.count)) sentences (\(textToAnalyze.count) chars)")
        
        let newInsights = await analyzeWithBestAvailableMethod(textToAnalyze)
        
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
        
        logDebug("❓ Analyzing sentence structure...")
        let sentences = extractSentences(from: text)
        
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
        
        for entity in entities.prefix(1) {
            let sentencesWithEntity = sentences.filter { $0.contains(entity) }
            let insightContent: String
            
            if let contextSentence = sentencesWithEntity.first {
                insightContent = "Discussion about \(entity): \(formatWithEllipsis(contextSentence, maxLength: 80))"
            } else {
                insightContent = "Discussion involving: \(entity)"
            }
            
            detectedInsights.append(IntelligenceInsight(type: .idea, content: insightContent, sourceText: text))
            logInfo("🏢 Found contextual entity insight: \(entity)")
        }
        
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
        
        let topicCounts = Dictionary(grouping: nouns, by: { $0.lowercased() })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        if let topTopic = topicCounts.first, topTopic.value >= 3 {
            logInfo("📌 Key topic: \(topTopic.key) (mentioned \(topTopic.value) times)")
            
            let sentencesWithTopic = sentences.filter { $0.lowercased().contains(topTopic.key.lowercased()) }
            let insightContent: String
            
            if let contextSentence = sentencesWithTopic.first {
                insightContent = "Key discussion topic: \(topTopic.key) - \(formatWithEllipsis(contextSentence, maxLength: 80))"
            } else {
                insightContent = "Key topic: \(topTopic.key)"
            }
            
            detectedInsights.append(IntelligenceInsight(type: .idea, content: insightContent, sourceText: text))
        }
        
        let questions = sentences.filter { $0.last == "?" || $0.lowercased().hasPrefix("what") || 
                                           $0.lowercased().hasPrefix("how") || $0.lowercased().hasPrefix("why") }
        
        if !questions.isEmpty {
            logInfo("❓ Found \(questions.count) question(s)")
            if let firstQuestion = questions.first {
                detectedInsights.append(IntelligenceInsight(
                    type: .question,
                    content: "Question raised: \(formatWithEllipsis(firstQuestion, maxLength: 60))",
                    sourceText: text
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
    
    private func extractSentences(from text: String) -> [String] {
        return text.components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func formatWithEllipsis(_ text: String, maxLength: Int) -> String {
        let trimmed = String(text.prefix(maxLength))
        return text.count > maxLength ? "\(trimmed)..." : trimmed
    }
}
