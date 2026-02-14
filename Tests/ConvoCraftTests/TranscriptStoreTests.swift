import XCTest
@testable import ConvoCraft

final class TranscriptStoreTests: XCTestCase {
    
    var store: TranscriptStore!
    
    override func setUp() {
        super.setUp()
        store = TranscriptStore()
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    // MARK: - Partial Segment Tests
    
    func testAddPartialSegment() async {
        let segment = TranscriptSegment(
            text: "Hello world",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addPartialSegment(segment)
        
        let partial = await store.getPartialSegment()
        XCTAssertEqual(partial?.id, segment.id)
        XCTAssertEqual(partial?.text, segment.text)
        XCTAssertEqual(partial?.timestamp, segment.timestamp)
        XCTAssertEqual(partial?.isFinal, false)
    }
    
    func testAddPartialSegmentReplacesExisting() async {
        let firstSegment = TranscriptSegment(
            text: "First",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        let secondSegment = TranscriptSegment(
            text: "Second",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addPartialSegment(firstSegment)
        await store.addPartialSegment(secondSegment)
        
        let partial = await store.getPartialSegment()
        XCTAssertEqual(partial?.id, secondSegment.id)
        XCTAssertEqual(partial?.text, "Second")
    }
    
    func testGetPartialSegmentWhenEmpty() async {
        let partial = await store.getPartialSegment()
        XCTAssertNil(partial)
    }
    
    // MARK: - Finalize Tests
    
    func testFinalizeCurrent() async {
        let segment = TranscriptSegment(
            text: "Test message",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addPartialSegment(segment)
        await store.finalizeCurrent()
        
        let allSegments = await store.getAllSegments()
        XCTAssertEqual(allSegments.count, 1)
        XCTAssertEqual(allSegments.first?.id, segment.id)
        XCTAssertEqual(allSegments.first?.text, segment.text)
        XCTAssertEqual(allSegments.first?.isFinal, true)
        
        let partial = await store.getPartialSegment()
        XCTAssertNil(partial)
    }
    
    func testFinalizeCurrentWhenNoPartialSegment() async {
        await store.finalizeCurrent()
        
        let allSegments = await store.getAllSegments()
        XCTAssertTrue(allSegments.isEmpty)
    }
    
    func testFinalizeMultipleSegments() async {
        let segment1 = TranscriptSegment(
            text: "First message",
            timestamp: Date().timeIntervalSince1970 - 120,
            isFinal: false
        )
        let segment2 = TranscriptSegment(
            text: "Second message",
            timestamp: Date().timeIntervalSince1970 - 60,
            isFinal: false
        )
        let segment3 = TranscriptSegment(
            text: "Third message",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addPartialSegment(segment1)
        await store.finalizeCurrent()
        
        await store.addPartialSegment(segment2)
        await store.finalizeCurrent()
        
        await store.addPartialSegment(segment3)
        await store.finalizeCurrent()
        
        let allSegments = await store.getAllSegments()
        XCTAssertEqual(allSegments.count, 3)
        XCTAssertTrue(allSegments.allSatisfy { $0.isFinal })
    }
    
    // MARK: - Add Final Segment Tests
    
    func testAddFinalSegment() async {
        let segment = TranscriptSegment(
            text: "Final message",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addFinalSegment(segment)
        
        let allSegments = await store.getAllSegments()
        XCTAssertEqual(allSegments.count, 1)
        XCTAssertEqual(allSegments.first?.id, segment.id)
        XCTAssertEqual(allSegments.first?.text, segment.text)
        XCTAssertEqual(allSegments.first?.isFinal, true)
    }
    
    func testAddFinalSegmentForcesIsFinalTrue() async {
        let segment = TranscriptSegment(
            text: "Should be final",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addFinalSegment(segment)
        
        let allSegments = await store.getAllSegments()
        XCTAssertEqual(allSegments.first?.isFinal, true)
    }
    
    func testAddMultipleFinalSegments() async {
        for i in 1...5 {
            let segment = TranscriptSegment(
                text: "Message \(i)",
                timestamp: Date().timeIntervalSince1970 + TimeInterval(i * 60),
                isFinal: true
            )
            await store.addFinalSegment(segment)
        }
        
        let allSegments = await store.getAllSegments()
        XCTAssertEqual(allSegments.count, 5)
    }
    
    // MARK: - Get Recent Transcript Tests
    
    func testGetRecentTranscriptDefaultFiveMinutes() async {
        let now = Date().timeIntervalSince1970
        
        let recentSegment = TranscriptSegment(
            text: "Recent",
            timestamp: now - 60,
            isFinal: true
        )
        let oldSegment = TranscriptSegment(
            text: "Old",
            timestamp: now - 400,
            isFinal: true
        )
        
        await store.addFinalSegment(recentSegment)
        await store.addFinalSegment(oldSegment)
        
        let recent = await store.getRecentTranscript()
        
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.text, "Recent")
    }
    
    func testGetRecentTranscriptCustomTimeWindow() async {
        let now = Date().timeIntervalSince1970
        
        let veryRecent = TranscriptSegment(
            text: "Very recent",
            timestamp: now - 30,
            isFinal: true
        )
        let somewhatRecent = TranscriptSegment(
            text: "Somewhat recent",
            timestamp: now - 90,
            isFinal: true
        )
        let old = TranscriptSegment(
            text: "Old",
            timestamp: now - 200,
            isFinal: true
        )
        
        await store.addFinalSegment(veryRecent)
        await store.addFinalSegment(somewhatRecent)
        await store.addFinalSegment(old)
        
        let recent = await store.getRecentTranscript(lastMinutes: 2.0)
        
        XCTAssertEqual(recent.count, 2)
        let texts = recent.map { $0.text }
        XCTAssertTrue(texts.contains("Very recent"))
        XCTAssertTrue(texts.contains("Somewhat recent"))
    }
    
    func testGetRecentTranscriptAllWithinWindow() async {
        let now = Date().timeIntervalSince1970
        
        for i in 0..<3 {
            let segment = TranscriptSegment(
                text: "Message \(i)",
                timestamp: now - TimeInterval(i * 30),
                isFinal: true
            )
            await store.addFinalSegment(segment)
        }
        
        let recent = await store.getRecentTranscript(lastMinutes: 5.0)
        
        XCTAssertEqual(recent.count, 3)
    }
    
    func testGetRecentTranscriptNoneWithinWindow() async {
        let now = Date().timeIntervalSince1970
        
        let oldSegment = TranscriptSegment(
            text: "Old message",
            timestamp: now - 600,
            isFinal: true
        )
        
        await store.addFinalSegment(oldSegment)
        
        let recent = await store.getRecentTranscript(lastMinutes: 5.0)
        
        XCTAssertTrue(recent.isEmpty)
    }
    
    func testGetRecentTranscriptEmptyStore() async {
        let recent = await store.getRecentTranscript()
        XCTAssertTrue(recent.isEmpty)
    }
    
    func testGetRecentTranscriptBoundaryCondition() async {
        let now = Date().timeIntervalSince1970
        let windowMinutes: TimeInterval = 2.0
        let cutoffTime = now - (windowMinutes * 60)
        
        let boundarySegment = TranscriptSegment(
            text: "Boundary",
            timestamp: cutoffTime,
            isFinal: true
        )
        let justBeforeBoundary = TranscriptSegment(
            text: "Before boundary",
            timestamp: cutoffTime - 0.001,
            isFinal: true
        )
        
        await store.addFinalSegment(boundarySegment)
        await store.addFinalSegment(justBeforeBoundary)
        
        let recent = await store.getRecentTranscript(lastMinutes: windowMinutes)
        
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.text, "Boundary")
    }
    
    // MARK: - Get All Segments Tests
    
    func testGetAllSegmentsEmpty() async {
        let segments = await store.getAllSegments()
        XCTAssertTrue(segments.isEmpty)
    }
    
    func testGetAllSegmentsReturnsCopy() async {
        let segment = TranscriptSegment(
            text: "Test",
            timestamp: Date().timeIntervalSince1970,
            isFinal: true
        )
        
        await store.addFinalSegment(segment)
        
        var segments = await store.getAllSegments()
        segments.removeAll()
        
        let segmentsAgain = await store.getAllSegments()
        XCTAssertEqual(segmentsAgain.count, 1)
    }
    
    func testGetAllSegmentsPreservesOrder() async {
        let baseTime = Date().timeIntervalSince1970
        
        for i in 1...5 {
            let segment = TranscriptSegment(
                text: "Message \(i)",
                timestamp: baseTime + TimeInterval(i),
                isFinal: true
            )
            await store.addFinalSegment(segment)
        }
        
        let segments = await store.getAllSegments()
        
        for (index, segment) in segments.enumerated() {
            XCTAssertEqual(segment.text, "Message \(index + 1)")
        }
    }
    
    // MARK: - Clear Tests
    
    func testClearRemovesAllSegments() async {
        for i in 1...3 {
            let segment = TranscriptSegment(
                text: "Message \(i)",
                timestamp: Date().timeIntervalSince1970,
                isFinal: true
            )
            await store.addFinalSegment(segment)
        }
        
        await store.clear()
        
        let segments = await store.getAllSegments()
        XCTAssertTrue(segments.isEmpty)
    }
    
    func testClearRemovesPartialSegment() async {
        let segment = TranscriptSegment(
            text: "Partial",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addPartialSegment(segment)
        await store.clear()
        
        let partial = await store.getPartialSegment()
        XCTAssertNil(partial)
    }
    
    func testClearBothSegmentsAndPartial() async {
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
        
        await store.addFinalSegment(finalSegment)
        await store.addPartialSegment(partialSegment)
        await store.clear()
        
        let segments = await store.getAllSegments()
        let partial = await store.getPartialSegment()
        
        XCTAssertTrue(segments.isEmpty)
        XCTAssertNil(partial)
    }
    
    func testClearEmptyStore() async {
        await store.clear()
        
        let segments = await store.getAllSegments()
        let partial = await store.getPartialSegment()
        
        XCTAssertTrue(segments.isEmpty)
        XCTAssertNil(partial)
    }
    
    // MARK: - Edge Cases
    
    func testMixedOperations() async {
        let now = Date().timeIntervalSince1970
        
        let partial1 = TranscriptSegment(
            text: "Partial 1",
            timestamp: now - 300,
            isFinal: false
        )
        await store.addPartialSegment(partial1)
        await store.finalizeCurrent()
        
        let final1 = TranscriptSegment(
            text: "Final 1",
            timestamp: now - 240,
            isFinal: true
        )
        await store.addFinalSegment(final1)
        
        let partial2 = TranscriptSegment(
            text: "Partial 2",
            timestamp: now - 180,
            isFinal: false
        )
        await store.addPartialSegment(partial2)
        
        let final2 = TranscriptSegment(
            text: "Final 2",
            timestamp: now - 120,
            isFinal: true
        )
        await store.addFinalSegment(final2)
        
        await store.finalizeCurrent()
        
        let allSegments = await store.getAllSegments()
        let partial = await store.getPartialSegment()
        
        XCTAssertEqual(allSegments.count, 4)
        XCTAssertNil(partial)
    }
    
    func testTimestampEdgeCase() async {
        let zeroTimestamp = TranscriptSegment(
            text: "Zero timestamp",
            timestamp: 0,
            isFinal: true
        )
        
        await store.addFinalSegment(zeroTimestamp)
        
        let recent = await store.getRecentTranscript(lastMinutes: 1.0)
        XCTAssertTrue(recent.isEmpty)
        
        let all = await store.getAllSegments()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.timestamp, 0)
    }
    
    func testFutureTimestamp() async {
        let futureTimestamp = TranscriptSegment(
            text: "Future message",
            timestamp: Date().timeIntervalSince1970 + 3600,
            isFinal: true
        )
        
        await store.addFinalSegment(futureTimestamp)
        
        let recent = await store.getRecentTranscript(lastMinutes: 60.0)
        XCTAssertEqual(recent.count, 1)
    }
    
    func testLargeNumberOfSegments() async {
        let baseTime = Date().timeIntervalSince1970
        let count = 1000
        
        for i in 0..<count {
            let segment = TranscriptSegment(
                text: "Message \(i)",
                timestamp: baseTime - TimeInterval(count - i),
                isFinal: true
            )
            await store.addFinalSegment(segment)
        }
        
        let allSegments = await store.getAllSegments()
        XCTAssertEqual(allSegments.count, count)
        
        let recent = await store.getRecentTranscript(lastMinutes: 1.0)
        XCTAssertGreaterThan(recent.count, 0)
    }
    
    func testEmptyTextSegment() async {
        let emptyText = TranscriptSegment(
            text: "",
            timestamp: Date().timeIntervalSince1970,
            isFinal: true
        )
        
        await store.addFinalSegment(emptyText)
        
        let segments = await store.getAllSegments()
        XCTAssertEqual(segments.first?.text, "")
    }
    
    func testUnicodeText() async {
        let unicodeSegment = TranscriptSegment(
            text: "Hello 世界 🌍 مرحبا",
            timestamp: Date().timeIntervalSince1970,
            isFinal: true
        )
        
        await store.addFinalSegment(unicodeSegment)
        
        let segments = await store.getAllSegments()
        XCTAssertEqual(segments.first?.text, "Hello 世界 🌍 مرحبا")
    }
    
    func testSegmentIDPreservation() async {
        let specificID = UUID()
        let segment = TranscriptSegment(
            id: specificID,
            text: "Test",
            timestamp: Date().timeIntervalSince1970,
            isFinal: false
        )
        
        await store.addPartialSegment(segment)
        await store.finalizeCurrent()
        
        let segments = await store.getAllSegments()
        XCTAssertEqual(segments.first?.id, specificID)
    }
    
    func testConcurrentAccess() async {
        let testStore = TranscriptStore()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let segment = TranscriptSegment(
                        text: "Concurrent \(i)",
                        timestamp: Date().timeIntervalSince1970,
                        isFinal: true
                    )
                    await testStore.addFinalSegment(segment)
                }
            }
            
            for _ in 100..<200 {
                group.addTask {
                    let segment = TranscriptSegment(
                        text: "Partial",
                        timestamp: Date().timeIntervalSince1970,
                        isFinal: false
                    )
                    await testStore.addPartialSegment(segment)
                }
            }
            
            for _ in 200..<210 {
                group.addTask {
                    _ = await testStore.getAllSegments()
                }
            }
        }
        
        let segments = await testStore.getAllSegments()
        XCTAssertGreaterThanOrEqual(segments.count, 100)
    }
}