# ConvoCraft Project Roadmap

## Project Overview

**ConvoCraft** is a macOS-native meeting assistant that provides real-time transcription and AI-driven insights using exclusively Apple frameworks. It prioritizes privacy with fully local, on-device processing using Swift 6.2, SwiftUI, and Apple's Speech framework.

---

## Current State Summary

| Aspect | Status |
|--------|--------|
| **Completion** | ~80% implemented |
| **Tech Stack** | Swift 6.2, SwiftUI, Apple Speech, ScreenCaptureKit, NaturalLanguage |
| **Code Size** | ~1,154 lines across 13 Swift files |
| **Architecture** | Actor-based concurrency with clean layer separation |
| **Testing** | No tests implemented |

### Implementation Status

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CONVOCRAFT IMPLEMENTATION STATUS                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ████████████████████████████████████████████░░░░░░░░░░░  80% Complete  │
│                                                                          │
│  ✓ UI Layer           ████████████████████ 100% (6 views)               │
│  ✓ SpeechTranscriber  ████████████████████ 100%                          │
│  ✓ TranscriptStore    ████████████████████ 100%                          │
│  ✓ IntelligenceEngine ████████████████████ 100% (Tier 1 NLP)            │
│  ✓ SummaryEngine      ████████████████████ 100%                          │
│  ✓ PersistenceLayer   ████████████████████ 100%                          │
│  △ AudioCaptureManager████████████░░░░░░░░░░  50% (PCM conversion stub) │
│  ✗ Testing            ░░░░░░░░░░░░░░░░░░░░░░   0%                        │
│  ✗ FoundationModels   ░░░░░░░░░░░░░░░░░░░░░░   0% (awaiting framework)  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Critical Issues

### Issue 1: Audio Pipeline Incomplete (BLOCKER)

**Location:** `AudioCaptureManager.swift` lines 132-147

**Problem:** The CMSampleBuffer to PCM conversion is stubbed. The `stream(_:didOutputSampleBuffer:of:)` method yields `Data()` instead of actual audio data.

```swift
// Current (broken):
nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .audio else { return }
    Task { @MainActor in
        if let continuation = self.continuation {
            continuation.yield(Data())  // ← Returns empty data!
        }
    }
}
```

**Impact:** ScreenCaptureKit audio capture is configured but transcription receives no audio. The system captures audio frames but discards them before they reach the Speech framework.

### Issue 2: No Testing Infrastructure

**Problem:** Zero unit tests or integration tests exist.

**Impact:** Cannot validate:
- PCM conversion correctness
- Transcription pipeline integration
- IntelligenceEngine NLP patterns
- PersistenceLayer serialization
- Session lifecycle management

### Issue 3: Tier 2 Intelligence Unavailable

**Problem:** FoundationModels framework not yet available from Apple.

**Impact:** Limited to Tier 1 NLP (keyword matching, basic NER). No LLM-powered summarization or context understanding.

---

## Phase Structure

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           PHASE DEPENDENCIES                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Phase 1          Phase 2          Phase 3          Phase 4              │
│  CRITICAL         HIGH             MEDIUM           MEDIUM                │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐          │
│  │  Audio  │─────▶│ Testing │─────▶│ Features│─────▶│  Intel  │          │
│  │  Fix    │      │ & QA    │      │Enhance  │      │ Tier 2  │          │
│  └─────────┘      └─────────┘      └─────────┘      └─────────┘          │
│       │                │                │                │               │
│       │                │                │                ▼               │
│       │                │                │          ┌─────────┐           │
│       │                │                └─────────▶│ Phase 5 │           │
│       │                │                           │Platform │           │
│       │                │                           │   UX    │           │
│       ▼                ▼                           └─────────┘           │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │                    Production Ready                          │        │
│  └─────────────────────────────────────────────────────────────┘        │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Critical Fixes

**Priority:** 🔴 Critical  
**Duration Estimate:** 1-2 days  
**Complexity:** High

### Goal Statement

**Users can capture system audio and receive accurate real-time transcription.**

The audio pipeline must correctly convert CMSampleBuffer from ScreenCaptureKit into PCM format that Apple's Speech framework can process.

### Success Criteria

| # | Criterion | Verification Method |
|---|-----------|---------------------|
| 1 | User can start a meeting and see transcribed text from system audio | Manual: Play YouTube video, verify transcription appears |
| 2 | Audio capture works with multiple audio sources (system + microphone) | Manual: Test with Zoom call + external mic |
| 3 | PCM data is correctly formatted for Speech framework | Unit test: Validate audio buffer format |
| 4 | No audio memory leaks during extended sessions | Instruments: Monitor memory over 30-min session |

### Tasks

#### Task 1.1: Implement PCM Conversion (Complexity: High)

**File:** `Sources/ConvoCraft/Services/AudioCaptureManager.swift`

**Changes Required:**

```swift
// Replace lines 132-147 with proper PCM conversion
nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .audio else { return }
    
    // 1. Validate sample buffer
    guard sampleBuffer.isValid,
          sampleBuffer.numSamples > 0 else { return }
    
    // 2. Extract audio buffer list
    var audioBufferList = AudioBufferList()
    var blockBuffer: CMBlockBuffer?
    
    let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer,
        bufferListSizeNeededOut: nil,
        bufferListOut: &audioBufferList,
        bufferListSize: AudioBufferList.sizeInBytes(maximumBuffers: 1),
        blockBufferStructureAllocator: nil,
        blockBufferBlockAllocator: nil,
        flags: 0,
        blockBufferOut: &blockBuffer
    )
    
    guard status == noErr, let buffer = blockBuffer else { return }
    
    // 3. Extract raw PCM data
    let data = Data(bytes: audioBufferList.mBuffers.mData!, 
                    count: Int(audioBufferList.mBuffers.mDataByteSize))
    
    // 4. Yield to transcription pipeline
    Task { @MainActor in
        self.continuation?.yield(data)
    }
}
```

**Dependencies:** None (entry point)

#### Task 1.2: Integrate Audio Pipeline with SpeechTranscriber (Complexity: Medium)

**File:** `Sources/ConvoCraft/Services/SpeechTranscriber.swift`

**Current State:** Uses AVAudioEngine tap for microphone input only.

**Changes Required:**
- Add method to accept external audio buffer stream
- Route ScreenCaptureKit audio to recognition request

```swift
// Add to SpeechTranscriber.swift
func feedAudioBuffer(_ data: Data) {
    // Convert Data to AVAudioPCMBuffer
    // Append to recognitionRequest
}
```

**Dependencies:** Task 1.1

#### Task 1.3: Update MeetingSessionController Pipeline (Complexity: Low)

**File:** `Sources/ConvoCraft/Services/MeetingSessionController.swift`

**Current State:** AudioCaptureManager is initialized but never used in the transcription flow.

**Changes Required:**
- Start audio capture in `startMeeting()`
- Route captured audio to SpeechTranscriber
- Handle capture errors gracefully

**Dependencies:** Tasks 1.1, 1.2

#### Task 1.4: Add Audio Format Validation (Complexity: Low)

**File:** `Sources/ConvoCraft/Services/AudioCaptureManager.swift`

**Changes Required:**
- Add audio format conversion if needed (sample rate, channels)
- Validate 48kHz, mono format expected by Speech framework

**Dependencies:** Task 1.1

### Acceptance Checklist

- [ ] `stream(_:didOutputSampleBuffer:of:)` extracts valid PCM data
- [ ] Audio data reaches SpeechTranscriber
- [ ] Transcription appears in LiveTranscriptView during meeting
- [ ] No crashes when switching audio sources
- [ ] Memory usage stable over 30-minute session
- [ ] Console logs show audio buffer sizes > 0 bytes

---

## Phase 2: Quality & Reliability

**Priority:** 🟠 High  
**Duration Estimate:** 2-3 days  
**Complexity:** Medium

### Goal Statement

**The application is thoroughly tested and production-ready with robust error handling.**

Every critical path has unit tests, integration tests validate end-to-end flows, and users receive clear feedback when errors occur.

### Success Criteria

| # | Criterion | Verification Method |
|---|-----------|---------------------|
| 1 | All core components have unit tests with >80% coverage | `swift test --coverage` |
| 2 | Session lifecycle can be tested end-to-end | Integration test suite |
| 3 | All error paths show user-friendly messages | Manual error injection |
| 4 | Logging provides debugging information | Console log review |

### Tasks

#### Task 2.1: Set Up Testing Infrastructure (Complexity: Low)

**Files to Create:**
- `Tests/ConvoCraftTests/` directory structure
- Update `Package.swift` with test target

```swift
// Package.swift additions
.testTarget(
    name: "ConvoCraftTests",
    dependencies: ["ConvoCraft"]
)
```

**Dependencies:** None

#### Task 2.2: Unit Tests for IntelligenceEngine (Complexity: Medium)

**File:** `Tests/ConvoCraftTests/IntelligenceEngineTests.swift`

**Test Cases:**
- Uncertainty phrase detection
- Commitment phrase detection
- Risk signal detection
- Timeline/deadline detection
- Named entity recognition
- Edge cases (empty input, special characters)

```swift
// Example test structure
@Test("Detects uncertainty phrases")
func testUncertaintyDetection() async {
    let engine = IntelligenceEngine()
    let segment = TranscriptSegment(text: "maybe we should consider this", timestamp: 0)
    let insights = await engine.analyzeTranscript([segment])
    #expect(insights.contains { $0.type == .question })
}
```

**Dependencies:** Task 2.1

#### Task 2.3: Unit Tests for SummaryEngine (Complexity: Medium)

**File:** `Tests/ConvoCraftTests/SummaryEngineTests.swift`

**Test Cases:**
- Sentence tokenization
- Action item extraction
- Key decision extraction
- Empty transcript handling
- Long transcript handling

**Dependencies:** Task 2.1

#### Task 2.4: Unit Tests for PersistenceLayer (Complexity: Medium)

**File:** `Tests/ConvoCraftTests/PersistenceLayerTests.swift`

**Test Cases:**
- Summary serialization/deserialization
- File naming convention
- Loading multiple summaries
- Corrupted file handling

**Dependencies:** Task 2.1

#### Task 2.5: Unit Tests for TranscriptStore (Complexity: Low)

**File:** `Tests/ConvoCraftTests/TranscriptStoreTests.swift`

**Test Cases:**
- Segment addition
- Partial vs final segment handling
- Recent transcript retrieval
- Clear operation

**Dependencies:** Task 2.1

#### Task 2.6: Integration Tests for Session Flow (Complexity: High)

**File:** `Tests/ConvoCraftTests/SessionIntegrationTests.swift`

**Test Cases:**
- Full meeting lifecycle (start → stop → summary)
- Transcription flow with mock audio
- Analysis pipeline timing
- Error recovery during session

**Dependencies:** Tasks 2.2, 2.3, 2.4, 2.5

#### Task 2.7: Implement Error Handling Improvements (Complexity: Medium)

**Files:** 
- `Sources/ConvoCraft/Services/AudioCaptureManager.swift`
- `Sources/ConvoCraft/Services/SpeechTranscriber.swift`
- `Sources/ConvoCraft/Services/MeetingSessionController.swift`

**Changes Required:**
- Add typed error enums with recovery suggestions
- Implement retry logic for transient failures
- Add error aggregation for debugging

```swift
// Enhanced error handling
enum AudioCaptureError: LocalizedError {
    case permissionDenied(recoverySuggestion: String)
    case streamSetupFailed(underlying: Error?)
    case audioFormatUnsupported(format: String)
    
    var errorDescription: String? { ... }
    var recoverySuggestion: String? { ... }
}
```

**Dependencies:** Task 2.6

#### Task 2.8: Add Logging/Observability (Complexity: Low)

**File:** `Sources/ConvoCraft/Utils/Logger.swift` (new)

**Changes Required:**
- Create centralized logger using `os.log`
- Add log levels (debug, info, error)
- Log key events: session start/stop, transcription, insights

**Dependencies:** Task 2.7

### Acceptance Checklist

- [ ] `swift test` passes with all tests green
- [ ] Test coverage >80% for core components
- [ ] Error messages are user-friendly
- [ ] Logs are accessible via Console.app
- [ ] Integration tests cover full session lifecycle

---

## Phase 3: Feature Enhancements

**Priority:** 🟡 Medium  
**Duration Estimate:** 3-5 days  
**Complexity:** Medium-High

### Goal Statement

**Users can export meeting data in multiple formats, customize meetings with templates, and search across all transcripts.**

### Success Criteria

| # | Criterion | Verification Method |
|---|-----------|---------------------|
| 1 | User can export summary as Markdown file | Manual: Export and open in editor |
| 2 | User can export summary as PDF | Manual: Export and open in Preview |
| 3 | User can create and apply meeting templates | Manual: Create template, start meeting with it |
| 4 | User can search across all transcripts | Manual: Search returns matching segments |
| 5 | Summary formatting includes proper markdown headers | Visual inspection of exports |

### Tasks

#### Task 3.1: Implement Export Service (Complexity: Medium)

**File:** `Sources/ConvoCraft/Services/ExportService.swift` (new)

**Requirements:**
- Export to Markdown (.md)
- Export to PDF
- Export to plain text (.txt)
- Include all summary sections

```swift
// ExportService.swift
actor ExportService {
    func exportToMarkdown(_ summary: MeetingSummary) async throws -> URL
    func exportToPDF(_ summary: MeetingSummary) async throws -> URL
    func exportToPlainText(_ summary: MeetingSummary) async throws -> URL
}
```

**Dependencies:** Phase 2 complete

#### Task 3.2: Add Export UI (Complexity: Low)

**File:** `Sources/ConvoCraft/Views/ContentView.swift`

**Changes Required:**
- Add "Export" button to SummaryDetailView
- Show format selection dialog
- Display export success/failure

**Dependencies:** Task 3.1

#### Task 3.3: Implement Meeting Templates (Complexity: Medium)

**Files:**
- `Sources/ConvoCraft/Models/MeetingTemplate.swift` (new)
- `Sources/ConvoCraft/Views/TemplateSelectionView.swift` (new)

**Template Structure:**
```swift
struct MeetingTemplate: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let focusKeywords: [String]      // Words to highlight
    let trackedPhrases: [String]     // Custom phrases to detect
    let customInsightRules: [InsightRule]
}
```

**Dependencies:** Phase 2 complete

#### Task 3.4: Implement Search Functionality (Complexity: High)

**Files:**
- `Sources/ConvoCraft/Services/SearchService.swift` (new)
- `Sources/ConvoCraft/Views/SearchView.swift` (new)

**Requirements:**
- Full-text search across all transcripts
- Filter by date range
- Filter by meeting title
- Show context around matches

**Dependencies:** Phase 2 complete

#### Task 3.5: Enhanced Summary Formatting (Complexity: Low)

**File:** `Sources/ConvoCraft/Services/SummaryEngine.swift`

**Changes Required:**
- Add markdown formatting to summary sections
- Include timestamps in transcript sections
- Add meeting metadata header

```markdown
# Meeting Summary - February 14, 2026

**Duration:** 45 minutes
**Participants:** (detected entities)

## Summary
[AI-generated summary]

## Action Items
- [ ] Action item 1
- [ ] Action item 2

## Key Decisions
1. Decision one
2. Decision two

## Full Transcript
[00:00:00] First segment...
```

**Dependencies:** Task 3.1

### Acceptance Checklist

- [ ] Markdown export produces valid .md files
- [ ] PDF export is formatted correctly
- [ ] Plain text export preserves all content
- [ ] Templates can be created, saved, and applied
- [ ] Search returns relevant results within 2 seconds
- [ ] Export files open in standard applications

---

## Phase 4: Advanced Intelligence

**Priority:** 🟡 Medium  
**Duration Estimate:** 3-4 days (partial) + ongoing  
**Complexity:** High

### Goal Statement

**The application provides deeper meeting intelligence with enhanced NLP, topic segmentation, and FoundationModels integration when available.**

### Success Criteria

| # | Criterion | Verification Method |
|---|-----------|---------------------|
| 1 | Enhanced NLP patterns detect 5+ insight categories | Unit tests |
| 2 | Topics are automatically segmented in transcripts | Visual inspection |
| 3 | FoundationModels integration is ready for activation | Code review |
| 4 | Speaker identification works (when Apple supports it) | Integration test |

### Tasks

#### Task 4.1: Enhanced NLP Patterns (Complexity: Medium)

**File:** `Sources/ConvoCraft/Actors/IntelligenceEngine.swift`

**New Detection Categories:**
- **Questions:** Detect and track open questions
- **Agreements:** "I agree", "sounds good", "let's do it"
- **Disagreements:** "I don't think so", "that won't work"
- **Deadlines:** Extract specific dates/times
- **Numbers/Metrics:** Extract quantifiable data

**Dependencies:** Phase 2 complete

#### Task 4.2: Topic Segmentation (Complexity: Medium)

**File:** `Sources/ConvoCraft/Services/TopicSegmenter.swift` (new)

**Requirements:**
- Use NaturalLanguage framework for topic detection
- Segment transcript by topic changes
- Label segments with detected topics

```swift
struct TranscriptTopic: Identifiable {
    let id: UUID
    let label: String
    let startIndex: Int
    let endIndex: Int
    let segments: [TranscriptSegment]
}
```

**Dependencies:** Phase 2 complete

#### Task 4.3: FoundationModels Integration Preparation (Complexity: High)

**File:** `Sources/ConvoCraft/Services/LLMService.swift` (new, stub)

**Requirements:**
- Define protocol for LLM integration
- Create abstraction layer for Apple's FoundationModels
- Implement fallback to Tier 1 NLP when unavailable

```swift
/// Protocol for LLM-based intelligence
protocol LLMIntelligence {
    func generateSummary(from transcript: String) async throws -> String
    func extractActionItems(from transcript: String) async throws -> [String]
    func answerQuestion(_ question: String, context: String) async throws -> String
}

/// FoundationModels implementation (when available)
@available(macOS 15.0, *)
struct FoundationModelsService: LLMIntelligence {
    // Implementation when Apple releases framework
}
```

**Dependencies:** Phase 2 complete

#### Task 4.4: Speaker Identification Placeholder (Complexity: Low)

**File:** `Sources/ConvoCraft/Models/SpeakerSegment.swift` (new)

**Requirements:**
- Define speaker segment model
- Add placeholder for Apple's future speaker ID API
- Update UI to show speaker labels when available

**Dependencies:** Task 4.3

### Acceptance Checklist

- [ ] New insight categories appear in IntelligenceEngine
- [ ] Topics are labeled in long transcripts
- [ ] LLMService protocol compiles and passes tests
- [ ] Speaker model is ready for future implementation

---

## Phase 5: Platform & UX

**Priority:** 🟢 Low  
**Duration Estimate:** 2-3 days  
**Complexity:** Low-Medium

### Goal Statement

**The application integrates seamlessly into macOS workflow with quick access, keyboard shortcuts, and full accessibility support.**

### Success Criteria

| # | Criterion | Verification Method |
|---|-----------|---------------------|
| 1 | User can start meeting from menu bar | Manual test |
| 2 | All actions have keyboard shortcuts | Manual test |
| 3 | Preferences persist between sessions | Restart test |
| 4 | VoiceOver can navigate all controls | Accessibility Inspector |

### Tasks

#### Task 5.1: Menu Bar Quick Access (Complexity: Medium)

**Files:**
- `Sources/ConvoCraft/MenuBar/MenuBarController.swift` (new)
- `Sources/ConvoCraft/MenuBar/MenuBarView.swift` (new)

**Requirements:**
- Show recording status in menu bar
- Quick start/stop meeting
- Show last meeting summary
- Open main window option

**Dependencies:** Phase 3 complete

#### Task 5.2: Keyboard Shortcuts (Complexity: Low)

**File:** `Sources/ConvoCraft/Views/ContentView.swift`

**Shortcuts to Implement:**
| Shortcut | Action |
|----------|--------|
| ⌘N | New meeting |
| ⌘. | Stop meeting |
| ⌘E | Export summary |
| ⌘F | Focus search |
| ⌘, | Open preferences |

**Dependencies:** Phase 3 complete

#### Task 5.3: Preferences Panel (Complexity: Medium)

**Files:**
- `Sources/ConvoCraft/Views/PreferencesView.swift` (new)
- `Sources/ConvoCraft/Services/PreferencesManager.swift` (new)

**Settings:**
- Audio source selection (system/microphone/both)
- Transcription language
- Auto-save interval
- Export default format
- Theme (light/dark/system)

**Dependencies:** Phase 3 complete

#### Task 5.4: Accessibility Improvements (Complexity: Low)

**Files:** All view files

**Requirements:**
- Add accessibility labels to all controls
- Implement accessibility actions
- Support dynamic type scaling
- Ensure keyboard navigation works

**Dependencies:** Task 5.2

### Acceptance Checklist

- [ ] Menu bar icon shows recording status
- [ ] Meeting can be started from menu bar
- [ ] All keyboard shortcuts work
- [ ] Preferences persist after app restart
- [ ] Accessibility Inspector reports no issues

---

## Architecture Reference

### Current File Structure

```
ConvoCraft/
├── Package.swift
├── Sources/
│   └── ConvoCraft/
│       ├── ConvoCraft.swift           # App entry point
│       ├── Models/
│       │   ├── TranscriptSegment.swift    # 16 lines ✓
│       │   ├── MeetingSummary.swift       # 14 lines ✓
│       │   └── IntelligenceInsight.swift  # 22 lines ✓
│       ├── Views/
│       │   └── ContentView.swift      # 347 lines ✓ (6 views)
│       ├── Services/
│       │   ├── AudioCaptureManager.swift  # 150 lines △ (needs fix)
│       │   ├── SpeechTranscriber.swift    # 121 lines ✓
│       │   ├── MeetingSessionController.swift # 162 lines ✓
│       │   ├── SummaryEngine.swift        # 150 lines ✓
│       │   └── PersistenceLayer.swift     # 59 lines ✓
│       └── Actors/
│           ├── TranscriptStore.swift      # (in Services)
│           └── IntelligenceEngine.swift   # 108 lines ✓
└── Tests/                              # NOT CREATED
    └── ConvoCraftTests/
```

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐                                                     │
│  │ ScreenCaptureKit│──────┐                                              │
│  │  (System Audio) │      │                                              │
│  └─────────────────┘      │                                              │
│                           ▼                                              │
│  ┌─────────────────┐  ┌───────────────────┐                              │
│  │   Microphone    │──▶│AudioCaptureManager│                              │
│  │  (AVAudioEngine)│  │   (PCM Conversion)│                              │
│  └─────────────────┘  └─────────┬─────────┘                              │
│                                 │                                        │
│                                 │ Data<PCM>                              │
│                                 ▼                                        │
│                       ┌───────────────────┐                              │
│                       │ SpeechTranscriber │                              │
│                       │   (Apple Speech)  │                              │
│                       └─────────┬─────────┘                              │
│                                 │                                        │
│                                 │ TranscriptSegments                     │
│                                 ▼                                        │
│                    ┌────────────────────────┐                            │
│                    │   TranscriptStore      │◀──────┐                     │
│                    │       (Actor)          │       │                     │
│                    └───────────┬────────────┘       │                     │
│                                │                    │                     │
│              ┌─────────────────┼─────────────────┐  │                     │
│              │                 │                 │  │                     │
│              ▼                 ▼                 ▼  │                     │
│  ┌───────────────────┐ ┌───────────────┐ ┌──────────┴──────────┐          │
│  │ IntelligenceEngine│ │ SummaryEngine │ │MeetingSessionController         │
│  │    (Actor)        │ │   (Actor)    │ │      @Observable)   │          │
│  └─────────┬─────────┘ └───────┬───────┘ └──────────┬──────────┘          │
│            │                   │                    │                     │
│            │ Insights          │ Summary            │ State               │
│            ▼                   ▼                    ▼                     │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │                         SwiftUI Views                            │     │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐  │     │
│  │  │ContentView  │ │MeetingView  │ │InsightsView │ │SummaryView│  │     │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘  │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│                                │                                         │
│                                │ Persist                                 │
│                                ▼                                         │
│                    ┌───────────────────┐                                 │
│                    │ PersistenceLayer  │                                 │
│                    │  (JSON Storage)   │                                 │
│                    └───────────────────┘                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Progress Tracking

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Critical Fixes | 🔴 Not Started | 0% |
| Phase 2: Quality & Reliability | ⚪ Blocked (Phase 1) | 0% |
| Phase 3: Feature Enhancements | ⚪ Blocked (Phase 2) | 0% |
| Phase 4: Advanced Intelligence | ⚪ Blocked (Phase 2) | 0% |
| Phase 5: Platform & UX | ⚪ Blocked (Phase 3) | 0% |

### Legend
- 🔴 Not Started
- 🟡 In Progress
- 🟢 Complete
- ⚪ Blocked

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| PCM conversion more complex than expected | Medium | High | Research AVAudioBuffer APIs before implementation |
| ScreenCaptureKit audio format incompatible with Speech framework | Low | High | Add format conversion layer |
| FoundationModels delayed indefinitely | High | Medium | Design abstraction layer, use Tier 1 NLP |
| Apple changes Speech API in future macOS | Low | Medium | Use stable APIs, abstract behind protocol |
| Memory leaks in long sessions | Medium | Medium | Add explicit cleanup, use Instruments to verify |

---

## Next Steps

1. **Immediate:** Begin Phase 1, Task 1.1 (PCM Conversion)
2. **This Week:** Complete Phase 1 and begin Phase 2 testing infrastructure
3. **This Month:** Complete Phases 1-2, begin Phase 3
4. **Ongoing:** Monitor Apple FoundationModels availability for Phase 4

---

*Roadmap created: February 14, 2026*  
*Last updated: February 14, 2026*
