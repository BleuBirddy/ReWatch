# Third-party notices

ReWatch's own code is under the [MIT licence](LICENSE). The app also contains the libraries below, which keep their own licences. The full licence texts are in [`ReWatch/Resources/Licenses`](ReWatch/Resources/Licenses) and are shown in the app under **Licenses** (the ⓘ button on the main screen).

Two files in this repository come from MPVKit and stay under its licence, the GNU LGPL version 3 ([`Packages/MPVKit/LICENSE`](Packages/MPVKit/LICENSE)), not MIT: [`Packages/MPVKit/Package.swift`](Packages/MPVKit/Package.swift) (modified) and [`Tools/ffmpeg/mpvkit-extra-formats.patch`](Tools/ffmpeg/mpvkit-extra-formats.patch) (a change to MPVKit's build script).

## Libraries in the app

All of them are built into the app as static libraries. Except for FFmpeg, ReWatch uses the unmodified prebuilt copies that [MPVKit](https://github.com/mpvkit/MPVKit) publishes (its LGPL build; no GPL parts).

| Library | Version | Licence | Source |
|---|---|---|---|
| FFmpeg | n9.0.2, with the extra formats below | LGPL 3.0 or later | https://github.com/FFmpeg/FFmpeg/tree/n9.0.2 |
| mpv (libmpv, built with `-Dgpl=false`) | 0.41.0 | LGPL 2.1 or later | https://github.com/mpv-player/mpv/tree/v0.41.0 |
| MPVKit | 1.1.0-n9.0.2 | LGPL 3.0 | https://github.com/mpvkit/MPVKit/tree/1.1.0-n9.0.2 |
| libplacebo | 7.360.1 | LGPL 2.1 or later | https://code.videolan.org/videolan/libplacebo |
| libbluray | 1.4.0 | LGPL 2.1 or later | https://code.videolan.org/videolan/libbluray |
| FriBidi | 1.0.16 | LGPL 2.1 or later | https://github.com/fribidi/fribidi |
| GnuTLS | 3.8.11 | LGPL 2.1 or later | https://gitlab.com/gnutls/gnutls |
| Nettle | 3.10 | LGPL 3.0 (chosen from LGPL 3.0 or GPL 2.0) | https://git.lysator.liu.se/nettle/nettle |
| GMP | 6.2.1 | LGPL 3.0 (chosen from LGPL 3.0 or GPL 2.0) | https://gmplib.org |
| uchardet | 0.0.8 | MPL 1.1 | https://gitlab.freedesktop.org/uchardet/uchardet |
| libass | 0.17.5 | ISC | https://github.com/libass/libass |
| FreeType | 2.14.3 | FreeType License (FTL) | https://freetype.org |
| HarfBuzz | 14.2.0 | Old MIT | https://github.com/harfbuzz/harfbuzz |
| libunibreak | 6.1 | zlib | https://github.com/adah1972/libunibreak |
| Little CMS | 2.17 | MIT | https://github.com/mm2/Little-CMS |
| dav1d | 1.5.3 | BSD 2-Clause | https://code.videolan.org/videolan/dav1d |
| libdovi | 3.3.2 | MIT | https://github.com/quietvoid/dovi_tool |
| uavs3d | 1.2.1 | BSD 3-Clause | https://github.com/uavs3/uavs3d |
| MoltenVK | Vulkan 1.4 | Apache 2.0 | https://github.com/KhronosGroup/MoltenVK |
| shaderc, glslang, SPIRV-Tools | 2023.8.1 | Apache 2.0; parts of glslang BSD/MIT | https://github.com/google/shaderc |
| OpenSSL | 3.3.5 | Apache 2.0 | https://github.com/openssl/openssl |
| LuaJIT (Mac app only) | 2.1 | MIT | https://luajit.org |

MPVKit's build scripts for the prebuilt libraries are at https://github.com/mpvkit.

Portions of this software are copyright © 2026 The FreeType Project (www.freetype.org). All rights reserved.

## Your rights under the LGPL

FFmpeg, mpv and the other LGPL libraries come with these rights, whichever way you got ReWatch (App Store, a build from this repository, or anywhere else):

- **Source code.** The source of each LGPL library is at the link in the table above, at the version listed. ReWatch's only change to any of them is to FFmpeg's build options: [`Tools/ffmpeg/mpvkit-extra-formats.patch`](Tools/ffmpeg/mpvkit-extra-formats.patch) turns on FFmpeg's own `dts`, `truehd`, `wv` and `mxf` demuxers and `wavpack` and `theora` decoders. No FFmpeg source file is changed.
- **Changing a library and using it in ReWatch.** Because the libraries are built into the app, you change one by rebuilding ReWatch, and all of ReWatch's source is here under the MIT licence:
  1. Run `Tools/build-ffmpeg.sh` once. It downloads FFmpeg's source to `build/ffmpeg/MPVKit/dist/FFmpeg-n9.0.2`.
  2. Change FFmpeg there (or change its build options in the patch), then run `Tools/build-ffmpeg.sh` again. It keeps your changes to that source and puts the rebuilt libraries in `Packages/MPVKit/Frameworks`. To replace one of the other libraries, put your own build of it in `Packages/MPVKit/Frameworks` and point its `binaryTarget` in `Packages/MPVKit/Package.swift` at it, the same way the FFmpeg ones are.
  3. Build ReWatch as described in the [README](README.md#building), and install it on your own iPhone, iPad or Mac from Xcode. A free Apple Account is enough to install on your own devices.

If a link above stops working, open an issue on this repository and you'll be sent the source of that library at the version ReWatch uses.
