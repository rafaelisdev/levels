/// How long one output takes from its IO callback until the sound is in the air.
public struct OutputTiming: Equatable {
    /// Callback -> hardware for the first frame of a buffer: the device buffer plus its
    /// safety offset. Known exactly from Core Audio timestamps.
    public var ioLatency: Double
    /// One callback asks for a whole buffer, so its last frame is needed this much
    /// later than the first.
    public var bufferDuration: Double
    /// Hardware -> sound: converter and DSP latency reported by the device (for
    /// Bluetooth this includes the headphones' own A2DP delay report, if they send one).
    public var deviceLatency: Double
    /// What Core Audio does not know: a TV's processing (from EDID when it declares
    /// it) and the user's calibration for this device.
    public var extraLatency: Double

    public init(ioLatency: Double, bufferDuration: Double, deviceLatency: Double, extraLatency: Double = 0) {
        self.ioLatency = ioLatency
        self.bufferDuration = bufferDuration
        self.deviceLatency = deviceLatency
        self.extraLatency = extraLatency
    }

    /// How far ahead of "now" this output needs captured audio: up to the last frame of
    /// its next buffer, plus everything after the hardware.
    public var total: Double { ioLatency + bufferDuration + deviceLatency + extraLatency }
    /// The part after the sample has been handed to the hardware.
    public var afterHardware: Double { deviceLatency + extraLatency }
}

/// The shared timeline: a sample captured at host time `t` is heard on every output
/// at `t + delay`.
public enum Playout {
    /// Smallest common delay that every output can honour: the slowest path, plus the
    /// capture side's own latency and a safety margin for scheduling jitter.
    public static func delay(outputs: [OutputTiming], captureLatency: Double, margin: Double) -> Double {
        (outputs.map(\.total).max() ?? 0) + captureLatency + margin
    }

    /// For an output frame the hardware will consume at `presentTime`, the capture
    /// time of the source sample that belongs there.
    public static func sourceTime(presentTime: Double, output: OutputTiming, delay: Double) -> Double {
        presentTime + output.afterHardware - delay
    }
}
