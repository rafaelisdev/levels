import CoreAudio
import Foundation

/// Takes over the audio of one app's processes and plays it back with a gain.
///
/// How it works: a Core Audio process tap captures the app's output and mutes the
/// original (`.mutedWhenTapped`). A private aggregate device made of the current
/// output device + the tap runs an IO block that copies the tapped audio to the
/// output, multiplied by `gain`. If anything stops, the tap stops being read and
/// macOS unmutes the app by itself, so a failure never leaves an app silent.
@available(macOS 14.2, *)
final class ProcessTap: AppTap {
    var outputUID: String { session.clockDeviceUID }
    var destination: String { outputUID }
    var processObjects: [AudioObjectID] { session.processObjects }

    private var session: TapSession!
    private let gainStorage: UnsafeMutablePointer<Float>
    /// Debug only (--debug): peak of tapped input and of our output since last read.
    private let meter: UnsafeMutablePointer<Float>?

    /// Linear amplitude, 0...1. Read from the real-time thread without locks
    /// (a single aligned Float store/load), ramped there to avoid clicks.
    var gain: Float {
        get { gainStorage.pointee }
        set { gainStorage.pointee = min(max(newValue, 0), 1) }
    }

    init(processObjects: [AudioObjectID], outputUID: String, gain: Float, label: String) throws {
        gainStorage = .allocate(capacity: 1)
        gainStorage.initialize(to: min(max(gain, 0), 1))
        meter = DebugFlags.debug ? .allocate(capacity: 2) : nil
        meter?.initialize(repeating: 0, count: 2)

        // Every stored property is set by now, so if TapSession throws, deinit runs and
        // frees the storage: nothing to clean up here.
        let gainPointer = UnsafePointer(gainStorage)
        let meter = self.meter
        session = try TapSession(processObjects: processObjects, clockDeviceUID: outputUID, label: label) { format in
            var current = gainPointer.pointee
            return { _, input, _, output, _ in
                let target = gainPointer.pointee
                GainRenderer.render(input: input, output: output, tapChannels: format.channels, from: current, to: target)
                current = target
                if let meter {
                    meter[0] = max(meter[0], GainRenderer.peak(UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))))
                    meter[1] = max(meter[1], GainRenderer.peak(UnsafeMutableAudioBufferListPointer(output)))
                }
            }
        }
    }

    deinit {
        session?.invalidate()
        gainStorage.deallocate()
        meter?.deallocate()
    }

    func takePeaks() -> (input: Float, output: Float)? {
        guard let meter else { return nil }
        defer { meter[0] = 0; meter[1] = 0 }
        return (meter[0], meter[1])
    }

    /// Swap the set of processes without tearing the tap down. Returns false if Core
    /// Audio refused; the caller then rebuilds.
    func updateProcesses(_ objects: [AudioObjectID]) -> Bool {
        session.updateProcesses(objects)
    }

    func invalidate() {
        session.invalidate()
    }
}

/// Real-time safe copy: tap → output with a linear gain ramp. No allocations, no locks.
enum GainRenderer {
    static func render(input: UnsafePointer<AudioBufferList>,
                       output: UnsafeMutablePointer<AudioBufferList>,
                       tapChannels: Int,
                       from g0: Float, to g1: Float) {
        let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outs = UnsafeMutableAudioBufferListPointer(output)

        let (offset, tapCount) = BufferChannels.tapRange(ins, tapChannels: tapChannels)

        var frames = Int.max
        if tapCount > 0 {
            for c in 0..<tapCount {
                if let ch = BufferChannels.channel(ins, offset + c) { frames = min(frames, ch.frames) }
            }
        }

        let totalOut = BufferChannels.count(outs)

        var outBase = 0
        for ob in outs {
            let oc = Int(ob.mNumberChannels)
            defer { outBase += oc }
            guard let raw = ob.mData else { continue }
            memset(raw, 0, Int(ob.mDataByteSize))
            guard oc > 0, tapCount > 0, frames != .max else { continue }

            let dst = raw.assumingMemoryBound(to: Float.self)
            let n = min(frames, Int(ob.mDataByteSize) / (MemoryLayout<Float>.size * oc))
            guard n > 0 else { continue }
            let step = (g1 - g0) / Float(n)

            for c in 0..<oc {
                let global = outBase + c
                if totalOut == 1 && tapCount >= 2 {
                    // Mono output: fold L+R.
                    guard let l = BufferChannels.channel(ins, offset), let r = BufferChannels.channel(ins, offset + 1) else { continue }
                    var g = g0
                    for f in 0..<n {
                        dst[f * oc + c] = 0.5 * (l.data[f * l.stride] + r.data[f * r.stride]) * g
                        g += step
                    }
                    continue
                }
                let source: Int
                if global < tapCount { source = global }
                else if tapCount == 1 && global < 2 { source = 0 }
                else { continue } // extra surround channels stay silent
                guard let s = BufferChannels.channel(ins, offset + source) else { continue }
                var g = g0
                for f in 0..<n {
                    dst[f * oc + c] = s.data[f * s.stride] * g
                    g += step
                }
            }
        }
    }

    static func peak(_ list: UnsafeMutableAudioBufferListPointer) -> Float {
        var p: Float = 0
        for b in list {
            guard let d = b.mData else { continue }
            let samples = d.assumingMemoryBound(to: Float.self)
            for i in 0..<(Int(b.mDataByteSize) / MemoryLayout<Float>.size) { p = max(p, abs(samples[i])) }
        }
        return p
    }
}
