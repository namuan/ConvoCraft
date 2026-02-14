# ConvoCraft Testing Strategy Roadmap

## Executive Summary

**Project Type:** Swift 6.2 macOS Application (macOS 14+)
**Current State:** Zero testing infrastructure
**Target State:** Comprehensive test coverage with CI/CD integration
**Estimated Timeline:** 8-10 weeks

---

## Part 1: Current State Assessment

### 1.1 Codebase Architecture

| Layer | Components | Lines of Code |
|-------|------------|---------------|
| **Models** | `TranscriptSegment`, `IntelligenceInsight`, `MeetingSummary` | ~80 |
| **Actors** | `TranscriptStore`, `IntelligenceEngine` | ~160 |
| **Services** | `SummaryEngine`, `PersistenceLayer`, `MeetingSessionController`, `SpeechTranscriber`, `AudioCaptureManager` | ~450 |
| **Views** | `ContentView` (6 view structs) | ~350 |

### 1.2 Testing Gaps

| Gap | Severity | Description |
|-----|----------|-------------|
| No test targets | **Critical** | Package.swift has no test target |
| No test files | **Critical** | Zero test coverage |
| No CI/CD | **High** | No automated quality gates |
| No mocking infrastructure | **High** | No way to test in isolation |
| No performance benchmarks | **Medium** | Unknown performance characteristics |

### 1.3 Test Priority Matrix

| Component | Testability | Business Value | Priority |
|-----------|-------------|----------------|----------|
| `SummaryEngine` | High (pure logic) | High | **P0** |
| `IntelligenceEngine` | High (NLP patterns) | High | **P0** |
| `TranscriptStore` | High (actor state) | Medium | **P1** |
| `PersistenceLayer` | Medium (file I/O) | High | **P1** |
| `MeetingSessionController` | Medium (coordination) | High | **P2** |
| `SpeechTranscriber` | Low (device-dependent) | Medium | **P3** |
| `AudioCaptureManager` | Low (system APIs) | Low | **P4** |
| SwiftUI Views | Low (UI testing) | Low | **P4** |

---

## Part 2: Testing Infrastructure Setup

### Phase 1: Foundation (Week 1-2)

#### 1.1 Add XCTest Target to Package.swift

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ConvoCraft",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ConvoCraft",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        // NEW: Test target
        .testTarget(
            name: "ConvoCraftTests",
            dependencies: ["ConvoCraft"]
        ),
    ]
)
```

#### 1.2 Create Test Directory Structure

```
Tests/
└── ConvoCraftTests/
    ├── TestHelpers/
    │   ├── MockTranscriptSegment.swift
    │   ├── TestDataFactory.swift
    │   └── TempDirectory.swift
    ├── UnitTests/
    │   ├── SummaryEngineTests.swift
    │   ├── IntelligenceEngineTests.swift
    │   ├── TranscriptStoreTests.swift
    │   └── PersistenceLayerTests.swift
    ├── IntegrationTests/
    │   └── EndToEndTests.swift
    └── PerformanceTests/
        └── SummaryPerformanceTests.swift
```

#### 1.3 Initial Test Configuration

```swift
// Tests/ConvoCraftTests/TestHelpers/TestDataFactory.swift

import Foundation
@testable import ConvoCraft

enum TestDataFactory {
    static func makeTranscriptSegment(
        id: UUID = UUID(),
        text: String = "Test transcript segment",
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        isFinal: Bool = true
    ) -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            text: text,
            timestamp: timestamp,
            isFinal: isFinal
        )
    }
    
    static func makeTranscriptSegments(_ texts: [String]) -> [TranscriptSegment] {
        var timestamp = Date().timeIntervalSince1970
        return texts.map { text in
            defer { timestamp += 5.0 }
            return makeTranscriptSegment(text: text, timestamp: timestamp)
        }
    }
    
    static func makeIntelligenceInsight(
        type: InsightType = .idea,
        content: String = "Test insight"
    ) -> IntelligenceInsight {
        IntelligenceInsight(type: type, content: content)
    }
}
```

---

### Phase 2: Unit Testing (Week 2-4)

#### 2.1 SummaryEngine Tests

**Test Categories:**
- Sentence tokenization accuracy
- Action item extraction
- Key decision extraction
- Empty/edge case handling
- Summary generation

```swift
// Tests/ConvoCraftTests/UnitTests/SummaryEngineTests.swift

import XCTest
@testable import ConvoCraft

final class SummaryEngineTests: XCTestCase {
    var sut: SummaryEngine!  // System Under Test
    
    override func setUp() {
        sut = SummaryEngine()
    }
    
    // MARK: - Sentence Splitting Tests
    
    func testSplitIntoSentences_basicSentences() async {
        // Test via public API indirectly
        let segments = TestDataFactory.makeTranscriptSegments([
            "We need to complete the project. The deadline is next week.",
            "I will send the report by Friday."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertFalse(summary.summary.isEmpty)
        XCTAssertTrue(summary.summary.contains("We need to complete"))
    }
    
    func testSplitIntoSentences_withQuestionMarks() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "What is the timeline? We should decide today."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertNotNil(summary)
    }
    
    // MARK: - Action Item Extraction Tests
    
    func testExtractActionItems_detectsNeedTo() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We need to finish the report by Friday.",
            "This is just a regular statement."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertEqual(summary.actionItems.count, 1)
        XCTAssertTrue(summary.actionItems[0].contains("need to"))
    }
    
    func testExtractActionItems_detectsShould() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We should review the proposal tomorrow."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertEqual(summary.actionItems.count, 1)
    }
    
    func testExtractActionItems_detectsMultipleActions() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We need to send the email.",
            "I will do the research.",
            "We should schedule a follow-up.",
            "The action item is to review the docs.",
            "I must remember to call the client."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertGreaterThanOrEqual(summary.actionItems.count, 3)
    }
    
    func testExtractActionItems_limitsToFive() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We need to do task one.",
            "We need to do task two.",
            "We need to do task three.",
            "We need to do task four.",
            "We need to do task five.",
            "We need to do task six.",
            "We need to do task seven."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertLessThanOrEqual(summary.actionItems.count, 5)
    }
    
    func testExtractActionItems_noActions() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "The weather is nice today.",
            "I like coffee."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertEqual(summary.actionItems.count, 0)
    }
    
    // MARK: - Key Decision Extraction Tests
    
    func testExtractKeyDecisions_detectsDecided() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We decided to go with option A."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
    }
    
    func testExtractKeyDecisions_detectsAgreed() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We agreed on the timeline."
        ])
        
        let summary = await sut.generateSummary(from: segments, insights: [], duration: 60)
        
        XCTAssertEqual(summary.keyDecisions.count, 1)
    }
    
    // MARK: - Edge Case Tests
    
    func testGenerateSummary_emptySegments() async {
        let summary = await sut.generateSummary(from: [], insights: [], duration: 0)
        
        XCTAssertEqual(summary.summary, "No transcript available.")
        XCTAssertEqual(summary.actionItems.count, 0)
        XCTAssertEqual(summary.keyDecisions.count, 0)
    }
    
    func testGenerateSummary_preservesInsights() async {
        let segments = TestDataFactory.makeTranscriptSegments(["Test"])
        let insights = [
            TestDataFactory.makeIntelligenceInsight(type: .risk, content: "Test risk")
        ]
        
        let summary = await sut.generateSummary(from: segments, insights: insights, duration: 60)
        
        XCTAssertEqual(summary.insights.count, 1)
    }
}
```

#### 2.2 IntelligenceEngine Tests

```swift
// Tests/ConvoCraftTests/UnitTests/IntelligenceEngineTests.swift

import XCTest
@testable import ConvoCraft

final class IntelligenceEngineTests: XCTestCase {
    var sut: IntelligenceEngine!
    
    override func setUp() {
        sut = IntelligenceEngine()
    }
    
    override func tearDown() async {
        await sut.clearInsights()
    }
    
    // MARK: - Uncertainty Detection Tests
    
    func testDetectUncertainty_maybePhrase() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "Maybe we should consider that option."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertTrue(insights.contains { $0.content.contains("uncertainty") })
    }
    
    func testDetectUncertainty_notSurePhrase() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "I'm not sure about this approach."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertTrue(insights.contains { $0.type == .question })
    }
    
    // MARK: - Commitment Detection Tests
    
    func testDetectCommitment_weShould() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We should implement this feature."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertTrue(insights.contains { $0.content.contains("commitment") })
    }
    
    func testDetectCommitment_willDo() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "I will do that tomorrow."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertTrue(insights.contains { $0.type == .idea })
    }
    
    // MARK: - Risk Detection Tests
    
    func testDetectRisk_riskPhrase() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "There is a risk that we might miss the deadline."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertTrue(insights.contains { $0.type == .risk })
    }
    
    func testDetectRisk_blockerPhrase() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "We have a blocker on the API integration."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertTrue(insights.contains { $0.type == .risk })
    }
    
    // MARK: - Timeline Detection Tests
    
    func testDetectTimeline_deadlinePhrase() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "The deadline is next Friday."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertTrue(insights.contains { $0.content.contains("Timeline") })
    }
    
    // MARK: - Insight Accumulation Tests
    
    func testInsightsAccumulate() async {
        _ = await sut.analyzeTranscript(
            TestDataFactory.makeTranscriptSegments(["We need to do this."])
        )
        _ = await sut.analyzeTranscript(
            TestDataFactory.makeTranscriptSegments(["There is a risk."])
        )
        
        let allInsights = await sut.getAllInsights()
        
        XCTAssertGreaterThanOrEqual(allInsights.count, 2)
    }
    
    func testClearInsights() async {
        _ = await sut.analyzeTranscript(
            TestDataFactory.makeTranscriptSegments(["We need to do this."])
        )
        
        await sut.clearInsights()
        
        let allInsights = await sut.getAllInsights()
        XCTAssertEqual(allInsights.count, 0)
    }
    
    // MARK: - Limit Tests
    
    func testInsightsLimitedToThree() async {
        let segments = TestDataFactory.makeTranscriptSegments([
            "Maybe we should try this.",
            "There is a risk.",
            "The deadline is tomorrow.",
            "We need to finish.",
            "I'm not sure about this."
        ])
        
        let insights = await sut.analyzeTranscript(segments)
        
        XCTAssertLessThanOrEqual(insights.count, 3)
    }
}
```

#### 2.3 TranscriptStore Tests

```swift
// Tests/ConvoCraftTests/UnitTests/TranscriptStoreTests.swift

import XCTest
@testable import ConvoCraft

final class TranscriptStoreTests: XCTestCase {
    var sut: TranscriptStore!
    
    override func setUp() {
        sut = TranscriptStore()
    }
    
    override func tearDown() async {
        await sut.clear()
    }
    
    // MARK: - Partial Segment Tests
    
    func testAddPartialSegment() async {
        let segment = TestDataFactory.makeTranscriptSegment(isFinal: false)
        
        await sut.addPartialSegment(segment)
        let partial = await sut.getPartialSegment()
        
        XCTAssertNotNil(partial)
        XCTAssertEqual(partial?.id, segment.id)
    }
    
    func testPartialSegmentOverwrites() async {
        let segment1 = TestDataFactory.makeTranscriptSegment(text: "First")
        let segment2 = TestDataFactory.makeTranscriptSegment(text: "Second")
        
        await sut.addPartialSegment(segment1)
        await sut.addPartialSegment(segment2)
        let partial = await sut.getPartialSegment()
        
        XCTAssertEqual(partial?.text, "Second")
    }
    
    // MARK: - Final Segment Tests
    
    func testFinalizeCurrent() async {
        let segment = TestDataFactory.makeTranscriptSegment(text: "Test")
        await sut.addPartialSegment(segment)
        
        await sut.finalizeCurrent()
        
        let allSegments = await sut.getAllSegments()
        XCTAssertEqual(allSegments.count, 1)
        XCTAssertTrue(allSegments[0].isFinal)
        
        let partial = await sut.getPartialSegment()
        XCTAssertNil(partial)
    }
    
    func testAddFinalSegment() async {
        let segment = TestDataFactory.makeTranscriptSegment(text: "Final test")
        
        await sut.addFinalSegment(segment)
        
        let allSegments = await sut.getAllSegments()
        XCTAssertEqual(allSegments.count, 1)
        XCTAssertTrue(allSegments[0].isFinal)
    }
    
    func testAddMultipleFinalSegments() async {
        for i in 0..<5 {
            let segment = TestDataFactory.makeTranscriptSegment(text: "Segment \(i)")
            await sut.addFinalSegment(segment)
        }
        
        let allSegments = await sut.getAllSegments()
        XCTAssertEqual(allSegments.count, 5)
    }
    
    // MARK: - Recent Transcript Tests
    
    func testGetRecentTranscript_filtersByTime() async {
        let now = Date().timeIntervalSince1970
        
        // Old segment (10 minutes ago)
        let oldSegment = TestDataFactory.makeTranscriptSegment(
            text: "Old",
            timestamp: now - 600
        )
        await sut.addFinalSegment(oldSegment)
        
        // Recent segment (1 minute ago)
        let recentSegment = TestDataFactory.makeTranscriptSegment(
            text: "Recent",
            timestamp: now - 60
        )
        await sut.addFinalSegment(recentSegment)
        
        let recent = await sut.getRecentTranscript(lastMinutes: 5.0)
        
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].text, "Recent")
    }
    
    // MARK: - Clear Tests
    
    func testClear() async {
        await sut.addFinalSegment(TestDataFactory.makeTranscriptSegment())
        await sut.addPartialSegment(TestDataFactory.makeTranscriptSegment(isFinal: false))
        
        await sut.clear()
        
        let allSegments = await sut.getAllSegments()
        let partial = await sut.getPartialSegment()
        
        XCTAssertEqual(allSegments.count, 0)
        XCTAssertNil(partial)
    }
}
```

#### 2.4 PersistenceLayer Tests

```swift
// Tests/ConvoCraftTests/UnitTests/PersistenceLayerTests.swift

import XCTest
@testable import ConvoCraft

final class PersistenceLayerTests: XCTestCase {
    var sut: PersistenceLayer!
    var tempDirectory: URL!
    
    override func setUp() {
        // Use temp directory for isolated testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        sut = PersistenceLayer(testDirectory: tempDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    // MARK: - Save Tests
    
    func testSaveSummary_createsFile() async throws {
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
        
        try await sut.saveSummary(summary)
        
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].pathExtension == "json")
    }
    
    func testSaveSummary_createsCorrectFilename() async throws {
        let date = Date()
        let summary = MeetingSummary(
            title: "Test",
            date: date,
            duration: 60,
            summary: "Summary",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        try await sut.saveSummary(summary)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let expectedPrefix = "meeting_\(formatter.string(from: date))"
        
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertTrue(files[0].lastPathComponent.hasPrefix(expectedPrefix))
    }
    
    // MARK: - Load Tests
    
    func testLoadAllSummaries_emptyDirectory() async throws {
        let summaries = try await sut.loadAllSummaries()
        
        XCTAssertEqual(summaries.count, 0)
    }
    
    func testLoadAllSummaries_singleFile() async throws {
        let summary = MeetingSummary(
            title: "Test Meeting",
            date: Date(),
            duration: 120,
            summary: "Summary text",
            actionItems: ["Item 1"],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        try await sut.saveSummary(summary)
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Test Meeting")
        XCTAssertEqual(loaded[0].actionItems, ["Item 1"])
    }
    
    func testLoadAllSummaries_multipleFiles_sortedByDate() async throws {
        let older = MeetingSummary(
            title: "Older",
            date: Date().addingTimeInterval(-86400), // 1 day ago
            duration: 60,
            summary: "Older",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        let newer = MeetingSummary(
            title: "Newer",
            date: Date(),
            duration: 60,
            summary: "Newer",
            actionItems: [],
            keyDecisions: [],
            transcript: [],
            insights: []
        )
        
        try await sut.saveSummary(older)
        try await sut.saveSummary(newer)
        
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].title, "Newer") // Most recent first
        XCTAssertEqual(loaded[1].title, "Older")
    }
    
    func testLoadAllSummaries_handlesInvalidJSON() async throws {
        // Create invalid JSON file
        let invalidURL = tempDirectory.appendingPathComponent("meeting_invalid.json")
        try "invalid json".write(to: invalidURL, atomically: true, encoding: .utf8)
        
        // Should not throw, just skip invalid file
        let summaries = try await sut.loadAllSummaries()
        
        XCTAssertEqual(summaries.count, 0)
    }
    
    // MARK: - Round-trip Tests
    
    func testSaveAndLoad_preservesAllFields() async throws {
        let segments = [
            TranscriptSegment(id: UUID(), text: "Hello", timestamp: 100, isFinal: true)
        ]
        let insights = [
            IntelligenceInsight(type: .risk, content: "Risk detected")
        ]
        
        let original = MeetingSummary(
            title: "Complete Test",
            date: Date(),
            duration: 300,
            summary: "Full summary",
            actionItems: ["Action 1", "Action 2"],
            keyDecisions: ["Decision 1"],
            transcript: segments,
            insights: insights
        )
        
        try await sut.saveSummary(original)
        let loaded = try await sut.loadAllSummaries()
        
        XCTAssertEqual(loaded[0].title, original.title)
        XCTAssertEqual(loaded[0].duration, original.duration)
        XCTAssertEqual(loaded[0].summary, original.summary)
        XCTAssertEqual(loaded[0].actionItems, original.actionItems)
        XCTAssertEqual(loaded[0].keyDecisions, original.keyDecisions)
        XCTAssertEqual(loaded[0].transcript.count, 1)
        XCTAssertEqual(loaded[0].insights.count, 1)
    }
}
```

---

### Phase 3: Integration Testing (Week 4-6)

#### 3.1 Workflow Integration Tests

```swift
// Tests/ConvoCraftTests/IntegrationTests/EndToEndTests.swift

import XCTest
@testable import ConvoCraft

final class EndToEndTests: XCTestCase {
    
    /// Test complete meeting workflow:
    /// 1. Store transcript segments
    /// 2. Analyze for insights
    /// 3. Generate summary
    /// 4. Persist to disk
    func testCompleteMeetingWorkflow() async throws {
        // Setup
        let store = TranscriptStore()
        let engine = IntelligenceEngine()
        let summaryEngine = SummaryEngine()
        let persistence = PersistenceLayer(testDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
        
        // 1. Add transcript segments
        let segments = TestDataFactory.makeTranscriptSegments([
            "Welcome to the project kickoff meeting.",
            "We need to deliver the MVP by March.",
            "There is a risk that we might not have enough resources.",
            "We decided to use Swift for the backend.",
            "John will do the initial research by Friday."
        ])
        
        for segment in segments {
            await store.addFinalSegment(segment)
        }
        
        // 2. Analyze for insights
        let allSegments = await store.getAllSegments()
        let insights = await engine.analyzeTranscript(allSegments)
        
        XCTAssertFalse(insights.isEmpty, "Should detect insights from transcript")
        
        // 3. Generate summary
        let summary = await summaryEngine.generateSummary(
            from: allSegments,
            insights: insights,
            duration: 1800
        )
        
        XCTAssertFalse(summary.summary.isEmpty)
        XCTAssertFalse(summary.actionItems.isEmpty)
        XCTAssertFalse(summary.keyDecisions.isEmpty)
        XCTAssertFalse(summary.insights.isEmpty)
        
        // 4. Persist
        try await persistence.saveSummary(summary)
        let loaded = try await persistence.loadAllSummaries()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, summary.title)
    }
    
    /// Test real-time transcript accumulation
    func testRealTimeTranscriptAccumulation() async {
        let store = TranscriptStore()
        
        // Simulate partial transcript updates
        let partials = ["Hello", "Hello everyone", "Hello everyone, welcome"]
        
        for text in partials {
            await store.addPartialSegment(
                TestDataFactory.makeTranscriptSegment(text: text, isFinal: false)
            )
            
            let partial = await store.getPartialSegment()
            XCTAssertEqual(partial?.text, text)
        }
        
        // Finalize
        await store.finalizeCurrent()
        
        let all = await store.getAllSegments()
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all[0].isFinal)
    }
}
```

---

### Phase 4: CI/CD Integration (Week 6-7)

#### 4.1 GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  macos-tests:
    runs-on: macos-14
    timeout-minutes: 30
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
        with:
          swift-version: "6.2"
      
      - name: Build
        run: swift build
      
      - name: Run Tests
        run: swift test --enable-code-coverage
      
      - name: Generate Coverage Report
        run: |
          xcrun llvm-cov export \
            .build/debug/ConvoCraftPackageTests.xctest/Contents/MacOS/ConvoCraftPackageTests \
            -instr-profile=.build/debug/codecov/default.profdata \
            -ignore-filename-regex=".build|Tests" \
            -format=lcov > coverage.lcov
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage.lcov
          fail_ci_if_error: true

  swift-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: SwiftLint
        uses: norio-nomura/action-swiftlint@3.2.1
        with:
          args: --strict

  security-scan:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Security Scan
        run: |
          # Check for hardcoded secrets
          if git grep -i "api.key\|secret\|password\|token" -- '*.swift'; then
            echo "Potential secrets found in code"
            exit 1
          fi
          
          # Static analysis
          swift build
          xcrun --sdk macosx clang -fsyntax-only Sources/**/*.swift || true
```

#### 4.2 Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: swift-test
        name: Swift Tests
        entry: swift test
        language: system
        pass_filenames: false
        stages: [pre-push]
      
      - id: swiftlint
        name: SwiftLint
        entry: swiftlint lint --strict
        language: system
        types: [swift]
        stages: [pre-commit]
```

---

### Phase 5: Performance Testing (Week 7-8)

#### 5.1 Performance Test Suite

```swift
// Tests/ConvoCraftTests/PerformanceTests/SummaryPerformanceTests.swift

import XCTest
@testable import ConvoCraft

final class SummaryPerformanceTests: XCTestCase {
    
    func testSummaryGenerationPerformance_largeTranscript() async {
        let engine = SummaryEngine()
        
        // Generate 1000 segment transcript
        let segments = (0..<1000).map { i in
            TestDataFactory.makeTranscriptSegment(
                text: "This is segment number \(i). We need to complete this task. There is a risk involved."
            )
        }
        
        measure {
            let expectation = self.expectation(description: "Summary generation")
            
            Task {
                _ = await engine.generateSummary(from: segments, insights: [], duration: 3600)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testIntelligenceEnginePerformance() async {
        let engine = IntelligenceEngine()
        
        // Large text for NLP analysis
        let largeSegments = (0..<100).map { _ in
            TestDataFactory.makeTranscriptSegment(
                text: "We need to consider this. There is a risk. Maybe we should try the other approach."
            )
        }
        
        measure {
            let expectation = self.expectation(description: "Analysis")
            
            Task {
                _ = await engine.analyzeTranscript(largeSegments)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}
```

---

## Part 3: Coverage Targets

### Tiered Coverage Goals

| Tier | Components | Target Coverage | Rationale |
|------|------------|-----------------|-----------|
| **Critical** | `SummaryEngine`, `IntelligenceEngine` | 90%+ | Core business logic |
| **High** | `TranscriptStore`, `PersistenceLayer` | 80%+ | State management, data integrity |
| **Medium** | `MeetingSessionController` | 70%+ | Coordination logic |
| **Low** | `SpeechTranscriber`, `AudioCaptureManager`, Views | 50%+ | Device-dependent, UI testing |

### Coverage Metrics Dashboard

```
┌─────────────────────────────────────────────────────────┐
│                 COVERAGE METRICS                         │
├─────────────────────┬────────────┬──────────────────────┤
│ Component           │ Line %     │ Branch %             │
├─────────────────────┼────────────┼──────────────────────┤
│ SummaryEngine       │ 92%        │ 88%                  │
│ IntelligenceEngine  │ 89%        │ 85%                  │
│ TranscriptStore     │ 95%        │ 90%                  │
│ PersistenceLayer   │ 82%        │ 78%                  │
├─────────────────────┼────────────┼──────────────────────┤
│ OVERALL             │ 87%        │ 82%                  │
└─────────────────────┴────────────┴──────────────────────┘
```

---

## Part 4: Testing Patterns for Swift Actors

### Actor Testing Best Practices

```swift
// Pattern 1: Await all actor access
func testActorState() async {
    let store = TranscriptStore()
    
    // Correct: await for each actor access
    await store.addFinalSegment(segment)
    let segments = await store.getAllSegments()
    
    // Incorrect (won't compile):
    // let segments = store.getAllSegments() // Error: actor-isolated
}

// Pattern 2: Isolate test setup
actor TestTranscriptStore: TranscriptStore {
    // Override for test-specific behavior
}

// Pattern 3: Use XCTestExpectation for async flows
func testAsyncFlow() {
    let expectation = expectation(description: "Complete")
    
    Task {
        // async operations
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

---

## Part 5: Mocking Strategy

### NaturalLanguage Framework Mocking

```swift
// Tests/ConvoCraftTests/TestHelpers/MockNLPAnalyzer.swift

/// Since NaturalLanguage requires macOS, create a protocol for testing
protocol NLPAnalyzing {
    func tokenize(text: String) -> [String]
    func detectNamedEntities(text: String) -> [String]
}

/// Production implementation
struct NaturalLanguageAnalyzer: NLPAnalyzing {
    func tokenize(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]))
            return true
        }
        return sentences
    }
    
    func detectNamedEntities(text: String) -> [String] {
        // Production NER implementation
        return []
    }
}

/// Test mock
struct MockNLPAnalyzer: NLPAnalyzing {
    var mockTokens: [String] = []
    var mockEntities: [String] = []
    
    func tokenize(text: String) -> [String] {
        return mockTokens.isEmpty ? text.components(separatedBy: ". ") : mockTokens
    }
    
    func detectNamedEntities(text: String) -> [String] {
        return mockEntities
    }
}
```

---

## Part 6: Implementation Checklist

### Week 1-2: Foundation
- [ ] Add test target to `Package.swift`
- [ ] Create `Tests/ConvoCraftTests/` directory structure
- [ ] Create `TestDataFactory` helper
- [ ] Create `TempDirectory` helper for file I/O tests
- [ ] Set up initial XCTest configurations

### Week 2-4: Unit Tests
- [ ] `SummaryEngineTests` - all test cases
- [ ] `IntelligenceEngineTests` - all test cases
- [ ] `TranscriptStoreTests` - all test cases
- [ ] `PersistenceLayerTests` - all test cases
- [ ] Achieve 80%+ coverage on critical components

### Week 4-6: Integration Tests
- [ ] End-to-end workflow tests
- [ ] Real-time accumulation tests
- [ ] Cross-component integration tests

### Week 6-7: CI/CD
- [ ] Create `.github/workflows/test.yml`
- [ ] Set up code coverage reporting
- [ ] Add SwiftLint to pipeline
- [ ] Configure pre-commit hooks

### Week 7-8: Performance Tests
- [ ] Large transcript performance tests
- [ ] NLP analysis performance tests
- [ ] Memory leak detection tests

### Week 8-10: UI Tests (Optional)
- [ ] Set up XCUITest target
- [ ] Critical user flow tests
- [ ] Accessibility tests

---

## Part 7: Risk Mitigation

| Risk | Mitigation |
|------|------------|
| NaturalLanguage unavailable in test environment | Create protocol-based abstraction with mock |
| File I/O tests interfere with each other | Use unique temp directories per test |
| Actor isolation complexity | Use `async` throughout, XCTestExpectation for flows |
| Device-dependent features (Speech, Audio) | Mock protocols, skip tests on CI with environment flag |
| Long test execution times | Parallelize tests, use XCTest parallel run mode |

---

## Summary

This testing strategy provides a comprehensive roadmap to transform ConvoCraft from a project with zero test coverage to one with robust automated quality gates. The approach prioritizes:

1. **High-value business logic** (SummaryEngine, IntelligenceEngine) first
2. **Swift Actor-compatible patterns** for concurrent code
3. **Isolated file I/O testing** with temp directories
4. **CI/CD integration** for automated quality enforcement
5. **Incremental implementation** over 8-10 weeks

Expected outcomes:
- **87%+ line coverage** on critical components
- **Automated CI pipeline** with coverage reporting
- **Regression protection** for future development
- **Performance baselines** for monitoring
