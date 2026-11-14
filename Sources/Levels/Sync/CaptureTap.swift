import CoreAudio
import LevelsCore

/// Captures one app's audio into a `TimedRingBuffer`, stamped with host time, so
/// `OutputPlayer`s can play it on several devices in sync. The app's gain is applied
/// here, once, before the audio is shared.
@available(macOS 14.2, *)
final class CaptureTap {
    struct Stats {
        var framesWritten: Int64 = 0
        var ratePPM: Double = 0      // how far the capture clock runs from nominal
    }

    let buffer: TimedRingBuffer
    private var session: TapSession!
    private let gainStorage: UnsafeMutablePointer<Float>
    private let statsStorage: UnsafeMutablePointer<Stats>

    var gain: Float {
        get { gainStorage.pointee }
        set { gainStorage.pointee = min(max(newValue, 0), 1) }
    }
    var stats: Stats { statsStorage.pointee }
    var processObjects: [AudioObjectID] { session.processObjects }
    /// Seconds from a frame being captured until it is in the buffer.
    var latency: Double { session.inputLatency }

    /// - Parameter clockDeviceUID: one of the outputs; the capture runs on its clock.
    init(processObjects: [AudioObjectID], clockDeviceUID: String, gain: Float, label: String,
         buffer: TimedRingBuffer) throws {
        self.buffer = buffer
        gainStorage = .allocate(capacity: 1)
        gainStorage.initialize(to: min(max(gain, 0), 1))
        statsStorage = .allocate(capacity: 1)
        statsStorage.initialize(to: Stats())

        // Every stored property is set by now, so if TapSession throws, deinit runs and
        // frees the storage: nothing to clean up here.
        let gainPointer = UnsafePointer(gainStorage)
        let statsPointer = statsStorage
        session = try TapSession(processObjects: processObjects, clockDeviceUID: clockDeviceUID, label: label) { format in
            Self.makeIOBlock(buffer: buffer, format: format, gain: gainPointer, stats: statsPointer)
        }
    }

    deinit {
        session?.invalidate()
        gainStorage.deallocate()
        statsStorage.deallocate()
    }

    func updateProcesses(_ objects: [AudioObjectID]) -> Bool { session.updateProcesses(objects) }
    func invalidate() { session.invalidate() }

    /// Real-time block: tap -> gain -> ring buffer, and the capture clock with it.
    private static func makeIOBlock(buffer: TimedRingBuffer, format: TapFormat,
                                    gain: UnsafePointer<Float>, stats: UnsafeMutablePointer<Stats>) -> AudioDeviceIOBlock {
        var clock = ClockFilter(nominalRate: format.sampleRate)
        var currentGain = gain.pointee
        return { _, input, inputTime, output, _ in
            // The aggregate also drives its clock device; this capture plays nothing there.
            BufferChannels.silence(UnsafeMutableAudioBufferListPointer(output))

            let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            let tap = BufferChannels.tapRange(inputs, tapChannels: format.channels)
            guard tap.count > 0, let left = BufferChannels.channel(inputs, tap.offset) else { return }
            let right = tap.count > 1 ? (BufferChannels.channel(inputs, tap.offset + 1) ?? left) : left
            let frames = min(left.frames, right.frames)
            let start = buffer.nextWritePosition

            if inputTime.pointee.mFlags.contains(.hostTimeValid) {
                clock.update(frame: Double(start), time: HostClock.seconds(fromTicks: inputTime.pointee.mHostTime))
            }

            let target = gain.pointee
            let step = (target - currentGain) / Float(max(frames, 1))
            var g = currentGain
            for f in 0..<frames {
                let frame = start + Int64(f)
                buffer.store(left.data[f * left.stride] * g, frame: frame, channel: 0)
                buffer.store(right.data[f * right.stride] * g, frame: frame, channel: 1)
                g += step
            }
            currentGain = target
            buffer.advance(by: frames)
            buffer.publish(clock: clock.line)

            stats.pointee.framesWritten = buffer.nextWritePosition
            if let line = clock.line { stats.pointee.ratePPM = (clock.nominalPeriod / line.period - 1) * 1e6 }
        }
    }
}
