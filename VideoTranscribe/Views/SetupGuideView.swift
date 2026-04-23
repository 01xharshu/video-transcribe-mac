import SwiftUI

struct SetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var checking = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Required Dependencies")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Video Transcribe needs FFmpeg and whisper.cpp to run locally on your Mac.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical, 32)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Homebrew step
                    StepView(
                        number: 1,
                        title: "Install Homebrew (if not installed)",
                        description: "Homebrew is a package manager for macOS.",
                        command: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                    )
                    
                    // FFmpeg step
                    StepView(
                        number: 2,
                        title: "Install FFmpeg",
                        description: "Used to extract audio from video files.",
                        command: "brew install ffmpeg",
                        isInstalled: appState.ffmpegAvailable
                    )
                    
                    // Whisper step
                    StepView(
                        number: 3,
                        title: "Install whisper.cpp",
                        description: "The core transcription engine, optimized for Apple Silicon.",
                        command: "brew install whisper-cpp",
                        isInstalled: appState.whisperAvailable
                    )
                    
                    // Models step
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "4.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Download a Model")
                                .font(.headline)
                            
                            Text("The app requires an AI model to transcribe audio. We recommend the default 'Large v3 Turbo' for best accuracy.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if appState.whisperService.resolveModelPath(settings: appState.settings) != nil {
                                Label("Model downloaded successfully!", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .padding(.top, 4)
                            } else if appState.modelDownloader.isDownloading {
                                VStack(alignment: .leading) {
                                    Text(appState.modelDownloader.statusText)
                                        .font(.caption)
                                    ProgressView(value: appState.modelDownloader.progress)
                                        .progressViewStyle(.linear)
                                    Button("Cancel") {
                                        appState.modelDownloader.cancel()
                                    }
                                    .controlSize(.small)
                                }
                                .padding(.top, 4)
                            } else {
                                Button("Download Model (\(appState.settings.selectedModel.displayName))") {
                                    appState.modelDownloader.downloadModel(appState.settings.selectedModel) { success in
                                        if success { appState.checkDependencies() }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                                
                                if let err = appState.modelDownloader.downloadError {
                                    Text(err).foregroundStyle(.red).font(.caption)
                                }
                            }
                        }
                    }
                }
                .padding(32)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                if checking {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }
                
                Button("Check Again") {
                    checking = true
                    appState.checkDependencies()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        checking = false
                        if appState.ffmpegAvailable && appState.whisperAvailable {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 600, height: 650)
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    let command: String
    var isInstalled: Bool? = nil
    
    @State private var copied = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(isInstalled == true ? Color.green : Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                if isInstalled == true {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .bold))
                } else {
                    Text("\(number)")
                        .foregroundStyle(Color.blue)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    if isInstalled == true {
                        Text("Installed")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text(description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Code block
                HStack {
                    Text(command)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}
