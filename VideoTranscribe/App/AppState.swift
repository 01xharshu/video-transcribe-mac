import SwiftUI
import UniformTypeIdentifiers

@Observable
final class AppState {
    // MARK: - Jobs
    var jobs: [TranscriptionJob] = []
    var selectedJobId: UUID? = nil
    var showFilePicker: Bool = false
    
    // MARK: - Dependencies
    var ffmpegAvailable: Bool = false
    var whisperAvailable: Bool = false
    var showSetupGuide: Bool = false
    var showSettings: Bool = false
    var globalError: String? = nil
    
    // MARK: - Settings
    var settings: AppSettings = AppSettings.load()
    
    // MARK: - Recent Files
    var recentFiles: [URL] = []
    
    // MARK: - Services
    let ffmpegService = FFmpegService()
    let whisperService = WhisperService()
    let exportService = ExportService()
    let modelDownloader = ModelDownloader()
    
    // MARK: - Computed
    var selectedJob: TranscriptionJob? {
        jobs.first { $0.id == selectedJobId }
    }
    
    var activeJobsCount: Int {
        jobs.filter { $0.status != .pending && $0.status != .completed && $0.status != .failed }.count
    }
    
    var systemStatus: String {
        if !ffmpegAvailable { return "FFmpeg Missing" }
        if !whisperAvailable { return "Whisper Missing" }
        
        let active = jobs.filter { $0.status != .pending && $0.status != .completed && $0.status != .failed }
        if let first = active.first {
            return "\(first.status.rawValue)..."
        }
        
        if jobs.isEmpty { return "Ready" }
        return "Idle"
    }
    
    // MARK: - Dependency Checking
    
    func checkDependencies() {
        ffmpegAvailable = ffmpegService.isAvailable()
        whisperAvailable = whisperService.isAvailable(settings: settings)
        
        if !ffmpegAvailable || !whisperAvailable {
            showSetupGuide = true
        }
    }
    
    // MARK: - File Handling
    
    func addFiles(urls: [URL]) {
        let supportedExtensions = ["mp4", "mov", "mkv", "webm", "avi", "m4v", "wmv", "flv", "ts", "mts"]
        
        for url in urls {
            let ext = url.pathExtension.lowercased()
            
            if url.hasDirectoryPath {
                // Scan directory for video files
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                            addSingleFile(url: fileURL)
                        }
                    }
                }
            } else if supportedExtensions.contains(ext) {
                addSingleFile(url: url)
            }
        }
    }
    
    private func addSingleFile(url: URL) {
        guard !jobs.contains(where: { $0.inputURL == url }) else { return }
        
        let job = TranscriptionJob(inputURL: url)
        jobs.append(job)
        
        // Track recent files
        if !recentFiles.contains(url) {
            recentFiles.insert(url, at: 0)
            if recentFiles.count > 20 { recentFiles.removeLast() }
        }
        
        // Auto-select if first job
        if selectedJobId == nil {
            selectedJobId = job.id
        }
    }
    
    // MARK: - Transcription
    
    func startTranscription(for job: TranscriptionJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        
        Task {
            await processJob(at: index)
        }
    }
    
    func startAllPending() {
        for (index, job) in jobs.enumerated() {
            if job.status == .pending || job.status == .failed {
                Task {
                    await processJob(at: index)
                }
            }
        }
    }
    
    @MainActor
    private func processJob(at index: Int) async {
        guard index < jobs.count else { return }
        
        let job = jobs[index]
        guard job.status == .pending || job.status == .failed else { return }
        
        // Check file size warning
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: job.inputURL.path))?[.size] as? UInt64 ?? 0
        let fileSizeGB = Double(fileSize) / (1024 * 1024 * 1024)
        if fileSizeGB > 2.0 {
            jobs[index].warning = "Large file (\(String(format: "%.1f", fileSizeGB)) GB) — transcription may take a while."
        }
        
        // Step 1: Ensure Model is Downloaded
        if whisperService.resolveModelPath(settings: settings) == nil {
            jobs[index].status = .downloadingModel
            jobs[index].progress = 0.0
            
            // Wait for download to finish
            let success = await withCheckedContinuation { continuation in
                modelDownloader.downloadModel(settings.selectedModel) { result in
                    continuation.resume(returning: result)
                }
                
                // Monitor progress to update job
                Task {
                    while self.modelDownloader.isDownloading {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                        if index < self.jobs.count {
                            self.jobs[index].progress = self.modelDownloader.progress
                        }
                    }
                }
            }
            
            guard success else {
                jobs[index].status = .failed
                jobs[index].errorMessage = "Failed to download model: \(modelDownloader.downloadError ?? "Unknown error")"
                return
            }
        }
        
        // Step 2: Extract audio
        jobs[index].status = .extractingAudio
        jobs[index].progress = 0.0
        jobs[index].startTime = Date()
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoTranscribe")
            .appendingPathComponent(job.id.uuidString)
        
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let audioURL = tempDir.appendingPathComponent("audio.wav")
        jobs[index].tempAudioURL = audioURL
        
        do {
            try await ffmpegService.extractAudio(
                from: job.inputURL,
                to: audioURL
            ) { progress in
                Task { @MainActor in
                    if index < self.jobs.count {
                        self.jobs[index].progress = progress * 0.2 // 20% for extraction
                    }
                }
            }
        } catch {
            jobs[index].status = .failed
            jobs[index].errorMessage = "Audio extraction failed: \(error.localizedDescription)"
            return
        }
        
        // Check if audio was extracted
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            jobs[index].status = .failed
            jobs[index].errorMessage = "No audio track found in the video file."
            return
        }
        
        // Step 2: Transcribe
        jobs[index].status = .transcribing
        jobs[index].progress = 0.2
        
        do {
            let result = try await whisperService.transcribe(
                audioURL: audioURL,
                settings: settings
            ) { progress in
                Task { @MainActor in
                    if index < self.jobs.count {
                        self.jobs[index].progress = 0.2 + (progress * 0.8) // 80% for transcription
                        self.jobs[index].estimateTimeRemaining()
                    }
                }
            }
            
            jobs[index].segments = result.segments
            jobs[index].fullTranscript = result.fullText
            jobs[index].detectedLanguage = result.language
            jobs[index].status = .completed
            jobs[index].progress = 1.0
            jobs[index].endTime = Date()
            
        } catch {
            jobs[index].status = .failed
            jobs[index].errorMessage = "Transcription failed: \(error.localizedDescription)"
        }
        
        // Cleanup temp files
        if settings.autoCleanup {
            try? FileManager.default.removeItem(at: tempDir)
            jobs[index].tempAudioURL = nil
        }
    }
    
    // MARK: - Copy / Export
    
    func copyCurrentTranscript() {
        guard let job = selectedJob, let transcript = job.fullTranscript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
    }
    
    func exportTranscript(job: TranscriptionJob, format: ExportFormat) {
        guard let transcript = job.fullTranscript else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = job.fileName + format.fileExtension
        
        if let outputDir = settings.outputDirectory {
            panel.directoryURL = outputDir
        }
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let content: String
                    switch format {
                    case .txt:
                        content = self.exportService.exportAsTxt(transcript: transcript, segments: job.segments)
                    case .srt:
                        content = self.exportService.exportAsSrt(segments: job.segments)
                    case .json:
                        content = self.exportService.exportAsJson(job: job)
                    case .doc:
                        content = self.exportService.exportAsDoc(transcript: transcript, segments: job.segments)
                    }
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Job Management
    
    func removeJob(_ job: TranscriptionJob) {
        jobs.removeAll { $0.id == job.id }
        if selectedJobId == job.id {
            selectedJobId = jobs.first?.id
        }
    }
    
    func clearCompleted() {
        jobs.removeAll { $0.status == .completed }
        if let selectedId = selectedJobId, !jobs.contains(where: { $0.id == selectedId }) {
            selectedJobId = jobs.first?.id
        }
    }
}
