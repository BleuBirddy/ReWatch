import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: MediaLibrary
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("theme") private var theme: AppTheme = .standard
    @State private var showImporter = false
    @State private var playing: MediaItem?

    var body: some View {
        NavigationStack {
            Group {
                if library.items.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing to watch yet", systemImage: "play.rectangle")
                    } description: {
                        Text("Import mp3, mp4, flac or mkv files, or drop them into the ReWatch folder in the Files app.")
                    } actions: {
                        Button { showImporter = true } label: {
                            Text("Import Files").foregroundStyle(theme.background)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(library.items) { item in
                            Button { playing = item } label: { MediaRow(item: item) }
                                .listRowBackground(theme.surface)
                        }
                        .onDelete { offsets in
                            offsets.map { library.items[$0] }.forEach(library.delete)
                        }
                    }
                    // Hide the system's grey list background so ours shows.
                    .scrollContentBackground(.hidden)
                    .refreshable { library.reload() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("ReWatch")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    themeMenu
                    Button { showImporter = true } label: {
                        Label { Text("Import") } icon: { tinted("plus") }
                    }
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: MediaLibrary.importTypes,
                          allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { library.importPicked(urls) }
            }
            .fullScreenCover(item: $playing) { item in
                PlayerView(item: item)
            }
            .alert("Import problem", isPresented: Binding(
                get: { library.lastError != nil },
                set: { if !$0 { library.lastError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.lastError ?? "")
            }
            // Picks up files added through the Files app while ReWatch was away.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { library.reload() }
            }
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

    /// A toolbar icon in the theme colour. The glass toolbar recolours
    /// ordinary (template) icons to white for legibility, ignoring tint and
    /// foregroundStyle, so the colour is baked into the image instead.
    private func tinted(_ symbol: String) -> Image {
        let config = UIImage.SymbolConfiguration(textStyle: .body, scale: .large)
        guard let image = UIImage(systemName: symbol, withConfiguration: config) else { return Image(systemName: symbol) }
        return Image(uiImage: image.withTintColor(UIColor(theme.accent), renderingMode: .alwaysOriginal))
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
                Text("\(item.ext.uppercased()) · \(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))")
                    .font(.caption)
                    // Dimmer than the title, but not .secondary: that fades
                    // to ~60% and drops under readable contrast on ReWatch.
                    .opacity(0.8)
            }
        }
        .padding(.vertical, 4)
    }
}
