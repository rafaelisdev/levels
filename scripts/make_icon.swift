// Draws the app icon in the iOS 26 / macOS 26 "Liquid Glass" look and writes an .icns:
// dark glass squircle with a lit rim, three glowing faders, glass knobs.
// Usage: swift scripts/make_icon.swift Resources/AppIcon.icns [preview.png]
import AppKit

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "AppIcon.icns"
let previewPath = args.count > 2 ? args[2] : nil

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func white(_ a: CGFloat) -> CGColor { CGColor(gray: 1, alpha: a) }

/// Apple's icon shape is a continuous-curvature squircle; a superellipse with n≈5 matches it.
func squircle(_ r: CGRect, n: Double = 5) -> CGPath {
    let p = CGMutablePath()
    let steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = r.midX + r.width / 2 * CGFloat(copysign(pow(abs(c), 2 / n), c))
        let y = r.midY + r.height / 2 * CGFloat(copysign(pow(abs(s), 2 / n), s))
        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
    }
    p.closeSubpath()
    return p
}

func linear(_ ctx: CGContext, _ colors: [CGColor], _ locs: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locs)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radial(_ ctx: CGContext, _ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

func capsule(_ r: CGRect) -> CGPath {
    let rad = min(r.width, r.height) / 2
    return CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}

func draw(size px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ns = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ns
    let ctx = ns.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)          // draw in a 1024 grid
    ctx.interpolationQuality = .high

    // macOS icon grid: 824 pt body centered on the 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(body)

    // Drop shadow under the whole tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: CGColor(gray: 0, alpha: 0.38))
    ctx.addPath(shape); ctx.setFillColor(rgb(0x17181E)); ctx.fillPath()
    ctx.restoreGState()

    // Glass body: deep graphite, a touch lighter at the top.
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    linear(ctx, [rgb(0x3B3E4B), rgb(0x22242D), rgb(0x121318)], [0, 0.45, 1],
           from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    // Colored light leaking through the glass behind the faders.
    radial(ctx, [rgb(0x6B5BFF, 0.42), rgb(0x6B5BFF, 0)], center: CGPoint(x: 470, y: 400), radius: 420)
    radial(ctx, [rgb(0xFF5FA8, 0.22), rgb(0xFF5FA8, 0)], center: CGPoint(x: 720, y: 330), radius: 300)
    radial(ctx, [rgb(0x34D6FF, 0.20), rgb(0x34D6FF, 0)], center: CGPoint(x: 300, y: 560), radius: 300)
    // Specular sheen across the top.
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 860); ctx.scaleBy(x: 1.6, y: 0.55)
    radial(ctx, [white(0.16), white(0)], center: .zero, radius: 330)
    ctx.restoreGState()
    ctx.restoreGState()

    // Lit rim: bright along the top, fading at the sides, a softer bounce at the bottom.
    ctx.saveGState()
    ctx.addPath(shape); ctx.setLineWidth(9); ctx.replacePathWithStrokedPath(); ctx.clip()
    linear(ctx, [white(0.62), white(0.10), white(0.04), white(0.24)], [0, 0.35, 0.7, 1],
           from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(squircle(body.insetBy(dx: 5, dy: 5))); ctx.setLineWidth(2); ctx.replacePathWithStrokedPath(); ctx.clip()
    linear(ctx, [white(0.22), white(0)], [0, 1], from: CGPoint(x: 512, y: 920), to: CGPoint(x: 512, y: 640))
    ctx.restoreGState()

    // Faders.
    struct Fader { let x: CGFloat; let level: CGFloat; let top: UInt32; let bottom: UInt32 }
    let faders = [
        Fader(x: 352, level: 0.70, top: 0x3FD8FF, bottom: 0x3A6BFF),
        Fader(x: 512, level: 0.36, top: 0x8A6BFF, bottom: 0x5B4BFF),
        Fader(x: 672, level: 0.56, top: 0xFF6FB5, bottom: 0xB45BFF),
    ]
    let trackW: CGFloat = 44, bottomY: CGFloat = 262, trackH: CGFloat = 500

    for f in faders {
        let track = CGRect(x: f.x - trackW / 2, y: bottomY, width: trackW, height: trackH)
        // Groove cut into the glass.
        ctx.saveGState()
        ctx.addPath(capsule(track)); ctx.setFillColor(CGColor(gray: 0, alpha: 0.42)); ctx.fillPath()
        ctx.addPath(capsule(track)); ctx.clip()
        linear(ctx, [CGColor(gray: 0, alpha: 0.35), CGColor(gray: 0, alpha: 0)], [0, 1],
               from: CGPoint(x: track.minX, y: 0), to: CGPoint(x: track.minX + 14, y: 0))
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(capsule(track)); ctx.setLineWidth(2); ctx.replacePathWithStrokedPath(); ctx.clip()
        linear(ctx, [white(0.02), white(0.16)], [0, 1], from: CGPoint(x: 0, y: track.maxY), to: CGPoint(x: 0, y: track.minY))
        ctx.restoreGState()

        // Glowing fill up to the knob.
        let fill = CGRect(x: track.minX, y: bottomY, width: trackW, height: trackH * f.level)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 46, color: rgb(f.top, 0.75))
        ctx.addPath(capsule(fill)); ctx.setFillColor(rgb(f.bottom)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(capsule(fill)); ctx.clip()
        linear(ctx, [rgb(f.top), rgb(f.bottom)], [0, 1], from: CGPoint(x: 0, y: fill.maxY), to: CGPoint(x: 0, y: fill.minY))
        linear(ctx, [white(0.35), white(0)], [0, 1], from: CGPoint(x: fill.minX + 6, y: 0), to: CGPoint(x: fill.midX, y: 0))
        ctx.restoreGState()

        // Glass knob (fader cap).
        let kw: CGFloat = 138, kh: CGFloat = 78
        let ky = bottomY + trackH * f.level
        let knob = CGRect(x: f.x - kw / 2, y: ky - kh / 2, width: kw, height: kh)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: CGColor(gray: 0, alpha: 0.55))
        ctx.addPath(capsule(knob)); ctx.setFillColor(white(0.95)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(capsule(knob)); ctx.clip()
        linear(ctx, [white(1), CGColor(gray: 0.86, alpha: 1), CGColor(gray: 0.78, alpha: 1)], [0, 0.55, 1],
               from: CGPoint(x: 0, y: knob.maxY), to: CGPoint(x: 0, y: knob.minY))
        // A little of the fader color refracted through the cap.
        radial(ctx, [rgb(f.top, 0.30), rgb(f.top, 0)], center: CGPoint(x: knob.midX, y: knob.minY + 8), radius: 70)
        // Top specular highlight.
        let hi = CGRect(x: knob.minX + 14, y: knob.midY + 4, width: kw - 28, height: kh / 2 - 10)
        ctx.addPath(capsule(hi)); ctx.clip()
        linear(ctx, [white(0.95), white(0.0)], [0, 1], from: CGPoint(x: 0, y: hi.maxY), to: CGPoint(x: 0, y: hi.minY))
        ctx.restoreGState()
        // Cap groove line and rim.
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.16))
        ctx.addPath(capsule(CGRect(x: knob.midX - 34, y: knob.midY - 3, width: 68, height: 6))); ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(capsule(knob.insetBy(dx: 1, dy: 1))); ctx.setLineWidth(2); ctx.setStrokeColor(white(0.7)); ctx.strokePath()
        ctx.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VolumeMixer-\(UUID().uuidString).iconset")
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! draw(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! draw(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
if let previewPath { try! draw(size: 1024).write(to: URL(fileURLWithPath: previewPath)) }
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out]
try! task.run()
task.waitUntilExit()
try? fm.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "Wrote \(out)" : "iconutil failed")
