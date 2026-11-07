// Draws the ReWatch app icon: a glowing #ADFFFF eye with ornate, wispy
// clouds on #9B666B. Run from the repo root:
//   swift Tools/make-icon.swift ReWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

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
ctx.setFillColor(rgb(bg)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
let halo = CGGradient(colorsSpace: cs, colors: [rgb(glow, 0.20), rgb(glow, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(halo, startCenter: CGPoint(x: 512, y: 512), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 512), endRadius: 470, options: [])
ctx.setLineJoin(.round); ctx.setLineCap(.round)

func glowing(_ blur: CGFloat, _ alpha: CGFloat = 0.95, _ draw: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: blur, color: rgb(glow, alpha)); draw(); ctx.restoreGState()
}

// ---- Clouds: point lists drawn as tapered strokes ----
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

/// One cloud: a row of scalloped bumps, each holding a curl, with long
/// flowing ribbons. `dir` = 1 trails left, -1 mirrors it to trail right.
func cloud(x: CGFloat, base: CGFloat, scale s: CGFloat, dir: CGFloat) {
    func p(_ dx: CGFloat, _ dy: CGFloat) -> P { P(x: x + dir * dx * s, y: base + dy * s) }
    func ang(_ a: CGFloat) -> CGFloat { dir > 0 ? a : .pi - a }   // mirror an angle
    let bumps: [(CGFloat, CGFloat)] = [(0, 40), (88, 58), (180, 44)] // centre x, radius
    var strokes: [([P], CGFloat, CGFloat)] = []
    for (i, (cx, r)) in bumps.enumerated() {
        // Scallop over the top, stopping short of the baseline so
        // neighbours meet in a point instead of standing on "legs".
        let lo: CGFloat = i == 0 ? .pi : .pi - 0.55
        let hi: CGFloat = i == bumps.count - 1 ? 0 : 0.55
        strokes.append((arc(center: p(cx, 0), radius: r * s, from: ang(lo), to: ang(hi)), 6, 6))
        // A curl hanging from the scallop's crown, unwinding inward.
        strokes.append((spiral(center: p(cx, r * 0.30), radius: r * 0.62 * s,
                               from: ang(.pi / 2), turns: 1.75, cw: dir < 0), 5, 1.2))
    }
    // Ribbon 1: sweeps out from under the cloud, rises, and scrolls up.
    let r1 = quad(p(200, -6), p(40, -40), p(-130, 4)) + quad(p(-130, 4), p(-200, 30), p(-205, 70))
    strokes.append((r1, 5.5, 2.5))
    strokes.append((spiral(center: p(-180, 78), radius: 26 * s, from: ang(.pi), turns: 1.5, cw: dir > 0), 2.5, 1))
    // Ribbon 2: long, hair-thin, running the other way and ending in a hook.
    let r2 = quad(p(-90, -30), p(120, -64), p(330, -26)) + quad(p(330, -26), p(400, -10), p(430, -40))
    strokes.append((r2, 1, 4.5))
    strokes.append((spiral(center: p(412, -50), radius: 18 * s, from: ang(0), turns: 1.3, cw: dir > 0), 4, 1))
    // Ribbon 3: a faint echo beneath, fading at both ends.
    strokes.append((quad(p(-20, -58), p(140, -80), p(290, -60)), 0.8, 2.5))
    strokes.append((quad(p(290, -60), p(330, -55), p(360, -70)), 2.5, 0.6))

    // Soft glow pass, then a crisp pass.
    for (blur, alpha) in [(24.0, 0.9), (7.0, 0.8)] as [(CGFloat, CGFloat)] {
        glowing(blur, alpha) { for (pts, w0, w1) in strokes { taper(pts, w0, w1) } }
    }
}

ctx.setStrokeColor(rgb(glow))
cloud(x: 255, base: 880, scale: 0.85, dir: 1)     // upper left, trailing left
cloud(x: 770, base: 150, scale: 0.85, dir: -1)    // lower right, trailing right

// ---- Eye ----
// Drawn at 80% around the centre, which leaves clear space between the
// eye and the clouds in the corners.
ctx.saveGState()
ctx.translateBy(x: 512, y: 512); ctx.scaleBy(x: 0.8, y: 0.8); ctx.translateBy(x: -512, y: -512)
let eye = CGMutablePath()
eye.move(to: P(x: 170, y: 512))
eye.addQuadCurve(to: P(x: 854, y: 512), control: P(x: 512, y: 860))
eye.addQuadCurve(to: P(x: 170, y: 512), control: P(x: 512, y: 164))
// Fill with the background first, so the clouds pass behind the eye
// rather than showing through it.
ctx.setFillColor(rgb(bg)); ctx.addPath(eye); ctx.fillPath()
ctx.saveGState(); ctx.addPath(eye); ctx.clip()
ctx.drawRadialGradient(halo, startCenter: P(x: 512, y: 512), startRadius: 0,
                       endCenter: P(x: 512, y: 512), endRadius: 470, options: [])
ctx.restoreGState()

ctx.setStrokeColor(rgb(glow)); ctx.setFillColor(rgb(glow))
ctx.setLineWidth(40)
for blur in [90.0, 50.0, 20.0] as [CGFloat] { glowing(blur) { ctx.addPath(eye); ctx.strokePath() } }
let iris = CGRect(x: 512 - 128, y: 512 - 128, width: 256, height: 256)
ctx.setLineWidth(34)
for blur in [70.0, 30.0] as [CGFloat] { glowing(blur) { ctx.strokeEllipse(in: iris) } }
let pupil = CGRect(x: 512 - 64, y: 512 - 64, width: 128, height: 128)
for blur in [60.0, 20.0] as [CGFloat] { glowing(blur) { ctx.fillEllipse(in: pupil) } }

ctx.restoreGState()

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
