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
        guard speechRecognizer?.isAvailable == true else {
            throw TranscriptionError.recognizerNotAvailable
        }
        
        guard authorizationStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        
        // Create async stream for transcription results
        let stream = AsyncStream<(String, Bool)> { continuation in
            self.transcriptContinuation = continuation
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    self.transcriptContinuation?.yield((transcribedText, isFinal))
                    
                    if isFinal {
                        self.stopTranscription()
                    }
                }
                
                if let error = error {
                    print("Recognition error: \(error)")
                    self.transcriptContinuation?.finish()
                }
            }
        }
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        
        // Set up audio tap using nonisolated helper to avoid actor isolation issues
        setupAudioTap(inputNode: inputNode, recognitionRequest: recognitionRequest)
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isTranscribing = true
        
        return stream
    }
    
    func stopTranscription() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
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
