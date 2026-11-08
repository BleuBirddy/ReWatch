# ReWatch

<img src="ReWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="ReWatch icon: a glowing cyan eye with a play symbol in its pupil, inside a replay arrow, under a starry dusty rose sky" width="128" align="right">

A media player for iPhone, iPad and Mac, built on [mpv](https://mpv.io). It plays the files you already have, where they already are, including the formats Apple's own player won't open.

**Video:** `.3g2` `.3gp` `.asf` `.avi` `.divx` `.f4f` `.f4v` `.flv` `.m2p` `.m2ts` `.m4v` `.mkv` `.mov` `.mp4` `.mpeg` `.mpg` `.ogm` `.ps` `.ts` `.vob` `.webm` `.wmv`

**Audio:** `.aac` `.ac3` `.eac3` `.flac` `.m4a` `.mka` `.mp3` `.ogg` `.opus` `.wav` `.wma`

**Playlists:** `.m3u` (each entry must be a file ReWatch can read or, on iPhone, a web link)

MKV and other containers can carry several audio and subtitle tracks, including DTS and Dolby TrueHD sound.

No account, no ads, no tracking. ReWatch never copies, uploads or stores your files: it reads them in place.

## Features

- **mpv playback engine.** libmpv, the engine inside the mpv desktop player, decodes everything, with hardware decoding through VideoToolbox.
- **Open and play.** Pick a file, drag one onto the window, or choose **Open in ReWatch** from the share sheet or Finder. It starts playing from wherever it lives: Files, iCloud Drive, a USB drive, Downloads.
- **Recents.** Files you've opened are listed for one-tap replay. They're references, not copies; removing one only forgets it.
- **Resume where you left off.** Closing a file saves your position. Files you finish start from the beginning next time.
- **Audio and subtitle tracks.** Switch to the next track with one tap. mpv shows the track name on screen.
- **Background audio.** Music keeps playing with the screen locked.
- **Simple controls.** Tap to show play/pause, skip 10 seconds either way, and a seek bar. They fade on their own during playback.
- **On the Mac.** Each video gets its own window (full screen with the green button). File > Open… (⌘O), space to play or pause, arrow keys to skip 10 seconds, Esc to close, and controls that appear when you move the mouse. The Mac app is sandboxed: it can only read files you open.
- **Themes.**
  - **ReWatch** (default): #ADFFFF on #9B666B
  - **Dark**: near-black, for a dark room
  - **Warm**: amber on brown, with no blue light, for late at night

## Requirements

- iOS 17 or later (iPhone and iPad), or macOS 14 or later
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

Choose your team under **Signing & Capabilities**, pick an iPhone, iPad or **My Mac** as the run destination, then build and run. The first build downloads MPVKit (libmpv and FFmpeg as prebuilt binaries), which takes a few minutes.

Run `xcodegen generate` again after adding, moving or deleting source files.

## Project layout

```
ReWatch/
  App/          App entry point, themes
  Library/      Recents list, opening files (bookmarks, never copies)
  Player/       mpv wrapper (MPVPlayer), video surface, player screen
  Resources/    App icon, accent colour
  Supporting/   Info.plist (generated from project.yml), Mac sandbox entitlements
Tools/
  make-icon.swift      Draws the app icon (iOS and Mac versions)
  make-mac-icons.sh    Cuts the Mac icon sizes
project.yml     XcodeGen project definition
```

`Player/MPVPlayer.swift` is the core. It talks to libmpv's C API: it sets options, sends commands like `loadfile` and `seek`, and turns mpv's property events into values the SwiftUI screens can show.

## Regenerating the icon

The icon is drawn in code, so it can be tweaked by editing numbers instead of pixels:

```bash
swift Tools/make-icon.swift ReWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png Tools/AppIcon-mac.png
Tools/make-mac-icons.sh
```

## Status

Early. On the iPhone simulator, all four formats play, and resume, track switching, themes, background audio and Recents work. On a Mac, a 1080p video plays and resumes after quitting, and a sample of every listed format except `.f4f` plays.

Not supported yet: standalone `.dts`, `.thd` (TrueHD), `.wv` (WavPack) and `.mxf` files, and Theora video. The FFmpeg build that MPVKit ships leaves out those readers and decoders; supporting them means building FFmpeg with them included.

Not done yet:
- Testing on a real iPhone
- Lock-screen and Control Center playback controls

## Credits

- [mpv](https://mpv.io) and [FFmpeg](https://ffmpeg.org) do the actual playback.
- [MPVKit](https://github.com/mpvkit/MPVKit) packages them for Apple platforms. ReWatch uses its LGPL build. The GPL build would make the whole app GPL.
