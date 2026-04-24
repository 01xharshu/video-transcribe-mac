import Foundation
import Observation

@Observable
final class TranscriptionJob: Identifiable, Equatable {
    let id: UUID
    let inputURL: URL
    let addedDate: Date
    
    var status: JobStatus = .pending
    var progress: Double = 0.0
    var startTime: Date? = nil
    var endTime: Date? = nil
    var estimatedTimeRemaining: TimeInterval? = nil
    
    var fullTranscript: String? = nil
    var segments: [TranscriptionSegment] = []
    var detectedLanguage: String? = nil
    
    var tempAudioURL: URL? = nil
    var errorMessage: String? = nil
    var warning: String? = nil
    
    var fileName: String {
        inputURL.deletingPathExtension().lastPathComponent
    }
    
    var fileExtension: String {
        inputURL.pathExtension.uppercased()
    }
    
    var fileSizeFormatted: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: inputURL.path),
              let size = attrs[.size] as? UInt64 else {
            return "Unknown"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var durationFormatted: String? {
        guard let start = startTime, let end = endTime else { return nil }
        let duration = end.timeIntervalSince(start)
        return Self.formatDuration(duration)
    }
    
    init(inputURL: URL) {
        self.id = UUID()
        self.inputURL = inputURL
        self.addedDate = Date()
    }
    
    func estimateTimeRemaining() {
        guard let start = startTime, progress > 0.05 else {
            estimatedTimeRemaining = nil
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        let totalEstimate = elapsed / progress
        estimatedTimeRemaining = max(0, totalEstimate - elapsed)
    }
    
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    static func == (lhs: TranscriptionJob, rhs: TranscriptionJob) -> Bool {
        lhs.id == rhs.id
    }
}

enum JobStatus: String, Equatable {
    case pending = "Pending"
    case downloadingModel = "Downloading Model"
    case extractingAudio = "Extracting Audio"
    case transcribing = "Transcribing"
    case completed = "Completed"
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .downloadingModel: return "arrow.down.circle"
        case .extractingAudio: return "waveform"
        case .transcribing: return "text.word.spacing"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "secondary"
        case .downloadingModel: return "purple"
        case .extractingAudio: return "orange"
        case .transcribing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}
