# ConvoCraft

A macOS meeting assistant that provides real-time transcription and AI-driven insights using only Apple frameworks.

## Features

### During Meetings (Live)
- 🎙 **Real-time transcription** using Apple's Speech framework
- 💡 **AI-generated insights** including:
  - Clarifying questions
  - Suggested follow-ups
  - Risk detection
  - Key entity tracking
- 🔴 **Live visual indicator** during recording

### After Meetings
- 📝 **Structured summaries** with extractive approach
- ✅ **Action items** automatically extracted
- 🎯 **Key decisions** highlighted
- 💾 **Persistent storage** of transcripts and insights

## Architecture

ConvoCraft is built exclusively with Apple frameworks:

- **ScreenCaptureKit** - Audio capture (system + microphone)
- **Speech** - Real-time transcription
- **NaturalLanguage** - Lightweight NLP for pattern detection
- **SwiftUI** - Modern user interface
- **AVFoundation** - Audio processing
- **Actors** - Concurrency-safe state management

### System Architecture

```
SwiftUI App
    ↓
MeetingSessionController
    ↓
┌─────────────────┬──────────────────┐
│                 │                  │
SpeechTranscriber TranscriptStore   IntelligenceEngine
│                 │                  │
└─────────────────┴──────────────────┘
                  ↓
            SummaryEngine
                  ↓
           PersistenceLayer
```

## Requirements

- macOS 14.0 or later
- Microphone permission
- Speech recognition permission
- Screen capture permission (for system audio)

## Building

This is a Swift Package Manager project:

```bash
swift build
swift run
```

Or open in Xcode and build/run from there.

## Privacy & Security

- ✅ **Fully local processing** - No cloud APIs
- ✅ **No network calls** - All AI runs on-device
- ✅ **User-initiated recording** - No background recording
- ✅ **Local storage only** - Transcripts never leave device

## Components

### Models
- **TranscriptSegment** - Individual transcript entries
- **IntelligenceInsight** - AI-generated suggestions
- **MeetingSummary** - Post-meeting summary structure

### Actors (Concurrency-Safe)
- **TranscriptStore** - Thread-safe transcript storage
- **IntelligenceEngine** - NLP analysis engine

### Services
- **AudioCaptureManager** - ScreenCaptureKit audio capture
- **SpeechTranscriber** - Real-time speech recognition
- **SummaryEngine** - Post-meeting summary generation
- **PersistenceLayer** - JSON-based storage
- **MeetingSessionController** - Coordinates all components

### Views
- **ContentView** - Main app container
- **MeetingView** - Live meeting interface
- **LiveTranscriptView** - Real-time transcript display
- **InsightsView** - AI insights panel
- **SummaryListView** - Previous meetings list
- **SummaryDetailView** - Detailed summary view

## Usage

1. **Start a Meeting**: Click "Start Meeting" button
2. **Grant Permissions**: Allow microphone and speech recognition
3. **Speak Naturally**: The app will transcribe in real-time
4. **Monitor Insights**: AI insights appear in the right panel
5. **Stop Meeting**: Click "Stop Meeting" when done
6. **View Summary**: Check the "Summaries" tab for saved meetings

## Implementation Notes

### Intelligence Engine

The intelligence engine uses a two-tier approach:

**Tier 1: NaturalLanguage Framework**
- Fast, lightweight pattern detection
- Named entity recognition
- Commitment/action phrase detection
- Risk signal identification
- Runs continuously with minimal CPU

**Tier 2: Foundation Models (Future)**
- Contextual reasoning (when FoundationModels is available)
- Sliding context window to manage token limits
- Batched invocation to reduce overhead

### Concurrency Model

All long-running operations use Swift's structured concurrency:
- Audio capture runs in async task
- Speech recognition streams results
- NLP analysis runs periodically
- All state updates via MainActor
- No shared mutable state

### Performance Considerations

- Speech recognition runs continuously (~300-800ms latency)
- LLM inference batched (every 10 seconds)
- Sliding context window prevents memory growth
- Audio buffers not retained long-term

## License

MIT License - See LICENSE file for details

## Credits

Built following the architecture defined in PLAN.md, using only Apple-provided frameworks for maximum privacy and integration with macOS.
