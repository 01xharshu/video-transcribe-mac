import SwiftUI

struct TranscriptReaderView: View {
    @Environment(AppState.self) private var appState
    let job: TranscriptionJob
    
    @State private var showTimestamps: Bool = true
    @State private var searchText = ""
    @State private var copied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Reader Toolbar
            HStack(spacing: 20) {
                Toggle(isOn: $showTimestamps) {
                    Label("Timestamps", systemImage: "clock")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                
                Divider().frame(height: 16)
                
                Button {
                    copyToPasteboard()
                } label: {
                    Label(copied ? "Copied!" : "Copy All", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .tint(copied ? .green : .accentColor)
                
                Menu {
                    Button {
                        appState.exportTranscript(job: job, format: .doc)
                    } label: {
                        Label("Microsoft Word (.doc)", systemImage: "doc.richtext")
                    }
                    
                    Button {
                        appState.exportTranscript(job: job, format: .txt)
                    } label: {
                        Label("Plain Text (.txt)", systemImage: "doc.text")
                    }
                    
                    Button {
                        appState.exportTranscript(job: job, format: .srt)
                    } label: {
                        Label("Subtitles (.srt)", systemImage: "captions.bubble")
                    }
                } label: {
                    Label("Download As...", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.secondary.opacity(0.1)), alignment: .bottom)
            
            // Transcript Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let transcript = job.fullTranscript {
                        if showTimestamps && !job.segments.isEmpty {
                            ForEach(filteredSegments) { segment in
                                HStack(alignment: .top, spacing: 16) {
                                    Text(segment.startTimestamp)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 2)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Text(highlightSearch(segment.text))
                                        .font(.system(.body, design: .serif))
                                        .textSelection(.enabled)
                                        .lineSpacing(6)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        } else {
                            Text(highlightSearch(transcript))
                                .font(.system(.body, design: .serif))
                                .textSelection(.enabled)
                                .lineSpacing(8)
                                .padding()
                        }
                    } else {
                        ContentUnavailableView("No Transcript", systemImage: "doc.text")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Reader: \(job.fileName)")
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var filteredSegments: [TranscriptionSegment] {
        if searchText.isEmpty {
            return job.segments
        } else {
            return job.segments.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func copyToPasteboard() {
        guard let transcript = job.fullTranscript else { return }
        let content: String
        
        if showTimestamps {
            content = appState.exportService.exportAsTxt(transcript: transcript, segments: job.segments)
        } else {
            content = transcript
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        withAnimation {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
    
    private func highlightSearch(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        if searchText.isEmpty { return attributedString }
        
        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()
        
        var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
        while let range = lowercasedText.range(of: lowercasedSearch, range: searchRange) {
            if let attributedRange = Range(range, in: attributedString) {
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attributedRange].underlineStyle = .single
            }
            searchRange = range.upperBound..<lowercasedText.endIndex
        }
        
        return attributedString
    }
}
