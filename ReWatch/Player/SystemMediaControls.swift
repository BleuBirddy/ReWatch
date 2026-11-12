import Foundation
import MediaPlayer
#if os(iOS)
import AVFoundation
#endif

/// Connects a player to the system:
/// - the lock screen, Control Center and headphone/AirPods buttons
///   (Now Playing info plus remote commands; on the Mac, the media keys);
/// - on iPhone/iPad, the phone's audio rules: pause for a call or Siri,
///   resume after if iOS says to, and pause when headphones are unplugged
///   (so the sound doesn't suddenly come out of the speaker).
///
/// Main thread only. Each player has its own; only the one attached most
/// recently drives the system (on the Mac several windows can be open).
final class SystemMediaControls {
    /// The instance currently shown on the lock screen, so a closing window
    /// doesn't clear what another window is playing.
    private static weak var current: SystemMediaControls?

    private weak var player: MPVPlayer?
    private var title = ""
    /// Remote command registrations, kept so they can be removed again.
    private var targets: [(MPRemoteCommand, Any)] = []
    private var observers: [NSObjectProtocol] = []

    func attach(to player: MPVPlayer, title: String) {
        self.player = player
        self.title = title
        Self.current?.unregister()
        Self.current = self
        register()
        #if os(iOS)
        // The category is set once at launch (ReWatchApp); switching the
        // session on is what tells iOS this app is now the one playing.
        do { try AVAudioSession.sharedInstance().setActive(true) }
        catch { print("Audio session couldn't start: \(error)") }
        #endif
        update(from: player)
    }

    func detach(from player: MPVPlayer) {
        guard self.player === player else { return }
        unregister()
        guard Self.current === self else { return }
        Self.current = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        #else
        // Let music the person paused for this (Spotify, Music) carry on.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    /// Refreshes the lock screen. Called on pause/play, after seeks and when
    /// the duration becomes known; the system advances the time itself in
    /// between, from the elapsed time and the rate given here.
    func update(from player: MPVPlayer) {
        guard Self.current === self, self.player === player else { return }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.position,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPaused ? 0.0 : 1.0,
            MPNowPlayingInfoPropertyMediaType: (player.hasVideo ? MPNowPlayingInfoMediaType.video
                                                               : MPNowPlayingInfoMediaType.audio).rawValue,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #if os(macOS)
        // The Mac reads play/pause from here rather than from the rate.
        MPNowPlayingInfoCenter.default().playbackState = player.isPaused ? .paused : .playing
        #endif
    }

    // MARK: Private

    private func register() {
        let center = MPRemoteCommandCenter.shared()
        on(center.playCommand) { $0.play() }
        on(center.pauseCommand) { $0.pause() }
        on(center.togglePlayPauseCommand) { $0.togglePause() }
        // Same 10 seconds as the on-screen buttons.
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.preferredIntervals = [10]
        on(center.skipForwardCommand) { $0.skip(10) }
        on(center.skipBackwardCommand) { $0.skip(-10) }
        // Dragging the lock-screen progress bar.
        let seek = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let player = self?.player,
                  let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            player.seek(to: event.positionTime)
            return .success
        }
        targets.append((center.changePlaybackPositionCommand, seek))

        #if os(iOS)
        let notifications = NotificationCenter.default
        observers.append(notifications.addObserver(forName: AVAudioSession.interruptionNotification,
                                                   object: nil, queue: .main) { [weak self] note in
            self?.interrupted(note)
        })
        observers.append(notifications.addObserver(forName: AVAudioSession.routeChangeNotification,
                                                   object: nil, queue: .main) { [weak self] note in
            self?.routeChanged(note)
        })
        #endif
    }

    private func on(_ command: MPRemoteCommand, _ action: @escaping (MPVPlayer) -> Void) {
        let target = command.addTarget { [weak self] _ in
            guard let player = self?.player else { return .noActionableNowPlayingItem }
            action(player)
            return .success
        }
        targets.append((command, target))
    }

    private func unregister() {
        targets.forEach { command, target in command.removeTarget(target) }
        targets.removeAll()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    #if os(iOS)
    /// A call, an alarm or Siri took the audio. Pause; when it's over, carry
    /// on only if iOS says to (it doesn't, for example, after a long call).
    private func interrupted(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            player?.pause()
        case .ended:
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init) ?? []
            if options.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true)
                player?.play()
            }
        @unknown default:
            break
        }
    }

    /// Headphones unplugged or Bluetooth disconnected: pause, as Apple's
    /// own apps do, instead of switching to the loudspeaker mid-film.
    private func routeChanged(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        player?.pause()
    }
    #endif
}
