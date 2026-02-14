import Foundation
import Observation

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
        guard !isRecording else { return }
        
        // Request speech recognition authorization
        let authStatus = await speechTranscriber.requestAuthorization()
        speechTranscriber.updateAuthorizationStatus(authStatus)
        guard authStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        // Request microphone permission
        let micGranted = await speechTranscriber.requestMicrophonePermission()
        guard micGranted else {
            errorMessage = "Microphone not authorized"
            return
        }
        
        sessionStartTime = Date()
        isRecording = true
        errorMessage = nil
        
        // Clear previous data
        await transcriptStore.clear()
        await intelligenceEngine.clearInsights()
        currentTranscript = []
        partialTranscript = ""
        insights = []
        
        // Start transcription
        startTranscriptionFlow()
        
        // Start periodic analysis
        startPeriodicAnalysis()
    }
    
    func stopMeeting() async {
        guard isRecording else { return }
        
        // Stop all tasks
        captureTask?.cancel()
        transcriptionTask?.cancel()
        analysisTask?.cancel()
        
        speechTranscriber.stopTranscription()
        await audioCaptureManager.stopCapture()
        
        isRecording = false
        
        // Generate final summary
        await generateFinalSummary()
    }
    
    private func startTranscriptionFlow() {
        transcriptionTask = Task {
            do {
                let stream = try await speechTranscriber.startTranscription()
                
                for await (text, isFinal) in stream {
                    guard !Task.isCancelled else { break }
                    
                    let timestamp = Date().timeIntervalSince1970
                    let segment = TranscriptSegment(
                        text: text,
                        timestamp: timestamp,
                        isFinal: isFinal
                    )
                    
                    if isFinal {
                        await transcriptStore.addFinalSegment(segment)
                        await updateCurrentTranscript()
                        partialTranscript = ""
                    } else {
                        await transcriptStore.addPartialSegment(segment)
                        partialTranscript = text
                    }
                }
            } catch {
                errorMessage = "Transcription error: \(error.localizedDescription)"
            }
        }
    }
    
    private func startPeriodicAnalysis() {
        analysisTask = Task {
            while !Task.isCancelled {
                // Wait 10 seconds between analyses
                try? await Task.sleep(for: .seconds(10))
                
                guard !Task.isCancelled else { break }
                
                // Get recent transcript
                let recentSegments = await transcriptStore.getRecentTranscript(lastMinutes: 2.0)
                
                if !recentSegments.isEmpty {
                    // Analyze and get insights
                    let _ = await intelligenceEngine.analyzeTranscript(recentSegments)
                    
                    // Update UI
                    let allInsights = await intelligenceEngine.getAllInsights()
                    self.insights = Array(allInsights.suffix(10)) // Show last 10 insights
                }
            }
        }
    }
    
    private func updateCurrentTranscript() async {
        currentTranscript = await transcriptStore.getAllSegments()
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
