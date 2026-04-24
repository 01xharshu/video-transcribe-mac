import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        @Bindable var state = appState
        
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            // Main content
            if let job = appState.selectedJob {
                TranscriptDetailView(job: job)
            } else {
                DropZoneView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let error = appState.globalError ?? appState.selectedJob?.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button {
                            if appState.globalError != nil {
                                appState.globalError = nil
                            } else if let id = appState.selectedJob?.id, let index = appState.jobs.firstIndex(where: { $0.id == id }) {
                                appState.jobs[index].errorMessage = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.1))
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(.red.opacity(0.2)), alignment: .top)
                }
                
                HStack(spacing: 16) {
                    // System Status
                    HStack(spacing: 8) {
                        if appState.activeJobsCount > 0 {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Circle()
                                .fill(appState.ffmpegAvailable && appState.whisperAvailable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(appState.systemStatus)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Divider().frame(height: 14)
                    
                    // Dependencies
                    HStack(spacing: 12) {
                        StatusChip(name: "FFmpeg", icon: "waveform", isAvailable: appState.ffmpegAvailable)
                        StatusChip(name: "Whisper", icon: "brain", isAvailable: appState.whisperAvailable)
                    }
                    
                    Spacer()
                    
                    // Detailed Job Status
                    if let activeJob = appState.jobs.first(where: { $0.status != .pending && $0.status != .completed && $0.status != .failed }) {
                        HStack(spacing: 10) {
                            Text(activeJob.fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 150)
                            
                            ProgressView(value: activeJob.progress)
                                .progressViewStyle(.linear)
                                .frame(width: 100)
                                .controlSize(.small)
                            
                            Text("\(Int(activeJob.progress * 100))%")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.secondary.opacity(0.1)), alignment: .top)
            }
        }
        .animation(.spring(), value: appState.globalError)
        .animation(.spring(), value: appState.selectedJob?.errorMessage)
        .animation(.spring(), value: appState.activeJobsCount)
        .animation(.spring(), value: appState.ffmpegAvailable)
        .animation(.spring(), value: appState.whisperAvailable)
        .navigationTitle("Video Transcribe")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarContent
            }
        }
        .fileImporter(
            isPresented: $state.showFilePicker,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $state.showSetupGuide) {
            SetupGuideView()
        }
        .sheet(isPresented: $state.showSettings) {
            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        appState.showSettings = false
                    }
                    .padding([.top, .trailing])
                }
                SettingsView()
            }
            .frame(width: 500, height: 450)
        }
        .onDrop(of: supportedTypes, isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        Button {
            appState.showFilePicker = true
        } label: {
            Label("Open", systemImage: "plus")
        }
        .help("Add video files (⌘O)")
        
        if appState.jobs.contains(where: { $0.status == .pending }) {
            Button {
                appState.startAllPending()
            } label: {
                Label("Transcribe All", systemImage: "play.fill")
            }
            .help("Start all pending transcriptions")
        }
        
        if appState.activeJobsCount > 0 {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("\(appState.activeJobsCount) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        Button {
            appState.showSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .help("Open Settings (⌘,)")
    }
    
    private var supportedTypes: [UTType] {
        [
            .movie, .mpeg4Movie, .quickTimeMovie, .avi,
            UTType(filenameExtension: "mkv") ?? .movie,
            UTType(filenameExtension: "webm") ?? .movie,
            UTType(filenameExtension: "wmv") ?? .movie,
            UTType(filenameExtension: "flv") ?? .movie,
            UTType(filenameExtension: "m4v") ?? .movie,
            .folder
        ]
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            appState.addFiles(urls: urls)
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
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

struct StatusChip: View {
    let name: String
    let icon: String
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(name)
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isAvailable ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
        .foregroundStyle(isAvailable ? .green : .red)
        .clipShape(Capsule())
    }
}

import UniformTypeIdentifiers
