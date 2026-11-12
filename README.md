# ReWatch

<img src="ReWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="ReWatch icon: a glowing cyan eye with a play symbol in its pupil, inside a replay arrow, under a starry dusty rose sky" width="128" align="right">

A media player for iPhone, iPad and Mac, built on [mpv](https://mpv.io). It plays the files you already have, where they already are, including the formats Apple's own player won't open.

**Video:** `.3g2` `.3gp` `.asf` `.avi` `.divx` `.f4f` `.f4v` `.flv` `.m2p` `.m2ts` `.m4v` `.mkv` `.mov` `.mp4` `.mpeg` `.mpg` `.mxf` `.ogm` `.ogv` `.ps` `.ts` `.vob` `.webm` `.wmv`

**Audio:** `.aac` `.ac3` `.dts` `.eac3` `.flac` `.m4a` `.mka` `.mp3` `.ogg` `.opus` `.thd` (Dolby TrueHD) `.wav` `.wma` `.wv` (WavPack)

**Playlists:** `.m3u` (each entry must be a file ReWatch can read or, on iPhone, a web link)

MKV and other containers can carry several audio and subtitle tracks, including DTS and Dolby TrueHD sound.

No account, no ads, no tracking. ReWatch never uploads your files. It reads them in place, and only keeps a copy of the ones you choose to import.

## Features

- **mpv playback engine.** libmpv, the engine inside the mpv desktop player, decodes everything, with hardware decoding through VideoToolbox.
- **Open and play.** Pick a file, drag one onto the window, or choose **Open in ReWatch** from the share sheet or Finder. It starts playing from wherever it lives: Files, iCloud Drive, a USB drive, Downloads.
- **Recents.** Files you've opened are listed for one-tap replay. They're references, not copies; removing one only forgets it.
- **Import to this device.** **Import** (or File > Import…, ⇧⌘I, on the Mac) copies files into ReWatch, listed under **On This Device**, so they play with the USB drive unplugged or offline. A Recents entry can be copied too: swipe right or long-press, then **Save to This Device**. On iPhone and iPad the copies also show in the Files app under On My iPhone > ReWatch. Deleting one removes only the copy.
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
- [Homebrew](https://brew.sh), for the tools that build FFmpeg (the build script installs them)

## Building

The Xcode project is generated from `project.yml` and isn't checked in.

```bash
git clone https://github.com/BleuBirddy/ReWatch.git
cd ReWatch
Tools/build-ffmpeg.sh
xcodegen generate
open ReWatch.xcodeproj
```

`Tools/build-ffmpeg.sh` builds FFmpeg once, for iPhone/iPad, the Simulator and the Mac (about 10 minutes, plus downloading MPVKit's other libraries). It runs [MPVKit](https://github.com/mpvkit/MPVKit)'s own build scripts at the version ReWatch uses, with `Tools/ffmpeg/mpvkit-extra-formats.patch` applied. The patch only adds the parts MPVKit's prebuilt FFmpeg leaves out: the readers for standalone `.dts`, `.thd`, `.wv` and `.mxf` files, and the WavPack and Theora decoders. All of them are FFmpeg's own LGPL code. The result goes to `Packages/MPVKit/Frameworks/`, which isn't checked in. Run the script again only after changing the patch or the MPVKit version.

Choose your team under **Signing & Capabilities**, pick an iPhone, iPad or **My Mac** as the run destination, then build and run. The first build downloads the rest of MPVKit (libmpv and its other libraries, prebuilt), which takes a few minutes.

Run `xcodegen generate` again after adding, moving or deleting source files.

## Project layout

```
ReWatch/
  App/          App entry point, themes, Licenses screen
  Library/      Recents (bookmarks to files in place) and imported files (LocalLibrary)
  Player/       mpv wrapper (MPVPlayer), video surface, player screen
  Resources/    App icon, accent colour, licence texts shown in the app
  Supporting/   Info.plist (generated from project.yml), Mac sandbox entitlements
Packages/MPVKit/  ReWatch's copy of MPVKit's package, using the FFmpeg built below
Tools/
  build-ffmpeg.sh      Builds FFmpeg with the extra formats into Packages/MPVKit/Frameworks
  ffmpeg/              The patch for MPVKit's build scripts
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

Standalone `.dts`, `.thd`, `.wv` and `.mxf` files and Theora video play on the Mac and the iPhone simulator with ReWatch's own FFmpeg build (see Building).

Not done yet:
- Testing on a real iPhone
- Lock-screen and Control Center playback controls

## Credits

- [mpv](https://mpv.io) and [FFmpeg](https://ffmpeg.org) do the actual playback.
- [MPVKit](https://github.com/mpvkit/MPVKit) packages them for Apple platforms. ReWatch uses its LGPL build, with FFmpeg rebuilt to add a few formats (still LGPL). The GPL build would make the whole app GPL.

## Licence

ReWatch's own code is under the [MIT licence](LICENSE). The libraries inside the app keep their own licences; FFmpeg, mpv and several others are under the GNU LGPL. [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) lists every library with its licence and source code, and explains how to rebuild ReWatch with your own changed version of one. The app shows the same licences under **Licenses** (the ⓘ button).

Keeping it that way: don't switch to MPVKit's GPL build or pass `--enable-gpl` to FFmpeg, and when adding or updating a library, update the list in `ReWatch/App/LicensesView.swift`, `THIRD-PARTY-NOTICES.md` and the texts in `ReWatch/Resources/Licenses`.
