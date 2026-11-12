import XCTest
@testable import ReWatch

/// Imports into a throwaway folder, never the app's real Documents.
@MainActor
final class LocalLibraryTests: XCTestCase {
    private var root: URL!
    private var libraryFolder: URL { root.appendingPathComponent("library", isDirectory: true) }

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rewatch-library-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// A fake "video" with the given name and contents, in its own folder so
    /// two of them can share a name.
    private func source(_ name: String, _ contents: String) throws -> URL {
        let dir = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func importAndWait(_ library: LocalLibrary, _ urls: [URL]) async throws {
        library.importFiles(urls)
        try await waitUntil("imports finish") { library.importing == 0 }
    }

    func testImportCopiesAndKeepsTheCopyOutOfBackup() async throws {
        let library = LocalLibrary(folder: libraryFolder)
        let original = try source("clip.mp4", "frames")
        try await importAndWait(library, [original])

        XCTAssertEqual(library.files.map(\.title), ["clip"])
        let copy = try XCTUnwrap(library.files.first).url
        XCTAssertEqual(try Data(contentsOf: copy), Data("frames".utf8))
        XCTAssertEqual(try copy.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path), "original untouched")
    }

    func testImportingTheSameFileTwiceKeepsOneCopy() async throws {
        let library = LocalLibrary(folder: libraryFolder)
        let original = try source("clip.mp4", "frames")
        try await importAndWait(library, [original])
        try await importAndWait(library, [original])
        XCTAssertEqual(library.files.count, 1)
    }

    /// Both start copying before either finishes: names are picked at the
    /// end, so neither overwrites nor fails on the other.
    func testTwoDifferentFilesWithOneNameBothArrive() async throws {
        let library = LocalLibrary(folder: libraryFolder)
        let first = try source("clip.mp4", "first")
        let second = try source("clip.mp4", "second, longer")
        try await importAndWait(library, [first, second])

        XCTAssertEqual(Set(library.files.map(\.url.lastPathComponent)), ["clip.mp4", "clip 2.mp4"])
        XCTAssertNil(library.lastError)
    }

    func testUnsupportedFilesAreRefused() async throws {
        let library = LocalLibrary(folder: libraryFolder)
        try await importAndWait(library, [try source("notes.txt", "hi")])
        XCTAssertTrue(library.files.isEmpty)
        XCTAssertNotNil(library.lastError)
    }

    /// A copy cut off by the app being killed is hidden and cleaned up.
    func testLeftoverPartialCopiesAreHiddenAndRemoved() throws {
        try FileManager.default.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
        let partial = libraryFolder.appendingPathComponent(LocalLibrary.partialPrefix + "abc-clip.mp4")
        try Data("half".utf8).write(to: partial)

        let library = LocalLibrary(folder: libraryFolder)
        XCTAssertTrue(library.files.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
    }
}
