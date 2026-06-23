import Foundation

final class YouTubeService {
    
    /// Check if yt-dlp is installed
    func isAvailable() -> Bool {
        return findYtDlpPath() != nil
    }
    
    func findYtDlpPath() -> String? {
        // Only use the bundled yt-dlp
        if let bundlePath = Bundle.main.path(forResource: "yt-dlp", ofType: nil, inDirectory: "bin") {
            if FileManager.default.isExecutableFile(atPath: bundlePath) {
                return bundlePath
            }
        }
        
        return nil
    }
    
    /// Validate if a string is a YouTube URL
    static func isYouTubeURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"^https?://(www\.)?youtube\.com/watch\?v=[\w\-]+"#,
            #"^https?://(www\.)?youtube\.com/shorts/[\w\-]+"#,
            #"^https?://youtu\.be/[\w\-]+"#,
            #"^https?://m\.youtube\.com/watch\?v=[\w\-]+"#,
            #"^https?://(www\.)?youtube\.com/live/[\w\-]+"#,
        ]
        
        for pattern in patterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    /// Extract video title from YouTube URL
    func fetchVideoTitle(url: String) async -> String? {
        guard let ytDlpPath = findYtDlpPath() else { return nil }
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = [
            "--get-title",
            "--no-warnings",
            url
        ]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                _ = process
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0,
                   let title = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !title.isEmpty {
                    continuation.resume(returning: title)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Download video from YouTube URL to a local file
    func downloadVideo(
        url: String,
        to outputDir: URL,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> URL {
        guard let ytDlpPath = findYtDlpPath() else {
            throw YouTubeError.ytDlpNotFound
        }
        
        let outputTemplate = outputDir.appendingPathComponent("%(title)s.%(ext)s").path
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let stderrCapture = OutputCapture()
        
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = [
            "-f", "bestaudio[ext=m4a]/bestaudio/best",  // Prefer audio-only for faster download
            "--no-playlist",                              // Don't download playlists
            "--no-warnings",
            "--newline",                                  // One line per progress update
            "-o", outputTemplate,
            "--print", "after_move:filepath",             // Print final filepath after download
            url
        ]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        let stdoutCapture = OutputCapture()
        
        return try await withCheckedThrowingContinuation { continuation in
            let outHandle = outputPipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let output = String(data: data, encoding: .utf8) else { return }
                
                stdoutCapture.append(output)
                
                // Parse progress: [download]  45.2% of ~12.34MiB at  2.56MiB/s ETA 00:03
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if line.contains("[download]"),
                       let percentRange = line.range(of: #"(\d+\.?\d*)%"#, options: .regularExpression) {
                        let percentStr = line[percentRange].replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentStr) {
                            DispatchQueue.main.async {
                                progressHandler(percent / 100.0, "Downloading...")
                            }
                        }
                    } else if line.contains("[ExtractAudio]") || line.contains("[Merger]") {
                        DispatchQueue.main.async {
                            progressHandler(0.95, "Processing audio...")
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
            }
            
            process.terminationHandler = { proc in
                _ = process
                outHandle.readabilityHandler = nil
                errHandle.readabilityHandler = nil
                
                if proc.terminationStatus != 0 {
                    let stderr = stderrCapture.text
                    let errorMsg: String
                    if stderr.contains("Video unavailable") || stderr.contains("Private video") {
                        errorMsg = "This video is unavailable or private."
                    } else if stderr.contains("Sign in") || stderr.contains("age") {
                        errorMsg = "This video requires sign-in or age verification."
                    } else if stderr.contains("HTTP Error 429") {
                        errorMsg = "Too many requests — YouTube is rate limiting. Please wait and try again."
                    } else {
                        let lastLines = stderr.components(separatedBy: "\n")
                            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            .suffix(2)
                            .joined(separator: "\n")
                        errorMsg = lastLines.isEmpty ? "Download failed with exit code \(proc.terminationStatus)" : lastLines
                    }
                    continuation.resume(throwing: YouTubeError.downloadFailed(errorMsg))
                    return
                }
                
                // Find the downloaded file — yt-dlp prints the filepath to stdout
                let stdout = stdoutCapture.text
                let lines = stdout.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // The last non-empty line should be the filepath from --print after_move:filepath
                if let filePath = lines.last, FileManager.default.fileExists(atPath: filePath) {
                    continuation.resume(returning: URL(fileURLWithPath: filePath))
                    return
                }
                
                // Fallback: scan the output dir for recently created files
                if let files = try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: [.creationDateKey]),
                   let newest = files
                    .filter({ !$0.lastPathComponent.hasPrefix(".") })
                    .sorted(by: { 
                        let d1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                        let d2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                        return d1 > d2
                    }).first {
                    continuation.resume(returning: newest)
                    return
                }
                
                continuation.resume(throwing: YouTubeError.downloadFailed("Downloaded file not found"))
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: YouTubeError.launchFailed(error))
            }
        }
    }
    
    /// Thread-safe output capture helper
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
}

enum YouTubeError: LocalizedError {
    case ytDlpNotFound
    case invalidURL
    case downloadFailed(String)
    case launchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .ytDlpNotFound:
            return "yt-dlp not found. Install it with: brew install yt-dlp"
        case .invalidURL:
            return "Invalid YouTube URL. Please provide a valid YouTube video link."
        case .downloadFailed(let msg):
            return "YouTube download failed: \(msg)"
        case .launchFailed(let error):
            return "Failed to launch yt-dlp: \(error.localizedDescription)"
        }
    }
}
