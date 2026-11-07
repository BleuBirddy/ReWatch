# ReWatch

<img src="ReWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="ReWatch icon: a glowing cyan eye with ornate clouds on a dusty rose background" width="128" align="right">

An iOS media player built on [mpv](https://mpv.io). It plays the files you already have, including the formats Apple's own player won't open.

| Format | Type |
|---|---|
| `.mp4` | Video |
| `.mkv` | Video (Matroska, with multiple audio and subtitle tracks) |
| `.mp3` | Audio |
| `.flac` | Audio (lossless) |

No account, no ads, no tracking. Files stay on your device.

## Features

- **mpv playback engine.** libmpv, the engine inside the mpv desktop player, decodes everything, with hardware decoding through VideoToolbox.
- **Your files, your folder.** The library is the app's own folder, which shows up as **ReWatch** in the Files app. Drop videos in from a Mac or another app, use the **+** button to import, or pick **Open in ReWatch** from the share sheet.
- **Resume where you left off.** Closing a file saves your position. Files you finish start from the beginning next time.
- **Audio and subtitle tracks.** Switch to the next track with one tap. mpv shows the track name on screen.
- **Background audio.** Music keeps playing with the screen locked.
- **Simple controls.** Tap to show play/pause, skip 10 seconds either way, and a seek bar. They fade on their own during playback.
- **Themes.**
  - **ReWatch** (default): #ADFFFF on #9B666B
  - **Dark**: near-black, for a dark room
  - **Warm**: amber on brown, with no blue light, for late at night

## Requirements

- iOS 17 or later (iPhone and iPad)
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

The Xcode project is generated from `project.yml` and isn't checked in.

```bash
git clone https://github.com/BleuBirddy/ReWatch.git
cd ReWatch
xcodegen generate
open ReWatch.xcodeproj
```

Choose your team under **Signing & Capabilities**, then build and run. The first build downloads MPVKit (libmpv and FFmpeg as prebuilt binaries), which takes a few minutes.

Run `xcodegen generate` again after adding, moving or deleting source files.

## Project layout

```
ReWatch/
  App/          App entry point, themes
  Library/      The file list, importing, deleting
  Player/       mpv wrapper (MPVPlayer), video surface, player screen
  Resources/    App icon, accent colour
  Supporting/   Info.plist (generated from project.yml)
Tools/
  make-icon.swift   Draws the app icon
project.yml     XcodeGen project definition
```

`Player/MPVPlayer.swift` is the core. It talks to libmpv's C API: it sets options, sends commands like `loadfile` and `seek`, and turns mpv's property events into values the SwiftUI screens can show.

## Regenerating the icon

The icon is drawn in code, so it can be tweaked by editing numbers instead of pixels:

```bash
swift Tools/make-icon.swift ReWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Status

Early, and working in the simulator. All four formats play, and resume, track switching, themes and background audio work there.

Not done yet:
- Testing on a real iPhone
- Lock-screen and Control Center playback controls

## Credits

- [mpv](https://mpv.io) and [FFmpeg](https://ffmpeg.org) do the actual playback.
- [MPVKit](https://github.com/mpvkit/MPVKit) packages them for Apple platforms. ReWatch uses its LGPL build. The GPL build would make the whole app GPL.
