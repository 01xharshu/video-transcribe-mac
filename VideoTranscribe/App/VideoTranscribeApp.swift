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
