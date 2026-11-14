import Darwin

/// Host time in seconds (`mach_absolute_time`, the clock Core Audio stamps buffers with).
public enum HostClock {
    private static let secondsPerTick: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()

    public static func seconds(fromTicks ticks: UInt64) -> Double { Double(ticks) * secondsPerTick }
    public static var now: Double { seconds(fromTicks: mach_absolute_time()) }
}

/// A straight-line map between a device's frame counter and host time.
public struct ClockLine: Equatable {
    public var frame: Double   // anchor frame
    public var time: Double    // host seconds at `frame`
    public var period: Double  // seconds per frame (1 / actual sample rate)

    public init(frame: Double, time: Double, period: Double) {
        self.frame = frame
        self.time = time
        self.period = period
    }

    public func time(atFrame f: Double) -> Double { time + (f - frame) * period }
    public func frame(atTime t: Double) -> Double { frame + (t - time) / period }
}

/// Turns noisy (frame, host time) readings into a smooth `ClockLine` with a
/// second-order delay-locked loop (F. Adriaensen, "Using a DLL to filter time", 2005).
///
/// Every device runs on its own crystal, a few tens of ppm off nominal. The filter
/// tracks that real rate, so a timeline built on it does not drift, while callback
/// jitter (scheduling noise of about a millisecond) is averaged away.
public struct ClockFilter {
    public private(set) var line: ClockLine?
    public let nominalPeriod: Double

    private let bandwidth: Double      // loop bandwidth in Hz once locked
    private let maxError: Double       // larger jumps are a discontinuity, not jitter
    private var updates = 0

    private static let lockingUpdates = 50       // wide loop for the first updates
    private static let maxDeviation = 1e-3       // never believe a rate further than 1000 ppm off

    public init(nominalRate: Double, bandwidth: Double = 0.2, maxError: Double = 0.02) {
        nominalPeriod = 1 / nominalRate
        self.bandwidth = bandwidth
        self.maxError = maxError
    }

    public mutating func reset() {
        line = nil
        updates = 0
    }

    public mutating func update(frame: Double, time: Double) {
        guard var current = line else {
            line = ClockLine(frame: frame, time: time, period: nominalPeriod)
            updates = 1
            return
        }
        let steps = frame - current.frame
        guard steps > 0 else { return }   // repeated or out-of-order reading

        let predicted = current.time(atFrame: frame)
        let error = time - predicted
        if abs(error) > maxError {
            // The device restarted or skipped: re-anchor, keep the learned rate.
            line = ClockLine(frame: frame, time: time, period: current.period)
            updates = 1
            return
        }

        // Lock quickly with a wide loop, then narrow it to reject jitter.
        let hz = updates < Self.lockingUpdates ? bandwidth * 10 : bandwidth
        let omega = min(2 * .pi * hz * steps * current.period, 0.5)
        current.time = predicted + 2.squareRoot() * omega * error
        current.frame = frame
        current.period += omega * omega * error / steps
        current.period = min(max(current.period, nominalPeriod * (1 - Self.maxDeviation)),
                             nominalPeriod * (1 + Self.maxDeviation))
        line = current
        updates += 1
    }
}
