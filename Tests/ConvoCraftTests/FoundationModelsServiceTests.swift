import XCTest
@testable import ConvoCraft

@available(macOS 26.0, *)
final class FoundationModelsServiceTests: XCTestCase {
    
    func testDefaultPrompt() {
        let defaultPrompt = FoundationModelsService.defaultInsightPrompt
        XCTAssertFalse(defaultPrompt.isEmpty, "Default prompt should not be empty")
        XCTAssertTrue(defaultPrompt.contains("JSON"), "Default prompt should include JSON format instructions")
        print("Default prompt length: \(defaultPrompt.count) characters")
    }
    
    func testPromptPersistence() {
        let service = FoundationModelsService()
        
        // Save custom prompt
        let customPrompt = """
        Custom prompt for AI insight generation. Return JSON array with "type" and "content" fields.
        """
        service.insightPrompt = customPrompt
        
        // Verify we can retrieve it
        XCTAssertEqual(service.insightPrompt, customPrompt, "Retrieved prompt should match the set value")
    }
    
    func testResetToDefault() {
        let service = FoundationModelsService()
        
        // Save custom prompt first
        let customPrompt = "Custom prompt"
        service.insightPrompt = customPrompt
        
        // Reset to default
        service.resetInsightPromptToDefault()
        
        // Verify we got back the default prompt
        XCTAssertEqual(service.insightPrompt, FoundationModelsService.defaultInsightPrompt, "Prompt should be reset to default")
    }
    
    func testGenerateLiveInsightsWithCustomPrompt() async throws {
        let service = FoundationModelsService()
        let testText = "We discussed the new project requirements and decided to implement the feature next week. John will work on the frontend, and Sarah will handle the backend. There are concerns about the tight deadline."
        
        // Test with default prompt
        let insights = try await service.generateLiveInsights(from: testText)
        XCTAssertFalse(insights.isEmpty, "Should generate insights from test text")
        print("Generated \(insights.count) insights")
        
        insights.forEach { insight in
            print("- [\(insight.type)] \(insight.content)")
        }
    }
}