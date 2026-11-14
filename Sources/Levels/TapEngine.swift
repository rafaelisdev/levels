import AppKit
import CoreAudio
import LevelsCore

/// How the synced outputs line up, for the Outputs page.
struct SyncSummary: Equatable {
    struct Output: Equatable {
        let uid: String
        let own: Double      // the device's own path: buffers + device + calibration
        let held: Double     // how long Levels holds it back to meet the slowest one
    }
    let delay: Double        // what every app's sound is delayed by, end to end
    let outputs: [Output]
}

/// A per-app tap, whichever way it plays the audio: on the default output
/// (`ProcessTap`) or on several outputs in sync (`SyncGroup`).
@available(macOS 14.2, *)
protocol AppTap: AnyObject {
    /// Where it plays: an output UID, or the synced outputs' UIDs joined by "+".
    var destination: String { get }
    var gain: Float { get set }
    var processObjects: [AudioObjectID] { get }
    func updateProcesses(_ objects: [AudioObjectID]) -> Bool
    func invalidate()
    func takePeaks() -> (input: Float, output: Float)?
}

/// Finds apps that play audio and keeps one tap per app that needs one (macOS 14.2+).
///
/// Everything that talks to Core Audio runs on the engine's own serial queue: each of
/// those calls is a round trip to the audio server, and building or tearing down taps
/// for several apps on several outputs takes long enough to freeze the panel. The UI
/// sends the state it wants (`update`) or asks for a fresh look (`refresh`); requests
/// that pile up while a pass runs are merged into one. Results come back on the main
/// thread through `onReport` and `onBusy`.
@available(macOS 14.2, *)
final class TapEngine {
    /// What the UI wants. The engine works out which taps that takes.
    struct Settings: Equatable {
        var authorized = false
        var outputUID = ""
        /// nil: tapped apps play on the default output. Two or more outputs: every app
        /// that plays goes through a `SyncGroup` and is heard on all of them, lined up.
        var syncOutputs: [SyncGroup.Output]?
        var volumes: [String: Float] = [:]     // slider positions; absent = 100%
        var muted: Set<String> = []

        func wantsTap(_ id: String) -> Bool { muted.contains(id) || (volumes[id] ?? 1) < 1 }
        /// Slider position -> amplitude, squared so the slider feels even to the ear.
        func gain(_ id: String) -> Float {
            if muted.contains(id) { return 0 }
            let v = volumes[id] ?? 1
            return v * v
        }
        var destination: String { syncOutputs.map(SyncGroup.destination) ?? outputUID }
    }

    struct Report {
        var apps: [AudioApp]
        var error: String?
        var sync: SyncSummary?
    }

    /// Called on the main thread after every pass.
    var onReport: ((Report) -> Void)?
    /// Called on the main thread when taps start and finish being rebuilt.
    var onBusy: ((Bool) -> Void)?

    private let queue = DispatchQueue(label: "io.github.rafaelisdev.levels.engine", qos: .userInitiated)

    // Requests from other threads, merged until the next pass picks them up.
    private let pendingLock = NSLock()
    private var pendingSettings: Settings?
    private var pendingScan = false
    private var passScheduled = false

    // Engine-queue state.
    private var settings = Settings()
    private var apps: [AudioApp] = []
    private var taps: [String: AppTap] = [:]
    private var failed: [String: Set<AudioObjectID>] = [:]
    /// Apps that keep their tap even when set back to 100%. Switching between the tap and
    /// the direct path is what made 99% → 100% jump, so once an app has been touched it
    /// stays on the tap (gain 1.0) until it quits.
    private var engaged: Set<String> = []

    init() {
        // New or vanished audio processes: look again (delivered on the engine queue).
        var processes = CA.address(kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(CA.system, &processes, queue) { [weak self] _, _ in self?.refresh() }
    }

    // MARK: Requests (any thread)

    func update(_ settings: Settings) { schedule(settings: settings, scan: false) }
    /// Rescan apps (who is playing, new helper processes) and reconcile.
    func refresh() { schedule(settings: nil, scan: true) }
    func clearFailure(_ id: String) { queue.async { self.failed[id] = nil } }

    /// Debug: one line about every tap, printed from the engine queue.
    func logDebug(prefix: String) {
        queue.async {
            print(prefix + " " + self.debugLine())
            fflush(stdout)
        }
    }

    private func schedule(settings: Settings?, scan: Bool) {
        pendingLock.lock()
        if let settings { pendingSettings = settings }
        pendingScan = pendingScan || scan
        let dispatch = !passScheduled
        passScheduled = true
        pendingLock.unlock()
        if dispatch { queue.async { self.runPass() } }
    }

    // MARK: Pass (engine queue)

    private func runPass() {
        pendingLock.lock()
        let newSettings = pendingSettings
        let scan = pendingScan
        pendingSettings = nil
        pendingScan = false
        passScheduled = false
        pendingLock.unlock()

        if let newSettings { settings = newSettings }
        if scan || apps.isEmpty { apps = Self.scanApps() }
        let error = reconcile()
        let report = Report(apps: apps, error: error, sync: syncSummary())
        DispatchQueue.main.async { self.onReport?(report) }
    }

    /// Bring the taps in line with `settings` and `apps`. Returns the last error.
    private func reconcile() -> String? {
        guard settings.authorized else {
            // Without the permission a tap returns silence while muting the app.
            dropAll()
            return nil
        }
        let present = Set(apps.map(\.id))
        engaged.formIntersection(present)
        failed = failed.filter { present.contains($0.key) }

        // In sync mode every app that plays is taken over, or it would only be heard on
        // the default output.
        var wanted: [String: AudioApp] = [:]
        for app in apps where settings.wantsTap(app.id) || engaged.contains(app.id) || (settings.syncOutputs != nil && app.isPlaying) {
            wanted[app.id] = app
        }
        for (id, tap) in taps where wanted[id] == nil {
            tap.invalidate()
            taps[id] = nil
        }
        guard !settings.outputUID.isEmpty else { return nil }

        // Same devices, new calibration: re-time running groups in place.
        if let outputs = settings.syncOutputs {
            for case let group as SyncGroup in taps.values where group.destination == settings.destination {
                group.setExtraLatencies(outputs)
            }
        }

        let destination = settings.destination
        let toBuild = wanted.filter { id, app in
            guard let tap = taps[id], tap.destination == destination else {
                return failed[id] != Set(app.processObjects)
            }
            return false
        }
        if !toBuild.isEmpty { DispatchQueue.main.async { self.onBusy?(true) } }
        defer { if !toBuild.isEmpty { DispatchQueue.main.async { self.onBusy?(false) } } }

        var lastError: String?
        for (id, app) in wanted {
            let g = settings.gain(id)
            if let tap = taps[id], tap.destination == destination {
                tap.gain = g
                if Set(tap.processObjects) != Set(app.processObjects), !tap.updateProcesses(app.processObjects) {
                    rebuild(id, app: app, gain: g, error: &lastError)
                }
            } else if toBuild[id] != nil {
                rebuild(id, app: app, gain: g, error: &lastError)
            }
        }
        return lastError
    }

    /// Make before break: the new tap is running before the old one goes, so the app
    /// never blasts at full volume in between (and switching outputs leaves no gap).
    private func rebuild(_ id: String, app: AudioApp, gain: Float, error lastError: inout String?) {
        do {
            let tap: AppTap
            if let outputs = settings.syncOutputs {
                tap = try SyncGroup(processObjects: app.processObjects, label: app.name, outputs: outputs, gain: gain)
            } else {
                tap = try ProcessTap(processObjects: app.processObjects, outputUID: settings.outputUID, gain: gain, label: app.name)
            }
            taps[id]?.invalidate()
            taps[id] = tap
            failed[id] = nil
            engaged.insert(id)
        } catch {
            taps[id]?.invalidate()
            taps[id] = nil
            failed[id] = Set(app.processObjects)
            lastError = "\(app.name): \(error.localizedDescription)"
        }
    }

    private func dropAll() {
        taps.values.forEach { $0.invalidate() }
        taps.removeAll()
        failed.removeAll()
    }

    private func syncSummary() -> SyncSummary? {
        guard let outputs = settings.syncOutputs else { return nil }
        // Every group shares the same outputs and timing; without one (nothing playing
        // yet) ask Core Audio directly.
        let group = taps.values.lazy.compactMap { $0 as? SyncGroup }.first { $0.destination == settings.destination }
        let own: [(String, Double)] = group.map { g in g.players.map { ($0.deviceUID, $0.timing.total) } }
            ?? outputs.compactMap { o in CA.deviceID(forUID: o.uid).map { (o.uid, CA.outputTiming($0, extraLatency: o.extraLatency).total) } }
        let slowest = own.map(\.1).max() ?? 0
        return SyncSummary(delay: group?.delay ?? slowest,
                           outputs: own.map { SyncSummary.Output(uid: $0.0, own: $0.1, held: slowest - $0.1) })
    }

    // MARK: Apps

    /// Apps with audio processes right now. Talks to Core Audio: call off the main thread.
    static func scanApps() -> [AudioApp] {
        let me = getpid()
        var order: [String] = []
        var byID: [String: AudioApp] = [:]

        for object in CA.processObjects() {
            let pid = CA.pid(ofProcess: object)
            guard pid > 0, pid != me, let app = owningApp(of: pid) else { continue }
            let id = app.bundleIdentifier ?? "pid.\(app.processIdentifier)"
            let playing = CA.isRunningOutput(object)
            if var existing = byID[id] {
                existing.processObjects.append(object)
                existing.isPlaying = existing.isPlaying || playing
                byID[id] = existing
            } else {
                order.append(id)
                byID[id] = AudioApp(id: id,
                                    name: app.localizedName ?? id,
                                    icon: app.icon ?? NSWorkspace.shared.icon(forFileType: "app"),
                                    processObjects: [object],
                                    isPlaying: playing)
            }
        }
        return order.compactMap { byID[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The process itself if it is a normal app, otherwise the app responsible for it
    /// (Safari for its web-content processes, Chrome for its helpers, …).
    private static func owningApp(of pid: pid_t) -> NSRunningApplication? {
        if let own = NSRunningApplication(processIdentifier: pid), own.activationPolicy == .regular {
            return own
        }
        let responsible = responsibility_get_pid_responsible_for_pid(pid)
        if responsible > 0, responsible != pid,
           let app = NSRunningApplication(processIdentifier: responsible), app.activationPolicy == .regular {
            return app
        }
        return nil
    }

    private func debugLine() -> String {
        var line = "taps=\(taps.count)"
        for (id, tap) in taps {
            if let group = tap as? SyncGroup {
                let players = group.players.map { String(format: "%@ under=%d", $0.name, $0.stats.underrunFrames) }
                line += String(format: " | %@ sync D=%.1fms gain=%.2f [%@]", id, group.delay * 1000, group.gain, players.joined(separator: ", "))
            } else if let p = tap.takePeaks() {
                line += String(format: " | %@ gain=%.2f in=%.3f out=%.3f procs=%d", id, tap.gain, p.input, p.output, tap.processObjects.count)
            }
        }
        return line
    }
}
