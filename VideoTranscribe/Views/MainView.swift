import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
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
            
            // Bottom Status Bar
            if let error = appState.globalError ?? appState.selectedJob?.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.secondary.opacity(0.2)), alignment: .top)
            }
        }
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

import UniformTypeIdentifiers
