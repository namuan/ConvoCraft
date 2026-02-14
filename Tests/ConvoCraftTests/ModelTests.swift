import XCTest
@testable import ConvoCraft

final class ModelTests: XCTestCase {
    
    // MARK: - TranscriptSegment Tests
    
    // MARK: Initialization
    
    func testTranscriptSegment_Initialization_WithDefaultValues() {
        let segment = TranscriptSegment(text: "Hello world", timestamp: 1.5)
        
        XCTAssertNotNil(segment.id)
        XCTAssertEqual(segment.text, "Hello world")
        XCTAssertEqual(segment.timestamp, 1.5)
        XCTAssertFalse(segment.isFinal)
    }
    
    func testTranscriptSegment_Initialization_WithAllParameters() {
        let customId = UUID()
        let segment = TranscriptSegment(id: customId, text: "Test text", timestamp: 10.0, isFinal: true)
        
        XCTAssertEqual(segment.id, customId)
        XCTAssertEqual(segment.text, "Test text")
        XCTAssertEqual(segment.timestamp, 10.0)
        XCTAssertTrue(segment.isFinal)
    }
    
    func testTranscriptSegment_Initialization_EmptyText() {
        let segment = TranscriptSegment(text: "", timestamp: 0.0)
        
        XCTAssertEqual(segment.text, "")
        XCTAssertEqual(segment.timestamp, 0.0)
    }
    
    func testTranscriptSegment_Initialization_NegativeTimestamp() {
        let segment = TranscriptSegment(text: "Test", timestamp: -5.0)
        
        XCTAssertEqual(segment.timestamp, -5.0)
    }
    
    func testTranscriptSegment_Initialization_ZeroTimestamp() {
        let segment = TranscriptSegment(text: "Test", timestamp: 0.0)
        
        XCTAssertEqual(segment.timestamp, 0.0)
    }
    
    // MARK: Codable
    
    func testTranscriptSegment_Codable_Roundtrip() throws {
        let original = TranscriptSegment(
            id: UUID(),
            text: "Sample transcript text",
            timestamp: 123.456,
            isFinal: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TranscriptSegment.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.timestamp, original.timestamp)
        XCTAssertEqual(decoded.isFinal, original.isFinal)
    }
    
    func testTranscriptSegment_Codable_EmptyText() throws {
        let original = TranscriptSegment(text: "", timestamp: 0.0, isFinal: false)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptSegment.self, from: data)
        
        XCTAssertEqual(decoded.text, "")
    }
    
    func testTranscriptSegment_Codable_SpecialCharacters() throws {
        let specialText = "Hello \"World\"\n\tWith\\Special/Chars 🎉"
        let original = TranscriptSegment(text: specialText, timestamp: 1.0)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptSegment.self, from: data)
        
        XCTAssertEqual(decoded.text, specialText)
    }
    
    // MARK: Hashable
    
    func testTranscriptSegment_Hashable_EqualSegmentsHaveEqualHashes() {
        let id = UUID()
        let segment1 = TranscriptSegment(id: id, text: "Test", timestamp: 1.0, isFinal: true)
        let segment2 = TranscriptSegment(id: id, text: "Test", timestamp: 1.0, isFinal: true)
        
        XCTAssertEqual(segment1.hashValue, segment2.hashValue)
        XCTAssertEqual(segment1, segment2)
    }
    
    func testTranscriptSegment_Hashable_DifferentSegmentsHaveDifferentHashes() {
        let segment1 = TranscriptSegment(text: "Test 1", timestamp: 1.0)
        let segment2 = TranscriptSegment(text: "Test 2", timestamp: 2.0)
        
        XCTAssertNotEqual(segment1, segment2)
    }
    
    func testTranscriptSegment_Hashable_CanBeUsedInSet() {
        let id = UUID()
        let segment1 = TranscriptSegment(id: id, text: "Test", timestamp: 1.0)
        let segment2 = TranscriptSegment(id: id, text: "Test", timestamp: 1.0)
        let segment3 = TranscriptSegment(text: "Different", timestamp: 2.0)
        
        var set = Set<TranscriptSegment>()
        set.insert(segment1)
        set.insert(segment2)
        set.insert(segment3)
        
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: Identifiable
    
    func testTranscriptSegment_Identifiable_HasUniqueId() {
        let segment1 = TranscriptSegment(text: "Test", timestamp: 1.0)
        let segment2 = TranscriptSegment(text: "Test", timestamp: 1.0)
        
        XCTAssertNotEqual(segment1.id, segment2.id)
    }
    
    func testTranscriptSegment_Identifiable_PreservesProvidedId() {
        let customId = UUID()
        let segment = TranscriptSegment(id: customId, text: "Test", timestamp: 1.0)
        
        XCTAssertEqual(segment.id, customId)
    }
    
    // MARK: - IntelligenceInsight Tests
    
    // MARK: Initialization
    
    func testIntelligenceInsight_Initialization_WithDefaultValues() {
        let insight = IntelligenceInsight(type: .question, content: "What is this?")
        
        XCTAssertNotNil(insight.id)
        XCTAssertEqual(insight.type, .question)
        XCTAssertEqual(insight.content, "What is this?")
        XCTAssertGreaterThan(insight.timestamp, 0)
    }
    
    func testIntelligenceInsight_Initialization_WithAllParameters() {
        let customId = UUID()
        let customTimestamp: TimeInterval = 1700000000
        
        let insight = IntelligenceInsight(
            id: customId,
            type: .idea,
            content: "New idea",
            timestamp: customTimestamp
        )
        
        XCTAssertEqual(insight.id, customId)
        XCTAssertEqual(insight.type, .idea)
        XCTAssertEqual(insight.content, "New idea")
        XCTAssertEqual(insight.timestamp, customTimestamp)
    }
    
    func testIntelligenceInsight_Initialization_EmptyContent() {
        let insight = IntelligenceInsight(type: .risk, content: "")
        
        XCTAssertEqual(insight.content, "")
    }
    
    func testIntelligenceInsight_Initialization_AllInsightTypes() {
        let questionInsight = IntelligenceInsight(type: .question, content: "Q")
        let ideaInsight = IntelligenceInsight(type: .idea, content: "I")
        let riskInsight = IntelligenceInsight(type: .risk, content: "R")
        
        XCTAssertEqual(questionInsight.type, .question)
        XCTAssertEqual(ideaInsight.type, .idea)
        XCTAssertEqual(riskInsight.type, .risk)
    }
    
    // MARK: Codable
    
    func testIntelligenceInsight_Codable_Roundtrip() throws {
        let original = IntelligenceInsight(
            id: UUID(),
            type: .idea,
            content: "Brilliant idea here",
            timestamp: 1234567890
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IntelligenceInsight.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.timestamp, original.timestamp)
    }
    
    func testIntelligenceInsight_Codable_AllTypes() throws {
        for type in [InsightType.question, .idea, .risk] {
            let original = IntelligenceInsight(type: type, content: "Test")
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(IntelligenceInsight.self, from: data)
            XCTAssertEqual(decoded.type, type)
        }
    }
    
    // MARK: Hashable
    
    func testIntelligenceInsight_Hashable_EqualInsightsHaveEqualHashes() {
        let id = UUID()
        let insight1 = IntelligenceInsight(id: id, type: .question, content: "Test", timestamp: 1.0)
        let insight2 = IntelligenceInsight(id: id, type: .question, content: "Test", timestamp: 1.0)
        
        XCTAssertEqual(insight1.hashValue, insight2.hashValue)
        XCTAssertEqual(insight1, insight2)
    }
    
    func testIntelligenceInsight_Hashable_DifferentInsightsHaveDifferentHashes() {
        let insight1 = IntelligenceInsight(type: .question, content: "Question")
        let insight2 = IntelligenceInsight(type: .idea, content: "Idea")
        
        XCTAssertNotEqual(insight1, insight2)
    }
    
    func testIntelligenceInsight_Hashable_CanBeUsedInSet() {
        let id = UUID()
        let insight1 = IntelligenceInsight(id: id, type: .question, content: "Test", timestamp: 1.0)
        let insight2 = IntelligenceInsight(id: id, type: .question, content: "Test", timestamp: 1.0)
        let insight3 = IntelligenceInsight(type: .idea, content: "Different", timestamp: 2.0)
        
        var set = Set<IntelligenceInsight>()
        set.insert(insight1)
        set.insert(insight2)
        set.insert(insight3)
        
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: Identifiable
    
    func testIntelligenceInsight_Identifiable_HasUniqueId() {
        let insight1 = IntelligenceInsight(type: .question, content: "Test")
        let insight2 = IntelligenceInsight(type: .question, content: "Test")
        
        XCTAssertNotEqual(insight1.id, insight2.id)
    }
    
    func testIntelligenceInsight_Identifiable_PreservesProvidedId() {
        let customId = UUID()
        let insight = IntelligenceInsight(id: customId, type: .idea, content: "Test")
        
        XCTAssertEqual(insight.id, customId)
    }
    
    // MARK: - InsightType Tests
    
    func testInsightType_RawValues() {
        XCTAssertEqual(InsightType.question.rawValue, "question")
        XCTAssertEqual(InsightType.idea.rawValue, "idea")
        XCTAssertEqual(InsightType.risk.rawValue, "risk")
    }
    
    func testInsightType_Codable_Roundtrip() throws {
        for type in [InsightType.question, .idea, .risk] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(InsightType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }
    
    func testInsightType_InitFromRawValue() {
        XCTAssertEqual(InsightType(rawValue: "question"), .question)
        XCTAssertEqual(InsightType(rawValue: "idea"), .idea)
        XCTAssertEqual(InsightType(rawValue: "risk"), .risk)
        XCTAssertNil(InsightType(rawValue: "unknown"))
    }
    
    // MARK: - MeetingSummary Tests
    
    // MARK: Initialization
    
    func testMeetingSummary_Initialization_AllFields() {
        let date = Date()
        let transcript = [
            TranscriptSegment(text: "Hello", timestamp: 0.0),
            TranscriptSegment(text: "World", timestamp: 5.0)
        ]
        let insights = [
            IntelligenceInsight(type: .question, content: "Q1"),
            IntelligenceInsight(type: .idea, content: "I1")
        ]
        
        let summary = MeetingSummary(
            title: "Team Meeting",
            date: date,
            duration: 3600.0,
            summary: "Discussed project progress",
            actionItems: ["Task 1", "Task 2"],
            keyDecisions: ["Decision 1"],
            transcript: transcript,
            insights: insights
        )
        
        XCTAssertEqual(summary.title, "Team Meeting")
        XCTAssertEqual(summary.date, date)
        XCTAssertEqual(summary.duration, 3600.0)
        XCTAssertEqual(summary.summary, "Discussed project progress")
        XCTAssertEqual(summary.actionItems, ["Task 1", "Task 2"])
        XCTAssertEqual(summary.keyDecisions, ["Decision 1"])
        XCTAssertEqual(summary.transcript.count, 2)
        XCTAssertEqual(summary.insights.count, 2)
    }
    
    func testMeetingSummary_Initialization_EmptyCollections() {
        let date = Date()
        
        let summary = MeetingSummary(
            title: "Empty Meeting",
            date: date,
            duration: 0.0,
            summary: "",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        XCTAssertEqual(summary.title, "Empty Meeting")
        XCTAssertEqual(summary.actionItems, [])
        XCTAssertEqual(summary.keyDecisions, [])
        XCTAssertEqual(summary.transcript, [])
        XCTAssertEqual(summary.insights, [])
    }
    
    func testMeetingSummary_Initialization_EmptyTitle() {
        let summary = MeetingSummary(
            title: "",
            date: Date(),
            duration: 100.0,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        XCTAssertEqual(summary.title, "")
    }
    
    func testMeetingSummary_Initialization_LongDuration() {
        let longDuration: TimeInterval = 86400.0
        let summary = MeetingSummary(
            title: "Long Meeting",
            date: Date(),
            duration: longDuration,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        XCTAssertEqual(summary.duration, longDuration)
    }
    
    // MARK: Codable
    
    func testMeetingSummary_Codable_Roundtrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let transcript = [
            TranscriptSegment(id: UUID(), text: "First", timestamp: 0.0, isFinal: false),
            TranscriptSegment(id: UUID(), text: "Second", timestamp: 5.0, isFinal: true)
        ]
        let insights = [
            IntelligenceInsight(id: UUID(), type: .idea, content: "Great idea", timestamp: 100.0)
        ]
        
        let original = MeetingSummary(
            title: "Sprint Planning",
            date: date,
            duration: 1800.0,
            summary: "Planned sprint tasks",
            actionItems: ["Review code", "Write tests"],
            keyDecisions: ["Use Swift 6"],
            transcript: transcript,
            insights: insights
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(MeetingSummary.self, from: data)
        
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.date, original.date)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.summary, original.summary)
        XCTAssertEqual(decoded.actionItems, original.actionItems)
        XCTAssertEqual(decoded.keyDecisions, original.keyDecisions)
        XCTAssertEqual(decoded.transcript.count, original.transcript.count)
        XCTAssertEqual(decoded.insights.count, original.insights.count)
    }
    
    func testMeetingSummary_Codable_EmptyCollections() throws {
        let original = MeetingSummary(
            title: "Test",
            date: Date(),
            duration: 0.0,
            summary: "",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MeetingSummary.self, from: data)
        
        XCTAssertEqual(decoded.actionItems, [])
        XCTAssertEqual(decoded.keyDecisions, [])
        XCTAssertEqual(decoded.transcript, [])
        XCTAssertEqual(decoded.insights, [])
    }
    
    // MARK: Hashable
    
    func testMeetingSummary_Hashable_EqualSummariesHaveEqualHashes() {
        let date = Date()
        let summary1 = MeetingSummary(
            title: "Meeting",
            date: date,
            duration: 100.0,
            summary: "Summary",
            actionItems: ["A"],
            keyDecisions: ["D"],
            transcript: [],
            insights: []
        )
        let summary2 = MeetingSummary(
            title: "Meeting",
            date: date,
            duration: 100.0,
            summary: "Summary",
            actionItems: ["A"],
            keyDecisions: ["D"],
            transcript: [],
            insights: []
        )
        
        XCTAssertEqual(summary1.hashValue, summary2.hashValue)
        XCTAssertEqual(summary1, summary2)
    }
    
    func testMeetingSummary_Hashable_DifferentSummariesHaveDifferentHashes() {
        let summary1 = MeetingSummary(
            title: "Meeting 1",
            date: Date(),
            duration: 100.0,
            summary: "Summary 1",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        let summary2 = MeetingSummary(
            title: "Meeting 2",
            date: Date(),
            duration: 200.0,
            summary: "Summary 2",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        XCTAssertNotEqual(summary1, summary2)
    }
    
    func testMeetingSummary_Hashable_CanBeUsedInSet() {
        let date = Date()
        let summary1 = MeetingSummary(
            title: "Meeting",
            date: date,
            duration: 100.0,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        let summary2 = MeetingSummary(
            title: "Meeting",
            date: date,
            duration: 100.0,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        let summary3 = MeetingSummary(
            title: "Different Meeting",
            date: Date().addingTimeInterval(86400),
            duration: 200.0,
            summary: "Different",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        var set = Set<MeetingSummary>()
        set.insert(summary1)
        set.insert(summary2)
        set.insert(summary3)
        
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: Identifiable
    
    func testMeetingSummary_Identifiable_IdIsDate() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let summary = MeetingSummary(
            title: "Test",
            date: date,
            duration: 100.0,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        XCTAssertEqual(summary.id, date)
    }
    
    func testMeetingSummary_Identifiable_DifferentDatesProduceDifferentIds() {
        let date1 = Date(timeIntervalSince1970: 1700000000)
        let date2 = Date(timeIntervalSince1970: 1800000000)
        
        let summary1 = MeetingSummary(
            title: "Meeting 1",
            date: date1,
            duration: 100.0,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        let summary2 = MeetingSummary(
            title: "Meeting 2",
            date: date2,
            duration: 100.0,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        XCTAssertNotEqual(summary1.id, summary2.id)
    }
    
    // MARK: Integration Tests
    
    func testMeetingSummary_WithMultipleTranscriptsAndInsights() {
        let transcripts = (0..<10).map { i in
            TranscriptSegment(text: "Segment \(i)", timestamp: Double(i * 5), isFinal: i == 9)
        }
        
        let insights = [
            IntelligenceInsight(type: .question, content: "What about performance?"),
            IntelligenceInsight(type: .idea, content: "We could use caching"),
            IntelligenceInsight(type: .risk, content: "Timeline might slip")
        ]
        
        let summary = MeetingSummary(
            title: "Complex Meeting",
            date: Date(),
            duration: 3600.0,
            summary: "Complex discussion",
            actionItems: ["Task 1", "Task 2", "Task 3"],
            keyDecisions: ["Decision A", "Decision B"],
            transcript: transcripts,
            insights: insights
        )
        
        XCTAssertEqual(summary.transcript.count, 10)
        XCTAssertEqual(summary.insights.count, 3)
        XCTAssertTrue(summary.transcript.last!.isFinal)
        XCTAssertEqual(summary.actionItems.count, 3)
        XCTAssertEqual(summary.keyDecisions.count, 2)
    }
    
    func testModels_CanBeUsedTogether() throws {
        let segment = TranscriptSegment(text: "Discussion point", timestamp: 10.0, isFinal: false)
        let insight = IntelligenceInsight(type: .idea, content: "New feature idea", timestamp: 15.0)
        
        let summary = MeetingSummary(
            title: "Integration Test",
            date: Date(),
            duration: 60.0,
            summary: "Test summary",
            actionItems: ["Action"],
            keyDecisions: ["Decision"],
            transcript: [segment],
            insights: [insight]
        )
        
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(MeetingSummary.self, from: data)
        
        XCTAssertEqual(decoded.transcript.first?.text, "Discussion point")
        XCTAssertEqual(decoded.insights.first?.type, .idea)
    }
}
