import Foundation
import AVFoundation

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

@MainActor
class AudioCaptureManager: NSObject, ObservableObject {
    @Published var isCapturing = false
    private var stream: Any? // Will be SCStream on macOS
    private var continuation: AsyncStream<Data>.Continuation?
    
    func startCapture() async throws -> AsyncStream<Data> {
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else {
            throw CaptureError.unsupportedOS
        }
        
        // Request permission
        do {
            try await requestPermission()
        } catch {
            throw CaptureError.permissionDenied
        }
        
        // Create async stream for audio data
        let audioStream = AsyncStream<Data> { continuation in
            self.continuation = continuation
        }
        
        // Configure capture
        try await configureCaptureStream()
        
        isCapturing = true
        return audioStream
        #else
        throw CaptureError.unsupportedPlatform
        #endif
    }
    
    func stopCapture() async {
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else { return }
        
        if let stream = stream as? SCStream {
            try? await stream.stopCapture()
        }
        #endif
        
        continuation?.finish()
        continuation = nil
        stream = nil
        isCapturing = false
    }
    
    #if canImport(ScreenCaptureKit)
    @available(macOS 12.3, *)
    private func requestPermission() async throws {
        guard await SCContentSharingSession.isAvailable else {
            throw CaptureError.captureNotAvailable
        }
    }
    
    @available(macOS 12.3, *)
    private func configureCaptureStream() async throws {
        // Get available content
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        
        // For now, capture system audio
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 1
        config.excludesCurrentProcessAudio = false
        
        // Capture microphone if available
        if #available(macOS 14.0, *) {
            config.captureMicrophone = true
        }
        
        // Create filter (empty for system-wide audio)
        let filter = SCContentFilter()
        
        // Create stream
        let captureStream = SCStream(filter: filter, configuration: config, delegate: self)
        
        // Start capture
        try await captureStream.startCapture()
        
        self.stream = captureStream
    }
    #endif
    
    enum CaptureError: LocalizedError {
        case unsupportedOS
        case unsupportedPlatform
        case permissionDenied
        case captureNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .unsupportedOS:
                return "macOS 12.3 or later is required"
            case .unsupportedPlatform:
                return "ScreenCaptureKit is only available on macOS"
            case .permissionDenied:
                return "Screen recording permission denied"
            case .captureNotAvailable:
                return "Screen capture is not available"
            }
        }
    }
}

#if canImport(ScreenCaptureKit)
@available(macOS 12.3, *)
extension AudioCaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            print("Stream stopped with error: \(error)")
            self.isCapturing = false
        }
    }
}

@available(macOS 12.3, *)
extension AudioCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // TODO: Convert CMSampleBuffer to actual PCM audio data
        // This requires:
        // 1. Extract audio buffer list from CMSampleBuffer
        // 2. Convert to AVAudioPCMBuffer format
        // 3. Extract raw PCM data as Data
        // 4. Yield the audio data through the continuation
        //
        // Current implementation is a placeholder that signals audio was received
        // but doesn't provide usable audio data. This needs to be implemented
        // for actual audio processing and transcription to work.
        Task { @MainActor in
            if let continuation = self.continuation {
                continuation.yield(Data())
            }
        }
    }
}
#endif
