import SwiftUI

/// One library built into ReWatch, and the licence it comes under.
///
/// Why this screen exists: most of these licences require that anyone who
/// gets the app can see the licence texts and the copyright notices, and the
/// LGPL ones (FFmpeg, mpv...) also require telling people where to get the
/// source code. Keep this list in step with THIRD-PARTY-NOTICES.md and with
/// the libraries in Packages/MPVKit/Package.swift.
struct ThirdPartyLibrary: Identifiable {
    let name: String
    let version: String
    let licence: String
    let source: String
    /// Licence texts in Resources/Licenses (without ".txt"), shown in order.
    let texts: [String]
    var id: String { name }
}

enum Licenses {
    static let noticesURL = URL(string: "https://github.com/BleuBirddy/ReWatch/blob/main/THIRD-PARTY-NOTICES.md")!
    static let sourceURL = URL(string: "https://github.com/BleuBirddy/ReWatch")!

    // FreeType's licence asks for exactly this credit in the documentation.
    static let freeTypeCredit = "Portions of this software are copyright © 2026 The FreeType Project (www.freetype.org). All rights reserved."

    static let libraries: [ThirdPartyLibrary] = [
        .init(name: "FFmpeg", version: "n9.0.2 (with ReWatch's added formats)", licence: "LGPL 3.0 or later",
              source: "https://github.com/FFmpeg/FFmpeg/tree/n9.0.2", texts: ["FFmpeg", "LGPL-3.0", "GPL-3.0"]),
        .init(name: "mpv (libmpv)", version: "0.41.0", licence: "LGPL 2.1 or later",
              source: "https://github.com/mpv-player/mpv/tree/v0.41.0", texts: ["mpv", "LGPL-2.1"]),
        .init(name: "MPVKit", version: "1.1.0-n9.0.2", licence: "LGPL 3.0",
              source: "https://github.com/mpvkit/MPVKit/tree/1.1.0-n9.0.2", texts: ["LGPL-3.0", "GPL-3.0"]),
        .init(name: "libplacebo", version: "7.360.1", licence: "LGPL 2.1 or later",
              source: "https://code.videolan.org/videolan/libplacebo", texts: ["LGPL-2.1"]),
        .init(name: "libbluray", version: "1.4.0", licence: "LGPL 2.1 or later",
              source: "https://code.videolan.org/videolan/libbluray", texts: ["LGPL-2.1"]),
        .init(name: "FriBidi", version: "1.0.16", licence: "LGPL 2.1 or later",
              source: "https://github.com/fribidi/fribidi", texts: ["LGPL-2.1"]),
        .init(name: "GnuTLS", version: "3.8.11", licence: "LGPL 2.1 or later",
              source: "https://gitlab.com/gnutls/gnutls", texts: ["LGPL-2.1"]),
        .init(name: "Nettle", version: "3.10", licence: "LGPL 3.0 (chosen from LGPL 3.0 or GPL 2.0)",
              source: "https://git.lysator.liu.se/nettle/nettle", texts: ["LGPL-3.0", "GPL-3.0"]),
        .init(name: "GMP", version: "6.2.1", licence: "LGPL 3.0 (chosen from LGPL 3.0 or GPL 2.0)",
              source: "https://gmplib.org", texts: ["LGPL-3.0", "GPL-3.0"]),
        .init(name: "uchardet", version: "0.0.8", licence: "MPL 1.1",
              source: "https://gitlab.freedesktop.org/uchardet/uchardet", texts: ["uchardet"]),
        .init(name: "libass", version: "0.17.5", licence: "ISC",
              source: "https://github.com/libass/libass", texts: ["libass"]),
        .init(name: "FreeType", version: "2.14.3", licence: "FreeType License (FTL)",
              source: "https://freetype.org", texts: ["FreeType"]),
        .init(name: "HarfBuzz", version: "14.2.0", licence: "Old MIT",
              source: "https://github.com/harfbuzz/harfbuzz", texts: ["HarfBuzz"]),
        .init(name: "libunibreak", version: "6.1", licence: "zlib",
              source: "https://github.com/adah1972/libunibreak", texts: ["libunibreak"]),
        .init(name: "Little CMS", version: "2.17", licence: "MIT",
              source: "https://github.com/mm2/Little-CMS", texts: ["lcms2"]),
        .init(name: "dav1d", version: "1.5.3", licence: "BSD 2-Clause",
              source: "https://code.videolan.org/videolan/dav1d", texts: ["dav1d"]),
        .init(name: "libdovi", version: "3.3.2", licence: "MIT",
              source: "https://github.com/quietvoid/dovi_tool", texts: ["libdovi"]),
        .init(name: "uavs3d", version: "1.2.1", licence: "BSD 3-Clause",
              source: "https://github.com/uavs3/uavs3d", texts: ["uavs3d"]),
        .init(name: "MoltenVK", version: "Vulkan 1.4", licence: "Apache 2.0",
              source: "https://github.com/KhronosGroup/MoltenVK", texts: ["Apache-2.0"]),
        .init(name: "shaderc, glslang and SPIRV-Tools", version: "2023.8.1", licence: "Apache 2.0, and BSD/MIT for parts of glslang",
              source: "https://github.com/google/shaderc", texts: ["Apache-2.0", "glslang"]),
        .init(name: "OpenSSL", version: "3.3.5", licence: "Apache 2.0",
              source: "https://github.com/openssl/openssl", texts: ["Apache-2.0"]),
        .init(name: "LuaJIT (Mac only)", version: "2.1", licence: "MIT",
              source: "https://luajit.org", texts: ["LuaJIT"]),
    ]

    /// A licence text from the app bundle. (xcodegen copies everything in
    /// Resources/Licenses into the app, without the folder.)
    static func text(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "(\(name).txt is missing from the app)" }
        return text
    }
}

/// Settings-style list: ReWatch's own licence, then every library.
struct LicensesView: View {
    @AppStorage("theme") private var theme: AppTheme = .standard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("ReWatch is free software under the MIT licence. It is built on the libraries below, which keep their own licences. For the LGPL ones you can get their source code, and rebuild ReWatch with your own changed version of them.")
                    Link("How to get the source and rebuild", destination: Licenses.noticesURL)
                    Link("ReWatch's source code", destination: Licenses.sourceURL)
                }
                .listRowBackground(theme.surface)

                Section {
                    NavigationLink("ReWatch · MIT") {
                        LicenceTextView(title: "ReWatch", source: Licenses.sourceURL.absoluteString, texts: ["ReWatch"])
                    }
                }
                .listRowBackground(theme.surface)

                Section {
                    ForEach(Licenses.libraries) { library in
                        NavigationLink {
                            LicenceTextView(title: library.name, source: library.source, texts: library.texts)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(library.name) \(library.version)")
                                Text(library.licence).font(.caption).opacity(0.8)
                            }
                        }
                    }
                } header: {
                    Text("Libraries").foregroundStyle(theme.accent.opacity(0.8))
                } footer: {
                    Text(Licenses.freeTypeCredit).foregroundStyle(theme.accent.opacity(0.8))
                }
                .listRowBackground(theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Licenses")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .foregroundStyle(theme.accent)
        .tint(theme.accent)
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 520)
        #endif
    }
}

/// The full licence text(s) for one library.
private struct LicenceTextView: View {
    @AppStorage("theme") private var theme: AppTheme = .standard
    let title: String
    let source: String
    let texts: [String]

    // Shown paragraph by paragraph in a lazy stack: some licences are tens
    // of kilobytes, and one giant Text view scrolls slowly.
    private var paragraphs: [String] {
        texts.flatMap { Licenses.text($0).components(separatedBy: "\n\n") + ["———"] }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let url = URL(string: source) {
                    Link("Source code: \(source)", destination: url)
                }
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}
