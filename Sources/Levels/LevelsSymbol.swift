import AppKit
import SwiftUI

/// The Levels symbol from the brand board: three faders in a 120×120 viewBox,
/// stroke 7, knobs r 12.5 with a 7 pt ring cut out of whatever is behind them.
enum LevelsSymbol {
    private static let faders: [CGFloat] = [30, 60, 90]
    private static let knobs: [(CGFloat, CGFloat)] = [(30, 76), (60, 36), (90, 58)]

    /// Black-on-transparent template image; macOS tints it for the menu bar.
    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = rect.width / 120
            ctx.scaleBy(x: s, y: s)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(7)
            ctx.setLineCap(.round)
            for x in faders {
                ctx.move(to: CGPoint(x: x, y: 20))
                ctx.addLine(to: CGPoint(x: x, y: 100))
            }
            ctx.strokePath()
            for (x, y) in knobs {
                ctx.setBlendMode(.clear)        // the ring: a transparent gap around the knob
                ctx.fillEllipse(in: CGRect(x: x - 16, y: y - 16, width: 32, height: 32))
                ctx.setBlendMode(.normal)
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillEllipse(in: CGRect(x: x - 9, y: y - 9, width: 18, height: 18))
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 18 pt, the size the board specifies for the menu bar.
    static let menuBar: NSImage = image(size: 18)
}

/// The symbol in SwiftUI, tinted with the current foreground color.
struct LevelsMark: View {
    var size: CGFloat = 22
    var body: some View {
        Image(nsImage: LevelsSymbol.image(size: size))
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
    }
}
