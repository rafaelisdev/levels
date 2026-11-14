import CoreAudio
import LevelsCore

/// One app playing on several outputs at once, in sync: everything captured at host
/// time `t` is heard on every output at `t + delay`.
@available(macOS 14.2, *)
final class SyncGroup: AppTap {
    struct Output: Equatable {
        let uid: String
        /// Latency Core Audio doesn't know about (TV processing, user calibration).
        var extraLatency: Double = 0
    }

    /// Room for about 2.7 s at 48 kHz: the slowest supported output plus headroom.
    private static let bufferFrames = 1 << 17
    /// Allowance for scheduling jitter between capture and the slowest output.
    private static let margin = 0.005

    let buffer: TimedRingBuffer
    let outputs: [Output]
    private(set) var capture: CaptureTap!
    private(set) var players: [OutputPlayer] = []
    private(set) var delay: Double = 0

    static func destination(_ outputs: [Output]) -> String { outputs.map(\.uid).joined(separator: "+") }
    var destination: String { Self.destination(outputs) }
    var gain: Float {
        get { capture.gain }
        set { capture.gain = newValue }
    }
    var processObjects: [AudioObjectID] { capture.processObjects }

    /// - Parameter outputs: the first output also clocks the capture.
    init(processObjects: [AudioObjectID], label: String, outputs: [Output], gain: Float) throws {
        precondition(!outputs.isEmpty, "a sync group needs at least one output")
        self.outputs = outputs
        buffer = TimedRingBuffer(capacityFrames: Self.bufferFrames)
        do {
            capture = try CaptureTap(processObjects: processObjects, clockDeviceUID: outputs[0].uid,
                                     gain: gain, label: label, buffer: buffer)
            let timings = try outputs.map { output -> OutputTiming in
                guard let id = CA.deviceID(forUID: output.uid) else {
                    throw CoreAudioError(step: "find the output device", status: OSStatus(kAudioHardwareBadDeviceError))
                }
                return CA.outputTiming(id, extraLatency: output.extraLatency)
            }
            delay = Playout.delay(outputs: timings, captureLatency: capture.latency, margin: Self.margin)
            players = try zip(outputs, timings).map { output, timing in
                try OutputPlayer(deviceUID: output.uid, buffer: buffer, timing: timing, delay: delay)
            }
        } catch {
            invalidate()
            throw error
        }
    }

    deinit { invalidate() }

    func updateProcesses(_ objects: [AudioObjectID]) -> Bool { capture.updateProcesses(objects) }
    func takePeaks() -> (input: Float, output: Float)? { nil }

    /// New calibration offsets for the same devices: move each output, then re-time the
    /// group around the (possibly new) slowest one.
    func setExtraLatencies(_ outputs: [Output]) {
        for output in outputs {
            players.first { $0.deviceUID == output.uid }?.extraLatency = output.extraLatency
        }
        delay = Playout.delay(outputs: players.map(\.timing), captureLatency: capture.latency, margin: Self.margin)
        players.forEach { $0.delay = delay }
    }

    func invalidate() {
        players.forEach { $0.invalidate() }
        capture?.invalidate()
    }
}
