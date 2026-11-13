// Draws the Levels app icon from the brand board ("Levels — logo & app icon"):
// 824 pt plate, corner radius 186, dark gradient, white symbol 500 pt wide.
// Usage: swift scripts/make_icon.swift Resources/AppIcon.icns [preview.png] [--light]
import AppKit

let args = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
let light = CommandLine.arguments.contains("--light")
let out = args.first ?? "AppIcon.icns"
let previewPath = args.dropFirst().first

func gray(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// Theme values copied from the board's renderVals().
let plateTop = light ? gray(0xFFFFFF) : gray(0x262626)
let plateBottom = light ? gray(0xF1F1F1) : gray(0x050505)
let fg = light ? gray(0x0A0A0A) : gray(0xFFFFFF)
let knobBg = light ? gray(0xF8F8F8) : gray(0x141414)

/// The Levels symbol in its 120×120 viewBox (y down, like the SVG).
func drawSymbol(_ ctx: CGContext, in rect: CGRect) {
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: rect.width / 120, y: -rect.height / 120)   // flip to SVG coordinates
    ctx.setStrokeColor(fg)
    ctx.setLineWidth(7)
    ctx.setLineCap(.round)
    for x in [30.0, 60.0, 90.0] {
        ctx.move(to: CGPoint(x: x, y: 20))
        ctx.addLine(to: CGPoint(x: x, y: 100))
    }
    ctx.strokePath()
    // Knob: r 12.5 filled with fg, stroked 7 wide in the plate color = ring 9…16.
    for (x, y) in [(30.0, 76.0), (60.0, 36.0), (90.0, 58.0)] {
        ctx.setFillColor(knobBg)
        ctx.fillEllipse(in: CGRect(x: x - 16, y: y - 16, width: 32, height: 32))
        ctx.setFillColor(fg)
        ctx.fillEllipse(in: CGRect(x: x - 9, y: y - 9, width: 18, height: 18))
    }
    ctx.restoreGState()
}

func draw(size px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ns = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ns
    let ctx = ns.cgContext
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)   // work in the 1024 grid

    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)

    // Shadows from the board: 0 30px 60px and 0 4px 12px (y flipped).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 60, color: CGColor(gray: 0, alpha: light ? 0.18 : 0.30))
    ctx.addPath(shape); ctx.setFillColor(plateBottom); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: CGColor(gray: 0, alpha: light ? 0.10 : 0.20))
    ctx.addPath(shape); ctx.setFillColor(plateBottom); ctx.fillPath()
    ctx.restoreGState()

    // Plate gradient, top to bottom.
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [plateTop, plateBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: plate.maxY), end: CGPoint(x: 0, y: plate.minY), options: [])
    // Dark: inset 0 1px 0 rgba(255,255,255,.12). Light: inset 0 0 0 1px rgba(0,0,0,.06).
    if light {
        ctx.addPath(shape); ctx.setLineWidth(2); ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.06)); ctx.strokePath()
    } else {
        let lower = CGPath(roundedRect: plate.offsetBy(dx: 0, dy: -2), cornerWidth: 186, cornerHeight: 186, transform: nil)
        ctx.addPath(shape); ctx.addPath(lower)
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.12))
        ctx.fillPath(using: .evenOdd)
    }
    ctx.restoreGState()

    // Symbol: 500 pt, centered.
    drawSymbol(ctx, in: CGRect(x: 262, y: 262, width: 500, height: 500))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Levels-\(UUID().uuidString).iconset")
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
