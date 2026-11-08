import Foundation
import QuartzCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Libmpv

/// Swift wrapper around one libmpv instance: the same engine as the mpv
/// desktop player, driven through its C API (mpv_command, properties,
/// events). One instance per file played; call `shutdown()` when done.
///
/// Threading: commands are sent from the main thread (libmpv is thread
/// safe). mpv reports back through events, which are read on `queue` and
/// then published on the main thread for SwiftUI.
final class MPVPlayer: ObservableObject {
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isPaused = false
    @Published private(set) var isBuffering = false
    /// False for plain audio. True for video, and for audio files with
    /// embedded cover art (mpv shows the art as a one-frame video).
    @Published private(set) var hasVideo = false
    @Published private(set) var reachedEnd = false

    let layer = MetalLayer()

    private let mpv: OpaquePointer
    private let queue = DispatchQueue(label: "dev.jey.rewatch.mpv", qos: .userInitiated)
    private var isShutDown = false
    /// The file being played and whether its read permission was switched
    /// on, so it can be switched off once mpv is done with it.
    private var openFile: (url: URL, scoped: Bool)?
    /// Runs on the main thread after mpv has been destroyed.
    var onClosed: (() -> Void)?
    /// Only touched on `queue`. Stops the event loop once mpv is destroyed.
    private var destroyed = false

    // Ids passed to mpv_observe_property, so events can be matched without
    // string compares.
    private enum Observed: UInt64, CaseIterable {
        case position = 1, duration, pause, buffering, video, end

        var name: String {
            switch self {
            case .position: "time-pos"
            case .duration: "duration"
            case .pause: "pause"
            case .buffering: "paused-for-cache"
            case .video: "vo-configured"
            case .end: "eof-reached"
            }
        }
        var format: mpv_format {
            switch self {
            case .position, .duration: MPV_FORMAT_DOUBLE
            default: MPV_FORMAT_FLAG
            }
        }
    }

    init() {
        guard let handle = mpv_create() else { fatalError("libmpv failed to start") }
        mpv = handle

        layer.framebufferOnly = true
        layer.backgroundColor = CGColor(gray: 0, alpha: 1)

        // Options must be set before mpv_initialize. Reference:
        // https://mpv.io/manual/stable/#options
        var layerPointer = layer
        mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &layerPointer)
        setOption("vo", "gpu-next")
        setOption("gpu-api", "vulkan")
        setOption("gpu-context", "moltenvk")
        // Hardware decoding: far less battery than decoding on the CPU.
        setOption("hwdec", "videotoolbox")
        // At the end of a file, stay paused on the last frame instead of
        // unloading it, so the controls still have something to show.
        setOption("keep-open", "yes")
        // Subtitles: pick the track in the phone's language, else a default.
        setOption("subs-match-os-language", "yes")
        setOption("subs-fallback", "yes")
        // Resume where you left off ("watch later"), mpv's own feature.
        // Keyed on the file name only: the app's folder path changes when
        // iOS updates or restores the app, which would lose every position.
        setOption("watch-later-dir", Self.watchLaterFolder.path)
        setOption("ignore-path-in-watch-later-config", "yes")
        #if DEBUG
        mpv_request_log_messages(mpv, "warn")
        #endif

        check(mpv_initialize(mpv))

        for property in Observed.allCases {
            mpv_observe_property(mpv, property.rawValue, property.name, property.format)
        }

        // mpv calls this from its own thread whenever events are waiting.
        // passUnretained: no retain cycle, which is why shutdown() must
        // clear the callback before this object can go away.
        mpv_set_wakeup_callback(mpv, { context in
            guard let context else { return }
            Unmanaged<MPVPlayer>.fromOpaque(context).takeUnretainedValue().drainEvents()
        }, Unmanaged.passUnretained(self).toOpaque())

        #if os(iOS)
        // Mac apps keep drawing when they're not in front, so this is iOS only.
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        #else
        // Quitting the Mac app doesn't close its windows one by one first,
        // so the player would never get to save its place. Save on quit.
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate),
                                               name: NSApplication.willTerminateNotification, object: nil)
        #endif
    }

    deinit { shutdown() }

    static var watchLaterFolder: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("watch_later", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // MARK: Controls

    func load(_ url: URL) {
        // A file outside the app (opened, dropped, shared) can only be read
        // while its security scope is switched on: for the whole playback.
        openFile = (url, url.startAccessingSecurityScopedResource())
        command("loadfile", url.path, "replace")
    }

    func togglePause() { setFlag("pause", !isPaused) }

    func seek(to seconds: Double) {
        command("seek", String(seconds), "absolute")
    }

    func skip(_ seconds: Double) {
        command("seek", String(seconds), "relative")
    }

    /// Next subtitle / audio track, the same as pressing j / # in mpv.
    /// The "osd-msg" prefix makes mpv print the new track's name on the
    /// video, so there's no track menu to build.
    func cycleSubtitles() { commandString("osd-msg cycle sub") }
    func cycleAudio() { commandString("osd-msg cycle audio") }

    /// Saves the resume position (or forgets it if the file was finished,
    /// so a rewatch starts from the top) and destroys mpv. Safe to call
    /// more than once.
    func shutdown() {
        guard !isShutDown else { return }
        isShutDown = true
        NotificationCenter.default.removeObserver(self)

        saveResumePosition()

        mpv_set_wakeup_callback(mpv, nil, nil)
        // On `queue`, after any event loop already queued, so the loop never
        // touches a destroyed handle.
        let handle = mpv
        let file = openFile, closed = onClosed
        queue.async { [weak self] in
            self?.destroyed = true
            mpv_terminate_destroy(handle)
            // mpv has closed the file; now it's safe to give up access.
            if let file, file.scoped { file.url.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async { closed?() }
        }
    }

    /// Remembers where playback is, or forgets it once the file has been
    /// watched to the end, so a rewatch starts from the top.
    private func saveResumePosition() {
        if reachedEnd { command("delete-watch-later-config") }
        else { command("write-watch-later-config") }
    }

    // MARK: Background

    // Video can't be drawn in the background (and trying leaves a black
    // screen on return), so the video track is switched off while away.
    // Audio keeps playing: that's what lets music run with the screen locked.
    @objc private func didEnterBackground() {
        setString("vid", "no")
        // iOS can end a background app without warning (memory, or a swipe
        // in the app switcher), so save the resume position now.
        saveResumePosition()
    }
    @objc private func willEnterForeground() { setString("vid", "auto") }
    @objc private func appWillTerminate() { shutdown() }

    // MARK: Events

    private func drainEvents() {
        queue.async { [weak self] in
            guard let self else { return }
            while !self.destroyed {
                guard let event = mpv_wait_event(self.mpv, 0)?.pointee,
                      event.event_id != MPV_EVENT_NONE else { break }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: mpv_event) {
        switch event.event_id {
        case MPV_EVENT_PROPERTY_CHANGE:
            guard let observed = Observed(rawValue: event.reply_userdata),
                  let property = event.data?.assumingMemoryBound(to: mpv_event_property.self).pointee
            else { return }
            // format is NONE when the value doesn't exist yet (no file
            // loaded, unknown duration...). Treat that as zero / false.
            let hasValue = property.format != MPV_FORMAT_NONE && property.data != nil
            let double = hasValue && observed.format == MPV_FORMAT_DOUBLE
                ? property.data.assumingMemoryBound(to: Double.self).pointee : 0
            // mpv flags are C ints, not Swift Bools.
            let flag = hasValue && observed.format == MPV_FORMAT_FLAG
                ? property.data.assumingMemoryBound(to: Int32.self).pointee != 0 : false

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch observed {
                case .position: self.position = double
                case .duration: self.duration = double
                case .pause: self.isPaused = flag
                case .buffering: self.isBuffering = flag
                case .video: self.hasVideo = flag
                case .end: self.reachedEnd = flag
                }
            }

        case MPV_EVENT_LOG_MESSAGE:
            if let message = event.data?.assumingMemoryBound(to: mpv_event_log_message.self).pointee {
                print("[mpv \(String(cString: message.prefix))] \(String(cString: message.text))", terminator: "")
            }

        default:
            break
        }
    }

    // MARK: C API helpers

    private func command(_ args: String...) {
        guard !isShutDown || args.first?.hasSuffix("watch-later-config") == true else { return }
        // mpv wants a NULL-terminated array of C strings.
        var cArgs: [UnsafePointer<CChar>?] = args.map { UnsafePointer(strdup($0)) } + [nil]
        defer { cArgs.forEach { free(UnsafeMutablePointer(mutating: $0)) } }
        check(mpv_command(mpv, &cArgs))
    }

    private func commandString(_ command: String) {
        guard !isShutDown else { return }
        check(mpv_command_string(mpv, command))
    }

    private func setOption(_ name: String, _ value: String) {
        check(mpv_set_option_string(mpv, name, value))
    }

    private func setString(_ name: String, _ value: String) {
        guard !isShutDown else { return }
        check(mpv_set_property_string(mpv, name, value))
    }

    private func setFlag(_ name: String, _ value: Bool) {
        guard !isShutDown else { return }
        var flag: Int32 = value ? 1 : 0
        check(mpv_set_property(mpv, name, MPV_FORMAT_FLAG, &flag))
    }

    private func check(_ status: Int32) {
        if status < 0 { print("mpv error: \(String(cString: mpv_error_string(status)))") }
    }
}
