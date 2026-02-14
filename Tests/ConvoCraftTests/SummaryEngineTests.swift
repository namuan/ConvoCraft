import XCTest
@testable import ConvoCraft

final class SummaryEngineTests: XCTestCase {
    var sut: SummaryEngine!
    
    override func setUp() {
        super.setUp()
        sut = SummaryEngine()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Summary Generation Tests
    
    func testGenerateSummaryFromMultipleSegments() async {
        let segments = [
            TranscriptSegment(text: "Welcome to the meeting everyone.", timestamp: 0),
            TranscriptSegment(text: "Today we will discuss the project timeline.", timestamp: 5),
            TranscriptSegment(text: "Let's start with the current status.", timestamp: 10)
        ]
        let insights: [IntelligenceInsight] = []
        let duration: TimeInterval = 3600
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: duration)
        
        XCTAssertTrue(summary.summary.contains("Welcome to the meeting everyone."))
        XCTAssertEqual(summary.transcript.count, 3)
        XCTAssertEqual(summary.duration, duration)
    }
    
    func testGenerateSummaryLimitsToThreeSentences() async {
        let segments = [
            TranscriptSegment(text: "First sentence here.", timestamp: 0),
            TranscriptSegment(text: "Second sentence follows.", timestamp: 5),
            TranscriptSegment(text: "Third sentence now.", timestamp: 10),
            TranscriptSegment(text: "Fourth sentence should not appear.", timestamp: 15),
            TranscriptSegment(text: "Fifth sentence also excluded.", timestamp: 20)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertTrue(summary.summary.contains("First sentence"))
        XCTAssertTrue(summary.summary.contains("Second sentence"))
        XCTAssertTrue(summary.summary.contains("Third sentence"))
        XCTAssertFalse(summary.summary.contains("Fourth sentence"))
        XCTAssertFalse(summary.summary.contains("Fifth sentence"))
    }
    
    func testGenerateSummaryWithFewerThanThreeSentences() async {
        let segments = [
            TranscriptSegment(text: "Only one sentence.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.summary, "Only one sentence.")
    }
    
    // MARK: - Empty Transcript Tests
    
    func testGenerateSummaryWithEmptyTranscript() async {
        let segments: [TranscriptSegment] = []
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.summary, "No transcript available.")
        XCTAssertTrue(summary.actionItems.isEmpty)
        XCTAssertTrue(summary.keyDecisions.isEmpty)
        XCTAssertTrue(summary.transcript.isEmpty)
    }
    
    func testGenerateSummaryWithEmptyTextSegments() async {
        let segments = [
            TranscriptSegment(text: "", timestamp: 0),
            TranscriptSegment(text: "   ", timestamp: 5)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.summary, "No transcript available.")
    }
    
    // MARK: - Single Segment Tests
    
    func testGenerateSummaryWithSingleSegment() async {
        let segments = [
            TranscriptSegment(text: "This is the only segment in the transcript.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        let duration: TimeInterval = 120
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: duration)
        
        XCTAssertEqual(summary.summary, "This is the only segment in the transcript.")
        XCTAssertEqual(summary.transcript.count, 1)
        XCTAssertEqual(summary.duration, 120)
    }
    
    // MARK: - Action Item Extraction Tests
    
    func testExtractActionItemsWithNeedTo() async {
        let segments = [
            TranscriptSegment(text: "We need to finish the report by Friday.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].contains("need to"))
    }
    
    func testExtractActionItemsWithShould() async {
        let segments = [
            TranscriptSegment(text: "Someone should review the code.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("should"))
    }
    
    func testExtractActionItemsWithMust() async {
        let segments = [
            TranscriptSegment(text: "We must complete the deployment today.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("must"))
    }
    
    func testExtractActionItemsWithWillDo() async {
        let segments = [
            TranscriptSegment(text: "I will do the research tomorrow.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("will do"))
    }
    
    func testExtractActionItemsWithActionItem() async {
        let segments = [
            TranscriptSegment(text: "Action item: Schedule follow-up meeting.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("action item"))
    }
    
    func testExtractActionItemsWithFollowUp() async {
        let segments = [
            TranscriptSegment(text: "Please follow up with the client.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("follow up"))
    }
    
    func testExtractActionItemsWithTask() async {
        let segments = [
            TranscriptSegment(text: "This task requires immediate attention.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("task"))
    }
    
    func testExtractActionItemsWithTodo() async {
        let segments = [
            TranscriptSegment(text: "Add this to the todo list.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("todo"))
    }
    
    func testExtractActionItemsWithToDo() async {
        let segments = [
            TranscriptSegment(text: "This is something to do next week.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].lowercased().contains("to do"))
    }
    
    func testExtractActionItemsLimitedToFive() async {
        let segments = [
            TranscriptSegment(text: "We need to do task one. We should do task two. We must do task three. I will do task four. This is action item five. We need to do task six which should be excluded. We should do task seven also excluded.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 5)
    }
    
    func testExtractActionItemsWithNoMatches() async {
        let segments = [
            TranscriptSegment(text: "The weather is nice today. We had a good discussion.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertTrue(summary.actionItems.isEmpty)
    }
    
    // MARK: - Key Decision Extraction Tests
    
    func testExtractKeyDecisionsWithDecided() async {
        let segments = [
            TranscriptSegment(text: "We decided to go with option A.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("decided"))
    }
    
    func testExtractKeyDecisionsWithAgree() async {
        let segments = [
            TranscriptSegment(text: "Everyone agree on the proposal.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("agree"))
    }
    
    func testExtractKeyDecisionsWithApproved() async {
        let segments = [
            TranscriptSegment(text: "The budget was approved yesterday.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("approved"))
    }
    
    func testExtractKeyDecisionsWithConfirmed() async {
        let segments = [
            TranscriptSegment(text: "The deadline has been confirmed.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("confirmed"))
    }
    
    func testExtractKeyDecisionsWithCommitted() async {
        let segments = [
            TranscriptSegment(text: "The team committed to the timeline.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("committed"))
    }
    
    func testExtractKeyDecisionsWithGoingWith() async {
        let segments = [
            TranscriptSegment(text: "We are going with the blue design.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("going with"))
    }
    
    func testExtractKeyDecisionsWithFinalDecision() async {
        let segments = [
            TranscriptSegment(text: "The final decision is to postpone.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("final decision"))
    }
    
    func testExtractKeyDecisionsWithConsensus() async {
        let segments = [
            TranscriptSegment(text: "We reached consensus on the approach.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
        XCTAssertTrue(summary.keyDecisions[0].lowercased().contains("consensus"))
    }
    
    func testExtractKeyDecisionsLimitedToFive() async {
        let segments = [
            TranscriptSegment(text: "We decided on item one. We agree on item two. It was approved for item three. The plan was confirmed for item four. We committed to item five. We decided on item six should be excluded. We agree on item seven also excluded.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 5)
    }
    
    func testExtractKeyDecisionsWithNoMatches() async {
        let segments = [
            TranscriptSegment(text: "The meeting is starting. Let's discuss options.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertTrue(summary.keyDecisions.isEmpty)
    }
    
    // MARK: - Duration Tracking Tests
    
    func testDurationIsPreservedInSummary() async {
        let segments = [
            TranscriptSegment(text: "Short meeting.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        let expectedDuration: TimeInterval = 1234.56
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: expectedDuration)
        
        XCTAssertEqual(summary.duration, expectedDuration)
    }
    
    func testZeroDurationIsHandled() async {
        let segments = [
            TranscriptSegment(text: "Instant meeting.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.duration, 0)
    }
    
    func testLargeDurationIsHandled() async {
        let segments = [
            TranscriptSegment(text: "Long meeting.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        let largeDuration: TimeInterval = 86400 * 2 // 2 days
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: largeDuration)
        
        XCTAssertEqual(summary.duration, largeDuration)
    }
    
    // MARK: - Insight Preservation Tests
    
    func testInsightsArePreservedInSummary() async {
        let segments = [
            TranscriptSegment(text: "Discussion happening.", timestamp: 0)
        ]
        let insights = [
            IntelligenceInsight(type: .question, content: "What about budget?", timestamp: 10),
            IntelligenceInsight(type: .idea, content: "New feature idea", timestamp: 20),
            IntelligenceInsight(type: .risk, content: "Timeline risk", timestamp: 30)
        ]
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.insights.count, 3)
        XCTAssertEqual(summary.insights[0].type, .question)
        XCTAssertEqual(summary.insights[1].type, .idea)
        XCTAssertEqual(summary.insights[2].type, .risk)
    }
    
    func testEmptyInsightsAreHandled() async {
        let segments = [
            TranscriptSegment(text: "No insights here.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertTrue(summary.insights.isEmpty)
    }
    
    func testInsightContentIsPreserved() async {
        let segments = [
            TranscriptSegment(text: "Meeting content.", timestamp: 0)
        ]
        let insights = [
            IntelligenceInsight(type: .idea, content: "This is a test idea with specific content", timestamp: 0)
        ]
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.insights.first?.content, "This is a test idea with specific content")
    }
    
    // MARK: - Title Formatting Tests
    
    func testTitleContainsMeeting() async {
        let segments = [
            TranscriptSegment(text: "Test.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertTrue(summary.title.hasPrefix("Meeting - "))
    }
    
    func testTitleContainsFormattedDate() async {
        let segments = [
            TranscriptSegment(text: "Test.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        let dateInTitle = summary.title.replacingOccurrences(of: "Meeting - ", with: "")
        XCTAssertFalse(dateInTitle.isEmpty)
    }
    
    func testDateMatchesCurrentDate() async {
        let segments = [
            TranscriptSegment(text: "Test.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        let beforeDate = Date()
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        let afterDate = Date()
        
        XCTAssertGreaterThanOrEqual(summary.date, beforeDate)
        XCTAssertLessThanOrEqual(summary.date, afterDate)
    }
    
    // MARK: - Transcript Preservation Tests
    
    func testTranscriptSegmentsArePreserved() async {
        let segments = [
            TranscriptSegment(text: "First part.", timestamp: 0),
            TranscriptSegment(text: "Second part.", timestamp: 10),
            TranscriptSegment(text: "Third part.", timestamp: 20)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 30)
        
        XCTAssertEqual(summary.transcript.count, 3)
        XCTAssertEqual(summary.transcript[0].text, "First part.")
        XCTAssertEqual(summary.transcript[1].text, "Second part.")
        XCTAssertEqual(summary.transcript[2].text, "Third part.")
    }
    
    func testTranscriptSegmentIdsArePreserved() async {
        let segmentId = UUID()
        let segments = [
            TranscriptSegment(id: segmentId, text: "Test.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.transcript.first?.id, segmentId)
    }
    
    func testTranscriptTimestampsArePreserved() async {
        let segments = [
            TranscriptSegment(text: "Early.", timestamp: 5.5),
            TranscriptSegment(text: "Late.", timestamp: 100.25)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.transcript[0].timestamp, 5.5)
        XCTAssertEqual(summary.transcript[1].timestamp, 100.25)
    }
    
    func testTranscriptIsFinalFlagIsPreserved() async {
        let segments = [
            TranscriptSegment(text: "Draft.", timestamp: 0, isFinal: false),
            TranscriptSegment(text: "Final.", timestamp: 10, isFinal: true)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertFalse(summary.transcript[0].isFinal)
        XCTAssertTrue(summary.transcript[1].isFinal)
    }
    
    // MARK: - Edge Cases
    
    func testMixedContentWithActionItemsAndDecisions() async {
        let segments = [
            TranscriptSegment(text: "Welcome to the meeting. We decided to launch next week. We need to prepare the marketing materials. The budget was approved. Someone should notify the team. We agree on the pricing strategy.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertGreaterThanOrEqual(summary.actionItems.count, 2)
        XCTAssertGreaterThanOrEqual(summary.keyDecisions.count, 2)
    }
    
    func testCaseInsensitiveActionItemMatching() async {
        let segments = [
            TranscriptSegment(text: "We NEED TO complete this. Someone SHOULD help. We MUST succeed.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.actionItems.count, 3)
    }
    
    func testCaseInsensitiveDecisionMatching() async {
        let segments = [
            TranscriptSegment(text: "We DECIDED yesterday. Everyone AGREED. It was APPROVED.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.keyDecisions.count, 3)
    }
    
    func testSpecialCharactersInText() async {
        let segments = [
            TranscriptSegment(text: "Hello! How are you? I'm fine. We need to review the Q1/Q2 report (see attachment).", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertFalse(summary.summary.isEmpty)
        XCTAssertGreaterThanOrEqual(summary.actionItems.count, 1)
    }
    
    func testMultipleSegmentsAreJoinedCorrectly() async {
        let segments = [
            TranscriptSegment(text: "First segment.", timestamp: 0),
            TranscriptSegment(text: "Second segment.", timestamp: 5),
            TranscriptSegment(text: "Third segment.", timestamp: 10)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertTrue(summary.summary.contains("First segment."))
        XCTAssertTrue(summary.summary.contains("Second segment."))
        XCTAssertTrue(summary.summary.contains("Third segment."))
    }
    
    func testVeryLongTextSegment() async {
        let longText = String(repeating: "This is a sentence. ", count: 100)
        let segments = [
            TranscriptSegment(text: longText, timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertFalse(summary.summary.isEmpty)
    }
    
    func testMeetingSummaryIdIsDate() async {
        let segments = [
            TranscriptSegment(text: "Test.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertEqual(summary.id, summary.date)
    }
    
    func testMeetingSummaryIsHashable() async {
        let segments = [
            TranscriptSegment(text: "Test.", timestamp: 0)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary1 = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        let summary2 = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        let set: Set<MeetingSummary> = [summary1, summary2]
        XCTAssertEqual(set.count, 2)
    }
    
    func testMeetingSummaryIsCodable() async {
        let segments = [
            TranscriptSegment(text: "Test encoding.", timestamp: 0)
        ]
        let insights = [
            IntelligenceInsight(type: .idea, content: "Test insight", timestamp: 5)
        ]
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 100)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MeetingSummary.self, from: data)
        
        XCTAssertEqual(decoded.title, summary.title)
        XCTAssertEqual(decoded.duration, summary.duration)
        XCTAssertEqual(decoded.summary, summary.summary)
        XCTAssertEqual(decoded.actionItems, summary.actionItems)
        XCTAssertEqual(decoded.keyDecisions, summary.keyDecisions)
        XCTAssertEqual(decoded.transcript.count, summary.transcript.count)
        XCTAssertEqual(decoded.insights.count, summary.insights.count)
    }
    
    func testSegmentsWithWhitespaceOnly() async {
        let segments = [
            TranscriptSegment(text: "   ", timestamp: 0),
            TranscriptSegment(text: "\n\t", timestamp: 5),
            TranscriptSegment(text: "Valid text here.", timestamp: 10)
        ]
        let insights: [IntelligenceInsight] = []
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 0)
        
        XCTAssertTrue(summary.summary.contains("Valid text"))
    }
}
