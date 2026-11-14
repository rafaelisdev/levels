import XCTest
@testable import LevelsCore

final class MeasureAnalysisTests: XCTestCase {
    /// A synthetic measurement: two outputs, the second 100 ms late in its solo phase,
    /// then both together after correction, with the near output 10x louder (like laptop
    /// speakers next to the microphone versus a TV across the room).
    private func makeRecording(jointOffset: Double) -> (MeasureRecording, [Float]) {
        let rate = 48_000.0
        let chirps = [MeasureRecording.ChirpSpec(duration: 0.03, from: 800, to: 3_500, amplitude: 0.2),
                      MeasureRecording.ChirpSpec(duration: 0.03, from: 5_000, to: 10_000, amplitude: 0.2)]
        var rec = MeasureRecording(rate: rate, micLatency: 0.02, clickInterval: 0.6, clicksPerPhase: 4,
                                   outputNames: ["TV", "Speakers"], chirps: chirps, reference: 1,
                                   phases: [.init(name: "TV alone", gains: [1, 0], start: 1.0, delay: 0.05),
                                            .init(name: "Speakers alone", gains: [0, 1], start: 4.0, delay: 0.05),
                                            .init(name: "together", gains: [1, 1], start: 7.0, delay: 0.15)])
        var rng = SplitMix64(state: 11)
        var s = (0..<Int(10 * rate)).map { _ in Float(rng.gaussian()) * 0.002 }
        func add(_ output: Int, at seconds: Double, gain: Float) {
            let start = Int(seconds * rate)
            for (i, v) in chirps[output].samples(rate: rate).enumerated() { s[start + i] += v * gain }
        }
        // Lateness relative to "played + delay" (+ mic latency): TV +0.08, speakers -0.02.
        for phase in rec.phases {
            for click in 0..<rec.clicksPerPhase {
                let t = Double(rec.chirpStart(phase, click)) / rate + phase.delay + rec.micLatency
                if phase.gains[0] > 0 { add(0, at: t + (phase.joint ? -0.02 + jointOffset : 0.08), gain: 0.1) }
                if phase.gains[1] > 0 { add(1, at: t - 0.02, gain: 1) }
            }
        }
        rec.phases[2].delay = 0.15
        return (rec, s)
    }

    func testSoloPhasesGiveTheRelativeCorrection() throws {
        let (rec, s) = makeRecording(jointOffset: 0)
        let solo = MeasureAnalysis(recording: rec, samples: s).soloErrors()
        XCTAssertEqual(try XCTUnwrap(solo[0]), 0.08, accuracy: 0.0002)
        XCTAssertEqual(try XCTUnwrap(solo[1]), -0.02, accuracy: 0.0002)
    }

    func testFindsAQuietOutputUnderALoudOneWhenAligned() throws {
        // The TV is 10x quieter than the speakers and lands on the same spot.
        let (rec, s) = makeRecording(jointOffset: 0)
        let analysis = MeasureAnalysis(recording: rec, samples: s)
        let tv = analysis.arrivals(rec.phases[2], output: 0, around: -0.02, tolerance: 0.01, threshold: 0.3)
        XCTAssertTrue(tv.allSatisfy { $0 != nil }, "quiet output must still be found: \(tv)")
        for a in tv.compactMap({ $0 }) { XCTAssertEqual(a.error, -0.02, accuracy: 0.0003) }
    }

    func testDoesNotInventAnAlignedOutput() {
        // If the TV is really 40 ms off, it must not be "found" inside ±10 ms.
        let (rec, s) = makeRecording(jointOffset: 0.04)
        let analysis = MeasureAnalysis(recording: rec, samples: s)
        let tv = analysis.arrivals(rec.phases[2], output: 0, around: -0.02, tolerance: 0.01, threshold: 0.3)
        XCTAssertTrue(tv.allSatisfy { $0 == nil }, "a misaligned output must not be reported as aligned: \(tv)")
    }
}
