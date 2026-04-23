import SwiftUI
import UniformTypeIdentifiers

struct TranscriptDetailView: View {
    @Environment(AppState.self) private var appState
    let job: TranscriptionJob
    
    @State private var searchText = ""
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(.background)
                .border(width: 1, edges: [.bottom], color: Color.secondary.opacity(0.2))
            
            // Content
            if job.status == .pending || job.status == .downloadingModel || job.status == .extractingAudio || job.status == .transcribing {
                loadingView
            } else if job.status == .failed {
                errorView
            } else if let transcript = job.fullTranscript {
                transcriptView(transcript)
            } else {
                ContentUnavailableView("No Transcript", systemImage: "doc.text")
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if job.status == .completed {
                    Button {
                        appState.copyCurrentTranscript()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .help("Copy full transcript")
                    
                    Menu {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Button {
                                appState.exportTranscript(job: job, format: format)
                            } label: {
                                Label(format.rawValue, systemImage: format.icon)
                            }
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .help("Export transcript")
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.fileName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    Label(job.fileSizeFormatted, systemImage: "doc.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let lang = job.detectedLanguage {
                        Label(lang.uppercased(), systemImage: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let duration = job.durationFormatted {
                        Label(duration, systemImage: "stopwatch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if job.status == .pending {
                Image(systemName: "clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Ready to Transcribe")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Button("Start Transcription") {
                    appState.startTranscription(for: job)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 20)
            } else {
                VStack(spacing: 16) {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.circular)
                        .controlSize(.large)
                        .tint(job.status == .extractingAudio ? .orange : (job.status == .downloadingModel ? .purple : .blue))
                    
                    Text(job.status.rawValue)
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    if let eta = job.estimatedTimeRemaining {
                        Text("Estimated time remaining: \(TranscriptionJob.formatDuration(eta))")
                            .foregroundStyle(.secondary)
                    } else if job.progress > 0 {
                        Text("\(Int(job.progress * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    
                    if job.status == .downloadingModel {
                        Text("Downloading \(appState.settings.selectedModel.displayName) Model...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if job.status == .extractingAudio {
                        Text("Extracting audio with FFmpeg...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Transcribing with whisper.cpp (\(appState.settings.selectedModel.displayName))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorView: some View {
        ContentUnavailableView {
            Label("Transcription Failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } description: {
            Text(job.errorMessage ?? "An unknown error occurred.")
                .multilineTextAlignment(.center)
        } actions: {
            Button("Retry") {
                appState.startTranscription(for: job)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func transcriptView(_ transcript: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if appState.settings.enableTimestamps && !job.segments.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(job.segments) { segment in
                            HStack(alignment: .top, spacing: 16) {
                                Text(segment.startTimestamp)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                                    .frame(width: 85, alignment: .leading)
                                
                                Text(segment.text)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.05))
                                    .padding(.horizontal, 8)
                            )
                        }
                    }
                    .padding(.vertical)
                } else {
                    Text(transcript)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Custom edge border helper
extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }
            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }
            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }
            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}
