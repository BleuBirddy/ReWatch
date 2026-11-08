import SwiftUI

/// The main screen: files you've opened recently, and a way to open more.
/// Nothing here is stored in the app; each row is a reference to a file
/// wherever it lives (Files, iCloud Drive, a USB drive, Downloads...).
struct LibraryView: View {
    @EnvironmentObject private var recents: Recents
    @AppStorage("theme") private var theme: AppTheme = .standard
    @State private var showOpenPanel = false
    @State private var playing: MediaItem?
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if recents.items.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing playing yet", systemImage: "play.rectangle")
                    } description: {
                        Text(Self.emptyHint)
                    } actions: {
                        Button { showOpenPanel = true } label: {
                            Text("Open a File").foregroundStyle(theme.background)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(recents.items) { item in
                                Button { replay(item) } label: { MediaRow(item: item) }
                                    .buttonStyle(.plain)
                                    .listRowBackground(theme.surface)
                                    // "Remove" forgets the entry; the file stays put.
                                    .swipeActions {
                                        Button(role: .destructive) { recents.forget(item) } label: {
                                            Label("Remove", systemImage: "minus.circle")
                                        }
                                    }
                                    .contextMenu {
                                        Button("Remove from Recents", systemImage: "minus.circle") { recents.forget(item) }
                                    }
                            }
                        } header: {
                            Text("Recent").foregroundStyle(theme.accent.opacity(0.8))
                        }
                    }
                    // Hide the system's grey list background so ours shows.
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            // Drop files on the window (Mac, or iPad side by side with
            // Files): plays the first one straight away.
            .dropDestination(for: URL.self) { urls, _ in
                recents.open(urls)
                return true
            }
            .navigationTitle("ReWatch")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    themeMenu
                    Button { showOpenPanel = true } label: {
                        Label { Text("Open") } icon: { tinted("folder") }
                    }
                }
            }
            .fileImporter(isPresented: $showOpenPanel,
                          allowedContentTypes: Recents.openTypes) { result in
                if case .success(let url) = result { recents.open(url) }
            }
            #if os(iOS)
            .fullScreenCover(item: $playing) { item in
                PlayerView(item: item)
            }
            #endif
            .alert("Can't play that", isPresented: Binding(
                get: { recents.lastError != nil },
                set: { if !$0 { recents.lastError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(recents.lastError ?? "")
            }
            .onChange(of: recents.openRequested) { _, requested in
                if requested { showOpenPanel = true; recents.openRequested = false }
            }
            // A file opened from outside the list (Open panel, a drop,
            // Open in ReWatch, Finder): play it.
            .onChange(of: recents.playRequest) { _, item in
                if let item { play(item); recents.playRequest = nil }
            }
            #if DEBUG
            // Testing aid, debug builds only: REWATCH_AUTOPLAY=<path> opens
            // that file at launch, so playback can be checked without clicking.
            .onAppear {
                if let path = ProcessInfo.processInfo.environment["REWATCH_AUTOPLAY"] {
                    recents.open(URL(fileURLWithPath: path))
                }
            }
            #endif
        }
        // Text, icons and buttons all take the theme colour from here down.
        .foregroundStyle(theme.accent)
        .tint(theme.accent)
        // All three themes are dark backgrounds, so system sheets (file
        // picker, alerts, menus) should be dark too.
        .preferredColorScheme(.dark)
        // New bars pick up the new title colour (see applyToNavigationBars).
        .id(theme)
    }

    /// A Recents row: check the file is still there, then play it.
    private func replay(_ item: MediaItem) {
        if let ready = recents.prepare(item) { play(ready) }
    }

    /// iPhone/iPad: full screen over the list. Mac: a new window.
    private func play(_ item: MediaItem) {
        #if os(macOS)
        openWindow(value: item)
        #else
        playing = item
        #endif
    }

    /// A toolbar icon in the theme colour. The glass toolbar recolours
    /// ordinary (template) icons to white for legibility, ignoring tint and
    /// foregroundStyle, so the colour is baked into the image instead.
    private func tinted(_ symbol: String) -> Image {
        #if os(iOS)
        let config = UIImage.SymbolConfiguration(textStyle: .body, scale: .large)
        guard let image = UIImage(systemName: symbol, withConfiguration: config) else { return Image(systemName: symbol) }
        return Image(uiImage: image.withTintColor(UIColor(theme.accent), renderingMode: .alwaysOriginal))
        #else
        let config = NSImage.SymbolConfiguration(textStyle: .body, scale: .large)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(theme.accent)]))
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return Image(systemName: symbol) }
        return Image(nsImage: image)
        #endif
    }

    private static var emptyHint: String {
        #if os(macOS)
        "Open an mp3, mp4, flac or mkv file, or drag one onto this window. It plays from where it is; nothing is copied."
        #else
        "Open an mp3, mp4, flac or mkv file from Files, or share one to ReWatch. It plays from where it is; nothing is copied."
        #endif
    }

    private var themeMenu: some View {
        Menu {
            Picker("Theme", selection: Binding(
                get: { theme },
                // Style the bars first, so the rebuilt ones use the new colour.
                set: { newTheme in newTheme.applyToNavigationBars(); theme = newTheme })) {
                ForEach(AppTheme.allCases) { Text($0.name).tag($0) }
            }
        } label: {
            Label { Text("Theme") } icon: { tinted("paintpalette") }
        }
    }
}

private struct MediaRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isAudio ? "music.note" : "film")
                .font(.title2)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).lineLimit(2)
                Text("\(item.ext.uppercased()) · \(item.lastOpened.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    // Dimmer than the title, but not .secondary: that fades
                    // to ~60% and drops under readable contrast on ReWatch.
                    .opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        // The whole row is clickable on the Mac, not just the text.
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
