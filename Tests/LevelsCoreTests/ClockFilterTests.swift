import XCTest
@testable import LevelsCore

/// Deterministic noise so the tests never flake.
struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func uniform() -> Double { Double(next() >> 11) / Double(1 << 53) }
    /// Approximately normal (Irwin–Hall with 12 terms), mean 0, standard deviation 1.
    mutating func gaussian() -> Double { (0..<12).reduce(0) { acc, _ in acc + uniform() } - 6 }
}

final class ClockFilterTests: XCTestCase {
    private let nominal = 48_000.0
    private let block = 512.0

    /// A device running 80 ppm fast, read every 512 frames with 0.3 ms of jitter.
    private func runFilter(updates: Int, ppm: Double = 80, jitter: Double = 0.0003) -> (ClockFilter, truePeriod: Double, lastFrame: Double) {
        var filter = ClockFilter(nominalRate: nominal)
        var noise = SplitMix64(state: 42)
        let truePeriod = 1 / (nominal * (1 + ppm * 1e-6))
        let start = 1_000.0
        var frame = 0.0
        for _ in 0..<updates {
            filter.update(frame: frame, time: start + frame * truePeriod + noise.gaussian() * jitter)
            frame += block
        }
        return (filter, truePeriod, frame - block)
    }

    func testLearnsTheRealSampleRate() throws {
        let (filter, truePeriod, _) = runFilter(updates: 600)
        let line = try XCTUnwrap(filter.line)
        let errorPPM = abs(line.period / truePeriod - 1) * 1e6
        XCTAssertLessThan(errorPPM, 5, "rate error \(errorPPM) ppm")
    }

    func testAveragesAwayCallbackJitter() throws {
        let (filter, truePeriod, lastFrame) = runFilter(updates: 600)
        let line = try XCTUnwrap(filter.line)
        let trueTime = 1_000 + lastFrame * truePeriod
        // 0.3 ms of jitter in, a small fraction of that out.
        XCTAssertLessThan(abs(line.time(atFrame: lastFrame) - trueTime), 0.0001)
    }

    func testReanchorsAfterADiscontinuityButKeepsTheRate() throws {
        var (filter, _, lastFrame) = runFilter(updates: 600)
        let learned = try XCTUnwrap(filter.line).period
        let next = lastFrame + block
        let jumped = try XCTUnwrap(filter.line).time(atFrame: next) + 0.25   // device restarted
        filter.update(frame: next, time: jumped)
        let line = try XCTUnwrap(filter.line)
        XCTAssertEqual(line.time(atFrame: next), jumped, accuracy: 1e-9)
        XCTAssertEqual(line.period, learned, accuracy: 1e-15)
    }

    func testIgnoresRepeatedReadings() throws {
        var filter = ClockFilter(nominalRate: nominal)
        filter.update(frame: 0, time: 10)
        filter.update(frame: 0, time: 10.5)
        XCTAssertEqual(try XCTUnwrap(filter.line).time, 10)
    }

    func testFrameAndTimeAreInverse() {
        let line = ClockLine(frame: 1_000, time: 5, period: 1 / 44_100)
        XCTAssertEqual(line.frame(atTime: line.time(atFrame: 123_456.75)), 123_456.75, accuracy: 1e-6)
    }
}
