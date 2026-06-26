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
        .alert("Error", isPresented: Binding(
            get: { appState.globalError != nil },
            set: { if !$0 { appState.globalError = nil } }
        )) {
            Button("OK", role: .cancel) {
                appState.globalError = nil
            }
        } message: {
            if let error = appState.globalError {
                Text(error)
            }
        }
        .fileImporter(
            isPresented: $state.showFilePicker,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onDrop(of: supportedTypes, isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        HStack(spacing: 16) {
            // Detailed Job Status
            let activeJobs = appState.jobs.filter { $0.status != .pending && $0.status != .completed && $0.status != .failed }
            if let activeJob = activeJobs.first {
                HStack(spacing: 8) {
                    Text(activeJob.fileName)
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                    
                    ProgressView(value: activeJob.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                        .controlSize(.mini)
                    
                    Text("\(Int(activeJob.progress * 100))%")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    // Show queue count if more pending
                    let pendingCount = appState.jobs.filter({ $0.status == .pending }).count
                    if pendingCount > 0 {
                        Text("+\(pendingCount) queued")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.trailing, 10)
            } else {
                // Dependency Status (Only show if missing)
                if !appState.ffmpegAvailable || !appState.whisperAvailable {
                    HStack(spacing: 8) {
                        if !appState.ffmpegAvailable {
                            StatusChip(name: "FFmpeg Missing", icon: "exclamationmark.triangle.fill", isAvailable: false)
                        }
                        if !appState.whisperAvailable {
                            StatusChip(name: "Whisper Missing", icon: "exclamationmark.triangle.fill", isAvailable: false)
                        }
                    }
                    .padding(.trailing, 10)
                }
            }
            
            if appState.jobs.contains(where: { $0.status == .pending }) {
                Button {
                    appState.startAllPending()
                } label: {
                    Label("Transcribe All", systemImage: "play.fill")
                }
                .help("Start all pending transcriptions")
            }
            
            Button {
                appState.showFilePicker = true
            } label: {
                Label("Open", systemImage: "plus")
            }
            .help("Add video files (⌘O)")
            
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings (⌘,)")
            } else {
                Button {
                    NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings (⌘,)")
            }
        }
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
