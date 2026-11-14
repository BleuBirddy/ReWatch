import SwiftUI

/// Full-screen player in the spirit of mpv's on-screen controller: the
/// picture fills the screen, a tap shows a thin set of controls, and they
/// fade away again on their own.
struct PlayerView: View {
    let item: MediaItem
    /// Closes the player, given by whoever opened it. `dismiss` alone
    /// proved unreliable on a real iPhone (the X did nothing), so the
    /// owner also takes the player down itself.
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("theme") private var theme: AppTheme = .standard
    @StateObject private var player = MPVPlayer()
    @State private var showControls = true
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0
    @State private var hideTask: Task<Void, Never>?
    /// Set when the file can't even be found (before mpv sees it).
    @State private var openError: String?

    var body: some View {
        ZStack {
            // Black behind video (anything else frames the picture);
            // the theme colour when there is only sound to show.
            (player.hasVideo ? Color.black : theme.background).ignoresSafeArea()

            VideoSurface(layer: player.layer)
                .ignoresSafeArea()
                // Its black backing would cover the theme colour for audio.
                // Hidden, not removed, so mpv keeps its drawing surface.
                .opacity(player.hasVideo ? 1 : 0)

            if !player.hasVideo {
                audioArtwork
            }

            if player.isBuffering {
                ProgressView().tint(theme.accent).controlSize(.large)
            }

            if showControls {
                controls.transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { setControls(visible: !showControls) }
        // Mac: moving the mouse brings the controls back, as in most players.
        .onContinuousHover { phase in
            if case .active = phase { setControls(visible: true) }
        }
        .background { keyboardShortcuts }
        #if os(iOS)
        .statusBarHidden(!showControls)
        .persistentSystemOverlays(.hidden)
        #else
        .navigationTitle(item.title)
        #endif
        .preferredColorScheme(.dark)
        .onAppear {
            guard let (url, _) = item.resolve() else {
                // Say why, rather than closing as if nothing happened.
                openError = "ReWatch can't find \u{201C}\(item.title)\u{201D}. If it's on a USB drive, plug it back in and try again."
                return
            }
            if item.isTemporaryCopy {
                // An Inbox copy iOS made for this one viewing: delete it
                // once mpv has let go of it, so nothing stays in the app.
                player.onClosed = { try? FileManager.default.removeItem(at: url) }
            }
            player.load(url, title: item.title)
            scheduleHide()
        }
        .onDisappear {
            hideTask?.cancel()
            player.shutdown()
        }
        // Missing file, unreadable drive, not a media file: tell the person
        // and close, instead of leaving a black screen.
        .alert("Can't play \u{201C}\(item.title)\u{201D}", isPresented: Binding(
            get: { openError != nil || player.failure != nil },
            set: { _ in })) {
            Button("OK") { close() }
        } message: {
            Text(openError ?? player.failure ?? "")
        }
        .onChange(of: player.isPaused) { _, paused in
            // Keep the controls up while paused; start the fade on resume.
            if paused { setControls(visible: true) } else { scheduleHide() }
        }
    }

    /// mpv-style keys: space plays/pauses, arrows skip 10 s, Esc closes.
    /// Invisible buttons, because SwiftUI hangs keyboard shortcuts on
    /// buttons. Works on the Mac and on an iPad with a keyboard.
    private var keyboardShortcuts: some View {
        Group {
            Button("Play/Pause") { player.togglePause() }
                .keyboardShortcut(.space, modifiers: [])
            Button("Back 10 seconds") { player.skip(-10); setControls(visible: true) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("Forward 10 seconds") { player.skip(10); setControls(visible: true) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("Close") { close() }
                .keyboardShortcut(.cancelAction)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var audioArtwork: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundStyle(theme.accent.opacity(0.7))
            Text(item.title)
                .font(.title3)
                .foregroundStyle(theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        // Sits above the play button instead of behind it.
        .padding(.bottom, 340)
    }

    private var controls: some View {
        VStack {
            HStack {
                Button { close() } label: {
                    Image(systemName: "xmark").font(.title3.weight(.semibold))
                        // A finger-sized target (44 pt); the bare glyph
                        // was about 20 pt and easy to miss.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
                Text(item.title).font(.headline).lineLimit(1)
                Spacer()
                if player.hasVideo {
                    Button { player.cycleAudio() } label: { Image(systemName: "speaker.wave.2") }
                        .accessibilityLabel("Next audio track")
                    Button { player.cycleSubtitles() } label: { Image(systemName: "captions.bubble") }
                        .accessibilityLabel("Next subtitle track")
                }
            }
            .padding()

            Spacer()

            HStack(spacing: 48) {
                Button { player.skip(-10); scheduleHide() } label: {
                    Image(systemName: "gobackward.10").font(.system(size: 32))
                }
                Button { player.togglePause() } label: {
                    Image(systemName: player.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 48))
                        .frame(width: 60)
                }
                .accessibilityLabel(player.isPaused ? "Play" : "Pause")
                Button { player.skip(10); scheduleHide() } label: {
                    Image(systemName: "goforward.10").font(.system(size: 32))
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Slider(value: Binding(
                    get: { scrubbing ? scrubValue : player.position },
                    set: { scrubValue = $0 }),
                       in: 0...max(player.duration, 1)) { editing in
                    // Seek once, on release. Seeking on every drag step
                    // makes mpv decode frames nobody will see.
                    if editing {
                        scrubValue = player.position
                        hideTask?.cancel()
                    } else {
                        player.seek(to: scrubValue)
                        scheduleHide()
                    }
                    scrubbing = editing
                }
                HStack {
                    Text(timeString(scrubbing ? scrubValue : player.position))
                    Spacer()
                    Text(timeString(player.duration))
                }
                .font(.caption.monospacedDigit())
            }
            .padding()
        }
        .foregroundStyle(theme.accent)
        .tint(theme.accent)
        .background(
            LinearGradient(colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }

    private func close() {
        onClose?()
        dismiss()
    }

    private func setControls(visible: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) { showControls = visible }
        if visible { scheduleHide() }
    }

    /// Fades the controls after 3 s of playback. Paused or scrubbing keeps
    /// them up.
    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !player.isPaused, !scrubbing, player.hasVideo else { return }
            withAnimation(.easeInOut(duration: 0.3)) { showControls = false }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Hosts mpv's Metal layer inside SwiftUI and keeps it sized to the view
/// (rotation, split screen, window resizing).
#if os(iOS)
private struct VideoSurface: UIViewRepresentable {
    let layer: CALayer

    func makeUIView(context: Context) -> LayerHostView { LayerHostView(hosted: layer) }
    func updateUIView(_ view: LayerHostView, context: Context) {}

    final class LayerHostView: UIView {
        private let hosted: CALayer

        init(hosted: CALayer) {
            self.hosted = hosted
            super.init(frame: .zero)
            backgroundColor = .black
            layer.addSublayer(hosted)
        }
        required init?(coder: NSCoder) { fatalError("not used") }

        override func layoutSubviews() {
            super.layoutSubviews()
            // No implicit animation, or the video slides around on rotation.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            hosted.contentsScale = window?.screen.nativeScale ?? traitCollection.displayScale
            CATransaction.commit()
        }
    }
}
#else
private struct VideoSurface: NSViewRepresentable {
    let layer: CALayer

    func makeNSView(context: Context) -> LayerHostView { LayerHostView(hosted: layer) }
    func updateNSView(_ view: LayerHostView, context: Context) {}

    final class LayerHostView: NSView {
        private let hosted: CALayer

        init(hosted: CALayer) {
            self.hosted = hosted
            super.init(frame: .zero)
            // AppKit views have no layer until asked for one.
            wantsLayer = true
            layer?.backgroundColor = CGColor(gray: 0, alpha: 1)
            layer?.addSublayer(hosted)
        }
        required init?(coder: NSCoder) { fatalError("not used") }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            // Retina vs. non-Retina, and it changes if the window moves screens.
            hosted.contentsScale = window?.backingScaleFactor ?? 2
            CATransaction.commit()
        }

        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            needsLayout = true
        }
    }
}
#endif
