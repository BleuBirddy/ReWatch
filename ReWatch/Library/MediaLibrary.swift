import Foundation
import UniformTypeIdentifiers

/// One playable file in the library.
struct MediaItem: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let added: Date

    var id: URL { url }
    var title: String { url.deletingPathExtension().lastPathComponent }
    var ext: String { url.pathExtension.lowercased() }
    var isAudio: Bool { MediaLibrary.audioExtensions.contains(ext) }
}

/// The library is the app's Documents folder, nothing more. No database to
/// get out of sync: whatever files are in the folder (including ones dropped
/// in through the Files app) are the library.
@MainActor
final class MediaLibrary: ObservableObject {
    static let audioExtensions: Set<String> = ["mp3", "flac"]
    static let videoExtensions: Set<String> = ["mp4", "mkv"]
    static var supportedExtensions: Set<String> { audioExtensions.union(videoExtensions) }

    /// Types the file importer lets you pick. mkv comes from the type
    /// declared in project.yml (UTImportedTypeDeclarations).
    static let importTypes: [UTType] = [
        .mp3, .mpeg4Movie,
        UTType("org.xiph.flac") ?? .audio,
        UTType("org.matroska.mkv") ?? .movie,
    ]

    @Published private(set) var items: [MediaItem] = []
    @Published var lastError: String?

    let folder: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    init() {
        importInbox()
        reload()
    }

    func reload() {
        let keys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        items = urls.compactMap { url in
            guard Self.supportedExtensions.contains(url.pathExtension.lowercased()),
                  let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.isRegularFile == true else { return nil }
            return MediaItem(url: url, size: Int64(v.fileSize ?? 0), added: v.creationDate ?? .distantPast)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Copies files chosen in the importer. They live outside the sandbox,
    /// so access has to be opened (and closed) around the copy.
    func importPicked(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            copyIn(url, move: false)
        }
        reload()
    }

    /// A file handed over by "Open in". iOS already put a copy in
    /// Documents/Inbox, so it's moved rather than copied again.
    func importShared(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        copyIn(url, move: url.path.contains("/Inbox/"))
        reload()
    }

    func delete(_ item: MediaItem) {
        do { try FileManager.default.removeItem(at: item.url) }
        catch { lastError = "Couldn't delete \(item.title): \(error.localizedDescription)" }
        reload()
    }

    /// Anything left in Inbox from a share that arrived while the app wasn't
    /// running gets pulled in at launch.
    private func importInbox() {
        let inbox = folder.appendingPathComponent("Inbox")
        let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
        files.forEach { copyIn($0, move: true) }
    }

    private func copyIn(_ source: URL, move: Bool) {
        guard Self.supportedExtensions.contains(source.pathExtension.lowercased()) else {
            lastError = "ReWatch plays mp3, mp4, flac and mkv. \(source.lastPathComponent) isn't one of those."
            if move { try? FileManager.default.removeItem(at: source) }
            return
        }
        let dest = uniqueDestination(for: source.lastPathComponent)
        do {
            if move { try FileManager.default.moveItem(at: source, to: dest) }
            else { try FileManager.default.copyItem(at: source, to: dest) }
        } catch {
            lastError = "Couldn't import \(source.lastPathComponent): \(error.localizedDescription)"
        }
    }

    /// "Movie.mkv" → "Movie 2.mkv" if the name is taken, so an import never
    /// overwrites a file already in the library.
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
