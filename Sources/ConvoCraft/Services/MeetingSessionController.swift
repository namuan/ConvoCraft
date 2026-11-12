import Foundation
import Observation

@MainActor
@Observable
class MeetingSessionController {
    // Published state
    var isRecording = false
    var currentTranscript: [TranscriptSegment] = []
    var partialTranscript: String {
        AudioSource.allCases.compactMap { source in
            guard let text = partialTranscripts[source], !text.isEmpty else { return nil }
            return "\(source.displayName): \(text)"
        }.joined(separator: "\n")
    }
    private var partialTranscripts: [AudioSource: String] = [:]
    var insights: [IntelligenceInsight] = []
    var errorMessage: String?
    var lastSummary: MeetingSummary?
    
    // Services
    private let microphoneTranscriber = SpeechTranscriber(source: .microphone)
    private let systemTranscriber = SpeechTranscriber(source: .system)
    private let audioCaptureManager = AudioCaptureManager()
    private let microphoneTranscriptStore = TranscriptStore()
    private let systemTranscriptStore = TranscriptStore()
    private let intelligenceEngine = IntelligenceEngine()
    private let summaryEngine = SummaryEngine()
    private let persistenceLayer = PersistenceLayer()
    
    // Session tracking
    private var sessionStartTime: Date?
    private var captureTask: Task<Void, Never>?
    private var transcriptionTasks: [Task<Void, Never>] = []
    private var audioWriter: AudioRecordingWriter?
    private var analysisTask: Task<Void, Never>?
    private var lastAnalyzedTextHash: Int?
    
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
        
        let startDate = Date()
        sessionStartTime = startDate
        errorMessage = nil
        
        logInfo("Clearing previous data...")
        // Clear previous data
        await microphoneTranscriptStore.clear()
        await systemTranscriptStore.clear()
        await intelligenceEngine.clearInsights()
        currentTranscript = []
        partialTranscripts = [:]
        insights = []
        logSuccess("Previous data cleared")

        do {
            let stream = try await audioCaptureManager.startCapture()
            audioWriter = try AudioRecordingWriter(startDate: startDate)
            try await startTranscriptionFlows()
            isRecording = true
            startAudioFlow(stream)
        } catch {
            audioCaptureManager.stopCapture()
            microphoneTranscriber.stopTranscription()
            systemTranscriber.stopTranscription()
            errorMessage = "Could not start audio recording: \(error.localizedDescription)"
            logError(errorMessage ?? "Could not start audio recording")
            return
        }
        
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
        analysisTask?.cancel()
        audioCaptureManager.stopCapture()
        await captureTask?.value
        captureTask = nil

        logInfo("Stopping speech transcribers...")
        microphoneTranscriber.stopTranscription()
        systemTranscriber.stopTranscription()
        transcriptionTasks.forEach { $0.cancel() }
        transcriptionTasks.removeAll()
        do {
            let paths = try await audioWriter?.finish() ?? []
            logInfo("Saved meeting audio: \(paths.joined(separator: ", "))")
        } catch {
            errorMessage = "Could not finalize meeting audio: \(error.localizedDescription)"
            logError(errorMessage ?? "Could not finalize meeting audio")
        }
        audioWriter = nil

        isRecording = false
        logSuccess("Meeting stopped")
        
        // Finalize any partial transcript before generating summary
        logInfo("Finalizing partial transcripts...")
        await microphoneTranscriptStore.finalizeCurrent()
        await systemTranscriptStore.finalizeCurrent()

        // Log final state with detailed segment info
        let finalSegments = await allTranscriptSegments()
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
    
    private func startTranscriptionFlows() async throws {
        let speechAuth = await microphoneTranscriber.requestAuthorization()
        microphoneTranscriber.updateAuthorizationStatus(speechAuth)
        systemTranscriber.updateAuthorizationStatus(speechAuth)
        let microphoneStream = try microphoneTranscriber.startTranscription()
        let systemStream = try systemTranscriber.startTranscription()
        transcriptionTasks = [
            consumeTranscription(microphoneStream, source: .microphone),
            consumeTranscription(systemStream, source: .system)
        ]
    }

    private func startAudioFlow(_ stream: AsyncStream<AudioChunk>) {
        captureTask = Task {
            for await chunk in stream {
                guard !Task.isCancelled else { break }
                switch chunk.source {
                case .microphone:
                    microphoneTranscriber.append(chunk.samples)
                case .system:
                    systemTranscriber.append(chunk.samples)
                }
                do {
                    try await audioWriter?.append(chunk)
                } catch {
                    errorMessage = "Could not save meeting audio: \(error.localizedDescription)"
                    logError(errorMessage ?? "Could not save meeting audio")
                }
            }
        }
    }

    private func consumeTranscription(_ stream: AsyncStream<(String, Bool)>, source: AudioSource) -> Task<Void, Never> {
        Task {
            for await (text, isFinal) in stream {
                guard !Task.isCancelled else { break }
                let segment = TranscriptSegment(
                    text: text,
                    timestamp: Date().timeIntervalSince1970,
                    isFinal: isFinal,
                    source: source
                )
                let store = source == .microphone ? microphoneTranscriptStore : systemTranscriptStore
                if isFinal {
                    await store.addFinalSegment(segment)
                    partialTranscripts[source] = nil
                    await updateCurrentTranscript()
                } else {
                    await store.addPartialSegment(segment)
                    partialTranscripts[source] = text
                }
            }
        }
    }

    private func allTranscriptSegments() async -> [TranscriptSegment] {
        let microphone = await microphoneTranscriptStore.getAllSegments()
        let system = await systemTranscriptStore.getAllSegments()
        return (microphone + system).sorted { $0.timestamp < $1.timestamp }
    }
    
    private func startPeriodicAnalysis() {
        logInfo("📊 Starting periodic analysis task...")
        analysisTask = Task {
            var analysisCount = 0
            while !Task.isCancelled {
                // Wait 20 seconds between analyses
                try? await Task.sleep(for: .seconds(20))
                
                guard !Task.isCancelled else {
                    logInfo("🚫 Periodic analysis cancelled")
                    break
                }
                
                analysisCount += 1
                logDebug("🔄 Periodic analysis cycle #\(analysisCount)")
                
                // Finalize any accumulated partial segment periodically
                if await microphoneTranscriptStore.getPartialSegment() != nil {
                    await microphoneTranscriptStore.finalizeCurrent()
                }
                if await systemTranscriptStore.getPartialSegment() != nil {
                    await systemTranscriptStore.finalizeCurrent()
                }
                await updateCurrentTranscript()

                // Get recent transcript
                let cutoff = Date().timeIntervalSince1970 - 120
                let recentSegments = await allTranscriptSegments().filter { $0.timestamp >= cutoff }
                logInfo("📝 Got \(recentSegments.count) recent transcript segments (last 2 minutes)")
                
                if !recentSegments.isEmpty {
                    let recentText = recentSegments.map { $0.text }.joined(separator: " ")
                    let textHash = recentText.hash
                    
                    guard textHash != lastAnalyzedTextHash else {
                        logDebug("⏭ Skipping analysis cycle — no new transcript content")
                        continue
                    }
                    lastAnalyzedTextHash = textHash
                    
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
        currentTranscript = await allTranscriptSegments()
    }
    
    private func checkAllPermissions() async -> Bool {
        logInfo("🔐 Checking all permissions...")
        
        logDebug("Requesting speech recognition authorization...")
        let speechAuth = await microphoneTranscriber.requestAuthorization()
        microphoneTranscriber.updateAuthorizationStatus(speechAuth)
        systemTranscriber.updateAuthorizationStatus(speechAuth)
        logInfo("Speech recognition status: \(speechAuth.rawValue)")
        
        guard speechAuth == .authorized else {
            return setPermissionError("⚠️ Speech recognition permission required. Please grant permission in System Settings.")
        }
        
        logDebug("Checking microphone permission...")
        let micGranted = await microphoneTranscriber.requestMicrophonePermission()
        logInfo("Microphone permission: \(micGranted ? "granted" : "denied")")
        
        guard micGranted else {
            return setPermissionError("⚠️ Microphone permission required. Please grant permission in System Settings.")
        }
        
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
        let allSegments = await allTranscriptSegments()
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
