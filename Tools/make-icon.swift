// Draws the ReWatch app icon: a glowing #ADFFFF eye inside a "replay"
// ring, under a starry sky, on #9B666B. Run from the repo root:
//   swift Tools/make-icon.swift ReWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png Tools/AppIcon-mac.png
// then Tools/make-mac-icons.sh to cut the Mac sizes from the second file.
//
// Layers, back to front: sky gradient, ripples, stars, halo, replay
// ring, eye. Coordinates are CoreGraphics: origin bottom-left.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ hex: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}
let glow = 0xADFFFF, bg = 0x9B666B
let centre = CGPoint(x: 512, y: 512)
ctx.setLineJoin(.round); ctx.setLineCap(.round)

func glowing(_ blur: CGFloat, _ alpha: CGFloat = 0.95, _ draw: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: blur, color: rgb(glow, alpha)); draw(); ctx.restoreGState()
}

/// Same picture every run: a tiny fixed-seed generator for the stars.
var seed: UInt64 = 0x5EED_2026
func random() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(seed >> 33) / CGFloat(1 << 31)
}

// ---- Sky: #9B666B, lit from the middle and deepening to the edges ----
let sky = CGGradient(colorsSpace: cs, colors: [rgb(0xB5868A), rgb(bg), rgb(0x6A3F44)] as CFArray,
                     locations: [0, 0.55, 1])!
ctx.drawRadialGradient(sky, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 760, options: [.drawsAfterEndLocation])

// Faint ripples spreading from the eye, like rings on water.
for (i, r) in [395.0, 430.0, 468.0, 510.0].enumerated() {
    ctx.setStrokeColor(rgb(glow, 0.10 - CGFloat(i) * 0.02)); ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: 512 - r, y: 512 - r, width: 2 * r, height: 2 * r))
}

// ---- Drawing helpers: point lists drawn as tapered strokes ----
typealias P = CGPoint
func quad(_ a: P, _ c: P, _ b: P, n: Int = 60) -> [P] {
    (0...n).map { i in let t = CGFloat(i) / CGFloat(n), u = 1 - t
        return P(x: u*u*a.x + 2*u*t*c.x + t*t*b.x, y: u*u*a.y + 2*u*t*c.y + t*t*b.y) }
}
/// Spiral curling inward: the ornate scroll at the end of each wisp.
func spiral(center c: P, radius r: CGFloat, from a0: CGFloat, turns: CGFloat, cw: Bool, n: Int = 120) -> [P] {
    (0...n).map { i in let t = CGFloat(i) / CGFloat(n)
        let a = a0 + (cw ? -1 : 1) * t * turns * 2 * .pi, rr = r * (1 - 0.82 * t)
        return P(x: c.x + rr * cos(a), y: c.y + rr * sin(a)) }
}
func arc(center c: P, radius r: CGFloat, from a0: CGFloat, to a1: CGFloat, n: Int = 60) -> [P] {
    (0...n).map { i in let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)
        return P(x: c.x + r * cos(a), y: c.y + r * sin(a)) }
}
/// Draws a polyline whose width eases from w0 to w1: thin, wispy ends.
func taper(_ pts: [P], _ w0: CGFloat, _ w1: CGFloat) {
    for i in 1..<pts.count {
        let t = CGFloat(i) / CGFloat(pts.count - 1)
        ctx.setLineWidth(w0 + (w1 - w0) * t)
        ctx.move(to: pts[i - 1]); ctx.addLine(to: pts[i]); ctx.strokePath()
    }
}


// ---- Stars ----
/// A four-pointed sparkle with a soft glow.
func sparkle(_ c: P, _ r: CGFloat) {
    let star = CGMutablePath()
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4 + .pi / 2
        let rr = i % 2 == 0 ? r : r * 0.16
        let pt = P(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
        i == 0 ? star.move(to: pt) : star.addLine(to: pt)
    }
    star.closeSubpath()
    ctx.setFillColor(rgb(glow))
    glowing(r * 0.9) { ctx.addPath(star); ctx.fillPath() }
}

// Scattered pinpricks, kept out of the middle so the eye stays clear.
for _ in 0..<90 {
    let pt = P(x: 40 + random() * 944, y: 40 + random() * 944)
    let d = hypot(pt.x - 512, pt.y - 512)
    guard d > 390 else { continue }
    let r = 1.2 + random() * 2.4, a = 0.35 + random() * 0.55
    ctx.setFillColor(rgb(glow, a))
    glowing(6, a) { ctx.fillEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)) }
}
// Sparkles, grouped in the corners.
for (pt, r) in [(P(x: 805, y: 905), 30.0), (P(x: 905, y: 780), 16.0), (P(x: 690, y: 960), 11.0),
                (P(x: 215, y: 120), 30.0), (P(x: 115, y: 250), 16.0), (P(x: 340, y: 70), 11.0)] as [(P, CGFloat)] {
    sparkle(pt, r)
}

// ---- Halo behind the eye ----
let halo = CGGradient(colorsSpace: cs, colors: [rgb(glow, 0.30), rgb(glow, 0.08), rgb(glow, 0)] as CFArray,
                      locations: [0, 0.5, 1])!
ctx.drawRadialGradient(halo, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 360, options: [])

// ---- Replay ring: the "Re" in ReWatch ----
// An arc running anticlockwise almost all the way round, ending in an
// arrowhead at the top, like a rewind symbol, with sprocket dots outside
// it like the edge of film.
let ringR: CGFloat = 340
let a0: CGFloat = 130 * .pi / 180, sweep: CGFloat = 300 * .pi / 180
ctx.setStrokeColor(rgb(glow))
let ringPts = arc(center: centre, radius: ringR, from: a0, to: a0 + sweep, n: 240)
for (blur, a) in [(30.0, 0.9), (10.0, 0.9)] as [(CGFloat, CGFloat)] {
    glowing(blur, a) { taper(ringPts, 3, 11) }
}
do {
    // Arrowhead at the end of the arc, pointing along it (anticlockwise).
    let end = a0 + sweep
    let tip = P(x: 512 + ringR * cos(end + 0.12), y: 512 + ringR * sin(end + 0.12))
    let back = P(x: 512 + ringR * cos(end - 0.04), y: 512 + ringR * sin(end - 0.04))
    let out = P(x: back.x + 30 * cos(end), y: back.y + 30 * sin(end))
    let inn = P(x: back.x - 30 * cos(end), y: back.y - 30 * sin(end))
    let head = CGMutablePath(); head.addLines(between: [tip, out, inn]); head.closeSubpath()
    ctx.setFillColor(rgb(glow))
    glowing(18) { ctx.addPath(head); ctx.fillPath() }
}
for i in 0..<36 {
    let a = CGFloat(i) * 10 * .pi / 180
    // Leave the gap by the arrowhead empty.
    let rel = (a - a0).truncatingRemainder(dividingBy: 2 * .pi)
    let wrapped = rel < 0 ? rel + 2 * .pi : rel
    guard wrapped < sweep - 0.05 else { continue }
    let pt = P(x: 512 + (ringR + 22) * cos(a), y: 512 + (ringR + 22) * sin(a))
    ctx.setFillColor(rgb(glow, 0.75))
    glowing(8, 0.8) { ctx.fillEllipse(in: CGRect(x: pt.x - 3.5, y: pt.y - 3.5, width: 7, height: 7)) }
}

// ---- Eye ----
// Drawn in its original coordinates and scaled to 62% around the centre,
// leaving room for the ring.
ctx.saveGState()
ctx.translateBy(x: 512, y: 512); ctx.scaleBy(x: 0.62, y: 0.62); ctx.translateBy(x: -512, y: -512)
let left = P(x: 170, y: 512), right = P(x: 854, y: 512)
let upperCtl = P(x: 512, y: 860), lowerCtl = P(x: 512, y: 164)
let eye = CGMutablePath()
eye.move(to: left)
eye.addQuadCurve(to: right, control: upperCtl)
eye.addQuadCurve(to: left, control: lowerCtl)

// Inside of the eye: dark, so the iris glows against it.
ctx.saveGState(); ctx.addPath(eye); ctx.clip()
let inside = CGGradient(colorsSpace: cs, colors: [rgb(0x5E363B), rgb(0x7E4E53)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(inside, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 340, options: [.drawsAfterEndLocation])
ctx.restoreGState()

ctx.setStrokeColor(rgb(glow)); ctx.setFillColor(rgb(glow))

// Lids.
ctx.setLineWidth(36)
for blur in [60.0, 30.0, 12.0] as [CGFloat] { glowing(blur) { ctx.addPath(eye); ctx.strokePath() } }

// Iris: outer ring, then fine fibres running in toward the pupil.
let iris = CGRect(x: 512 - 128, y: 512 - 128, width: 256, height: 256)
ctx.setLineWidth(30)
for blur in [44.0, 18.0] as [CGFloat] { glowing(blur) { ctx.strokeEllipse(in: iris) } }
for i in 0..<48 {
    let a = CGFloat(i) * 2 * .pi / 48
    let r0: CGFloat = 76, r1: CGFloat = i % 2 == 0 ? 112 : 100
    ctx.setStrokeColor(rgb(glow, i % 2 == 0 ? 0.85 : 0.5)); ctx.setLineWidth(i % 2 == 0 ? 4 : 2.5)
    glowing(6, 0.6) {
        ctx.move(to: P(x: 512 + r0 * cos(a), y: 512 + r0 * sin(a)))
        ctx.addLine(to: P(x: 512 + r1 * cos(a), y: 512 + r1 * sin(a))); ctx.strokePath()
    }
}

// Pupil, with a play triangle cut through it: it's a player, after all.
let pupil = CGRect(x: 512 - 64, y: 512 - 64, width: 128, height: 128)
ctx.setFillColor(rgb(glow))
for blur in [40.0, 14.0] as [CGFloat] { glowing(blur) { ctx.fillEllipse(in: pupil) } }
let play = CGMutablePath()
play.addLines(between: [P(x: 494, y: 540), P(x: 494, y: 484), P(x: 543, y: 512)])
play.closeSubpath()
ctx.setFillColor(rgb(0x5E363B)); ctx.addPath(play); ctx.fillPath()

ctx.restoreGState()

func write(_ image: CGImage, to path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
}
let square = ctx.makeImage()!
write(square, to: CommandLine.arguments[1])

// Optional second path: the Mac version. iOS rounds icon corners itself;
// the Mac doesn't, so the art goes inside Apple's Mac icon grid: an
// 824-point rounded square centred on a 1024 transparent canvas, with a
// soft drop shadow.
if CommandLine.arguments.count > 2 {
    let mac = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    mac.saveGState()
    mac.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
    mac.addPath(shape); mac.setFillColor(rgb(bg)); mac.fillPath()
    mac.restoreGState()
    mac.addPath(shape); mac.clip()
    mac.draw(square, in: body)
    write(mac.makeImage()!, to: CommandLine.arguments[2])
}
