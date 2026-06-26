import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var youtubeURL = ""
    @State private var showYouTubeInput = false
    @State private var batchAddedCount: Int? = nil
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            List(selection: $state.selectedJobId) {
                if appState.jobs.isEmpty {
                    ContentUnavailableView {
                        Label("No Videos", systemImage: "film")
                    } description: {
                        Text("Drop video files here or click + to add")
                    }
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(appState.jobs) { job in
                            JobRowView(job: job)
                                .tag(job.id)
                                .contextMenu {
                                    jobContextMenu(for: job)
                                }
                        }
                    } header: {
                        HStack {
                            Text("Files (\(appState.jobs.count))")
                            Spacer()
                            if appState.jobs.contains(where: { $0.status == .completed }) {
                                Button("Clear Done") {
                                    appState.clearCompleted()
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            // MARK: - Persistent YouTube Input
            Divider()
            
            youtubeInputSection
        }
    }
    
    // MARK: - YouTube Input Section
    @ViewBuilder
    private var youtubeInputSection: some View {
        VStack(spacing: 8) {
            // Toggle / header
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showYouTubeInput.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("Add YouTube")
                        .font(.system(.caption, weight: .semibold))
                    Spacer()
                    Image(systemName: showYouTubeInput ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showYouTubeInput {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("YouTube URL", text: $youtubeURL)
                            .textFieldStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onSubmit {
                                submitYouTubeURL()
                            }
                        
                        Button {
                            if let clipboard = NSPasteboard.general.string(forType: .string) {
                                // Try batch paste first
                                let count = appState.addYouTubeURLs(clipboard)
                                if count > 0 {
                                    batchAddedCount = count
                                    youtubeURL = ""
                                    autoStartQueueIfNeeded()
                                    // Clear notification after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        batchAddedCount = nil
                                    }
                                } else {
                                    // Single URL fallback
                                    youtubeURL = clipboard
                                }
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Paste from clipboard (supports multiple URLs)")
                        
                        Button {
                            submitYouTubeURL()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                        .disabled(youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("Add YouTube video")
                    }
                    
                    if let count = batchAddedCount {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("Added \(count) video\(count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Queue status
                    if appState.isProcessingQueue {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Queue running — add more anytime")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(.background)
    }
    
    private func submitYouTubeURL() {
        let trimmed = youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Try batch add first (handles multiple URLs pasted)
        let batchCount = appState.addYouTubeURLs(trimmed)
        if batchCount > 0 {
            if batchCount > 1 {
                batchAddedCount = batchCount
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    batchAddedCount = nil
                }
            }
        } else {
            // Single URL
            appState.addYouTubeURL(trimmed)
        }
        youtubeURL = ""
        autoStartQueueIfNeeded()
    }
    
    private func autoStartQueueIfNeeded() {
        // Auto-start queue if it's not already running
        if !appState.isProcessingQueue && appState.jobs.contains(where: { $0.status == .pending }) {
            appState.startAllPending()
        }
    }
    
    @ViewBuilder
    private func jobContextMenu(for job: TranscriptionJob) -> some View {
        if job.status == .pending || job.status == .failed {
            Button("Start Transcription") {
                appState.startTranscription(for: job)
            }
        }
        
        if job.status == .completed {
            Button("Copy Transcript") {
                if let transcript = job.fullTranscript {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcript, forType: .string)
                }
            }
            
            Divider()
            
            Menu("Export As…") {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(format.rawValue) {
                        appState.exportTranscript(job: job, format: format)
                    }
                }
            }
        }
        
        Divider()
        
        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(job.inputURL.path, inFileViewerRootedAtPath: "")
        }
        .disabled(job.isYouTube)
        
        Button("Remove", role: .destructive) {
            appState.removeJob(job)
        }
    }
}

struct JobRowView: View {
    let job: TranscriptionJob
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                statusIcon
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(job.fileName)
                        .font(.system(.body, design: .default, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack(spacing: 6) {
                        if job.isYouTube {
                            HStack(spacing: 3) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 10))
                                Text("YouTube")
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                        } else {
                            Text(job.fileExtension.uppercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !job.isYouTube {
                            Text(job.fileSizeFormatted)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            
            if job.status == .downloadingVideo || job.status == .downloadingModel || job.status == .extractingAudio || job.status == .transcribing {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)
                        .tint(job.status == .downloadingVideo ? .red : (job.status == .extractingAudio ? .orange : (job.status == .downloadingModel ? .purple : .blue)))
                        .frame(height: 4)
                    
                    HStack {
                        Text(job.status.rawValue)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let eta = job.estimatedTimeRemaining {
                            Text("~\(TranscriptionJob.formatDuration(eta))")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Int(job.progress * 100))%")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
            
            if let warning = job.warning {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .font(.title3)
        case .downloadingVideo:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.red)
                .font(.title3)
                .symbolEffect(.variableColor.iterative)
        case .downloadingModel:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.purple)
                .font(.title3)
                .symbolEffect(.variableColor.iterative)
        case .extractingAudio:
            Image(systemName: "waveform")
                .foregroundStyle(.orange)
                .font(.title3)
                .symbolEffect(.variableColor.iterative)
        case .transcribing:
            Image(systemName: "text.word.spacing")
                .foregroundStyle(.blue)
                .font(.title3)
                .symbolEffect(.variableColor.iterative)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)
        }
    }
}
