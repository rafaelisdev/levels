import CoreAudio
import Foundation

/// Channel count and sample rate of the audio a tap delivers.
struct TapFormat {
    let channels: Int
    let sampleRate: Double
}

/// A Core Audio process tap and the private aggregate device that reads it.
///
/// The tap mutes its processes only while the aggregate is running, so whenever a
/// session stops (or Levels quits or crashes) macOS gives the apps their sound back.
/// What happens to the tapped audio is up to the IO block the owner supplies.
@available(macOS 14.2, *)
final class TapSession {
    let clockDeviceUID: String
    let format: TapFormat
    private(set) var processObjects: [AudioObjectID]

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let description: CATapDescription

    /// - Parameters:
    ///   - clockDeviceUID: device the aggregate runs on (its clock, and its output buffers).
    ///   - makeIOBlock: builds the real-time block once the tap's format is known.
    init(processObjects: [AudioObjectID], clockDeviceUID: String, label: String,
         makeIOBlock: (TapFormat) -> AudioDeviceIOBlock) throws {
        self.processObjects = processObjects
        self.clockDeviceUID = clockDeviceUID

        description = CATapDescription(stereoMixdownOfProcesses: processObjects)
        description.uuid = UUID()
        description.name = "Levels – \(label)"
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true

        var tap = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(description, &tap), "capture the app’s audio")
        tapID = tap

        let asbd = CA.value(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
        format = TapFormat(channels: Int(asbd?.mChannelsPerFrame ?? 2), sampleRate: asbd?.mSampleRate ?? 48_000)

        do {
            if let asbd, asbd.mFormatID != kAudioFormatLinearPCM || asbd.mFormatFlags & kAudioFormatFlagIsFloat == 0 {
                throw CoreAudioError(step: "read the audio format", status: OSStatus(asbd.mFormatID))
            }
            aggregateID = try Self.makeAggregate(label: label, clockDeviceUID: clockDeviceUID, tapUID: description.uuid.uuidString)

            var procID: AudioDeviceIOProcID?
            // nil queue: the block runs directly on the real-time IO thread.
            try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil, makeIOBlock(format)),
                      "start audio processing")
            ioProcID = procID
            try check(AudioDeviceStart(aggregateID, procID), "start the output")
        } catch {
            invalidate()
            throw error
        }
    }

    deinit { invalidate() }

    /// Seconds between a frame being captured and the IO block seeing it: one buffer
    /// plus the aggregate's input safety offset.
    var inputLatency: Double {
        let frames = (CA.value(aggregateID, kAudioDevicePropertyBufferFrameSize, initial: UInt32(512)) ?? 512)
            + (CA.value(aggregateID, kAudioDevicePropertySafetyOffset, scope: kAudioDevicePropertyScopeInput, initial: UInt32(0)) ?? 0)
        return Double(frames) / format.sampleRate
    }

    /// Swap the set of processes (e.g. Safari opened a new tab process) without
    /// tearing the tap down. Returns false if Core Audio refused; the caller then rebuilds.
    func updateProcesses(_ objects: [AudioObjectID]) -> Bool {
        guard tapID != kAudioObjectUnknown else { return false }
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

    private static func makeAggregate(label: String, clockDeviceUID: String, tapUID: String) throws -> AudioObjectID {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Levels – \(label)",
            kAudioAggregateDeviceUIDKey: "Levels-" + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: clockDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: clockDeviceUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tapUID,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var aggregate = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregate), "create the audio device")
        return aggregate
    }
}

/// Finding channels in an `AudioBufferList`, which may be interleaved or not.
enum BufferChannels {
    struct Channel {
        let data: UnsafeMutablePointer<Float>
        let stride: Int    // samples between frames (channels in that buffer)
        let frames: Int
    }

    static func count(_ list: UnsafeMutableAudioBufferListPointer) -> Int {
        list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    @inline(__always)
    static func channel(_ list: UnsafeMutableAudioBufferListPointer, _ index: Int) -> Channel? {
        var base = 0
        for b in list {
            let n = Int(b.mNumberChannels)
            if index < base + n, n > 0, let d = b.mData {
                return Channel(data: d.assumingMemoryBound(to: Float.self) + (index - base), stride: n,
                               frames: Int(b.mDataByteSize) / (MemoryLayout<Float>.size * n))
            }
            base += n
        }
        return nil
    }

    /// In an aggregate's input list the clock device's own inputs (if any, e.g. a USB
    /// interface) come first and the tap last: returns where the tap's channels start.
    static func tapRange(_ input: UnsafeMutableAudioBufferListPointer, tapChannels: Int) -> (offset: Int, count: Int) {
        let total = count(input)
        let tapCount = min(tapChannels, total)
        return (total - tapCount, tapCount)
    }

    static func silence(_ list: UnsafeMutableAudioBufferListPointer) {
        for b in list { if let d = b.mData { memset(d, 0, Int(b.mDataByteSize)) } }
    }
}
