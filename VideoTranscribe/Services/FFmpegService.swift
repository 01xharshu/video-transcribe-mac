import Foundation

final class FFmpegService {
    
    /// Check if FFmpeg is available on the system
    func isAvailable() -> Bool {
        return findFFmpegPath() != nil
    }
    
    func findFFmpegPath() -> String? {
        let commonPaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try `which ffmpeg`
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "ffmpeg"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }
        
        return nil
    }
    
    /// Extract audio from video file as 16kHz mono WAV (required by whisper.cpp)
    func extractAudio(
        from videoURL: URL,
        to audioURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        guard let ffmpegPath = findFFmpegPath() else {
            throw FFmpegError.notFound
        }
        
        // First, get video duration for progress calculation
        let duration = try await getVideoDuration(videoURL: videoURL, ffmpegPath: ffmpegPath)
        
        let process = Process()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-i", videoURL.path,
            "-vn",                    // No video
            "-acodec", "pcm_s16le",  // 16-bit PCM
            "-ar", "16000",          // 16kHz sample rate (whisper.cpp requirement)
            "-ac", "1",              // Mono
            "-y",                    // Overwrite output
            "-progress", "pipe:2",   // Progress to stderr
            audioURL.path
        ]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            // Read stderr for progress
            let errorHandle = errorPipe.fileHandleForReading
            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let output = String(data: data, encoding: .utf8) else { return }
                
                // Parse progress from FFmpeg output
                if let timeMatch = output.range(of: #"out_time_us=(\d+)"#, options: .regularExpression) {
                    let timeStr = output[timeMatch]
                        .replacingOccurrences(of: "out_time_us=", with: "")
                    if let timeUs = Double(timeStr), duration > 0 {
                        let currentTime = timeUs / 1_000_000
                        let progress = min(1.0, currentTime / duration)
                        DispatchQueue.main.async {
                            progressHandler(progress)
                        }
                    }
                }
            }
            
            process.terminationHandler = { proc in
                _ = process // Retain process
                errorHandle.readabilityHandler = nil
                
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: FFmpegError.extractionFailed(code: proc.terminationStatus))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: FFmpegError.launchFailed(error))
            }
        }
    }
    
    /// Get video duration in seconds
    private func getVideoDuration(videoURL: URL, ffmpegPath: String) async throws -> Double {
        let ffprobePath = ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        
        let process = Process()
        let pipe = Pipe()
        
        let execPath: String
        if FileManager.default.isExecutableFile(atPath: ffprobePath) {
            execPath = ffprobePath
        } else {
            // Use ffmpeg with -i to get duration
            execPath = ffmpegPath
        }
        
        if execPath.hasSuffix("ffprobe") {
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = [
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                videoURL.path
            ]
        } else {
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = ["-i", videoURL.path]
        }
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        process.standardOutput = pipe
        process.standardError = pipe
        
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                // Retain process to prevent deallocation
                _ = process
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // Try to parse duration
                if let durationStr = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "\n").first,
                   let duration = Double(durationStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    continuation.resume(returning: duration)
                    return
                }
                
                // Parse from ffmpeg -i output: Duration: HH:MM:SS.xx
                if let range = output.range(of: #"Duration: (\d{2}):(\d{2}):(\d{2})\.\d+"#, options: .regularExpression) {
                    let durationStr = String(output[range])
                    let components = durationStr.replacingOccurrences(of: "Duration: ", with: "")
                        .components(separatedBy: ":")
                    if components.count == 3,
                       let h = Double(components[0]),
                       let m = Double(components[1]),
                       let s = Double(components[2]) {
                        continuation.resume(returning: h * 3600 + m * 60 + s)
                        return
                    }
                }
                
                continuation.resume(returning: 0) // Unknown duration
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: 0)
            }
        }
    }
}

enum FFmpegError: LocalizedError {
    case notFound
    case extractionFailed(code: Int32)
    case launchFailed(Error)
    case noAudioTrack
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "FFmpeg not found. Install it with: brew install ffmpeg"
        case .extractionFailed(let code):
            return "Audio extraction failed (exit code \(code)). The video may not contain an audio track."
        case .launchFailed(let error):
            return "Failed to launch FFmpeg: \(error.localizedDescription)"
        case .noAudioTrack:
            return "No audio track found in the video file."
        }
    }
}
