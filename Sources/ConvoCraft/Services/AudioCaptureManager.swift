import Foundation
import AVFoundation
import CoreMedia

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
            logDebug("Removing stream output...")
            do {
                try stream.removeStreamOutput(self, type: .audio)
                logSuccess("Stream output removed")
            } catch {
                logWarning("Failed to remove stream output: \(error.localizedDescription)")
            }
            
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
        
        // Create filter - need to specify at least one display for audio capture
        logDebug("Creating SCContentFilter...")
        guard let display = content.displays.first else {
            logError("No displays found")
            throw CaptureError.captureNotAvailable
        }
        logInfo("📺 Using display: \(display.displayID) for audio capture")
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        logDebug("Filter created with display for system-wide audio")
        
        // Create stream
        logDebug("Creating SCStream...")
        let captureStream = SCStream(filter: filter, configuration: config, delegate: self)
        logSuccess("SCStream created")
        
        // Add output handler to receive audio samples
        do {
            logDebug("Adding stream output handler...")
            try captureStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            logSuccess("Stream output handler added")
        } catch {
            logError("Failed to add stream output: \(error.localizedDescription)")
            throw error
        }
        
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
        
        // Get audio format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            logWarning("⚠️ Failed to get format description from sample buffer")
            return
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        
        // Extract audio buffer from CMSampleBuffer
        guard let blockBufferRef = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            logWarning("⚠️ Failed to get data buffer from sample buffer")
            return
        }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(
            blockBufferRef,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        
        guard status == kCMBlockBufferNoErr, let dataPointer = dataPointer, length > 0 else {
            logWarning("⚠️ Failed to get data pointer from block buffer or empty data")
            return
        }
        
        // Convert to Data
        let audioData = Data(bytes: dataPointer, count: length)
        
        if let streamDesc = audioStreamBasicDescription?.pointee {
            logDebug("🎵 Audio sample: \(audioData.count) bytes, \(streamDesc.mSampleRate)Hz, \(streamDesc.mChannelsPerFrame)ch")
        } else {
            logDebug("🎵 Audio sample: \(audioData.count) bytes")
        }
        
        Task { @MainActor in
            if let continuation = self.continuation {
                continuation.yield(audioData)
            }
        }
    }
}
#endif
