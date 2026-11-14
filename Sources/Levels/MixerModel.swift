import AppKit
import AudioToolbox
import Combine
import CoreAudio
import LevelsCore
import ServiceManagement

struct AudioApp: Identifiable, Equatable {
    let id: String            // bundle id, or "pid.<n>" for apps without one
    let name: String
    let icon: NSImage
    var processObjects: [AudioObjectID]
    var isPlaying: Bool

    static func == (a: AudioApp, b: AudioApp) -> Bool {
        a.id == b.id && a.name == b.name && a.isPlaying == b.isPlaying && a.processObjects == b.processObjects
    }
}

/// An output device as the Outputs page shows it.
struct OutputChoice: Identifiable, Equatable {
    let id: String          // device UID
    let name: String
    let symbol: String
    let isBuiltIn: Bool
}

/// All state lives on the main thread. Core Audio listeners hop to the main queue.
final class MixerModel: ObservableObject {
    static let shared = MixerModel()

    @Published private(set) var apps: [AudioApp] = []
    @Published private(set) var volumes: [String: Float] = [:]   // slider position 0...1, saved
    @Published private(set) var muted: Set<String> = []          // per session
    @Published private(set) var outputName = ""
    @Published private(set) var outputSymbol = "speaker.wave.2.fill"
    @Published private(set) var masterVolume: Float?             // nil: device has no volume control
    @Published private(set) var masterMuted = false
    @Published private(set) var permission: AudioCapturePermission.Status = .unknown
    @Published private(set) var errorMessage: String?
    /// Real output devices (for the Outputs page).
    @Published private(set) var outputs: [OutputChoice] = []
    /// Extra devices to play on besides the default output (UIDs, saved). With at least
    /// one connected, tapped apps play on all of them, lined up.
    @Published private(set) var syncSelection: [String] = []
    /// Latency Core Audio doesn't know about, per device (seconds), relative to the
    /// built-in speakers. Measured or set by ear on the Outputs page; saved.
    @Published private(set) var syncOffsets: [String: Double] = [:]
    /// How the synced outputs line up right now (nil when not syncing).
    @Published private(set) var syncSummary: SyncSummary?
    /// True while taps are being rebuilt in the background (e.g. an output was added).
    @Published private(set) var engineBusy = false
    /// macOS hid the menu bar icon (no room); the panel explains it until dismissed.
    @Published var menuBarIconHidden = false
    @Published var launchAtLogin = false {
        didSet { if launchAtLogin != oldValue && !syncingLogin { applyLaunchAtLogin() } }
    }

    /// Per-app volume needs Core Audio process taps (macOS 14.2+).
    let perAppSupported: Bool
    /// SMAppService (macOS 13+).
    let launchAtLoginSupported: Bool
    let systemVersion: String

    private let engineBox: AnyObject?
    private var outputDevice = AudioObjectID(kAudioObjectUnknown)
    private var outputUID = ""
    private var requestingPermission = false
    /// TCC turned a request down this session. After that it can still report "never
    /// asked" (it does for a rebuilt, re-signed app), and asking again only gets another
    /// instant no, so the panel flipped between its two permission cards every second.
    private var permissionRefused = false
    private var syncingLogin = false
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var timer: Timer?
    private let defaultsKey = "appVolumes"
    private let selectionKey = "syncOutputs"
    private let offsetsKey = "syncOffsets"
    /// False during launch: sync groups are only created once this is set (see init).
    private var syncReady = false
    static let offsetRange: ClosedRange<Double> = -0.2...0.5

    @available(macOS 14.2, *)
    private var engine: TapEngine { engineBox as! TapEngine }

    private init() {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        systemVersion = v.patchVersion > 0 ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" : "\(v.majorVersion).\(v.minorVersion)"

        if #available(macOS 14.2, *), !DebugFlags.legacy {
            perAppSupported = true
            let engine = TapEngine()
            engineBox = engine
        } else {
            perAppSupported = false
            engineBox = nil
        }
        if #available(macOS 13, *) {
            launchAtLoginSupported = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLoginSupported = false
        }

        if let saved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Double] {
            volumes = saved.mapValues { Float($0) }
        } else if let old = UserDefaults(suiteName: "local.volumemixer")?.dictionary(forKey: defaultsKey) as? [String: Double] {
            // First launch after the rename from VolumeMixer: keep the saved volumes.
            volumes = old.mapValues { Float($0) }
            UserDefaults.standard.set(old, forKey: defaultsKey)
        }
        if perAppSupported { permission = AudioCapturePermission.status() }
        syncSelection = UserDefaults.standard.stringArray(forKey: selectionKey) ?? []
        syncOffsets = UserDefaults.standard.dictionary(forKey: offsetsKey) as? [String: Double] ?? [:]

        if #available(macOS 14.2, *), perAppSupported {
            engine.onReport = { [weak self] report in self?.apply(report) }
            engine.onBusy = { [weak self] busy in self?.engineBusy = busy }
        }
        listenToSystem()
        refreshOutputs()
        refreshOutputDevice()
        refreshApps()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if DebugFlags.debug { startDebugTools() }
        // Multi-output starts a moment after launch: creating several IO procs while the
        // app is still launching once stalled Core Audio. Until then taps play normally.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.syncReady = true
            self?.applySync()
        }
    }

    // MARK: - Multi-output

    /// Outputs playing right now: the default output first (it clocks the capture), then
    /// the selected extra devices that are connected.
    var activeOutputs: [String] {
        guard !outputUID.isEmpty else { return [] }
        let connected = Set(outputs.map(\.id))
        return [outputUID] + syncSelection.filter { $0 != outputUID && connected.contains($0) }
    }

    var isSyncing: Bool { activeOutputs.count >= 2 }
    var defaultOutputUID: String { outputUID }

    func plays(on uid: String) -> Bool { activeOutputs.contains(uid) }

    func toggleOutput(_ uid: String) {
        guard uid != outputUID else { return }   // the default output always plays
        if let i = syncSelection.firstIndex(of: uid) { syncSelection.remove(at: i) } else { syncSelection.append(uid) }
        UserDefaults.standard.set(syncSelection, forKey: selectionKey)
        applySync()
    }

    func syncOffset(_ uid: String) -> Double { syncOffsets[uid] ?? 0 }

    func setSyncOffset(_ seconds: Double, for uid: String) {
        let ms = (min(max(seconds, Self.offsetRange.lowerBound), Self.offsetRange.upperBound) * 1000).rounded()
        syncOffsets[uid] = ms / 1000
        UserDefaults.standard.set(syncOffsets, forKey: offsetsKey)
        applySync()
    }

    private func applySync() { pushSettings() }

    /// Lists output devices off the main thread (each property is a round trip to the
    /// audio server), then publishes them.
    private func refreshOutputs() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fresh = CA.outputDevices().map { d in
                OutputChoice(id: d.uid, name: d.name, symbol: Self.symbol(for: d.id, name: d.name),
                             isBuiltIn: d.transport == kAudioDeviceTransportTypeBuiltIn)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, fresh != self.outputs else { return }
                let before = self.activeOutputs
                self.outputs = fresh
                if self.activeOutputs != before { self.pushSettings() }   // a selected device came or went
            }
        }
    }

    // MARK: - Public actions

    func volume(of id: String) -> Float { volumes[id] ?? 1 }
    func isMuted(_ id: String) -> Bool { muted.contains(id) }

    func setVolume(_ value: Float, for id: String) {
        let v = (min(max(value, 0), 1) * 100).rounded() / 100
        if v >= 1 { volumes[id] = nil } else { volumes[id] = v }
        if v > 0 { muted.remove(id) }
        clearFailure(id)
        save()
        reconcile()
    }

    func toggleMute(_ id: String) {
        if muted.contains(id) { muted.remove(id) } else { muted.insert(id) }
        clearFailure(id)
        reconcile()
    }

    func reset(_ id: String) {
        volumes[id] = nil
        muted.remove(id)
        save()
        reconcile()
    }

    func resetAll() {
        volumes.removeAll()
        muted.removeAll()
        save()
        reconcile()
    }

    func setMasterVolume(_ v: Float) {
        guard outputDevice != kAudioObjectUnknown else { return }
        CA.setVolume(outputDevice, v)
        masterVolume = v
        if masterMuted && v > 0 {
            CA.setMuted(outputDevice, false)
            masterMuted = false
        }
    }

    func toggleMasterMute() {
        guard outputDevice != kAudioObjectUnknown else { return }
        CA.setMuted(outputDevice, !masterMuted)
        masterMuted = CA.isMuted(outputDevice)
    }

    func requestPermission() {
        if permission == .denied {
            AudioCapturePermission.openSystemSettings()
        } else {
            askForPermission()
        }
    }

    /// Called each time the panel opens so the list is fresh immediately.
    func panelOpened() {
        if perAppSupported { refreshPermission() }
        refreshApps()
        refreshMaster()
        refreshOutputs()
        if #available(macOS 13, *) {
            syncingLogin = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
            syncingLogin = false
        }
    }

    // MARK: - Listening

    private func listenToSystem() {
        var output = CA.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(CA.system, &output, .main) { [weak self] _, _ in
            self?.refreshOutputDevice()
        }
        var devices = CA.address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(CA.system, &devices, .main) { [weak self] _, _ in
            self?.refreshOutputs()
        }
        // No cleanup on quit: private taps and aggregates die with the process, and the
        // apps get their sound back.
    }

    private func tick() {
        refreshApps()
        if perAppSupported && permission != .authorized { refreshPermission() }
        if DebugFlags.debug { logDebug() }
    }

    /// Debug only: report main-thread stalls, and accept commands from outside
    /// (`toggle:<uid>`, `offset:<uid>:<ms>`) so UI responsiveness can be measured.
    private func startDebugTools() {
        var lastBeat = HostClock.now
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let now = HostClock.now
            if now - lastBeat > 0.15 { print(String(format: "stall: main thread blocked %.0f ms", (now - lastBeat - 0.05) * 1000)); fflush(stdout) }
            lastBeat = now
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("io.github.rafaelisdev.levels.debug"),
                                                            object: nil, queue: .main) { [weak self] note in
            guard let self, let command = note.object as? String else { return }
            let parts = command.split(separator: ":").map(String.init)
            print("debug command: \(command)"); fflush(stdout)
            if parts.count == 2, parts[0] == "toggle" { self.toggleOutput(parts[1]) }
            if parts.count == 3, parts[0] == "offset", let ms = Double(parts[2]) { self.setSyncOffset(ms / 1000, for: parts[1]) }
        }
    }

    private func logDebug() {
        let playing = apps.filter(\.isPlaying).map(\.name).joined(separator: ", ")
        var line = "macOS \(systemVersion) perApp=\(perAppSupported) perm=\(permission) out=\(outputName) master=\(masterVolume.map { String(format: "%.2f", $0) } ?? "-") playing=[\(playing)]"
        if let errorMessage { line += " | error: \(errorMessage)" }
        if #available(macOS 14.2, *), perAppSupported {
            engine.logDebug(prefix: line)
        } else {
            print(line)
            fflush(stdout)
        }
    }

    /// Asks TCC off the main thread (a round trip that can take a while), then updates.
    private func refreshPermission() {
        DispatchQueue.global(qos: .utility).async {
            let reported = AudioCapturePermission.status()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let status = reported == .unknown && self.permissionRefused ? .denied : reported
                guard status != self.permission else { return }
                self.permission = status
                self.reconcile()
            }
        }
    }

    // MARK: - Output device

    private func refreshOutputDevice() {
        let device = CA.defaultOutputDevice()
        guard device != outputDevice else { refreshMaster(); return }

        for (addr, block) in deviceListeners {
            var a = addr
            AudioObjectRemovePropertyListenerBlock(outputDevice, &a, .main, block)
        }
        deviceListeners.removeAll()

        outputDevice = device
        outputUID = CA.deviceUID(device) ?? ""
        outputName = device == kAudioObjectUnknown ? NSLocalizedString("No output device", comment: "") : CA.deviceName(device)
        outputSymbol = Self.symbol(for: device, name: outputName)

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.refreshMaster() }
        for selector in [CA.virtualMainVolume, kAudioDevicePropertyMute] {
            var addr = CA.address(selector, scope: kAudioDevicePropertyScopeOutput)
            if AudioObjectAddPropertyListenerBlock(device, &addr, .main, block) == noErr {
                deviceListeners.append((addr, block))
            }
        }
        refreshMaster()

        // Taps play into specific devices: the engine moves them (new before old).
        pushSettings()
    }

    private func refreshMaster() {
        let v = CA.canSetVolume(outputDevice) ? CA.volume(outputDevice) : nil
        if v != masterVolume { masterVolume = v }
        let m = CA.isMuted(outputDevice)
        if m != masterMuted { masterMuted = m }
    }

    private static func symbol(for device: AudioObjectID, name: String) -> String {
        switch CA.transportType(device) {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return name.localizedCaseInsensitiveContains("airpods") ? "airpods" : "headphones"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "tv"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt:
            return "hifispeaker.fill"
        case kAudioDeviceTransportTypeBuiltIn:
            let lower = name.lowercased()
            return lower.contains("headphone") || lower.contains("наушник") ? "headphones" : "laptopcomputer"
        default:
            return "speaker.wave.2.fill"
        }
    }

    // MARK: - Apps and taps

    /// Ask the engine for a fresh look at which apps play (it scans off the main thread).
    private func refreshApps() {
        guard #available(macOS 14.2, *), perAppSupported else { return }
        engine.refresh()
    }

    private func wantsTap(_ id: String) -> Bool {
        muted.contains(id) || volume(of: id) < 1
    }

    private func clearFailure(_ id: String) {
        if #available(macOS 14.2, *), perAppSupported { engine.clearFailure(id) }
    }

    private func reconcile() { pushSettings() }

    /// Send the state the UI wants to the engine; it does the Core Audio work on its own
    /// queue and reports back through `apply(_:)`.
    private func pushSettings() {
        guard #available(macOS 14.2, *), perAppSupported else { return }
        askForPermissionIfNeeded()
        var settings = TapEngine.Settings()
        settings.authorized = permission == .authorized
        settings.outputUID = outputUID
        if syncReady && isSyncing {
            settings.syncOutputs = activeOutputs.map { SyncGroup.Output(uid: $0, extraLatency: syncOffset($0)) }
        }
        settings.volumes = volumes
        settings.muted = muted
        engine.update(settings)
    }

    @available(macOS 14.2, *)
    private func apply(_ report: TapEngine.Report) {
        if report.apps != apps {
            apps = report.apps
            // A newly seen app may need a tap the moment it shows up (saved volume).
            askForPermissionIfNeeded()
        }
        if report.error != errorMessage { errorMessage = report.error }
        if report.sync != syncSummary { syncSummary = report.sync }
    }

    /// Asks the first time Levels needs a tap: a slider below 100%, a mute, or playing
    /// on several outputs (without the permission that only plays on the default one).
    private func askForPermissionIfNeeded() {
        guard permission == .unknown else { return }
        if (syncReady && isSyncing) || apps.contains(where: { wantsTap($0.id) }) { askForPermission() }
    }

    private func askForPermission() {
        guard !requestingPermission else { return }
        requestingPermission = true
        AudioCapturePermission.request { [weak self] granted in
            guard let self else { return }
            self.requestingPermission = false
            if !granted { self.permissionRefused = true }
            let status = AudioCapturePermission.status()
            self.permission = granted ? .authorized : (status == .unknown ? .denied : status)
            self.reconcile()
        }
    }

    // MARK: - Misc

    private func save() {
        UserDefaults.standard.set(volumes.mapValues { Double($0) }, forKey: defaultsKey)
    }

    private func applyLaunchAtLogin() {
        guard #available(macOS 13, *) else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = String(format: NSLocalizedString("Launch at login: %@", comment: ""), error.localizedDescription)
        }
        syncingLogin = true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        syncingLogin = false
    }
}
