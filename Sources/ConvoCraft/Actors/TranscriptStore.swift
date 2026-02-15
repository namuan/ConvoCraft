import Foundation

actor TranscriptStore {
    private(set) var segments: [TranscriptSegment] = []
    private var partialSegment: TranscriptSegment?
    private var lastProcessedText: String = ""
    
    func addPartialSegment(_ segment: TranscriptSegment) {
        let newText = extractNewText(from: segment.text)
        
        guard !newText.isEmpty else { return }
        
        if shouldFinalizePartial(newText: newText) {
            print("🔄 Finalizing segment due to: \(newText.count >= 100 ? "length" : "punctuation")")
            finalizeCurrent()
        }
        
        accumulatePartialText(newText, timestamp: segment.timestamp)
        lastProcessedText = segment.text
    }
    
    private func extractNewText(from text: String) -> String {
        if text.hasPrefix(lastProcessedText) && text.count > lastProcessedText.count {
            let startIndex = text.index(text.startIndex, offsetBy: lastProcessedText.count)
            let extracted = String(text[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            print("➕ Extracted new text (\(extracted.count) chars): \(extracted.prefix(80))...")
            return extracted
        }
        
        if text != lastProcessedText {
            print("🔄 Completely new utterance (\(text.count) chars): \(text.prefix(80))...")
            return text
        }
        
        return ""
    }
    
    private func shouldFinalizePartial(newText: String) -> Bool {
        guard partialSegment != nil else { return false }
        
        let hasSignificantLength = newText.count >= 100
        let endsWithPunctuation = newText.hasSuffix(".") || newText.hasSuffix("?") || newText.hasSuffix("!")
        
        return hasSignificantLength || endsWithPunctuation
    }
    
    private func accumulatePartialText(_ newText: String, timestamp: TimeInterval) {
        if let partial = partialSegment {
            let combinedText = partial.text + " " + newText
            partialSegment = TranscriptSegment(
                id: partial.id,
                text: combinedText,
                timestamp: timestamp,
                isFinal: false
            )
            print("📝 Accumulated partial: \(combinedText.count) chars total")
        } else {
            partialSegment = TranscriptSegment(
                id: UUID(),
                text: newText,
                timestamp: timestamp,
                isFinal: false
            )
            print("🆕 New partial segment: \(newText.prefix(60))... [\(newText.count) chars]")
        }
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
