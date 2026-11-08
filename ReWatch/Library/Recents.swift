import Foundation
import UniformTypeIdentifiers

/// A file you've opened. ReWatch never copies files: this holds a bookmark,
/// a reference the system can turn back into the file's location (and
/// permission to read it) later, even if the file was renamed or moved.
/// Codable so Recents can be saved and the Mac can hand one to a new window.
struct MediaItem: Identifiable, Hashable, Codable {
    var id = UUID()
    let title: String
    let ext: String
    /// Where the file was when opened. Only used to spot the same file
    /// being opened twice; the bookmark is what finds it.
    let path: String
    var bookmark: Data
    var lastOpened: Date
    /// A copy iOS made in the app's Inbox folder ("Open in" from some apps
    /// sends a copy, not the original). Played once and deleted, and never
    /// kept in Recents, so nothing stays saved in the app.
    var isTemporaryCopy = false

    var isAudio: Bool { Recents.audioExtensions.contains(ext) }
    var isPlaylist: Bool { Recents.playlistExtensions.contains(ext) }

    /// The file's current location, or nil if it's gone.
    func resolve() -> (url: URL, isStale: Bool)? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: Recents.resolveOptions,
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        return (url, stale)
    }
}

/// The files you've opened recently, newest first, kept in UserDefaults as
/// bookmarks. Removing one only forgets it; the file itself is never touched.
@MainActor
final class Recents: ObservableObject {
    // Everything mpv (through MPVKit's FFmpeg) can play that ReWatch offers
    // to open. Left out on purpose:
    // - .sh (a shell script, not media), .ytb and .twi (not media formats).
    // .dts, .thd (Dolby TrueHD), .wv (WavPack), .mxf and Theora video
    // (.ogm/.ogv/.ogg) need ReWatch's own FFmpeg build, which adds the parts
    // MPVKit's prebuilt one leaves out (Tools/build-ffmpeg.sh).
    nonisolated static let audioExtensions: Set<String> = [
        "aac", "ac3", "dts", "eac3", "flac", "m4a", "mka", "mp3", "ogg", "opus",
        "thd", "wav", "wma", "wv",
    ]
    nonisolated static let videoExtensions: Set<String> = [
        "3g2", "3gp", "asf", "avi", "divx", "f4f", "f4v", "flv", "m2p", "m2ts",
        "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "mxf", "ogm", "ogv", "ps",
        "ts", "vob", "webm", "wmv",
    ]
    /// Playlists: mpv plays each entry in turn. Entries must be web links
    /// or files ReWatch is allowed to read (see README).
    nonisolated static let playlistExtensions: Set<String> = ["m3u"]
    nonisolated static var supportedExtensions: Set<String> {
        audioExtensions.union(videoExtensions).union(playlistExtensions)
    }

    /// Types the Open panel lets you pick, one per extension. Types the
    /// system doesn't know come from UTImportedTypeDeclarations in
    /// project.yml; anything still unknown gets a type made up from the
    /// extension, which matches files with that extension all the same.
    static let openTypes: [UTType] = supportedExtensions.sorted().compactMap { UTType(filenameExtension: $0) }

    // The sandboxed Mac app needs "security-scoped" bookmarks to read a
    // file again after relaunch (entitlement files.bookmarks.app-scope).
    // iOS bookmarks to picked files carry that permission already.
    #if os(macOS)
    nonisolated static let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
    nonisolated static let resolveOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
    #else
    nonisolated static let bookmarkOptions: URL.BookmarkCreationOptions = []
    nonisolated static let resolveOptions: URL.BookmarkResolutionOptions = []
    #endif

    @Published private(set) var items: [MediaItem] = []
    @Published var lastError: String?
    /// Set by File > Open… (⌘O); LibraryView shows the Open panel.
    @Published var openRequested = false
    /// A file waiting to be played (from Open in, Finder, a drop...).
    /// LibraryView plays it and sets this back to nil.
    @Published var playRequest: MediaItem?

    private let storageKey = "recents"
    private let limit = 50

    init() {
        load()
        removeLeftoverInboxCopies()
    }

    /// Opens a file picked, dropped or handed over by another app: plays it
    /// where it is and remembers it in Recents.
    func open(_ url: URL) {
        guard let item = makeItem(for: url) else { return }
        remember(item)
        playRequest = item
    }

    /// Several files dropped at once: plays the first, remembers them all.
    func open(_ urls: [URL]) {
        let opened = urls.compactMap(makeItem(for:))
        opened.reversed().forEach(remember)
        playRequest = opened.first
    }

    /// Gets a Recents entry ready to play again: checks the file still
    /// exists, refreshes its bookmark if the file moved, and moves it to
    /// the top. Nil (with an error to show) if the file is gone.
    func prepare(_ item: MediaItem) -> MediaItem? {
        guard let (url, isStale) = item.resolve() else {
            lastError = "Couldn't find \u{201C}\(item.title)\u{201D}. It may have been moved to another device, renamed or deleted."
            return nil
        }
        var updated = item
        updated.lastOpened = .now
        if isStale, let fresh = makeItem(for: url) {
            updated.bookmark = fresh.bookmark
        }
        remember(updated)
        return updated
    }

    func forget(_ item: MediaItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: Private

    private func makeItem(for url: URL) -> MediaItem? {
        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            lastError = "ReWatch doesn't play .\(ext) files, so it can't open \(url.lastPathComponent)."
            return nil
        }
        // Files from the Open panel, a drop or another app come with
        // permission to read them that has to be switched on while used.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: Self.bookmarkOptions,
                                                includingResourceValuesForKeys: nil, relativeTo: nil)
            return MediaItem(title: url.deletingPathExtension().lastPathComponent, ext: ext, path: url.path,
                             bookmark: bookmark, lastOpened: .now,
                             isTemporaryCopy: url.path.contains("/Documents/Inbox/"))
        } catch {
            lastError = "Couldn't open \(url.lastPathComponent): \(error.localizedDescription)"
            return nil
        }
    }

    private func remember(_ item: MediaItem) {
        guard !item.isTemporaryCopy else { return }
        items.removeAll { $0.id == item.id || $0.path == item.path }
        items.insert(item, at: 0)
        if items.count > limit { items.removeLast(items.count - limit) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([MediaItem].self, from: data) else { return }
        items = saved
    }

    /// Temporary Inbox copies are deleted when their player closes; this
    /// catches any left behind if the app was killed mid-playback. Only
    /// copies over an hour old: when iOS launches ReWatch to open a file,
    /// this runs before the file is handed over, and must not delete it.
    private func removeLeftoverInboxCopies() {
        let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Inbox")
        let files = (try? FileManager.default.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let cutoff = Date.now.addingTimeInterval(-3600)
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? FileManager.default.removeItem(at: file) }
        }
    }
}
