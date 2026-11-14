import AppKit
import CoreAudio
import LevelsCore

/// Debug-only acoustic check of multi-output sync (`--sync-measure`, run from the
/// "Levels Measure" copy so the real app never asks for the microphone).
///
/// The microphone's IO thread drives everything: it records, and on the same clock it
/// feeds the test signal into the buffer the output players read. A chirp written at
/// frame p and heard at frame m arrived after exactly (m - p) frames.
///
/// Each output alone first (clean timing, gives its correction), then all outputs at
/// once with the corrections applied. Outputs use chirps in separate frequency bands,
/// so `MeasureAnalysis` can time each one even while they overlap. With
/// `--measure-dump <path>` the recording is saved for `--sync-analyze <path>`.
@available(macOS 14.2, *)
final class SyncMeasure {
    private static var running: SyncMeasure?

    static func run(outputUIDs: [String]?, dumpPath: String?) {
        do {
            running = try SyncMeasure(outputUIDs: outputUIDs, dumpPath: dumpPath)
        } catch {
            print("measure: \(error.localizedDescription)")
            NSApp.terminate(nil)
        }
    }

    /// Offline: analyse a saved recording, print the report, quit.
    static func analyze(path: String) {
        do {
            let recording = try JSONDecoder().decode(MeasureRecording.self, from: Data(contentsOf: URL(fileURLWithPath: path + ".json")))
            let raw = try Data(contentsOf: URL(fileURLWithPath: path + ".f32"))
            let samples = raw.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
            MeasureAnalysis(recording: recording, samples: samples).report().forEach { print("analyze: \($0)") }
        } catch {
            print("analyze: \(error.localizedDescription)")
        }
        NSApp.terminate(nil)
    }

    // Schedule (seconds). The long lead lets a TV's HDMI audio wake up first.
    private static let lead = 1.5, clickInterval = 0.6, clicksPerPhase = 6, gap = 1.2
    private static var phaseLength: Double { Double(clicksPerPhase) * clickInterval + gap }
    /// One band per output, far enough apart that a loud output can't mask a quiet one.
    private static let chirpSpecs = [MeasureRecording.ChirpSpec(duration: 0.03, from: 800, to: 3_500, amplitude: 0.2),
                                     MeasureRecording.ChirpSpec(duration: 0.03, from: 5_000, to: 10_000, amplitude: 0.2)]

    private var recording: MeasureRecording
    private let length: Int
    private let dumpPath: String?
    private let source: [UnsafeMutablePointer<Float>]     // one channel per output
    private let samples: UnsafeMutablePointer<Float>      // what the microphone heard
    private let written: UnsafeMutablePointer<Int64>
    private let ring = TimedRingBuffer(capacityFrames: 1 << 17)
    private let micID: AudioObjectID
    /// Part of the playout delay covering the microphone side (input buffer + margin),
    /// kept when the delay is recomputed after corrections.
    private let captureAllowance: Double
    private var micProc: AudioDeviceIOProcID?
    private var players: [OutputPlayer] = []
    private var current = -1
    private var timer: Timer?

    private init(outputUIDs: [String]?, dumpPath: String?) throws {
        self.dumpPath = dumpPath
        micID = CA.value(CA.system, kAudioHardwarePropertyDefaultInputDevice, initial: AudioObjectID(kAudioObjectUnknown)) ?? 0
        guard micID != kAudioObjectUnknown else {
            throw CoreAudioError(step: "find the microphone", status: OSStatus(kAudioHardwareBadDeviceError))
        }
        let rate = CA.nominalSampleRate(micID)
        let input = kAudioDevicePropertyScopeInput
        let micLatency = (CA.value(micID, kAudioDevicePropertyLatency, scope: input, initial: UInt32(0)) ?? 0)
            + (CA.array(micID, kAudioDevicePropertyStreams, scope: input, initial: AudioObjectID(0)).first
                .flatMap { CA.value($0, kAudioStreamPropertyLatency, initial: UInt32(0)) } ?? 0)
        let micIO = Double((CA.value(micID, kAudioDevicePropertyBufferFrameSize, initial: UInt32(512)) ?? 512)
            + (CA.value(micID, kAudioDevicePropertySafetyOffset, scope: input, initial: UInt32(0)) ?? 0)) / rate
        captureAllowance = micIO + 0.005

        // Two outputs at most: two bands, two source channels.
        let uids = Array((outputUIDs ?? CA.outputDevices().map(\.uid)).prefix(2))
        let names = uids.map { uid in CA.deviceID(forUID: uid).map(CA.deviceName) ?? uid }
        var phases = names.indices.map { i in
            MeasureRecording.Phase(name: "\(names[i]) alone", gains: names.indices.map { $0 == i ? 1 : 0 })
        }
        if uids.count > 1 { phases.append(.init(name: "together, corrected", gains: uids.map { _ in 1 })) }
        for i in phases.indices { phases[i].start = Self.lead + Double(i) * Self.phaseLength }
        let reference = uids.firstIndex { uid in
            CA.deviceID(forUID: uid).map { CA.transportType($0) == kAudioDeviceTransportTypeBuiltIn } ?? false
        } ?? 0
        recording = MeasureRecording(rate: rate, micLatency: Double(micLatency) / rate, clickInterval: Self.clickInterval,
                                     clicksPerPhase: Self.clicksPerPhase, outputNames: names,
                                     chirps: Array(Self.chirpSpecs.prefix(uids.count)), reference: reference, phases: phases)

        // The test signal: each output's chirp in its own source channel.
        let length = Int((Self.lead + Double(phases.count) * Self.phaseLength + 1) * rate)
        self.length = length
        source = (0..<2).map { _ in
            let channel = UnsafeMutablePointer<Float>.allocate(capacity: length)
            channel.initialize(repeating: 0, count: length)
            return channel
        }
        for (output, spec) in recording.chirps.enumerated() {
            let chirp = spec.samples(rate: rate)
            for phase in phases {
                for click in 0..<Self.clicksPerPhase {
                    let at = recording.chirpStart(phase, click)
                    for (k, v) in chirp.enumerated() { source[output][at + k] = v }
                }
            }
        }
        samples = .allocate(capacity: length)
        samples.initialize(repeating: 0, count: length)
        written = .allocate(capacity: 1)
        written.initialize(to: 0)

        let timings = try uids.map { uid -> OutputTiming in
            guard let id = CA.deviceID(forUID: uid) else {
                throw CoreAudioError(step: "find the output device", status: OSStatus(kAudioHardwareBadDeviceError))
            }
            return CA.outputTiming(id)
        }
        let delay = (timings.map(\.total).max() ?? 0) + captureAllowance
        players = try zip(uids, timings).map { try OutputPlayer(deviceUID: $0, buffer: ring, timing: $1, delay: delay, gain: 0) }
        for (i, player) in players.enumerated() { player.sourceChannel = i }

        print(String(format: "measure: mic %@ (reported input latency %.1f ms), playout delay %.1f ms",
                     CA.deviceName(micID), recording.micLatency * 1000, delay * 1000))
        for (p, spec) in zip(players, recording.chirps) {
            let t = p.timing
            print(String(format: "measure: output %@ (%.0f–%.0f Hz) io %.1f + buffer %.1f + device %.1f ms", p.name,
                         spec.from, spec.to, t.ioLatency * 1000, t.bufferDuration * 1000, t.deviceLatency * 1000))
        }
        try startMicrophone()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in self?.tick() }
    }

    deinit {
        source.forEach { $0.deallocate() }
        samples.deallocate()
        written.deallocate()
    }

    private var heard: [Float] { Array(UnsafeBufferPointer(start: samples, count: length)) }

    private func startMicrophone() throws {
        let ring = self.ring, left = source[0], right = source[1], samples = self.samples
        let written = self.written, length = self.length
        var clock = ClockFilter(nominalRate: recording.rate)
        let block: AudioDeviceIOBlock = { _, input, inputTime, _, _ in
            let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            guard let mic = BufferChannels.channel(inputs, 0) else { return }
            let start = ring.nextWritePosition
            if inputTime.pointee.mFlags.contains(.hostTimeValid) {
                clock.update(frame: Double(start), time: HostClock.seconds(fromTicks: inputTime.pointee.mHostTime))
            }
            for f in 0..<mic.frames {
                let p = Int(start) + f
                let inRange = p < length
                ring.store(inRange ? left[p] : 0, frame: Int64(p), channel: 0)
                ring.store(inRange ? right[p] : 0, frame: Int64(p), channel: 1)
                if inRange { samples[p] = mic.data[f * mic.stride] }
            }
            ring.advance(by: mic.frames)
            ring.publish(clock: clock.line)
            written.pointee = ring.nextWritePosition
        }
        var proc: AudioDeviceIOProcID?
        try check(AudioDeviceCreateIOProcIDWithBlock(&proc, micID, nil, block), "open the microphone")
        micProc = proc
        try check(AudioDeviceStart(micID, proc), "start the microphone")
    }

    /// Main thread: open the outputs for the phase now playing, correct once before the
    /// joint phase, finish when the signal is done.
    private func tick() {
        guard let delay = players.first?.delay else { return }
        let playing = Double(written.pointee) / recording.rate - delay
        let index = Int(((playing - Self.lead + Self.gap / 2) / Self.phaseLength).rounded(.down))
        // Phases only move forward: raising the delay makes "what is playing now" step
        // back, which must not re-enter an earlier phase.
        if index > current, index < recording.phases.count {
            current = index
            if recording.phases[index].joint { applyCorrections() }
            for (player, gain) in zip(players, recording.phases[index].gains) { player.gain = gain }
            recording.phases[index].delay = players[0].delay
        }
        if written.pointee >= Int64(length) { finish() }
    }

    /// Solo timings, relative to the reference output, become extra latency; then the
    /// group is re-timed around the new slowest output.
    private func applyCorrections() {
        let solo = MeasureAnalysis(recording: recording, samples: heard).soloErrors()
        guard recording.reference < solo.count, let anchor = solo[recording.reference] else { return }
        for (player, error) in zip(players, solo) {
            if let error { player.extraLatency += error - anchor }
        }
        let delay = (players.map(\.timing.total).max() ?? 0) + captureAllowance
        for player in players { player.delay = delay }
    }

    private func finish() {
        timer?.invalidate()
        if let micProc {
            AudioDeviceStop(micID, micProc)
            AudioDeviceDestroyIOProcID(micID, micProc)
        }
        players.forEach { $0.invalidate() }

        MeasureAnalysis(recording: recording, samples: heard).report().forEach { print("measure: \($0)") }
        if let dumpPath {
            do {
                try JSONEncoder().encode(recording).write(to: URL(fileURLWithPath: dumpPath + ".json"))
                try Data(buffer: UnsafeBufferPointer(start: samples, count: length)).write(to: URL(fileURLWithPath: dumpPath + ".f32"))
                print("measure: recording saved to \(dumpPath).json/.f32")
            } catch {
                print("measure: could not save the recording: \(error.localizedDescription)")
            }
        }
        print("measure: done")
        NSApp.terminate(nil)
    }
}
