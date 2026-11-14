import XCTest
@testable import ReWatch
#if os(iOS)
import UIKit
#endif

/// Real mpv, no screen or sound (headless), each test with its own resume
/// folder so the app's saved positions are never touched.
@MainActor
final class MPVPlayerTests: XCTestCase {
    private var folder: URL!
    private var player: MPVPlayer!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("rewatch-tests-\(UUID().uuidString)", isDirectory: true)
        player = MPVPlayer(headless: true, watchLaterFolder: folder)
    }

    override func tearDown() async throws {
        player.shutdown()
        try? FileManager.default.removeItem(at: folder)
    }

    private var tinyVideo: URL {
        Bundle(for: Self.self).url(forResource: "tiny", withExtension: "mp4")!
    }

    #if os(iOS)
    /// The USB bug from 2026-11-12: going to the background switches video
    /// off and saves the resume file at the same moment, so the file said
    /// "vid=no" and the next play was sound only. The saved file must keep
    /// the position but never the video track.
    func testBackgroundSaveDoesNotSwitchVideoOffNextTime() async throws {
        player.load(tinyVideo, title: "tiny")
        try await waitUntil("the file loads") { self.player.duration > 0 }

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        let saved = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        XCTAssertEqual(saved.count, 1, "one resume file")
        let contents = try String(contentsOf: saved[0], encoding: .utf8)
        XCTAssertTrue(contents.contains("start="), "position saved:\n\(contents)")
        XCTAssertFalse(contents.contains("vid="), "video track saved:\n\(contents)")
    }
    #endif

    func testMissingFileReportsAReason() async throws {
        player.load(folder.appendingPathComponent("not-there.mp4"), title: "gone")
        try await waitUntil("mpv reports the failure") { self.player.failure != nil }
    }

    func testNonMediaFileReportsAReason() async throws {
        let junk = folder.appendingPathComponent("junk.mp4")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(repeating: 0x5A, count: 4096).write(to: junk)
        player.load(junk, title: "junk")
        try await waitUntil("mpv reports the failure") { self.player.failure != nil }
    }

    /// The screen dimmed and locked in the middle of a film, because
    /// nothing told the system a video was on. It must be kept awake
    /// while the picture moves, and released again when paused.
    func testScreenStaysAwakeOnlyWhilePlaying() async throws {
        player.load(tinyVideo, title: "tiny")
        try await waitUntil("the picture starts") { self.player.hasVideo }
        player.seek(to: 0)
        XCTAssertTrue(player.keepsScreenAwake, "playing video")

        player.pause()
        try await waitUntil("it pauses") { self.player.isPaused }
        XCTAssertFalse(player.keepsScreenAwake, "paused video")
    }

    func testAGoodFileReportsNoFailure() async throws {
        player.load(tinyVideo, title: "tiny")
        try await waitUntil("the file loads") { self.player.duration > 0 }
        XCTAssertNil(player.failure)
    }
}

/// Polls until `condition` is true. mpv reports back asynchronously, through
/// the main queue, so tests wait instead of checking straight away. Fails
/// after `timeout` rather than hanging.
@MainActor
func waitUntil(_ what: String, timeout: Double = 10, _ condition: @escaping () -> Bool) async throws {
    let deadline = Date.now.addingTimeInterval(timeout)
    while !condition() {
        if Date.now > deadline { XCTFail("Timed out waiting for \(what)"); return }
        try await Task.sleep(for: .milliseconds(50))
    }
}
