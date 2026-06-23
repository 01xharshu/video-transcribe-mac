import Foundation
import AVFoundation

final class FFmpegService {
    
    /// Check if FFmpeg is available on the system
    func isAvailable() -> Bool {
        return findFFmpegPath() != nil
    }
    
    func findFFmpegPath() -> String? {
        // Only use the bundled FFmpeg
        if let bundlePath = Bundle.main.path(forResource: "ffmpeg", ofType: nil, inDirectory: "bin") {
            if FileManager.default.isExecutableFile(atPath: bundlePath) {
                return bundlePath
            }
        }
        
        return nil
    }
    
    /// Extract audio from video file as 16kHz mono WAV (required by whisper.cpp)
    /// First tries AVFoundation (native, no file-access issues), then falls back to FFmpeg.
    func extractAudio(
        from videoURL: URL,
        to audioURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        // Start security-scoped resource access (needed for user-selected files)
        let didStartAccess = videoURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                videoURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Verify the file is readable
        guard FileManager.default.isReadableFile(atPath: videoURL.path) else {
            // Try copying to a temp location if original isn't readable by subprocesses
            throw FFmpegError.fileNotReadable(path: videoURL.path)
        }
        
        // Strategy: Try AVFoundation first (no subprocess file-access issues),
        // then fall back to FFmpeg for broader codec support.
        do {
            try await extractAudioWithAVFoundation(from: videoURL, to: audioURL, progressHandler: progressHandler)
            return
        } catch {
            // AVFoundation failed — fall back to FFmpeg
            // This handles codecs AVFoundation doesn't support (e.g., MKV, some WebM)
        }
        
        // Fallback: Copy input to temp if needed, then use FFmpeg
        try await extractAudioWithFFmpeg(from: videoURL, to: audioURL, progressHandler: progressHandler)
    }
    
    /// Extract audio using AVFoundation (native macOS — avoids file-permission issues with subprocesses)
    private func extractAudioWithAVFoundation(
        from videoURL: URL,
        to audioURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: videoURL)
        
        // Check for audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw FFmpegError.noAudioTrack
        }
        
        // Get duration (not needed for progress since we monitor exportSession.progress directly)
        _ = try await asset.load(.duration)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw FFmpegError.avFoundationFailed("Could not create export session")
        }
        
        // Export as M4A first, then convert to WAV with FFmpeg for whisper.cpp compatibility
        let tempM4AURL = audioURL.deletingLastPathComponent().appendingPathComponent("temp_audio.m4a")
        
        // Remove existing temp file
        try? FileManager.default.removeItem(at: tempM4AURL)
        
        exportSession.outputURL = tempM4AURL
        exportSession.outputFileType = .m4a
        exportSession.audioTimePitchAlgorithm = .spectral
        
        // Monitor progress
        let progressTask = Task {
            while !Task.isCancelled {
                let progress = Double(exportSession.progress)
                await MainActor.run {
                    progressHandler(progress * 0.5) // First 50% for extraction
                }
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            }
        }
        
        await exportSession.export()
        progressTask.cancel()
        
        guard exportSession.status == .completed else {
            let errorMsg = exportSession.error?.localizedDescription ?? "Unknown export error"
            try? FileManager.default.removeItem(at: tempM4AURL)
            throw FFmpegError.avFoundationFailed(errorMsg)
        }
        
        // Now convert M4A to 16kHz mono WAV using FFmpeg
        guard let ffmpegPath = findFFmpegPath() else {
            // If no FFmpeg, try to use the M4A directly (some whisper builds accept it)
            try FileManager.default.moveItem(at: tempM4AURL, to: audioURL)
            return
        }
        
        let process = Process()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-i", tempM4AURL.path,
            "-vn",
            "-acodec", "pcm_s16le",
            "-ar", "16000",
            "-ac", "1",
            "-y",
            audioURL.path
        ]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                _ = process
                // Cleanup temp M4A
                try? FileManager.default.removeItem(at: tempM4AURL)
                
                if proc.terminationStatus == 0 {
                    DispatchQueue.main.async { progressHandler(1.0) }
                    continuation.resume()
                } else {
                    continuation.resume(throwing: FFmpegError.extractionFailed(
                        code: proc.terminationStatus,
                        stderr: "Failed to convert extracted audio to WAV format"
                    ))
                }
            }
            
            do {
                try process.run()
            } catch {
                try? FileManager.default.removeItem(at: tempM4AURL)
                continuation.resume(throwing: FFmpegError.launchFailed(error))
            }
        }
    }
    
    /// Extract audio using FFmpeg CLI (handles broader codec/container support)
    private func extractAudioWithFFmpeg(
        from videoURL: URL,
        to audioURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        guard let ffmpegPath = findFFmpegPath() else {
            throw FFmpegError.notFound
        }
        
        // Copy the input file to a temp location to avoid file-access permission issues
        // macOS grants file access to the app process, but NOT to child processes (ffmpeg)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoTranscribe")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let tempInputURL = tempDir.appendingPathComponent(videoURL.lastPathComponent)
        
        // Copy the video to temp so ffmpeg can access it
        var useTempCopy = false
        do {
            try FileManager.default.copyItem(at: videoURL, to: tempInputURL)
            useTempCopy = true
        } catch {
            // If copy fails, try using the original path directly
            useTempCopy = false
        }
        
        let inputPath = useTempCopy ? tempInputURL.path : videoURL.path
        
        defer {
            if useTempCopy {
                try? FileManager.default.removeItem(at: tempDir)
            }
        }
        
        // Get duration for progress
        let duration = try await getVideoDuration(filePath: inputPath, ffmpegPath: ffmpegPath)
        
        let process = Process()
        let errorPipe = Pipe()
        let stderrCapture = OutputCapture()
        
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-i", inputPath,
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
                
                stderrCapture.append(output)
                
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
                    // Parse stderr for more useful error info
                    let stderr = stderrCapture.text
                    let errorDetail: String
                    if stderr.contains("does not contain any stream") || stderr.contains("no audio") {
                        errorDetail = "The video file does not contain an audio track."
                    } else if stderr.contains("Permission denied") || stderr.contains("Operation not permitted") {
                        errorDetail = "Permission denied — the app cannot access this file. Try dragging the file in again."
                    } else if stderr.contains("Invalid data found") || stderr.contains("Invalid argument") {
                        errorDetail = "The video file appears to be corrupted or in an unsupported format."
                    } else {
                        // Extract the last meaningful error line
                        let errorLines = stderr.components(separatedBy: "\n")
                            .filter { !$0.isEmpty && !$0.hasPrefix("frame=") && !$0.hasPrefix("out_time") && !$0.hasPrefix("progress=") }
                        errorDetail = errorLines.suffix(3).joined(separator: "\n")
                    }
                    continuation.resume(throwing: FFmpegError.extractionFailed(
                        code: proc.terminationStatus,
                        stderr: errorDetail
                    ))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: FFmpegError.launchFailed(error))
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
    
    /// Get video duration in seconds
    private func getVideoDuration(filePath: String, ffmpegPath: String) async throws -> Double {
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
                filePath
            ]
        } else {
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = ["-i", filePath]
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
    case extractionFailed(code: Int32, stderr: String)
    case launchFailed(Error)
    case noAudioTrack
    case fileNotReadable(path: String)
    case avFoundationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "FFmpeg not found. Install it with: brew install ffmpeg"
        case .extractionFailed(_, let stderr):
            if stderr.isEmpty {
                return "Audio extraction failed. The video may not contain an audio track or the file format is unsupported."
            }
            return "Audio extraction failed: \(stderr)"
        case .launchFailed(let error):
            return "Failed to launch FFmpeg: \(error.localizedDescription)"
        case .noAudioTrack:
            return "No audio track found in the video file."
        case .fileNotReadable(let path):
            return "Cannot read the video file. Please try dragging it in again.\nPath: \(path)"
        case .avFoundationFailed(let msg):
            return "AVFoundation export failed: \(msg)"
        }
    }
}
