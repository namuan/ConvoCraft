import Foundation
import FoundationModels

@available(macOS 26.0, *)
final class FoundationModelsService: @unchecked Sendable {
    private let model = SystemLanguageModel()
    private var session: LanguageModelSession?
    
    init() {
        session = LanguageModelSession(model: model)
    }
    
    func generateLiveInsights(from text: String) async throws -> [IntelligenceInsight] {
        let prompt = """
        Analyze this recent meeting discussion and extract live insights. Identify:
        
        1. Key topics being discussed
        2. Questions raised
        3. Action items mentioned
        4. Risks or concerns
        5. Decisions made
        
        For each insight, classify it as one of:
        - "question": For questions or clarification needs
        - "idea": For key topics, ideas, or decisions
        - "risk": For risks, problems, or concerns
        
        Return the insights as a JSON array in this format:
        [
            {
                "type": "question|idea|risk",
                "content": "Insight text"
            }
        ]
        
        Keep insights concise and focused on the most important points from the recent discussion. Limit to 3-5 key insights.
        """
        
        let userPrompt = "\(prompt)\n\nRecent discussion:\n\(text)"
        let options = GenerationOptions(temperature: 0.4)
        
        guard let session = session else {
            throw CocoaError(.coderInvalidValue, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
        }
        
        logDebug("🤖 FoundationModelsService: Generating insights for text length: \(text.count) chars")
        let response = try await session.respond(to: userPrompt, options: options)
        logInfo("✅ FoundationModelsService: Response received: \(response.content.count) chars")
        
        return parseInsightsFromResponse(response.content)
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