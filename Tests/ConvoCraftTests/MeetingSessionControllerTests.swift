import XCTest
@testable import ConvoCraft

@MainActor
final class MeetingSessionControllerTests: XCTestCase {
    
    var controller: MeetingSessionController!
    
    override func setUp() async throws {
        try await super.setUp()
        controller = MeetingSessionController()
    }
    
    override func tearDown() async throws {
        controller = nil
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialStateIsRecordingIsFalse() {
        XCTAssertFalse(controller.isRecording)
    }
    
    func testInitialStateCurrentTranscriptIsEmpty() {
        XCTAssertTrue(controller.currentTranscript.isEmpty)
    }
    
    func testInitialStatePartialTranscriptIsEmpty() {
        XCTAssertEqual(controller.partialTranscript, "")
    }
    
    func testInitialStateInsightsIsEmpty() {
        XCTAssertTrue(controller.insights.isEmpty)
    }
    
    func testInitialStateErrorMessageIsNil() {
        XCTAssertNil(controller.errorMessage)
    }
    
    func testInitialStateLastSummaryIsNil() {
        XCTAssertNil(controller.lastSummary)
    }
    
    func testAllInitialStateProperties() {
        XCTAssertFalse(controller.isRecording)
        XCTAssertTrue(controller.currentTranscript.isEmpty)
        XCTAssertEqual(controller.partialTranscript, "")
        XCTAssertTrue(controller.insights.isEmpty)
        XCTAssertNil(controller.errorMessage)
        XCTAssertNil(controller.lastSummary)
    }
    
    // MARK: - Observable Property Tests
    
    func testIsRecordingCanBeSetToTrue() {
        controller.isRecording = true
        XCTAssertTrue(controller.isRecording)
    }
    
    func testIsRecordingCanBeSetBackToFalse() {
        controller.isRecording = true
        controller.isRecording = false
        XCTAssertFalse(controller.isRecording)
    }
    
    func testErrorMessageCanBeSet() {
        controller.errorMessage = "Test error"
        XCTAssertEqual(controller.errorMessage, "Test error")
    }
    
    func testErrorMessageCanBeCleared() {
        controller.errorMessage = "Test error"
        controller.errorMessage = nil
        XCTAssertNil(controller.errorMessage)
    }
    
    func testPartialTranscriptCanBeSet() {
        controller.partialTranscript = "Hello world"
        XCTAssertEqual(controller.partialTranscript, "Hello world")
    }
    
    func testPartialTranscriptCanBeCleared() {
        controller.partialTranscript = "Hello world"
        controller.partialTranscript = ""
        XCTAssertEqual(controller.partialTranscript, "")
    }
    
    func testCurrentTranscriptCanBeModified() {
        let segment = TranscriptSegment(
            text: "Test transcript",
            timestamp: Date().timeIntervalSince1970,
            isFinal: true
        )
        controller.currentTranscript = [segment]
        
        XCTAssertEqual(controller.currentTranscript.count, 1)
        XCTAssertEqual(controller.currentTranscript.first?.text, "Test transcript")
    }
    
    func testCurrentTranscriptCanBeCleared() {
        let segment = TranscriptSegment(
            text: "Test",
            timestamp: Date().timeIntervalSince1970,
            isFinal: true
        )
        controller.currentTranscript = [segment]
        controller.currentTranscript = []
        
        XCTAssertTrue(controller.currentTranscript.isEmpty)
    }
    
    func testInsightsCanBeSet() {
        let insight = IntelligenceInsight(
            type: .idea,
            content: "Test insight"
        )
        controller.insights = [insight]
        
        XCTAssertEqual(controller.insights.count, 1)
        XCTAssertEqual(controller.insights.first?.content, "Test insight")
    }
    
    func testInsightsCanBeCleared() {
        let insight = IntelligenceInsight(
            type: .idea,
            content: "Test"
        )
        controller.insights = [insight]
        controller.insights = []
        
        XCTAssertTrue(controller.insights.isEmpty)
    }
    
    func testLastSummaryCanBeSet() {
        let summary = MeetingSummary(
            title: "Test Meeting",
            date: Date(),
            duration: 300,
            summary: "Test summary",
            actionItems: ["Action 1"],
            keyDecisions: ["Decision 1"],
            transcript: [],
            insights: []
        )
        controller.lastSummary = summary
        
        XCTAssertEqual(controller.lastSummary?.title, "Test Meeting")
    }
    
    func testLastSummaryCanBeCleared() {
        let summary = MeetingSummary(
            title: "Test",
            date: Date(),
            duration: 60,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        controller.lastSummary = summary
        controller.lastSummary = nil
        
        XCTAssertNil(controller.lastSummary)
    }
    
    // MARK: - Multiple Insight Types Test
    
    func testAllInsightTypesInInsightsArray() {
        let questionInsight = IntelligenceInsight(type: .question, content: "Question?")
        let ideaInsight = IntelligenceInsight(type: .idea, content: "Idea!")
        let riskInsight = IntelligenceInsight(type: .risk, content: "Risk!")
        
        controller.insights = [questionInsight, ideaInsight, riskInsight]
        
        XCTAssertEqual(controller.insights.count, 3)
        XCTAssertTrue(controller.insights.contains { $0.type == .question })
        XCTAssertTrue(controller.insights.contains { $0.type == .idea })
        XCTAssertTrue(controller.insights.contains { $0.type == .risk })
    }
    
    // MARK: - Transcript Segment State Tests
    
    func testTranscriptSegmentsWithDifferentIsFinalStates() {
        let finalSegment = TranscriptSegment(
            text: "Final",
            timestamp: Date().timeIntervalSince1970,
            isFinal: true
        )
        let partialSegment = TranscriptSegment(
            text: "Partial",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        controller.currentTranscript = [finalSegment, partialSegment]
        
        XCTAssertEqual(controller.currentTranscript.count, 2)
        XCTAssertTrue(controller.currentTranscript[0].isFinal)
        XCTAssertFalse(controller.currentTranscript[1].isFinal)
    }
    
    func testTranscriptSegmentOrdering() {
        let baseTime = Date().timeIntervalSince1970
        
        for i in 1...5 {
            let segment = TranscriptSegment(
                text: "Segment \(i)",
                timestamp: baseTime + TimeInterval(i),
                isFinal: true
            )
            controller.currentTranscript.append(segment)
        }
        
        XCTAssertEqual(controller.currentTranscript.count, 5)
        for (index, segment) in controller.currentTranscript.enumerated() {
            XCTAssertEqual(segment.text, "Segment \(index + 1)")
        }
    }
    
    // MARK: - Summary Properties Test
    
    func testMeetingSummaryAllProperties() {
        let segments = [
            TranscriptSegment(text: "Hello", timestamp: Date().timeIntervalSince1970, isFinal: true)
        ]
        let insights = [
            IntelligenceInsight(type: .idea, content: "Great idea")
        ]
        
        let summary = MeetingSummary(
            title: "Team Standup",
            date: Date(),
            duration: 900,
            summary: "Daily sync meeting",
            actionItems: ["Review PR", "Update docs"],
            keyDecisions: ["Ship on Friday"],
            transcript: segments,
            insights: insights
        )
        
        controller.lastSummary = summary
        
        XCTAssertEqual(controller.lastSummary?.title, "Team Standup")
        XCTAssertEqual(controller.lastSummary?.duration, 900)
        XCTAssertEqual(controller.lastSummary?.actionItems.count, 2)
        XCTAssertEqual(controller.lastSummary?.keyDecisions.count, 1)
        XCTAssertEqual(controller.lastSummary?.transcript.count, 1)
        XCTAssertEqual(controller.lastSummary?.insights.count, 1)
    }
    
    // MARK: - Error Message Variations
    
    func testDifferentErrorMessages() {
        let errors = [
            "Speech recognition not authorized",
            "Transcription error: Network unavailable",
            "Failed to save summary: Disk full",
            "Microphone access denied"
        ]
        
        for error in errors {
            controller.errorMessage = error
            XCTAssertEqual(controller.errorMessage, error)
        }
    }
    
    // MARK: - State Reset Simulation
    
    func testSimulatedStateReset() {
        controller.isRecording = true
        controller.currentTranscript = [
            TranscriptSegment(text: "Test", timestamp: Date().timeIntervalSince1970, isFinal: true)
        ]
        controller.partialTranscript = "Partial"
        controller.insights = [IntelligenceInsight(type: .idea, content: "Test")]
        controller.errorMessage = "Error"
        
        controller.isRecording = false
        controller.currentTranscript = []
        controller.partialTranscript = ""
        controller.insights = []
        controller.errorMessage = nil
        
        XCTAssertFalse(controller.isRecording)
        XCTAssertTrue(controller.currentTranscript.isEmpty)
        XCTAssertEqual(controller.partialTranscript, "")
        XCTAssertTrue(controller.insights.isEmpty)
        XCTAssertNil(controller.errorMessage)
    }
}

// MARK: - Tests Requiring Mocking/Integration Testing
/*
 The following tests would require mocking the hardware dependencies:
 
 1. startMeeting() Tests (requires mocking SpeechTranscriber):
    - testStartMeetingSetsIsRecordingToTrue
    - testStartMeetingClearsPreviousTranscript
    - testStartMeetingClearsPreviousInsights
    - testStartMeetingClearsPartialTranscript
    - testStartMeetingSetsErrorMessageWhenUnauthorized
    - testStartMeetingDoesNothingWhenAlreadyRecording
 
 2. stopMeeting() Tests (requires mocking AudioCaptureManager, SpeechTranscriber, SummaryEngine, PersistenceLayer):
    - testStopMeetingSetsIsRecordingToFalse
    - testStopMeetingGeneratesSummary
    - testStopMeetingSavesSummaryToPersistence
    - testStopMeetingDoesNothingWhenNotRecording
 
 3. loadPreviousSummaries() Tests (requires mocking PersistenceLayer):
    - testLoadPreviousSummariesReturnsSummaries
    - testLoadPreviousSummariesSetsErrorOnFailure
    - testLoadPreviousSummariesReturnsEmptyOnNoSummaries
 
 4. Transcription Flow Tests (requires mocking SpeechTranscriber stream):
    - testTranscriptionUpdatesPartialTranscript
    - testTranscriptionAppendsFinalSegment
    - testTranscriptionHandlesErrors
 
 5. Periodic Analysis Tests (requires mocking IntelligenceEngine):
    - testPeriodicAnalysisUpdatesInsights
    - testPeriodicAnalysisLimitsInsightsToTen
 
 To implement these tests, you would need to:
 1. Create protocols for AudioCaptureManager, SpeechTranscriber, TranscriptStore, IntelligenceEngine, SummaryEngine, and PersistenceLayer
 2. Inject these dependencies through an initializer
 3. Create mock implementations for testing
 
 Example protocol-based refactoring:
 
 protocol AudioCapturing {
     func startCapture() async throws
     func stopCapture() async
 }
 
 protocol SpeechTranscribing {
     func requestAuthorization() async -> Bool
     func startTranscription() async throws -> AsyncStream<(String, Bool)>
     func stopTranscription()
 }
 
 Then modify MeetingSessionController:
 
 @MainActor
 @Observable
 class MeetingSessionController {
     private let audioCaptureManager: AudioCapturing
     private let speechTranscriber: SpeechTranscribing
     // ... other dependencies
     
     init(
         audioCaptureManager: AudioCapturing = AudioCaptureManager(),
         speechTranscriber: SpeechTranscribing = SpeechTranscriber(),
         // ... other dependencies
     ) {
         self.audioCaptureManager = audioCaptureManager
         self.speechTranscriber = speechTranscriber
         // ...
     }
 }
 */
