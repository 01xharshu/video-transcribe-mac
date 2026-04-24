import SwiftUI

@main
struct VideoTranscribeApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appState.checkDependencies()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 720)
        
        WindowGroup(id: "transcript-reader", for: UUID.self) { $jobId in
            if let jobId = jobId, let job = appState.jobs.first(where: { $0.id == jobId }) {
                TranscriptReaderView(job: job)
                    .environment(appState)
            } else {
                Text("No transcript selected")
                    .padding()
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Video Files…") {
                    appState.showFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Copy Transcript") {
                    appState.copyCurrentTranscript()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(appState.selectedJob == nil)
            }
            
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        with: nil
                    )
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
        }
        #endif
    }
}
