import Foundation

final class WhisperService {
    
    /// Check if whisper.cpp is available
    func isAvailable(settings: AppSettings) -> Bool {
        return settings.resolvedWhisperPath() != nil
    }
    
    /// Transcribe audio file using whisper.cpp CLI
    func transcribe(
        audioURL: URL,
        settings: AppSettings,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranscriptionResult {
        guard let whisperPath = settings.resolvedWhisperPath() else {
            throw WhisperError.notFound
        }
        
        // Build model path
        let modelPath = resolveModelPath(settings: settings)
        guard let modelPath = modelPath else {
            throw WhisperError.modelNotFound(settings.selectedModel)
        }
        
        // Create output file for JSON results
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoTranscribe")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let outputBase = tempDir.appendingPathComponent("output")
        
        var arguments: [String] = [
            "-m", modelPath,
            "-f", audioURL.path,
            "--output-json",
            "-of", outputBase.path,
            "--print-progress",
        ]
        
        // Language setting
        if settings.language != .auto {
            arguments += ["-l", settings.language.rawValue]
        }
        
        // Threads
        if settings.threads > 0 {
            arguments += ["-t", String(settings.threads)]
        }
        
        // Timestamps
        if settings.enableTimestamps {
            arguments += ["--max-len", "0"] // Don't limit segment length
        }
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = arguments
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        let stdoutCapture = OutputCapture()
        let stderrCapture = OutputCapture()
        
        return try await withCheckedThrowingContinuation { continuation in
            // Read stdout for progress
            let outHandle = outputPipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let output = String(data: data, encoding: .utf8) else { return }
                stdoutCapture.append(output)
                
                // Parse progress: support both "progress = XX%" and "[XX%]" formats
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if let range = line.range(of: #"(\d+)%"#, options: .regularExpression) {
                        let percentStr = line[range].replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentStr) {
                            DispatchQueue.main.async {
                                progressHandler(percent / 100.0)
                            }
                        }
                    }
                }
            }
            
            let errHandle = errorPipe.fileHandleForReading
            errHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let output = String(data: data, encoding: .utf8) else { return }
                stderrCapture.append(output)
                
                // whisper.cpp may also output progress to stderr
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if let range = line.range(of: #"(\d+)%"#, options: .regularExpression) {
                        let percentStr = line[range].replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentStr) {
                            DispatchQueue.main.async {
                                progressHandler(percent / 100.0)
                            }
                        }
                    }
                }
            }
            
            process.terminationHandler = { proc in
                _ = process // Retain process
                outHandle.readabilityHandler = nil
                errHandle.readabilityHandler = nil
                
                if proc.terminationStatus != 0 {
                    continuation.resume(throwing: WhisperError.transcriptionFailed(
                        code: proc.terminationStatus,
                        stderr: stderrCapture.text
                    ))
                    return
                }
                
                // Parse output JSON
                let jsonURL = outputBase.appendingPathExtension("json")
                
                do {
                    let result = try self.parseWhisperOutput(
                        jsonURL: jsonURL,
                        stdout: stdoutCapture.text,
                        stderr: stderrCapture.text
                    )
                    
                    // Cleanup temp output
                    try? FileManager.default.removeItem(at: tempDir)
                    
                    continuation.resume(returning: result)
                } catch {
                    // Fallback: parse from stdout
                    let fallbackResult = self.parseFromStdout(stdoutCapture.text)
                    
                    try? FileManager.default.removeItem(at: tempDir)
                    
                    continuation.resume(returning: fallbackResult)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: WhisperError.launchFailed(error))
            }
        }
    }
    
    // MARK: - Output Capture
    
    private final class OutputCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var _text = ""
        
        var text: String {
            lock.lock()
            defer { lock.unlock() }
            return _text
        }
        
        func append(_ newText: String) {
            lock.lock()
            defer { lock.unlock() }
            _text += newText
        }
    }
    
    // MARK: - Model Path Resolution
    
    func resolveModelPath(settings: AppSettings) -> String? {
        let modelFile = settings.selectedModel.modelFileName
        
        // Check configured models directory
        if let modelsDir = settings.resolvedModelsDirectory() {
            let path = (modelsDir as NSString).appendingPathComponent(modelFile)
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Check all common paths
        for dir in AppSettings.commonModelPaths {
            let path = (dir as NSString).appendingPathComponent(modelFile)
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Check relative to whisper binary
        if let whisperPath = settings.resolvedWhisperPath() {
            let whisperDir = (whisperPath as NSString).deletingLastPathComponent
            let modelsDir = (whisperDir as NSString).appendingPathComponent("../share/whisper/models")
            let path = (modelsDir as NSString).appendingPathComponent(modelFile)
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    // MARK: - Output Parsing
    
    private func parseWhisperOutput(
        jsonURL: URL,
        stdout: String,
        stderr: String
    ) throws -> TranscriptionResult {
        let data = try Data(contentsOf: jsonURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let json = json else {
            throw WhisperError.parseError
        }
        
        var segments: [TranscriptionSegment] = []
        var fullText = ""
        var language: String? = nil
        
        // Parse language
        if let result = json["result"] as? [String: Any],
           let lang = result["language"] as? String {
            language = lang
        }
        
        // Parse transcription segments
        if let transcription = json["transcription"] as? [[String: Any]] {
            for item in transcription {
                if let timestamps = item["timestamps"] as? [String: Any],
                   let fromStr = timestamps["from"] as? String,
                   let toStr = timestamps["to"] as? String,
                   let text = item["text"] as? String {
                    
                    let startTime = parseTimestamp(fromStr)
                    let endTime = parseTimestamp(toStr)
                    
                    let segment = TranscriptionSegment(
                        startTime: startTime,
                        endTime: endTime,
                        text: text.trimmingCharacters(in: .whitespaces)
                    )
                    segments.append(segment)
                    fullText += text
                }
            }
        }
        
        if segments.isEmpty {
            // Try alternative JSON format
            if let results = json["results"] as? [[String: Any]] {
                for item in results {
                    let start = item["start"] as? Double ?? item["t0"] as? Double ?? 0
                    let end = item["end"] as? Double ?? item["t1"] as? Double ?? 0
                    let text = item["text"] as? String ?? ""
                    
                    let segment = TranscriptionSegment(
                        startTime: start / 1000.0,  // Convert ms to seconds
                        endTime: end / 1000.0,
                        text: text.trimmingCharacters(in: .whitespaces)
                    )
                    segments.append(segment)
                    fullText += text
                }
            }
        }
        
        if fullText.isEmpty {
            fullText = segments.map { $0.text }.joined(separator: " ")
        }
        
        return TranscriptionResult(
            fullText: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: segments,
            language: language
        )
    }
    
    private func parseFromStdout(_ stdout: String) -> TranscriptionResult {
        var segments: [TranscriptionSegment] = []
        var fullText = ""
        
        // Parse whisper.cpp text output format:
        // [00:00:00.000 --> 00:00:05.000]  Text here
        let lines = stdout.components(separatedBy: "\n")
        let pattern = #"\[(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})\]\s*(.*)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex?.firstMatch(in: line, range: range) {
                if let startRange = Range(match.range(at: 1), in: line),
                   let endRange = Range(match.range(at: 2), in: line),
                   let textRange = Range(match.range(at: 3), in: line) {
                    
                    let startTime = parseTimestamp(String(line[startRange]))
                    let endTime = parseTimestamp(String(line[endRange]))
                    let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                    
                    if !text.isEmpty {
                        let segment = TranscriptionSegment(
                            startTime: startTime,
                            endTime: endTime,
                            text: text
                        )
                        segments.append(segment)
                        fullText += text + " "
                    }
                }
            }
        }
        
        return TranscriptionResult(
            fullText: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: segments,
            language: nil
        )
    }
    
    /// Parse timestamp string "HH:MM:SS.mmm" to TimeInterval
    private func parseTimestamp(_ str: String) -> TimeInterval {
        let components = str.components(separatedBy: ":")
        guard components.count >= 2 else { return 0 }
        
        if components.count == 3 {
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        } else {
            let minutes = Double(components[0]) ?? 0
            let seconds = Double(components[1]) ?? 0
            return minutes * 60 + seconds
        }
    }
}

enum WhisperError: LocalizedError {
    case notFound
    case modelNotFound(WhisperModel)
    case transcriptionFailed(code: Int32, stderr: String)
    case launchFailed(Error)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "whisper.cpp not found. Please install it and configure the path in Settings."
        case .modelNotFound(let model):
            return "Model '\(model.displayName)' (\(model.modelFileName)) not found. Download it from the whisper.cpp models repository."
        case .transcriptionFailed(let code, let stderr):
            let truncatedErr = stderr.suffix(500)
            return "Transcription failed (exit code \(code)).\n\(truncatedErr)"
        case .launchFailed(let error):
            return "Failed to launch whisper.cpp: \(error.localizedDescription)"
        case .parseError:
            return "Failed to parse transcription output."
        }
    }
}
