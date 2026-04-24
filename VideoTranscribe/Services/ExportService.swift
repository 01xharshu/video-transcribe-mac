import Foundation

final class ExportService {
    
    /// Export as plain text with optional timestamps
    func exportAsTxt(transcript: String, segments: [TranscriptionSegment]) -> String {
        return transcript
    }
    
    /// Export as SRT subtitle format
    func exportAsSrt(segments: [TranscriptionSegment]) -> String {
        var output = ""
        
        for (index, segment) in segments.enumerated() {
            output += "\(index + 1)\n"
            output += "\(segment.srtStartTimestamp) --> \(segment.srtEndTimestamp)\n"
            output += "\(segment.text)\n"
            output += "\n"
        }
        
        return output
    }
    
    /// Export as JSON
    func exportAsJson(job: TranscriptionJob) -> String {
        let exportData: [String: Any] = [
            "fileName": job.fileName,
            "fileExtension": job.fileExtension,
            "fileSize": job.fileSizeFormatted,
            "transcribedAt": ISO8601DateFormatter().string(from: job.endTime ?? Date()),
            "language": job.detectedLanguage ?? "unknown",
            "fullTranscript": job.fullTranscript ?? "",
            "segments": job.segments.map { segment in
                return [
                    "start": segment.startTime,
                    "end": segment.endTime,
                    "startTimestamp": segment.startTimestamp,
                    "endTimestamp": segment.endTimestamp,
                    "text": segment.text
                ] as [String: Any]
            }
        ]
        
        if let jsonData = try? JSONSerialization.data(
            withJSONObject: exportData,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        }
        
        return "{}"
    }
    
    /// Export as Word-compatible RTF (saved with .doc extension)
    func exportAsDoc(transcript: String, segments: [TranscriptionSegment]) -> String {
        var rtf = "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Arial;}}\n"
        rtf += "\\f0\\fs24 "
        
        let escaped = transcript.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\n", with: "\\line ")
        rtf += escaped
        
        rtf += "}"
        return rtf
    }
}
