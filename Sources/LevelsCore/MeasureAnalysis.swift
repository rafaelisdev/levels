import Foundation

/// A microphone recording of a sync measurement, plus what was played when. Saved by
/// the live measurement so the analysis can be re-run (and improved) offline, without
/// the microphone.
public struct MeasureRecording: Codable {
    public struct Phase: Codable {
        public var name: String
        public var gains: [Float]          // per output; >0 = playing
        public var start: Double           // first chirp, seconds into the signal
        public var delay: Double           // playout delay in force while it played
        public var joint: Bool { gains.count > 1 && gains.allSatisfy { $0 > 0 } }

        public init(name: String, gains: [Float], start: Double = 0, delay: Double = 0) {
            self.name = name
            self.gains = gains
            self.start = start
            self.delay = delay
        }
    }

    public struct ChirpSpec: Codable {
        public var duration: Double, from: Double, to: Double, amplitude: Float
        public init(duration: Double, from: Double, to: Double, amplitude: Float) {
            self.duration = duration; self.from = from; self.to = to; self.amplitude = amplitude
        }
        public func samples(rate: Double) -> [Float] {
            Chirp.make(rate: rate, duration: duration, from: from, to: to, amplitude: amplitude)
        }
        /// The band this chirp occupies, slightly widened.
        public var band: (low: Double, high: Double) { (min(from, to) * 0.8, max(from, to) * 1.15) }
    }

    public var rate: Double
    /// What the microphone says its own latency is. Often wrong; only relative results
    /// (output vs reference output) are trusted.
    public var micLatency: Double
    public var clickInterval: Double
    public var clicksPerPhase: Int
    public var outputNames: [String]
    public var chirps: [ChirpSpec]         // one per output
    public var reference: Int              // built-in/wired output used as time zero
    public var phases: [Phase]

    public init(rate: Double, micLatency: Double, clickInterval: Double, clicksPerPhase: Int,
                outputNames: [String], chirps: [ChirpSpec], reference: Int, phases: [Phase]) {
        self.rate = rate; self.micLatency = micLatency; self.clickInterval = clickInterval
        self.clicksPerPhase = clicksPerPhase; self.outputNames = outputNames; self.chirps = chirps
        self.reference = reference; self.phases = phases
    }

    /// Signal frame where chirp `click` of `phase` starts.
    public func chirpStart(_ phase: Phase, _ click: Int) -> Int {
        Int((phase.start + Double(click) * clickInterval) * rate)
    }
}

/// Times each output's chirps in a `MeasureRecording`.
///
/// Outputs play chirps in separate frequency bands. Each output is timed on the
/// recording filtered to its own band (zero-phase, so no time shift): a loud nearby
/// output then cannot mask or bias a quiet distant one.
public struct MeasureAnalysis {
    public struct Arrival: Equatable {
        public var error: Double   // seconds later than "played + playout delay"
        public var score: Float
    }

    public let recording: MeasureRecording
    private let templates: [[Float]]
    private let bands: [[Float]]        // the recording filtered to each output's band

    public init(recording: MeasureRecording, samples: [Float]) {
        self.recording = recording
        templates = recording.chirps.map { $0.samples(rate: recording.rate) }
        bands = recording.chirps.map { BandPass.apply(samples, low: $0.band.low, high: $0.band.high, rate: recording.rate) }
    }

    /// Arrival of `output`'s chirp for every click of `phase`. Searched within
    /// `around ± tolerance` when given (seconds of error), otherwise -30...+400 ms.
    public func arrivals(_ phase: MeasureRecording.Phase, output: Int, around: Double? = nil,
                         tolerance: Double = 0, threshold: Float = 0.25) -> [Arrival?] {
        let rate = recording.rate
        return (0..<recording.clicksPerPhase).map { click in
            let at = recording.chirpStart(phase, click)
            let expected = at + Int((phase.delay + recording.micLatency) * rate)
            let window = around.map { e in
                (expected + Int((e - tolerance) * rate))..<(expected + Int((e + tolerance) * rate) + 1)
            } ?? (expected - Int(0.03 * rate))..<(expected + Int(0.4 * rate))
            return Correlation.peaks(in: bands[output], template: templates[output], range: window, count: 1,
                                     separation: Int(0.0005 * rate), threshold: threshold).first.map {
                Arrival(error: ($0.position - Double(at)) / rate - recording.micLatency - phase.delay, score: $0.score)
            }
        }
    }

    /// Per output, median lateness in its solo phase (phase index = output index).
    public func soloErrors() -> [Double?] {
        recording.outputNames.indices.map { i in
            guard recording.phases.indices.contains(i), !recording.phases[i].joint else { return nil }
            return median(arrivals(recording.phases[i], output: i).compactMap { $0?.error })
        }
    }

    /// Human-readable summary: solo timings, the corrections they imply, and how far
    /// apart the outputs landed when playing together.
    public func report(jointTolerance: Double = 0.010, jointThreshold: Float = 0.25) -> [String] {
        var lines: [String] = []
        let solo = soloErrors()
        for (i, phase) in recording.phases.enumerated() where !phase.joint && i < templates.count {
            let found = arrivals(phase, output: i)
            lines.append("\(phase.name): " + found.map(format).joined(separator: "  "))
        }
        guard recording.reference < solo.count, let anchor = solo[recording.reference] else {
            lines.append("reference output not heard alone")
            return lines
        }
        for (i, error) in solo.enumerated() {
            let correction = error.map { String(format: "%+.1f ms", ($0 - anchor) * 1000) } ?? "not heard"
            lines.append("correction for \(recording.outputNames[i]): \(correction)")
        }
        for phase in recording.phases where phase.joint {
            let perOutput = templates.indices.map {
                arrivals(phase, output: $0, around: anchor, tolerance: jointTolerance, threshold: jointThreshold)
            }
            var spreads: [Double] = []
            let clicks = (0..<recording.clicksPerPhase).map { click -> String in
                let values = perOutput.map { $0[click] }
                let heard = values.compactMap { $0?.error }
                if heard.count == values.count, let lo = heard.min(), let hi = heard.max() { spreads.append(hi - lo) }
                return values.map(format).joined(separator: " / ")
            }
            let spread = median(spreads).map { String(format: "%.2f ms", $0 * 1000) } ?? "n/a"
            lines.append("\(phase.name) (delay \(String(format: "%.1f", phase.delay * 1000)) ms): "
                         + clicks.joined(separator: "  ") + ", spread \(spread)")
        }
        return lines
    }

    private func format(_ a: Arrival?) -> String {
        a.map { String(format: "%+.1f ms (%.2f)", $0.error * 1000, $0.score) } ?? "?"
    }
}

public func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let s = values.sorted()
    return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
}
