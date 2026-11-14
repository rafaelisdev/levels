import AudioToolbox
import CoreAudio
import Foundation
import LevelsCore

/// Thin wrappers around the C Core Audio property API.
enum CA {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    /// kAudioObjectPropertyElementMain / ...Master (renamed in macOS 12; both are 0).
    static let mainElement = AudioObjectPropertyElement(0)
    /// virtualMainVolume ('vmvc'), spelled out so it works on macOS 11.
    static let virtualMainVolume = AudioObjectPropertySelector(0x766D_7663)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = CA.mainElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    // MARK: Generic reads / writes (plain-old-data values only)

    static func value<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                         initial: T) -> T? {
        var addr = address(selector, scope: scope)
        guard AudioObjectHasProperty(object, &addr) else { return nil }
        var size = UInt32(MemoryLayout<T>.size)
        var result = initial
        let status = withUnsafeMutablePointer(to: &result) {
            AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0)
        }
        return status == noErr ? result : nil
    }

    @discardableResult
    static func set<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                       _ newValue: T) -> Bool {
        var addr = address(selector, scope: scope)
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &addr),
              AudioObjectIsPropertySettable(object, &addr, &settable) == noErr,
              settable.boolValue else { return false }
        var v = newValue
        let status = withUnsafeMutablePointer(to: &v) {
            AudioObjectSetPropertyData(object, &addr, 0, nil, UInt32(MemoryLayout<T>.size), $0)
        }
        return status == noErr
    }

    static func isSettable(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                           scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> Bool {
        var addr = address(selector, scope: scope)
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &addr),
              AudioObjectIsPropertySettable(object, &addr, &settable) == noErr else { return false }
        return settable.boolValue
    }

    static func array<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                         initial: T) -> [T] {
        var addr = address(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var items = [T](repeating: initial, count: Int(size) / MemoryLayout<T>.stride)
        let status = items.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(items.prefix(Int(size) / MemoryLayout<T>.stride))
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> String? {
        var addr = address(selector, scope: scope)
        guard AudioObjectHasProperty(object, &addr) else { return nil }
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var ref: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &ref) {
            AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let ref else { return nil }
        return ref.takeRetainedValue() as String
    }

    // MARK: Devices

    static func defaultOutputDevice() -> AudioObjectID {
        value(system, kAudioHardwarePropertyDefaultOutputDevice, initial: AudioObjectID(kAudioObjectUnknown))
            ?? AudioObjectID(kAudioObjectUnknown)
    }

    static func deviceUID(_ device: AudioObjectID) -> String? {
        string(device, kAudioDevicePropertyDeviceUID)
    }

    static func deviceName(_ device: AudioObjectID) -> String {
        string(device, kAudioObjectPropertyName) ?? NSLocalizedString("Output", comment: "")
    }

    static func transportType(_ device: AudioObjectID) -> UInt32 {
        value(device, kAudioDevicePropertyTransportType, initial: UInt32(0)) ?? 0
    }

    /// Total channel count of a device (or aggregate) in the given scope.
    static func channelCount(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    // Device-wide volume as macOS shows it in the menu bar.
    static func volume(_ device: AudioObjectID) -> Float? {
        value(device, virtualMainVolume,
              scope: kAudioDevicePropertyScopeOutput, initial: Float32(0))
    }

    static func canSetVolume(_ device: AudioObjectID) -> Bool {
        isSettable(device, virtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
    }

    static func setVolume(_ device: AudioObjectID, _ v: Float) {
        set(device, virtualMainVolume,
            scope: kAudioDevicePropertyScopeOutput, Float32(min(max(v, 0), 1)))
    }

    static func isMuted(_ device: AudioObjectID) -> Bool {
        (value(device, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput, initial: UInt32(0)) ?? 0) != 0
    }

    static func setMuted(_ device: AudioObjectID, _ muted: Bool) {
        set(device, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput, UInt32(muted ? 1 : 0))
    }

    // MARK: Outputs (multi-output sync)

    struct OutputDevice: Equatable {
        let id: AudioObjectID
        let uid: String
        let name: String
        let transport: UInt32
    }

    static func deviceID(forUID uid: String) -> AudioObjectID? {
        var addr = address(kAudioHardwarePropertyTranslateUIDToDevice)
        var qualifier = uid as CFString
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafeMutablePointer(to: &qualifier) {
            AudioObjectGetPropertyData(system, &addr, UInt32(MemoryLayout<CFString>.size), $0, &size, &id)
        }
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    /// Real devices that can play sound. Virtual devices (other apps' drivers) and
    /// aggregates are left out: syncing to them makes no sense.
    static func outputDevices() -> [OutputDevice] {
        array(system, kAudioHardwarePropertyDevices, initial: AudioObjectID(0)).compactMap { id in
            let transport = transportType(id)
            guard transport != kAudioDeviceTransportTypeVirtual, transport != kAudioDeviceTransportTypeAggregate,
                  !array(id, kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput, initial: AudioObjectID(0)).isEmpty,
                  let uid = deviceUID(id) else { return nil }
            return OutputDevice(id: id, uid: uid, name: deviceName(id), transport: transport)
        }
    }

    static func nominalSampleRate(_ device: AudioObjectID) -> Double {
        value(device, kAudioDevicePropertyNominalSampleRate, initial: Float64(48_000)) ?? 48_000
    }

    /// What Core Audio knows about an output's latency (see `OutputTiming`).
    static func outputTiming(_ device: AudioObjectID, extraLatency: Double = 0) -> OutputTiming {
        let out = kAudioDevicePropertyScopeOutput
        let rate = nominalSampleRate(device)
        let buffer = value(device, kAudioDevicePropertyBufferFrameSize, initial: UInt32(512)) ?? 512
        let safety = value(device, kAudioDevicePropertySafetyOffset, scope: out, initial: UInt32(0)) ?? 0
        let latency = value(device, kAudioDevicePropertyLatency, scope: out, initial: UInt32(0)) ?? 0
        let stream = array(device, kAudioDevicePropertyStreams, scope: out, initial: AudioObjectID(0)).first
        let streamLatency = stream.flatMap { value($0, kAudioStreamPropertyLatency, initial: UInt32(0)) } ?? 0
        return OutputTiming(ioLatency: Double(buffer + safety) / rate,
                            bufferDuration: Double(buffer) / rate,
                            deviceLatency: Double(latency + streamLatency) / rate,
                            extraLatency: extraLatency)
    }

    // MARK: Processes (macOS 14.2+)

    @available(macOS 14.2, *)
    static func processObjects() -> [AudioObjectID] {
        array(system, kAudioHardwarePropertyProcessObjectList, initial: AudioObjectID(0))
    }

    @available(macOS 14.2, *)
    static func pid(ofProcess object: AudioObjectID) -> pid_t {
        value(object, kAudioProcessPropertyPID, initial: pid_t(-1)) ?? -1
    }

    @available(macOS 14.2, *)
    static func isRunningOutput(_ object: AudioObjectID) -> Bool {
        (value(object, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0)) ?? 0) != 0
    }
}

/// Exported by libSystem; maps helper/XPC processes (e.g. "Safari Web Content",
/// "Chrome Helper") to the app that is responsible for them.
@_silgen_name("responsibility_get_pid_responsible_for_pid")
func responsibility_get_pid_responsible_for_pid(_ pid: pid_t) -> pid_t

struct CoreAudioError: LocalizedError {
    let step: String
    let status: OSStatus
    var errorDescription: String? {
        String(format: NSLocalizedString("Couldn’t %@ (error %d)", comment: ""), NSLocalizedString(step, comment: ""), status)
    }
}

@inline(__always)
func check(_ status: OSStatus, _ step: String) throws {
    if status != noErr { throw CoreAudioError(step: step, status: status) }
}
