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
        
        logInfo("Generating final summary...")
        // Generate final summary
        await generateFinalSummary()
        Logger.shared.logSeparator()
    }
    
    private func startTranscriptionFlow() {
        logInfo("📝 Starting transcription flow...")
        transcriptionTask = Task {
            do {
                logInfo("Requesting transcription stream from SpeechTranscriber...")
                let stream = try await speechTranscriber.startTranscription()
                logSuccess("Transcription stream obtained, listening for results...")
                
                for await (text, isFinal) in stream {
                    logDebug("Received transcription: isFinal=\(isFinal), text=\(text.prefix(50))...")
                    guard !Task.isCancelled else { break }
                    
                    let timestamp = Date().timeIntervalSince1970
                    let segment = TranscriptSegment(
                        text: text,
                        timestamp: timestamp,
                        isFinal: isFinal
                    )
                    
                    if isFinal {
                        logInfo("Final transcript segment received")
                        await transcriptStore.addFinalSegment(segment)
                        await updateCurrentTranscript()
                        partialTranscript = ""
                    } else {
                        logDebug("Partial transcript segment received")
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
        
        // Check speech recognition
        logDebug("Requesting speech recognition authorization...")
        let speechAuth = await speechTranscriber.requestAuthorization()
        speechTranscriber.updateAuthorizationStatus(speechAuth)
        logInfo("Speech recognition status: \(speechAuth.rawValue)")
        if speechAuth != .authorized {
            errorMessage = "⚠️ Speech recognition permission required. Please grant permission in System Settings."
            return false
        }
        
        // Check microphone
        logDebug("Checking microphone permission...")
        let micGranted = await speechTranscriber.requestMicrophonePermission()
        logInfo("Microphone permission: \(micGranted ? "granted" : "denied")")
        if !micGranted {
            errorMessage = "⚠️ Microphone permission required. Please grant permission in System Settings."
            return false
        }
        
        // Check screen recording (for audio capture)
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else {
            let msg = "⚠️ macOS 12.3 or later is required for audio capture."
            logError(msg)
            errorMessage = msg
            return false
        }
        
        logDebug("Checking screen recording permission...")
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            logSuccess("Screen recording permission granted")
        } catch {
            let msg = "⚠️ Screen Recording permission required. Please grant permission in System Settings > Privacy & Security > Screen Recording."
            logError("Screen recording permission check failed: \(error.localizedDescription)")
            errorMessage = msg
            return false
        }
        #endif
        
        logSuccess("All permissions validated!")
        return true
    }
    
    private func generateFinalSummary() async {
        guard let startTime = sessionStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let allSegments = await transcriptStore.getAllSegments()
        let allInsights = await intelligenceEngine.getAllInsights()
        
        let summary = await summaryEngine.generateSummary(
            from: allSegments,
            insights: allInsights,
            duration: duration
        )
        
        // Save summary
        do {
            try await persistenceLayer.saveSummary(summary)
            lastSummary = summary
        } catch {
            errorMessage = "Failed to save summary: \(error.localizedDescription)"
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
}
