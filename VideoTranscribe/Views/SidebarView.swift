import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
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
        
        Button("Remove", role: .destructive) {
            appState.removeJob(job)
        }
    }
}

struct JobRowView: View {
    let job: TranscriptionJob
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                statusIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.fileName)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack(spacing: 4) {
                        Text(job.fileExtension)
                            .font(.system(.caption2, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        
                        Text(job.fileSizeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if job.status == .downloadingModel || job.status == .extractingAudio || job.status == .transcribing {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)
                        .tint(job.status == .extractingAudio ? .orange : (job.status == .downloadingModel ? .purple : .blue))
                    
                    HStack {
                        Text(job.status.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let eta = job.estimatedTimeRemaining {
                            Text("~\(TranscriptionJob.formatDuration(eta))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Int(job.progress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .font(.title3)
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
