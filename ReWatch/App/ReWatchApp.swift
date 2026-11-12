import SwiftUI
import AVFoundation

@main
struct ReWatchApp: App {
    @StateObject private var recents = Recents()
    @StateObject private var library = LocalLibrary()

    init() {
        // .playback: sound plays even with the silent switch on, and keeps
        // going in the background (paired with UIBackgroundModes = audio).
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        #endif
        // Bars must be styled before the first one is created.
        let saved = UserDefaults.standard.string(forKey: "theme").flatMap(AppTheme.init) ?? .standard
        saved.applyToNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(recents)
                .environmentObject(library)
                // "Open in ReWatch" from Files or the share sheet, or
                // Open With / double-click in Finder: play it where it is.
                .onOpenURL { url in recents.open(url) }
                #if os(macOS)
                // Below this the toolbar and list rows start to crowd.
                .frame(minWidth: 480, minHeight: 420)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 560)
        #endif
        .commands {
            // File > Open… (⌘O), in place of File > New, which does nothing here.
            CommandGroup(replacing: .newItem) {
                Button("Open…") { recents.openRequested = true }
                    .keyboardShortcut("o")
                Button("Import…") { library.importRequested = true }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        // On the Mac each file plays in its own window, so it can sit beside
        // the library, be resized, or go full screen with the green button.
        WindowGroup("Player", for: MediaItem.self) { $item in
            if let item {
                PlayerView(item: item)
                    .frame(minWidth: 480, minHeight: 320)
            }
        }
        .defaultSize(width: 960, height: 600)
        #endif
    }
}
