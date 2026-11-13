import AppKit
import Foundation

/// The "System Audio Recording Only" permission that process taps need.
/// There is no public API to ask for it, so this uses the TCC calls macOS itself
/// uses (the same approach other audio-capture apps take). Without the permission a
/// tap returns silence while still muting the app, so taps are never created
/// before access is granted.
enum AudioCapturePermission {
    enum Status { case authorized, denied, unknown }

    private typealias PreflightFn = @convention(c) (CFString, CFDictionary?) -> Int
    private typealias RequestFn = @convention(c) (CFString, CFDictionary?, @escaping @convention(block) (Bool) -> Void) -> Void

    private static let service = "kTCCServiceAudioCapture" as CFString
    private static let handle = dlopen("/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)

    private static let preflight: PreflightFn? = {
        guard let handle, let sym = dlsym(handle, "TCCAccessPreflight") else { return nil }
        return unsafeBitCast(sym, to: PreflightFn.self)
    }()

    private static let requestFn: RequestFn? = {
        guard let handle, let sym = dlsym(handle, "TCCAccessRequest") else { return nil }
        return unsafeBitCast(sym, to: RequestFn.self)
    }()

    /// False when the TCC calls are missing; the app then just tries the tap.
    static var canCheck: Bool { preflight != nil && requestFn != nil }

    static func status() -> Status {
        guard let preflight else { return .authorized }
        switch preflight(service, nil) {
        case 0: return .authorized
        case 1: return .denied
        default: return .unknown
        }
    }

    static func request(_ completion: @escaping (Bool) -> Void) {
        guard let requestFn else { completion(true); return }
        requestFn(service, nil) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
        NSWorkspace.shared.open(url)
    }
}
