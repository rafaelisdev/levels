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
    static let snapshotPath: String? = value(after: "--snapshot")
    /// `--update-feed <url>`: read update.json from here instead of the latest release.
    static let updateFeed: URL? = value(after: "--update-feed").flatMap(URL.init(string:))
    /// `--sync <bundle id> [--sync-outputs uid,uid]`: multi-output sync test (SyncProbe).
    static let syncApp: String? = value(after: "--sync")
    static let syncOutputs: [String]? = value(after: "--sync-outputs")?.split(separator: ",").map(String.init)
    /// `--sync-measure [--measure-dump <path>]`: acoustic sync measurement (SyncMeasure),
    /// from the Levels Measure copy. `--sync-analyze <path>`: analyse a saved recording.
    static let measure = args.contains("--sync-measure")
    static let measureDump: String? = value(after: "--measure-dump")
    static let analyzePath: String? = value(after: "--sync-analyze")

    private static func value(after flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
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
        if let path = DebugFlags.analyzePath, #available(macOS 14.2, *) {
            SyncMeasure.analyze(path: path)
            return
        }
        if DebugFlags.measure, #available(macOS 14.2, *) {
            // Measurement copy: no panel and no taps, just the test, then quit. Started a
            // moment after launch: creating IO procs during launch can stall Core Audio.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                SyncMeasure.run(outputUIDs: DebugFlags.syncOutputs, dumpPath: DebugFlags.measureDump)
            }
            return
        }
        let model = MixerModel.shared

        makeStatusItem()

        panel = MenuPanel(rootView: MixerPanel(model: model, close: { [weak self] in self?.panel.dismiss() }))
        panel.willShow = { model.panelOpened() }

        if DebugFlags.openAtLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.togglePanel() }
        }
        watchForHiddenStatusItem(model: model)
        Updater.shared.canInstallUnattended = { [weak self] in
            !(self?.panel.isVisible ?? true) && !model.apps.contains(where: \.isPlaying)
        }
        Updater.shared.start()
        if let app = DebugFlags.syncApp, #available(macOS 14.2, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                SyncProbe.start(appID: app, outputUIDs: DebugFlags.syncOutputs)
            }
        }
        if let path = DebugFlags.snapshotPath {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                Task { @MainActor in Self.writeSnapshot(of: model, to: path) }
            }
        }
    }

    /// Debug: render the panel with SwiftUI's own renderer (dark, solid background).
    /// AppKit-backed controls such as the switch show as placeholders there.
    @MainActor
    private static func writeSnapshot(of model: MixerModel, to path: String) {
        guard #available(macOS 13, *) else { return }
        let page: AnyView = CommandLine.arguments.contains("--snapshot-outputs")
            ? AnyView(OutputsPage(model: model) {}.frame(width: 330))
            : AnyView(MixerPanel(model: model))
        let view = page
            .background(Color(white: 0.17))
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        try? png?.write(to: URL(fileURLWithPath: path))
    }

    /// Opening Levels again (Spotlight, Finder, Dock) shows the panel: the way in when
    /// the menu bar icon is hidden. Shown a beat later, once the activation is done.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.showPanel() }
        return false
    }

    /// macOS hides status items that don't fit (on MacBooks, behind the camera notch).
    /// If ours stays hidden even next to the system icons, open the panel once and say
    /// why, so Levels never just vanishes. Checked for a few seconds: the first launch
    /// after an update can take that long to draw the icon.
    private func watchForHiddenStatusItem(model: MixerModel, checksLeft: Int = 4) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            let visible = self.statusItemVisible
            self.debugLog("status item visible: \(visible)")
            guard !visible else { return }
            if checksLeft > 1 {
                self.watchForHiddenStatusItem(model: model, checksLeft: checksLeft - 1)
            } else {
                model.menuBarIconHidden = true
                self.showPanel()
            }
        }
    }

    private static let statusItemName = "LevelsStatusItem"
    /// Where AppKit keeps a status item's place; larger is further left.
    private static var positionKey: String { "NSStatusItem Preferred Position \(statusItemName)" }

    private func makeStatusItem() {
        placeStatusItemOnFirstLaunch()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = Self.statusItemName   // keeps a ⌘-dragged position across launches
        guard let button = statusItem.button else { return }
        button.image = LevelsSymbol.menuBar
        button.setAccessibilityLabel("Levels")
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    /// A new status item starts at the far left, closest to the notch, where a full menu
    /// bar hides it. So the first time, Levels takes a place just left of the system
    /// (Control Center) icons, next to Sound. Only Levels' own position is written, and
    /// only before the item exists (AppKit reads it once, when the item is created); after
    /// that, wherever the user ⌘-drags the icon is kept.
    private func placeStatusItemOnFirstLaunch() {
        guard UserDefaults.standard.object(forKey: Self.positionKey) == nil else { return }
        let system = UserDefaults(suiteName: "com.apple.controlcenter")?.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("NSStatusItem Preferred Position") }
            .compactMap { ($0.value as? NSNumber)?.doubleValue } ?? []
        let position = (system.max() ?? 360) + 40
        UserDefaults.standard.set(position, forKey: Self.positionKey)
        debugLog("status item placed at preferred position \(Int(position))")
    }

    private func debugLog(_ text: String) {
        guard DebugFlags.debug else { return }
        print(text)
        fflush(stdout)
    }

    private var statusItemVisible: Bool {
        statusItem.button?.window?.occlusionState.contains(.visible) ?? false
    }

    private func showPanel() {
        guard let button = statusItem.button, !panel.isVisible else { return }
        panel.toggle(below: button)
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
    private var shownAt = Date.distantPast
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
        hosting.frame = effect.bounds
        effect.addSubview(hosting)
        contentView = effect
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        // Activation shuffles focus right after the panel opens (e.g. when Levels is
        // reopened from Spotlight); that is not the user clicking away.
        if Date().timeIntervalSince(shownAt) < 0.6 {
            DispatchQueue.main.async { self.makeKey() }
            return
        }
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
        shownAt = Date()
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
