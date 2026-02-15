// Test file to verify the improved AI insights generation
import Foundation
import FoundationModels
import ConvoCraft

func testImprovedInsightsGeneration() async {
    print("=== Testing Improved AI Insights Generation ===")
    
    // Sample meeting conversation with meaningful content
    let sampleTranscript = [
        TranscriptSegment(text: "We need to discuss the implementation strategy for the new user authentication system. The current approach has security vulnerabilities and doesn't support multi-factor authentication.", timestamp: 0),
        TranscriptSegment(text: "What are the options for integrating MFA? Should we use SMS-based verification or authenticator apps like Google Authenticator?", timestamp: 15),
        TranscriptSegment(text: "I think authenticator apps are more secure than SMS. We should also consider support for biometric authentication for mobile devices.", timestamp: 30),
        TranscriptSegment(text: "Let's prioritize the authenticator app integration first, then add biometric support in the next phase. We should aim to have this implemented by the end of the quarter.", timestamp: 45),
        TranscriptSegment(text: "We need to coordinate with the security team to ensure our implementation meets compliance requirements like GDPR.", timestamp: 60)
    ]
    
    print("\n=== Using Foundation Models (if available) ===")
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        do {
            let intelligenceEngine = IntelligenceEngine()
            let insights = await intelligenceEngine.analyzeTranscript(sampleTranscript)
            
            print("Generated \(insights.count) insights:")
            for (index, insight) in insights.enumerated() {
                print("\(index + 1). [\(insight.type)] \(insight.content)")
            }
            
            // Verify quality improvements
            let ideaCount = insights.filter { $0.type == .idea }.count
            print("\n✅ Idea count: \(ideaCount)")
            
            let hasMeaningfulIdeas = insights.allSatisfy { insight in
                if insight.type == .idea {
                    let content = insight.content.lowercased()
                    return content.count > 10 && 
                           !content.contains("key topic:") && 
                           !content.contains("topic:") &&
                           !content.contains("idea:")
                }
                return true
            }
            
            print("✅ Meaningful ideas:", hasMeaningfulIdeas ? "Yes" : "No")
            
        } catch {
            print("❌ Error using Foundation Models: \(error)")
        }
    } else {
        print("ℹ️ Foundation Models not available on this macOS version")
    }
    #endif
    
    print("\n=== Using NLP Fallback ===")
    do {
        let intelligenceEngine = IntelligenceEngine()
        let insights = await intelligenceEngine.analyzeTranscript(sampleTranscript)
        
        print("Generated \(insights.count) insights:")
        for (index, insight) in insights.enumerated() {
            print("\(index + 1). [\(insight.type)] \(insight.content)")
        }
        
    } catch {
        print("❌ Error using NLP analysis: \(error)")
    }
}

// Run the test
Task {
    await testImprovedInsightsGeneration()
}