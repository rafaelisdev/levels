import XCTest
@testable import LevelsCore

final class CorrelationTests: XCTestCase {
    private let rate = 48_000.0
    private lazy var chirp = Chirp.make(rate: rate, duration: 0.005, from: 1_000, to: 8_000, amplitude: 0.3)

    /// Noise with the chirp added at whole-sample positions.
    private func signal(length: Int, arrivals: [(at: Int, gain: Float)], noise: Float, seed: UInt64 = 7) -> [Float] {
        var rng = SplitMix64(state: seed)
        var s = (0..<length).map { _ in Float(rng.gaussian()) * noise }
        for a in arrivals {
            for (i, v) in chirp.enumerated() where a.at + i < length { s[a.at + i] += v * a.gain }
        }
        return s
    }

    func testFindsAChirpInNoiseToTheSample() throws {
        let s = signal(length: 20_000, arrivals: [(at: 12_345, gain: 0.2)], noise: 0.01)
        let peak = try XCTUnwrap(Correlation.peaks(in: s, template: chirp, range: 0..<19_000, count: 1, separation: 48).first)
        XCTAssertEqual(peak.position, 12_345, accuracy: 0.5)
        XCTAssertGreaterThan(peak.score, 0.8)
    }

    func testSeparatesTwoOutputsThreeMillisecondsApart() throws {
        // Two speakers playing the same click 3 ms (144 samples) apart, one quieter.
        let s = signal(length: 20_000, arrivals: [(at: 10_000, gain: 0.3), (at: 10_144, gain: 0.12)], noise: 0.005)
        let peaks = Correlation.peaks(in: s, template: chirp, range: 9_000..<12_000, count: 2, separation: 48)
        XCTAssertEqual(peaks.count, 2)
        let positions = peaks.map(\.position).sorted()
        XCTAssertEqual(positions[0], 10_000, accuracy: 1)
        XCTAssertEqual(positions[1], 10_144, accuracy: 1)
    }

    func testUpAndDownChirpsAreTimedIndependentlyWhenTheyOverlap() throws {
        // Two outputs play opposite sweeps at the same moment, 1 ms apart: each template
        // must find its own output, not the other one.
        let up = Chirp.make(rate: rate, duration: 0.008, from: 1_000, to: 8_000, amplitude: 0.2)
        let down = Chirp.make(rate: rate, duration: 0.008, from: 8_000, to: 1_000, amplitude: 0.2)
        var rng = SplitMix64(state: 3)
        var s = (0..<20_000).map { _ in Float(rng.gaussian()) * 0.005 }
        for (i, v) in up.enumerated() { s[10_000 + i] += v }
        for (i, v) in down.enumerated() { s[10_048 + i] += 0.5 * v }
        let upPeak = try XCTUnwrap(Correlation.peaks(in: s, template: up, range: 9_000..<12_000, count: 1, separation: 24).first)
        let downPeak = try XCTUnwrap(Correlation.peaks(in: s, template: down, range: 9_000..<12_000, count: 1, separation: 24).first)
        XCTAssertEqual(upPeak.position, 10_000, accuracy: 1)
        XCTAssertEqual(downPeak.position, 10_048, accuracy: 1)
    }

    func testScoresStayNormalisedOverLongQuietStretches() throws {
        // Band-filtered silence is tiny; a drifting running energy once produced scores
        // in the hundreds. Normalised correlation can never exceed 1.
        var rng = SplitMix64(state: 5)
        var s = (0..<60_000).map { _ in Float(rng.gaussian()) * 1e-6 }
        for (i, v) in chirp.enumerated() { s[50_000 + i] += v * 0.01 }
        let peaks = Correlation.peaks(in: s, template: chirp, range: 0..<59_000, count: 3, separation: 48, threshold: 0.2)
        XCTAssertTrue(peaks.allSatisfy { $0.score <= 1.0001 }, "\(peaks)")
        XCTAssertEqual(try XCTUnwrap(peaks.first).position, 50_000, accuracy: 0.5)
    }

    func testReportsNothingWhenOnlyNoiseIsThere() {
        let s = signal(length: 20_000, arrivals: [], noise: 0.01)
        XCTAssertTrue(Correlation.peaks(in: s, template: chirp, range: 0..<19_000, count: 2, separation: 48, threshold: 0.5).isEmpty)
    }

    func testChirpIsWindowedAndBounded() {
        XCTAssertEqual(chirp.count, 240)
        XCTAssertEqual(chirp.first ?? 1, 0, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(chirp.map(abs).max() ?? 1, 0.3)
    }
}
