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
        logInfo("📹 AudioCaptureManager.startCapture() called")
        
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else {
            logError("macOS 12.3+ required for ScreenCaptureKit")
            throw CaptureError.unsupportedOS
        }
        logDebug("ScreenCaptureKit available")
        
        // Request permission
        logDebug("Requesting screen recording permission...")
        do {
            try await requestPermission()
            logSuccess("Screen recording permission granted")
        } catch {
            logError("Permission denied: \(error.localizedDescription)")
            throw CaptureError.permissionDenied
        }
        
        // Create async stream for audio data
        logDebug("Creating audio data stream...")
        let audioStream = AsyncStream<Data> { continuation in
            self.continuation = continuation
        }
        logSuccess("Audio stream created")
        
        // Configure capture
        logDebug("Configuring audio capture stream...")
        try await configureCaptureStream()
        logSuccess("Capture stream configured")
        
        isCapturing = true
        logSuccess("✅ Audio capture started!")
        Logger.shared.logSeparator()
        return audioStream
        #else
        throw CaptureError.unsupportedPlatform
        #endif
    }
    
    func stopCapture() async {
        logInfo("🛑 Stopping audio capture...")
        
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else {
            logWarning("macOS too old for ScreenCaptureKit")
            return
        }
        
        if let stream = stream as? SCStream {
            logDebug("Stopping SCStream...")
            try? await stream.stopCapture()
            logSuccess("SCStream stopped")
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
        // Check if we have screen recording permission by attempting to get shareable content
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            // If we get here, permission is granted
        } catch {
            // Permission denied or not granted yet
            throw CaptureError.permissionDenied
        }
    }
    
    @available(macOS 12.3, *)
    private func configureCaptureStream() async throws {
        logInfo("⚙️ Configuring capture stream...")
        
        // Get available content
        logDebug("Getting shareable content...")
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        logInfo("📺 Found \(content.displays.count) displays, \(content.windows.count) windows, \(content.applications.count) applications")
        
        // For now, capture system audio
        logDebug("Creating SCStreamConfiguration...")
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 1
        config.excludesCurrentProcessAudio = false
        logInfo("🎵 Audio config: sampleRate=\(config.sampleRate), channels=\(config.channelCount), capturesAudio=\(config.capturesAudio)")
        
        // Capture microphone if available (macOS 15.0+)
        if #available(macOS 15.0, *) {
            config.captureMicrophone = true
            logInfo("🎤 Microphone capture enabled (macOS 15.0+)")
        } else {
            logInfo("⚠️ Microphone capture not available (requires macOS 15.0+)")
        }
        
        // Create filter (empty for system-wide audio)
        logDebug("Creating SCContentFilter...")
        let filter = SCContentFilter()
        logDebug("Filter created (empty for system-wide audio)")
        
        // Create stream
        logDebug("Creating SCStream...")
        let captureStream = SCStream(filter: filter, configuration: config, delegate: self)
        logSuccess("SCStream created")
        
        // Start capture
        logDebug("Starting SCStream capture...")
        try await captureStream.startCapture()
        logSuccess("🟢 SCStream capture started!")
        
        self.stream = captureStream
        logSuccess("AudioCaptureManager fully configured")
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
            logError("🛑 Stream stopped with error: \(error.localizedDescription)")
            print("Stream stopped with error: \(error)")
            self.isCapturing = false
        }
    }
}

@available(macOS 12.3, *)
extension AudioCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        logDebug("🎵 Audio sample buffer received (type=audio)")
        
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
        
        logWarning("⚠️ PLACEHOLDER: Audio buffer received but not processed (yielding empty data)")
        
        Task { @MainActor in
            if let continuation = self.continuation {
                continuation.yield(Data())
                logDebug("Yielded empty audio data (placeholder)")
            } else {
                logWarning("No continuation available to yield audio data")
            }
        }
    }
}
#endif
