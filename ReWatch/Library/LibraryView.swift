import SwiftUI

/// The main screen: files imported onto this device, files you've opened
/// recently, and ways to open or import more. Recents are references to
/// files wherever they live (Files, iCloud Drive, a USB drive...); only
/// "On This Device" holds real copies.
struct LibraryView: View {
    @EnvironmentObject private var recents: Recents
    @EnvironmentObject private var library: LocalLibrary
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("theme") private var theme: AppTheme = .standard
    @State private var showOpenPanel = false
    /// One file picker serves both buttons (SwiftUI only honours one
    /// fileImporter per view); this says which one opened it.
    @State private var pickerImports = false
    @State private var confirmDelete: LocalLibrary.File?
    @State private var playing: MediaItem?
    @State private var showLicenses = false
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if recents.items.isEmpty && library.files.isEmpty && library.importing == 0 {
                    ContentUnavailableView {
                        Label("Nothing playing yet", systemImage: "play.rectangle")
                    } description: {
                        Text(Self.emptyHint)
                    } actions: {
                        Button { pick(importing: false) } label: {
                            Text("Open a File").foregroundStyle(theme.background)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Import to This Device") { pick(importing: true) }
                    }
                } else {
                    List {
                        if !library.files.isEmpty || library.importing > 0 {
                            onDeviceSection
                        }
                        if !recents.items.isEmpty {
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
                                        .swipeActions(edge: .leading) {
                                            Button { saveToDevice(item) } label: {
                                                Label("Save to This Device", systemImage: "square.and.arrow.down")
                                            }
                                        }
                                        .contextMenu {
                                            Button("Save to This Device", systemImage: "square.and.arrow.down") { saveToDevice(item) }
                                            Button("Remove from Recents", systemImage: "minus.circle") { recents.forget(item) }
                                        }
                                }
                            } header: {
                                Text("Recent").foregroundStyle(theme.accent.opacity(0.8))
                            }
                        }
                    }
                    // Hide the system's grey list background so ours shows.
                    .scrollContentBackground(.hidden)
                    // On the List. On the Section it never appeared; and with it
                    // beside the file picker (plus a switchable multiple-selection
                    // setting) the picker stopped opening. Tested in the simulator.
                    .confirmationDialog("Delete \u{201C}\(confirmDelete?.title ?? "")\u{201D} from this device?",
                                        isPresented: Binding(get: { confirmDelete != nil },
                                                             set: { if !$0 { confirmDelete = nil } }),
                                        titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            if let file = confirmDelete { library.delete(file) }
                        }
                    } message: {
                        Text("The copy in ReWatch is removed for good. The original, wherever it came from, isn't touched.")
                    }
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
                    // Licences of ReWatch and the libraries inside it
                    // (several of them require the app to show these).
                    Button { showLicenses = true } label: {
                        Label { Text("Licenses") } icon: { tinted("info.circle") }
                    }
                    themeMenu
                    Button { pick(importing: true) } label: {
                        Label { Text("Import") } icon: { tinted("square.and.arrow.down") }
                    }
                    Button { pick(importing: false) } label: {
                        Label { Text("Open") } icon: { tinted("folder") }
                    }
                }
            }
            .sheet(isPresented: $showLicenses) { LicensesView() }
            // Multiple selection for both, kept fixed (see the delete dialog
            // above). Open with several files plays the first and remembers
            // the rest.
            .fileImporter(isPresented: $showOpenPanel,
                          allowedContentTypes: Recents.openTypes,
                          allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                if pickerImports { library.importFiles(urls) } else { recents.open(urls) }
            }
            #if os(iOS)
            .fullScreenCover(item: $playing) { item in
                PlayerView(item: item) { playing = nil }
            }
            #endif
            // One alert for both: two alerts on one view can't both show.
            .alert("Something went wrong", isPresented: Binding(
                get: { recents.lastError != nil || library.lastError != nil },
                set: { if !$0 { recents.lastError = nil; library.lastError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(recents.lastError ?? library.lastError ?? "")
            }
            .onChange(of: recents.openRequested) { _, requested in
                if requested { pick(importing: false); recents.openRequested = false }
            }
            .onChange(of: library.importRequested) { _, requested in
                if requested { pick(importing: true); library.importRequested = false }
            }
            // Files may have been added or deleted in the Files app meanwhile.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { library.reload() }
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

    private var onDeviceSection: some View {
        Section {
            ForEach(library.files) { file in
                Button { if let item = library.item(for: file) { play(item) } } label: {
                    LocalRow(file: file)
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.surface)
                .swipeActions {
                    Button(role: .destructive) { confirmDelete = file } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button("Delete from This Device", systemImage: "trash", role: .destructive) { confirmDelete = file }
                }
            }
            if library.importing > 0 {
                HStack(spacing: 12) {
                    ProgressView().tint(theme.accent).frame(width: 36)
                    Text(library.importing == 1 ? "Importing 1 file\u{2026}" : "Importing \(library.importing) files\u{2026}")
                }
                .padding(.vertical, 4)
                .listRowBackground(theme.surface)
            }
        } header: {
            Text("On This Device").foregroundStyle(theme.accent.opacity(0.8))
        }
    }

    private func pick(importing: Bool) {
        pickerImports = importing
        showOpenPanel = true
    }

    /// Copies a Recents file into the app, e.g. to keep a video from a USB
    /// drive after unplugging it.
    private func saveToDevice(_ item: MediaItem) {
        guard let (url, _) = item.resolve() else {
            recents.lastError = "Couldn't find \u{201C}\(item.title)\u{201D}. If it's on a drive, plug it back in."
            return
        }
        library.importFiles([url])
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
        "Open a video or audio file, or drag one onto this window, to play it from where it is. Or import it to keep a copy in ReWatch."
        #else
        "Open a video or audio file from Files, or share one to ReWatch, to play it from where it is. Or import it to keep a copy on this device."
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
            Image(systemName: item.isPlaylist ? "list.bullet" : item.isAudio ? "music.note" : "film")
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

private struct LocalRow: View {
    let file: LocalLibrary.File

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: Recents.audioExtensions.contains(file.ext) ? "music.note"
                  : Recents.playlistExtensions.contains(file.ext) ? "list.bullet" : "film")
                .font(.title2)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.title).lineLimit(2)
                Text("\(file.ext.uppercased()) · \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                    .font(.caption)
                    .opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
