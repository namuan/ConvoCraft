import Foundation

actor TranscriptStore {
    private(set) var segments: [TranscriptSegment] = []
    private var partialSegment: TranscriptSegment?
    private var lastProcessedText: String = ""
    
    func addPartialSegment(_ segment: TranscriptSegment) {
        // Speech recognition provides cumulative text
        // Extract only the NEW text that wasn't in the previous update
        let newText: String
        if segment.text.hasPrefix(lastProcessedText) && segment.text.count > lastProcessedText.count {
            // New text is everything after what we already have
            let startIndex = segment.text.index(segment.text.startIndex, offsetBy: lastProcessedText.count)
            newText = String(segment.text[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            print("➕ Extracted new text (\(newText.count) chars): \(newText.prefix(80))...")
        } else if segment.text != lastProcessedText {
            // Completely different text (e.g., new utterance started)
            newText = segment.text
            print("🔄 Completely new utterance (\(newText.count) chars): \(newText.prefix(80))...")
        } else {
            // No change
            return
        }
        
        if !newText.isEmpty {
            // Check if this looks like a complete thought (ends with punctuation or has significant length)
            let shouldFinalize = newText.count >= 100 || 
                                 newText.hasSuffix(".") || 
                                 newText.hasSuffix("?") || 
                                 newText.hasSuffix("!")
            
            if shouldFinalize && partialSegment != nil {
                // Finalize the previous partial before starting a new one
                print("🔄 Finalizing segment due to: \(newText.count >= 100 ? "length" : "punctuation")")
                finalizeCurrent()
            }
            
            // Accumulate the new text in partial segment
            if let partial = partialSegment {
                let combinedText = partial.text + " " + newText
                partialSegment = TranscriptSegment(
                    id: partial.id,
                    text: combinedText,
                    timestamp: segment.timestamp,
                    isFinal: false
                )
                print("📝 Accumulated partial: \(combinedText.count) chars total")
            } else {
                partialSegment = TranscriptSegment(
                    id: UUID(),
                    text: newText,
                    timestamp: segment.timestamp,
                    isFinal: false
                )
                print("🆕 New partial segment: \(newText.prefix(60))... [\(newText.count) chars]")
            }
        }
        
        lastProcessedText = segment.text
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
            print("📝 Finalized partial segment: \(final.text.prefix(50))... (total: \(segments.count))")
        }
    }
    
    func addFinalSegment(_ segment: TranscriptSegment) {
        // Don't add if it's exactly the same as the last segment
        if let last = segments.last, last.text == segment.text {
            print("⚠️ Skipping duplicate final segment: \(segment.text.prefix(50))")
            return
        }
        
        let final = TranscriptSegment(
            id: UUID(),
            text: segment.text,
            timestamp: segment.timestamp,
            isFinal: true
        )
        segments.append(final)
        partialSegment = nil
        print("✅ Added final segment #\(segments.count): \(final.text.prefix(80))... [\(final.text.count) chars]")
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
        lastProcessedText = ""
    }
}
