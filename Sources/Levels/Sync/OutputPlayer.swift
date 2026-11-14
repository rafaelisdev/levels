import CoreAudio
import LevelsCore

/// Plays a `TimedRingBuffer` on one output device so that every frame is heard at
/// its capture time + the group's playout delay.
///
/// Each player runs on its own device's IO thread and clock. It never pushes data:
/// on every cycle it asks "which capture time belongs to the frames my hardware will
/// consume next?" and reads them at a fractional position, which absorbs both the
/// fixed offset between devices and their clock drift.
@available(macOS 14.2, *)
final class OutputPlayer {
    struct Stats {
        var underrunFrames = 0
        var ioLatency = 0.0      // measured: callback -> hardware, seconds
        var ratePPM = 0.0        // this device's clock vs nominal
        var headroom = 0.0       // newest captured audio minus what we read, seconds
    }

    let deviceUID: String
    let name: String

    private let deviceID: AudioObjectID
    private let baseTiming: OutputTiming
    private var ioProcID: AudioDeviceIOProcID?
    private let control: UnsafeMutablePointer<Control>
    private let statsStorage: UnsafeMutablePointer<Stats>

    /// Written on the main thread, read on the IO thread (aligned word-size values).
    private struct Control {
        var delay: Double
        var gain: Float
        var extraLatency: Double
        var channel: Int = -1   // -1 stereo, 0/1: play that source channel on every speaker
    }

    var delay: Double {
        get { control.pointee.delay }
        set { control.pointee.delay = newValue }
    }
    var gain: Float {
        get { control.pointee.gain }
        set { control.pointee.gain = min(max(newValue, 0), 1) }
    }
    /// Latency Core Audio doesn't know about; changing it moves this output in time.
    var extraLatency: Double {
        get { control.pointee.extraLatency }
        set { control.pointee.extraLatency = newValue }
    }
    /// nil: normal stereo. 0 or 1: this output plays only that source channel, on all of
    /// its speakers (used to give each output its own test signal).
    var sourceChannel: Int? {
        get { control.pointee.channel < 0 ? nil : control.pointee.channel }
        set { control.pointee.channel = newValue.map { min(max($0, 0), 1) } ?? -1 }
    }
    var timing: OutputTiming {
        var t = baseTiming
        t.extraLatency = extraLatency
        return t
    }
    var stats: Stats { statsStorage.pointee }

    init(deviceUID: String, buffer: TimedRingBuffer, timing: OutputTiming, delay: Double, gain: Float = 1) throws {
        guard let id = CA.deviceID(forUID: deviceUID) else {
            throw CoreAudioError(step: "find the output device", status: OSStatus(kAudioHardwareBadDeviceError))
        }
        deviceID = id
        self.deviceUID = deviceUID
        name = CA.deviceName(id)
        baseTiming = timing
        control = .allocate(capacity: 1)
        control.initialize(to: Control(delay: delay, gain: min(max(gain, 0), 1), extraLatency: timing.extraLatency))
        statsStorage = .allocate(capacity: 1)
        statsStorage.initialize(to: Stats())

        // Every stored property is set by now, so a throw below runs deinit, which stops
        // the IO proc and frees the storage.
        let block = Self.makeIOBlock(buffer: buffer, timing: timing, rate: CA.nominalSampleRate(id),
                                     control: UnsafePointer(control), stats: statsStorage)
        var procID: AudioDeviceIOProcID?
        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, id, nil, block), "start audio processing")
        ioProcID = procID
        try check(AudioDeviceStart(id, procID), "start the output")
    }

    deinit {
        invalidate()
        control.deallocate()
        statsStorage.deallocate()
    }

    func invalidate() {
        guard let ioProcID else { return }
        AudioDeviceStop(deviceID, ioProcID)
        AudioDeviceDestroyIOProcID(deviceID, ioProcID)
        self.ioProcID = nil
    }

    private static func makeIOBlock(buffer: TimedRingBuffer, timing: OutputTiming, rate: Double,
                                    control: UnsafePointer<Control>, stats: UnsafeMutablePointer<Stats>) -> AudioDeviceIOBlock {
        var deviceClock = ClockFilter(nominalRate: rate)
        var snapshot = TimedRingBuffer.Snapshot()
        var currentGain = control.pointee.gain
        // What decides where this output reads: its after-hardware latency minus the
        // shared delay. When it moves, the read position jumps.
        var lastShift = timing.afterHardware - control.pointee.delay

        return { now, _, _, output, outputTime in
            let outputs = UnsafeMutableAudioBufferListPointer(output)
            BufferChannels.silence(outputs)

            let time = outputTime.pointee
            guard time.mFlags.contains([.sampleTimeValid, .hostTimeValid]),
                  let left = BufferChannels.channel(outputs, 0) else { return }
            let present = HostClock.seconds(fromTicks: time.mHostTime)
            deviceClock.update(frame: time.mSampleTime, time: present)
            guard let device = deviceClock.line else { return }

            stats.pointee.ioLatency = present - HostClock.seconds(fromTicks: now.pointee.mHostTime)
            stats.pointee.ratePPM = (deviceClock.nominalPeriod / device.period - 1) * 1e6

            let frames = left.frames
            buffer.read(into: &snapshot)
            guard let capture = snapshot.clock, let range = buffer.readableRange(for: snapshot) else {
                stats.pointee.underrunFrames += frames
                return
            }

            // Capture time of the first frame, then one capture step per output frame.
            let settings = control.pointee
            var current = timing
            current.extraLatency = settings.extraLatency
            var delay = settings.delay
            var targetGain = settings.gain
            let shift = current.afterHardware - settings.delay
            if abs(shift - lastShift) > 0.0005 {
                // The timing moved (an output added or removed, a calibration change).
                // Finish this buffer on the old timing, fading out; the next one starts
                // on the new timing and fades in through the normal gain ramp. A short
                // dip instead of a click.
                delay = current.afterHardware - lastShift
                targetGain = 0
                lastShift = shift
            }
            let source = Playout.sourceTime(presentTime: device.time(atFrame: time.mSampleTime),
                                            output: current, delay: delay)
            var position = capture.frame(atTime: source)
            let step = device.period / capture.period
            stats.pointee.headroom = (Double(range.upperBound) - position) * capture.period

            let right = BufferChannels.channel(outputs, 1)
            let mono = BufferChannels.count(outputs) == 1
            let gainStep = (targetGain - currentGain) / Float(max(frames, 1))
            var g = currentGain
            let leftSource = settings.channel < 0 ? 0 : settings.channel
            let rightSource = settings.channel < 0 ? 1 : settings.channel
            for f in 0..<frames {
                if let l = buffer.sample(at: position, channel: leftSource, in: range),
                   let r = buffer.sample(at: position, channel: rightSource, in: range) {
                    if mono {
                        left.data[f * left.stride] = 0.5 * (l + r) * g
                    } else {
                        left.data[f * left.stride] = l * g
                        if let right { right.data[f * right.stride] = r * g }
                    }
                } else {
                    stats.pointee.underrunFrames += 1
                }
                position += step
                g += gainStep
            }
            currentGain = targetGain
        }
    }
}
