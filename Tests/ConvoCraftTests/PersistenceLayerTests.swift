import XCTest
@testable import ConvoCraft

final class PersistenceLayerTests: XCTestCase {
    private var sut: PersistenceLayer!
    private var testDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = PersistenceLayer()
        testDirectory = await sut.getSummariesDirectory()
        try await cleanupTestDirectory()
    }
    
    override func tearDown() async throws {
        try await cleanupTestDirectory()
        sut = nil
        try await super.tearDown()
    }
    
    private func cleanupTestDirectory() async throws {
        let fileManager = FileManager.default
        let fileURLs = try fileManager.contentsOfDirectory(
            at: testDirectory,
            includingPropertiesForKeys: nil
        )
        for fileURL in fileURLs where fileURL.pathExtension == "json" {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    private func createSampleSummary(
        title: String = "Test Meeting",
        date: Date = Date(),
        duration: TimeInterval = 3600,
        summary: String = "Test summary",
        actionItems: [String] = ["Action 1", "Action 2"],
        keyDecisions: [String] = ["Decision 1"],
        transcript: [TranscriptSegment] = [],
        insights: [IntelligenceInsight] = []
    ) -> MeetingSummary {
        MeetingSummary(
            title: title,
            date: date,
            duration: duration,
            summary: summary,
            actionItems: actionItems,
            keyDecisions: keyDecisions,
            transcript: transcript,
            insights: insights
        )
    }
    
    func testGetSummariesDirectoryReturnsValidPath() async {
        let directory = await sut.getSummariesDirectory()
        
        XCTAssertEqual(directory.lastPathComponent, "MeetingSummaries")
        XCTAssertTrue(directory.path.contains("Documents"))
    }
    
    func testDirectoryExistsAfterInitialization() async {
        let directory = await sut.getSummariesDirectory()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }
    
    func testSaveSummaryCreatesFile() async throws {
        let summary = createSampleSummary(title: "Save Test")
        
        try await sut.saveSummary(summary)
        
        let directory = await sut.getSummariesDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].lastPathComponent.hasPrefix("meeting_"))
    }
    
    func testFileNamingConvention() async throws {
        let date = Date()
        let summary = createSampleSummary(date: date)
        
        try await sut.saveSummary(summary)
        
        let directory = await sut.getSummariesDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        XCTAssertEqual(files.count, 1)
        
        let filename = files[0].lastPathComponent
        XCTAssertTrue(filename.hasPrefix("meeting_"))
        XCTAssertTrue(filename.hasSuffix(".json"))
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let expectedDatePart = formatter.string(from: date)
        XCTAssertTrue(filename.contains(expectedDatePart), "Filename should contain formatted date")
    }
    
    func testLoadEmptyDirectoryReturnsEmptyArray() async throws {
        try await cleanupTestDirectory()
        
        let summaries = try await sut.loadAllSummaries()
        
        XCTAssertTrue(summaries.isEmpty)
    }
    
    func testLoadSummariesReturnsSavedSummary() async throws {
        let original = createSampleSummary(
            title: "Load Test",
            summary: "This is a test summary"
        )
        
        try await sut.saveSummary(original)
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, original.title)
        XCTAssertEqual(loaded[0].summary, original.summary)
    }
    
    func testRoundtripSaveAndLoadPreservesData() async throws {
        let transcript = [
            TranscriptSegment(text: "Hello world", timestamp: 0, isFinal: true),
            TranscriptSegment(text: "Second segment", timestamp: 5.0, isFinal: false)
        ]
        let insights = [
            IntelligenceInsight(type: .question, content: "What about X?"),
            IntelligenceInsight(type: .idea, content: "New feature idea"),
            IntelligenceInsight(type: .risk, content: "Timeline risk")
        ]
        
        let original = createSampleSummary(
            title: "Roundtrip Test",
            date: Date(timeIntervalSince1970: 1234567890),
            duration: 7200,
            summary: "Complex summary with special characters: émojis 🎉 and symbols @#$%",
            actionItems: ["Action 1", "Action 2", "Action with émoji 🚀"],
            keyDecisions: ["Decision A", "Decision B"],
            transcript: transcript,
            insights: insights
        )
        
        try await sut.saveSummary(original)
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 1)
        let loadedSummary = loaded[0]
        
        XCTAssertEqual(loadedSummary.title, original.title)
        XCTAssertEqual(loadedSummary.date.timeIntervalSince1970, original.date.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(loadedSummary.duration, original.duration)
        XCTAssertEqual(loadedSummary.summary, original.summary)
        XCTAssertEqual(loadedSummary.actionItems, original.actionItems)
        XCTAssertEqual(loadedSummary.keyDecisions, original.keyDecisions)
        XCTAssertEqual(loadedSummary.transcript.count, original.transcript.count)
        XCTAssertEqual(loadedSummary.insights.count, original.insights.count)
        
        for i in 0..<transcript.count {
            XCTAssertEqual(loadedSummary.transcript[i].text, transcript[i].text)
            XCTAssertEqual(loadedSummary.transcript[i].timestamp, transcript[i].timestamp)
            XCTAssertEqual(loadedSummary.transcript[i].isFinal, transcript[i].isFinal)
        }
        
        for i in 0..<insights.count {
            XCTAssertEqual(loadedSummary.insights[i].type, insights[i].type)
            XCTAssertEqual(loadedSummary.insights[i].content, insights[i].content)
        }
    }
    
    func testLoadMultipleSummariesSortedByDateDescending() async throws {
        let olderDate = Date().addingTimeInterval(-86400)
        let newerDate = Date().addingTimeInterval(86400)
        let newestDate = Date().addingTimeInterval(172800)
        
        let olderSummary = createSampleSummary(title: "Older", date: olderDate)
        let newerSummary = createSampleSummary(title: "Newer", date: newerDate)
        let newestSummary = createSampleSummary(title: "Newest", date: newestDate)
        
        try await sut.saveSummary(olderSummary)
        try await sut.saveSummary(newerSummary)
        try await sut.saveSummary(newestSummary)
        
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].title, "Newest")
        XCTAssertEqual(loaded[1].title, "Newer")
        XCTAssertEqual(loaded[2].title, "Older")
        
        XCTAssertTrue(loaded[0].date > loaded[1].date)
        XCTAssertTrue(loaded[1].date > loaded[2].date)
    }
    
    func testHandlesCorruptedFilesGracefully() async throws {
        let validSummary = createSampleSummary(title: "Valid Summary")
        try await sut.saveSummary(validSummary)
        
        let directory = await sut.getSummariesDirectory()
        let corruptedFile = directory.appendingPathComponent("meeting_corrupted.json")
        try "invalid json content".write(to: corruptedFile, atomically: true, encoding: .utf8)
        
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Valid Summary")
        
        try? FileManager.default.removeItem(at: corruptedFile)
    }
    
    func testSavesWithISO8601DateFormat() async throws {
        let summary = createSampleSummary(date: Date())
        try await sut.saveSummary(summary)
        
        let directory = await sut.getSummariesDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        guard let fileURL = files.first else {
            XCTFail("No file found")
            return
        }
        
        let data = try Data(contentsOf: fileURL)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"date\" : \""))
    }
    
    func testSavesWithPrettyPrinting() async throws {
        let summary = createSampleSummary()
        try await sut.saveSummary(summary)
        
        let directory = await sut.getSummariesDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        guard let fileURL = files.first else {
            XCTFail("No file found")
            return
        }
        
        let data = try Data(contentsOf: fileURL)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\n"))
        XCTAssertTrue(jsonString!.contains("  "))
    }
    
    func testDataIntegrityWithAllFields() async throws {
        let fullSummary = MeetingSummary(
            title: "Full Integration Test",
            date: Date(),
            duration: 5400,
            summary: "A comprehensive meeting covering Q4 roadmap",
            actionItems: [
                "Follow up with marketing team",
                "Schedule architecture review",
                "Update project timeline"
            ],
            keyDecisions: [
                "Approved budget increase",
                "Selected vendor A over vendor B"
            ],
            transcript: [
                TranscriptSegment(text: "Let's start the meeting", timestamp: 0.0, isFinal: true),
                TranscriptSegment(text: "First agenda item", timestamp: 30.0, isFinal: true),
                TranscriptSegment(text: "Discussion continued", timestamp: 60.0, isFinal: false)
            ],
            insights: [
                IntelligenceInsight(type: .question, content: "Should we pivot?", timestamp: 100.0),
                IntelligenceInsight(type: .idea, content: "Automate testing pipeline", timestamp: 200.0),
                IntelligenceInsight(type: .risk, content: "Resource constraints in Q1", timestamp: 300.0)
            ]
        )
        
        try await sut.saveSummary(fullSummary)
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 1)
        let result = loaded[0]
        
        XCTAssertEqual(result.title, fullSummary.title)
        XCTAssertEqual(result.duration, fullSummary.duration)
        XCTAssertEqual(result.summary, fullSummary.summary)
        XCTAssertEqual(result.actionItems, fullSummary.actionItems)
        XCTAssertEqual(result.keyDecisions, fullSummary.keyDecisions)
        XCTAssertEqual(result.transcript.count, 3)
        XCTAssertEqual(result.insights.count, 3)
    }
    
    func testMultipleSavesCreateMultipleFiles() async throws {
        for i in 1...5 {
            let summary = createSampleSummary(
                title: "Meeting \(i)",
                date: Date().addingTimeInterval(TimeInterval(i * 60))
            )
            try await sut.saveSummary(summary)
        }
        
        let directory = await sut.getSummariesDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        XCTAssertEqual(files.count, 5)
    }
    
    func testSummaryWithEmptyCollections() async throws {
        let emptySummary = MeetingSummary(
            title: "Empty Collections",
            date: Date(),
            duration: 0,
            summary: "",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        try await sut.saveSummary(emptySummary)
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertTrue(loaded[0].actionItems.isEmpty)
        XCTAssertTrue(loaded[0].keyDecisions.isEmpty)
        XCTAssertTrue(loaded[0].transcript.isEmpty)
        XCTAssertTrue(loaded[0].insights.isEmpty)
    }
    
    func testSummaryIdReturnsDate() async throws {
        let date = Date(timeIntervalSince1970: 1609459200)
        let summary = createSampleSummary(date: date)
        
        XCTAssertEqual(summary.id.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }
    
    func testConcurrentAccessToPersistenceLayer() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                let title = "Concurrent \(i)"
                let date = Date().addingTimeInterval(TimeInterval(i))
                group.addTask { [sut] in
                    let summary = MeetingSummary(
                        title: title,
                        date: date,
                        duration: 3600,
                        summary: "Test",
                        actionItems: [],
                        keyDecisions: [],
                        transcript: [],
                        insights: []
                    )
                    try await sut.saveSummary(summary)
                }
            }
        }
        
        let loaded = try await sut.loadAllSummaries()
        XCTAssertGreaterThanOrEqual(loaded.count, 1)
    }
}