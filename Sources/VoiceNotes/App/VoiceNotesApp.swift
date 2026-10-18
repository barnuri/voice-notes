import SwiftUI
import VoiceNotesCore

@main
struct VoiceNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("VoiceNotes") {
            ContentView()
                .environment(appDelegate.settings)
                .environment(appDelegate.store)
                .environment(appDelegate.controller)
                .environment(appDelegate.sync)
                .environment(appDelegate.microphones)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { RecordingCommands(controller: appDelegate.controller) }

        Settings {
            SettingsView()
                .environment(appDelegate.settings)
                .environment(appDelegate.sync)
                .environment(appDelegate.microphones)
                .environment(appDelegate.dictation)
                .environment(appDelegate.globalHotKey)
        }
    }
}
