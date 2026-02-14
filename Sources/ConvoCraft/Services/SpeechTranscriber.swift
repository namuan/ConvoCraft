import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechTranscriber: NSObject, ObservableObject {
    @Published var isTranscribing = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var transcriptContinuation: AsyncStream<(String, Bool)>.Continuation?
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
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
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
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
