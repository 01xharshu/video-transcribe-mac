import Foundation

final class ExportService {
    
    /// Export as plain text with optional timestamps
    func exportAsTxt(transcript: String, segments: [TranscriptionSegment]) -> String {
        if segments.isEmpty {
            return transcript
        }
        
        var output = ""
        for segment in segments {
            output += "[\(segment.startTimestamp) → \(segment.endTimestamp)] \(segment.text)\n"
        }
        return output
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
        
        if segments.isEmpty {
            let escaped = transcript.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "{", with: "\\{")
                .replacingOccurrences(of: "}", with: "\\}")
                .replacingOccurrences(of: "\n", with: "\\line ")
            rtf += escaped
        } else {
            for segment in segments {
                rtf += "{\\b [\(segment.startTimestamp) \\u8594? \(segment.endTimestamp)]} "
                let escaped = segment.text.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "{", with: "\\{")
                    .replacingOccurrences(of: "}", with: "\\}")
                    .replacingOccurrences(of: "\n", with: "\\line ")
                rtf += escaped
                rtf += "\\line\\line "
            }
        }
        rtf += "}"
        return rtf
    }
}
