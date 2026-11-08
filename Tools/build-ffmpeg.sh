#!/bin/bash
# Builds ReWatch's own copy of FFmpeg, the library that reads and decodes
# media files for mpv.
#
# Why: MPVKit's prebuilt FFmpeg leaves out a few readers ("demuxers") and
# decoders, so standalone .dts, .thd (Dolby TrueHD), .wv (WavPack) and .mxf
# files, and Theora video, don't play. This script runs MPVKit's own build
# scripts at the exact MPVKit version ReWatch uses, with
# Tools/ffmpeg/mpvkit-extra-formats.patch applied, which only adds those
# parts to FFmpeg's configure options.
#
# Licence: everything added is FFmpeg's own LGPL code. The build does not
# pass --enable-gpl, so the app stays LGPL-compatible.
#
# Output: Packages/MPVKit/Frameworks/Lib*.xcframework (iOS device, iOS
# simulator, and macOS arm64 + x86_64). Those are not committed (too big);
# run this once before the first Xcode build. Takes about 10 minutes on an
# M-series Mac, plus downloads.
#
# Usage: Tools/build-ffmpeg.sh
set -euo pipefail

# Must match the MPVKit version in Packages/MPVKit/Package.swift.
MPVKIT_VERSION=1.1.0-n9.0.2

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/ffmpeg"
SRC="$WORK/MPVKit"
OUT="$ROOT/Packages/MPVKit/Frameworks"
PATCH="$ROOT/Tools/ffmpeg/mpvkit-extra-formats.patch"

# Tools FFmpeg's build needs (MPVKit's script would otherwise install them
# itself halfway through).
for tool in nasm pkg-config wget glslc sdl2-config; do
    if ! command -v "$tool" >/dev/null; then
        case "$tool" in
            pkg-config) brew install pkgconf ;;
            glslc) brew install glslang shaderc ;;
            sdl2-config) brew install sdl2 ;;
            *) brew install "$tool" ;;
        esac
    fi
done

# A fresh MPVKit checkout at the pinned version, so a rerun never builds
# with leftover edits.
mkdir -p "$WORK"
if [ -d "$SRC/.git" ]; then
    git -C "$SRC" checkout -q .
    git -C "$SRC" clean -qfdx -e dist
else
    git clone -q --depth 1 --branch "$MPVKIT_VERSION" https://github.com/mpvkit/MPVKit.git "$SRC"
fi
git -C "$SRC" apply "$PATCH"

# ios = iPhone/iPad, isimulator = Simulator (arm64 + x86_64), macos = Mac
# (arm64 + x86_64). Every other library MPVKit needs is downloaded prebuilt;
# only FFmpeg is compiled. The build log is dist/FFmpeg-n9.0.2.log.
(cd "$SRC" && make build platform=ios,isimulator,macos)

mkdir -p "$OUT"
for lib in Libavcodec Libavdevice Libavfilter Libavformat Libavutil Libswresample Libswscale; do
    rm -rf "${OUT:?}/$lib.xcframework"
    cp -R "$SRC/dist/release/xcframework/$lib.xcframework" "$OUT/"
done
echo "FFmpeg xcframeworks are in $OUT"
