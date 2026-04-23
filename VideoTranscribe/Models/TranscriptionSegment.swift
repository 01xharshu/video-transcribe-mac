import Foundation

struct TranscriptionSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    
    init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
    
    var startTimestamp: String {
        Self.formatTimestamp(startTime)
    }
    
    var endTimestamp: String {
        Self.formatTimestamp(endTime)
    }
    
    /// SRT-compatible timestamp format: HH:MM:SS,mmm
    var srtStartTimestamp: String {
        Self.formatSrtTimestamp(startTime)
    }
    
    var srtEndTimestamp: String {
        Self.formatSrtTimestamp(endTime)
    }
    
    static func formatTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, ms)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, ms)
    }
    
    static func formatSrtTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, ms)
    }
}

struct TranscriptionResult {
    let fullText: String
    let segments: [TranscriptionSegment]
    let language: String?
}
