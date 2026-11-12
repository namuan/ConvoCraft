import Foundation

enum AudioSource: String, Codable, CaseIterable, Sendable {
    case microphone
    case system

    var displayName: String {
        switch self {
        case .microphone: "Me"
        case .system: "Them"
        }
    }
}

struct AudioChunk: Sendable {
    let source: AudioSource
    let samples: [Float]
    let timestamp: TimeInterval
}
