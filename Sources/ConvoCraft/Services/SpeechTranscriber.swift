import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechTranscriber: NSObject, ObservableObject {
    @Published var isTranscribing = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    let source: AudioSource
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var transcriptContinuation: AsyncStream<(String, Bool)>.Continuation?

    init(source: AudioSource) {
        self.source = source
    }

    nonisolated func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func updateAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) {
        authorizationStatus = status
    }

    func startTranscription() throws -> AsyncStream<(String, Bool)> {
        guard speechRecognizer?.isAvailable == true else {
            throw TranscriptionError.recognizerNotAvailable
        }
        guard authorizationStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let stream = AsyncStream<(String, Bool)> { continuation in
            transcriptContinuation = continuation
        }
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcriptContinuation?.yield((result.bestTranscription.formattedString, result.isFinal))
                }
                if let error {
                    logError("\(self.source.displayName) recognition error: \(error.localizedDescription)")
                    self.transcriptContinuation?.finish()
                }
            }
        }
        isTranscribing = true
        return stream
    }

    func append(_ samples: [Float]) {
        guard !samples.isEmpty, let request = recognitionRequest,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        channel.update(from: samples, count: samples.count)
        request.append(buffer)
    }

    func stopTranscription() {
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

        var errorDescription: String? {
            switch self {
            case .recognizerNotAvailable: "Speech recognizer is not available"
            case .notAuthorized: "Speech recognition not authorized"
            }
        }
    }
}
