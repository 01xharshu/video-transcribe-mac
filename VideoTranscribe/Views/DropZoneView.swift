import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Environment(AppState.self) private var appState
    @State private var isTargeted = false
    @State private var animateGradient = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    // Glow ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.blue, .purple, .pink, .orange, .blue],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .opacity(isTargeted ? 0.8 : 0.2)
                        .rotationEffect(.degrees(animateGradient ? 360 : 0))
                        .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: animateGradient)
                    
                    // Icon background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "film")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(
                            isTargeted
                                ? AnyShapeStyle(.blue)
                                : AnyShapeStyle(.secondary)
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .scaleEffect(isTargeted ? 1.1 : 1.0)
                .animation(.spring(duration: 0.3), value: isTargeted)
                
                VStack(spacing: 8) {
                    Text("Drop Video Files Here")
                        .font(.system(.title2, weight: .semibold))
                    
                    Text("Supports MP4, MOV, MKV, WebM, AVI, and more")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                
                HStack(spacing: 12) {
                    Button {
                        appState.showFilePicker = true
                    } label: {
                        Label("Choose Files", systemImage: "folder")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button {
                        selectFolder()
                    } label: {
                        Label("Choose Folder", systemImage: "folder.badge.plus")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                // Status indicators
                HStack(spacing: 20) {
                    StatusIndicator(
                        icon: "lock.shield.fill",
                        text: "100% Local",
                        color: .green
                    )
                    
                    StatusIndicator(
                        icon: "bolt.fill",
                        text: "Metal Accelerated",
                        color: .orange
                    )
                    
                    StatusIndicator(
                        icon: "eye.slash.fill",
                        text: "Private",
                        color: .blue
                    )
                }
                .padding(.top, 8)
                
                // Dependency warnings
                if !appState.ffmpegAvailable || !appState.whisperAvailable {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.horizontal, 40)
                        
                        if !appState.ffmpegAvailable {
                            DependencyWarning(
                                name: "FFmpeg",
                                installCommand: "brew install ffmpeg"
                            )
                        }
                        
                        if !appState.whisperAvailable {
                            DependencyWarning(
                                name: "whisper.cpp",
                                installCommand: "brew install whisper-cpp"
                            )
                        }
                        
                        Button("Setup Guide") {
                            appState.showSetupGuide = true
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 4])
                )
                .padding(20)
        }
        .background(.background)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .onAppear {
            animateGradient = true
        }
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
