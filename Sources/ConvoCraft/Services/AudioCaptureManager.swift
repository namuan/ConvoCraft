import AVFoundation
import CoreAudio
import Foundation

@MainActor
final class AudioCaptureManager: ObservableObject {
    @Published private(set) var isCapturing = false

    private let audioEngine = AVAudioEngine()
    private var systemTap: CoreAudioSystemTap?
    private var continuation: AsyncStream<AudioChunk>.Continuation?

    func startCapture() async throws -> AsyncStream<AudioChunk> {
        guard !isCapturing else { throw CaptureError.alreadyCapturing }
        let stream = AsyncStream<AudioChunk> { continuation in
            self.continuation = continuation
        }
        guard let continuation else { throw CaptureError.streamUnavailable }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw CaptureError.microphoneUnavailable
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            guard let channels = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            var mono = [Float](repeating: 0, count: frames)
            for channel in 0..<channelCount {
                for frame in 0..<frames {
                    mono[frame] += channels[channel][frame] / Float(channelCount)
                }
            }
            let samples = AudioCaptureManager.resample(mono, from: format.sampleRate)
            let timestamp = Date().timeIntervalSince1970
            continuation.yield(AudioChunk(source: .microphone, samples: samples, timestamp: timestamp))
            _ = time
        }

        do {
            let tap = try CoreAudioSystemTap { samples in
                continuation.yield(AudioChunk(source: .system, samples: samples, timestamp: Date().timeIntervalSince1970))
            }
            try audioEngine.start()
            try tap.start()
            systemTap = tap
            isCapturing = true
            return stream
        } catch {
            input.removeTap(onBus: 0)
            audioEngine.stop()
            continuation.finish()
            self.continuation = nil
            throw error
        }
    }

    static func checkSystemAudioPermission() throws {
        let tap = try CoreAudioSystemTap { _ in }
        try tap.start()
        tap.stop()
    }

    func stopCapture() {
        guard isCapturing else { return }
        systemTap?.stop()
        systemTap = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        continuation?.finish()
        continuation = nil
        isCapturing = false
    }

    nonisolated fileprivate static func resample(_ input: [Float], from sampleRate: Double) -> [Float] {
        guard !input.isEmpty, sampleRate > 0 else { return [] }
        if sampleRate == 16_000 { return input }
        let outputCount = Int(Double(input.count) * 16_000 / sampleRate)
        guard outputCount > 0 else { return [] }
        let step = sampleRate / 16_000
        return (0..<outputCount).map { index in
            let position = Double(index) * step
            let lower = min(Int(position), input.count - 1)
            let upper = min(lower + 1, input.count - 1)
            let fraction = Float(position - Double(lower))
            return input[lower] * (1 - fraction) + input[upper] * fraction
        }
    }

    enum CaptureError: LocalizedError {
        case alreadyCapturing
        case streamUnavailable
        case microphoneUnavailable

        var errorDescription: String? {
            switch self {
            case .alreadyCapturing: "Audio capture is already running"
            case .streamUnavailable: "Could not create the audio stream"
            case .microphoneUnavailable: "No usable microphone input is available"
            }
        }
    }
}

private final class CoreAudioSystemTap: @unchecked Sendable {
    private let onSamples: @Sendable ([Float]) -> Void
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var sampleRate: Double = 0
    private var format: AudioStreamBasicDescription?

    init(onSamples: @escaping @Sendable ([Float]) -> Void) throws {
        self.onSamples = onSamples
        try createTap()
    }

    func start() throws {
        guard aggregateID != kAudioObjectUnknown, let ioProcID else {
            throw CoreAudioError.invalidState
        }
        let status = AudioDeviceStart(aggregateID, ioProcID)
        guard status == noErr else { throw CoreAudioError.status(status) }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
    }

    deinit {
        stop()
    }

    private func createTap() throws {
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.name = "ConvoCraft System Audio"
        description.isPrivate = true
        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let createStatus = AudioHardwareCreateProcessTap(description, &newTapID)
        guard createStatus == noErr else { throw CoreAudioError.status(createStatus) }
        tapID = newTapID

        var uid: CFString?
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uidSize = UInt32(MemoryLayout<CFString?>.size)
        let uidStatus = withUnsafeMutablePointer(to: &uid) { pointer in
            AudioObjectGetPropertyData(tapID, &uidAddress, 0, nil, &uidSize, pointer)
        }
        guard uidStatus == noErr, let uid else { throw CoreAudioError.status(uidStatus) }

        var audioFormat = AudioStreamBasicDescription()
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let formatStatus = AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &formatSize, &audioFormat)
        guard formatStatus == noErr, audioFormat.mSampleRate > 0 else {
            throw CoreAudioError.status(formatStatus)
        }
        sampleRate = audioFormat.mSampleRate
        format = audioFormat

        let subTap: [String: Any] = [kAudioSubTapUIDKey: uid]
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "ConvoCraft System Audio",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceTapListKey: [subTap]
        ]
        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        let aggregateStatus = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &newAggregateID)
        guard aggregateStatus == noErr else { throw CoreAudioError.status(aggregateStatus) }
        aggregateID = newAggregateID

        var newIOProcID: AudioDeviceIOProcID?
        let callback = onSamples
        let rate = sampleRate
        let streamFormat = audioFormat
        let procStatus = AudioDeviceCreateIOProcIDWithBlock(&newIOProcID, aggregateID, DispatchQueue.global(qos: .userInitiated)) { _, inputData, _, _, _ in
            guard let buffer = inputData.pointee.mBuffers.mData,
                  inputData.pointee.mBuffers.mDataByteSize > 0,
                  let samples = Self.decode(buffer, byteCount: Int(inputData.pointee.mBuffers.mDataByteSize), format: streamFormat) else {
                return
            }
            callback(AudioCaptureManager.resample(samples, from: rate))
        }
        guard procStatus == noErr, let newIOProcID else { throw CoreAudioError.status(procStatus) }
        ioProcID = newIOProcID
    }

    private static func decode(_ pointer: UnsafeMutableRawPointer, byteCount: Int, format: AudioStreamBasicDescription) -> [Float]? {
        let bytesPerSample = Int(format.mBitsPerChannel / 8)
        guard bytesPerSample > 0 else { return nil }
        let count = byteCount / bytesPerSample
        switch format.mFormatFlags & kAudioFormatFlagIsFloat {
        case kAudioFormatFlagIsFloat:
            if bytesPerSample == MemoryLayout<Float>.size {
                return Array(UnsafeBufferPointer(start: pointer.assumingMemoryBound(to: Float.self), count: count))
            }
            if bytesPerSample == MemoryLayout<Double>.size {
                return UnsafeBufferPointer(start: pointer.assumingMemoryBound(to: Double.self), count: count).map(Float.init)
            }
        default:
            if bytesPerSample == MemoryLayout<Int16>.size {
                return UnsafeBufferPointer(start: pointer.assumingMemoryBound(to: Int16.self), count: count).map { Float($0) / Float(Int16.max) }
            }
            if bytesPerSample == MemoryLayout<Int32>.size {
                return UnsafeBufferPointer(start: pointer.assumingMemoryBound(to: Int32.self), count: count).map { Float($0) / Float(Int32.max) }
            }
        }
        return nil
    }

    enum CoreAudioError: LocalizedError {
        case invalidState
        case status(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidState: "System audio capture is not initialized"
            case .status(let status): "Core Audio failed with status \(status)"
            }
        }
    }
}
