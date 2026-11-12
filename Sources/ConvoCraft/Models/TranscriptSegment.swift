import Foundation

struct TranscriptSegment: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval
    let isFinal: Bool
    let source: AudioSource

    init(id: UUID = UUID(), text: String, timestamp: TimeInterval, isFinal: Bool = false, source: AudioSource = .microphone) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isFinal = isFinal
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case timestamp
        case isFinal
        case source
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        timestamp = try values.decode(TimeInterval.self, forKey: .timestamp)
        isFinal = try values.decode(Bool.self, forKey: .isFinal)
        source = try values.decodeIfPresent(AudioSource.self, forKey: .source) ?? .microphone
    }
}
