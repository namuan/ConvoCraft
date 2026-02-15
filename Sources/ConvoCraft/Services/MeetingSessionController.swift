import Foundation
import Observation

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

@MainActor
@Observable
class MeetingSessionController {
    // Published state
    var isRecording = false
    var currentTranscript: [TranscriptSegment] = []
    var partialTranscript: String = ""
    var insights: [IntelligenceInsight] = []
    var errorMessage: String?
    var lastSummary: MeetingSummary?
    
    // Services
    private let audioCaptureManager = AudioCaptureManager()
    private let speechTranscriber = SpeechTranscriber()
    private let transcriptStore = TranscriptStore()
    private let intelligenceEngine = IntelligenceEngine()
    private let summaryEngine = SummaryEngine()
    private let persistenceLayer = PersistenceLayer()
    
    // Session tracking
    private var sessionStartTime: Date?
    private var captureTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    
    func startMeeting() async {
        logInfo("🎬 startMeeting() called")
        
        guard !isRecording else {
            logWarning("Already recording, ignoring start request")
            return
        }
        
        logInfo("Checking all permissions...")
        // Check all permissions before starting
        let permissionsValid = await checkAllPermissions()
        if !permissionsValid {
            logError("Permissions check failed: \(errorMessage ?? "Unknown error")")
            return
        }
        logSuccess("All permissions granted!")
        
        sessionStartTime = Date()
        isRecording = true
        errorMessage = nil
        
        logInfo("Clearing previous data...")
        // Clear previous data
        await transcriptStore.clear()
        await intelligenceEngine.clearInsights()
        currentTranscript = []
        partialTranscript = ""
        insights = []
        logSuccess("Previous data cleared")
        
        logInfo("Starting transcription flow...")
        // Start transcription
        startTranscriptionFlow()
        
        logInfo("Starting periodic analysis...")
        // Start periodic analysis
        startPeriodicAnalysis()
        
        logSuccess("Meeting started successfully!")
        Logger.shared.logSeparator()
    }
    
    func stopMeeting() async {
        logInfo("🛑 stopMeeting() called")
        
        guard isRecording else {
            logWarning("Not recording, ignoring stop request")
            return
        }
        
        logInfo("Stopping all tasks...")
        // Stop all tasks
        captureTask?.cancel()
        transcriptionTask?.cancel()
        analysisTask?.cancel()
        
        logInfo("Stopping speech transcriber...")
        speechTranscriber.stopTranscription()
        
        logInfo("Stopping audio capture...")
        await audioCaptureManager.stopCapture()
        
        isRecording = false
        logSuccess("Meeting stopped")
        
        // Finalize any partial transcript before generating summary
        logInfo("Finalizing partial transcripts...")
        await transcriptStore.finalizeCurrent()
        
        // Log final state with detailed segment info
        let finalSegments = await transcriptStore.getAllSegments()
        logInfo("📊 Final transcript has \(finalSegments.count) segments before summary generation")
        if !finalSegments.isEmpty {
            for (index, seg) in finalSegments.enumerated() {
                logDebug("  Segment #\(index + 1): \(seg.text.prefix(60))... [\(seg.text.count) chars]")
            }
        }
        
        logInfo("Generating final summary...")
        // Generate final summary
        await generateFinalSummary()
        Logger.shared.logSeparator()
    }
    
    private func startTranscriptionFlow() {
        logInfo("📝 Starting transcription flow with system audio capture...")
        transcriptionTask = Task {
            do {
                logInfo("Starting audio capture from system...")
                let audioStream = try await audioCaptureManager.startCapture()
                logSuccess("Audio capture stream obtained")
                
                logInfo("Requesting transcription with captured audio stream...")
                let transcriptStream = try await speechTranscriber.startTranscription(with: audioStream)
                logSuccess("Transcription stream obtained, listening for results...")
                
                for await (text, isFinal) in transcriptStream {
                    guard !Task.isCancelled else { break }
                    
                    logDebug("📥 Received: isFinal=\(isFinal), length=\(text.count), text=\(text.prefix(100))...")
                    
                    let timestamp = Date().timeIntervalSince1970
                    let segment = TranscriptSegment(
                        text: text,
                        timestamp: timestamp,
                        isFinal: isFinal
                    )
                    
                    if isFinal {
                        logInfo("✅ FINAL segment received, adding to store")
                        await transcriptStore.addFinalSegment(segment)
                        
                        // Verify it was added and show total
                        let allSegs = await transcriptStore.getAllSegments()
                        logInfo("📊 Store now has \(allSegs.count) segments, total chars: \(allSegs.reduce(0) { $0 + $1.text.count })")
                        
                        await updateCurrentTranscript()
                        partialTranscript = ""
                    } else {
                        logDebug("⏳ Partial segment, updating UI")
                        await transcriptStore.addPartialSegment(segment)
                        partialTranscript = text
                    }
                }
                logWarning("Transcription stream ended")
            } catch {
                let errorMsg = "Transcription error: \(error.localizedDescription)"
                logError(errorMsg)
                errorMessage = errorMsg
            }
        }
    }
    
    private func startPeriodicAnalysis() {
        logInfo("📊 Starting periodic analysis task...")
        analysisTask = Task {
            var analysisCount = 0
            while !Task.isCancelled {
                // Wait 10 seconds between analyses
                try? await Task.sleep(for: .seconds(10))
                
                guard !Task.isCancelled else {
                    logInfo("🚫 Periodic analysis cancelled")
                    break
                }
                
                analysisCount += 1
                logDebug("🔄 Periodic analysis cycle #\(analysisCount)")
                
                // Finalize any accumulated partial segment periodically
                let partialCount = await transcriptStore.getPartialSegment() != nil ? 1 : 0
                if partialCount > 0 {
                    logInfo("⏱ Finalizing partial segment (periodic)")
                    await transcriptStore.finalizeCurrent()
                }
                
                // Get recent transcript
                let recentSegments = await transcriptStore.getRecentTranscript(lastMinutes: 2.0)
                logInfo("📝 Got \(recentSegments.count) recent transcript segments (last 2 minutes)")
                
                if !recentSegments.isEmpty {
                    // Log segment content
                    let sampleText = recentSegments.first?.text ?? ""
                    logDebug("📤 Sample text: \(sampleText.prefix(50))...")
                    
                    // Analyze and get insights
                    logDebug("🧠 Calling IntelligenceEngine.analyzeTranscript...")
                    let newInsights = await intelligenceEngine.analyzeTranscript(recentSegments)
                    logInfo("✨ Generated \(newInsights.count) new insights")
                    
                    // Update UI on MainActor
                    let allInsights = await intelligenceEngine.getAllInsights()
                    logInfo("📊 Total insights: \(allInsights.count), showing last 10")
                    
                    await MainActor.run {
                        self.insights = Array(allInsights.suffix(10)) // Show last 10 insights
                        logSuccess("✅ Updated insights array on MainActor")
                    }
                    
                    if !newInsights.isEmpty {
                        logSuccess("✅ Updated UI with insights")
                    }
                } else {
                    logWarning("⚠️ No recent segments to analyze")
                }
            }
        }
    }
    
    private func updateCurrentTranscript() async {
        currentTranscript = await transcriptStore.getAllSegments()
    }
    
    private func checkAllPermissions() async -> Bool {
        logInfo("🔐 Checking all permissions...")
        
        logDebug("Requesting speech recognition authorization...")
        let speechAuth = await speechTranscriber.requestAuthorization()
        speechTranscriber.updateAuthorizationStatus(speechAuth)
        logInfo("Speech recognition status: \(speechAuth.rawValue)")
        
        guard speechAuth == .authorized else {
            return setPermissionError("⚠️ Speech recognition permission required. Please grant permission in System Settings.")
        }
        
        logDebug("Checking microphone permission...")
        let micGranted = await speechTranscriber.requestMicrophonePermission()
        logInfo("Microphone permission: \(micGranted ? "granted" : "denied")")
        
        guard micGranted else {
            return setPermissionError("⚠️ Microphone permission required. Please grant permission in System Settings.")
        }
        
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else {
            return setPermissionError("⚠️ macOS 12.3 or later is required for audio capture.")
        }
        
        logDebug("Checking screen recording permission...")
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            logSuccess("Screen recording permission granted")
        } catch {
            logError("Screen recording permission check failed: \(error.localizedDescription)")
            return setPermissionError("⚠️ Screen Recording permission required. Please grant permission in System Settings > Privacy & Security > Screen Recording.")
        }
        #endif
        
        logSuccess("All permissions validated!")
        return true
    }
    
    private func setPermissionError(_ message: String) -> Bool {
        errorMessage = message
        logError(message)
        return false
    }
    
    private func generateFinalSummary() async {
        guard let startTime = sessionStartTime else {
            logWarning("No start time for session")
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let allSegments = await transcriptStore.getAllSegments()
        let allInsights = await intelligenceEngine.getAllInsights()
        
        logInfo("📊 Generating final summary...")
        logInfo("   Duration: \(Int(duration))s")
        logInfo("   Segments: \(allSegments.count)")
        logInfo("   Insights: \(allInsights.count)")
        
        if allSegments.isEmpty {
            logWarning("⚠️ No transcript segments were captured during this meeting!")
        } else {
            let totalChars = allSegments.reduce(0) { $0 + $1.text.count }
            logInfo("   Total transcript chars: \(totalChars)")
        }
        
        let summary = await summaryEngine.generateSummary(
            from: allSegments,
            insights: allInsights,
            duration: duration
        )
        
        logInfo("📝 Summary generated with \(summary.transcript.count) segments")
        
        // Save summary
        do {
            try await persistenceLayer.saveSummary(summary)
            lastSummary = summary
            logSuccess("✅ Summary saved successfully")
        } catch {
            let errorMsg = "Failed to save summary: \(error.localizedDescription)"
            logError(errorMsg)
            errorMessage = errorMsg
        }
    }
    
    func loadPreviousSummaries() async -> [MeetingSummary] {
        do {
            return try await persistenceLayer.loadAllSummaries()
        } catch {
            errorMessage = "Failed to load summaries: \(error.localizedDescription)"
            return []
        }
    }
    
    func deleteSummary(_ summary: MeetingSummary) async throws {
        try await persistenceLayer.deleteSummary(summary)
    }
    
    func deleteSummaries(_ summaries: [MeetingSummary]) async throws {
        try await persistenceLayer.deleteSummaries(summaries)
    }
}
