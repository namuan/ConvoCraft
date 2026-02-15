import Foundation
import FoundationModels

@available(macOS 26.0, *)
final class FoundationModelsService: @unchecked Sendable {
    private let model = SystemLanguageModel()
    private var session: LanguageModelSession?
    
    // Default prompt for AI insight generation
    static let defaultInsightPrompt = """
        Analyze this recent meeting discussion and extract meaningful, actionable live insights. Identify:
        
        1. **Deep topics**: Not just keywords - explain what's being discussed about the topic
        2. **Questions raised**: Specific questions that need answers or clarification
        3. **Action items**: Concrete tasks or responsibilities mentioned
        4. **Risks or concerns**: Potential problems or challenges that require attention
        5. **Decisions made**: Agreements or choices that were finalized
        
        For each insight, classify it as one of:
        - "question": For questions or clarification needs
        - "idea": For deep topics, meaningful ideas, or decisions with context
        - "risk": For risks, problems, or concerns
        
        **IMPORTANT GUIDELINES FOR IDEAS**:
        - Do NOT just list single keywords or simple topics
        - Explain the context or significance of the topic
        - Avoid generic phrases like "Key topic: [word]"
        - Provide meaningful insights that add value to the discussion
        - Example of good idea: "Discussing implementation strategy for the new user authentication system"
        - Example of bad idea: "Authentication" (too vague, just a keyword)
        
        Return the insights as a JSON array in this format:
        [
            {
                "type": "question|idea|risk",
                "content": "Insight text"
            }
        ]
        
        Keep insights concise but meaningful. Focus on quality over quantity. Limit to 2-4 high-quality insights.
        """
    
    // UserDefaults key for storing custom prompt
    private static let insightPromptKey = "ConvoCraft.InsightPrompt"
    
    // Current prompt (default or custom)
    var insightPrompt: String {
        get {
            return UserDefaults.standard.string(forKey: Self.insightPromptKey) ?? Self.defaultInsightPrompt
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.insightPromptKey)
        }
    }
    
    // Reset to default prompt
    func resetInsightPromptToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.insightPromptKey)
    }
    
    init() {
        session = LanguageModelSession(model: model)
    }
    
    func generateLiveInsights(from text: String) async throws -> [IntelligenceInsight] {
        let userPrompt = "\(insightPrompt)\n\nRecent discussion:\n\(text)"
        let options = GenerationOptions(temperature: 0.3) // Lower temperature for more focused output
        
        guard let session = session else {
            throw CocoaError(.coderInvalidValue, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
        }
        
        logDebug("🤖 FoundationModelsService: Generating insights for text length: \(text.count) chars")
        let response = try await session.respond(to: userPrompt, options: options)
        logInfo("✅ FoundationModelsService: Response received: \(response.content.count) chars")
        
        var insights = parseInsightsFromResponse(response.content)
        
        // Filter and enhance insights quality
        insights = enhanceInsightsQuality(insights)
        
        return insights
    }
    
    private func enhanceInsightsQuality(_ insights: [IntelligenceInsight]) -> [IntelligenceInsight] {
        return insights.compactMap { insight in
            // Skip low-quality ideas that are just keywords or too vague
            if insight.type == .idea {
                let content = insight.content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Filter out insights that are too short or contain only keywords
                if content.count < 8 || isKeywordOnly(content) {
                    logDebug("⚠️ Skipping low-quality idea: \(content)")
                    return nil
                }
                
                // Improve formatting of ideas
                var improvedContent = content
                
                // Remove generic prefixes like "Key topic: " or "Topic: "
                improvedContent = improvedContent.replacingOccurrences(of: "Key topic: ", with: "", options: .caseInsensitive)
                improvedContent = improvedContent.replacingOccurrences(of: "Topic: ", with: "", options: .caseInsensitive)
                improvedContent = improvedContent.replacingOccurrences(of: "Idea: ", with: "", options: .caseInsensitive)
                
                return IntelligenceInsight(type: insight.type, content: improvedContent)
            }
            
            return insight
        }
    }
    
    private func isKeywordOnly(_ text: String) -> Bool {
        // Check if text is likely to be just a single keyword or very simple phrase
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Criteria for keyword-only insights:
        // - Very short (less than 3 words)
        // - Contains no verbs or adjectives
        // - Looks like a single noun phrase with no context
        
        let wordCount = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        if wordCount <= 2 {
            return true
        }
        
        // Check for patterns that indicate keyword-only insights
        let keywordPatterns = [
            "^[A-Z][a-z]*$", // Single capitalized word
            "^[a-z]+$",      // Single lowercase word
            "^[A-Z][a-z]+ [A-Z][a-z]+$", // Two capitalized words with no other context
            "^[A-Z]+$"       // All uppercase acronym
        ]
        
        for pattern in keywordPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    func generateEnhancedSummary(from text: String) async throws -> String {
        let prompt = """
        Summarize this meeting transcript in 3-5 concise sentences, focusing on key decisions, action items, and main topics discussed.
        """
        
        let userPrompt = "\(prompt)\n\nTranscript:\n\(text)"
        let options = GenerationOptions(temperature: 0.3)
        
        guard let session = session else {
            throw CocoaError(.coderInvalidValue, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
        }
        
        logDebug("🤖 FoundationModelsService: Generating summary for text length: \(text.count) chars")
        let response = try await session.respond(to: userPrompt, options: options)
        logInfo("✅ FoundationModelsService: Summary generated")
        
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func extractActionItems(from text: String) async throws -> [String] {
        let prompt = """
        Extract all action items from this meeting transcript. Action items are tasks, responsibilities, or things that need to be done. Return them as a JSON array of strings. Keep each action item concise.
        """
        
        let userPrompt = "\(prompt)\n\nTranscript:\n\(text)"
        let options = GenerationOptions(temperature: 0.2)
        
        guard let session = session else {
            throw CocoaError(.coderInvalidValue, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
        }
        
        logDebug("🤖 FoundationModelsService: Extracting action items for text length: \(text.count) chars")
        let response = try await session.respond(to: userPrompt, options: options)
        logInfo("✅ FoundationModelsService: Action items extracted")
        
        return parseActionItemsFromResponse(response.content)
    }
    
    func extractKeyDecisions(from text: String) async throws -> [String] {
        let prompt = """
        Extract all key decisions from this meeting transcript. Decisions are agreements, conclusions, or choices made during the meeting. Return them as a JSON array of strings. Keep each decision concise.
        """
        
        let userPrompt = "\(prompt)\n\nTranscript:\n\(text)"
        let options = GenerationOptions(temperature: 0.2)
        
        guard let session = session else {
            throw CocoaError(.coderInvalidValue, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
        }
        
        logDebug("🤖 FoundationModelsService: Extracting key decisions for text length: \(text.count) chars")
        let response = try await session.respond(to: userPrompt, options: options)
        logInfo("✅ FoundationModelsService: Key decisions extracted")
        
        return parseKeyDecisionsFromResponse(response.content)
    }
    
    private func parseInsightsFromResponse(_ text: String) -> [IntelligenceInsight] {
        guard let jsonData = extractJSON(from: text) else {
            logWarning("⚠️ FoundationModelsService: Failed to extract JSON from response")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            struct InsightData: Codable {
                let type: String
                let content: String
            }
            
            let insightsData = try decoder.decode([InsightData].self, from: jsonData)
            
            return insightsData.compactMap { data in
                guard let type = InsightType(rawValue: data.type) else {
                    logWarning("⚠️ FoundationModelsService: Unknown insight type: \(data.type)")
                    return nil
                }
                
                return IntelligenceInsight(type: type, content: data.content.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            logError("❌ FoundationModelsService: Failed to parse insights JSON: \(error)")
            logDebug("Response: \(text)")
            return []
        }
    }
    
    private func parseActionItemsFromResponse(_ text: String) -> [String] {
        guard let jsonData = extractJSON(from: text) else {
            logWarning("⚠️ FoundationModelsService: Failed to extract JSON from action items response")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let items = try decoder.decode([String].self, from: jsonData)
            return items.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } catch {
            logError("❌ FoundationModelsService: Failed to parse action items JSON: \(error)")
            logDebug("Response: \(text)")
            return []
        }
    }
    
    private func parseKeyDecisionsFromResponse(_ text: String) -> [String] {
        guard let jsonData = extractJSON(from: text) else {
            logWarning("⚠️ FoundationModelsService: Failed to extract JSON from key decisions response")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let items = try decoder.decode([String].self, from: jsonData)
            return items.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } catch {
            logError("❌ FoundationModelsService: Failed to parse key decisions JSON: \(error)")
            logDebug("Response: \(text)")
            return []
        }
    }
    
    private func extractJSON(from text: String) -> Data? {
        // Extract JSON from response (handle markdown code blocks)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look for JSON between ```json and ```
        if trimmedText.contains("```json") {
            let parts = trimmedText.components(separatedBy: "```json")
            if parts.count > 1 {
                let jsonPart = parts[1].components(separatedBy: "```").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                return jsonPart?.data(using: .utf8)
            }
        }
        
        // Look for JSON between ``` and ```
        if trimmedText.contains("```") {
            let parts = trimmedText.components(separatedBy: "```")
            if parts.count > 1 {
                let jsonPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return jsonPart.data(using: .utf8)
            }
        }
        
        // Try to find JSON object or array directly
        if trimmedText.hasPrefix("{") || trimmedText.hasPrefix("[") {
            return trimmedText.data(using: .utf8)
        }
        
        logDebug("❌ No JSON found in response: \(trimmedText.prefix(200))")
        return nil
    }
}