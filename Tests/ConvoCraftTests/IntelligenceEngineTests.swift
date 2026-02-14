import XCTest
@testable import ConvoCraft

final class IntelligenceEngineTests: XCTestCase {
    
    var sut: IntelligenceEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = IntelligenceEngine()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Uncertainty Phrase Detection
    
    func testDetectsUncertaintyPhraseMaybe() async {
        let segments = [TranscriptSegment(text: "Maybe we should consider this approach", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("maybe") ?? false)
    }
    
    func testDetectsUncertaintyPhraseNotSure() async {
        let segments = [TranscriptSegment(text: "I am not sure about this solution", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("not sure") ?? false)
    }
    
    func testDetectsUncertaintyPhrasePerhaps() async {
        let segments = [TranscriptSegment(text: "Perhaps we could try something different", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("perhaps") ?? false)
    }
    
    func testDetectsUncertaintyPhraseMight() async {
        let segments = [TranscriptSegment(text: "This might be the right direction", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("might") ?? false)
    }
    
    func testDetectsUncertaintyPhraseCouldBe() async {
        let segments = [TranscriptSegment(text: "That could be a viable option", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("could be") ?? false)
    }
    
    func testUncertaintyPhraseIsCaseInsensitive() async {
        let segments = [TranscriptSegment(text: "MAYBE this will work", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
    }
    
    // MARK: - Commitment/Action Phrase Detection
    
    func testDetectsCommitmentPhraseWeShould() async {
        let segments = [TranscriptSegment(text: "We should implement this feature", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .idea)
        XCTAssertTrue(insights.first?.content.contains("Action commitment") ?? false)
    }
    
    func testDetectsCommitmentPhraseNeedTo() async {
        let segments = [TranscriptSegment(text: "We need to finish this by Friday", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .idea)
        XCTAssertTrue(insights.first?.content.contains("Action commitment") ?? false)
    }
    
    func testDetectsCommitmentPhraseMust() async {
        let segments = [TranscriptSegment(text: "We must complete the review", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .idea)
        XCTAssertTrue(insights.first?.content.contains("Action commitment") ?? false)
    }
    
    func testDetectsCommitmentPhraseWillDo() async {
        let segments = [TranscriptSegment(text: "I will do that tomorrow", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .idea)
        XCTAssertTrue(insights.first?.content.contains("Action commitment") ?? false)
    }
    
    func testCommitmentPhraseIsCaseInsensitive() async {
        let segments = [TranscriptSegment(text: "WE SHOULD consider this", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .idea)
    }
    
    // MARK: - Risk Phrase Detection
    
    func testDetectsRiskPhraseRisk() async {
        let segments = [TranscriptSegment(text: "There is a risk of delay", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .risk)
        XCTAssertTrue(insights.first?.content.contains("risk") ?? false)
    }
    
    func testDetectsRiskPhraseProblem() async {
        let segments = [TranscriptSegment(text: "We have a problem with the deployment", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .risk)
        XCTAssertTrue(insights.first?.content.contains("problem") ?? false)
    }
    
    func testDetectsRiskPhraseIssue() async {
        let segments = [TranscriptSegment(text: "This issue needs attention", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .risk)
        XCTAssertTrue(insights.first?.content.contains("issue") ?? false)
    }
    
    func testDetectsRiskPhraseConcern() async {
        let segments = [TranscriptSegment(text: "I have a concern about the timeline", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .risk)
        XCTAssertTrue(insights.first?.content.contains("concern") ?? false)
    }
    
    func testDetectsRiskPhraseBlocker() async {
        let segments = [TranscriptSegment(text: "There is a blocker in our workflow", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .risk)
        XCTAssertTrue(insights.first?.content.contains("blocker") ?? false)
    }
    
    func testDetectsRiskPhraseChallenge() async {
        let segments = [TranscriptSegment(text: "This challenge requires attention", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .risk)
        XCTAssertTrue(insights.first?.content.contains("challenge") ?? false)
    }
    
    func testRiskPhraseIsCaseInsensitive() async {
        let segments = [TranscriptSegment(text: "RISK is high here", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .risk)
    }
    
    // MARK: - Timeline Phrase Detection
    
    func testDetectsTimelinePhraseDeadline() async {
        let segments = [TranscriptSegment(text: "The deadline is approaching", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("Timeline") ?? false)
    }
    
    func testDetectsTimelinePhraseDueDate() async {
        let segments = [TranscriptSegment(text: "What is the due date?", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("Timeline") ?? false)
    }
    
    func testDetectsTimelinePhraseTimeline() async {
        let segments = [TranscriptSegment(text: "Let's review the timeline", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("Timeline") ?? false)
    }
    
    func testDetectsTimelinePhraseSchedule() async {
        let segments = [TranscriptSegment(text: "The schedule is tight", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
        XCTAssertTrue(insights.first?.content.contains("Timeline") ?? false)
    }
    
    func testDetectsTimelinePhraseByNextWeek() async {
        let segments = [TranscriptSegment(text: "We need this by next week", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 2)
        XCTAssertTrue(insights.contains { $0.type == .idea })
        XCTAssertTrue(insights.contains { $0.type == .question && $0.content.contains("Timeline") })
    }
    
    func testTimelinePhraseIsCaseInsensitive() async {
        let segments = [TranscriptSegment(text: "THE DEADLINE is tomorrow", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
    }
    
    // MARK: - Multiple Phrase Detection
    
    func testDetectsMultiplePhraseTypes() async {
        let segments = [TranscriptSegment(text: "Maybe we should fix this risk before the deadline", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 3)
        XCTAssertTrue(insights.contains { $0.type == .question })
        XCTAssertTrue(insights.contains { $0.type == .idea })
        XCTAssertTrue(insights.contains { $0.type == .risk })
    }
    
    func testLimitsInsightsToThree() async {
        let segments = [TranscriptSegment(text: "Maybe we should address the risk issue concern blocker challenge by the deadline timeline schedule", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 3)
    }
    
    func testCombinesMultipleSegments() async {
        let segments = [
            TranscriptSegment(text: "Maybe", timestamp: 0),
            TranscriptSegment(text: "we should", timestamp: 1),
            TranscriptSegment(text: "address the risk", timestamp: 2)
        ]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 3)
    }
    
    // MARK: - Empty Transcript Handling
    
    func testHandlesEmptySegmentsArray() async {
        let segments: [TranscriptSegment] = []
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 0)
    }
    
    func testHandlesSegmentWithEmptyText() async {
        let segments = [TranscriptSegment(text: "", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 0)
    }
    
    func testHandlesSegmentsWithOnlyWhitespace() async {
        let segments = [TranscriptSegment(text: "   ", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 0)
    }
    
    // MARK: - Clear Insights Functionality
    
    func testClearInsightsRemovesAllStoredInsights() async {
        let segments = [TranscriptSegment(text: "Maybe we should consider this", timestamp: 0)]
        _ = await sut.analyzeTranscript(segments)
        
        var currentInsights = await sut.getAllInsights()
        XCTAssertFalse(currentInsights.isEmpty)
        
        await sut.clearInsights()
        
        currentInsights = await sut.getAllInsights()
        XCTAssertTrue(currentInsights.isEmpty)
    }
    
    func testClearInsightsOnEmptyEngineDoesNotCrash() async {
        await sut.clearInsights()
        let insights = await sut.getAllInsights()
        XCTAssertTrue(insights.isEmpty)
    }
    
    // MARK: - Insight Storage and Retrieval
    
    func testGetAllInsightsReturnsStoredInsights() async {
        let segments = [TranscriptSegment(text: "Maybe we should check the risk", timestamp: 0)]
        _ = await sut.analyzeTranscript(segments)
        
        let allInsights = await sut.getAllInsights()
        XCTAssertEqual(allInsights.count, 3)
    }
    
    func testInsightsAccumulateAcrossMultipleAnalyses() async {
        let segments1 = [TranscriptSegment(text: "Maybe this works", timestamp: 0)]
        let segments2 = [TranscriptSegment(text: "We should try again", timestamp: 1)]
        
        _ = await sut.analyzeTranscript(segments1)
        _ = await sut.analyzeTranscript(segments2)
        
        let allInsights = await sut.getAllInsights()
        XCTAssertEqual(allInsights.count, 2)
    }
    
    func testAnalyzeTranscriptReturnsNewInsights() async {
        let segments = [TranscriptSegment(text: "Maybe we should check this", timestamp: 0)]
        let newInsights = await sut.analyzeTranscript(segments)
        
        let allInsights = await sut.getAllInsights()
        XCTAssertEqual(newInsights.count, allInsights.count)
    }
    
    func testInsightHasValidId() async {
        let segments = [TranscriptSegment(text: "Maybe", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertNotNil(insights.first?.id)
    }
    
    func testInsightHasValidTimestamp() async {
        let segments = [TranscriptSegment(text: "Maybe", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertNotNil(insights.first?.timestamp)
        XCTAssertTrue((insights.first?.timestamp ?? 0) > 0)
    }
    
    // MARK: - Edge Cases
    
    func testHandlesPhraseWithinWord() async {
        let segments = [TranscriptSegment(text: "assignment", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 0)
    }
    
    func testHandlesRepeatedPhrases() async {
        let segments = [TranscriptSegment(text: "maybe maybe maybe", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
    }
    
    func testHandlesMixedCasePhrases() async {
        let segments = [TranscriptSegment(text: "MaYbE this is right", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.type, .question)
    }
    
    func testHandlesSpecialCharacters() async {
        let segments = [TranscriptSegment(text: "Maybe! We should... do this?", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertGreaterThanOrEqual(insights.count, 1)
    }
    
    func testHandlesVeryLongText() async {
        let longText = String(repeating: "This is a sentence. ", count: 1000) + " maybe this is the end"
        let segments = [TranscriptSegment(text: longText, timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertGreaterThanOrEqual(insights.count, 1)
    }
    
    func testHandlesUnicodeCharacters() async {
        let segments = [TranscriptSegment(text: "Maybe 我们 should这样做 🎉", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertGreaterThanOrEqual(insights.count, 1)
    }
    
    func testPhraseDetectionDoesNotMatchPartialWords() async {
        let segments = [TranscriptSegment(text: "assignment commitment", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        let hasMistakenRisk = insights.contains { $0.type == .risk }
        XCTAssertFalse(hasMistakenRisk)
    }
    
    func testInsightContentContainsRelevantPhrase() async {
        let segments = [TranscriptSegment(text: "There is a major risk here", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        let riskInsight = insights.first { $0.type == .risk }
        XCTAssertNotNil(riskInsight)
        XCTAssertTrue(riskInsight?.content.contains("risk") ?? false)
    }
    
    func testMultipleTimelinePhrasesProduceOneInsight() async {
        let segments = [TranscriptSegment(text: "The deadline and timeline are both important", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        let timelineInsights = insights.filter { $0.content.contains("Timeline") }
        XCTAssertEqual(timelineInsights.count, 1)
    }
    
    func testMultipleRiskPhrasesProduceOneInsight() async {
        let segments = [TranscriptSegment(text: "The risk and problem are both concerning", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        let riskInsights = insights.filter { $0.type == .risk }
        XCTAssertEqual(riskInsights.count, 1)
    }
    
    func testMultipleCommitmentPhrasesProduceOneInsight() async {
        let segments = [TranscriptSegment(text: "We should and need to do this", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        let commitmentInsights = insights.filter { $0.content.contains("Action commitment") }
        XCTAssertEqual(commitmentInsights.count, 1)
    }
    
    func testMultipleUncertaintyPhrasesProduceOneInsight() async {
        let segments = [TranscriptSegment(text: "Maybe and perhaps we could be right", timestamp: 0)]
        let insights = await sut.analyzeTranscript(segments)
        
        let uncertaintyInsights = insights.filter { $0.content.contains("uncertainty") }
        XCTAssertEqual(uncertaintyInsights.count, 1)
    }
}