import CoreAudio
import Foundation

/// Takes over the audio of one app's processes and plays it back with a gain.
///
/// How it works: a Core Audio process tap captures the app's output and mutes the
/// original (`.mutedWhenTapped`). A private aggregate device made of the current
/// output device + the tap runs an IO block that copies the tapped audio to the
/// output, multiplied by `gain`. If anything stops, the tap stops being read and
/// macOS unmutes the app by itself, so a failure never leaves an app silent.
@available(macOS 14.2, *)
final class ProcessTap {
    let outputUID: String
    private(set) var processObjects: [AudioObjectID]

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var tapDescription: CATapDescription?
    private let gainStorage: UnsafeMutablePointer<Float>
    /// Debug only (--debug): peak of tapped input and of our output since last read.
    private let meter: UnsafeMutablePointer<Float>?

    /// Linear amplitude, 0...1. Read from the real-time thread without locks
    /// (a single aligned Float store/load), ramped there to avoid clicks.
    var gain: Float {
        get { gainStorage.pointee }
        set { gainStorage.pointee = min(max(newValue, 0), 1) }
    }

    init(processObjects: [AudioObjectID], outputUID: String, gain: Float, label: String) throws {
        self.processObjects = processObjects
        self.outputUID = outputUID
        gainStorage = .allocate(capacity: 1)
        gainStorage.initialize(to: min(max(gain, 0), 1))
        if DebugFlags.debug {
            meter = .allocate(capacity: 2)
            meter!.initialize(repeating: 0, count: 2)
        } else {
            meter = nil
        }
        do {
            try start(label: label)
        } catch {
            invalidate()
            throw error
        }
    }

    deinit {
        invalidate()
        gainStorage.deallocate()
        meter?.deallocate()
    }

    func takePeaks() -> (input: Float, output: Float)? {
        guard let meter else { return nil }
        defer { meter[0] = 0; meter[1] = 0 }
        return (meter[0], meter[1])
    }

    private func start(label: String) throws {
        let description = CATapDescription(stereoMixdownOfProcesses: processObjects)
        description.uuid = UUID()
        description.name = "Levels – \(label)"
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true
        tapDescription = description

        var tap = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(description, &tap), "перехватить звук приложения")
        tapID = tap

        let format = CA.value(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
        if let format, format.mFormatID != kAudioFormatLinearPCM || format.mFormatFlags & kAudioFormatFlagIsFloat == 0 {
            throw CoreAudioError(step: "разобрать формат звука", status: OSStatus(format.mFormatID))
        }
        let tapChannels = Int(format?.mChannelsPerFrame ?? 2)

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Levels – \(label)",
            kAudioAggregateDeviceUIDKey: "Levels-" + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var agg = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &agg), "создать аудиоустройство")
        aggregateID = agg

        let gainPointer = UnsafePointer(gainStorage)
        let meter = self.meter
        var current = gainStorage.pointee
        var procID: AudioDeviceIOProcID?
        // nil queue: the block runs directly on the real-time IO thread.
        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, agg, nil) { _, input, _, output, _ in
            let target = gainPointer.pointee
            GainRenderer.render(input: input, output: output, tapChannels: tapChannels, from: current, to: target)
            current = target
            if let meter {
                meter[0] = max(meter[0], GainRenderer.peak(UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))))
                meter[1] = max(meter[1], GainRenderer.peak(UnsafeMutableAudioBufferListPointer(output)))
            }
        }, "запустить обработку звука")
        ioProcID = procID

        try check(AudioDeviceStart(agg, procID), "запустить вывод")
    }

    /// Swap the set of processes (e.g. Safari opened a new tab process) without
    /// tearing the tap down. Returns false if Core Audio refused; the caller then rebuilds.
    func updateProcesses(_ objects: [AudioObjectID]) -> Bool {
        guard let description = tapDescription, tapID != kAudioObjectUnknown else { return false }
        description.processes = objects
        var addr = CA.address(kAudioTapPropertyDescription)
        var ref: CATapDescription = description
        let status = withUnsafeMutablePointer(to: &ref) {
            AudioObjectSetPropertyData(tapID, &addr, 0, nil, UInt32(MemoryLayout<CATapDescription>.size), $0)
        }
        if status == noErr { processObjects = objects }
        return status == noErr
    }

    func invalidate() {
        if aggregateID != kAudioObjectUnknown {
            if let ioProcID {
                AudioDeviceStop(aggregateID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }
}

/// Real-time safe copy: tap → output with a linear gain ramp. No allocations, no locks.
enum GainRenderer {
    static func render(input: UnsafePointer<AudioBufferList>,
                       output: UnsafeMutablePointer<AudioBufferList>,
                       tapChannels: Int,
                       from g0: Float, to g1: Float) {
        let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outs = UnsafeMutableAudioBufferListPointer(output)

        // The aggregate's input list holds the output device's own inputs (if it has any,
        // e.g. a USB interface) first and the tap last, so skip to the tap's channels.
        var totalIn = 0
        for b in ins { totalIn += Int(b.mNumberChannels) }
        let tapCount = min(tapChannels, totalIn)
        let offset = totalIn - tapCount

        var frames = Int.max
        if tapCount > 0 {
            for c in 0..<tapCount {
                if let ch = channel(ins, offset + c) { frames = min(frames, ch.frames) }
            }
        }

        var totalOut = 0
        for b in outs { totalOut += Int(b.mNumberChannels) }

        var outBase = 0
        for ob in outs {
            let oc = Int(ob.mNumberChannels)
            defer { outBase += oc }
            guard let raw = ob.mData else { continue }
            memset(raw, 0, Int(ob.mDataByteSize))
            guard oc > 0, tapCount > 0, frames != .max else { continue }

            let dst = raw.assumingMemoryBound(to: Float.self)
            let n = min(frames, Int(ob.mDataByteSize) / (MemoryLayout<Float>.size * oc))
            guard n > 0 else { continue }
            let step = (g1 - g0) / Float(n)

            for c in 0..<oc {
                let global = outBase + c
                if totalOut == 1 && tapCount >= 2 {
                    // Mono output: fold L+R.
                    guard let l = channel(ins, offset), let r = channel(ins, offset + 1) else { continue }
                    var g = g0
                    for f in 0..<n {
                        dst[f * oc + c] = 0.5 * (l.data[f * l.stride] + r.data[f * r.stride]) * g
                        g += step
                    }
                    continue
                }
                let source: Int
                if global < tapCount { source = global }
                else if tapCount == 1 && global < 2 { source = 0 }
                else { continue } // extra surround channels stay silent
                guard let s = channel(ins, offset + source) else { continue }
                var g = g0
                for f in 0..<n {
                    dst[f * oc + c] = s.data[f * s.stride] * g
                    g += step
                }
            }
        }
    }

    static func peak(_ list: UnsafeMutableAudioBufferListPointer) -> Float {
        var p: Float = 0
        for b in list {
            guard let d = b.mData else { continue }
            let samples = d.assumingMemoryBound(to: Float.self)
            for i in 0..<(Int(b.mDataByteSize) / MemoryLayout<Float>.size) { p = max(p, abs(samples[i])) }
        }
        return p
    }

    private struct Channel {
        let data: UnsafePointer<Float>
        let stride: Int
        let frames: Int
    }

    @inline(__always)
    private static func channel(_ list: UnsafeMutableAudioBufferListPointer, _ index: Int) -> Channel? {
        var base = 0
        for b in list {
            let n = Int(b.mNumberChannels)
            if index < base + n, n > 0, let d = b.mData {
                let p = UnsafePointer(d.assumingMemoryBound(to: Float.self)) + (index - base)
                return Channel(data: p, stride: n, frames: Int(b.mDataByteSize) / (MemoryLayout<Float>.size * n))
            }
            base += n
        }
        return nil
    }
}
