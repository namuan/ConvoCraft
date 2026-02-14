ConvoCraft: macOS Meeting Summariser with Real-Time Transcription & Local LLM Assistance

Apple Frameworks Only

⸻

1. Overview

This document defines the architecture for a macOS meeting assistant that:
	•	Captures system/app audio (Zoom, Teams, etc.)
	•	Captures microphone audio
	•	Performs near real-time transcription during the meeting
	•	Generates live AI-driven ideas and questions during the meeting
	•	Produces a structured post-meeting summary

The implementation must use only Apple-provided frameworks:
	•	ScreenCaptureKit
	•	AVFoundation
	•	Speech
	•	NaturalLanguage
	•	SwiftUI
	•	FoundationModels (for local LLM inference on supported systems)

Target platform: macOS 14+
Preferred: macOS 15+ (for improved on-device model support)

⸻

2. Goals

2.1 Functional Goals

During meeting (live):
	•	Capture system + mic audio
	•	Near real-time transcription
	•	Continuously generate:
	•	Clarifying questions
	•	Suggested follow-ups
	•	Risks / gaps
	•	Idea expansions

After meeting:
	•	Structured summary
	•	Extracted action items
	•	Key decisions
	•	Persist transcript + AI insights locally

⸻

2.2 Non-Goals
	•	No cloud APIs
	•	No third-party LLMs
	•	No Whisper
	•	No network calls
	•	No background recording without user initiation

⸻

3. System Architecture

SwiftUI App
    ↓
MeetingSessionController
    ↓
CaptureManager (ScreenCaptureKit)
    ↓
AudioPipeline
    ↓
SpeechTranscriber (Streaming)
    ↓
TranscriptStore (actor)
    ↓
Realtime Intelligence Engine
        ├── NaturalLanguage (lightweight NLP)
        └── Local LLM (FoundationModels)
    ↓
SummaryEngine (post-meeting)
    ↓
Persistence Layer


⸻

4. Audio Capture

4.1 Design Decision

Use ScreenCaptureKit exclusively for:
	•	System audio
	•	Per-app audio
	•	Microphone audio

This avoids:
	•	AVAudioEngine mixing
	•	Clock drift
	•	Complex audio graph setup

⸻

4.2 Capture Configuration

let config = SCStreamConfiguration()
config.capturesAudio = true
config.captureMicrophone = true
config.sampleRate = 48000
config.channelCount = 1
config.excludesCurrentProcessAudio = false


⸻

4.3 Buffer Pipeline

CMSampleBuffer
    ↓
Convert → AVAudioPCMBuffer
    ↓
Append → Speech Recognition Request

Audio normalization:
	•	48 kHz
	•	Mono
	•	Float PCM

⸻

5. Near Real-Time Transcription

5.1 Framework

Use:
	•	Speech

5.2 Streaming Mode

Use:

SFSpeechAudioBufferRecognitionRequest

Configure for:
	•	On-device recognition
	•	Partial results enabled

request.shouldReportPartialResults = true


⸻

5.3 Latency Target

Expected transcription latency:
	•	300–800ms for partial text
	•	1–2 seconds for stabilized segments

This satisfies “near real-time” interaction requirements.

⸻

5.4 Transcription Architecture

AudioCaptureTask
    ↓
AsyncStream<AudioBuffer>
    ↓
SpeechTranscriber Task
    ↓
Partial Results → UI
Final Results → TranscriptStore

The system must:
	•	Display partial transcription immediately
	•	Commit finalized segments to transcript store
	•	Restart recognition session on timeout

⸻

6. Transcript Store

Concurrency-safe actor:

actor TranscriptStore {
    private(set) var segments: [TranscriptSegment] = []
}

Segment structure:

struct TranscriptSegment {
    let text: String
    let timestamp: TimeInterval
}


⸻

7. Realtime Intelligence Engine

This component generates:
	•	Questions to ask
	•	Idea expansions
	•	Risk detection
	•	Missing information signals

It runs during the meeting.

⸻

7.1 Two-Tier Intelligence Design

Tier 1: Lightweight NLP (Low Latency)

Uses:
	•	NaturalLanguage

Responsibilities:
	•	Detect named entities
	•	Extract topics
	•	Identify commitments
	•	Spot future tense
	•	Detect uncertainty phrases

Triggers:
	•	“we should”
	•	“maybe”
	•	“not sure”
	•	“deadline”
	•	“risk”

This tier runs continuously with minimal CPU overhead.

⸻

Tier 2: Local LLM (Contextual Reasoning)

Uses:
	•	FoundationModels

Purpose:

Generate contextual outputs like:
	•	“Ask about timeline feasibility.”
	•	“Clarify budget approval.”
	•	“Potential technical risk: integration complexity.”

⸻

8. Local LLM Integration

8.1 Context Window Strategy

We do NOT feed entire transcript.

Instead:
	•	Maintain sliding context window (last N minutes or N tokens)
	•	Summarize older segments periodically
	•	Feed:
	•	Recent transcript
	•	Detected key entities
	•	Conversation intent summary

⸻

8.2 Invocation Strategy

Trigger LLM:
	•	Every X finalized transcript segments
	•	Or when topic shift detected
	•	Or when question pattern appears

LLM runs asynchronously to avoid blocking UI.

⸻

8.3 Prompt Strategy (Conceptual)

System instruction:
	•	You are a meeting assistant.
	•	Generate concise suggestions.
	•	Do not hallucinate.
	•	Base only on transcript.

Input:
	•	Recent transcript
	•	Key topics extracted

Output structured as:

{
  "questions": [],
  "ideas": [],
  "risks": []
}


⸻

8.4 Latency Expectations

Local LLM:
	•	~300ms–2s depending on device
	•	Must run off main thread
	•	Results streamed back to UI

⸻

9. UI Integration

Framework:
	•	SwiftUI

Live UI sections:
	•	🎙 Live Transcript
	•	💡 Suggested Questions
	•	⚠ Risks / Gaps
	•	🧠 Ideas

All powered by observable state from MeetingSessionController.

⸻

10. Post-Meeting Summary

After capture stops:
	1.	Freeze transcript
	2.	Generate final summary
	3.	Extract action items
	4.	Persist to disk

Summary engine may:
	•	Use NaturalLanguage extractive approach
	•	Or invoke local LLM for higher-quality summary

⸻

11. Concurrency Model

All long-running tasks run in structured concurrency:

Task Group:
    - Audio capture task
    - Speech recognition task
    - Realtime NLP task
    - LLM inference task

State isolation:
	•	TranscriptStore → actor
	•	IntelligenceEngine → actor
	•	UI updates via @MainActor

No shared mutable state.

⸻

12. Performance Considerations
	•	Speech runs continuously → CPU load
	•	LLM inference batched to avoid excessive calls
	•	Sliding context window prevents memory growth
	•	Do not retain raw audio buffers long-term

⸻

13. Privacy & Security
	•	Fully local processing
	•	No cloud calls
	•	No transcript leaves device
	•	Recording requires explicit user action
	•	Visual indicator during recording

⸻

14. Failure Handling

Speech Failure
	•	Auto-restart recognition
	•	Buffer audio while restarting

LLM Failure
	•	Skip cycle
	•	Retry next trigger

Permission Revocation
	•	Graceful stop
	•	Clear UI state

⸻

15. Key Architectural Principles
	•	Single audio source (ScreenCaptureKit)
	•	Near real-time transcription
	•	Sliding context reasoning
	•	Layered intelligence (NLP + LLM)
	•	Actor-isolated state
	•	Apple frameworks only
	•	Offline-first

⸻

16. Clean Mental Model

ScreenCaptureKit → Ear
Speech → Hearing
NaturalLanguage → Pattern recognition
FoundationModels → Reasoning
SwiftUI → Presentation


⸻

17. Conclusion

This design enables:
	•	Near real-time transcription
	•	Live AI-generated ideas and questions
	•	Fully offline operation
	•	Apple-only technology stack
	•	Scalable, modular architecture
	•	Production-grade concurrency model

It represents the cleanest, most future-proof Apple-native architecture for a real-time intelligent macOS meeting assistant.
