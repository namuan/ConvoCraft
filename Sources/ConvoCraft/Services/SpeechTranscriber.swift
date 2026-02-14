import Foundation
import Speech
import AVFoundation
import AVFAudio

@MainActor
class SpeechTranscriber: NSObject, ObservableObject {
    @Published var isTranscribing = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var transcriptContinuation: AsyncStream<(String, Bool)>.Continuation?
    
    nonisolated func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func updateAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) {
        self.authorizationStatus = status
    }
    
    // Helper function to set up audio tap without actor isolation issues
    nonisolated private func setupAudioTap(
        inputNode: AVAudioInputNode,
        recognitionRequest: SFSpeechAudioBufferRecognitionRequest
    ) {
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
            // This closure runs on a real-time audio thread
            // recognitionRequest.append() is thread-safe
            recognitionRequest.append(buffer)
        }
    }
    
    func startTranscription() async throws -> AsyncStream<(String, Bool)> {
        logInfo("🎬 SpeechTranscriber.startTranscription() called")
        
        guard speechRecognizer?.isAvailable == true else {
            logError("Speech recognizer is not available")
            throw TranscriptionError.recognizerNotAvailable
        }
        logDebug("Speech recognizer is available")
        
        guard authorizationStatus == .authorized else {
            logError("Speech recognition not authorized, status: \(authorizationStatus.rawValue)")
            throw TranscriptionError.notAuthorized
        }
        logSuccess("Speech recognition is authorized")
        
        // Create recognition request
        logDebug("Creating SFSpeechAudioBufferRecognitionRequest...")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            logError("Failed to create recognition request")
            throw TranscriptionError.failedToCreateRequest
        }
        logSuccess("Recognition request created")
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        logDebug("Recognition request configured: partialResults=true, onDevice=true")
        
        // Create async stream for transcription results
        logDebug("Creating AsyncStream for transcription results...")
        let stream = AsyncStream<(String, Bool)> { continuation in
            self.transcriptContinuation = continuation
        }
        logSuccess("AsyncStream created")
        
        // Start recognition task
        logDebug("Starting recognition task...")
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    logDebug("🗣 Transcription result: isFinal=\(isFinal), length=\(transcribedText.count) chars")
                    self.transcriptContinuation?.yield((transcribedText, isFinal))
                    
                    if isFinal {
                        logInfo("Final transcription received, stopping...")
                        self.stopTranscription()
                    }
                }
                
                if let error = error {
                    logError("Recognition error: \(error.localizedDescription)")
                    print("Recognition error: \(error)")
                    self.transcriptContinuation?.finish()
                }
            }
        }
        
        if recognitionTask == nil {
            logError("Failed to create recognition task")
            throw TranscriptionError.failedToCreateRequest
        }
        logSuccess("Recognition task started")
        
        // Configure audio engine
        logDebug("Configuring audio engine...")
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        logInfo("🎤 Audio format: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
        
        // Set up audio tap using nonisolated helper to avoid actor isolation issues
        logDebug("Installing audio tap on input node...")
        setupAudioTap(inputNode: inputNode, recognitionRequest: recognitionRequest)
        logSuccess("Audio tap installed")
        
        logDebug("Preparing audio engine...")
        audioEngine.prepare()
        logDebug("Starting audio engine...")
        try audioEngine.start()
        logSuccess("🎵 Audio engine started successfully!")
        
        isTranscribing = true
        logSuccess("✅ Transcription started successfully!")
        Logger.shared.logSeparator()
        
        return stream
    }
    
    func stopTranscription() {
        logInfo("🛑 Stopping transcription...")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        logDebug("Audio engine stopped and tap removed")
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        transcriptContinuation?.finish()
        transcriptContinuation = nil
        
        isTranscribing = false
    }
    
    enum TranscriptionError: LocalizedError {
        case recognizerNotAvailable
        case notAuthorized
        case failedToCreateRequest
        
        var errorDescription: String? {
            switch self {
            case .recognizerNotAvailable:
                return "Speech recognizer is not available"
            case .notAuthorized:
                return "Speech recognition not authorized"
            case .failedToCreateRequest:
                return "Failed to create recognition request"
            }
        }
    }
}
