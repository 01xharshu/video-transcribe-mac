import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Environment(AppState.self) private var appState
    @State private var isTargeted = false
    @State private var animateGradient = false
    @State private var youtubeURL = ""
    @State private var isValidatingURL = false
    
    var body: some View {
        ZStack {
            backdropView
            
            VStack {
                Spacer()
                
                ContentUnavailableView {
                    Label("No Video Selected", systemImage: "film")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color.primary)
                        .symbolEffect(.pulse, options: .repeating, isActive: isTargeted)
                } description: {
                    Text("Drag and drop media files, or paste a YouTube link to begin.")
                        .font(.system(.body, design: .default))
                        .foregroundStyle(.secondary)
                } actions: {
                    actionsView
                }
                
                Spacer()
                
                statusIndicators
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            dropZoneBorder
        }
        .background(.background)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }
    
    @ViewBuilder
    private var actionsView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Button("Choose Files…") {
                    appState.showFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Choose Folder…") {
                    selectFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 10)
            
            youtubeInputView
        }
    }
    
    @ViewBuilder
    private var youtubeInputView: some View {
        VStack(spacing: 12) {
            Divider()
                .frame(maxWidth: 300)
                .padding(.vertical, 10)
            
            Text("Or download from YouTube")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                TextField("Paste YouTube URL here", text: $youtubeURL)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit {
                        submitYouTubeURL()
                    }
                
                Button {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        youtubeURL = clipboard
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .help("Paste from clipboard")
                
                Button("Add") {
                    submitYouTubeURL()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(maxWidth: 400)
        }
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var backdropView: some View {
        if !isTargeted {
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private var statusIndicators: some View {
        HStack(spacing: 24) {
            StatusIndicator(icon: "lock.shield.fill", text: "100% Local", color: .green)
            StatusIndicator(icon: "bolt.fill", text: "Metal Accelerated", color: .orange)
            StatusIndicator(icon: "eye.slash.fill", text: "Private", color: .blue)
        }
        .padding(.bottom, 30)
    }
    
    @ViewBuilder
    private var dropZoneBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.clear,
                style: StrokeStyle(lineWidth: 3, dash: isTargeted ? [10, 5] : [])
            )
            .background(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
            .animation(.easeInOut(duration: 0.2), value: isTargeted)
            .padding(16)
    }
    
    private func submitYouTubeURL() {
        let trimmed = youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        appState.addYouTubeURL(trimmed)
        youtubeURL = ""
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Select a folder containing video files"
        
        panel.begin { response in
            if response == .OK {
                appState.addFiles(urls: panel.urls)
            }
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        appState.addFiles(urls: [url])
                    }
                }
            }
        }
    }
}

struct StatusIndicator: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DependencyWarning: View {
    let name: String
    let installCommand: String
    @State private var copied = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            
            Text("\(name) not found.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(installCommand, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                HStack(spacing: 3) {
                    Text(copied ? "Copied!" : installCommand)
                        .font(.system(.caption, design: .monospaced))
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }
}
