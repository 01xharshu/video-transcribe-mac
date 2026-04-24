import SwiftUI

struct TranscriptReaderView: View {
    @Environment(AppState.self) private var appState
    let job: TranscriptionJob
    
    @State private var searchText = ""
    @State private var copied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Reader Toolbar
            HStack(spacing: 20) {
                Button {
                    copyToPasteboard()
                } label: {
                    Label(copied ? "Copied!" : "Copy to Clipboard", systemImage: copied ? "checkmark" : "doc.on.doc")
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
                
                TextField("Search in transcript...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.secondary.opacity(0.1)), alignment: .bottom)
            
            // Transcript Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let transcript = job.fullTranscript {
                        Text(highlightSearch(transcript))
                            .font(.system(.body, design: .serif))
                            .textSelection(.enabled)
                            .lineSpacing(10)
                            .padding()
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
    
    
    private func copyToPasteboard() {
        guard let transcript = job.fullTranscript else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        
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
