import SwiftUI
import AVFoundation

@main
struct ReWatchApp: App {
    @StateObject private var library = MediaLibrary()

    init() {
        // .playback: sound plays even with the silent switch on, and keeps
        // going in the background (paired with UIBackgroundModes = audio).
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        // Bars must be styled before the first one is created.
        let saved = UserDefaults.standard.string(forKey: "theme").flatMap(AppTheme.init) ?? .standard
        saved.applyToNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                // "Open in ReWatch" from Files or the share sheet.
                .onOpenURL { url in library.importShared(url) }
        }
    }
}
