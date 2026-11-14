import Foundation

/// Test signals and arrival-time detection for measuring how late each output plays.
public enum Chirp {
    /// Linear sweep from `f0` to `f1` under a Hann window. Short and wideband, so its
    /// autocorrelation is one sharp peak: good for timing, gentle on the ear.
    public static func make(rate: Double, duration: Double, from f0: Double, to f1: Double, amplitude: Float) -> [Float] {
        let n = max(Int(duration * rate), 2)
        let sweep = (f1 - f0) / duration
        return (0..<n).map { i in
            let t = Double(i) / rate
            let window = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(n - 1))
            return amplitude * Float(window * sin(2 * .pi * (f0 * t + 0.5 * sweep * t * t)))
        }
    }
}

public struct CorrelationPeak: Equatable {
    /// Sample index where the template starts, refined below one sample.
    public var position: Double
    /// Normalised correlation, 1 = identical shape.
    public var score: Float
}

public enum Correlation {
    /// Where `template` occurs in `signal` within `range` (start positions): up to `count`
    /// strongest peaks at least `separation` samples apart, strongest first, ignoring
    /// anything below `threshold`. Scores are normalised by the local signal energy, so a
    /// quiet speaker scores as well as a loud one.
    public static func peaks(in signal: [Float], template: [Float], range: Range<Int>,
                             count: Int, separation: Int, threshold: Float = 0.3) -> [CorrelationPeak] {
        let m = template.count
        let lower = max(range.lowerBound, 0)
        let upper = min(range.upperBound, signal.count - m)
        guard m > 0, upper - lower > 2 else { return [] }

        let templateEnergy = template.reduce(0.0) { $0 + Double($1) * Double($1) }
        // Windows a million times (60 dB) weaker than the template are silence, not a match.
        let silence = templateEnergy * 1e-6
        var scores = [Float](repeating: 0, count: upper - lower)
        signal.withUnsafeBufferPointer { s in
            template.withUnsafeBufferPointer { t in
                func windowEnergy(_ k: Int) -> Double {
                    var e = 0.0
                    for i in 0..<m { e += Double(s[k + i]) * Double(s[k + i]) }
                    return e
                }
                // Running energy of the window under the template, in Double and re-summed
                // exactly every 1024 steps: a Float running sum drifts to zero over quiet,
                // filtered stretches and makes scores explode.
                var energy = windowEnergy(lower)
                for k in lower..<upper {
                    if k > lower {
                        if (k - lower) % 1024 == 0 {
                            energy = windowEnergy(k)
                        } else {
                            let out = Double(s[k - 1]), into = Double(s[k + m - 1])
                            energy += into * into - out * out
                        }
                    }
                    guard energy > silence else { continue }
                    var dot = 0.0
                    for i in 0..<m { dot += Double(t[i]) * Double(s[k + i]) }
                    scores[k - lower] = Float(dot / (templateEnergy * energy).squareRoot())
                }
            }
        }

        // Local maxima above the threshold, strongest first, kept apart by `separation`.
        var candidates: [(index: Int, score: Float)] = []
        for i in 1..<(scores.count - 1) where scores[i] >= threshold && scores[i] >= scores[i - 1] && scores[i] > scores[i + 1] {
            candidates.append((i, scores[i]))
        }
        candidates.sort { $0.score > $1.score }
        var picked: [CorrelationPeak] = []
        for c in candidates where picked.count < count {
            let position = Double(lower + c.index) + parabolicOffset(scores, c.index)
            if picked.allSatisfy({ abs($0.position - position) >= Double(separation) }) {
                picked.append(CorrelationPeak(position: position, score: c.score))
            }
        }
        return picked
    }

    /// Sub-sample position of a peak from its two neighbours.
    private static func parabolicOffset(_ y: [Float], _ i: Int) -> Double {
        let a = y[i - 1], b = y[i], c = y[i + 1]
        let denominator = a - 2 * b + c
        guard denominator != 0 else { return 0 }
        return Double(0.5 * (a - c) / denominator)
    }
}

/// Zero-phase band-pass: 4th-order Butterworth-style high- and low-pass sections, run
/// forward then backward so the result is not shifted in time at all (which matters:
/// this feeds arrival-time measurements).
public enum BandPass {
    public static func apply(_ signal: [Float], low: Double, high: Double, rate: Double) -> [Float] {
        var x = signal.map(Double.init)
        let sections = [Biquad.highPass(low, rate), Biquad.highPass(low, rate),
                        Biquad.lowPass(high, rate), Biquad.lowPass(high, rate)]
        for section in sections { section.run(&x) }
        x.reverse()
        for section in sections { section.run(&x) }
        x.reverse()
        return x.map(Float.init)
    }

    /// Second-order section (RBJ cookbook, Q = 1/sqrt(2)).
    private struct Biquad {
        let b0, b1, b2, a1, a2: Double

        static func lowPass(_ f: Double, _ rate: Double) -> Biquad {
            let (c, alpha) = trig(f, rate)
            return normalised(b: [(1 - c) / 2, 1 - c, (1 - c) / 2], a: [1 + alpha, -2 * c, 1 - alpha])
        }

        static func highPass(_ f: Double, _ rate: Double) -> Biquad {
            let (c, alpha) = trig(f, rate)
            return normalised(b: [(1 + c) / 2, -(1 + c), (1 + c) / 2], a: [1 + alpha, -2 * c, 1 - alpha])
        }

        private static func trig(_ f: Double, _ rate: Double) -> (cos: Double, alpha: Double) {
            let w = 2 * Double.pi * f / rate
            return (cos(w), sin(w) / (2 * 0.5.squareRoot()))
        }

        private static func normalised(b: [Double], a: [Double]) -> Biquad {
            Biquad(b0: b[0] / a[0], b1: b[1] / a[0], b2: b[2] / a[0], a1: a[1] / a[0], a2: a[2] / a[0])
        }

        func run(_ x: inout [Double]) {
            var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
            for i in x.indices {
                let input = x[i]
                let y = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
                x2 = x1; x1 = input; y2 = y1; y1 = y
                x[i] = y
            }
        }
    }
}
