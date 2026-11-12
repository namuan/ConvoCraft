import Foundation

actor AudioRecordingWriter {
    private struct Track {
        let url: URL
        let handle: FileHandle
        var frames: UInt32
    }

    private let directory: URL
    private var tracks: [AudioSource: Track] = [:]
    private let sampleRate: UInt32 = 16_000

    init(startDate: Date) throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("MeetingRecordings", isDirectory: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        directory = root.appendingPathComponent("meeting_\(formatter.string(from: startDate))", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func append(_ chunk: AudioChunk) throws {
        var track = try trackFor(chunk.source)
        var pcm = Data(capacity: chunk.samples.count * 2)
        for sample in chunk.samples {
            let clamped = max(-1, min(1, sample))
            var value = Int16(clamped * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        try track.handle.seekToEnd()
        try track.handle.write(contentsOf: pcm)
        track.frames &+= UInt32(chunk.samples.count)
        tracks[chunk.source] = track
    }

    func finish() throws -> [String] {
        var paths: [String] = []
        for source in AudioSource.allCases {
            guard let track = tracks[source] else { continue }
            try track.handle.seek(toOffset: 0)
            try track.handle.write(contentsOf: header(frameCount: track.frames))
            try track.handle.close()
            paths.append(track.url.path)
            tracks[source] = nil
        }
        return paths
    }

    private func trackFor(_ source: AudioSource) throws -> Track {
        if let track = tracks[source] { return track }
        let suffix = source == .microphone ? "microphone" : "system"
        let url = directory.appendingPathComponent("\(suffix).wav")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.write(contentsOf: header(frameCount: 0))
        let track = Track(url: url, handle: handle, frames: 0)
        tracks[source] = track
        return track
    }

    private func header(frameCount: UInt32) -> Data {
        let dataSize = frameCount &* 2
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendLE(dataSize &+ 36, to: &data)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        appendLE(UInt32(16), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(sampleRate, to: &data)
        appendLE(sampleRate &* 2, to: &data)
        appendLE(UInt16(2), to: &data)
        appendLE(UInt16(16), to: &data)
        data.append(contentsOf: Array("data".utf8))
        appendLE(dataSize, to: &data)
        return data
    }

    private func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
