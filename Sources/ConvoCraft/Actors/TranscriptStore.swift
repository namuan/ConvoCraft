import Foundation

actor TranscriptStore {
    private(set) var segments: [TranscriptSegment] = []
    private var partialSegment: TranscriptSegment?
    
    func addPartialSegment(_ segment: TranscriptSegment) {
        partialSegment = segment
    }
    
    func finalizeCurrent() {
        if let partial = partialSegment {
            let final = TranscriptSegment(
                id: partial.id,
                text: partial.text,
                timestamp: partial.timestamp,
                isFinal: true
            )
            segments.append(final)
            partialSegment = nil
        }
    }
    
    func addFinalSegment(_ segment: TranscriptSegment) {
        let final = TranscriptSegment(
            id: segment.id,
            text: segment.text,
            timestamp: segment.timestamp,
            isFinal: true
        )
        segments.append(final)
    }
    
    func getRecentTranscript(lastMinutes: TimeInterval = 5.0) -> [TranscriptSegment] {
        let cutoffTime = Date().timeIntervalSince1970 - (lastMinutes * 60)
        return segments.filter { $0.timestamp >= cutoffTime }
    }
    
    func getAllSegments() -> [TranscriptSegment] {
        return segments
    }
    
    func getPartialSegment() -> TranscriptSegment? {
        return partialSegment
    }
    
    func clear() {
        segments.removeAll()
        partialSegment = nil
    }
}
