import XCTest
@testable import LevelsCore

final class TimedRingBufferTests: XCTestCase {
    private func fill(_ buffer: TimedRingBuffer, frames: Int, _ value: (Int64) -> Float) {
        let start = buffer.nextWritePosition
        for f in start..<(start + Int64(frames)) {
            for c in 0..<buffer.channels { buffer.store(value(f), frame: f, channel: c) }
        }
        buffer.advance(by: frames)
    }

    func testCapacityIsRoundedUpToAPowerOfTwo() {
        XCTAssertEqual(TimedRingBuffer(capacityFrames: 10_000, guardFrames: 512).capacity, 16_384)
    }

    func testPublishedSnapshotReachesReaders() {
        let buffer = TimedRingBuffer(capacityFrames: 16_384, guardFrames: 512)
        fill(buffer, frames: 100) { _ in 0 }
        let clock = ClockLine(frame: 0, time: 1, period: 1 / 48_000)
        XCTAssertTrue(buffer.publish(clock: clock))
        var snapshot = TimedRingBuffer.Snapshot()
        XCTAssertTrue(buffer.read(into: &snapshot))
        XCTAssertEqual(snapshot, .init(writePosition: 100, clock: clock))
    }

    func testInterpolationIsExactOnAStraightLine() throws {
        let buffer = TimedRingBuffer(capacityFrames: 16_384, guardFrames: 512)
        fill(buffer, frames: 1_000) { Float($0) }
        buffer.publish(clock: nil)
        var snapshot = TimedRingBuffer.Snapshot()
        buffer.read(into: &snapshot)
        let range = try XCTUnwrap(buffer.readableRange(for: snapshot))
        XCTAssertEqual(try XCTUnwrap(buffer.sample(at: 500.25, channel: 1, in: range)), 500.25, accuracy: 1e-3)
    }

    func testFractionalDelayOfASineIsAccurate() throws {
        // 1 kHz at 48 kHz, read 0.37 frames off the grid everywhere.
        let rate = 48_000.0, freq = 1_000.0
        let buffer = TimedRingBuffer(capacityFrames: 16_384, guardFrames: 512)
        fill(buffer, frames: 4_800) { Float(sin(2 * .pi * freq * Double($0) / rate)) }
        buffer.publish(clock: nil)
        var snapshot = TimedRingBuffer.Snapshot()
        buffer.read(into: &snapshot)
        let range = try XCTUnwrap(buffer.readableRange(for: snapshot))
        var worst: Float = 0
        for i in stride(from: 10.0, to: 4_700, by: 1) {
            let x = i + 0.37
            let got = try XCTUnwrap(buffer.sample(at: x, channel: 0, in: range))
            worst = max(worst, abs(got - Float(sin(2 * .pi * freq * x / rate))))
        }
        XCTAssertLessThan(worst, 1e-3, "worst error \(worst) (\(20 * log10(worst)) dB)")
    }

    func testRefusesFramesThatAreNotCapturedYet() throws {
        let buffer = TimedRingBuffer(capacityFrames: 16_384, guardFrames: 512)
        fill(buffer, frames: 100) { _ in 1 }
        buffer.publish(clock: nil)
        var snapshot = TimedRingBuffer.Snapshot()
        buffer.read(into: &snapshot)
        let range = try XCTUnwrap(buffer.readableRange(for: snapshot))
        XCTAssertNotNil(buffer.sample(at: 97.5, channel: 0, in: range))   // needs 96...99, all written
        XCTAssertNil(buffer.sample(at: 98.5, channel: 0, in: range))      // needs frame 100, not yet
    }

    func testRefusesFramesTheWriterMayBeOverwriting() throws {
        let buffer = TimedRingBuffer(capacityFrames: 16_384, guardFrames: 512)
        fill(buffer, frames: 40_000) { Float($0) }   // wrapped around twice
        buffer.publish(clock: nil)
        var snapshot = TimedRingBuffer.Snapshot()
        buffer.read(into: &snapshot)
        let range = try XCTUnwrap(buffer.readableRange(for: snapshot))
        XCTAssertEqual(range.lowerBound, 40_000 - 16_384 + 512)
        XCTAssertNil(buffer.sample(at: Double(range.lowerBound), channel: 0, in: range))
        XCTAssertEqual(try XCTUnwrap(buffer.sample(at: 39_000, channel: 0, in: range)), 39_000, accuracy: 1e-2)
    }
}
