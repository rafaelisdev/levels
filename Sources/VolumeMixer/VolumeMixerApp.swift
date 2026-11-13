import AppKit
import SwiftUI

enum DebugFlags {
    private static let args = CommandLine.arguments
    /// `--debug`: print tap levels to stdout every second.
    static let debug = args.contains("--debug")
    /// `--legacy`: behave as on macOS older than 14.2 (device volume only).
    static let legacy = args.contains("--legacy")
    /// `--open`: show the panel right after launch.
    static let openAtLaunch = args.contains("--open") || snapshotPath != nil
    /// `--snapshot <path>`: keep writing the panel to a PNG (for checking the UI).
    static let snapshotPath: String? = {
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()
}

// An AppKit shell instead of SwiftUI's MenuBarExtra, which needs macOS 13.
@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: MenuPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = MixerModel.shared

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "slider.vertical.3", accessibilityDescription: "Микшер")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        panel = MenuPanel(rootView: MixerPanel(model: model, close: { [weak self] in self?.panel.dismiss() }))
        panel.willShow = { model.panelOpened() }

        if DebugFlags.openAtLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.togglePanel() }
        }
        if let path = DebugFlags.snapshotPath {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.panel.writeSnapshot(to: path)
            }
        }
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        panel.toggle(below: button)
    }
}

/// Borderless panel under the menu bar icon that looks like a system menu: blurred
/// background, rounded corners, shadow. Closes on outside click or Escape.
final class MenuPanel: NSPanel {
    private let effect = NSVisualEffectView()
    private var hosting: NSHostingView<AnyView>!
    private weak var anchor: NSStatusBarButton?
    private var keyMonitor: Any?
    private var lastDismiss = Date.distantPast
    private let radius: CGFloat = 13
    var willShow: (() -> Void)?

    init<Content: View>(rootView: Content) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 330, height: 300),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: radius)

        let root = rootView
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
            .fixedSize()
            .background(SizeReader { [weak self] size in self?.fit(size) })
        hosting = NSHostingView(rootView: AnyView(root))
        hosting.autoresizingMask = [.width, .height]
        if DebugFlags.snapshotPath != nil {
            // cacheDisplay can't capture vibrancy, so snapshots use a solid dark backing.
            appearance = NSAppearance(named: .darkAqua)
            let plain = NSView()
            plain.wantsLayer = true
            plain.layer?.backgroundColor = NSColor(white: 0.17, alpha: 1).cgColor
            hosting.frame = plain.bounds
            plain.addSubview(hosting)
            contentView = plain
        } else {
            hosting.frame = effect.bounds
            effect.addSubview(hosting)
            contentView = effect
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        dismiss()
    }

    override func cancelOperation(_ sender: Any?) { dismiss() }

    func toggle(below button: NSStatusBarButton) {
        if isVisible { dismiss(); return }
        // The click that closed the panel (resignKey) also lands here; don't reopen at once.
        guard Date().timeIntervalSince(lastDismiss) > 0.25 else { return }
        show(below: button)
    }

    private func show(below button: NSStatusBarButton) {
        anchor = button
        willShow?()
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        setFrame(frameFor(size: size), display: true)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().alphaValue = 1
        }
        button.highlight(true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss(); return nil } // Escape
            return event
        }
    }

    func dismiss() {
        guard isVisible else { return }
        lastDismiss = Date()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        anchor?.highlight(false)
        orderOut(nil)
    }

    /// Keep the panel's top edge under the icon while SwiftUI content grows or shrinks.
    private func fit(_ size: CGSize) {
        guard size.width > 0, size.height > 0, isVisible else { return }
        setFrame(frameFor(size: size), display: true)
        invalidateShadow()
    }

    private func frameFor(size: CGSize) -> NSRect {
        guard let button = anchor, let window = button.window else {
            return NSRect(origin: frame.origin, size: size)
        }
        let item = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? item
        var x = item.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = item.minY - 5 - size.height
        return NSRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    /// Debug: draw the panel content over a plain background into a PNG.
    func writeSnapshot(to path: String) {
        let view = hosting!
        let rect = view.bounds
        guard rect.width > 0, let rep = view.bitmapImageRepForCachingDisplay(in: rect) else { return }
        view.cacheDisplay(in: rect, to: rep)
        let image = NSImage(size: rect.size)
        image.lockFocus()
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        NSColor(white: dark ? 0.17 : 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: rect.size), xRadius: radius, yRadius: radius).fill()
        rep.draw(in: rect)
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff),
           let png = bmp.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}

private struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Reports the SwiftUI content size so the panel can follow it.
private struct SizeReader: View {
    let onChange: (CGSize) -> Void
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: SizeKey.self, value: geo.size)
        }
        .onPreferenceChange(SizeKey.self, perform: onChange)
    }
}
