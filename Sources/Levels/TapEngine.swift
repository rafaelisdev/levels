import AppKit
import CoreAudio

/// Finds apps that play audio and keeps one ProcessTap per app that needs one (macOS 14.2+).
@available(macOS 14.2, *)
final class TapEngine {
    private var taps: [String: ProcessTap] = [:]
    private var failed: [String: Set<AudioObjectID>] = [:]
    /// Apps that keep their tap even when set back to 100%. Switching between the tap and
    /// the direct path is what made 99% → 100% jump, so once an app has been touched it
    /// stays on the tap (gain 1.0) until it quits or the output device changes.
    private var engaged: Set<String> = []

    var hasTaps: Bool { !taps.isEmpty }

    // MARK: Apps

    func scanApps() -> [AudioApp] {
        let me = getpid()
        var order: [String] = []
        var byID: [String: AudioApp] = [:]

        for object in CA.processObjects() {
            let pid = CA.pid(ofProcess: object)
            guard pid > 0, pid != me, let app = Self.owningApp(of: pid) else { continue }
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

    // MARK: Taps

    /// Returns the last error, if any tap could not be created.
    func reconcile(apps: [AudioApp], outputUID: String,
                   wantsTap: (String) -> Bool, gain: (String) -> Float) -> String? {
        let present = Set(apps.map(\.id))
        engaged.formIntersection(present)
        failed = failed.filter { present.contains($0.key) }

        var wanted: [String: AudioApp] = [:]
        for app in apps where wantsTap(app.id) || engaged.contains(app.id) {
            wanted[app.id] = app
        }
        for (id, tap) in taps where wanted[id] == nil {
            tap.invalidate()
            taps[id] = nil
        }
        guard !outputUID.isEmpty else { return nil }

        var lastError: String?
        for (id, app) in wanted {
            let g = gain(id)
            if let tap = taps[id], tap.outputUID == outputUID {
                tap.gain = g
                if Set(tap.processObjects) != Set(app.processObjects), !tap.updateProcesses(app.processObjects) {
                    rebuild(id, app: app, gain: g, outputUID: outputUID, error: &lastError)
                }
                continue
            }
            if let f = failed[id], f == Set(app.processObjects) { continue }
            rebuild(id, app: app, gain: g, outputUID: outputUID, error: &lastError)
        }
        return lastError
    }

    func clearFailure(_ id: String) { failed[id] = nil }

    /// Drop every tap (output device changed or permission lost). `engaged` is kept so
    /// touched apps get their tap back on the new device.
    func dropAll() {
        taps.values.forEach { $0.invalidate() }
        taps.removeAll()
        failed.removeAll()
    }

    private func rebuild(_ id: String, app: AudioApp, gain: Float, outputUID: String, error lastError: inout String?) {
        do {
            // New tap first, then drop the old one, so the app never blasts at full volume in between.
            let tap = try ProcessTap(processObjects: app.processObjects, outputUID: outputUID, gain: gain, label: app.name)
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

    func debugLine() -> String {
        var line = "taps=\(taps.count)"
        for (id, tap) in taps {
            if let p = tap.takePeaks() {
                line += String(format: " | %@ gain=%.2f in=%.3f out=%.3f procs=%d", id, tap.gain, p.input, p.output, tap.processObjects.count)
            }
        }
        return line
    }
}
