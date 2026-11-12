import Foundation

/// Files imported into ReWatch: real copies kept in the app's Documents
/// folder, so they play with the USB drive unplugged, offline, or after
/// the original is gone. On iPhone/iPad the folder also shows in the Files
/// app (On My iPhone > ReWatch), so files can be added or removed there too.
///
/// The folder is the library, nothing more: no database to get out of step
/// with what's actually on disk.
@MainActor
final class LocalLibrary: ObservableObject {
    struct File: Identifiable, Hashable {
        let url: URL
        let size: Int64
        var id: URL { url }
        var title: String { url.deletingPathExtension().lastPathComponent }
        var ext: String { url.pathExtension.lowercased() }
    }

    @Published private(set) var files: [File] = []
    /// How many copies are still running. Big videos from a USB drive take
    /// a while, so the list shows that something is happening.
    @Published private(set) var importing = 0
    @Published var lastError: String?
    /// Set by File > Import… (⇧⌘I); LibraryView shows the picker.
    @Published var importRequested = false

    let folder: URL

    /// Copies in progress are written under this prefix. The leading dot
    /// hides them from the list (and from the Files app) until complete.
    nonisolated static let partialPrefix = ".partial-"

    /// `folder` is the app's Documents folder; tests pass their own.
    init(folder: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        removeLeftoverPartials()
        reload()
    }

    /// Re-reads the folder. Called on launch, after imports and deletes, and
    /// when the app comes back (files may have been changed in Files).
    func reload() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
        files = urls.compactMap { url in
            guard Recents.supportedExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { return nil }
            return File(url: url, size: Int64(values.fileSize ?? 0))
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Copies files into the library. The copying runs off the main thread
    /// so the app doesn't freeze on a multi-gigabyte video.
    func importFiles(_ urls: [URL]) {
        for source in urls {
            let ext = source.pathExtension.lowercased()
            guard Recents.supportedExtensions.contains(ext) else {
                lastError = "ReWatch doesn't play .\(ext) files, so it didn't import \(source.lastPathComponent)."
                continue
            }
            // Read permission for a file outside the app has to stay on
            // until the copy has finished.
            let scoped = source.startAccessingSecurityScopedResource()
            if isAlreadyImported(source) {
                if scoped { source.stopAccessingSecurityScopedResource() }
                continue
            }
            // Copy under a hidden name first; it gets its real name only once
            // complete, so a half-copied video never shows up in the list.
            let name = source.lastPathComponent
            let partial = folder.appendingPathComponent(Self.partialPrefix + UUID().uuidString + "-" + name)
            importing += 1
            Task.detached(priority: .userInitiated) {
                var failure: String?
                do { try FileManager.default.copyItem(at: source, to: partial) }
                catch {
                    // Don't leave half a video behind (drive pulled mid-copy).
                    try? FileManager.default.removeItem(at: partial)
                    failure = "Couldn't import \(name): \(error.localizedDescription)"
                }
                if scoped { source.stopAccessingSecurityScopedResource() }
                await MainActor.run { [weak self, failure] in
                    self?.finishImport(partial: failure == nil ? partial : nil, name: name, failure: failure)
                }
            }
        }
    }

    /// Deletes the copy for good. The original (if it still exists) is
    /// untouched.
    func delete(_ file: File) {
        do { try FileManager.default.removeItem(at: file.url) }
        catch { lastError = "Couldn't delete \(file.title): \(error.localizedDescription)" }
        reload()
    }

    /// A player-ready item for an imported file. Made fresh each time and
    /// never added to Recents: the file already has its place in the list.
    func item(for file: File) -> MediaItem? {
        guard let bookmark = try? file.url.bookmarkData(options: Recents.bookmarkOptions,
                                                        includingResourceValuesForKeys: nil, relativeTo: nil)
        else {
            lastError = "Couldn't open \(file.title)."
            return nil
        }
        return MediaItem(title: file.title, ext: file.ext, path: file.url.path,
                         bookmark: bookmark, lastOpened: .now)
    }

    // MARK: Private

    /// Back on the main thread: give the finished copy its real name. The
    /// name is chosen here, not when the copy started, so two files called
    /// "Movie.mkv" imported at once become "Movie.mkv" and "Movie 2.mkv"
    /// instead of the second one failing.
    private func finishImport(partial: URL?, name: String, failure: String?) {
        importing -= 1
        if let failure { lastError = failure }
        if let partial {
            var destination = uniqueDestination(for: name)
            do {
                // Same folder, so this is a rename: instant and all-or-nothing.
                try FileManager.default.moveItem(at: partial, to: destination)
                // Imports are copies of files that exist elsewhere, and videos
                // are big: backing them up would quietly fill people's iCloud.
                // Excluded, so they stay on this device only.
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? destination.setResourceValues(values)
            } catch {
                try? FileManager.default.removeItem(at: partial)
                lastError = "Couldn't import \(name): \(error.localizedDescription)"
            }
        }
        reload()
    }

    /// Copies interrupted by the app being closed or killed.
    private func removeLeftoverPartials() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix(Self.partialPrefix) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    /// Same name and same size as a file already here: importing it again
    /// would only use up space, so it's skipped.
    private func isAlreadyImported(_ source: URL) -> Bool {
        let existing = folder.appendingPathComponent(source.lastPathComponent)
        guard let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              let existingSize = try? existing.resourceValues(forKeys: [.fileSizeKey]).fileSize
        else { return false }
        return size == existingSize
    }

    /// "Movie.mkv" → "Movie 2.mkv" if the name is taken, so an import never
    /// overwrites a different file.
    private func uniqueDestination(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }
}
