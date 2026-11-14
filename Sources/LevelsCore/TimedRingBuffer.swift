import os

/// Captured audio with a clock: one writer (the capture IO thread) appends frames,
/// several readers (one per output device, each on its own IO thread) read them back
/// at fractional positions chosen by host time.
///
/// Real-time rules: no allocation after init, and no blocking. Writer and readers
/// share only a small snapshot (write position + clock line) behind an unfair lock
/// that both sides take with `trylock`; whoever misses it simply uses the previous
/// snapshot for one more cycle.
public final class TimedRingBuffer {
    public struct Snapshot: Equatable {
        public var writePosition: Int64 = 0   // frames written so far (first unwritten frame)
        public var clock: ClockLine?          // capture frame <-> host time

        public init(writePosition: Int64 = 0, clock: ClockLine? = nil) {
            self.writePosition = writePosition
            self.clock = clock
        }
    }

    public let capacity: Int
    public let channels: Int
    /// Frames just behind the oldest data that readers must not touch, because the
    /// writer may already be overwriting them.
    public let guardFrames: Int

    private let mask: Int
    private let storage: UnsafeMutablePointer<Float>
    private let lock: UnsafeMutablePointer<os_unfair_lock>
    private var writePosition: Int64 = 0        // writer-owned
    private var published = Snapshot()          // guarded by `lock`

    /// - Parameter capacityFrames: rounded up to a power of two.
    public init(capacityFrames: Int, channels: Int = 2, guardFrames: Int = 4096) {
        var size = 1
        while size < capacityFrames { size <<= 1 }
        precondition(size > guardFrames * 2, "buffer too small for its guard band")
        capacity = size
        mask = size - 1
        self.channels = channels
        self.guardFrames = guardFrames
        storage = .allocate(capacity: size * channels)
        storage.initialize(repeating: 0, count: size * channels)
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        storage.deallocate()
        lock.deallocate()
    }

    // MARK: Writer (single thread)

    /// Next frame index the writer will fill.
    public var nextWritePosition: Int64 { writePosition }

    @inline(__always)
    public func store(_ value: Float, frame: Int64, channel: Int) {
        storage[(Int(truncatingIfNeeded: frame) & mask) * channels + channel] = value
    }

    /// Makes frames up to `nextWritePosition + count` part of the stream.
    public func advance(by count: Int) {
        writePosition += Int64(count)
    }

    /// Shares the current write position and clock with readers. Returns false if a
    /// reader held the lock; the next call publishes the newer state anyway.
    @discardableResult
    public func publish(clock: ClockLine?) -> Bool {
        guard os_unfair_lock_trylock(lock) else { return false }
        published = Snapshot(writePosition: writePosition, clock: clock)
        os_unfair_lock_unlock(lock)
        return true
    }

    // MARK: Readers

    /// Copies the latest published state. Returns false (and leaves `snapshot` as it
    /// was) if the writer was publishing at that instant.
    @discardableResult
    public func read(into snapshot: inout Snapshot) -> Bool {
        guard os_unfair_lock_trylock(lock) else { return false }
        snapshot = published
        os_unfair_lock_unlock(lock)
        return true
    }

    /// The span of frames a reader may interpolate in for `snapshot`.
    public func readableRange(for snapshot: Snapshot) -> ClosedRange<Int64>? {
        let newest = snapshot.writePosition - 1
        let oldest = max(0, snapshot.writePosition - Int64(capacity) + Int64(guardFrames))
        return oldest <= newest ? oldest...newest : nil
    }

    /// Catmull-Rom interpolated sample at a fractional frame position, or nil when the
    /// four neighbours are not all readable (not captured yet, or already overwritten).
    @inline(__always)
    public func sample(at position: Double, channel: Int, in range: ClosedRange<Int64>) -> Float? {
        let base = position.rounded(.down)
        let i = Int64(base)
        guard i - 1 >= range.lowerBound, i + 2 <= range.upperBound else { return nil }
        let t = Float(position - base)
        return catmullRom(raw(i - 1, channel), raw(i, channel), raw(i + 1, channel), raw(i + 2, channel), t)
    }

    @inline(__always)
    private func raw(_ frame: Int64, _ channel: Int) -> Float {
        storage[(Int(truncatingIfNeeded: frame) & mask) * channels + channel]
    }
}

/// Cubic Catmull-Rom interpolation between `y1` and `y2` (t in 0...1). Exact for
/// straight lines and smooth enough for the small rate changes clock drift needs.
@inline(__always)
public func catmullRom(_ y0: Float, _ y1: Float, _ y2: Float, _ y3: Float, _ t: Float) -> Float {
    let c1 = 0.5 * (y2 - y0)
    let c2 = y0 - 2.5 * y1 + 2 * y2 - 0.5 * y3
    let c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2)
    return ((c3 * t + c2) * t + c1) * t + y1
}
