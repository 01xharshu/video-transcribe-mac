import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    private enum Tabs: Hashable {
        case model, output, advanced
    }
    
    var body: some View {
        TabView {
            ModelSettingsView()
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }
                .tag(Tabs.model)
            
            OutputSettingsView()
                .tabItem {
                    Label("Output", systemImage: "doc.text")
                }
                .tag(Tabs.output)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(Tabs.advanced)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct ModelSettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        let settings = state.settings
        
        Form {
            Section {
                Picker("Whisper Model:", selection: $state.settings.selectedModel) {
                    ForEach(WhisperModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .disabled(appState.modelDownloader.isDownloading)
                
                Text(settings.selectedModel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 120) // Align with picker content
                
                // Model Download Status
                HStack {
                    Spacer()
                    if appState.whisperService.resolveModelPath(settings: settings) != nil {
                        Label("Model is downloaded and ready.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else if appState.modelDownloader.isDownloading {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(appState.modelDownloader.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ProgressView(value: appState.modelDownloader.progress)
                                .progressViewStyle(.linear)
                                .frame(width: 150)
                            
                            Button("Cancel") {
                                appState.modelDownloader.cancel()
                            }
                            .font(.caption)
                            .controlSize(.mini)
                        }
                    } else {
                        Button {
                            appState.modelDownloader.downloadModel(settings.selectedModel) { success in
                                if success {
                                    appState.checkDependencies()
                                }
                            }
                        } label: {
                            Label("Download Model", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 4)
                
                if let error = appState.modelDownloader.downloadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            
            Section {
                HStack {
                    Text("Speed vs Accuracy:")
                        .frame(width: 112, alignment: .trailing)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Speed:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            HStack(spacing: 2) {
                                ForEach(0..<5) { i in
                                    Circle()
                                        .fill(i < settings.selectedModel.speedRating ? Color.blue : Color.secondary.opacity(0.2))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Accuracy:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            HStack(spacing: 2) {
                                ForEach(0..<5) { i in
                                    Circle()
                                        .fill(i < settings.selectedModel.accuracyRating ? Color.green : Color.secondary.opacity(0.2))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            Section {
                Picker("Language:", selection: $state.settings.language) {
                    ForEach(TranscriptionLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                
                Text("Select specific language if known for better accuracy, or Auto-Detect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 120)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.selectedModel) { _, _ in
            appState.settings.save()
        }
        .onChange(of: settings.language) { _, _ in
            appState.settings.save()
        }
    }
}

struct OutputSettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        let settings = state.settings
        
        Form {
            Section {
                Toggle("Include Timestamps", isOn: $state.settings.enableTimestamps)
                
                Text("Shows timestamps next to transcript segments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
                
                Toggle("Auto-cleanup temporary files", isOn: $state.settings.autoCleanup)
                
                Text("Deletes extracted audio files after transcription completes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
            
            Section("Default Export Location") {
                HStack {
                    Text(settings.outputDirectory?.path ?? "Ask every time")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(settings.outputDirectory == nil ? .secondary : .primary)
                    
                    Spacer()
                    
                    Button("Choose...") {
                        selectOutputDirectory()
                    }
                    
                    if settings.outputDirectory != nil {
                        Button("Clear") {
                            state.settings.outputDirectory = nil
                            appState.settings.save()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.enableTimestamps) { _, _ in appState.settings.save() }
        .onChange(of: settings.autoCleanup) { _, _ in appState.settings.save() }
    }
    
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Output Folder"
        
        if panel.runModal() == .OK {
            appState.settings.outputDirectory = panel.url
            appState.settings.save()
        }
    }
}

struct AdvancedSettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        let settings = state.settings
        
        Form {
            Section("whisper.cpp Binary Path") {
                TextField("", text: $state.settings.whisperPath)
                    .textFieldStyle(.roundedBorder)
                
                Text("Path to whisper-cpp executable. Leave default if installed via Homebrew.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Models Directory (Optional)") {
                HStack {
                    TextField("", text: $state.settings.modelsDirectory)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            state.settings.modelsDirectory = url.path
                            appState.settings.save()
                        }
                    }
                }
                
                Text("Custom directory containing ggml-*.bin models. If empty, standard paths are searched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Performance") {
                Stepper("Threads: \(settings.threads == 0 ? "Auto" : "\(settings.threads)")", value: $state.settings.threads, in: 0...32)
                Text("0 uses the default number of threads (recommended).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.whisperPath) { _, _ in appState.settings.save() }
        .onChange(of: settings.modelsDirectory) { _, _ in appState.settings.save() }
        .onChange(of: settings.threads) { _, _ in appState.settings.save() }
    }
}
