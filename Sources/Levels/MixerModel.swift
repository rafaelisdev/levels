import AppKit
import AudioToolbox
import Combine
import CoreAudio
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
    private var syncingLogin = false
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var timer: Timer?
    private let defaultsKey = "appVolumes"

    @available(macOS 14.2, *)
    private var engine: TapEngine { engineBox as! TapEngine }

    private init() {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        systemVersion = v.patchVersion > 0 ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" : "\(v.majorVersion).\(v.minorVersion)"

        if #available(macOS 14.2, *), !DebugFlags.legacy {
            perAppSupported = true
            engineBox = TapEngine()
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

        listenToSystem()
        refreshOutputDevice()
        refreshApps()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
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
        if #available(macOS 13, *) {
            syncingLogin = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
            syncingLogin = false
        }
    }

    // MARK: - Listening

    private func listenToSystem() {
        if #available(macOS 14.2, *), perAppSupported {
            var processes = CA.address(kAudioHardwarePropertyProcessObjectList)
            AudioObjectAddPropertyListenerBlock(CA.system, &processes, .main) { [weak self] _, _ in
                self?.refreshApps()
            }
        }
        var output = CA.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(CA.system, &output, .main) { [weak self] _, _ in
            self?.refreshOutputDevice()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if #available(macOS 14.2, *), self.perAppSupported { self.engine.dropAll() }
        }
    }

    private func tick() {
        refreshApps()
        if perAppSupported && permission != .authorized { refreshPermission() }
        if DebugFlags.debug { logDebug() }
    }

    private func logDebug() {
        let playing = apps.filter(\.isPlaying).map(\.name).joined(separator: ", ")
        var line = "macOS \(systemVersion) perApp=\(perAppSupported) perm=\(permission) out=\(outputName) master=\(masterVolume.map { String(format: "%.2f", $0) } ?? "-") playing=[\(playing)]"
        if #available(macOS 14.2, *), perAppSupported { line += " " + engine.debugLine() }
        if let errorMessage { line += " | error: \(errorMessage)" }
        print(line)
        fflush(stdout)
    }

    private func refreshPermission() {
        let status = AudioCapturePermission.status()
        guard status != permission else { return }
        permission = status
        reconcile()
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
        outputName = device == kAudioObjectUnknown ? "Нет устройства вывода" : CA.deviceName(device)
        outputSymbol = Self.symbol(for: device, name: outputName)

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.refreshMaster() }
        for selector in [CA.virtualMainVolume, kAudioDevicePropertyMute] {
            var addr = CA.address(selector, scope: kAudioDevicePropertyScopeOutput)
            if AudioObjectAddPropertyListenerBlock(device, &addr, .main, block) == noErr {
                deviceListeners.append((addr, block))
            }
        }
        refreshMaster()

        // Taps play into a specific device, so move them all to the new one.
        if #available(macOS 14.2, *), perAppSupported {
            engine.dropAll()
            reconcile()
        }
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

    private func refreshApps() {
        guard #available(macOS 14.2, *), perAppSupported else { return }
        let fresh = engine.scanApps()
        if fresh != apps {
            apps = fresh
            reconcile()
        }
    }

    private func wantsTap(_ id: String) -> Bool {
        muted.contains(id) || volume(of: id) < 1
    }

    /// Slider position → amplitude. Squared so the slider feels even to the ear.
    private func gain(for id: String) -> Float {
        if muted.contains(id) { return 0 }
        let v = volume(of: id)
        return v * v
    }

    private func clearFailure(_ id: String) {
        if #available(macOS 14.2, *), perAppSupported { engine.clearFailure(id) }
    }

    private func reconcile() {
        guard #available(macOS 14.2, *), perAppSupported else { return }
        let needed = apps.contains { wantsTap($0.id) }

        guard permission == .authorized else {
            // Without the permission a tap returns silence while muting the app.
            engine.dropAll()
            if needed && permission == .unknown { askForPermission() }
            return
        }
        let error = engine.reconcile(apps: apps, outputUID: outputUID,
                                     wantsTap: { [unowned self] in self.wantsTap($0) },
                                     gain: { [unowned self] in self.gain(for: $0) })
        if error != errorMessage { errorMessage = error }
    }

    private func askForPermission() {
        guard !requestingPermission else { return }
        requestingPermission = true
        AudioCapturePermission.request { [weak self] granted in
            guard let self else { return }
            self.requestingPermission = false
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
            errorMessage = "Автозапуск: \(error.localizedDescription)"
        }
        syncingLogin = true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        syncingLogin = false
    }
}
