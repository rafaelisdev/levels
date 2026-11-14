import AppKit
import LevelsCore

/// Debug harness for multi-output sync (`--sync <bundle id> [--sync-outputs uid,uid]`):
/// plays one app on several outputs and prints what every part of the pipeline sees.
@available(macOS 14.2, *)
enum SyncProbe {
    private static var group: SyncGroup?
    private static var timer: Timer?

    static func start(appID: String, outputUIDs: [String]?) {
        let devices = CA.outputDevices()
        for d in devices {
            let t = CA.outputTiming(d.id)
            log(String(format: "output %@ [%@] io=%.1f ms device=%.1f ms", d.name, d.uid, t.ioLatency * 1000, t.deviceLatency * 1000))
        }
        guard let app = TapEngine.scanApps().first(where: { $0.id == appID }) else {
            log("sync: \(appID) has no audio processes yet; start it first")
            return
        }
        let uids = outputUIDs ?? devices.map(\.uid)
        do {
            let g = try SyncGroup(processObjects: app.processObjects, label: app.name,
                                  outputs: uids.map { SyncGroup.Output(uid: $0) }, gain: 1)
            group = g
            log(String(format: "sync: %@ on %d outputs, playout delay %.1f ms, capture latency %.1f ms",
                       app.name, g.players.count, g.delay * 1000, g.capture.latency * 1000))
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in report(g) }
        } catch {
            log("sync: \(error.localizedDescription)")
        }
    }

    private static func report(_ g: SyncGroup) {
        var line = String(format: "sync D=%.1fms capture %+.1fppm frames=%lld", g.delay * 1000, g.capture.stats.ratePPM, g.capture.stats.framesWritten)
        for p in g.players {
            let s = p.stats
            line += String(format: " | %@ io=%.1fms ppm=%+.1f under=%d head=%.1fms",
                           p.name, s.ioLatency * 1000, s.ratePPM, s.underrunFrames, s.headroom * 1000)
        }
        log(line)
    }

    private static func log(_ text: String) {
        print(text)
        fflush(stdout)
    }
}
